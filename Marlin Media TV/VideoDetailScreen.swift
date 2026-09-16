//
//  VideoDetailScreen.swift
//  Marlin Media TV
//
//  Frame 09: thumbnail, name, duration, resolution/codec line, Play.
//
//  Pass 2 (D026): the same behaviour as the movie detail — the watched pill, "Resume · N min left"
//  with its in-button bar, "Start over" and "Mark watched" / "Mark unwatched". A video has one
//  file, so there is no picker and nothing to follow.
//
//  Pass 2b (D032): the screen re-reads the video every time the player closes.
//
//  Not yet run on a device: this server has no videos (pass 2, least-sure 4).
//

import SwiftUI

struct VideoDetailScreen: View {
    let video: Video
    let api: APIClient
    /// D032: ContentView's count of player closes.
    let playerClosed: Int
    let play: (PlayRequest) -> Void

    @State private var playError: String?
    @State private var thumbs: FileThumbs?
    /// The video as the server last gave it — re-read after a playback write (D026, D032).
    @State private var current: Video?
    @FocusState private var playFocused: Bool

    private var shown: Video { current ?? video }
    private var savedPosition: Double { shown.file.playback.position }
    private var isWatched: Bool { shown.file.playback.watched }
    private var timeLeft: String? { Format.timeLeft(position: savedPosition, duration: shown.file.duration) }
    private var resumeShare: Double? { Format.share(position: savedPosition, duration: shown.file.duration) }

    /// Pass 2g: the timeline stills of the one file this screen plays, asked once on open.
    private func loadThumbs() async {
        guard thumbs == nil else { return }
        do {
            thumbs = try await api.thumbs(fileId: shown.file.fileId)
        } catch {
            print("[thumbs] \(shown.title): \((error as? APIError)?.localizedDescription ?? String(describing: error))")
        }
    }

    /// D026/D032: re-read the video (the server has no single-video route, so the list is re-read).
    private func refresh() async {
        do {
            current = try await api.videos().first { $0.id == video.id }
            EvidenceLog.line("[detail] video \(video.id) re-read: position \(shown.file.playback.position) watched \(shown.file.playback.watched)")
        } catch {
            EvidenceLog.line("[detail] could not re-read video \(video.id): \((error as? APIError)?.localizedDescription ?? String(describing: error))")
        }
    }

    private var spec: String {
        var parts = [shown.file.resolutionLabel, shown.file.videoCodec.map(Format.videoCodec)].compactMap { $0 }
        if let audio = shown.file.audioTracks.first { parts.append(Format.audioTrack(audio)) }
        parts.append(Format.size(shown.file.size))
        return parts.joined(separator: " · ")
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Nocturne.videoGround
            ServerImage(path: shown.artwork.backdrop ?? shown.artwork.poster ?? shown.artwork.still) {
                LinearGradient(stops: [.init(color: Color(hex: 0x332E4E), location: 0),
                                       .init(color: Color(hex: 0x1B1D2B), location: 0.6),
                                       .init(color: Nocturne.surface, location: 1)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .frame(width: 1100, height: 619)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Nocturne.neutral700, lineWidth: 1))
            .shadow(color: .black.opacity(0.6), radius: 35, y: 24)
            .padding(.leading, 80)
            .padding(.top, 96)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 18) {
                    Kicker(text: "Video")
                    if isWatched { WatchedPill() }
                }
                Text(shown.title)
                    .font(.nocturne(60, .medium))
                    .kerning(-1.2)
                    .foregroundStyle(Nocturne.accent100)
                    .lineLimit(3)
                    .padding(.top, 20)
                    .accessibilityIdentifier("detail.title")
                Text(Format.clock(shown.file.duration ?? 0))
                    .font(.nocturne(26)).foregroundStyle(Nocturne.neutral300).padding(.top, 24)
                Text(spec)
                    .font(.nocturne(24)).foregroundStyle(Nocturne.neutral500).padding(.top, 8)
                Text("Added \(Format.addedDate(shown.added)) · \(shown.file.directory)")
                    .font(.nocturne(22)).foregroundStyle(Nocturne.neutral600).padding(.top, 8)
                Button { start(resume: true) } label: {
                    if savedPosition > 0 {
                        ResumeButtonLabel(title: "Resume" + (timeLeft.map { " · \($0)" } ?? ""),
                                          share: resumeShare, width: 460)
                    } else {
                        PrimaryButtonLabel(title: "Play", icon: "▶", width: 460)
                    }
                }
                .buttonStyle(BareButtonStyle())
                .focused($playFocused)
                .accessibilityIdentifier("play")
                .padding(.top, 44)
                if savedPosition > 0 {
                    Button(action: pressStartOver) { SecondaryButtonLabel(title: "Start over") }
                        .buttonStyle(BareButtonStyle())
                        .accessibilityIdentifier("startover")
                        .padding(.top, 18)
                }
                Button(action: pressMark) {
                    SecondaryButtonLabel(title: isWatched ? "Mark unwatched" : "Mark watched")
                }
                .buttonStyle(BareButtonStyle())
                .accessibilityIdentifier("mark")
                .padding(.top, 18)
                if let playError {
                    Text(playError).font(.nocturne(22)).foregroundStyle(Nocturne.accent300).padding(.top, 16)
                }
            }
            .frame(width: 580, alignment: .leading)
            .padding(.leading, 1250)
            .padding(.top, 150)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear { playFocused = true }
        .task { await loadThumbs() }
        .onChange(of: playerClosed) { _, _ in
            Task { await refresh() }        // D032
        }
    }

    private func pressStartOver() {
        Task {
            await PlaybackWrite.send(api, fileId: shown.file.fileId, position: 0, why: "start over")
            start(resume: false)
        }
    }

    private func pressMark() {
        let nowWatched = !isWatched
        Task {
            await PlaybackWrite.send(api, fileId: shown.file.fileId, position: 0, watched: nowWatched,
                                     why: nowWatched ? "mark watched" : "mark unwatched")
            await refresh()
        }
    }

    private func start(resume: Bool) {
        guard let request = PlayRequest.video(shown, thumbs: thumbs, resume: resume) else {
            playError = "The server gave no usable stream URL: \(shown.file.stream)"
            return
        }
        play(request)
    }
}
