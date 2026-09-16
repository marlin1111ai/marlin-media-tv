//
//  ContentView.swift
//  Marlin Media TV
//
//  Library at the root of a NavigationStack (Menu pops, as tvOS does); detail screens are
//  pushed; the player is a full-screen cover above everything.
//
//  Pass 2 (D025): a Continue Watching card opens the player directly — its file's detail and
//  thumbnail index are fetched first — and the row is asked for again whenever the player closes,
//  so a position written during playback is on the row when the library comes back.
//
//  Pass 2b (D032): `playerClosed` counts the closes and is handed to every detail screen. A
//  full-screen cover never takes its content off screen, so a pushed detail screen gets no
//  appearance callback when the player goes away; this counter is that signal, and each screen
//  re-reads its own item from it.
//

import SwiftUI

enum Destination: Hashable {
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
            LibraryScreen(model: library, open: { path.append($0) }, openEntry: openEntry)
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
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
            // D025: back from the player — the position just written belongs on the row.
            // D032: and every detail screen re-reads itself off this counter.
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
}
