//
//  Models.swift
//  Marlin Media TV
//
//  Decodable models of the marlin-media server's JSON (server/api.go on 2026-09-13, confirmed
//  against the live server 192.168.1.250:8093 running version 0.2.0). Every field here exists
//  in that JSON; nothing is invented. Decoded with `.convertFromSnakeCase`.
//

import Foundation

struct Artwork: Decodable, Hashable {
    let poster: String?
    let backdrop: String?
    let still: String?
    let posterSource: String?
    let backdropSource: String?
    let stillSource: String?
}

struct Playback: Decodable, Hashable {
    let position: Double
    let watched: Bool
    let lastPlayed: String?
}

struct AudioTrackInfo: Decodable, Hashable {
    let codec: String
    let channels: Int
    let layout: String
}

struct SubtitleTrackInfo: Decodable, Hashable {
    let codec: String
}

/// The per-file block shared by editions, episodes and videos (server `mediaFile`).
struct MediaInfo: Decodable, Hashable {
    let fileId: Int
    let playback: Playback
    let path: String
    let size: Int64
    let duration: Double?
    let resolution: String?
    let resolutionLabel: String?
    let hdr: Bool
    let videoCodec: String?
    let audioTracks: [AudioTrackInfo]
    let subtitleTracks: [SubtitleTrackInfo]
    let stream: String

    var streamURL: URL? { ServerConfig.resolve(stream) }
    var fileName: String { (path as NSString).lastPathComponent }
    var directory: String { "/" + (path as NSString).deletingLastPathComponent }
}

struct Edition: Decodable, Hashable, Identifiable {
    let id: Int
    let name: String?
    let file: MediaInfo

    private enum CodingKeys: String, CodingKey { case id, name }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        file = try MediaInfo(from: decoder)
    }

    /// The edition's name, or its file name when the server has none (`name` is null for an untagged file).
    var displayName: String { name ?? file.fileName }
}

struct Movie: Decodable, Hashable, Identifiable {
    let id: Int
    let title: String
    let parsedTitle: String
    let year: Int?
    let added: String
    let tmdbId: Int?
    let unmatched: Bool
    let manualMatch: Bool
    let overview: String?
    let releaseDate: String?
    let runtime: Int?
    let genres: [String]
    let rating: Double?
    let artwork: Artwork
    let editions: [Edition]
}

struct Show: Decodable, Hashable, Identifiable {
    let id: Int
    let title: String
    let parsedTitle: String
    let year: Int?
    let added: String
    let tmdbId: Int?
    let unmatched: Bool
    let manualMatch: Bool
    let overview: String?
    let firstAirDate: String?
    let runtime: Int?
    let genres: [String]
    let rating: Double?
    let seasonCount: Int
    let episodeCount: Int
    let artwork: Artwork
    /// Present on GET /api/shows/{id} only.
    let seasons: [Season]?
}

struct Season: Decodable, Hashable, Identifiable {
    let id: Int
    let number: Int
    let name: String?
    let overview: String?
    let episodes: [Episode]
}

struct Episode: Decodable, Hashable, Identifiable {
    let id: Int
    let season: Int
    let number: Int
    let title: String?
    let tmdbName: String?
    let tmdbEpisodeId: Int?
    let unmatched: Bool
    let overview: String?
    let airDate: String?
    let artwork: Artwork
    let file: MediaInfo

    private enum CodingKeys: String, CodingKey {
        case id, season, number, title, tmdbName, tmdbEpisodeId, unmatched, overview, airDate, artwork
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        season = try c.decode(Int.self, forKey: .season)
        number = try c.decode(Int.self, forKey: .number)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        tmdbName = try c.decodeIfPresent(String.self, forKey: .tmdbName)
        tmdbEpisodeId = try c.decodeIfPresent(Int.self, forKey: .tmdbEpisodeId)
        unmatched = try c.decode(Bool.self, forKey: .unmatched)
        overview = try c.decodeIfPresent(String.self, forKey: .overview)
        airDate = try c.decodeIfPresent(String.self, forKey: .airDate)
        artwork = try c.decode(Artwork.self, forKey: .artwork)
        file = try MediaInfo(from: decoder)
    }

    var displayTitle: String { title ?? tmdbName ?? "Episode \(number)" }
}

struct Video: Decodable, Hashable, Identifiable {
    let id: Int
    let title: String
    let year: Int?
    let added: String
    let tmdbId: Int?
    let unmatched: Bool
    let overview: String?
    let artwork: Artwork
    let file: MediaInfo

    private enum CodingKeys: String, CodingKey { case id, title, year, added, tmdbId, unmatched, overview, artwork }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        year = try c.decodeIfPresent(Int.self, forKey: .year)
        added = try c.decode(String.self, forKey: .added)
        tmdbId = try c.decodeIfPresent(Int.self, forKey: .tmdbId)
        unmatched = try c.decode(Bool.self, forKey: .unmatched)
        overview = try c.decodeIfPresent(String.self, forKey: .overview)
        artwork = try c.decode(Artwork.self, forKey: .artwork)
        file = try MediaInfo(from: decoder)
    }
}

// MARK: - Presentation of the server's values (display names only; the data is the server's)

nonisolated enum Format {
    /// ffprobe codec_name (+ profile) → the frames' short names: "hevc Main 10" → "HEVC".
    static func videoCodec(_ codec: String?) -> String {
        guard let codec, let base = codec.split(separator: " ").first else { return "—" }
        switch base.lowercased() {
        case "hevc", "h265": return "HEVC"
        case "h264", "avc": return "H.264"
        case "mpeg2video": return "MPEG-2"
        case "mpeg4": return "MPEG-4"
        case "av1": return "AV1"
        case "vc1": return "VC-1"
        case "vp9": return "VP9"
        default: return base.uppercased()
        }
    }

    static func audioCodec(_ codec: String) -> String {
        switch codec.lowercased() {
        case "truehd": return "TrueHD"
        case "dts": return "DTS"
        case "ac3": return "AC-3"
        case "eac3": return "E-AC-3"
        case "aac": return "AAC"
        case "flac": return "FLAC"
        case "opus": return "Opus"
        case "mp3": return "MP3"
        case "mp2": return "MP2"
        case "vorbis": return "Vorbis"
        default:
            return codec.lowercased().hasPrefix("pcm") ? "PCM" : codec.uppercased()
        }
    }

    /// ffprobe channel_layout → the frames' "7.1" / "5.1" / "2.0".
    static func layout(_ layout: String, channels: Int) -> String {
        let trimmed = layout.split(separator: "(").first.map(String.init) ?? layout
        switch trimmed.lowercased() {
        case "stereo": return "2.0"
        case "mono": return "1.0"
        case "": return channels > 0 ? "\(channels) ch" : ""
        default: return trimmed
        }
    }

    /// "AC-3 5.1" — codec and channels/layout of one audio track.
    static func audioTrack(_ t: AudioTrackInfo) -> String {
        "\(audioCodec(t.codec)) \(layout(t.layout, channels: t.channels))"
    }

    static func audioTracks(_ tracks: [AudioTrackInfo]) -> String {
        tracks.isEmpty ? "No audio" : tracks.map(audioTrack).joined(separator: " · ")
    }

    static func subtitleCodec(_ codec: String) -> String {
        switch codec.lowercased() {
        case "subrip", "srt": return "SRT"
        case "hdmv_pgs_subtitle", "pgs": return "PGS"
        case "ass", "ssa": return "ASS"
        case "dvd_subtitle": return "VobSub"
        case "mov_text": return "MOV Text"
        case "webvtt": return "WebVTT"
        default: return codec.uppercased()
        }
    }

    static func subtitleCount(_ n: Int) -> String {
        switch n {
        case 0: return "No subtitles"
        case 1: return "1 subtitle"
        default: return "\(n) subtitles"
        }
    }

    /// 8379 s → "2 h 20 min"; 2588 s → "43 min".
    static func minutes(_ seconds: Double?) -> String {
        guard let seconds else { return "—" }
        let m = Int((seconds / 60).rounded())
        return m >= 60 ? "\(m / 60) h \(m % 60) min" : "\(m) min"
    }

    /// Runtime in minutes from TMDB → "2 h 21 min".
    static func runtime(_ minutes: Int?) -> String {
        guard let m = minutes else { return "—" }
        return m >= 60 ? "\(m / 60) h \(m % 60) min" : "\(m) min"
    }

    /// 761 s → "12:41"; 5046 s → "1:24:06" (the prototype's `fmt`).
    static func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    /// 13214700163 bytes → "13.2 GB" (decimal gigabytes, as the frames show).
    static func size(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_000_000_000
        if gb >= 10 { return "\(Int(gb.rounded())) GB" }
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return String(format: "%.0f MB", Double(bytes) / 1_000_000)
    }

    /// RFC3339 "2026-09-14T01:09:07Z" → "14 Sep 2026".
    static func addedDate(_ rfc3339: String) -> String {
        let parser = ISO8601DateFormatter()
        guard let date = parser.date(from: rfc3339) else { return rfc3339 }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    static func year(fromDate date: String?) -> String? {
        guard let date, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }

    static func rating(_ r: Double?) -> String? {
        guard let r else { return nil }
        return String(format: "TMDB %.1f", r)
    }

    static func genres(_ g: [String]) -> String { g.joined(separator: " · ") }
}
