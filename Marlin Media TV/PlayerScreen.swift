//
//  PlayerScreen.swift
//  Marlin Media TV
//
//  Frames 10 (overlay), 11 (audio panel), 12 (subtitle panel), 13 (paused + frame step),
//  14/15 (skip feedback), and the scrub bar (pass 2a). Nothing here is focusable: the UIKit surface underneath owns the
//  remote and the model tells this view what to draw.
//

import SwiftUI

struct PlayerScreen: View {
    @State private var model: PlayerModel

    init(request: PlayRequest, onDismiss: @escaping () -> Void) {
        _model = State(initialValue: PlayerModel(request: request, onDismiss: onDismiss))
    }

    var body: some View {
        ZStack {
            Nocturne.playerBg
            PlayerHost(model: model)
            ZStack {
                if let pill = model.skipPill, model.scrub == nil { SkipFeedback(text: pill.text, forward: pill.forward) }
                if !model.isPlaying, model.errorText == nil, model.scrub == nil { PausedCenter(framePill: model.framePill) }
                // D045: the clock, while paused only. Hidden while a track panel is open, because
                // frames 11/12 put the panel in that same corner.
                if !model.isPlaying, model.errorText == nil, model.panel == nil { pausedClock }
                if model.scrub == nil, model.overlayVisible || model.panel != nil { overlay }
                if let scrub = model.scrub {
                    ScrubOverlay(scrub: scrub, lengthMs: model.lengthMs,
                                 thumb: model.thumbStrip?.tile, tileSize: model.thumbStrip?.tileSize ?? .zero)
                }
                if let panel = model.panel { TrackPanel(model: model, panel: panel) }
                if let error = model.errorText { PlaybackError(text: error) }
            }
            .allowsHitTesting(false)   // visuals only; the UIKit surface underneath owns every press and touch
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .background(Nocturne.playerBg)
        .onExitCommand { model.handle(.menu) }   // Menu with a panel open closes the panel; otherwise exits (pass 1d)
        .onDisappear { model.dismiss() }
        .accessibilityIdentifier("player")
    }

    /// D045: the clock at the player's top right **while paused** — the same pair, the same style and
    /// the same place (right 80, top 56) as Home, the library tabs and the detail screens (D041).
    /// While playing there is none, as frames 10–15 draw it; this revises D041's "not on the player".
    private var pausedClock: some View {
        NowClock()
            .padding(.trailing, 80)
            .padding(.top, 56)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .transition(.opacity)
    }

    /// Frame 10.
    private var overlay: some View {
        VStack {
            Spacer()
            ZStack(alignment: .bottom) {
                LinearGradient(stops: [.init(color: Nocturne.playerBg.opacity(0), location: 0),
                                       .init(color: Nocturne.playerBg.opacity(0.55), location: 0.5),
                                       .init(color: Nocturne.playerBg.opacity(0.92), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 1080 * 0.52)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(model.request.title)
                                .font(.nocturne(46, .medium))
                                .foregroundStyle(Nocturne.accent100)
                                .lineLimit(1)
                                .accessibilityIdentifier("player.title")
                            Text(model.request.subtitle)
                                .font(.nocturne(26))
                                .foregroundStyle(Nocturne.neutral400)
                                .lineLimit(1)
                        }
                        Spacer()
                        HStack(spacing: 16) {
                            PanelButton(title: "Audio", focused: model.focus == .audio)
                            PanelButton(title: "Subtitles", focused: model.focus == .subtitles)
                        }
                    }
                    HStack(spacing: 26) {
                        Text(model.elapsedText)
                            .font(.nocturne(30, .medium)).monospacedDigit()
                            .foregroundStyle(Nocturne.text)
                            .frame(width: 130, alignment: .leading)
                            .accessibilityIdentifier("player.elapsed")
                        Scrubber(progress: model.progress)
                        Text(model.remainingText)
                            .font(.nocturne(30, .medium)).monospacedDigit()
                            .foregroundStyle(Nocturne.neutral400)
                            .frame(width: 130, alignment: .trailing)
                    }
                    .padding(.top, 40)
                    HStack {
                        HStack(spacing: 14) {
                            Text(model.isPlaying ? "▶" : "❙❙")
                                .font(.nocturne(model.isPlaying ? 22 : 20))
                                .foregroundStyle(Nocturne.accent)
                            Text(model.isPlaying ? "Playing" : model.stateName)
                                .font(.nocturne(24))
                                .foregroundStyle(Nocturne.neutral500)
                                .accessibilityIdentifier("player.state")
                        }
                        Spacer()
                        if !model.isPlaying {
                            HStack(spacing: 34) {
                                HStack(spacing: 12) {
                                    Text("◀").foregroundStyle(Nocturne.accent)
                                    Text("click: frame back")
                                }
                                HStack(spacing: 12) {
                                    Text("click")
                                    Text("▶").foregroundStyle(Nocturne.accent)
                                    Text(": frame forward")
                                }
                            }
                            .font(.nocturne(24))
                            .foregroundStyle(Nocturne.neutral400)
                        }
                    }
                    .padding(.top, 20)
                }
                .padding(.horizontal, 80)
                .padding(.bottom, 78)
            }
        }
        .transition(.opacity)
        .animation(.easeOut(duration: 0.25), value: model.overlayVisible)
    }
}

/// The Audio / Subtitles buttons of frame 10 (focused: accent border, tint and glow).
private struct PanelButton: View {
    let title: String
    let focused: Bool

    var body: some View {
        Text(title)
            .font(.nocturne(26, .medium))
            .foregroundStyle(focused ? Nocturne.accent100 : Nocturne.neutral300)
            .padding(.vertical, 16)
            .padding(.horizontal, 30)
            .background(focused ? Nocturne.accent.opacity(0.18) : Nocturne.bg.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? Nocturne.accent : Nocturne.neutral600, lineWidth: focused ? 3 : 1))
            .shadow(color: focused ? Nocturne.accent.opacity(0.3) : .clear, radius: 20)
            .accessibilityIdentifier("player.\(title)")
    }
}

/// Frame 10's scrubber: 8 px track, accent fill, a white knob with a glow. While scrubbing (pass 2a) the knob is the
/// target and `mark` is where playback was when the drag began.
private struct Scrubber: View {
    let progress: Double
    var mark: Double? = nil

    var body: some View {
        GeometryReader { geo in
            let x = geo.size.width * progress
            ZStack(alignment: .leading) {
                Capsule().fill(Nocturne.text.opacity(0.22)).frame(height: 8)
                Capsule().fill(Nocturne.accent).frame(width: max(0, x), height: 8)
                if let mark {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Nocturne.neutral300)
                        .frame(width: 4, height: 20)
                        .offset(x: geo.size.width * mark - 2)
                }
                RoundedRectangle(cornerRadius: 5)
                    .fill(Nocturne.accent100)
                    .frame(width: 10, height: 34)
                    .shadow(color: Nocturne.accent.opacity(0.8), radius: 12)
                    .offset(x: x - 5)
            }
            .frame(height: 34)
        }
        .frame(height: 34)
    }
}

/// Pass 2a: the scrub bar — frame 10's timeline row (type, widths, 26 pt spacing) in frames 14/15's place, the bar
/// alone 78 pt above the bottom edge over frame 10's shade. Elapsed and remaining are the target's.
/// Pass 2g: above the bar, the server's still nearest the target (`thumb`), over the target's place on the track.
/// When the server has no still there yet, nothing is drawn above the bar.
private struct ScrubOverlay: View {
    let scrub: PlayerModel.Scrub
    let lengthMs: Int
    let thumb: CGImage?
    let tileSize: CGSize

    private func share(_ ms: Int) -> Double { lengthMs > 0 ? min(1, max(0, Double(ms) / Double(lengthMs))) : 0 }

    var body: some View {
        VStack {
            Spacer()
            ZStack(alignment: .bottom) {
                LinearGradient(stops: [.init(color: Nocturne.playerBg.opacity(0), location: 0),
                                       .init(color: Nocturne.playerBg.opacity(0.55), location: 0.5),
                                       .init(color: Nocturne.playerBg.opacity(0.92), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 1080 * 0.52)
                VStack(spacing: 26) {
                    if let thumb, tileSize.width > 0, tileSize.height > 0 { still(thumb) }
                    HStack(spacing: 26) {
                        Text(Format.clock(Double(scrub.targetMs) / 1000))
                            .font(.nocturne(30, .medium)).monospacedDigit()
                            .foregroundStyle(Nocturne.text)
                            .frame(width: 130, alignment: .leading)
                        Scrubber(progress: share(scrub.targetMs), mark: share(scrub.startMs))
                        Text("−" + Format.clock(Double(max(0, lengthMs - scrub.targetMs)) / 1000))
                            .font(.nocturne(30, .medium)).monospacedDigit()
                            .foregroundStyle(Nocturne.neutral400)
                            .frame(width: 130, alignment: .trailing)
                    }
                }
                .padding(.horizontal, 80)
                .padding(.bottom, 78)
            }
        }
    }

    /// The still, carried over the knob: the same 130 pt time columns and 26 pt gaps as the bar row, so the width it
    /// travels is the track's own. It stops at either end of the track rather than leaving it.
    private func still(_ image: CGImage) -> some View {
        HStack(spacing: 26) {
            Color.clear.frame(width: 130, height: 1)
            GeometryReader { geo in
                Image(decorative: image, scale: 1)
                    .resizable()
                    .frame(width: tileSize.width, height: tileSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Nocturne.neutral700, lineWidth: 1))
                    .shadow(color: .black.opacity(0.55), radius: 24, y: 14)
                    .offset(x: min(max(0, geo.size.width * share(scrub.targetMs) - tileSize.width / 2),
                                   max(0, geo.size.width - tileSize.width)))
            }
            .frame(height: tileSize.height)
            Color.clear.frame(width: 130, height: 1)
        }
    }
}

/// Frames 14 and 15.
private struct SkipFeedback: View {
    let text: String
    let forward: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [Nocturne.accent.opacity(0.14), Nocturne.playerBg.opacity(0)],
                           startPoint: forward ? .trailing : .leading, endPoint: forward ? UnitPoint(x: 0.55, y: 0.5) : UnitPoint(x: 0.45, y: 0.5))
            HStack(spacing: 28) {
                if forward { pill; arrows("▶▶") } else { arrows("◀◀"); pill }
            }
            .padding(.leading, forward ? 0 : 180)
            .padding(.trailing, forward ? 180 : 0)
            .frame(maxWidth: .infinity, alignment: forward ? .trailing : .leading)
        }
    }

    private var pill: some View {
        Text(text)
            .font(.nocturne(66, .medium)).monospacedDigit()
            .foregroundStyle(Nocturne.accent100)
            .padding(.vertical, 20).padding(.horizontal, 42)
            .background(Nocturne.playerBg.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Nocturne.accent, lineWidth: 1))
            .shadow(color: Nocturne.accent.opacity(0.3), radius: 35)
    }

    private func arrows(_ glyph: String) -> some View {
        Text(glyph).font(.nocturne(72)).foregroundStyle(Nocturne.text.opacity(0.45))
    }
}

/// Frame 13's centre: the pause mark and, after a step, the "Frame ±1" indicator.
private struct PausedCenter: View {
    let framePill: String?

    var body: some View {
        VStack(spacing: 30) {
            ZStack {
                Circle().fill(Nocturne.playerBg.opacity(0.45))
                Circle().stroke(Nocturne.text.opacity(0.4), lineWidth: 3)
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 3).fill(Nocturne.accent100).frame(width: 13, height: 48)
                    RoundedRectangle(cornerRadius: 3).fill(Nocturne.accent100).frame(width: 13, height: 48)
                }
            }
            .frame(width: 126, height: 126)
            if let framePill {
                Text(framePill)
                    .font(.nocturne(40, .medium)).monospacedDigit()
                    .foregroundStyle(Nocturne.accent100)
                    .padding(.vertical, 16).padding(.horizontal, 34)
                    .background(Nocturne.accent.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Nocturne.accent, lineWidth: 1))
                    .shadow(color: Nocturne.accent.opacity(0.32), radius: 30)
                    .accessibilityIdentifier("player.frame")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 300)
    }
}

/// Frames 11 and 12.
private struct TrackPanel: View {
    let model: PlayerModel
    let panel: PlayerModel.Panel

    private var rows: [PlayerModel.TrackItem] { panel == .audio ? model.audioTracks : model.subtitleRows }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Nocturne.playerBg.opacity(0.55)
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Kicker(text: panel == .audio ? "Audio" : "Subtitles")
                    Text(panel == .audio ? "\(model.audioTracks.count) track\(model.audioTracks.count == 1 ? "" : "s")" : model.currentSubtitleName)
                        .font(.nocturne(38, .medium))
                        .foregroundStyle(Nocturne.accent100)
                }
                .padding(.top, 34).padding(.horizontal, 40).padding(.bottom, 26)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) { Rectangle().fill(Nocturne.panelRule).frame(height: 1) }
                if rows.isEmpty {
                    Text("VLCKit reports no \(panel == .audio ? "audio" : "subtitle") tracks yet")
                        .font(.nocturne(24)).foregroundStyle(Nocturne.neutral500)
                        .padding(.vertical, 26).padding(.horizontal, 40)
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    TrackRow(row: row, kind: panel, focused: index == model.panelIndex)
                }
            }
            .frame(width: 760, alignment: .leading)
            .background(Nocturne.panelBg, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Nocturne.neutral600, lineWidth: 1))
            .shadow(color: .black.opacity(0.8), radius: 45, y: 30)
            .padding(.top, 90)
            .padding(.trailing, 80)
        }
    }
}

private struct TrackRow: View {
    let row: PlayerModel.TrackItem
    let kind: PlayerModel.Panel
    let focused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            if kind == .audio {
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.primary)
                        .font(.nocturne(30, .medium))
                        .foregroundStyle(focused || row.selected ? Nocturne.accent100 : Nocturne.neutral300)
                    Text([row.codec, row.layout].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.nocturne(22))
                        .foregroundStyle(row.selected ? Nocturne.accent300 : Nocturne.neutral500)
                }
                Spacer()
            } else {
                Text(row.primary)
                    .font(.nocturne(30, .medium))
                    .foregroundStyle(focused || row.selected ? Nocturne.accent100 : Nocturne.neutral300)
                Spacer()
                Text(row.codec).font(.nocturne(22)).foregroundStyle(Nocturne.neutral500)
            }
            if row.selected {
                Text("✓").font(.nocturne(28)).foregroundStyle(Nocturne.accent400)
            }
        }
        .padding(.vertical, 26).padding(.horizontal, 40)
        .background(focused ? Nocturne.accent.opacity(0.2) : .clear)
        .overlay(alignment: .top) { Rectangle().fill(Nocturne.panelRule).frame(height: 1) }
        .overlay { if focused { Rectangle().stroke(Nocturne.accent, lineWidth: 4).padding(2) } }
    }
}

/// A playback failure, shown in full (no frame exists for it; the wording follows frame 17).
private struct PlaybackError: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Kicker(text: "Playback")
            Text("Can't play this file")
                .font(.nocturne(66, .medium)).kerning(-1.3).foregroundStyle(Nocturne.accent100)
            Text(text)
                .font(.nocturne(27)).foregroundStyle(Nocturne.neutral400)
                .frame(maxWidth: 900, alignment: .leading)
            Text("Menu to go back")
                .font(.nocturne(22)).foregroundStyle(Nocturne.neutral600)
        }
        .padding(.leading, 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Nocturne.playerBg.opacity(0.85))
    }
}
