//
//  MovieDetailScreen.swift
//  Marlin Media TV
//
//  Frame 06 (movie detail) and frame 07 (edition picker). The deferred items — the watched
//  pill, "Resume · N min left", "Start over", "Mark unwatched", progress — are not here; the
//  Play button reads "Play" only. Play on a one-edition movie plays it; on a multi-edition
//  movie it opens the picker. Selecting an edition row also plays that edition (prototype).
//

import SwiftUI

struct MovieDetailScreen: View {
    let movie: Movie
    let play: (PlayRequest) -> Void

    @State private var pickerOpen = false
    @State private var playError: String?
    @FocusState private var playFocused: Bool
    @FocusState private var pickerFocus: Int?

    var body: some View {
        ZStack(alignment: .topLeading) {
            DetailBackdrop(path: movie.artwork.backdrop)
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    top
                    editions
                        .padding(.top, 56)
                }
                .padding(.horizontal, 80)
                .padding(.top, 78)
                .padding(.bottom, 80)
            }
            .scrollClipDisabled()
            if pickerOpen {
                picker.zIndex(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear { playFocused = true }
        .onChange(of: pickerOpen) { _, open in
            if open {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    pickerFocus = movie.editions.first?.id
                }
            } else {
                playFocused = true
            }
        }
    }

    private var top: some View {
        HStack(alignment: .top, spacing: 56) {
            ServerImage(path: movie.artwork.poster) { InitialTile(title: movie.title, fontSize: 120) }
                .frame(width: 300, height: 450)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Nocturne.neutral700, lineWidth: 1))
                .shadow(color: .black.opacity(0.6), radius: 30, y: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(movie.title)
                    .font(.nocturne(82, .medium))
                    .kerning(-1.6)
                    .foregroundStyle(Nocturne.accent100)
                    .lineLimit(2)
                    .accessibilityIdentifier("detail.title")
                HStack(spacing: 20) {
                    if let year = movie.year { Text(String(year)) }
                    Dot()
                    Text(Format.runtime(movie.runtime))
                    if let rating = Format.rating(movie.rating) {
                        Dot()
                        Text(rating)
                            .font(.nocturne(19))
                            .kerning(1.1)
                            .padding(.vertical, 6).padding(.horizontal, 12)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Nocturne.neutral600, lineWidth: 1))
                    }
                    if !movie.genres.isEmpty {
                        Dot()
                        Text(Format.genres(movie.genres))
                    }
                }
                .font(.nocturne(24))
                .foregroundStyle(Nocturne.neutral300)
                .padding(.top, 22)
                if let overview = movie.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.nocturne(26))
                        .lineSpacing(26 * 0.55)
                        .foregroundStyle(Nocturne.neutral400)
                        .frame(maxWidth: 960, alignment: .leading)
                        .padding(.top, 26)
                }
                HStack(spacing: 26) {
                    Button(action: pressPlay) {
                        PrimaryButtonLabel(title: "Play", icon: "▶", width: 520)
                    }
                    .buttonStyle(BareButtonStyle())
                    .focused($playFocused)
                    .accessibilityIdentifier("play")
                }
                .padding(.top, 40)
                if let playError {
                    Text(playError)
                        .font(.nocturne(22))
                        .foregroundStyle(Nocturne.accent300)
                        .padding(.top, 16)
                }
            }
            .frame(maxWidth: 1400, alignment: .leading)
        }
    }

    private var editions: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                Kicker(text: "Editions")
                Text(movie.editions.count == 1 ? "1 file on server" : "\(movie.editions.count) files on server")
                    .font(.nocturne(20))
                    .foregroundStyle(Nocturne.neutral600)
            }
            VStack(spacing: 2) {
                ForEach(movie.editions) { edition in
                    Button { start(edition) } label: {
                        EditionRowLabel(edition: edition)
                    }
                    .buttonStyle(BareButtonStyle())
                    .accessibilityIdentifier("edition.\(edition.displayName)")
                }
            }
        }
    }

    /// Frame 07.
    private var picker: some View {
        ZStack {
            Color(red: 11 / 255, green: 12 / 255, blue: 19 / 255).opacity(0.74)
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    Kicker(text: "Choose an edition")
                    Text(movie.title).font(.nocturne(42, .medium)).foregroundStyle(Nocturne.accent100)
                }
                .padding(.top, 38).padding(.horizontal, 44).padding(.bottom, 28)
                ForEach(movie.editions) { edition in
                    Button { start(edition) } label: {
                        PickerRowLabel(edition: edition)
                    }
                    .buttonStyle(BareButtonStyle())
                    .focused($pickerFocus, equals: edition.id)
                    .accessibilityIdentifier("pick.\(edition.displayName)")
                }
                Text("Menu to cancel")
                    .font(.nocturne(20))
                    .foregroundStyle(Nocturne.neutral600)
                    .padding(.top, 24).padding(.horizontal, 44).padding(.bottom, 34)
            }
            .frame(width: 1180, alignment: .leading)
            .background(Nocturne.panelBg, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Nocturne.neutral600, lineWidth: 1))
            .shadow(color: .black.opacity(0.75), radius: 45, y: 30)
            .focusSection()
        }
        .ignoresSafeArea()
        .onExitCommand { pickerOpen = false }
    }

    private func pressPlay() {
        if movie.editions.count > 1 {
            pickerOpen = true
        } else if let edition = movie.editions.first {
            start(edition)
        } else {
            playError = "This movie has no editions on the server, so there is nothing to play."
        }
    }

    private func start(_ edition: Edition) {
        guard let request = PlayRequest.movie(movie, edition: edition) else {
            playError = "The server gave no usable stream URL for \(edition.displayName): \(edition.file.stream)"
            return
        }
        pickerOpen = false
        play(request)
    }
}

// MARK: - Rows

/// Frame 06's edition row: name, resolution + HDR, codec, audio tracks, subtitle count, size.
private struct EditionRowLabel: View {
    let edition: Edition
    @Environment(\.isFocused) private var focused

    var body: some View {
        HStack(spacing: 28) {
            Text(edition.displayName)
                .font(.nocturne(27, .medium))
                .foregroundStyle(focused ? Nocturne.accent100 : Nocturne.text)
                .lineLimit(1)
                .frame(width: 320, alignment: .leading)
            HStack(spacing: 9) {
                if let label = edition.file.resolutionLabel {
                    Badge(text: label, size: 17, ground: Nocturne.controlBg)
                }
                if edition.file.hdr { Badge(text: "HDR", accent: true, size: 17) }
            }
            .frame(width: 230, alignment: .leading)
            Text(Format.videoCodec(edition.file.videoCodec))
                .font(.nocturne(22))
                .foregroundStyle(Nocturne.neutral500)
                .frame(width: 150, alignment: .leading)
            Text(Format.audioTracks(edition.file.audioTracks))
                .font(.nocturne(22))
                .foregroundStyle(Nocturne.neutral400)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Format.subtitleCount(edition.file.subtitleTracks.count))
                .font(.nocturne(22))
                .foregroundStyle(Nocturne.neutral500)
                .frame(width: 170, alignment: .trailing)
            Text(Format.size(edition.file.size))
                .font(.nocturne(22))
                .foregroundStyle(Nocturne.neutral600)
                .frame(width: 110, alignment: .trailing)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 26)
        .background(focused ? Nocturne.accent.opacity(0.18) : Nocturne.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(focused ? Nocturne.accent : Nocturne.rowRule, lineWidth: focused ? 2 : 1))
    }
}

/// Frame 07's picker row.
private struct PickerRowLabel: View {
    let edition: Edition
    @Environment(\.isFocused) private var focused

    var body: some View {
        HStack(spacing: 26) {
            Text(edition.displayName)
                .font(.nocturne(30, .medium))
                .foregroundStyle(focused ? Nocturne.accent100 : Nocturne.neutral300)
                .lineLimit(1)
                .frame(width: 300, alignment: .leading)
            HStack(spacing: 9) {
                if let label = edition.file.resolutionLabel {
                    Badge(text: label, size: 17, ground: Nocturne.controlBg)
                }
                if edition.file.hdr { Badge(text: "HDR", accent: true, size: 17) }
            }
            .frame(width: 210, alignment: .leading)
            Text(Format.videoCodec(edition.file.videoCodec))
                .font(.nocturne(22))
                .foregroundStyle(focused ? Nocturne.neutral300 : Nocturne.neutral500)
                .frame(width: 130, alignment: .leading)
            Text(Format.audioTracks(edition.file.audioTracks))
                .font(.nocturne(22))
                .foregroundStyle(focused ? Nocturne.neutral200 : Nocturne.neutral400)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Format.subtitleCount(edition.file.subtitleTracks.count))
                .font(.nocturne(22))
                .foregroundStyle(focused ? Nocturne.neutral300 : Nocturne.neutral500)
                .frame(width: 150, alignment: .trailing)
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 44)
        .background(focused ? Nocturne.accent.opacity(0.2) : .clear)
        .overlay(alignment: .top) { Rectangle().fill(Nocturne.panelRule).frame(height: 1) }
        .overlay { if focused { Rectangle().stroke(Nocturne.accent, lineWidth: 4).padding(2) } }
    }
}

/// Frames 06 and 08: the backdrop under the detail text, with the frames' two gradient washes
/// and the bottom fade.
struct DetailBackdrop: View {
    let path: String?

    var body: some View {
        ZStack {
            Nocturne.bg
            ServerImage(path: path) {
                EllipticalGradient(
                    stops: [.init(color: Color(hex: 0x3B3560), location: 0),
                            .init(color: Color(hex: 0x232538), location: 0.45),
                            .init(color: Nocturne.bg, location: 0.75)],
                    center: UnitPoint(x: 0.78, y: 0.1), startRadiusFraction: 0, endRadiusFraction: 0.9)
            }
            .opacity(0.8)
            LinearGradient(
                stops: [.init(color: Nocturne.bg, location: 0.26),
                        .init(color: Nocturne.bg.opacity(0.82), location: 0.48),
                        .init(color: Nocturne.bg.opacity(0.25), location: 0.76),
                        .init(color: Nocturne.bg.opacity(0.6), location: 1)],
                startPoint: .leading, endPoint: .trailing)
            VStack {
                Spacer()
                LinearGradient(colors: [Nocturne.bg.opacity(0), Nocturne.bg], startPoint: .top, endPoint: .bottom)
                    .frame(height: 340)
            }
        }
        .ignoresSafeArea()
    }
}
