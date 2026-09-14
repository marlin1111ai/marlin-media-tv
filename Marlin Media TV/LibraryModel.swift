//
//  LibraryModel.swift
//  Marlin Media TV
//
//  The library's three lists, loaded together. A failure of any one of them is the whole
//  library's failure and is shown in full (frame 17); nothing is ever silently empty.
//

import Foundation
import Observation

enum LibraryTab: String, CaseIterable, Hashable {
    case movies = "Movies"
    case shows = "TV Shows"
    case videos = "Videos"
}

/// Frame 05's control, limited to Title and Year in this pass (DECISIONS.md D010 lists Recently Added for a later pass).
enum SortOrder: String, CaseIterable, Hashable {
    case title = "Title"
    case year = "Year"
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
    var tab: LibraryTab = .movies
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
    }

    var sortedMovies: [Movie] {
        switch sort {
        case .title: return movies.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .year: return movies.sorted { ($0.year ?? Int.min) > ($1.year ?? Int.min) }
        }
    }

    var sortedShows: [Show] {
        switch sort {
        case .title: return shows.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .year: return shows.sorted { ($0.year ?? Int.min) > ($1.year ?? Int.min) }
        }
    }

    var sortedVideos: [Video] {
        switch sort {
        case .title: return videos.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .year: return videos.sorted { ($0.year ?? Int.min) > ($1.year ?? Int.min) }
        }
    }
}
