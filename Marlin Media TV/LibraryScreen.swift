//
//  LibraryScreen.swift
//  Marlin Media TV
//
//  Frames 01 (Movies), 02 (TV Shows), 03 (Videos), 04 (Videos empty), 05 (sort control open),
//  16 (loading) and 17 (can't reach server).
//
//  Pass 2 (D023, D025): the sort control carries Recently Added, and each tab shows a
//  "Continue watching" row above its grid holding only that tab's kind, in the server's order,
//  every entry, scrolling sideways. With no entries there is no heading and no row, and the grid
//  moves up. The grid posters themselves carry no bar and no watched mark. The "Browse cached"
//  button of frame 17 is still not here.
//
//  Pass 2b (D033): focus entering the row lands on its **first** card. The row is a focus scope
//  and the first card is its preferred default focus; without that the focus engine picks the card
//  nearest the header item focus came from, which on the TV Shows tab is the second card.
//
//  2026-10-04, the five apps: this is each app's **first screen**. An app of one kind has no tab
//  bar — its word stands where the tabs were — and Marlin Music's tabs are Albums and Artists.
//  Marlin TV Shows adds the Up next row under Continue Watching (the old Home's TV row, D040,
//  without the episodes in progress). The screen re-reads itself every time it appears, and the
//  launch focus goes to the first Continue Watching card, as Home's did (D040, D043).
//

import SwiftUI

struct LibraryScreen: View {
    @Bindable var model: LibraryModel
    /// Marlin Music's player, for the header's Now Playing button; nil in the other four apps.
    let music: MusicPlayer?
    let open: (Destination) -> Void
    /// D025: a Continue Watching card plays its file directly.
    let openEntry: (ContinueEntry) -> Void
    /// D040: an Up next card plays its episode.
    let openEpisode: (UpNextEpisode) -> Void

    @State private var sortOpen = false
    @FocusState private var focusedTab: LibraryTab?
    @FocusState private var sortFocus: SortOrder?
    @FocusState private var sortButtonFocused: Bool
    /// D033: which card of the Continue Watching row has focus, so that focus arriving from
    /// outside the row can be moved to its first card.
    @FocusState private var focusedCard: Int?
    /// D043: the launch focus is placed once in a session, and never again.
    @State private var launchFocusPlaced = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch model.phase {
            case .loading:
                LibraryLoadingView()
            case let .failed(message, unreachable):
                LibraryErrorView(message: message, unreachable: unreachable) {
                    Task { await model.load() }
                }
            case .loaded:
                loaded
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // D041: the clock, where the new frames put it on every screen but the player. It goes on
        // before `ignoresSafeArea` so that it sits 56 pt from the frame's own top, not 56 pt inside
        // tvOS's safe area, which put it a header's height too low.
        .overlay(alignment: .topTrailing) {
            NowClock().padding(.trailing, 80).padding(.top, 56)
        }
        .ignoresSafeArea()
    }

    // MARK: frames 01–04

    private var loaded: some View {
        ZStack(alignment: .topLeading) {
            Nocturne.libraryGround
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 52)
                    .padding(.horizontal, 80)
                content
            }
            if sortOpen {
                sortMenu
                    .padding(.top, 52 + 68 + 18)   // below the control (frame 05: margin-top 18)
                    .padding(.trailing, 80)
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                    .zIndex(5)
            }
        }
        // D025/D040: the screen is re-read every time it appears — including the return from a
        // detail screen. ContentView does the same when the player closes.
        .onAppear { Task { await model.refresh() }; placeLaunchFocus() }
        // D043: the in-progress list arrives after the first appearance, so the cards exist only
        // once it has — that is where the launch focus is placed.
        .onChange(of: model.continueWatching.count) { _, _ in placeLaunchFocus() }
        .onChange(of: sortOpen) { _, open in
            if open {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    sortFocus = model.sort
                }
            } else {
                sortButtonFocused = true
            }
        }
        .onChange(of: sortFocus) { _, focus in
            // Focus left the open menu by a swipe: close it, as the prototype does on any click outside.
            if sortOpen, focus == nil { sortOpen = false }
        }
    }

    /// D043, carried over from Home: when the app opens, focus lands on the **first** Continue
    /// Watching card. It is placed once in a session — on the first list the screen receives — so
    /// moving along the row, coming back from the player and every later re-read are untouched.
    /// With nothing in progress there is no row and nothing is placed.
    ///
    /// The card is asked for until it takes focus, because the focus engine ignores a request for a
    /// view that is not on screen yet and the row is built from a list that has just arrived. The
    /// loop stops the moment any card of the row holds focus, so a viewer who moves first is not
    /// pulled back.
    private func placeLaunchFocus() {
        guard !launchFocusPlaced, let first = model.continueEntries(for: model.tab).first?.fileId else { return }
        launchFocusPlaced = true
        Task { @MainActor in
            for _ in 0..<12 {
                if focusedCard != nil { break }
                focusedCard = first
                try? await Task.sleep(for: .milliseconds(120))
            }
            EvidenceLog.line("[focus] launch: asked for the first Continue Watching card \(first); "
                             + "focus is now \(focusedCard.map(String.init) ?? "outside the row")")
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 60) {
                Wordmark()
                if model.kind.tabs.count > 1 {
                    HStack(spacing: 14) {
                        ForEach(model.kind.tabs, id: \.self) { tab in
                            Button { model.tab = tab } label: {
                                TabLabel(title: tab.rawValue, selected: model.tab == tab)
                            }
                            .buttonStyle(BareButtonStyle())
                            .focused($focusedTab, equals: tab)
                            .accessibilityIdentifier("tab.\(tab.rawValue)")
                        }
                    }
                } else {
                    SectionLabel(title: model.kind.section)
                }
            }
            Spacer()
            HStack(spacing: 20) {
                if let music, music.isActive {
                    NowPlayingButton { open(.nowPlaying) }
                }
                // The sort belongs to the albums; artists are always by name.
                if model.tab != .artists {
                    Button { sortOpen.toggle() } label: {
                        SortControlLabel(sort: model.sort.rawValue, open: sortOpen)
                    }
                    .buttonStyle(BareButtonStyle())
                    .focused($sortButtonFocused)
                    .accessibilityIdentifier("sort")
                    .accessibilityLabel("Sort \(model.sort.rawValue)")
                }
            }
            // D041: the new frames move the control 260 pt in from the right edge, to clear the
            // clock that now sits there.
            .padding(.trailing, 260)
        }
    }

    /// Frame 05: the open sort control's list. Focus moves vertically; the current sort carries the check and the accent mark.
    private var sortMenu: some View {
        VStack(spacing: 0) {
            ForEach(SortOrder.allCases, id: \.self) { option in
                Button {
                    model.sort = option
                    sortOpen = false
                } label: {
                    SortOptionLabel(title: option.rawValue, current: model.sort == option)
                }
                .buttonStyle(BareButtonStyle())
                .focused($sortFocus, equals: option)
                .accessibilityIdentifier("sort.\(option.rawValue)")
            }
        }
        .frame(width: 420)
        .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Nocturne.neutral700, lineWidth: 1))
        .shadow(color: .black.opacity(0.7), radius: 30, y: 22)
        .focusSection()
        .onExitCommand { sortOpen = false }
    }

    /// D025: the row for the tab on screen, or nothing at all when the server lists no entry of
    /// that kind — no heading, no row, and the grid moves up to take the space.
    /// D033: its first card is the scope's default focus.
    @ViewBuilder
    private var continueRow: some View {
        let entries = model.continueEntries(for: model.tab)
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 22) {
                Kicker(text: "Continue watching")
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 34) {
                        ForEach(entries) { entry in
                            Button { openEntry(entry) } label: {
                                ContinueCardLabel(entry: entry)
                            }
                            .buttonStyle(BareButtonStyle())
                            .accessibilityIdentifier("continue.\(entry.fileId)")
                            .focused($focusedCard, equals: entry.fileId)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .scrollClipDisabled()
            }
            .padding(.bottom, 30)
            // Its own focus region, so moving down from the tabs enters the row instead of
            // restoring the grid's last focused poster and skipping past it.
            .focusSection()
            // D033: focus has come in from outside the row — a moment ago no card had it. tvOS
            // picks the nearest card in the direction of travel (pass 2b: the rightmost one when
            // arriving from the sort control), so it is moved to the first card here. A move from
            // one card to another inside the row has a previous card, and is left alone.
            .onChange(of: focusedCard) { previous, current in
                guard previous == nil, let current,
                      let first = entries.first?.fileId, current != first else { return }
                focusedCard = first
                EvidenceLog.line("[focus] continue row entered at card \(current); moved to the first card \(first)")
            }
        }
    }

    /// Marlin TV Shows' Up next row (D040's order, the episodes in progress left to the row above
    /// it): the next episode of each show in the frames' wide card. A click plays it. Nothing at
    /// all when there is no next episode anywhere.
    @ViewBuilder
    private var upNextRow: some View {
        let items = model.upNext
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 22) {
                Kicker(text: "Up next")
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 32) {
                        ForEach(items) { item in
                            Button { openEpisode(item) } label: {
                                WideCardLabel(still: item.episode.artwork.still,
                                              title: item.show.title,
                                              subtitle: "S\(item.episode.season) E\(item.episode.number) · \(item.episode.displayTitle)",
                                              fallbackInitial: item.show.title)
                            }
                            .buttonStyle(BareButtonStyle())
                            .accessibilityIdentifier("upnext.\(item.id)")
                        }
                    }
                    .padding(.vertical, 8)
                }
                .scrollClipDisabled()
            }
            .padding(.bottom, 30)
            .focusSection()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.tab {
        case .movies:
            // Marlin Adult is this tab on the adult routes: "titles", and the studio under each.
            let adult = model.kind == .adult
            PosterGrid(heading: "All \(adult ? "titles" : "movies") · \(model.movies.count)", lead: { continueRow }) {
                ForEach(model.sortedMovies) { movie in
                    let file = movie.editions.first?.file
                    PosterCard(title: movie.title, year: movie.year, poster: movie.artwork.poster,
                               badges: badges(file), line2: adult ? movie.studio : nil) {
                        open(.movie(movie))
                    }
                    .accessibilityIdentifier("poster.\(movie.title)")
                }
            }
        case .shows:
            // The shows list carries no per-file resolution or HDR, so shows get no badges.
            PosterGrid(heading: "All shows · \(model.shows.count)", lead: { continueRow; upNextRow }) {
                ForEach(model.sortedShows) { show in
                    PosterCard(title: show.title, year: show.year, poster: show.artwork.poster, badges: []) {
                        open(.show(show))
                    }
                    .accessibilityIdentifier("poster.\(show.title)")
                }
            }
        case .videos:
            if model.videos.isEmpty {
                VideosEmptyView()
            } else {
                VideoList(videos: model.sortedVideos, lead: { continueRow }) { open(.video($0)) }
            }
        case .albums:
            PosterGrid(heading: "All albums · \(model.albums.count)", lead: { EmptyView() }) {
                ForEach(model.sortedAlbums) { album in
                    CoverCard(title: album.title, line2: album.cardLine, cover: album.cover) {
                        open(.album(album))
                    }
                    .accessibilityIdentifier("album.\(album.id)")
                }
            }
        case .artists:
            PosterGrid(heading: "All artists · \(model.artists.count)", lead: { EmptyView() }) {
                ForEach(model.sortedArtists) { artist in
                    CoverCard(title: artist.name, line2: artist.cardLine, cover: model.cover(of: artist)) {
                        open(.artist(artist))
                    }
                    .accessibilityIdentifier("artist.\(artist.id)")
                }
            }
        }
    }

    /// Frame 01: "4K" from resolution_label, "HDR" from hdr.
    private func badges(_ file: MediaInfo?) -> [(String, Bool)] {
        guard let file else { return [] }
        var out: [(String, Bool)] = []
        if file.resolutionLabel == "4K" { out.append(("4K", false)) }
        if file.hdr { out.append(("HDR", true)) }
        return out
    }
}

// MARK: - Continue watching (frames 01, 02; D025)

/// Frame 01's card for a movie or a video, frame 02's for an episode: the art with the position's
/// bar across its foot, the title, the episode line for a show, and "N min left". Where the server
/// reports no duration there is no line and no bar.
struct ContinueCardLabel: View {
    let entry: ContinueEntry
    @Environment(\.isFocused) private var focused

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ServerImage(path: entry.artwork?.poster ?? entry.artwork?.backdrop ?? entry.artwork?.still) {
                InitialTile(title: entry.cardTitle)
            }
            .frame(width: 262, height: 393)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .bottom) {
                if let share = entry.progress {
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Nocturne.text.opacity(0.18))
                        GeometryReader { geo in
                            Rectangle().fill(Nocturne.accent).frame(width: geo.size.width * share)
                        }
                    }
                    .frame(height: 5)
                }
            }
            .overlay {
                if focused {
                    RoundedRectangle(cornerRadius: 12).stroke(Nocturne.accent, lineWidth: 4).padding(-8)
                } else {
                    RoundedRectangle(cornerRadius: 8).stroke(Nocturne.neutral800, lineWidth: 1)
                }
            }
            .shadow(color: focused ? .black.opacity(0.65) : .clear, radius: 35, y: 26)
            .shadow(color: focused ? Nocturne.accent.opacity(0.3) : .clear, radius: 35)
            Text(entry.cardTitle)
                .font(.nocturne(22, .medium))
                .foregroundStyle(focused ? Nocturne.accent100 : Nocturne.text)
                .lineLimit(1)
                .padding(.top, 14)
            if let subtitle = entry.cardSubtitle {
                Text(subtitle)
                    .font(.nocturne(19))
                    .foregroundStyle(Nocturne.neutral500)
                    .lineLimit(1)
                    .padding(.top, 4)
            }
            if let left = entry.timeLeftText {
                Text(left)
                    .font(.nocturne(19))
                    .foregroundStyle(entry.cardSubtitle == nil ? Nocturne.neutral500 : Nocturne.neutral600)
                    .lineLimit(1)
                    .padding(.top, entry.cardSubtitle == nil ? 4 : 2)
            }
        }
        .frame(width: 262, alignment: .leading)
        .opacity(focused ? 1 : 0.82)
        .scaleEffect(focused ? 1.05 : 1, anchor: .top)
        .offset(y: focused ? -8 : 0)
        .animation(.easeOut(duration: 0.15), value: focused)
    }
}

// MARK: - Header pieces

/// "MARLIN", 24 px, .26 em, accent.
struct Wordmark: View {
    var body: some View {
        Text("MARLIN")
            .font(.nocturne(24, .medium))
            .kerning(24 * 0.26)
            .foregroundStyle(Nocturne.accent)
    }
}

/// The app's own word where the tabs were (2026-10-04): an app of one kind has nothing to switch
/// between. It keeps a tab's height, so the header and the sort menu under it stay where they were.
struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.nocturne(30, .medium))
            .foregroundStyle(Nocturne.neutral300)
            .lineLimit(1)
            .padding(.vertical, 13)
    }
}

/// A library tab (frames 01–03): the selected tab carries the accent border, tint and glow; a
/// focused, unselected tab takes the prototype's hover look (accent border, bright text). Tabs
/// switch on click, as the prototype does.
private struct TabLabel: View {
    let title: String
    let selected: Bool
    @Environment(\.isFocused) private var focused

    var body: some View {
        Text(title)
            .font(.nocturne(30, .medium))
            .foregroundStyle(selected || focused ? Nocturne.accent100 : Nocturne.neutral500)
            .padding(.vertical, 13)
            .padding(.horizontal, 30)
            .background(selected ? Nocturne.accent.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected || focused ? Nocturne.accent : .clear, lineWidth: 3))
            .shadow(color: selected ? Nocturne.accent.opacity(0.34) : .clear, radius: 22)
    }
}

/// The sort control, closed (frames 01–04) and open (frame 05).
private struct SortControlLabel: View {
    let sort: String
    let open: Bool
    @Environment(\.isFocused) private var focused

    var body: some View {
        HStack(spacing: 12) {
            Text("SORT")
                .font(.nocturne(18, .medium))
                .kerning(1.8)
                .foregroundStyle(focused || open ? Nocturne.neutral400 : Nocturne.neutral600)
            Text(sort)
                .font(.nocturne(24, .medium))
                .foregroundStyle(focused || open ? Nocturne.accent100 : Nocturne.neutral300)
            Text(open ? "▴" : "▾")
                .font(.nocturne(20))
                .foregroundStyle(Nocturne.accent)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 26)
        .background(focused || open ? Nocturne.accent.opacity(0.16) : Nocturne.controlBg, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused || open ? Nocturne.accent : Nocturne.neutral700, lineWidth: focused || open ? 3 : 1))
        .shadow(color: focused || open ? Nocturne.accent.opacity(0.3) : .clear, radius: 22)
    }
}

private struct SortOptionLabel: View {
    let title: String
    let current: Bool
    @Environment(\.isFocused) private var focused

    var body: some View {
        HStack {
            Text(title)
                .font(.nocturne(28, .medium))
                .foregroundStyle(current || focused ? Nocturne.accent100 : Nocturne.neutral300)
            Spacer()
            if current {
                Text("✓").font(.nocturne(26)).foregroundStyle(Nocturne.accent)
            }
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 28)
        .background(current ? Nocturne.accent.opacity(0.2) : (focused ? Nocturne.accent.opacity(0.14) : .clear))
        .overlay(alignment: .leading) {
            if current { Rectangle().fill(Nocturne.accent).frame(width: 4) }
        }
        .overlay(alignment: .top) {
            Rectangle().fill(Nocturne.rowRule).frame(height: 1)
        }
    }
}

// MARK: - Poster grid (frames 01, 02)

struct PosterGrid<Lead: View, Content: View>: View {
    let heading: String
    @ViewBuilder let lead: () -> Lead
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 22) {
                lead()
                Kicker(text: heading)
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(250), spacing: 36, alignment: .top), count: 6),
                          alignment: .leading, spacing: 44) {
                    content()
                }
                .padding(.top, 12)
            }
            .padding(.top, 46)
            .padding(.horizontal, 80)
            .padding(.bottom, 80)
        }
        // The grid scrolls **clipped**, as the old Home's rows did: with clipping disabled a row
        // scrolled away drew over the header above it. The sideways rows inside keep their
        // unclipped edges, so a focused card's lift and glow are not cut off.
    }
}

/// A 250 × 375 poster with title and year; focus is the accent outline, a lift and a glow (frame 01, Blade Runner).
struct PosterCard: View {
    let title: String
    let year: Int?
    let poster: String?
    let badges: [(String, Bool)]
    /// Marlin Adult: the studio, shown in the year's place when the title has one.
    var line2: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PosterCardLabel(title: title, line2: line2 ?? year.map(String.init), poster: poster, badges: badges)
        }
        .buttonStyle(BareButtonStyle())
        .accessibilityLabel("\(title), \(year.map(String.init) ?? "")")
    }
}

private struct PosterCardLabel: View {
    let title: String
    let line2: String?
    let poster: String?
    let badges: [(String, Bool)]
    @Environment(\.isFocused) private var focused

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ServerImage(path: poster) { InitialTile(title: title) }
                .frame(width: 250, height: 375)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 7) {
                        ForEach(badges, id: \.0) { badge in Badge(text: badge.0, accent: badge.1) }
                    }
                    .padding(12)
                }
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
            Text(line2 ?? " ")
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

// MARK: - Videos (frames 03, 04)

private struct VideoList<Lead: View>: View {
    let videos: [Video]
    @ViewBuilder let lead: () -> Lead
    let open: (Video) -> Void

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                lead()
                ForEach(videos) { video in
                    Button { open(video) } label: {
                        VideoRowLabel(video: video)
                    }
                    .buttonStyle(BareButtonStyle())
                    .accessibilityIdentifier("video.\(video.title)")
                }
            }
            .frame(width: 1200, alignment: .leading)
            .padding(.top, 44)
            .padding(.horizontal, 80)
            .padding(.bottom, 80)
        }
        // Clipped, like the poster grid: a row scrolled away must not draw over the header.
    }
}

private struct VideoRowLabel: View {
    let video: Video
    @Environment(\.isFocused) private var focused

    private var spec: String {
        [video.file.resolutionLabel, video.file.videoCodec.map(Format.videoCodec)].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 30) {
            ServerImage(path: video.artwork.backdrop ?? video.artwork.poster ?? video.artwork.still) {
                Nocturne.posterPlaceholder
            }
            .frame(width: 250, height: 141)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(focused ? Nocturne.neutral700 : Nocturne.neutral800, lineWidth: 1))
            VStack(alignment: .leading, spacing: 8) {
                Text(video.title)
                    .font(.nocturne(30, .medium))
                    .foregroundStyle(focused ? Nocturne.accent100 : Nocturne.text)
                    .lineLimit(1)
                Text(spec)
                    .font(.nocturne(21))
                    .foregroundStyle(focused ? Nocturne.neutral400 : Nocturne.neutral500)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(Format.clock(video.file.duration ?? 0))
                .font(.nocturne(28, .medium))
                .monospacedDigit()
                .foregroundStyle(focused ? Nocturne.text : Nocturne.neutral400)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .background(focused ? Nocturne.accent.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            if focused { RoundedRectangle(cornerRadius: 12).stroke(Nocturne.accent, lineWidth: 4).padding(-4) }
        }
        .shadow(color: focused ? Nocturne.accent.opacity(0.26) : .clear, radius: 30)
        .opacity(focused ? 1 : 0.86)
    }
}

/// Frame 04.
private struct VideosEmptyView: View {
    var body: some View {
        VStack(spacing: 26) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .foregroundStyle(Nocturne.neutral800)
                .frame(width: 190, height: 107)
            Text("No videos yet")
                .font(.nocturne(46, .medium))
                .foregroundStyle(Nocturne.text)
            Text("Drop files into the Videos folder on your server. Marlin picks them up on the next scan.")
                .font(.nocturne(26))
                .foregroundStyle(Nocturne.neutral500)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 700)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 170 - 120)
        .padding(.horizontal, 80)
        .padding(.bottom, 80)
    }
}

// MARK: - Loading (frame 16)

private struct LibraryLoadingView: View {
    var body: some View {
        ZStack(alignment: .topLeading) {
            Nocturne.libraryGround
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 60) {
                    Wordmark()
                    Skeleton(width: 150, height: 52, radius: 10, color: Nocturne.surface)
                }
                .padding(.top, 52)
                .padding(.horizontal, 80)
                VStack(alignment: .leading, spacing: 26) {
                    Skeleton(width: 300, height: 22, radius: 4, color: Nocturne.surface)
                    HStack(spacing: 34) {
                        ForEach(0..<6, id: \.self) { _ in
                            VStack(alignment: .leading, spacing: 0) {
                                LinearGradient(colors: [Color(hex: 0x1E2030), Color(hex: 0x262939), Color(hex: 0x1E2030)],
                                               startPoint: .leading, endPoint: .trailing)
                                    .frame(width: 250, height: 375)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                Skeleton(width: 190, height: 20, radius: 4, color: Nocturne.surface).padding(.top, 16)
                                Skeleton(width: 90, height: 18, radius: 4, color: Color(hex: 0x1F2130)).padding(.top, 10)
                            }
                        }
                    }
                }
                .padding(.top, 46)
                .padding(.horizontal, 80)
            }
            HStack(spacing: 20) {
                Spinner()
                Text("Loading library from \(ServerConfig.host)…")
                    .font(.nocturne(26))
                    .foregroundStyle(Nocturne.neutral500)
            }
            .padding(.leading, 80)
            .padding(.top, 1080 - 96 - 34)
        }
    }
}

private struct Skeleton: View {
    let width: CGFloat
    let height: CGFloat
    let radius: CGFloat
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: radius).fill(color).frame(width: width, height: height)
    }
}

/// Frame 16's spinner: a 34 px ring, #423a6a with the accent on top, turning.
private struct Spinner: View {
    @State private var turning = false

    var body: some View {
        ZStack {
            Circle().stroke(Nocturne.accent800, lineWidth: 3)
            Circle().trim(from: 0, to: 0.25).stroke(Nocturne.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(turning ? 360 : 0))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: turning)
        }
        .frame(width: 34, height: 34)
        .onAppear { turning = true }
    }
}

// MARK: - Can't reach server (frame 17, Retry only)

struct LibraryErrorView: View {
    let message: String
    let unreachable: Bool
    let retry: () -> Void
    @FocusState private var retryFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Nocturne.errorGround
            Wordmark()
                .padding(.leading, 80)
                .padding(.top, 52)
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "Connection")
                Text(unreachable ? "Can't reach server" : "Server error")
                    .font(.nocturne(66, .medium))
                    .kerning(-1.3)
                    .foregroundStyle(Nocturne.accent100)
                    .padding(.top, 22)
                Text(unreachable
                     ? "\(ServerConfig.host) did not answer. Check that the server is powered on and on the same network as this Apple TV."
                     : "\(ServerConfig.host) answered, but the library could not be read.")
                    .font(.nocturne(27))
                    .foregroundStyle(Nocturne.neutral400)
                    .frame(maxWidth: 780, alignment: .leading)
                    .padding(.top, 24)
                Text(message)
                    .font(.nocturne(22))
                    .foregroundStyle(Nocturne.neutral600)
                    .frame(maxWidth: 900, alignment: .leading)
                    .padding(.top, 20)
                    .accessibilityIdentifier("error.message")
                Button(action: retry) {
                    PrimaryButtonLabel(title: "Retry", icon: nil, width: nil, paddingH: 60, paddingV: 24)
                }
                .buttonStyle(BareButtonStyle())
                .focused($retryFocused)
                .accessibilityIdentifier("retry")
                .padding(.top, 48)
            }
            .frame(maxWidth: 900, alignment: .leading)
            .padding(.leading, 80)
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .onAppear { retryFocused = true }
    }
}

/// The accent-tinted primary action (Play, Retry): tint always, the 4 px ring and glow when focused.
struct PrimaryButtonLabel: View {
    let title: String
    let icon: String?
    let width: CGFloat?
    var paddingH: CGFloat = 34
    var paddingV: CGFloat = 26
    @Environment(\.isFocused) private var focused

    var body: some View {
        HStack(spacing: 18) {
            if let icon { Text(icon).font(.nocturne(26)).foregroundStyle(Nocturne.accent100) }
            Text(title).font(.nocturne(32, .medium)).foregroundStyle(Nocturne.accent100)
        }
        .padding(.vertical, paddingV)
        .padding(.horizontal, paddingH)
        .frame(width: width, alignment: .leading)
        .background(Nocturne.accent.opacity(focused ? 0.18 : 0.10), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            if focused { RoundedRectangle(cornerRadius: 15).stroke(Nocturne.accent, lineWidth: 4).padding(-5) }
            else { RoundedRectangle(cornerRadius: 12).stroke(Nocturne.neutral700, lineWidth: 1) }
        }
        .shadow(color: focused ? Nocturne.accent.opacity(0.3) : .clear, radius: 35)
    }
}

// MARK: - Up next (frame 00b's card)

/// Frame 00b's wide card (340 × 191), drawn for the old Home's TV Shows row and now used by Marlin
/// TV Shows' Up next row.
struct WideCardLabel: View {
    let still: String?
    let title: String
    let subtitle: String
    let fallbackInitial: String
    @Environment(\.isFocused) private var focused

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ServerImage(path: still) { InitialTile(title: fallbackInitial, fontSize: 72) }
                .frame(width: 340, height: 191)
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
                .font(.nocturne(22, .medium))
                .foregroundStyle(focused ? Nocturne.accent100 : Nocturne.text)
                .lineLimit(1)
                .padding(.top, 14)
            Text(subtitle)
                .font(.nocturne(19))
                .foregroundStyle(focused ? Nocturne.neutral400 : Nocturne.neutral500)
                .lineLimit(1)
                .padding(.top, 4)
        }
        .frame(width: 340, alignment: .leading)
        .opacity(focused ? 1 : 0.86)
        .scaleEffect(focused ? 1.04 : 1, anchor: .top)
        .offset(y: focused ? -8 : 0)
        .animation(.easeOut(duration: 0.15), value: focused)
    }
}
