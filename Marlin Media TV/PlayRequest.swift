//
//  PlayRequest.swift
//  Marlin Media TV
//
//  What the player is asked to play: the stream URL the server serves with Range support
//  (no transcoding exists) and the two overlay lines of frame 10.
//

import Foundation

struct PlayRequest: Identifiable, Hashable {
    enum Kind: Hashable { case movie, episode, video }

    let kind: Kind
    /// Frame 10's big line: the movie, show or video title.
    let title: String
    /// Frame 10's second line: "Extended · SD · AC-3 5.1", "S1 E1 · Unauthorized Magic", "1080p · H.264".
    let subtitle: String
    let url: URL
    let file: MediaInfo
    /// The server's timeline stills for `file` (pass 2g), when the detail screen's one index
    /// request was for this very file; nil otherwise, and then the scrub shows no thumbnail.
    let thumbs: FileThumbs?

    var id: String { url.absoluteString }

    /// An index belongs to a request only when it is the index of the file being played.
    private static func matching(_ thumbs: FileThumbs?, _ file: MediaInfo) -> FileThumbs? {
        thumbs?.fileId == file.fileId ? thumbs : nil
    }

    static func movie(_ movie: Movie, edition: Edition, thumbs: FileThumbs? = nil) -> PlayRequest? {
        guard let url = edition.file.streamURL else { return nil }
        var parts = [edition.displayName]
        if let label = edition.file.resolutionLabel { parts.append(label + (edition.file.hdr ? " HDR" : "")) }
        if let first = edition.file.audioTracks.first { parts.append(Format.audioTrack(first)) }
        return PlayRequest(kind: .movie, title: movie.title, subtitle: parts.joined(separator: " · "), url: url,
                           file: edition.file, thumbs: matching(thumbs, edition.file))
    }

    static func episode(_ episode: Episode, of show: Show, thumbs: FileThumbs? = nil) -> PlayRequest? {
        guard let url = episode.file.streamURL else { return nil }
        return PlayRequest(kind: .episode, title: show.title,
                           subtitle: "S\(episode.season) E\(episode.number) · \(episode.displayTitle)",
                           url: url, file: episode.file, thumbs: matching(thumbs, episode.file))
    }

    static func video(_ video: Video, thumbs: FileThumbs? = nil) -> PlayRequest? {
        guard let url = video.file.streamURL else { return nil }
        let parts = [video.file.resolutionLabel, video.file.videoCodec.map(Format.videoCodec)].compactMap { $0 }
        return PlayRequest(kind: .video, title: video.title, subtitle: parts.joined(separator: " · "), url: url,
                           file: video.file, thumbs: matching(thumbs, video.file))
    }
}
