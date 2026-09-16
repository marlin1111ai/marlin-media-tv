//
//  LibraryModel.swift
//  Marlin Media TV
//
//  The library's three lists, loaded together. A failure of any one of them is the whole
//  library's failure and is shown in full (frame 17); nothing is ever silently empty.
//
//  Pass 2 (D023, D025) adds the Recently Added sort and the Continue Watching list. The
//  continue-watching list is *not* part of the library's success: if that one call fails the row
//  is simply absent and the failure is a log line, because the library itself is fine.
//
//  Pass 3 (D040) adds what Home needs: every show's episodes (the shows list carries none), and
//  the three Home rows with their orders.
//

import Foundation
import Observation

enum LibraryTab: String, CaseIterable, Hashable {
    case movies = "Movies"
    case shows = "TV Shows"
    case videos = "Videos"

    /// The continue-watching kind this tab shows (D025: each tab shows only its own kind).
    var continueKind: ContinueEntry.Kind {
        switch self {
        case .movies: return .movie
        case .shows: return .episode
        case .videos: return .video
        }
    }
}

/// Frame 05's control (D010, completed by D023: Recently Added is `added`, newest first).
enum SortOrder: String, CaseIterable, Hashable {
    case title = "Title"
    case year = "Year"
    case recentlyAdded = "Recently Added"
}

/// D040: one episode of one show, as Home's TV Shows row shows it.
struct HomeEpisode: Identifiable, Hashable {
    let show: Show
    let episode: Episode
    var id: Int { episode.file.fileId }
}

@MainActor
@Observable
final class LibraryModel {
    enum Phase: Equatable {
        case loading
        case loaded
        case failed(String, unreachable: Bool)
    }

    let api = APIClient()
    private(set) var phase: Phase = .loading
    private(set) var movies: [Movie] = []
    private(set) var shows: [Show] = []
    private(set) var videos: [Video] = []
    /// D025: the server's in-progress list, in the server's order (newest `last_played` first).
    private(set) var continueWatching: [ContinueEntry] = []
    /// D040: each show with its seasons and episodes — `GET /api/shows` carries none, and Home's
    /// TV row is built from episodes.
    private(set) var showDetails: [Show] = []
    var tab: LibraryTab = .movies
    /// Every tab still opens on Title (D023).
    var sort: SortOrder = .title

    func load() async {
        phase = .loading
        do {
            async let m = api.movies()
            async let s = api.shows()
            async let v = api.videos()
            let (movies, shows, videos) = try await (m, s, v)
            self.movies = movies
            self.shows = shows
            self.videos = videos
            phase = .loaded
            print("[library] loaded \(movies.count) movies, \(shows.count) shows, \(videos.count) videos from \(ServerConfig.baseURL)")
        } catch let error as APIError {
            print("[library] failed: \(error.localizedDescription)")
            phase = .failed(error.localizedDescription, unreachable: error.isUnreachable)
        } catch {
            print("[library] failed: \(error)")
            phase = .failed(String(describing: error), unreachable: false)
        }
        await refreshContinueWatching()
        await refreshShowDetails()
    }

    /// D040: everything again — the three lists, the in-progress list and every show's episodes.
    /// Home asks for this each time it appears, including on the way back from the player. It does
    /// nothing while the first load is still running, and a failure keeps what is already on screen
    /// rather than emptying it.
    func refresh() async {
        if case .loading = phase { return }
        do {
            async let m = api.movies()
            async let s = api.shows()
            async let v = api.videos()
            let (movies, shows, videos) = try await (m, s, v)
            self.movies = movies
            self.shows = shows
            self.videos = videos
            phase = .loaded
        } catch {
            let detail = (error as? APIError)?.localizedDescription ?? String(describing: error)
            EvidenceLog.line("[home] refresh failed, keeping what is on screen: \(detail)")
        }
        await refreshContinueWatching()
        await refreshShowDetails()
    }

    /// D025: asked for every time the library appears, including on the way back from the player,
    /// so a position written during playback is on the row at once.
    func refreshContinueWatching() async {
        do {
            let entries = try await api.continueWatching()
            continueWatching = entries
            EvidenceLog.line("[continue] \(entries.count) entries: \(entries.map { "\($0.kind.rawValue)/\($0.fileId)@\(Int($0.playback.position))s" }.joined(separator: ", "))")
        } catch {
            let detail = (error as? APIError)?.localizedDescription ?? String(describing: error)
            EvidenceLog.line("[continue] failed, the row is not shown: \(detail)")
            continueWatching = []
        }
    }

    /// D040: one `GET /api/shows/{id}` per show, together, for Home's TV row. A show that fails is
    /// left out of the row rather than failing the screen.
    func refreshShowDetails() async {
        let list = shows
        guard !list.isEmpty else { showDetails = []; return }
        let api = self.api
        let details = await withTaskGroup(of: Show?.self) { group -> [Show] in
            for show in list {
                group.addTask { try? await api.show(id: show.id) }
            }
            var out: [Show] = []
            for await detail in group { if let detail { out.append(detail) } }
            return out
        }
        showDetails = details.sorted { $0.id < $1.id }
        EvidenceLog.line("[home] \(showDetails.count) of \(list.count) shows detailed for the TV row")
    }

    /// The entries of one tab, in the server's order.
    func continueEntries(for tab: LibraryTab) -> [ContinueEntry] {
        continueWatching.filter { $0.kind == tab.continueKind }
    }

    // MARK: - Home rows (D040)

    static let homeRowLimit = 6

    private func inProgress(_ file: MediaInfo) -> Bool {
        file.playback.position > 0 && !file.playback.watched
    }

    /// The latest `last_played` of any of a movie's editions.
    private func lastPlayed(_ movie: Movie) -> Date {
        movie.editions.map { Format.rfc3339($0.file.playback.lastPlayed) }.max() ?? .distantPast
    }

    /// D040: in-progress movies first (most recently played first), then the rest by title.
    var homeMovies: [Movie] {
        let started = movies.filter { m in m.editions.contains { inProgress($0.file) } }
            .sorted { lastPlayed($0) > lastPlayed($1) }
        let startedIds = Set(started.map(\.id))
        let rest = movies.filter { !startedIds.contains($0.id) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return Array((started + rest).prefix(Self.homeRowLimit))
    }

    /// D040: in-progress videos first (most recently played first), then the rest by title.
    var homeVideos: [Video] {
        let started = videos.filter { inProgress($0.file) }
            .sorted { Format.rfc3339($0.file.playback.lastPlayed) > Format.rfc3339($1.file.playback.lastPlayed) }
        let startedIds = Set(started.map(\.id))
        let rest = videos.filter { !startedIds.contains($0.id) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        return Array((started + rest).prefix(Self.homeRowLimit))
    }

    /// D040, the TV row's order: the episodes in progress (newest watched first); then, for each
    /// show, the next episode after the last one it finished; then on down each show, a step at a
    /// time, until the row is full. A show never watched joins from its first episode, after the
    /// shows that have been watched.
    var homeEpisodes: [HomeEpisode] {
        func ordered(_ show: Show) -> [Episode] {
            (show.seasons ?? []).flatMap(\.episodes)
                .sorted { ($0.season, $0.number) < ($1.season, $1.number) }
        }

        var row: [HomeEpisode] = []
        var taken = Set<Int>()

        // 1 — everything in progress, most recently played first.
        let started = showDetails.flatMap { show in
            ordered(show).filter { inProgress($0.file) }.map { HomeEpisode(show: show, episode: $0) }
        }
        .sorted {
            Format.rfc3339($0.episode.file.playback.lastPlayed) > Format.rfc3339($1.episode.file.playback.lastPlayed)
        }
        for item in started where row.count < Self.homeRowLimit {
            row.append(item); taken.insert(item.id)
        }

        // 2 — the shows themselves: those with any history first, most recent first, then the rest
        // by title.
        func history(_ show: Show) -> Date {
            ordered(show).map { Format.rfc3339($0.file.playback.lastPlayed) }.max() ?? .distantPast
        }
        let watched = showDetails.filter { history($0) > .distantPast }.sorted { history($0) > history($1) }
        let fresh = showDetails.filter { history($0) == .distantPast }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }

        // 3 — from after each show's last finished episode, a step at a time across the shows.
        let queues: [[HomeEpisode]] = (watched + fresh).map { show in
            let episodes = ordered(show)
            let lastFinished = episodes.lastIndex { $0.file.playback.watched }
            let start = lastFinished.map { $0 + 1 } ?? 0
            guard start < episodes.count else { return [] }
            return episodes[start...].map { HomeEpisode(show: show, episode: $0) }
        }

        var depth = 0
        while row.count < Self.homeRowLimit {
            var addedOne = false
            for queue in queues where row.count < Self.homeRowLimit {
                guard depth < queue.count else { continue }
                let item = queue[depth]
                guard !taken.contains(item.id) else { addedOne = true; continue }
                row.append(item); taken.insert(item.id); addedOne = true
            }
            if !addedOne { break }
            depth += 1
        }
        return row
    }

    // MARK: - Opening things

    /// D025: a Continue Watching card plays its file straight away — no detail screen and no
    /// edition picker. The entry itself carries no path, HDR flag or codecs, so the item's detail
    /// is fetched for the real `MediaInfo` (D014's `.mkv` rule and D016's display match both need
    /// it), and then the file's thumbnail index, exactly as a detail screen would (D021).
    func playRequest(for entry: ContinueEntry) async -> PlayRequest? {
        do {
            switch entry.kind {
            case .movie:
                guard let id = entry.movieId else { return nil }
                let movie = try await api.movie(id: id)
                guard let edition = movie.editions.first(where: { $0.file.fileId == entry.fileId }) else {
                    EvidenceLog.line("[continue] file \(entry.fileId) is no longer an edition of movie \(id)")
                    return nil
                }
                return PlayRequest.movie(movie, edition: edition, thumbs: await thumbs(entry.fileId), resume: true)
            case .episode:
                guard let id = entry.showId else { return nil }
                let show = try await api.show(id: id)
                let episodes = (show.seasons ?? []).flatMap(\.episodes)
                guard let episode = episodes.first(where: { $0.file.fileId == entry.fileId }) else {
                    EvidenceLog.line("[continue] file \(entry.fileId) is no longer an episode of show \(id)")
                    return nil
                }
                return PlayRequest.episode(episode, of: show, thumbs: await thumbs(entry.fileId), resume: true)
            case .video:
                guard let video = try await api.videos().first(where: { $0.file.fileId == entry.fileId }) else {
                    EvidenceLog.line("[continue] file \(entry.fileId) is no longer a video")
                    return nil
                }
                return PlayRequest.video(video, thumbs: await thumbs(entry.fileId), resume: true)
            }
        } catch {
            let detail = (error as? APIError)?.localizedDescription ?? String(describing: error)
            EvidenceLog.line("[continue] could not open file \(entry.fileId): \(detail)")
            return nil
        }
    }

    /// D040: a card in Home's TV row plays its episode, resuming where it was left.
    func playRequest(for item: HomeEpisode) async -> PlayRequest? {
        PlayRequest.episode(item.episode, of: item.show, thumbs: await thumbs(item.episode.file.fileId), resume: true)
    }

    private func thumbs(_ fileId: Int) async -> FileThumbs? {
        do { return try await api.thumbs(fileId: fileId) } catch {
            EvidenceLog.line("[thumbs] file \(fileId): \((error as? APIError)?.localizedDescription ?? String(describing: error))")
            return nil
        }
    }

    private func byTitle<T>(_ items: [T], _ title: (T) -> String) -> [T] {
        items.sorted { title($0).localizedStandardCompare(title($1)) == .orderedAscending }
    }

    var sortedMovies: [Movie] {
        switch sort {
        case .title: return byTitle(movies, \.title)
        case .year: return movies.sorted { ($0.year ?? Int.min) > ($1.year ?? Int.min) }
        case .recentlyAdded: return movies.sorted { Format.addedAt($0.added) > Format.addedAt($1.added) }
        }
    }

    var sortedShows: [Show] {
        switch sort {
        case .title: return byTitle(shows, \.title)
        case .year: return shows.sorted { ($0.year ?? Int.min) > ($1.year ?? Int.min) }
        // D023: a show sorts by the show's own `added`; the server exposes no per-episode date.
        case .recentlyAdded: return shows.sorted { Format.addedAt($0.added) > Format.addedAt($1.added) }
        }
    }

    var sortedVideos: [Video] {
        switch sort {
        case .title: return byTitle(videos, \.title)
        case .year: return videos.sorted { ($0.year ?? Int.min) > ($1.year ?? Int.min) }
        case .recentlyAdded: return videos.sorted { Format.addedAt($0.added) > Format.addedAt($1.added) }
        }
    }
}
