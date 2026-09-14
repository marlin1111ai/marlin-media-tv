//
//  ContentView.swift
//  Marlin Media TV
//
//  Library at the root of a NavigationStack (Menu pops, as tvOS does); detail screens are
//  pushed; the player is a full-screen cover above everything.
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
            LibraryScreen(model: library) { path.append($0) }
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case let .movie(movie):
                        MovieDetailScreen(movie: movie) { playRequest = $0 }
                    case let .show(show):
                        ShowDetailScreen(show: show, api: library.api) { playRequest = $0 }
                    case let .video(video):
                        VideoDetailScreen(video: video) { playRequest = $0 }
                    }
                }
        }
        .background(Nocturne.bg)
        .fullScreenCover(item: $playRequest) { request in
            PlayerScreen(request: request) { playRequest = nil }
        }
        .task { await library.load() }
    }
}
