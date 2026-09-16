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

    /// The entries of one tab, in the server's order.
    func continueEntries(for tab: LibraryTab) -> [ContinueEntry] {
        continueWatching.filter { $0.kind == tab.continueKind }
    }

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

    private func thumbs(_ fileId: Int) async -> FileThumbs? {
        do { return try await api.thumbs(fileId: fileId) } catch {
            EvidenceLog.line("[thumbs] continue-watching file \(fileId): \((error as? APIError)?.localizedDescription ?? String(describing: error))")
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
