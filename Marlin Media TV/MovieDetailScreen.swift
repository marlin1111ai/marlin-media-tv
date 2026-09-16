//
//  MovieDetailScreen.swift
//  Marlin Media TV
//
//  Frame 06 (movie detail) and frame 07 (edition picker).
//
//  Pass 2 (D026): the watched pill, "Resume · N min left" with its in-button bar, "Start over" and
//  "Mark watched" / "Mark unwatched" are here. On a movie with several editions the buttons follow
//  the edition with the latest `last_played` (the first edition when none has been played), and
//  pressing Play or Resume still opens the picker; the picker shows "Resume · N min left" under
//  the editions that have a saved position. Where the file's length is unknown there is no
//  "N min left" and no bar.
//

import SwiftUI

struct MovieDetailScreen: View {
    let movie: Movie
    let api: APIClient
    let play: (PlayRequest) -> Void

    @State private var pickerOpen = false
    @State private var playError: String?
    @State private var thumbs: FileThumbs?
    /// The movie as the server last gave it — re-read after a playback write (D026).
    @State private var current: Movie?
    @FocusState private var playFocused: Bool
    @FocusState private var pickerFocus: Int?

    private var shown: Movie { current ?? movie }

    /// D026: the edition the buttons follow.
    private var followed: Edition? {
        let played = shown.editions.filter { $0.file.playback.lastPlayed != nil }
        guard !played.isEmpty else { return shown.editions.first }
        return played.max {
            Format.rfc3339($0.file.playback.lastPlayed) < Format.rfc3339($1.file.playback.lastPlayed)
        }
    }

    private var savedPosition: Double { followed?.file.playback.position ?? 0 }
    private var isWatched: Bool { followed?.file.playback.watched ?? false }
    private var timeLeft: String? {
        guard let followed else { return nil }
        return Format.timeLeft(position: savedPosition, duration: followed.file.duration)
    }
    private var resumeShare: Double? {
        guard let followed else { return nil }
        return Format.share(position: savedPosition, duration: followed.file.duration)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            DetailBackdrop(path: shown.artwork.backdrop)
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
        .task { await loadThumbs() }
        .onChange(of: pickerOpen) { _, open in
            if open {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    pickerFocus = shown.editions.first?.id
                }
            } else {
                playFocused = true
            }
        }
    }

    private var top: some View {
        HStack(alignment: .top, spacing: 56) {
            ServerImage(path: shown.artwork.poster) { InitialTile(title: shown.title, fontSize: 120) }
                .frame(width: 300, height: 450)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Nocturne.neutral700, lineWidth: 1))
                .shadow(color: .black.opacity(0.6), radius: 30, y: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(shown.title)
                    .font(.nocturne(82, .medium))
                    .kerning(-1.6)
                    .foregroundStyle(Nocturne.accent100)
                    .lineLimit(2)
                    .accessibilityIdentifier("detail.title")
                HStack(spacing: 20) {
                    if let year = shown.year { Text(String(year)) }
                    Dot()
                    Text(Format.runtime(shown.runtime))
                    if let rating = Format.rating(shown.rating) {
                        Dot()
                        Text(rating)
                            .font(.nocturne(19))
                            .kerning(1.1)
                            .padding(.vertical, 6).padding(.horizontal, 12)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Nocturne.neutral600, lineWidth: 1))
                    }
                    if !shown.genres.isEmpty {
                        Dot()
                        Text(Format.genres(shown.genres))
                    }
                    // D026: frame 06's pill, at the end of the meta row, only when watched.
                    if isWatched { WatchedPill() }
                }
                .font(.nocturne(24))
                .foregroundStyle(Nocturne.neutral300)
                .padding(.top, 22)
                if let overview = shown.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.nocturne(26))
                        .lineSpacing(26 * 0.55)
                        .foregroundStyle(Nocturne.neutral400)
                        .frame(maxWidth: 960, alignment: .leading)
                        .padding(.top, 26)
                }
                buttons
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

    private var buttons: some View {
        HStack(spacing: 26) {
            Button(action: pressPlay) {
                if savedPosition > 0 {
                    ResumeButtonLabel(title: "Resume" + (timeLeft.map { " · \($0)" } ?? ""),
                                      share: resumeShare, width: 520)
                } else {
                    PrimaryButtonLabel(title: "Play", icon: "▶", width: 520)
                }
            }
            .buttonStyle(BareButtonStyle())
            .focused($playFocused)
            .accessibilityIdentifier("play")

            if savedPosition > 0 {
                Button(action: pressStartOver) { SecondaryButtonLabel(title: "Start over") }
                    .buttonStyle(BareButtonStyle())
                    .accessibilityIdentifier("startover")
            }
            Button(action: pressMark) {
                SecondaryButtonLabel(title: isWatched ? "Mark unwatched" : "Mark watched")
            }
            .buttonStyle(BareButtonStyle())
            .accessibilityIdentifier("mark")
        }
    }

    private var editions: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                Kicker(text: "Editions")
                Text(shown.editions.count == 1 ? "1 file on server" : "\(shown.editions.count) files on server")
                    .font(.nocturne(20))
                    .foregroundStyle(Nocturne.neutral600)
            }
            VStack(spacing: 2) {
                ForEach(shown.editions) { edition in
                    Button { start(edition, resume: true) } label: {
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
                    Text(shown.title).font(.nocturne(42, .medium)).foregroundStyle(Nocturne.accent100)
                }
                .padding(.top, 38).padding(.horizontal, 44).padding(.bottom, 28)
                ForEach(shown.editions) { edition in
                    Button { start(edition, resume: true) } label: {
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

    /// Pass 2g: the timeline stills of the file that would play, asked once when the screen opens
    /// and never polled or re-fetched. On a multi-edition movie Play opens the picker, so the file
    /// that would play is taken to be the first edition's; another edition then plays without
    /// thumbnails (the scrub simply shows none).
    private func loadThumbs() async {
        guard thumbs == nil, let file = shown.editions.first?.file else { return }
        do {
            thumbs = try await api.thumbs(fileId: file.fileId)
        } catch {
            print("[thumbs] \(shown.title): \((error as? APIError)?.localizedDescription ?? String(describing: error))")
        }
    }

    /// D026: re-read the movie so the pill, the button and the picker show what the server now holds.
    private func refresh() async {
        do { current = try await api.movie(id: movie.id) } catch {
            EvidenceLog.line("[detail] could not re-read movie \(movie.id): \((error as? APIError)?.localizedDescription ?? String(describing: error))")
        }
    }

    private func pressPlay() {
        if shown.editions.count > 1 {
            pickerOpen = true
        } else if let edition = shown.editions.first {
            start(edition, resume: true)
        } else {
            playError = "This movie has no editions on the server, so there is nothing to play."
        }
    }

    /// D026: position 0 is written first, then the edition plays from the beginning.
    private func pressStartOver() {
        guard let edition = followed else { return }
        Task {
            await PlaybackWrite.send(api, fileId: edition.file.fileId, position: 0, why: "start over")
            start(edition, resume: false)
        }
    }

    /// D026: both directions write position 0; the screen is re-read afterwards.
    private func pressMark() {
        guard let edition = followed else { return }
        let nowWatched = !isWatched
        Task {
            await PlaybackWrite.send(api, fileId: edition.file.fileId, position: 0, watched: nowWatched,
                                     why: nowWatched ? "mark watched" : "mark unwatched")
            await refresh()
        }
    }

    private func start(_ edition: Edition, resume: Bool) {
        guard let request = PlayRequest.movie(shown, edition: edition, thumbs: thumbs, resume: resume) else {
            playError = "The server gave no usable stream URL for \(edition.displayName): \(edition.file.stream)"
            return
        }
        pickerOpen = false
        play(request)
    }
}

// MARK: - Shared pieces of frames 06 and 09 (pass 2)

/// Frame 06's watched pill, at the end of the meta row. The owner dropped the frame's watch count
/// (D026), so it reads "✓ Watched" and nothing more.
struct WatchedPill: View {
    var body: some View {
        HStack(spacing: 9) {
            Text("✓")
            Text("Watched")
        }
        .font(.nocturne(19))
        .foregroundStyle(Nocturne.accent300)
        .padding(.vertical, 6).padding(.horizontal, 14)
        .background(Nocturne.accent.opacity(0.16), in: Capsule())
        .overlay(Capsule().stroke(Nocturne.accent700, lineWidth: 1))
        .accessibilityIdentifier("watched.pill")
    }
}

/// Frames 06 and 09: the Resume button — the primary action with the saved position's bar along
/// its bottom edge. `share` is nil when the file's length is unknown, and then no bar is drawn.
struct ResumeButtonLabel: View {
    let title: String
    let share: Double?
    let width: CGFloat?
    @Environment(\.isFocused) private var focused

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 18) {
                Text("▶").font(.nocturne(26)).foregroundStyle(Nocturne.accent100)
                Text(title).font(.nocturne(32, .medium)).foregroundStyle(Nocturne.accent100)
            }
            .padding(.vertical, 26)
            .padding(.horizontal, 34)
            .frame(width: width, alignment: .leading)
            if let share {
                ZStack(alignment: .leading) {
                    Rectangle().fill(Nocturne.text.opacity(0.2))
                    GeometryReader { geo in
                        Rectangle().fill(Nocturne.accent).frame(width: geo.size.width * share)
                    }
                }
                .frame(height: 5)
            }
        }
        .frame(width: width)
        .background(Nocturne.accent.opacity(focused ? 0.18 : 0.10), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            if focused { RoundedRectangle(cornerRadius: 15).stroke(Nocturne.accent, lineWidth: 4).padding(-5) }
            else { RoundedRectangle(cornerRadius: 12).stroke(Nocturne.neutral700, lineWidth: 1) }
        }
        .shadow(color: focused ? Nocturne.accent.opacity(0.3) : .clear, radius: 35)
    }
}

/// Frames 06 and 09: "Start over", "Mark watched" / "Mark unwatched".
struct SecondaryButtonLabel: View {
    let title: String
    @Environment(\.isFocused) private var focused

    var body: some View {
        Text(title)
            .font(.nocturne(30, .medium))
            .foregroundStyle(focused ? Nocturne.accent100 : Nocturne.neutral300)
            .lineLimit(1)
            .padding(.vertical, 28).padding(.horizontal, 30)
            .background(focused ? Nocturne.accent.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                if focused { RoundedRectangle(cornerRadius: 15).stroke(Nocturne.accent, lineWidth: 4).padding(-5) }
                else { RoundedRectangle(cornerRadius: 12).stroke(Nocturne.neutral600, lineWidth: 1) }
            }
            .shadow(color: focused ? Nocturne.accent.opacity(0.28) : .clear, radius: 30)
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

/// Frame 07's picker row. D026: an edition with a saved position carries "Resume · N min left"
/// under its name; one without carries nothing.
private struct PickerRowLabel: View {
    let edition: Edition
    @Environment(\.isFocused) private var focused

    private var resumeLine: String? {
        let playback = edition.file.playback
        guard playback.position > 0 else { return nil }
        guard let left = Format.timeLeft(position: playback.position, duration: edition.file.duration) else {
            return "Resume"
        }
        return "Resume · \(left)"
    }

    var body: some View {
        HStack(spacing: 26) {
            VStack(alignment: .leading, spacing: 6) {
                Text(edition.displayName)
                    .font(.nocturne(30, .medium))
                    .foregroundStyle(focused ? Nocturne.accent100 : Nocturne.neutral300)
                    .lineLimit(1)
                if let resumeLine {
                    Text(resumeLine)
                        .font(.nocturne(20))
                        .foregroundStyle(Nocturne.accent400)
                }
            }
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
