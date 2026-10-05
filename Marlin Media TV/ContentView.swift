//
//  ContentView.swift
//  Marlin Media TV
//
//  2026-10-04, the five apps: **each app opens straight onto its own library** — the combined Home
//  screen (pass 3, D040) is gone. Detail screens are pushed above the library; the player is a
//  full-screen cover above everything.
//
//  Pass 2b (D032): `playerClosed` counts the closes and is handed to every detail screen. A
//  full-screen cover never takes its content off screen, so a pushed screen gets no appearance
//  callback when the player goes away; this counter is that signal.
//
//  Marlin Music has no film player. Its `MusicPlayer` lives here, from launch, so the music plays
//  on while the owner browses; Play/Pause on the remote reaches it from anywhere in the app, and
//  leaving the app stops it.
//

import SwiftUI

enum Destination: Hashable {
    case movie(Movie)
    case show(Show)
    case video(Video)
    // Marlin Music
    case album(Album)
    case artist(Artist)
    case nowPlaying
}

struct ContentView: View {
    @State private var library = LibraryModel()
    @State private var path: [Destination] = []
    @State private var playRequest: PlayRequest?
    /// D032: how many times the player has closed in this session.
    @State private var playerClosed = 0
    /// Marlin Music's player; the other four apps have none.
    @State private var music: MusicPlayer? = AppKind.current == .music ? MusicPlayer() : nil
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack(path: $path) {
            LibraryScreen(model: library,
                          music: music,
                          open: { path.append($0) },
                          openEntry: openEntry,
                          openEpisode: openEpisode)
                .navigationDestination(for: Destination.self) { destination in
                    switch destination {
                    case let .movie(movie):
                        MovieDetailScreen(movie: movie, api: library.api, playerClosed: playerClosed) { playRequest = $0 }
                    case let .show(show):
                        ShowDetailScreen(show: show, api: library.api, playerClosed: playerClosed) { playRequest = $0 }
                    case let .video(video):
                        VideoDetailScreen(video: video, api: library.api, playerClosed: playerClosed) { playRequest = $0 }
                    case let .album(album):
                        if let music {
                            AlbumScreen(album: album, api: library.api, music: music) { path.append(.nowPlaying) }
                        }
                    case let .artist(artist):
                        ArtistScreen(artist: artist, model: library, music: music) { path.append($0) }
                    case .nowPlaying:
                        if let music { NowPlayingScreen(music: music) }
                    }
                }
        }
        .background(Nocturne.bg)
        .fullScreenCover(item: $playRequest) { request in
            PlayerScreen(request: request) { playRequest = nil }
        }
        .onChange(of: playRequest) { _, request in
            // D025/D032/D040: back from the player — the positions it wrote are the server's truth
            // now. The first screen re-reads itself here, and the detail screens off this counter.
            if request == nil {
                playerClosed += 1
                Task { await library.refresh() }
            }
        }
        // Marlin Music: Play/Pause on the remote, from any screen of the app. The other four apps
        // pass nil and keep the system's own handling.
        .onPlayPauseCommand(perform: music.map { player in { player.toggle() } })
        // The album has ended, or the music was stopped: Now Playing has nothing to show.
        .onChange(of: music?.isActive) { _, active in
            if active != true { path.removeAll { $0 == .nowPlaying } }
        }
        // Leaving the app stops the music, as Home does on the PC box.
        .onChange(of: scenePhase) { _, phase in
            guard let music else { return }
            EvidenceLog.line("[app] scene phase \(phase)")
            if phase == .background { music.stop(why: "the app left the screen") }
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

    /// D040: a card in the Up next row plays that episode, resuming where it was left.
    private func openEpisode(_ item: UpNextEpisode) {
        Task {
            if let request = await library.playRequest(for: item) {
                playRequest = request
            }
        }
    }
}
