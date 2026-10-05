//
//  MusicScreens.swift
//  Marlin Media TV
//
//  Marlin Music (2026-10-04). There are no design frames for music: these screens follow the
//  frames' look — the library's grid and header, the detail screens' ground and buttons.
//   - the Albums and Artists tabs are `LibraryScreen`'s, with the square `CoverCard` below;
//   - `ArtistScreen` — one artist's albums;
//   - `AlbumScreen` — the cover, the album's lines and its tracks; a track plays the album from there;
//   - `NowPlayingScreen` — the cover, the track, the time bar and Previous / Pause / Next.
//  Menu from Now Playing leaves the music playing; the Now Playing button in the headers goes back.
//

import SwiftUI

// MARK: - Cards and header pieces

/// A 250 × 250 cover with a title and one line under it: an album, or an artist shown by the cover
/// of one of that artist's albums. Focus is the poster card's: the accent outline, a lift and a glow.
struct CoverCard: View {
    let title: String
    let line2: String
    let cover: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CoverCardLabel(title: title, line2: line2, cover: cover)
        }
        .buttonStyle(BareButtonStyle())
        .accessibilityLabel("\(title), \(line2)")
    }
}

private struct CoverCardLabel: View {
    let title: String
    let line2: String
    let cover: String?
    @Environment(\.isFocused) private var focused

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ServerImage(path: cover) { InitialTile(title: title) }
                .frame(width: 250, height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    if focused {
                        RoundedRectangle(cornerRadius: 12).stroke(Nocturne.accent, lineWidth: 4).padding(-8)
                    } else {
                        RoundedRectangle(cornerRadius: 8).stroke(Nocturne.neutral800, lineWidth: 1)
                    }
                }
                .shadow(color: focused ? .black.opacity(0.65) : .clear, radius: 35, y: 26)
                .shadow(color: focused ? Nocturne.accent.opacity(0.3) : .clear, radius: 35)
            Text(title)
                .font(.nocturne(focused ? 23 : 22, .medium))
                .foregroundStyle(focused ? Nocturne.accent100 : Nocturne.text)
                .lineLimit(2)
                .padding(.top, focused ? 20 : 14)
            Text(line2.isEmpty ? " " : line2)
                .font(.nocturne(19))
                .foregroundStyle(focused ? Nocturne.neutral400 : Nocturne.neutral500)
                .lineLimit(1)
                .padding(.top, 4)
        }
        .frame(width: 250, alignment: .leading)
        .opacity(focused ? 1 : 0.82)
        .scaleEffect(focused ? 1.05 : 1, anchor: .top)
        .offset(y: focused ? -8 : 0)
        .animation(.easeOut(duration: 0.15), value: focused)
    }
}

/// The header's way back to Now Playing, shown only while music is playing or paused. It takes the
/// sort control's look.
struct NowPlayingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) { NowPlayingButtonLabel() }
            .buttonStyle(BareButtonStyle())
            .accessibilityIdentifier("nowplaying")
    }
}

private struct NowPlayingButtonLabel: View {
    @Environment(\.isFocused) private var focused

    var body: some View {
        HStack(spacing: 12) {
            Text("♪")
                .font(.nocturne(22))
                .foregroundStyle(Nocturne.accent)
            Text("Now Playing")
                .font(.nocturne(24, .medium))
                .foregroundStyle(focused ? Nocturne.accent100 : Nocturne.neutral300)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 26)
        .background(focused ? Nocturne.accent.opacity(0.16) : Nocturne.controlBg, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? Nocturne.accent : Nocturne.neutral700, lineWidth: focused ? 3 : 1))
        .shadow(color: focused ? Nocturne.accent.opacity(0.3) : .clear, radius: 22)
    }
}

// MARK: - An artist's albums

struct ArtistScreen: View {
    let artist: Artist
    let model: LibraryModel
    let music: MusicPlayer?
    let open: (Destination) -> Void

    var body: some View {
        let albums = model.albums(of: artist)
        ZStack(alignment: .topLeading) {
            Nocturne.libraryGround
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    HStack(spacing: 60) {
                        Wordmark()
                        SectionLabel(title: artist.name)
                    }
                    Spacer()
                    if let music, music.isActive {
                        NowPlayingButton { open(.nowPlaying) }
                            .padding(.trailing, 260)     // clear of the clock, as the sort control is
                    }
                }
                .padding(.top, 52)
                .padding(.horizontal, 80)
                PosterGrid(heading: "\(artist.name) · \(albums.count) album\(albums.count == 1 ? "" : "s")",
                           lead: { EmptyView() }) {
                    ForEach(albums) { album in
                        CoverCard(title: album.title, line2: album.year.map(String.init) ?? "", cover: album.cover) {
                            open(.album(album))
                        }
                        .accessibilityIdentifier("album.\(album.id)")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            NowClock().padding(.trailing, 80).padding(.top, 56)
        }
        .ignoresSafeArea()
    }
}

// MARK: - An album and its tracks

struct AlbumScreen: View {
    /// The album as the list gave it: no tracks.
    let album: Album
    let api: APIClient
    let music: MusicPlayer
    let openNowPlaying: () -> Void

    /// The album with its tracks, from `GET /api/albums/{id}`.
    @State private var detail: Album?
    @State private var loadError: String?
    @State private var playError: String?
    @FocusState private var playFocused: Bool

    private var shown: Album { detail ?? album }

    private var tracks: [Track] {
        (detail?.tracks ?? []).sorted { ($0.disc ?? 0, $0.number ?? 0) < ($1.disc ?? 0, $1.number ?? 0) }
    }

    private var manyDiscs: Bool { (shown.discCount ?? 1) > 1 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            DetailBackdrop(path: nil)
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    top
                    trackList
                        .padding(.top, 56)
                }
                .padding(.horizontal, 80)
                .padding(.top, 78)
                .padding(.bottom, 80)
            }
            .scrollClipDisabled()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            NowClock().padding(.trailing, 80).padding(.top, 56)
        }
        .ignoresSafeArea()
        .onAppear { playFocused = true }
        .task { await load() }
    }

    private var top: some View {
        HStack(alignment: .top, spacing: 56) {
            ServerImage(path: shown.cover) { InitialTile(title: shown.title, fontSize: 120) }
                .frame(width: 400, height: 400)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Nocturne.neutral700, lineWidth: 1))
                .shadow(color: .black.opacity(0.6), radius: 30, y: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(shown.title)
                    .font(.nocturne(72, .medium))
                    .kerning(-1.4)
                    .foregroundStyle(Nocturne.accent100)
                    .lineLimit(2)
                    .accessibilityIdentifier("album.title")
                if let artist = shown.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.nocturne(34, .medium))
                        .foregroundStyle(Nocturne.neutral200)
                        .lineLimit(1)
                        .padding(.top, 12)
                }
                HStack(spacing: 20) {
                    if let year = shown.year {
                        Text(String(year))
                        Dot()
                    }
                    Text("\(shown.trackCount) track\(shown.trackCount == 1 ? "" : "s")")
                    if let duration = shown.duration {
                        Dot()
                        Text(Format.minutes(duration))
                    }
                }
                .font(.nocturne(24))
                .foregroundStyle(Nocturne.neutral300)
                .padding(.top, 20)
                if let spec = tracks.first?.spec, !spec.isEmpty {
                    Text(spec)
                        .font(.nocturne(22))
                        .foregroundStyle(Nocturne.neutral500)
                        .padding(.top, 12)
                }
                HStack(spacing: 26) {
                    Button { play(from: 0) } label: {
                        PrimaryButtonLabel(title: "Play", icon: "▶", width: 420)
                    }
                    .buttonStyle(BareButtonStyle())
                    .focused($playFocused)
                    .accessibilityIdentifier("album.play")
                    if music.isActive {
                        Button(action: openNowPlaying) { SecondaryButtonLabel(title: "Now Playing") }
                            .buttonStyle(BareButtonStyle())
                            .accessibilityIdentifier("album.nowplaying")
                    }
                }
                .padding(.top, 40)
                if let message = playError ?? loadError ?? music.errorText {
                    Text(message)
                        .font(.nocturne(22))
                        .foregroundStyle(Nocturne.accent300)
                        .frame(maxWidth: 1100, alignment: .leading)
                        .padding(.top, 16)
                        .accessibilityIdentifier("album.error")
                }
            }
            .frame(maxWidth: 1300, alignment: .leading)
        }
    }

    private var trackList: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                if manyDiscs, track.disc != (index > 0 ? tracks[index - 1].disc : nil) {
                    Kicker(text: "Disc \(track.disc ?? 1)")
                        .padding(.top, index == 0 ? 0 : 26)
                        .padding(.bottom, 12)
                }
                Button { play(from: index) } label: {
                    TrackRowLabel(number: track.number ?? index + 1,
                                  title: track.title,
                                  // A track's own artist only where it is not the album's.
                                  artist: track.artist.flatMap { $0 != shown.artist && !$0.isEmpty ? $0 : nil },
                                  duration: Format.clock(track.duration ?? 0),
                                  playing: music.albumId == album.id && music.index == index)
                }
                .buttonStyle(BareButtonStyle())
                .accessibilityIdentifier("track.\(index + 1)")
            }
        }
    }

    private func load() async {
        guard detail == nil else { return }
        do {
            let loaded = try await api.album(id: album.id)
            detail = loaded
            EvidenceLog.line("[album] \(album.id): \(loaded.tracks?.count ?? 0) tracks")
        } catch {
            let message = (error as? APIError)?.localizedDescription ?? String(describing: error)
            loadError = "Couldn't load the album: \(message)"
            EvidenceLog.line("[album] \(album.id) failed: \(message)")
        }
    }

    /// The album's tracks as the queue, starting at the track picked; then Now Playing.
    private func play(from index: Int) {
        let list = tracks
        guard list.indices.contains(index) else {
            playError = loadError ?? "This album has no tracks on the server, so there is nothing to play."
            return
        }
        var queue: [QueuedTrack] = []
        for track in list {
            guard let url = ServerConfig.resolve(track.stream) else {
                playError = "The server gave no usable stream URL for \(track.title): \(track.stream)"
                return
            }
            queue.append(QueuedTrack(title: track.title,
                                     artist: [track.artist, shown.artist].compactMap { $0 }.first { !$0.isEmpty } ?? "",
                                     album: shown.title,
                                     year: shown.year.map(String.init) ?? "",
                                     cover: shown.cover,
                                     spec: track.spec,
                                     url: url,
                                     duration: track.duration ?? 0))
        }
        playError = nil
        music.start(queue, at: index, albumId: album.id)
        openNowPlaying()
    }
}

/// One track of the album: its number, title, its own artist where that differs, and its length.
/// The track that is playing carries the accent.
private struct TrackRowLabel: View {
    let number: Int
    let title: String
    let artist: String?
    let duration: String
    let playing: Bool
    @Environment(\.isFocused) private var focused

    var body: some View {
        HStack(spacing: 28) {
            Text(playing ? "♪" : String(number))
                .font(.nocturne(24, .medium))
                .monospacedDigit()
                .foregroundStyle(playing ? Nocturne.accent : Nocturne.neutral500)
                .frame(width: 56, alignment: .trailing)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.nocturne(27, .medium))
                    .foregroundStyle(focused ? Nocturne.accent100 : (playing ? Nocturne.accent300 : Nocturne.text))
                    .lineLimit(1)
                if let artist {
                    Text(artist)
                        .font(.nocturne(20))
                        .foregroundStyle(Nocturne.neutral500)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(duration)
                .font(.nocturne(24))
                .monospacedDigit()
                .foregroundStyle(focused ? Nocturne.text : Nocturne.neutral400)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 26)
        .background(focused ? Nocturne.accent.opacity(0.18) : Nocturne.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(focused ? Nocturne.accent : Nocturne.rowRule, lineWidth: focused ? 2 : 1))
    }
}

// MARK: - Now Playing

struct NowPlayingScreen: View {
    let music: MusicPlayer

    private enum Control: Hashable { case previous, toggle, next }
    @FocusState private var focus: Control?

    var body: some View {
        ZStack {
            Nocturne.libraryGround
            if let track = music.track {
                HStack(alignment: .center, spacing: 90) {
                    ServerImage(path: track.cover) { InitialTile(title: track.album, fontSize: 160) }
                        .frame(width: 600, height: 600)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Nocturne.neutral700, lineWidth: 1))
                        .shadow(color: .black.opacity(0.6), radius: 40, y: 26)
                    details(track)
                        .frame(width: 900, alignment: .leading)
                }
                .padding(.horizontal, 80)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            NowClock().padding(.trailing, 80).padding(.top, 56)
        }
        .ignoresSafeArea()
        .onAppear { focus = .toggle }
    }

    private func details(_ track: QueuedTrack) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Kicker(text: "Now playing · track \(music.index + 1) of \(music.queue.count)")
            Text(track.title)
                .font(.nocturne(64, .medium))
                .kerning(-1.2)
                .foregroundStyle(Nocturne.accent100)
                .lineLimit(2)
                .padding(.top, 20)
                .accessibilityIdentifier("nowplaying.title")
            if !track.artist.isEmpty {
                Text(track.artist)
                    .font(.nocturne(34, .medium))
                    .foregroundStyle(Nocturne.neutral200)
                    .lineLimit(1)
                    .padding(.top, 14)
            }
            Text([track.album, track.year].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.nocturne(26))
                .foregroundStyle(Nocturne.neutral400)
                .lineLimit(1)
                .padding(.top, 8)
            if !track.spec.isEmpty {
                Text(track.spec)
                    .font(.nocturne(22))
                    .foregroundStyle(Nocturne.neutral500)
                    .padding(.top, 10)
            }
            // The time bar: elapsed, the bar, what is left.
            VStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    Capsule().fill(Nocturne.text.opacity(0.18))
                    GeometryReader { geo in
                        Capsule().fill(Nocturne.accent).frame(width: geo.size.width * music.progress)
                    }
                }
                .frame(height: 6)
                HStack {
                    Text(Format.clock(music.positionS))
                    Spacer()
                    Text("−" + Format.clock(max(0, music.lengthS - music.positionS)))
                }
                .font(.nocturne(24))
                .monospacedDigit()
                .foregroundStyle(Nocturne.neutral400)
            }
            .padding(.top, 44)
            HStack(spacing: 26) {
                Button { music.previous() } label: { SecondaryButtonLabel(title: "Previous") }
                    .buttonStyle(BareButtonStyle())
                    .focused($focus, equals: .previous)
                    .accessibilityIdentifier("nowplaying.previous")
                Button { music.toggle() } label: { SecondaryButtonLabel(title: music.isPaused ? "Play" : "Pause") }
                    .buttonStyle(BareButtonStyle())
                    .focused($focus, equals: .toggle)
                    .accessibilityIdentifier("nowplaying.toggle")
                Button { music.next() } label: { SecondaryButtonLabel(title: "Next") }
                    .buttonStyle(BareButtonStyle())
                    .focused($focus, equals: .next)
                    .disabled(music.nextTitle == nil)
                    .accessibilityIdentifier("nowplaying.next")
            }
            .padding(.top, 40)
            if let next = music.nextTitle {
                Text("Next: \(next)")
                    .font(.nocturne(22))
                    .foregroundStyle(Nocturne.neutral500)
                    .lineLimit(1)
                    .padding(.top, 26)
            }
            if let message = music.errorText {
                Text(message)
                    .font(.nocturne(22))
                    .foregroundStyle(Nocturne.accent300)
                    .padding(.top, 16)
                    .accessibilityIdentifier("nowplaying.error")
            }
        }
    }
}
