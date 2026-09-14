//
//  ServerAPI.swift
//  Marlin Media TV
//
//  The marlin-media server, fixed at http://192.168.1.250:8093 (DECISIONS.md D007: no settings
//  screen). Every failure is thrown as an APIError with a message the UI shows in full.
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

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func movies() async throws -> [Movie] { try await get("/api/movies") }
    func movie(id: Int) async throws -> Movie { try await get("/api/movies/\(id)") }
    func shows() async throws -> [Show] { try await get("/api/shows") }
    func show(id: Int) async throws -> Show { try await get("/api/shows/\(id)") }
    func videos() async throws -> [Video] { try await get("/api/videos") }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = ServerConfig.baseURL.appending(path: path)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
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
