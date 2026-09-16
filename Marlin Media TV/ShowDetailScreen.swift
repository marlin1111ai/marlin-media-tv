//
//  ShowDetailScreen.swift
//  Marlin Media TV
//
//  Frame 08: season selector, episode list with still, number, title, duration and synopsis.
//  Seasons and episodes come from GET /api/shows/{id}; its failure is shown in full.
//
//  Pass 2 (D027): "N unwatched" at the end of the meta row counts every episode of the show not
//  marked watched (a partly watched one counts as unwatched); each row's right-hand column reads
//  "Watched ✓", "N min left" with the bar across its still, or "Unwatched"; a click resumes at the
//  saved position; and press-and-hold opens the mark menu. Where a file's length is unknown there
//  is no "N min left" and no bar.
//
//  Pass 2c (D031): an episode row is a focusable view, not a Button, so the select press reaches
//  the row's own gesture rather than a Button that swallows it.
//
//  Pass 3 (D039): two fixes to that row.
//   - **The highlight is back.** A plain `.focusable()` view does not put `isFocused` into its
//     child's environment the way a Button's style does, so `EpisodeRowLabel` saw `false` and drew
//     nothing. The row now takes `focused:` explicitly from `@FocusState`; the drawing itself is
//     the pass 2/2b row, unchanged.
//   - **The hold is decided by the press's own length.** The press-down instant is remembered and
//     the release is judged against it: past the threshold opens the mark menu and plays nothing,
//     shorter plays or resumes. Pass 2c raced SwiftUI's callbacks instead — `onPressingChanged`
//     arrives before `perform`, so the release was taken as a click and started playback. The
//     pass 2c press-down/press-up instrumentation is removed.
//
//  Pass 2b (D032): the screen re-reads itself whenever the player closes.
//

import SwiftUI

struct ShowDetailScreen: View {
    let show: Show
    let api: APIClient
    /// D032: ContentView's count of player closes.
    let playerClosed: Int
    let play: (PlayRequest) -> Void

    private enum Phase: Equatable { case loading, loaded(Show), failed(String) }
    @State private var phase: Phase = .loading
    @State private var seasonId: Int?
    @State private var playError: String?
    @State private var thumbs: FileThumbs?
    /// D027: the episode whose press-and-hold menu is open.
    @State private var holdEpisode: Episode?
    /// D031/D039: the row the remote is on, when the press began, and whether the player is up.
    @FocusState private var focusedEpisode: Int?
    @State private var pressDown: Date?
    @State private var playerUp = false
    @FocusState private var focusedSeason: Int?

    /// D039: held at least this long and the press is a hold, not a click.
    private static let holdSeconds = 0.6

    var body: some View {
        ZStack(alignment: .topLeading) {
            DetailBackdrop(path: show.artwork.backdrop)
            switch phase {
            case .loading:
                header(detail: nil)
                    .padding(.horizontal, 80)
                    .padding(.top, 44)
                HStack(spacing: 20) {
                    ProgressView().tint(Nocturne.accent)
                    Text("Loading seasons from \(ServerConfig.host)…")
                        .font(.nocturne(26)).foregroundStyle(Nocturne.neutral500)
                }
                .padding(.leading, 80)
                .padding(.top, 1080 - 96 - 34)
            case let .failed(message):
                LibraryErrorView(message: message, unreachable: false) { Task { await load() } }
            case let .loaded(detail):
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        header(detail: detail)
                        episodes(detail: detail)
                            .padding(.top, 10)
                    }
                    .padding(.horizontal, 80)
                    .padding(.top, 44)
                    .padding(.bottom, 80)
                }
                .scrollClipDisabled()
            }
            if let holdEpisode {
                markMenu(for: holdEpisode).zIndex(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // D041: the clock, as the new frame 08 draws it — before `ignoresSafeArea`, so it lands at
        // the frame's own top right.
        .overlay(alignment: .topTrailing) { NowClock().padding(.trailing, 80).padding(.top, 56) }
        .ignoresSafeArea()
        .task { await load() }
        .onChange(of: playerClosed) { _, _ in
            // D032: the player has closed — the positions it wrote are now the server's truth.
            playerUp = false
            Task { await reload() }
        }
    }

    private var loadedDetail: Show? {
        if case let .loaded(detail) = phase { return detail }
        return nil
    }

    /// D027: every episode of the show that is not marked watched, partly watched included.
    private func unwatchedCount(_ detail: Show) -> Int {
        (detail.seasons ?? []).flatMap(\.episodes).filter { !$0.file.playback.watched }.count
    }

    private func load() async {
        phase = .loading
        do {
            let detail = try await api.show(id: show.id)
            seasonId = seasonId ?? detail.seasons?.first?.id
            phase = .loaded(detail)
            print("[show] loaded \(detail.title): \(detail.seasons?.count ?? 0) seasons")
            // Pass 2g: one index request per screen, for the file that would play — the first
            // episode of the first season. Any other episode plays without thumbnails.
            if thumbs == nil, let file = detail.seasons?.first?.episodes.first?.file {
                do {
                    thumbs = try await api.thumbs(fileId: file.fileId)
                } catch {
                    print("[thumbs] \(show.title): \((error as? APIError)?.localizedDescription ?? String(describing: error))")
                }
            }
        } catch {
            let message = (error as? APIError)?.localizedDescription ?? String(describing: error)
            print("[show] failed: \(message)")
            phase = .failed(message)
        }
    }

    /// D032: re-read without the loading screen, so the list does not flash on the way back from
    /// the player or after a mark. The chosen season is kept.
    private func reload() async {
        do {
            let detail = try await api.show(id: show.id)
            seasonId = seasonId ?? detail.seasons?.first?.id
            phase = .loaded(detail)
            EvidenceLog.line("[detail] show \(show.id) re-read: \(unwatchedCount(detail)) unwatched")
        } catch {
            EvidenceLog.line("[detail] could not re-read show \(show.id): \((error as? APIError)?.localizedDescription ?? String(describing: error))")
        }
    }

    private func header(detail: Show?) -> some View {
        HStack(alignment: .top, spacing: 48) {
            ServerImage(path: show.artwork.poster) { InitialTile(title: show.title, fontSize: 84) }
                .frame(width: 210, height: 315)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Nocturne.neutral700, lineWidth: 1))
                .shadow(color: .black.opacity(0.6), radius: 25, y: 20)
            VStack(alignment: .leading, spacing: 0) {
                Text(show.title)
                    .font(.nocturne(72, .medium))
                    .kerning(-1.4)
                    .foregroundStyle(Nocturne.accent100)
                    .lineLimit(2)
                    .accessibilityIdentifier("detail.title")
                HStack(spacing: 18) {
                    if let years = Format.year(fromDate: show.firstAirDate) ?? show.year.map(String.init) { Text(years) }
                    Dot()
                    Text("\(show.seasonCount) season\(show.seasonCount == 1 ? "" : "s") · \(show.episodeCount) episode\(show.episodeCount == 1 ? "" : "s")")
                    if !show.genres.isEmpty {
                        Dot()
                        Text(Format.genres(show.genres))
                    }
                    // D027: frame 08's count, at the end of the meta row.
                    if let detail {
                        let unwatched = unwatchedCount(detail)
                        if unwatched > 0 {
                            Dot()
                            Text("\(unwatched) unwatched")
                                .foregroundStyle(Nocturne.accent400)
                                .accessibilityIdentifier("show.unwatched")
                        }
                    }
                }
                .font(.nocturne(24))
                .foregroundStyle(Nocturne.neutral300)
                .padding(.top, 18)
                if let overview = show.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.nocturne(25))
                        .lineSpacing(25 * 0.5)
                        .foregroundStyle(Nocturne.neutral400)
                        .lineLimit(3)
                        .frame(maxWidth: 1000, alignment: .leading)
                        .padding(.top, 22)
                }
                if let seasons = detail?.seasons {
                    HStack(spacing: 16) {
                        ForEach(seasons) { season in
                            Button { seasonId = season.id } label: {
                                SeasonLabel(title: season.name ?? "Season \(season.number)", selected: seasonId == season.id)
                            }
                            .buttonStyle(BareButtonStyle())
                            .focused($focusedSeason, equals: season.id)
                            .accessibilityIdentifier("season.\(season.number)")
                        }
                    }
                    .padding(.top, 34)
                }
                if let playError {
                    Text(playError).font(.nocturne(22)).foregroundStyle(Nocturne.accent300).padding(.top, 16)
                }
            }
            .frame(maxWidth: 1300, alignment: .leading)
        }
    }

    /// D031: each row is a focusable view rather than a Button, so the select press reaches the
    /// row's own gesture. D039: the highlight comes from `@FocusState`, not the environment.
    private func episodes(detail: Show) -> some View {
        let season = detail.seasons?.first { $0.id == seasonId } ?? detail.seasons?.first
        return VStack(spacing: 8) {
            ForEach(season?.episodes ?? []) { episode in
                EpisodeRowLabel(episode: episode, focused: focusedEpisode == episode.id)
                    .focusable()
                    .focused($focusedEpisode, equals: episode.id)
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("episode.\(episode.season).\(episode.number)")
                    // D039: this gesture is here only to report the press. Its own minimum is set
                    // far beyond any real press, so SwiftUI never ends the press at the threshold
                    // itself — pass 2c measured the release at 601 ms against a 600 ms minimum,
                    // a race the comparison below cannot reliably win. With the minimum out of
                    // reach, the release is the real one and its length decides.
                    .onLongPressGesture(minimumDuration: 3600) {
                        // never fires
                    } onPressingChanged: { pressing in
                        pressChanged(episode, pressing: pressing)
                    }
            }
        }
    }

    /// D039: the press decides itself. Down is remembered; the release is measured against it.
    private func pressChanged(_ episode: Episode, pressing: Bool) {
        if pressing {
            pressDown = Date()
            return
        }
        let held = pressDown.map { Date().timeIntervalSince($0) } ?? 0
        pressDown = nil
        guard holdEpisode == nil, !playerUp else { return }
        if held >= Self.holdSeconds {
            holdEpisode = episode
            EvidenceLog.line("[hold] menu for S\(episode.season)E\(episode.number) file \(episode.file.fileId) after \(Int(held * 1000)) ms (watched=\(episode.file.playback.watched))")
        } else {
            start(episode)
        }
    }

    /// D027: the mark menu, in the edition picker's style (frame 07).
    private func markMenu(for episode: Episode) -> some View {
        let watched = episode.file.playback.watched
        return ZStack {
            Color(red: 11 / 255, green: 12 / 255, blue: 19 / 255).opacity(0.74)
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    Kicker(text: "Episode")
                    Text("S\(episode.season) E\(episode.number) · \(episode.displayTitle)")
                        .font(.nocturne(42, .medium))
                        .foregroundStyle(Nocturne.accent100)
                        .lineLimit(2)
                }
                .padding(.top, 38).padding(.horizontal, 44).padding(.bottom, 28)
                Button {
                    mark(episode, watched: !watched)
                } label: {
                    MarkRowLabel(title: watched ? "Mark unwatched" : "Mark watched")
                }
                .buttonStyle(BareButtonStyle())
                .accessibilityIdentifier("episode.mark")
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
        .onExitCommand { holdEpisode = nil }
    }

    /// D027: the same writes as the detail screens — position 0, and the watched flag either way.
    private func mark(_ episode: Episode, watched: Bool) {
        holdEpisode = nil
        Task {
            await PlaybackWrite.send(api, fileId: episode.file.fileId, position: 0, watched: watched,
                                     why: watched ? "mark watched (episode hold)" : "mark unwatched (episode hold)")
            await reload()
        }
    }

    /// D027: a row with a saved position resumes there; one without plays from the start.
    private func start(_ episode: Episode) {
        guard let request = PlayRequest.episode(episode, of: show, thumbs: thumbs, resume: true) else {
            playError = "The server gave no usable stream URL for E\(episode.number): \(episode.file.stream)"
            return
        }
        playerUp = true
        EvidenceLog.line("[episode] click: playing S\(episode.season)E\(episode.number) from \(request.startMs) ms")
        play(request)
    }
}

private struct SeasonLabel: View {
    let title: String
    let selected: Bool
    @Environment(\.isFocused) private var focused

    var body: some View {
        Text(title)
            .font(.nocturne(28, .medium))
            .foregroundStyle(selected || focused ? Nocturne.accent100 : Nocturne.neutral500)
            .padding(.vertical, 13)
            .padding(.horizontal, 34)
            .background(selected ? Nocturne.accent.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected || focused ? Nocturne.accent : .clear, lineWidth: 3))
            .shadow(color: selected ? Nocturne.accent.opacity(0.32) : .clear, radius: 22)
    }
}

/// The mark menu's one row, in the picker row's style.
private struct MarkRowLabel: View {
    let title: String
    @Environment(\.isFocused) private var focused

    var body: some View {
        Text(title)
            .font(.nocturne(30, .medium))
            .foregroundStyle(focused ? Nocturne.accent100 : Nocturne.neutral300)
            .padding(.vertical, 26)
            .padding(.horizontal, 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(focused ? Nocturne.accent.opacity(0.2) : .clear)
            .overlay(alignment: .top) { Rectangle().fill(Nocturne.panelRule).frame(height: 1) }
            .overlay { if focused { Rectangle().stroke(Nocturne.accent, lineWidth: 4).padding(2) } }
    }
}

/// Frame 08's episode row. D027 adds the state column and the bar across the still.
/// D039: `focused` is passed in rather than read from the environment, which a plain focusable
/// view does not provide. The drawing is exactly the pass 2/2b row.
private struct EpisodeRowLabel: View {
    let episode: Episode
    let focused: Bool

    private var playback: Playback { episode.file.playback }
    private var share: Double? { Format.share(position: playback.position, duration: episode.file.duration) }
    private var timeLeft: String? { Format.timeLeft(position: playback.position, duration: episode.file.duration) }

    /// "Watched ✓", "N min left" or "Unwatched" — and nothing at all for a partly watched file
    /// whose length the server does not report, where "N min left" cannot be worked out.
    private var stateText: String? {
        if playback.watched { return "Watched ✓" }
        if playback.position > 0 { return timeLeft }
        return "Unwatched"
    }

    var body: some View {
        HStack(spacing: 26) {
            ServerImage(path: episode.artwork.still) {
                LinearGradient(colors: [Color(hex: 0x2B2741), Color(hex: 0x1B1D2B)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .frame(width: 192, height: 108)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .bottomLeading) {
                Text("E\(episode.number)")
                    .font(.nocturne(22, .medium))
                    .foregroundStyle(Nocturne.text.opacity(0.4))
                    .padding(.leading, 12).padding(.bottom, 10)
            }
            .overlay(alignment: .bottom) {
                // D027: in progress and the length known — frame 08's bar across the still's foot.
                if !playback.watched, playback.position > 0, let share {
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Nocturne.text.opacity(0.2))
                        GeometryReader { geo in
                            Rectangle().fill(Nocturne.accent).frame(width: geo.size.width * share)
                        }
                    }
                    .frame(height: 5)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Nocturne.neutral800, lineWidth: 1))
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text(episode.displayTitle)
                        .font(.nocturne(28, .medium))
                        .foregroundStyle(focused ? Nocturne.accent100 : Nocturne.text)
                        .lineLimit(1)
                    Text(Format.minutes(episode.file.duration))
                        .font(.nocturne(21))
                        .foregroundStyle(Nocturne.neutral600)
                }
                if let overview = episode.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.nocturne(21))
                        .foregroundStyle(Nocturne.neutral500)
                        .lineLimit(2)
                        .frame(maxWidth: 1020, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(stateText ?? "")
                .font(.nocturne(21))
                .foregroundStyle(Nocturne.accent400)
                .frame(width: 190, alignment: .trailing)
                .accessibilityIdentifier("episode.state.\(episode.season).\(episode.number)")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .background(focused ? Nocturne.accent.opacity(0.18) : Nocturne.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? Nocturne.accent : Nocturne.panelRule, lineWidth: focused ? 2 : 1))
    }
}
