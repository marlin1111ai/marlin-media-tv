//
//  MusicModels.swift
//  Marlin Media TV
//
//  Decodable models of the server's music JSON (`/api/albums`, `/api/albums/{id}`, `/api/artists`),
//  read against the live server on 2026-10-04 (version 0.10.0). Decoded with
//  `.convertFromSnakeCase`. Marlin Music is the only app that uses them.
//

import Foundation

struct AlbumArtwork: Decodable, Hashable {
    let cover: String?
    let coverSource: String?
}

struct Album: Decodable, Hashable, Identifiable {
    let id: Int
    let title: String
    let year: Int?
    let added: String
    let artistId: Int?
    let artist: String?
    let trackCount: Int
    let discCount: Int?
    let duration: Double?
    /// `{}` on an album with no cover.
    let artwork: AlbumArtwork?
    /// Present on GET /api/albums/{id} only.
    let tracks: [Track]?

    var cover: String? { artwork?.cover }

    /// The second line of an album's card: "Eagles · 1976".
    var cardLine: String {
        [artist, year.map(String.init)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

struct Artist: Decodable, Hashable, Identifiable {
    let id: Int
    let name: String
    let added: String
    let albumCount: Int
    let trackCount: Int

    /// The second line of an artist's card: "5 albums · 71 tracks".
    var cardLine: String {
        "\(albumCount) album\(albumCount == 1 ? "" : "s") · \(trackCount) track\(trackCount == 1 ? "" : "s")"
    }
}

struct Track: Decodable, Hashable, Identifiable {
    let id: Int
    let title: String
    let number: Int?
    let disc: Int?
    let artist: String?
    let fileId: Int
    let duration: Double?
    let audioCodec: String?
    let channels: Int?
    let layout: String?
    let sampleRate: Int?
    let bitDepth: Int?
    let stream: String

    /// "FLAC · 96 kHz · 24-bit · 2.0" — whatever of it the server reports.
    var spec: String {
        var parts: [String] = []
        if let audioCodec { parts.append(Format.audioCodec(audioCodec)) }
        if let sampleRate, sampleRate > 0 { parts.append(String(format: "%g kHz", Double(sampleRate) / 1000)) }
        if let bitDepth, bitDepth > 0 { parts.append("\(bitDepth)-bit") }
        let shape = Format.layout(layout ?? "", channels: channels ?? 0)
        if !shape.isEmpty { parts.append(shape) }
        return parts.joined(separator: " · ")
    }
}
