//
//  VideoDetailScreen.swift
//  Marlin Media TV
//
//  Frame 09: thumbnail, name, duration, resolution/codec line, Play. "Resume" and "Start over"
//  are a later pass (D009).
//

import SwiftUI

struct VideoDetailScreen: View {
    let video: Video
    let api: APIClient
    let play: (PlayRequest) -> Void

    @State private var playError: String?
    @State private var thumbs: FileThumbs?
    @FocusState private var playFocused: Bool

    /// Pass 2g: the timeline stills of the one file this screen plays, asked once on open.
    private func loadThumbs() async {
        guard thumbs == nil else { return }
        do {
            thumbs = try await api.thumbs(fileId: video.file.fileId)
        } catch {
            print("[thumbs] \(video.title): \((error as? APIError)?.localizedDescription ?? String(describing: error))")
        }
    }

    private var spec: String {
        var parts = [video.file.resolutionLabel, video.file.videoCodec.map(Format.videoCodec)].compactMap { $0 }
        if let audio = video.file.audioTracks.first { parts.append(Format.audioTrack(audio)) }
        parts.append(Format.size(video.file.size))
        return parts.joined(separator: " · ")
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Nocturne.videoGround
            ServerImage(path: video.artwork.backdrop ?? video.artwork.poster ?? video.artwork.still) {
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
                Kicker(text: "Video")
                Text(video.title)
                    .font(.nocturne(60, .medium))
                    .kerning(-1.2)
                    .foregroundStyle(Nocturne.accent100)
                    .lineLimit(3)
                    .padding(.top, 20)
                    .accessibilityIdentifier("detail.title")
                Text(Format.clock(video.file.duration ?? 0))
                    .font(.nocturne(26)).foregroundStyle(Nocturne.neutral300).padding(.top, 24)
                Text(spec)
                    .font(.nocturne(24)).foregroundStyle(Nocturne.neutral500).padding(.top, 8)
                Text("Added \(Format.addedDate(video.added)) · \(video.file.directory)")
                    .font(.nocturne(22)).foregroundStyle(Nocturne.neutral600).padding(.top, 8)
                Button {
                    guard let request = PlayRequest.video(video, thumbs: thumbs) else {
                        playError = "The server gave no usable stream URL: \(video.file.stream)"
                        return
                    }
                    play(request)
                } label: {
                    PrimaryButtonLabel(title: "Play", icon: "▶", width: 460)
                }
                .buttonStyle(BareButtonStyle())
                .focused($playFocused)
                .accessibilityIdentifier("play")
                .padding(.top, 44)
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
    }
}
