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

    /// The file is truncated once per launch; every player after that appends to it.
    /// Returns VLCKit's file logger on it (nil if the file could not be opened).
    static func fileLogger() -> VLCFileLogger? {
        if handle == nil {
            FileManager.default.createFile(atPath: url.path, contents: nil)
            guard let fh = try? FileHandle(forWritingTo: url) else {
                print("[log] could not open \(url.path)")
                return nil
            }
            handle = fh
            line("[log] started \(Date()) VLCKit \(VLCLibrary.shared().version)")
        }
        guard let handle else { return nil }
        let logger = VLCFileLogger(fileHandle: handle)
        logger.level = .debug
        return logger
    }

    static func line(_ text: String) {
        let stamp = Date().formatted(.dateTime.hour().minute().second().secondFraction(.fractional(3)))
        let out = "\(stamp) \(text)"
        print(out)
        if let data = (out + "\n").data(using: .utf8) {
            handle?.write(data)
        }
    }
}
