//
//  PlayerModel.swift
//  Marlin Media TV
//
//  VLCKit playing the server's original file directly. The remote's meaning (DECISIONS.md D008):
//  click = play/pause; Menu = back; while playing, left/right = −10 s / +30 s; while paused,
//  a left/right click = one frame back / forward — through VLC's native previous-frame and
//  next-frame (pass 1f). While paused, a horizontal swipe or drag on the touch surface scrubs (D021): the picture
//  holds while the bar moves the target and the server's still nearest the target shows above the bar (pass 2g),
//  click or Play/Pause lands there and plays, Menu drops it and stays paused;
//  while playing a drag does nothing. The overlay
//  appears on touch and fades after 4 s while playing. Audio and Subtitles are reached with an
//  up swipe from the surface; the panels list VLCKit's actual tracks and switch on selection.
//

import Foundation
import Observation
import UIKit
import VLCKit
import AVFoundation
import AVKit
import CoreMedia

enum RemoteInput {
    case select, playPause, menu, up, down, touch
    case left(source: String)
    case right(source: String)
}

@MainActor
@Observable
final class PlayerModel: NSObject, VLCMediaPlayerDelegate, VLCMediaParserDelegate {
    enum Focus: Equatable { case surface, audio, subtitles }
    enum Panel: Equatable { case audio, subtitles }

    struct TrackItem: Identifiable, Equatable {
        let id: String
        let name: String
        let language: String?
        /// VLC's codec description ("Audio Coding 3 (AC-3)") shortened to the frames' names ("AC-3") by fourcc.
        let codec: String
        let channels: Int
        let selected: Bool

        static func shortCodec(fourcc: UInt32, fallback: String) -> String {
            let chars = (0..<4).map { Character(UnicodeScalar(UInt8((fourcc >> (8 * UInt32($0))) & 0xFF))) }
            let code = String(chars).trimmingCharacters(in: .whitespaces).lowercased()
            switch code {
            case "a52": return "AC-3"
            case "eac3": return "E-AC-3"
            case "mlpa", "mlp", "trhd": return "TrueHD"
            case "dts": return "DTS"
            case "dtsh": return "DTS-HD"
            case "mp4a": return "AAC"
            case "mpga", "mp3": return "MP3"
            case "flac": return "FLAC"
            case "opus": return "Opus"
            case "pgs": return "PGS"
            case "subt", "srt": return "SRT"
            case "ssa": return "ASS"
            case "dvbs": return "DVB"
            case "cvd", "dvsb", "dvdsub": return "VobSub"
            default: return fallback
            }
        }

        /// "English" from "eng", else VLC's own track name.
        var primary: String {
            if let language, !language.isEmpty {
                if let localized = Locale.current.localizedString(forLanguageCode: language), localized != language {
                    return localized
                }
                if let localized = Locale.current.localizedString(forIdentifier: language), localized != language {
                    return localized
                }
                return name.isEmpty ? language : name
            }
            return name.isEmpty ? id : name
        }

        var layout: String {
            switch channels {
            case 8: return "7.1"
            case 7: return "6.1"
            case 6: return "5.1"
            case 2: return "2.0"
            case 1: return "1.0"
            case 0: return ""
            default: return "\(channels) ch"
            }
        }
    }

    static let overlayFade: Duration = .seconds(4)
    static let pillLife: Duration = .milliseconds(900)
    static let skipBack = 10
    static let skipForward = 30

    let request: PlayRequest
    let onDismiss: () -> Void
    @ObservationIgnored private let library: VLCLibrary
    @ObservationIgnored let player: VLCMediaPlayer

    private(set) var stateName = "Opening"
    private(set) var isPlaying = false
    private(set) var timeMs = 0
    private(set) var lengthMs = 0
    private(set) var overlayVisible = true
    private(set) var focus: Focus = .surface
    private(set) var panel: Panel?
    private(set) var panelIndex = 0
    private(set) var skipPill: (text: String, forward: Bool)?
    private(set) var framePill: String?
    private(set) var errorText: String?
    private(set) var audioTracks: [TrackItem] = []
    private(set) var textTracks: [TrackItem] = []

    @ObservationIgnored private var hideTask: Task<Void, Never>?
    @ObservationIgnored private var skipTask: Task<Void, Never>?
    @ObservationIgnored private var frameTask: Task<Void, Never>?
    @ObservationIgnored private var hasPlayed = false

    /// A touch-surface scrub (D021), taken only while paused: the position the picture is held at, and the target the
    /// thumb has moved to. Nothing seeks until it lands; Menu drops it and the film stays paused where it was.
    struct Scrub: Equatable {
        let startMs: Int
        var targetMs: Int
    }

    /// One full width of the touch surface moves the target by this share of the running time.
    static let scrubSpan = 0.25

    private(set) var scrub: Scrub?
    @ObservationIgnored private var scrubBaseMs = 0
    /// Pass 2g: the server's timeline stills for this file, when the detail screen had an index for
    /// it. Set once, before playback starts; the strip itself is observable.
    @ObservationIgnored private(set) var thumbStrip: ThumbStrip?
    /// A paused drag that has not moved the target yet: no scrub shows until it does.
    @ObservationIgnored private var dragStartMs: Int?
    @ObservationIgnored private var dismissed = false

    // Display matching (D016): the parse-before-play step, the display request and its observers.
    @ObservationIgnored private weak var drawableView: UIView?
    @ObservationIgnored private var parser: VLCMediaParser?
    @ObservationIgnored private var pendingMedia: VLCMedia?
    @ObservationIgnored private var playbackStarted = false
    @ObservationIgnored private var parseFallbackTask: Task<Void, Never>?
    @ObservationIgnored private var modeObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var displayLogTask: Task<Void, Never>?
    @ObservationIgnored private var displayRequestPending = false   // parse gave no frame rate: use the player's video track

    init(request: PlayRequest, onDismiss: @escaping () -> Void) {
        self.request = request
        self.onDismiss = onDismiss
        library = VLCLibrary.shared()
        var loggers: [any VLCLogging] = []
        if let file = EvidenceLog.fileLogger() { loggers.append(file) }
        let console = VLCConsoleLogger()
        console.level = .info
        loggers.append(console)
        library.loggers = loggers
        player = VLCMediaPlayer(library: library)
        super.init()
        player.delegate = self
        EvidenceLog.line("[player] request \(request.title) — \(request.subtitle) — \(request.url.absoluteString)")
        EvidenceLog.line("[player] file \(request.file.path) \(request.file.resolution ?? "?") hdr=\(request.file.hdr) video=\(request.file.videoCodec ?? "?") audio=\(request.file.audioTracks.map { "\($0.codec) \($0.layout)" }.joined(separator: ", "))")
        if let thumbs = request.thumbs {
            thumbStrip = ThumbStrip(thumbs)
        } else {
            EvidenceLog.line("[thumbs] no index for this file; the scrub shows no thumbnail")
        }
    }

    // MARK: lifecycle

    func attach(drawable: UIView) {
        player.drawable = drawable
        guard let media = VLCMedia(url: request.url) else {
            errorText = "VLCKit could not create a media object for \(request.url.absoluteString)"
            EvidenceLog.line("[player] \(errorText!)")
            return
        }
        // D014: over HTTP the access is not fast-seekable, so VLC's default mkv demuxer treats the file's
        // Cues as untrusted and prerolls every seek from the last keyframe it has read. The trusted-cues
        // submodule seeks to the cue before the target instead. MKV only; every other container is untouched.
        if request.file.path.lowercased().hasSuffix(".mkv") {
            media.addOption(":demux=mkv_trusted")
        }
        drawableView = drawable
        pendingMedia = media
        // D016: ask tvOS for the stream's frame rate and dynamic range before playback. The server does not
        // report a frame rate, so VLCKit parses the stream header first (one short read over the LAN); the
        // dynamic range comes from the server's hdr flag. If the parse fails or exceeds 5 s, playback starts anyway.
        EvidenceLog.line("[display] before: \(displayState())")
        let parser = VLCMediaParser(library: library, timeout: 5_000_000)   // libvlc_parser_cfg.timeout is in microseconds
        parser.delegate = self
        self.parser = parser
        parseFallbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard let self, !Task.isCancelled, !self.playbackStarted else { return }
            EvidenceLog.line("[display] parse did not finish in 6 s; playing without a display request")
            self.startPlayback()
        }
        if parser.queue(media, options: [.parse]) != 0 {
            EvidenceLog.line("[display] parse could not be queued; playing without a display request")
            startPlayback()
        }
    }

    private func startPlayback() {
        guard !playbackStarted, let media = pendingMedia else { return }
        playbackStarted = true
        parseFallbackTask?.cancel()
        player.media = media
        player.play()
        EvidenceLog.line("[player] play() called")
        bumpOverlay()
    }

    // MARK: display matching (D016)

    private var displayWindow: UIWindow? {
        drawableView?.window ?? UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
    }

    private func displayState() -> String {
        let screen = UIScreen.main
        var s = "maxFPS=\(screen.maximumFramesPerSecond) edrHeadroom=\(String(format: "%.2f", screen.currentEDRHeadroom))/\(String(format: "%.2f", screen.potentialEDRHeadroom)) gamut=\(screen.traitCollection.displayGamut.rawValue)"
        if let dm = displayWindow?.avDisplayManager {
            s += " matchingEnabled=\(dm.isDisplayCriteriaMatchingEnabled) switchInProgress=\(dm.isDisplayModeSwitchInProgress) criteria=\(dm.preferredDisplayCriteria == nil ? "nil" : "set")"
        } else {
            s += " (no window yet)"
        }
        return s
    }

    private func requestDisplayMode(for media: VLCMedia) {
        guard let track = media.tracksInformation.first(where: { $0.type == .video }), let video = track.video else {
            EvidenceLog.line("[display] no video track in the parsed media; will use the player's video track")
            displayRequestPending = true; return
        }
        let fps = video.frameRateDenominator > 0 ? Double(video.frameRate) / Double(video.frameRateDenominator) : Double(video.frameRate)
        guard fps > 0 else {
            // VLC's Matroska demuxer does not put a usable frame rate on the parsed ES (matroska_segment_parse.cpp:512-513);
            // the player's own video track carries the one the packetizer reads from the stream (SPS VUI), ~0.1 s after play().
            EvidenceLog.line("[display] frame rate unknown from the parse (\(video.frameRate)/\(video.frameRateDenominator)); will use the player's video track once it reports one")
            displayRequestPending = true; return
        }
        requestDisplayMode(fps: fps, width: Int(video.width), height: Int(video.height), codecName: VLCMedia.codecName(forFourCC: track.codec, trackType: .video), source: "parsed media")
    }

    private func requestDisplayModeFromPlayerIfPending() {
        guard displayRequestPending, let track = player.videoTracks.first, let v = track.video, v.frameRate > 0 else { return }
        displayRequestPending = false
        let fps = v.frameRateDenominator > 0 ? Double(v.frameRate) / Double(v.frameRateDenominator) : Double(v.frameRate)
        requestDisplayMode(fps: fps, width: Int(v.width), height: Int(v.height), codecName: track.codecName(), source: "player video track")
    }

    private func requestDisplayMode(fps: Double, width: Int, height: Int, codecName: String, source: String) {
        let hdr = request.file.hdr
        let isH264 = codecName.localizedCaseInsensitiveContains("H264") || codecName.localizedCaseInsensitiveContains("H.264")
        let codecType: CMVideoCodecType = isH264 ? kCMVideoCodecType_H264 : kCMVideoCodecType_HEVC
        let ext: [CFString: Any] = hdr
            ? [kCMFormatDescriptionExtension_ColorPrimaries: kCMFormatDescriptionColorPrimaries_ITU_R_2020,
               kCMFormatDescriptionExtension_TransferFunction: kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ,
               kCMFormatDescriptionExtension_YCbCrMatrix: kCMFormatDescriptionYCbCrMatrix_ITU_R_2020]
            : [kCMFormatDescriptionExtension_ColorPrimaries: kCMFormatDescriptionColorPrimaries_ITU_R_709_2,
               kCMFormatDescriptionExtension_TransferFunction: kCMFormatDescriptionTransferFunction_ITU_R_709_2,
               kCMFormatDescriptionExtension_YCbCrMatrix: kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2]
        var desc: CMVideoFormatDescription?
        let status = CMVideoFormatDescriptionCreate(allocator: kCFAllocatorDefault, codecType: codecType, width: Int32(width), height: Int32(height), extensions: ext as CFDictionary, formatDescriptionOut: &desc)
        guard status == noErr, let desc else { EvidenceLog.line("[display] format description failed (\(status)); no display request"); return }
        guard let window = displayWindow else { EvidenceLog.line("[display] no window; no display request"); return }
        let criteria = AVDisplayCriteria(refreshRate: Float(fps), formatDescription: desc)
        observeModeSwitches()
        window.avDisplayManager.preferredDisplayCriteria = criteria
        EvidenceLog.line("[display] request (from \(source)) refresh=\(String(format: "%.3f", fps)) range=\(hdr ? "HDR10 (PQ, BT.2020)" : "SDR (BT.709)") codec=\(codecName) \(width)x\(height) — after set: \(displayState())")
        displayLogTask?.cancel()
        displayLogTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, !Task.isCancelled else { return }
            EvidenceLog.line("[display] 4 s after request: \(self.displayState())")
        }
    }

    private func observeModeSwitches() {
        guard modeObservers.isEmpty else { return }
        let names: [(Notification.Name, String)] = [(.AVDisplayManagerModeSwitchStart, "start"), (.AVDisplayManagerModeSwitchEnd, "end"), (.AVDisplayManagerModeSwitchSettingsChanged, "settings changed")]
        for (name, label) in names {
            modeObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    EvidenceLog.line("[display] mode switch \(label): \(self.displayState())")
                }
            })
        }
    }

    private func clearDisplayRequest() {
        displayLogTask?.cancel()
        if let dm = displayWindow?.avDisplayManager, dm.preferredDisplayCriteria != nil {
            dm.preferredDisplayCriteria = nil
            EvidenceLog.line("[display] cleared: \(displayState())")
        }
        for observer in modeObservers { NotificationCenter.default.removeObserver(observer) }
        modeObservers.removeAll()
    }

    // MARK: VLCMediaParserDelegate (D016)

    nonisolated func mediaFinishedParsing(_ media: VLCMedia, with status: VLCMediaParsedStatus) {
        Task { @MainActor in
            EvidenceLog.line("[display] parse finished with status \(status.rawValue)")
            if status == .done { self.requestDisplayMode(for: media) }
            else { EvidenceLog.line("[display] no display request (parse status \(status.rawValue))") }
            self.startPlayback()
        }
    }

    func dismiss() {
        guard !dismissed else { return }
        dismissed = true
        hideTask?.cancel(); skipTask?.cancel(); frameTask?.cancel()
        parseFallbackTask?.cancel(); parser?.cancelAllParsing()
        EvidenceLog.line("[player] dismiss at \(timeMs) ms, state \(stateName)")
        clearDisplayRequest()
        player.stop()
        player.drawable = nil
        onDismiss()
    }

    // MARK: remote

    func handle(_ input: RemoteInput) {
        if scrub != nil {
            // D021: while a scrub is up, click or Play/Pause lands and Menu cancels; nothing else acts.
            switch input {
            case .select: landScrub("select")
            case .playPause: landScrub("playPause")
            case .menu: cancelScrub()
            case .touch: break
            default: EvidenceLog.line("[scrub] \(input) ignored while scrubbing")
            }
            return
        }
        if case .touch = input {} else { dragStartMs = nil }   // a press ends a drag that has not moved the target
        switch input {
        case .touch:
            bumpOverlay()
        case .select:
            if let panel {
                pick(panelIndex, in: panel)
            } else if focus == .audio {
                open(.audio)
            } else if focus == .subtitles {
                open(.subtitles)
            } else {
                togglePlayPause(source: "select")
            }
        case .playPause:
            togglePlayPause(source: "playPause button")
        case .menu:
            if panel != nil {
                closePanel()
            } else {
                dismiss()
            }
        case let .left(source):
            if panel != nil { return }
            if focus != .surface { focus = .audio; bumpOverlay(); return }
            if isPlaying { skip(-Self.skipBack, source: source) }
            else if source == "click" { frameStep(-1) }
            else { EvidenceLog.line("[player] left \(source) while paused: no action (frame step is on click)") }
        case let .right(source):
            if panel != nil { return }
            if focus != .surface { focus = .subtitles; bumpOverlay(); return }
            if isPlaying { skip(Self.skipForward, source: source) }
            else if source == "click" { frameStep(1) }
            else { EvidenceLog.line("[player] right \(source) while paused: no action (frame step is on click)") }
        case .up:
            if let panel {
                panelIndex = max(0, panelIndex - 1)
                EvidenceLog.line("[player] \(panel) panel row \(panelIndex)")
            } else if focus == .surface {
                if overlayVisible { focus = .audio }
                bumpOverlay()
            }
        case .down:
            if let panel {
                panelIndex = min(panelCount(panel) - 1, panelIndex + 1)
                EvidenceLog.line("[player] \(panel) panel row \(panelIndex)")
            } else if focus != .surface {
                focus = .surface
                bumpOverlay()
            }
        }
    }

    // MARK: scrub (D021)

    /// VLC's `vlc_tick_now()` clock (CLOCK_MONOTONIC, µs), so a [scrub] line lines up with VLC's trace.
    static func tick() -> UInt64 { clock_gettime_nsec_np(CLOCK_MONOTONIC) / 1000 }

    /// A horizontal swipe or drag began. Only while paused (while playing a drag does nothing); on a scrub that is
    /// already up it moves on from the target.
    func scrubBegan() {
        guard !isPlaying else {
            EvidenceLog.line("[scrub] drag while playing: no action tick=\(Self.tick())")
            return
        }
        guard panel == nil, errorText == nil, lengthMs > 0, playbackStarted, !dismissed else {
            EvidenceLog.line("[scrub] drag not taken: panel=\(panel != nil) error=\(errorText != nil) length=\(lengthMs) ms")
            return
        }
        if let scrub {
            scrubBaseMs = scrub.targetMs
            EvidenceLog.line("[scrub] drag again from target \(scrub.targetMs) ms tick=\(Self.tick())")
            return
        }
        scrubBaseMs = Int(player.time.intValue)
        dragStartMs = scrubBaseMs
    }

    /// The thumb's horizontal travel since the drag began, as a share of the surface's width. The scrub appears
    /// once the target first moves, so a touch that comes with a click shows no bar and holds back no click.
    func scrubMoved(fraction: Double) {
        let end = max(0, lengthMs - 1000)   // a target at the very end would stop the input and close the player
        let target = min(max(0, scrubBaseMs + Int(fraction * Self.scrubSpan * Double(lengthMs))), end)
        if var s = scrub {
            guard target != s.targetMs else { return }
            s.targetMs = target
            scrub = s
            thumbStrip?.show(ms: target)
        } else if let start = dragStartMs, target != start {
            dragStartMs = nil
            scrub = Scrub(startMs: start, targetMs: target)
            focus = .surface
            skipPill = nil
            framePill = nil
            EvidenceLog.line("[scrub] begin at \(start) ms tick=\(Self.tick())")
            thumbStrip?.show(ms: target)
        }
    }

    /// The thumb left the surface. Nothing seeks: the bar keeps the target until the scrub lands or is cancelled.
    func scrubLifted() {
        dragStartMs = nil
        guard let s = scrub else { return }
        EvidenceLog.line("[scrub] lift target=\(s.targetMs) ms tick=\(Self.tick())")
    }

    /// Click or Play/Pause: play, then the scrub's one seek, made once playback runs — a seek while paused reads
    /// ahead of its target and plays from there (pass 2a).
    private func landScrub(_ source: String) {
        guard let s = scrub, !dismissed else { return }
        EvidenceLog.line("[scrub] land \(source) from \(s.startMs) ms at \(s.targetMs) ms tick=\(Self.tick())")
        scrub = nil
        thumbStrip?.clear()
        player.play()
        if s.targetMs != s.startMs {
            player.time = VLCTime(int: Int32(s.targetMs))
            EvidenceLog.line("[scrub] seek \(s.targetMs) ms after play tick=\(Self.tick())")
        }
        bumpOverlay()
        logAfterScrub("land", expected: s.targetMs)
    }

    /// Menu: nothing has seeked, so the film is still paused where the drag began.
    private func cancelScrub() {
        guard let s = scrub else { return }
        EvidenceLog.line("[scrub] cancel menu at \(s.targetMs) ms, back to \(s.startMs) ms tick=\(Self.tick())")
        scrub = nil
        thumbStrip?.clear()
        bumpOverlay()
        logAfterScrub("cancel", expected: s.startMs)
    }

    private func logAfterScrub(_ what: String, expected: Int) {
        Task { @MainActor [weak self] in
            for (wait, mark) in [(1, 1), (2, 3)] {
                try? await Task.sleep(for: .seconds(wait))
                guard let self, !self.dismissed else { return }
                self.timeMs = Int(self.player.time.intValue)
                EvidenceLog.line("[scrub] \(what) +\(mark) s time=\(self.timeMs) ms (expected \(expected) ms) state \(self.stateName)")
            }
        }
    }

    private func togglePlayPause(source: String) {
        framePill = nil
        if isPlaying {
            EvidenceLog.line("[player] pause (\(source)) at \(player.time.intValue) ms")
            player.pause()
        } else {
            EvidenceLog.line("[player] play (\(source)) at \(player.time.intValue) ms")
            player.play()
        }
        bumpOverlay()
    }

    private func skip(_ seconds: Int, source: String) {
        let before = Int(player.time.intValue)
        let length = lengthMs > 0 ? lengthMs : Int.max
        let target = min(max(0, before + seconds * 1000), length)
        player.time = VLCTime(int: Int32(target))
        EvidenceLog.line("[skip] \(seconds > 0 ? "+" : "")\(seconds) s (\(source)) before=\(before) ms target=\(target) ms")
        skipPill = (seconds > 0 ? "+\(seconds) s" : "−\(-seconds) s", seconds > 0)
        skipTask?.cancel()
        skipTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled else { return }
            self.timeMs = Int(self.player.time.intValue)
            EvidenceLog.line("[skip] after=\(self.timeMs) ms")
            try? await Task.sleep(for: Self.pillLife - .milliseconds(500))
            guard !Task.isCancelled else { return }
            self.skipPill = nil
        }
        bumpOverlay()
    }

    private func frameStep(_ direction: Int) {
        guard !isPlaying else { return }
        let before = Int(player.time.intValue)
        if direction > 0 {
            EvidenceLog.line("[framestep] +1 gotoNextFrame before=\(before) ms")
            player.gotoNextFrame()
            framePill = "Frame +1"
            frameTask?.cancel()
            frameTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(400))
                guard let self, !Task.isCancelled else { return }
                self.timeMs = Int(self.player.time.intValue)
                EvidenceLog.line("[framestep] +1 after(400 ms)=\(self.timeMs) ms")
            }
        } else {
            EvidenceLog.line("[framestep] −1 gotoPreviousFrame before=\(before) ms")
            player.gotoPreviousFrame()
            framePill = "Frame −1"
            frameTask?.cancel()
            frameTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(400))
                guard let self, !Task.isCancelled else { return }
                self.timeMs = Int(self.player.time.intValue)
                EvidenceLog.line("[framestep] −1 after(400 ms)=\(self.timeMs) ms")
            }
        }
        scheduleFramePillClear()
        bumpOverlay()
    }

    private func scheduleFramePillClear() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.pillLife)
            self?.framePill = nil
        }
    }

    // MARK: overlay

    func bumpOverlay() {
        overlayVisible = true
        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.overlayFade)
            guard let self, !Task.isCancelled else { return }
            if self.isPlaying, self.panel == nil {
                self.overlayVisible = false
                self.focus = .surface
            }
        }
    }

    // MARK: tracks (frames 11, 12)

    private func item(_ t: VLCMediaPlayer.Track) -> TrackItem {
        TrackItem(id: t.trackId, name: t.trackName, language: t.language,
                  codec: TrackItem.shortCodec(fourcc: t.fourcc, fallback: t.codecName()),
                  channels: Int(t.audio?.channelsNumber ?? 0), selected: t.isSelected)
    }

    private func refreshTracks() {
        audioTracks = player.audioTracks.map(item)
        textTracks = player.textTracks.map(item)
    }

    var subtitleRows: [TrackItem] {
        [TrackItem(id: "off", name: "Off", language: nil, codec: "", channels: 0, selected: !textTracks.contains { $0.selected })] + textTracks
    }

    var currentSubtitleName: String {
        textTracks.first { $0.selected }?.primary ?? "Off"
    }

    private func panelCount(_ panel: Panel) -> Int {
        panel == .audio ? max(1, audioTracks.count) : subtitleRows.count
    }

    private func open(_ panel: Panel) {
        refreshTracks()
        self.panel = panel
        switch panel {
        case .audio: panelIndex = audioTracks.firstIndex { $0.selected } ?? 0
        case .subtitles: panelIndex = subtitleRows.firstIndex { $0.selected } ?? 0
        }
        let list = panel == .audio ? audioTracks : textTracks
        EvidenceLog.line("[\(panel)] panel opened: \(list.map { "\($0.id) \($0.primary) \($0.codec) \($0.layout)\($0.selected ? " ✓" : "")" }.joined(separator: " | "))")
        bumpOverlay()
    }

    private func closePanel() {
        EvidenceLog.line("[player] panel closed")
        panel = nil
        bumpOverlay()
    }

    private func pick(_ index: Int, in panel: Panel) {
        switch panel {
        case .audio:
            let tracks = player.audioTracks
            guard tracks.indices.contains(index) else { return }
            let track = tracks[index]
            EvidenceLog.line("[audio] select \(track.trackId) \(track.trackName) \(track.codecName()) ch=\(track.audio?.channelsNumber ?? 0)")
            track.isSelectedExclusively = true
        case .subtitles:
            if index == 0 {
                EvidenceLog.line("[subtitles] off (deselectAllTextTracks)")
                player.deselectAllTextTracks()
            } else {
                let tracks = player.textTracks
                guard tracks.indices.contains(index - 1) else { return }
                let track = tracks[index - 1]
                EvidenceLog.line("[subtitles] select \(track.trackId) \(track.trackName) \(track.codecName())")
                track.isSelectedExclusively = true
            }
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self else { return }
            self.refreshTracks()
            EvidenceLog.line("[\(panel)] now selected: audio=\(self.audioTracks.filter(\.selected).map(\.id)) text=\(self.textTracks.filter(\.selected).map(\.id))")
        }
        closePanel()
    }

    // MARK: VLCMediaPlayerDelegate (VLCKit calls these off the main actor)

    nonisolated func mediaPlayerStateChanged(_ newState: VLCMediaPlayerState) {
        Task { @MainActor in self.stateChanged(newState) }
    }

    nonisolated func mediaPlayerTimeChanged(_ aNotification: Notification) {
        Task { @MainActor in self.timeChanged() }
    }

    nonisolated func mediaPlayerLengthChanged(_ length: Int64) {
        Task { @MainActor in
            self.lengthMs = Int(length)
            EvidenceLog.line("[player] length \(length) ms")
        }
    }

    nonisolated func mediaPlayerBufferingChanged(_ progress: Float) {
        Task { @MainActor in
            if progress == 0 || progress >= 1 { EvidenceLog.line("[player] buffering \(progress)") }
        }
    }

    nonisolated func mediaPlayerTrackAdded(_ trackId: String, with trackType: VLCMedia.TrackType) {
        Task { @MainActor in
            self.refreshTracks()
            EvidenceLog.line("[player] track added \(trackId) type=\(trackType.rawValue)")
            self.requestDisplayModeFromPlayerIfPending()
        }
    }

    nonisolated func mediaPlayerTrackUpdated(_ trackId: String, with trackType: VLCMedia.TrackType) {
        Task { @MainActor in self.refreshTracks(); self.requestDisplayModeFromPlayerIfPending() }
    }

    nonisolated func mediaPlayerTrackSelected(_ trackType: VLCMedia.TrackType, selectedId: String, unselectedId: String) {
        Task { @MainActor in
            self.refreshTracks()
            EvidenceLog.line("[player] track selected type=\(trackType.rawValue) selected=\(selectedId) unselected=\(unselectedId)")
        }
    }

    nonisolated func mediaPlayer(_ player: VLCMediaPlayer, nextFrameSteppedWith result: VLCMediaPlayerFrameStepResult) {
        Task { @MainActor in
            self.timeMs = Int(self.player.time.intValue)
            EvidenceLog.line("[framestep] nextFrameStepped result=\(result.rawValue) time=\(self.timeMs) ms")
        }
    }

    nonisolated func mediaPlayer(_ player: VLCMediaPlayer, previousFrameSteppedWith result: VLCMediaPlayerFrameStepResult) {
        Task { @MainActor in
            self.timeMs = Int(self.player.time.intValue)
            EvidenceLog.line("[framestep] previousFrameStepped result=\(result.rawValue) time=\(self.timeMs) ms")
        }
    }

    private func stateChanged(_ state: VLCMediaPlayerState) {
        stateName = VLCMediaPlayerStateToString(state).replacingOccurrences(of: "VLCMediaPlayerState", with: "")
        isPlaying = state == .playing
        EvidenceLog.line("[player] state \(stateName) at \(player.time.intValue) ms")
        switch state {
        case .playing:
            hasPlayed = true
            refreshTracks()
            bumpOverlay()
        case .paused:
            bumpOverlay()
        case .error:
            let detail = VLCLibrary.currentErrorMessage ?? "no detail from VLC"
            errorText = "Playback failed: \(detail)"
            EvidenceLog.line("[player] \(errorText!)")
            overlayVisible = true
        case .stopped:
            if hasPlayed { dismiss() }
        default:
            break
        }
    }

    private func timeChanged() {
        timeMs = Int(player.time.intValue)
        if lengthMs == 0, let length = player.media?.length.intValue, length > 0 { lengthMs = Int(length) }
    }

    // MARK: overlay values (frame 10)

    var elapsedText: String { Format.clock(Double(timeMs) / 1000) }
    var remainingText: String { "−" + Format.clock(Double(max(0, lengthMs - timeMs)) / 1000) }
    var progress: Double { lengthMs > 0 ? min(1, max(0, Double(timeMs) / Double(lengthMs))) : 0 }
}
