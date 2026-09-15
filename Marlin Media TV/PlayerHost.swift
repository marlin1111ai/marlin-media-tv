//
//  PlayerHost.swift
//  Marlin Media TV
//
//  The VLCKit drawable and the Siri Remote, in UIKit. The surface view is the one focused
//  element while the player is up (nothing in the SwiftUI overlay is focusable), so every
//  press reaches this controller's `pressesBegan`, every touch its `touchesBegan`, and every
//  swipe its recognizers. Learned from Marlin DVR TV's PlayerHost (Passes 28/29): an edge
//  *click* on the remote is a `UIPress` (.leftArrow/.rightArrow); a swipe is not a press at
//  all, only touches — so click and swipe are told apart here and handed to the model as such.
//  While paused, a horizontal swipe or drag is also a scrub (D021): a pan recognizer that runs
//  alongside the swipes and begins only while paused hands it to the model.
//

import SwiftUI
import UIKit

struct PlayerHost: UIViewControllerRepresentable {
    let model: PlayerModel

    func makeUIViewController(context: Context) -> PlayerHostController {
        PlayerHostController(model: model)
    }

    func updateUIViewController(_ controller: PlayerHostController, context: Context) {}
}

final class PlayerHostController: UIViewController {
    private let model: PlayerModel
    private let surface: SurfaceView

    init(model: PlayerModel) {
        self.model = model
        self.surface = SurfaceView(model: model)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 7 / 255, green: 8 / 255, blue: 12 / 255, alpha: 1)
        surface.frame = view.bounds
        surface.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        surface.backgroundColor = .black
        view.addSubview(surface)
        for (direction, name) in [(UISwipeGestureRecognizer.Direction.left, "left"), (.right, "right"), (.up, "up"), (.down, "down")] {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(swiped(_:)))
            swipe.direction = direction
            swipe.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
            swipe.name = name
            surface.addGestureRecognizer(swipe)
        }
        // D021: while paused, a horizontal swipe or drag scrubs. The pan runs alongside the swipes rather than waiting
        // for them to fail — waiting let every paused flick end as a swipe with no scrub (pass 2d). It begins only
        // while paused and for a drag that travels more across than up or down, so while playing the swipes keep
        // D008's skips (see gestureRecognizerShouldBegin).
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        pan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        pan.name = "scrub"
        pan.delegate = self
        surface.addGestureRecognizer(pan)
        model.attach(drawable: surface)
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] { [surface] }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setNeedsFocusUpdate()
            self?.updateFocusIfNeeded()
        }
    }

    @objc private func swiped(_ gesture: UISwipeGestureRecognizer) {
        guard gesture.state == .ended || gesture.state == .recognized else { return }
        switch gesture.direction {
        case .left: model.handle(.left(source: "swipe"))
        case .right: model.handle(.right(source: "swipe"))
        case .up: model.handle(.up)
        case .down: model.handle(.down)
        default: break
        }
    }

    /// Pass 2a: the drag's horizontal travel as a share of the surface's width.
    @objc private func panned(_ pan: UIPanGestureRecognizer) {
        let fraction = pan.translation(in: surface).x / max(1, surface.bounds.width)
        switch pan.state {
        case .began:
            model.scrubBegan()
            model.scrubMoved(fraction: fraction)
        case .changed:
            model.scrubMoved(fraction: fraction)
        case .ended, .cancelled:
            model.scrubMoved(fraction: fraction)
            model.scrubLifted()
        default: break
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            switch press.type {
            case .select: model.handle(.select); handled = true
            case .playPause: model.handle(.playPause); handled = true
            case .menu: model.handle(.menu); handled = true
            case .leftArrow: model.handle(.left(source: "click")); handled = true
            case .rightArrow: model.handle(.right(source: "click")); handled = true
            case .upArrow: model.handle(.up); handled = true
            case .downArrow: model.handle(.down); handled = true
            default: break
            }
        }
        if !handled { super.pressesBegan(presses, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let ours: Set<UIPress.PressType> = [.select, .playPause, .menu, .leftArrow, .rightArrow, .upArrow, .downArrow]
        if presses.contains(where: { ours.contains($0.type) }) { return }
        super.pressesEnded(presses, with: event)
    }
}

extension PlayerHostController: UIGestureRecognizerDelegate {
    /// D021: the scrub pan begins only while paused, for a drag that has travelled more across than up or down.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let t = pan.translation(in: pan.view)
        guard abs(t.x) > abs(t.y) else { return false }
        if model.isPlaying {
            EvidenceLog.line("[scrub] drag while playing: no action")
            return false
        }
        return true
    }

    /// The pan and the swipes recognize together, so a paused swipe also scrubs and neither blocks the other.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        gestureRecognizer is UIPanGestureRecognizer || other is UIPanGestureRecognizer
    }
}

/// The focusable view VLCKit draws into (it satisfies VLCDrawable: `addSubview` and `bounds`).
final class SurfaceView: UIView {
    private let model: PlayerModel

    init(model: PlayerModel) {
        self.model = model
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override var canBecomeFocused: Bool { true }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        model.handle(.touch)
        super.touchesBegan(touches, with: event)
    }
}
