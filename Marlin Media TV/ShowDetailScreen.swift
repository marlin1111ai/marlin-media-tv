//
//  ShowDetailScreen.swift
//  Marlin Media TV
//
//  Frame 08: season selector, episode list with still, number, title, duration and synopsis.
//  Selecting an episode plays it. The watched/"N min left" column is a later pass (D009).
//  Seasons and episodes come from GET /api/shows/{id}; its failure is shown in full.
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .task { await load() }
    }

    private func load() async {
        phase = .loading
        do {
            let detail = try await api.show(id: show.id)
            seasonId = detail.seasons?.first?.id
            phase = .loaded(detail)
            print("[show] loaded \(detail.title): \(detail.seasons?.count ?? 0) seasons")
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
                    guard let request = PlayRequest.episode(episode, of: show) else {
                        playError = "The server gave no usable stream URL for E\(episode.number): \(episode.file.stream)"
                        return
                    }
                    play(request)
                } label: {
                    EpisodeRowLabel(episode: episode)
                }
                .buttonStyle(BareButtonStyle())
                .accessibilityIdentifier("episode.\(episode.season).\(episode.number)")
            }
        }
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

/// Frame 08's episode row.
private struct EpisodeRowLabel: View {
    let episode: Episode
    @Environment(\.isFocused) private var focused

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
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .background(focused ? Nocturne.accent.opacity(0.18) : Nocturne.surface.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? Nocturne.accent : Nocturne.panelRule, lineWidth: focused ? 2 : 1))
    }
}
