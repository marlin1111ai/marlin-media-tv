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

    var body: some View {
        NavigationStack(path: $path) {
            LibraryScreen(model: library, open: { path.append($0) }, openEntry: openEntry)
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case let .movie(movie):
                        MovieDetailScreen(movie: movie, api: library.api) { playRequest = $0 }
                    case let .show(show):
                        ShowDetailScreen(show: show, api: library.api) { playRequest = $0 }
                    case let .video(video):
                        VideoDetailScreen(video: video, api: library.api) { playRequest = $0 }
                    }
                }
        }
        .background(Nocturne.bg)
        .fullScreenCover(item: $playRequest) { request in
            PlayerScreen(request: request) { playRequest = nil }
        }
        .onChange(of: playRequest) { _, request in
            // D025: back from the player — the position just written belongs on the row.
            if request == nil { Task { await library.refreshContinueWatching() } }
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
