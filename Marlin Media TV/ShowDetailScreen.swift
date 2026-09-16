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
//  saved position; and press-and-hold opens the mark overlay. Where a file's length is unknown
//  there is no "N min left" and no bar.
//

import SwiftUI

struct ShowDetailScreen: View {
    let show: Show
    let api: APIClient
    let play: (PlayRequest) -> Void

    private enum Phase: Equatable { case loading, loaded(Show), failed(String) }
    @State private var phase: Phase = .loading
    @State private var seasonId: Int?
    @State private var playError: String?
    @State private var thumbs: FileThumbs?
    /// D027: the episode whose press-and-hold menu is open.
    @State private var holdEpisode: Episode?
    @FocusState private var focusedSeason: Int?

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
        .ignoresSafeArea()
        .task { await load() }
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

    private func episodes(detail: Show) -> some View {
        let season = detail.seasons?.first { $0.id == seasonId } ?? detail.seasons?.first
        return VStack(spacing: 8) {
            ForEach(season?.episodes ?? []) { episode in
                Button {
                    start(episode)
                } label: {
                    EpisodeRowLabel(episode: episode)
                }
                .buttonStyle(BareButtonStyle())
                .accessibilityIdentifier("episode.\(episode.season).\(episode.number)")
                // D027: press-and-hold on the row opens the mark menu.
                .onLongPressGesture(minimumDuration: 0.6) { holdEpisode = episode }
            }
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
            await load()
        }
    }

    /// D027: a row with a saved position resumes there; one without plays from the start.
    private func start(_ episode: Episode) {
        guard let request = PlayRequest.episode(episode, of: show, thumbs: thumbs, resume: true) else {
            playError = "The server gave no usable stream URL for E\(episode.number): \(episode.file.stream)"
            return
        }
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
private struct EpisodeRowLabel: View {
    let episode: Episode
    @Environment(\.isFocused) private var focused

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
