//
//  HomeScreen.swift
//  Marlin Media TV
//
//  Frames 00, 00b and 00c — the screen the app opens on (D040).
//
//  Top: MARLIN, then Movies / TV Shows / Videos, which open that library tab; Menu there comes
//  back here. Then the rows, each heading a kicker and each row scrolling sideways:
//   - **Continue watching** — every in-progress movie, episode and video mixed, newest first, the
//     same cards the library tabs use. Hidden when there is nothing in progress (frame 00c).
//   - **Movies · N** — up to six, in-progress first and then by title; opens the movie screen.
//   - **TV Shows · N** — up to six episodes in the frames' wide card, each with its own still, the
//     show's title and "S# E# · episode title"; plays that episode, resuming if it has a spot.
//   - **Videos · N** — up to six, in-progress first and then by title; opens the video screen. The
//     heading shows even when there are none.
//  The clock (D041) sits where the frames put it, at the top right.
//
//  The rows scroll **clipped**: with clipping disabled they drew over the pinned header when the
//  screen scrolled. The horizontal rows keep their unclipped edges, so a focused card's lift and
//  glow are not cut off.
//

import SwiftUI

struct HomeScreen: View {
    @Bindable var model: LibraryModel
    /// D032: ContentView's count of player closes — Home re-reads itself on every one.
    let playerClosed: Int
    let openTab: (LibraryTab) -> Void
    let open: (Destination) -> Void
    let playEntry: (ContinueEntry) -> Void
    let playEpisode: (HomeEpisode) -> Void

    @FocusState private var focusedTab: LibraryTab?
    /// D043: which Continue Watching card has focus, so that the first one can be given it when the
    /// app opens.
    @FocusState private var focusedCard: Int?
    /// D043: the launch focus is placed once in a session, and never again.
    @State private var launchFocusPlaced = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Nocturne.libraryGround
            switch model.phase {
            case .loading:
                header
                HStack(spacing: 20) {
                    ProgressView().tint(Nocturne.accent)
                    Text("Loading library from \(ServerConfig.host)…")
                        .font(.nocturne(26)).foregroundStyle(Nocturne.neutral500)
                }
                .padding(.leading, 80)
                .padding(.top, 1080 - 96 - 34)
            case let .failed(message, unreachable):
                LibraryErrorView(message: message, unreachable: unreachable) {
                    Task { await model.load() }
                }
            case .loaded:
                VStack(alignment: .leading, spacing: 0) {
                    header
                    rows
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // D041: the clock goes on before `ignoresSafeArea`, so it sits at the frame's own top right
        // — 56 pt down and 80 pt in, as the frames draw it — rather than inside tvOS's safe area.
        .overlay(alignment: .topTrailing) {
            NowClock().padding(.trailing, 80).padding(.top, 56)
        }
        .ignoresSafeArea()
        // D040: Home is re-read every time it appears, and every time the player closes.
        .onAppear { Task { await model.refresh() }; placeLaunchFocus() }
        .onChange(of: playerClosed) { _, _ in Task { await model.refresh() } }
        // D043: the in-progress list arrives after the first appearance, so the cards exist only
        // once it has — that is where the launch focus is placed.
        .onChange(of: model.continueWatching.count) { _, _ in placeLaunchFocus() }
    }

    /// D043: when the app opens, focus lands on the **first** Continue Watching card, as frame 00
    /// draws it. It is placed once in a session — on the first list Home receives — so moving along
    /// the row, coming back from the player and every later re-read are untouched. **With nothing in
    /// progress there is no row and nothing is placed:** the focus engine keeps today's behaviour.
    ///
    /// The card is asked for until it takes focus, because the focus engine ignores a request for a
    /// view that is not on screen yet and the row is built from a list that has just arrived. The
    /// loop stops the moment any card of the row holds focus, so a viewer who moves first is not
    /// pulled back.
    private func placeLaunchFocus() {
        guard !launchFocusPlaced, let first = model.continueWatching.first?.fileId else { return }
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

    /// Frames 00/00b/00c: MARLIN, then the three library buttons.
    private var header: some View {
        HStack(spacing: 60) {
            Wordmark()
            HStack(spacing: 16) {
                ForEach(LibraryTab.allCases, id: \.self) { tab in
                    Button { openTab(tab) } label: {
                        HomeTabLabel(title: tab.rawValue)
                    }
                    .buttonStyle(BareButtonStyle())
                    .focused($focusedTab, equals: tab)
                    .accessibilityIdentifier("home.tab.\(tab.rawValue)")
                }
            }
        }
        .padding(.top, 52)
        .padding(.horizontal, 80)
    }

    private var rows: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 36) {
                if !model.continueWatching.isEmpty {
                    HomeRow(heading: "Continue watching") {
                        ForEach(model.continueWatching) { entry in
                            Button { playEntry(entry) } label: {
                                ContinueCardLabel(entry: entry)
                            }
                            .buttonStyle(BareButtonStyle())
                            .accessibilityIdentifier("home.continue.\(entry.fileId)")
                            .focused($focusedCard, equals: entry.fileId)
                        }
                    }
                }
                HomeRow(heading: "Movies · \(model.movies.count)") {
                    ForEach(model.homeMovies) { movie in
                        PosterCard(title: movie.title, year: movie.year, poster: movie.artwork.poster,
                                   badges: badges(movie.editions.first?.file)) {
                            open(.movie(movie))
                        }
                        .accessibilityIdentifier("home.movie.\(movie.title)")
                    }
                }
                HomeRow(heading: "TV Shows · \(model.shows.count)") {
                    ForEach(model.homeEpisodes) { item in
                        Button { playEpisode(item) } label: {
                            WideCardLabel(still: item.episode.artwork.still,
                                          title: item.show.title,
                                          subtitle: "S\(item.episode.season) E\(item.episode.number) · \(item.episode.displayTitle)",
                                          fallbackInitial: item.show.title)
                        }
                        .buttonStyle(BareButtonStyle())
                        .accessibilityIdentifier("home.episode.\(item.episode.season).\(item.episode.number)")
                    }
                }
                HomeRow(heading: "Videos · \(model.videos.count)") {
                    ForEach(model.homeVideos) { video in
                        Button { open(.video(video)) } label: {
                            WideCardLabel(still: video.artwork.backdrop ?? video.artwork.poster ?? video.artwork.still,
                                          title: video.title,
                                          subtitle: videoSpec(video),
                                          fallbackInitial: video.title)
                        }
                        .buttonStyle(BareButtonStyle())
                        .accessibilityIdentifier("home.video.\(video.title)")
                    }
                }
            }
            .padding(.top, 46)
            .padding(.leading, 80)
            .padding(.trailing, 80)
            .padding(.bottom, 80)
        }
    }

    private func videoSpec(_ video: Video) -> String {
        let parts = [video.file.resolutionLabel, video.file.videoCodec.map(Format.videoCodec)].compactMap { $0 }
        return (parts + [Format.clock(video.file.duration ?? 0)]).joined(separator: " · ")
    }

    private func badges(_ file: MediaInfo?) -> [(String, Bool)] {
        guard let file else { return [] }
        var out: [(String, Bool)] = []
        if file.resolutionLabel == "4K" { out.append(("4K", false)) }
        if file.hdr { out.append(("HDR", true)) }
        return out
    }
}

/// One Home row: the frames' kicker, then the cards side by side.
private struct HomeRow<Content: View>: View {
    let heading: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Kicker(text: heading)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 32) {
                    content()
                }
                .padding(.vertical, 8)
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }
}

/// Frames 00/00b/00c: a library button on Home — outlined when it has no focus, and the accent
/// tint, border and glow when it does.
private struct HomeTabLabel: View {
    let title: String
    @Environment(\.isFocused) private var focused

    var body: some View {
        Text(title)
            .font(.nocturne(30, .medium))
            .foregroundStyle(focused ? Nocturne.accent100 : Nocturne.neutral300)
            .lineLimit(1)
            .padding(.vertical, focused ? 13 : 15)
            .padding(.horizontal, 32)
            .background(focused ? Nocturne.accent.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? Nocturne.accent : Nocturne.neutral700,
                                                              lineWidth: focused ? 3 : 1))
            .shadow(color: focused ? Nocturne.accent.opacity(0.34) : .clear, radius: 22)
    }
}

/// Frame 00b's wide card (340 × 191), used by Home's TV Shows and Videos rows.
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
