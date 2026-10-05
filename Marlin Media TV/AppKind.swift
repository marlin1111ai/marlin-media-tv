//
//  AppKind.swift
//  Marlin Media TV
//
//  Five apps share this code, one per kind of the one Marlin Media server (owner, 2026-10-04):
//  Marlin Movies, Marlin TV Shows, Marlin Videos, Marlin Music and Marlin Adult. Each target names
//  its kind in its Info.plist (`MarlinApp`, filled from the `MARLIN_APP` build setting) and loads
//  only that kind. Marlin Adult is Marlin Movies on the server's `/api/adult/` routes.
//

import Foundation

nonisolated enum AppKind: String, Sendable {
    case movies, shows, videos, music, adult

    /// The kind this app was built as. A missing or unknown value stops the app at launch rather
    /// than opening the wrong library.
    static let current: AppKind = {
        let value = Bundle.main.object(forInfoDictionaryKey: "MarlinApp") as? String
        guard let value, let kind = AppKind(rawValue: value) else {
            fatalError("Info.plist key MarlinApp is \(value ?? "missing"); expected movies, shows, videos, music or adult")
        }
        return kind
    }()

    /// The word beside MARLIN in the header.
    var section: String {
        switch self {
        case .movies: return "Movies"
        case .shows: return "TV Shows"
        case .videos: return "Videos"
        case .music: return "Music"
        case .adult: return "Adult"
        }
    }

    /// The first screen's tabs. An app with one has no tab bar.
    @MainActor var tabs: [LibraryTab] {
        switch self {
        case .movies, .adult: return [.movies]
        case .shows: return [.shows]
        case .videos: return [.videos]
        case .music: return [.albums, .artists]
        }
    }
}
