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
//  Pass 3 (D040) adds every show's episodes (the shows list carries none) and the order of the
//  next-episode row built from them.
//
//  2026-10-04, the five apps: the model loads **only its own app's kind** (`AppKind`). Marlin TV
//  Shows keeps the next-episode order for its Up next row; Marlin Adult's Continue Watching row is
//  made from its titles' own positions, because the server keeps no continue list for adult; Marlin
//  Music loads albums and artists and has no Continue Watching at all. The combined Home screen
//  and its Movies and Videos rows are gone.
//

import Foundation
import Observation

enum LibraryTab: String, CaseIterable, Hashable {
    case movies = "Movies"
    case shows = "TV Shows"
    case videos = "Videos"
    /// Marlin Music's two.
    case albums = "Albums"
    case artists = "Artists"

    /// The continue-watching kind this tab shows (D025: each tab shows only its own kind). Music
    /// has none.
    var continueKind: ContinueEntry.Kind? {
        switch self {
        case .movies: return .movie
        case .shows: return .episode
        case .videos: return .video
        case .albums, .artists: return nil
        }
    }
}

/// Frame 05's control (D010, completed by D023: Recently Added is `added`, newest first).
enum SortOrder: String, CaseIterable, Hashable {
    case title = "Title"
    case year = "Year"
    case recentlyAdded = "Recently Added"
}

/// D040: one episode of one show, as Marlin TV Shows' Up next row shows it.
struct UpNextEpisode: Identifiable, Hashable {
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

    let kind = AppKind.current
    let api = APIClient()
    private(set) var phase: Phase = .loading
    /// Marlin Movies' movies, and Marlin Adult's titles.
    private(set) var movies: [Movie] = []
    private(set) var shows: [Show] = []
    private(set) var videos: [Video] = []
    private(set) var albums: [Album] = []
    private(set) var artists: [Artist] = []
    /// D025: the server's in-progress list, in the server's order (newest `last_played` first).
    private(set) var continueWatching: [ContinueEntry] = []
    /// D040: each show with its seasons and episodes — `GET /api/shows` carries none, and the
    /// Up next row is built from episodes.
    private(set) var showDetails: [Show] = []
    var tab: LibraryTab = AppKind.current.tabs[0]
    /// Every tab still opens on Title (D023).
    var sort: SortOrder = .title

    func load() async {
        phase = .loading
        do {
            try await fetchLists()
            phase = .loaded
            print("[library] \(kind.rawValue): loaded \(movies.count) movies, \(shows.count) shows, \(videos.count) videos, \(albums.count) albums, \(artists.count) artists from \(ServerConfig.baseURL)")
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

    /// The lists of this app's kind, and no other's.
    private func fetchLists() async throws {
        switch kind {
        case .movies, .adult:
            movies = try await api.movies()
        case .shows:
            shows = try await api.shows()
        case .videos:
            videos = try await api.videos()
        case .music:
            async let a = api.albums()
            async let r = api.artists()
            let (albums, artists) = try await (a, r)
            self.albums = albums
            self.artists = artists
        }
    }

    /// D040: everything again — the app's lists, the in-progress list and every show's episodes.
    /// The first screen asks for this each time it appears, and again on the way back from the
    /// player. It does nothing while the first load is still running, and a failure keeps what is
    /// already on screen rather than emptying it.
    func refresh() async {
        if case .loading = phase { return }
        do {
            try await fetchLists()
            phase = .loaded
        } catch {
            let detail = (error as? APIError)?.localizedDescription ?? String(describing: error)
            EvidenceLog.line("[library] refresh failed, keeping what is on screen: \(detail)")
        }
        await refreshContinueWatching()
        await refreshShowDetails()
    }

    /// D025: asked for every time the library appears, including on the way back from the player,
    /// so a position written during playback is on the row at once.
    func refreshContinueWatching() async {
        switch kind {
        case .music:
            return      // nothing is saved to the server for music, so there is nothing to continue
        case .adult:
            continueWatching = adultContinue()
            EvidenceLog.line("[continue] \(continueWatching.count) entries from the titles' own positions: \(continueWatching.map { "file \($0.fileId)@\(Int($0.playback.position))s" }.joined(separator: ", "))")
            return
        case .movies, .shows, .videos:
            break
        }
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

    /// The server keeps no continue list for adult, so Marlin Adult's row is made here: every
    /// edition with a position and no watched mark, newest `last_played` first.
    private func adultContinue() -> [ContinueEntry] {
        movies.flatMap { movie in movie.editions.filter { inProgress($0.file) }.map { (movie, $0) } }
            .sorted { Format.rfc3339($0.1.file.playback.lastPlayed) > Format.rfc3339($1.1.file.playback.lastPlayed) }
            .map { movie, edition in
                ContinueEntry(kind: .movie, fileId: edition.file.fileId, stream: edition.file.stream,
                              playback: edition.file.playback, duration: edition.file.duration,
                              movieId: movie.id, year: movie.year, edition: edition.name,
                              showId: nil, showTitle: nil, season: nil, episode: nil, videoId: nil,
                              title: movie.title, artwork: movie.artwork)
            }
    }

    /// D040: one `GET /api/shows/{id}` per show, together, for the Up next row. A show that fails
    /// is left out of the row rather than failing the screen. Marlin TV Shows only.
    func refreshShowDetails() async {
        guard kind == .shows else { return }
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
        EvidenceLog.line("[upnext] \(showDetails.count) of \(list.count) shows detailed for the Up next row")
    }

    /// The entries of one tab, in the server's order.
    func continueEntries(for tab: LibraryTab) -> [ContinueEntry] {
        guard let kind = tab.continueKind else { return [] }
        return continueWatching.filter { $0.kind == kind }
    }

    // MARK: - Up next (D040)

    static let upNextLimit = 6

    private func inProgress(_ file: MediaInfo) -> Bool {
        file.playback.position > 0 && !file.playback.watched
    }

    /// Marlin TV Shows' Up next row, in D040's order: for each show, the next episode after the
    /// last one it finished; then on down each show, a step at a time, until the row is full. Shows
    /// with any history come first, most recently watched first, then the rest by title, each from
    /// its first episode. **Episodes in progress are left to the Continue Watching row above it.**
    var upNext: [UpNextEpisode] {
        func ordered(_ show: Show) -> [Episode] {
            (show.seasons ?? []).flatMap(\.episodes)
                .sorted { ($0.season, $0.number) < ($1.season, $1.number) }
        }

        var row: [UpNextEpisode] = []
        var taken = Set(showDetails.flatMap { ordered($0).filter { inProgress($0.file) }.map(\.file.fileId) })

        func history(_ show: Show) -> Date {
            ordered(show).map { Format.rfc3339($0.file.playback.lastPlayed) }.max() ?? .distantPast
        }
        let watched = showDetails.filter { history($0) > .distantPast }.sorted { history($0) > history($1) }
        let fresh = showDetails.filter { history($0) == .distantPast }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }

        let queues: [[UpNextEpisode]] = (watched + fresh).map { show in
            let episodes = ordered(show)
            let lastFinished = episodes.lastIndex { $0.file.playback.watched }
            let start = lastFinished.map { $0 + 1 } ?? 0
            guard start < episodes.count else { return [] }
            return episodes[start...].map { UpNextEpisode(show: show, episode: $0) }
        }

        var depth = 0
        while row.count < Self.upNextLimit {
            var addedOne = false
            for queue in queues where row.count < Self.upNextLimit {
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

    /// D040: a card in the Up next row plays its episode, resuming where it was left.
    func playRequest(for item: UpNextEpisode) async -> PlayRequest? {
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

    // MARK: - Marlin Music

    private func sorted(_ list: [Album]) -> [Album] {
        switch sort {
        case .title: return byTitle(list, \.title)
        case .year: return list.sorted { ($0.year ?? Int.min) > ($1.year ?? Int.min) }
        case .recentlyAdded: return list.sorted { Format.addedAt($0.added) > Format.addedAt($1.added) }
        }
    }

    var sortedAlbums: [Album] { sorted(albums) }

    /// Artists are always by name; the sort control belongs to the albums.
    var sortedArtists: [Artist] { byTitle(artists, \.name) }

    func albums(of artist: Artist) -> [Album] { sorted(albums.filter { $0.artistId == artist.id }) }

    /// An artist has no picture on the server: the card shows the cover of the artist's first
    /// album, by title, that has one.
    func cover(of artist: Artist) -> String? {
        byTitle(albums.filter { $0.artistId == artist.id }, \.title).compactMap(\.cover).first
    }
}
