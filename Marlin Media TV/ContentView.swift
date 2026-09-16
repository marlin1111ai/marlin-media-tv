//
//  ContentView.swift
//  Marlin Media TV
//
//  Pass 3 (D040): **Home is the root.** The three buttons on Home push a library tab, and Menu
//  there pops back to Home, as tvOS does. Detail screens are pushed above either; the player is a
//  full-screen cover above everything.
//
//  Pass 2b (D032): `playerClosed` counts the closes and is handed to Home and every detail screen.
//  A full-screen cover never takes its content off screen, so a pushed screen gets no appearance
//  callback when the player goes away; this counter is that signal.
//

import SwiftUI

enum Destination: Hashable {
    case library(LibraryTab)
    case movie(Movie)
    case show(Show)
    case video(Video)
}

struct ContentView: View {
    @State private var library = LibraryModel()
    @State private var path: [Destination] = []
    @State private var playRequest: PlayRequest?
    /// D032: how many times the player has closed in this session.
    @State private var playerClosed = 0

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen(model: library,
                       playerClosed: playerClosed,
                       openTab: { tab in
                           library.tab = tab
                           path.append(.library(tab))
                       },
                       open: { path.append($0) },
                       playEntry: openEntry,
                       playEpisode: openEpisode)
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case .library:
                        LibraryScreen(model: library, open: { path.append($0) }, openEntry: openEntry)
                    case let .movie(movie):
                        MovieDetailScreen(movie: movie, api: library.api, playerClosed: playerClosed) { playRequest = $0 }
                    case let .show(show):
                        ShowDetailScreen(show: show, api: library.api, playerClosed: playerClosed) { playRequest = $0 }
                    case let .video(video):
                        VideoDetailScreen(video: video, api: library.api, playerClosed: playerClosed) { playRequest = $0 }
                    }
                }
        }
        .background(Nocturne.bg)
        .fullScreenCover(item: $playRequest) { request in
            PlayerScreen(request: request) { playRequest = nil }
        }
        .onChange(of: playRequest) { _, request in
            // D025/D032: back from the player — the positions it wrote are the server's truth now,
            // and Home and the detail screens re-read themselves off this counter.
            if request == nil {
                playerClosed += 1
                Task { await library.refreshContinueWatching() }
            }
        }
        .task { await library.load() }
    }

    /// D025: no detail screen and no edition picker — the card plays its own file, from its
    /// saved position.
    private func openEntry(_ entry: ContinueEntry) {
        Task {
            if let request = await library.playRequest(for: entry) {
                playRequest = request
            }
        }
    }

    /// D040: a card in Home's TV row plays that episode, resuming where it was left.
    private func openEpisode(_ item: HomeEpisode) {
        Task {
            if let request = await library.playRequest(for: item) {
                playRequest = request
            }
        }
    }
}
