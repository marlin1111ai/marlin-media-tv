//
//  ServerAPI.swift
//  Marlin Media TV
//
//  The marlin-media server, fixed at http://192.168.1.250:8093 (DECISIONS.md D007: no settings
//  screen). Every failure is thrown as an APIError with a message the UI shows in full.
//
//  Pass 2 (D024) adds the app's first and only write, `PUT /api/files/{fileId}/playback`, and the
//  `GET /api/continue-watching` list. Every playback write goes through `PlaybackWrite` so that a
//  failure is a log line and nothing else.
//

import Foundation

enum ServerConfig {
    static let baseURL = URL(string: "http://192.168.1.250:8093")!
    static var host: String { baseURL.host ?? baseURL.absoluteString }

    /// A server-relative path such as "/api/artwork/movie/1-poster.jpg?v=…" → absolute URL.
    static func resolve(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return URL(string: path, relativeTo: baseURL)?.absoluteURL
    }
}

enum APIError: LocalizedError {
    case transport(URLError, path: String)
    case http(status: Int, path: String, body: String)
    case decoding(String, path: String)
    case invalidResponse(path: String)

    /// True when the server did not answer at all (frame 17 copy applies).
    var isUnreachable: Bool {
        if case .transport = self { return true }
        return false
    }

    var errorDescription: String? {
        switch self {
        case let .transport(error, path):
            return "\(path): \(error.localizedDescription) (URLError \(error.code.rawValue))"
        case let .http(status, path, body):
            return "\(path): HTTP \(status) \(body.prefix(200))"
        case let .decoding(detail, path):
            return "\(path): the response did not decode — \(detail)"
        case let .invalidResponse(path):
            return "\(path): not an HTTP response"
        }
    }
}

struct APIClient: Sendable {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        encoder = JSONEncoder()
    }

    func movies() async throws -> [Movie] { try await get("/api/movies") }
    func movie(id: Int) async throws -> Movie { try await get("/api/movies/\(id)") }
    func shows() async throws -> [Show] { try await get("/api/shows") }
    func show(id: Int) async throws -> Show { try await get("/api/shows/\(id)") }
    func videos() async throws -> [Video] { try await get("/api/videos") }

    /// The file's timeline stills (pass 2g). The first request starts generation on the server, so
    /// this is asked once per detail screen and never polled (the index is a snapshot).
    func thumbs(fileId: Int) async throws -> FileThumbs {
        FileThumbs(fileId: fileId, index: try await get("/api/files/\(fileId)/thumbs"))
    }

    /// Pass 2 (D024): the server's in-progress list — `position > 0` and not watched, newest
    /// `last_played` first, one entry per file. The order is the server's and is kept.
    func continueWatching(limit: Int = 200) async throws -> [ContinueEntry] {
        try await get("/api/continue-watching", query: [URLQueryItem(name: "limit", value: String(limit))])
    }

    /// Pass 2 (D024): the app's only write. Either key may be omitted and the server leaves an
    /// omitted one unchanged; it sets `last_played` to its own clock on every write and answers
    /// with the block it stored. Callers go through `PlaybackWrite`, not this directly.
    @discardableResult
    func putPlayback(fileId: Int, position: Double? = nil, watched: Bool? = nil) async throws -> Playback {
        /// Optional properties are encoded with `encodeIfPresent`, so a nil key is simply absent —
        /// which is exactly the server's "leave unchanged".
        struct Body: Encodable {
            let position: Double?
            let watched: Bool?
        }
        let path = "/api/files/\(fileId)/playback"
        var request = URLRequest(url: ServerConfig.baseURL.appending(path: path))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(Body(position: position, watched: watched))
        return try await send(request, path: path)
    }

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var url = ServerConfig.baseURL.appending(path: path)
        if !query.isEmpty { url.append(queryItems: query) }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        return try await send(request, path: path)
    }

    private func send<T: Decodable>(_ request: URLRequest, path: String) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw APIError.transport(error, path: path)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse(path: path) }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode, path: path, body: String(decoding: data, as: UTF8.self))
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw APIError.decoding(Self.describe(error), path: path)
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        func path(_ context: DecodingError.Context) -> String {
            context.codingPath.map(\.stringValue).joined(separator: ".")
        }
        switch error {
        case let .keyNotFound(key, context): return "missing key '\(key.stringValue)' at \(path(context))"
        case let .typeMismatch(type, context): return "type mismatch (\(type)) at \(path(context)): \(context.debugDescription)"
        case let .valueNotFound(type, context): return "null where \(type) expected at \(path(context))"
        case let .dataCorrupted(context): return "corrupt data at \(path(context)): \(context.debugDescription)"
        @unknown default: return error.localizedDescription
        }
    }
}

/// Pass 2 (D024): every playback write in the app goes through here. The request and the server's
/// answer are written to the app's log; a failure is written there too and nowhere else — nothing
/// appears on screen and playback is never affected by it.
@MainActor
enum PlaybackWrite {
    @discardableResult
    static func send(_ api: APIClient, fileId: Int, position: Double? = nil, watched: Bool? = nil,
                     why: String) async -> Playback? {
        let sent = [position.map { "position=\(String(format: "%.1f", $0))" }, watched.map { "watched=\($0)" }]
            .compactMap { $0 }.joined(separator: " ")
        do {
            let stored = try await api.putPlayback(fileId: fileId, position: position, watched: watched)
            EvidenceLog.line("[playback] PUT file \(fileId) \(sent) (\(why)) → 200 position=\(stored.position) watched=\(stored.watched) last_played=\(stored.lastPlayed ?? "null")")
            return stored
        } catch {
            let detail = (error as? APIError)?.localizedDescription ?? String(describing: error)
            EvidenceLog.line("[playback] PUT file \(fileId) \(sent) (\(why)) FAILED: \(detail)")
            return nil
        }
    }
}
