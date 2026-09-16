//
//  NowClock.swift
//  Marlin Media TV
//
//  Pass 3 (D041): the date and time the new frames put at the top right of Home, the three library
//  tabs and the movie, show and video screens. The player frames (10–15) do not have it, and it is
//  not added there.
//
//  From the frames: the date is 18 px / 500, `.1em` tracking, uppercase, `#75798c`; the time is
//  24 px / 500, `#cfd3e5`, tabular figures; 14 px between them, baselines aligned. The placement
//  (`right: 80, top: 56`) belongs to each screen, so this view draws only the pair.
//
//  It keeps time while it is on screen: a one-second timer, which stops when the view goes away.
//

import SwiftUI
import Combine

struct NowClock: View {
    @State private var now = Date()
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// "TUE 15 SEP" — the frames' uppercase day, date and month.
    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f.string(from: now).uppercased()
    }

    /// "9:40 PM" — the device's own short time, so a 24-hour region reads as that region expects.
    private var timeText: String {
        now.formatted(date: .omitted, time: .shortened)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(dateText)
                .font(.nocturne(18, .medium))
                .kerning(1.8)
                .foregroundStyle(Nocturne.neutral600)
            Text(timeText)
                .font(.nocturne(24, .medium))
                .monospacedDigit()
                .foregroundStyle(Nocturne.neutral300)
        }
        .onReceive(tick) { now = $0 }
        .accessibilityIdentifier("clock")
        .accessibilityLabel("\(dateText), \(timeText)")
    }
}
