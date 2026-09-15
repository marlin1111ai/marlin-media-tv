//
//  ThumbStrip.swift
//  Marlin Media TV
//
//  The server's timeline stills (marlin-media image 0.3.0), shown above the bar during a paused
//  scrub (D021). One still every `interval` seconds, packed into sprite sheets of `columns` ×
//  `rows` tiles, row-major and chronological:
//    GET /api/files/{fileId}/thumbs   — the index below. Generation starts on the first request,
//        so the index is a snapshot: `sheets` lists only the sheets that exist at that moment,
//        and `state` is "none" (no usable duration), "generating", "complete" or "failed".
//    GET /api/thumbs/{fileId}/{n}.jpg — one sheet, as `sheet.url` gives it.
//  The index is fetched once when a detail screen opens and is never polled or re-fetched
//  (pass 2g), so a file still generating shows the stills it already has and nothing for the
//  rest. Where a still does not exist there is nothing above the bar — no placeholder, no held
//  image, no message.
//

import Foundation
import Observation
import UIKit

/// One sprite sheet that existed when the index was read.
struct ThumbSheet: Decodable, Hashable {
    let index: Int
    /// The still number of this sheet's first tile.
    let firstStill: Int
    /// Server-relative, with the server's cache-busting query ("/api/thumbs/2/0.jpg?v=…").
    let url: String
}

/// GET /api/files/{fileId}/thumbs.
struct ThumbIndex: Decodable, Hashable {
    let interval: Double
    let tileWidth: Int
    let tileHeight: Int
    let columns: Int
    let rows: Int
    let perSheet: Int
    /// How many stills the whole file has.
    let count: Int
    let state: String
    let sheets: [ThumbSheet]

    /// Where one still sits: the sheet that holds it and the tile's rectangle in that sheet.
    struct Placed {
        let sheet: ThumbSheet
        let rect: CGRect
    }

    /// The still nearest `ms`, or nil when the file has no stills at all.
    func still(nearestMs ms: Int) -> Int? {
        guard count > 0, interval > 0 else { return nil }
        let n = Int((Double(ms) / 1000 / interval).rounded())
        return min(max(0, n), count - 1)
    }

    /// The tile for a still, or nil when its sheet does not exist yet (generation is still running).
    func place(still n: Int) -> Placed? {
        guard perSheet > 0, columns > 0, rows > 0, tileWidth > 0, tileHeight > 0 else { return nil }
        guard let sheet = sheets.first(where: { $0.index == n / perSheet }) else { return nil }
        let within = n - sheet.firstStill
        guard within >= 0, within < perSheet else { return nil }
        return Placed(sheet: sheet,
                      rect: CGRect(x: (within % columns) * tileWidth, y: (within / columns) * tileHeight,
                                   width: tileWidth, height: tileHeight))
    }
}

/// The index together with the file it belongs to (the JSON carries no file id).
struct FileThumbs: Hashable {
    let fileId: Int
    let index: ThumbIndex
}

/// The stills of one file while the player is up: the sheets already downloaded, and the tile for
/// the scrub's latest target. Sheets are fetched as they are needed and kept for the rest of the
/// player's life.
@MainActor
@Observable
final class ThumbStrip {
    private let thumbs: FileThumbs
    @ObservationIgnored private var sheets: [Int: CGImage] = [:]
    @ObservationIgnored private var requested: Set<Int> = []
    @ObservationIgnored private var wanted: Int?

    /// The tile to draw, or nil when there is nothing to show for the target.
    private(set) var tile: CGImage?

    init(_ thumbs: FileThumbs) {
        self.thumbs = thumbs
        EvidenceLog.line("[thumbs] file \(thumbs.fileId): \(thumbs.index.count) stills every \(thumbs.index.interval) s, \(thumbs.index.sheets.count) of \(Int(ceil(Double(thumbs.index.count) / Double(max(1, thumbs.index.perSheet))))) sheets, state \(thumbs.index.state)")
    }

    /// The design size of one still (the server's tile size, in the frames' 1920 × 1080 space).
    var tileSize: CGSize { CGSize(width: thumbs.index.tileWidth, height: thumbs.index.tileHeight) }

    /// The scrub's target moved: show the still nearest it, if that still exists.
    func show(ms: Int) {
        guard let n = thumbs.index.still(nearestMs: ms) else { return }
        guard n != wanted else { return }
        wanted = n
        draw()
    }

    /// The scrub ended (landed or cancelled): nothing is shown until the next drag.
    func clear() {
        wanted = nil
        tile = nil
    }

    private func draw() {
        guard let n = wanted, let placed = thumbs.index.place(still: n) else { tile = nil; return }
        guard let sheet = sheets[placed.sheet.index] else {
            tile = nil                      // nothing above the bar until the sheet is here
            load(placed.sheet)
            return
        }
        // A partly filled last sheet can be shorter than columns × rows tiles.
        guard placed.rect.maxX <= CGFloat(sheet.width), placed.rect.maxY <= CGFloat(sheet.height),
              let cropped = sheet.cropping(to: placed.rect) else { tile = nil; return }
        tile = cropped
    }

    private func load(_ sheet: ThumbSheet) {
        guard !requested.contains(sheet.index), let url = ServerConfig.resolve(sheet.url) else { return }
        requested.insert(sheet.index)
        let started = ContinuousClock.now
        Task { [weak self] in
            let image = await Self.fetch(url)
            guard let self else { return }
            let took = (ContinuousClock.now - started).components
            let ms = took.seconds * 1000 + took.attoseconds / 1_000_000_000_000_000
            EvidenceLog.line("[thumbs] sheet \(sheet.index) \(image == nil ? "failed" : "loaded \(image!.width)x\(image!.height)") in \(ms) ms")
            if let image { self.sheets[sheet.index] = image } else { self.requested.remove(sheet.index) }
            self.draw()   // the target may have moved on while the sheet downloaded
        }
    }

    /// Off the main actor: the sheet is a full-size JPEG to decode.
    private nonisolated static func fetch(_ url: URL) async -> CGImage? {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            return UIImage(data: data)?.cgImage
        } catch {
            return nil
        }
    }
}
