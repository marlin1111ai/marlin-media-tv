//
//  MusicPlayer.swift
//  Marlin Media TV
//
//  Marlin Music's player (2026-10-04): VLCKit with no picture, the same engine as the films — some
//  of the library is in formats tvOS's own player does not read. One player lives from the app's
//  launch until it closes; an album's tracks are its queue, and each track's end starts the next.
//  The Now Playing screen is drawn from this object's state, and the music plays on while the
//  owner browses. **Nothing is saved to the server for music.**
//
//  VLCKit plays one track at a time. A change of track while one is playing stops the player first
//  and loads the new one from the `Stopped` state that follows; a `Stopped` state nobody asked for
//  is the track running out.
//

import Foundation
import Observation
import VLCKit

/// One track of the queue, as Now Playing shows it.
struct QueuedTrack: Hashable {
    let title: String
    let artist: String
    let album: String
    let year: String
    let cover: String?
    let spec: String
    let url: URL
    /// The server's length for the track, in seconds, until the player reports its own.
    let duration: Double
}

@MainActor
@Observable
final class MusicPlayer: NSObject, VLCMediaPlayerDelegate {
    /// Previous goes to the track's start after this many seconds, and to the track before until then.
    static let restartAfterS = 3.0

    private(set) var queue: [QueuedTrack] = []
    private(set) var albumId = 0
    private(set) var index = -1
    private(set) var isPaused = false
    private(set) var positionS = 0.0
    private(set) var lengthS = 0.0
    /// The last track that could not be played, said in full on the album and Now Playing screens.
    private(set) var errorText: String?

    @ObservationIgnored private let player: VLCMediaPlayer
    /// The player holds a track, from `load` until the `Stopped` state that ends it.
    @ObservationIgnored private var engaged = false
    /// The track waiting for the one before it to stop.
    @ObservationIgnored private var pending: Int?
    /// The music was stopped on purpose: the `Stopped` state that follows starts nothing.
    @ObservationIgnored private var halted = false

    var isActive: Bool { !queue.isEmpty }
    var track: QueuedTrack? { queue.indices.contains(index) ? queue[index] : nil }
    var nextTitle: String? { queue.indices.contains(index + 1) ? queue[index + 1].title : nil }
    var progress: Double { lengthS > 0 ? min(1, max(0, positionS / lengthS)) : 0 }

    override init() {
        let library = VLCLibrary.shared()
        var loggers: [any VLCLogging] = []
        if let file = EvidenceLog.fileLogger() { loggers.append(file) }
        let console = VLCConsoleLogger()
        console.level = .info
        loggers.append(console)
        library.loggers = loggers
        player = VLCMediaPlayer(library: library)
        super.init()
        player.delegate = self
    }

    // MARK: the queue

    /// The album's tracks as the queue, starting at the track picked.
    func start(_ tracks: [QueuedTrack], at index: Int, albumId: Int) {
        guard tracks.indices.contains(index) else { return }
        queue = tracks
        self.albumId = albumId
        errorText = nil
        EvidenceLog.line("[music] album \(albumId): \(tracks.count) tracks, from track \(index + 1)")
        go(to: index)
    }

    private func go(to newIndex: Int) {
        index = newIndex
        positionS = 0
        lengthS = queue[newIndex].duration
        isPaused = false
        halted = false
        if engaged {
            // The track before is still in the player: stop it, and load this one when it has.
            let stopAlreadyAsked = pending != nil
            pending = newIndex
            if !stopAlreadyAsked { player.stop() }
        } else {
            load(newIndex)
        }
    }

    private func load(_ i: Int) {
        guard let media = VLCMedia(url: queue[i].url) else {
            errorText = "Couldn't play track \(i + 1): VLCKit could not create a media object for \(queue[i].url.absoluteString)"
            EvidenceLog.line("[music] \(errorText!)")
            return
        }
        engaged = true
        player.media = media
        player.play()
        EvidenceLog.line("[music] track \(i + 1) of \(queue.count): \(queue[i].url.absoluteString)")
    }

    private func clear() {
        queue = []
        index = -1
        albumId = 0
        positionS = 0
        lengthS = 0
        isPaused = false
        pending = nil
    }

    // MARK: the remote and the buttons

    func toggle() {
        guard isActive, pending == nil else { return }
        EvidenceLog.line("[music] \(isPaused ? "play" : "pause") track \(index + 1) at \(Int(positionS)) s")
        if isPaused { player.play() } else { player.pause() }
    }

    func next() {
        guard isActive, index + 1 < queue.count else { return }
        go(to: index + 1)
    }

    func previous() {
        guard isActive else { return }
        if positionS > Self.restartAfterS || index == 0 {
            EvidenceLog.line("[music] back to the start of track \(index + 1)")
            player.time = VLCTime(int: 0)
            positionS = 0
        } else {
            go(to: index - 1)
        }
    }

    /// The app is leaving the screen: the music goes with it.
    func stop(why: String) {
        guard isActive else { return }
        EvidenceLog.line("[music] stopped at track \(index + 1), \(Int(positionS)) s: \(why)")
        clear()
        if engaged {
            halted = true
            player.stop()
        }
    }

    // MARK: VLCMediaPlayerDelegate (VLCKit calls these off the main actor)

    nonisolated func mediaPlayerStateChanged(_ newState: VLCMediaPlayerState) {
        Task { @MainActor in self.stateChanged(newState) }
    }

    nonisolated func mediaPlayerTimeChanged(_ aNotification: Notification) {
        Task { @MainActor in
            // A track on its way out still reports its time; it is not the new track's.
            guard self.isActive, self.pending == nil else { return }
            self.positionS = Double(self.player.time.intValue) / 1000
        }
    }

    nonisolated func mediaPlayerLengthChanged(_ length: Int64) {
        Task { @MainActor in
            guard self.isActive, self.pending == nil, length > 0 else { return }
            self.lengthS = Double(length) / 1000
        }
    }

    private func stateChanged(_ state: VLCMediaPlayerState) {
        let name = VLCMediaPlayerStateToString(state).replacingOccurrences(of: "VLCMediaPlayerState", with: "")
        EvidenceLog.line("[music] state \(name) track \(index + 1) at \(player.time.intValue) ms")
        switch state {
        case .playing:
            if pending == nil { isPaused = false }
        case .paused:
            if pending == nil { isPaused = true }
        case .error:
            let detail = VLCLibrary.currentErrorMessage ?? "no detail from VLC"
            errorText = "Couldn't play track \(index + 1): \(detail)"
            EvidenceLog.line("[music] \(errorText!)")
        case .stopped:
            engaged = false
            if halted {
                halted = false
            } else if let next = pending {
                pending = nil
                if queue.indices.contains(next) { load(next) }
            } else if isActive {
                // Nobody asked for this stop: the track has run out.
                if index + 1 < queue.count {
                    index += 1
                    positionS = 0
                    lengthS = queue[index].duration
                    load(index)
                } else {
                    EvidenceLog.line("[music] the album has ended")
                    clear()
                }
            }
        default:
            break
        }
    }
}
