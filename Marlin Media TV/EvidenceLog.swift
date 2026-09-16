//
//  EvidenceLog.swift
//  Marlin Media TV
//
//  One log file per launch in the app's Library/Caches folder (tvOS gives an app no writable Documents) — VLCKit's own file logger at debug
//  level and the app's "[player]" lines, interleaved — so the device-proof for a pass can be
//  copied off with `xcrun devicectl device copy from … --domain-type appDataContainer`
//  (DECISIONS.md D011). The same lines also go to the console.
//

import Foundation
import VLCKit

@MainActor
enum EvidenceLog {
    static let fileName = "marlin-media-tv.log"
    private static var handle: FileHandle?

    static var url: URL {
        URL.cachesDirectory.appending(path: fileName)
    }

    private static var openFailed = false

    /// The file is opened (and truncated) by whichever comes first — the first logged line or the
    /// first player. Pass 2: the playback writes of the detail screens happen with no player up, so
    /// waiting for `fileLogger()` would have left every one of them out of the file.
    @discardableResult
    private static func ensureHandle() -> FileHandle? {
        if handle == nil, !openFailed {
            FileManager.default.createFile(atPath: url.path, contents: nil)
            guard let fh = try? FileHandle(forWritingTo: url) else {
                openFailed = true
                print("[log] could not open \(url.path)")
                return nil
            }
            handle = fh
            // Safe: `handle` is already set, so this line does not re-enter this branch.
            line("[log] started \(Date()) VLCKit \(VLCLibrary.shared().version)")
        }
        return handle
    }

    /// VLCKit's file logger on the same handle (nil if the file could not be opened).
    static func fileLogger() -> VLCFileLogger? {
        guard let handle = ensureHandle() else { return nil }
        let logger = VLCFileLogger(fileHandle: handle)
        logger.level = .debug
        return logger
    }

    static func line(_ text: String) {
        let stamp = Date().formatted(.dateTime.hour().minute().second().secondFraction(.fractional(3)))
        let out = "\(stamp) \(text)"
        print(out)
        let fh = ensureHandle()
        if let data = (out + "\n").data(using: .utf8) {
            fh?.write(data)
        }
    }
}
