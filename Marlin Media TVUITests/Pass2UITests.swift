//
//  Pass2UITests.swift — evidence harness for pass 2 (2026-09-15). Not a standing test.
//
//  Drives the real Siri Remote on Home Theater through XCUIRemote and photographs the screen, the
//  Marlin DVR TV convention used by EvidenceUITests. Navigation reads which element has focus
//  (`hasFocus == YES`) and never counts presses.
//
//  The playback state each test needs is seeded from the Mac beforehand with
//  `PUT /api/files/{id}/playback` (the one write this pass is allowed), so a test that would
//  otherwise need an hour of playing — resuming, and the 90 % watched mark — runs in seconds.
//  Touch-surface drags are still impossible for XCUIRemote, so the scrub check uses the
//  uncommitted Page Up / Page Down hook of pass 2g.
//

import XCTest

final class Pass2UITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared
    private let headerOrder = ["tab.Movies", "tab.TV Shows", "tab.Videos", "sort"]

    override func setUp() { continueAfterFailure = true }

    // MARK: harness plumbing

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
    }

    private func note(_ t: String) {
        let a = XCTAttachment(string: "\(stamp()) \(t)")
        a.name = "note"; a.lifetime = .keepAlways; add(a)
        NSLog("[p2] %@", t)
    }

    private func stamp() -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f.string(from: Date())
    }

    private func press(_ b: XCUIRemote.Button, _ n: Int = 1, wait: UInt32 = 1) {
        for _ in 0..<n { remote.press(b); sleep(wait) }
    }

    private func focusedIds() -> [String] {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == YES")).allElementsBoundByIndex
            .map { $0.identifier.isEmpty ? "(\($0.label))" : $0.identifier }
    }

    private func isFocused(_ id: String) -> Bool { focusedIds().contains(id) }
    private func isFocused(prefix: String) -> Bool { focusedIds().contains { $0.hasPrefix(prefix) } }

    @discardableResult
    private func moveUntilFocused(_ id: String, pressing b: XCUIRemote.Button, limit: Int = 8) -> Bool {
        for _ in 0..<limit { if isFocused(id) { return true }; press(b) }
        return isFocused(id)
    }

    private func focusHeader() {
        for _ in 0..<10 { if isFocused(prefix: "tab.") || isFocused("sort") { return }; press(.up) }
    }

    private func focusHeaderItem(_ id: String) {
        focusHeader()
        guard let target = headerOrder.firstIndex(of: id) else { return }
        for _ in 0..<8 {
            if isFocused(id) { return }
            let cur = headerOrder.firstIndex { isFocused($0) } ?? 0
            press(cur < target ? .right : .left)
        }
    }

    private func selectTab(_ name: String) { focusHeaderItem("tab.\(name)"); press(.select, wait: 2) }

    private func pickSort(_ option: String) {
        focusHeaderItem("sort")
        press(.select)
        XCTAssertTrue(app.buttons["sort.\(option)"].waitForExistence(timeout: 5), "the sort menu did not open")
        sleep(1)
        _ = moveUntilFocused("sort.\(option)", pressing: .down, limit: 4)
            || moveUntilFocused("sort.\(option)", pressing: .up, limit: 4)
        press(.select, wait: 2)
    }

    private func launch() {
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["tab.Movies"].waitForExistence(timeout: 60), "the library did not load")
        sleep(3)
    }

    /// Into the grid and onto one poster.
    private func openPoster(_ id: String, tab: String) {
        selectTab(tab)
        press(.down)
        for _ in 0..<3 where !isFocused(prefix: "poster.") { press(.down) }
        _ = moveUntilFocused(id, pressing: .right, limit: 6) || moveUntilFocused(id, pressing: .left, limit: 6)
        press(.select, wait: 3)
        XCTAssertTrue(app.staticTexts["detail.title"].waitForExistence(timeout: 20), "the detail screen did not open")
        sleep(2)
    }

    private func leavePlayer() {
        press(.menu, wait: 4)
    }

    // MARK: 1 — the sort control on all three tabs, and the hidden row (steps 1, 3)

    func t1_SortAndEmptyRow() {
        launch()
        note("focus at launch: \(focusedIds())")
        shot("p2-t1-01-movies-title-no-continue-row")
        focusHeaderItem("sort")
        press(.select)
        XCTAssertTrue(app.buttons["sort.Recently Added"].waitForExistence(timeout: 5),
                      "Recently Added is not in the sort menu")
        sleep(1)
        shot("p2-t1-02-sort-menu-three-options")
        _ = moveUntilFocused("sort.Recently Added", pressing: .down, limit: 4)
        press(.select, wait: 2)
        shot("p2-t1-03-movies-recently-added")
        note("movies sorted by Recently Added")

        selectTab("TV Shows")
        sleep(1)
        shot("p2-t1-04-shows-recently-added")
        selectTab("Videos")
        sleep(1)
        shot("p2-t1-05-videos-recently-added")
        selectTab("Movies")
        pickSort("Title")
        shot("p2-t1-06-back-to-title")
    }

    // MARK: 2 — a multi-edition movie: the followed edition, the picker's resume line, the landing
    // (steps 4, 8). Seeded: file 2 (Stargate Extended) at 1800 s.

    func t2_ResumeMultiEdition() {
        launch()
        openPoster("poster.Stargate", tab: "Movies")
        shot("p2-t2-01-detail-resume-button")
        note("detail focus: \(focusedIds())")
        XCTAssertTrue(app.buttons["startover"].exists, "Start over is not on a movie with a saved position")
        XCTAssertTrue(app.buttons["mark"].exists, "the mark button is missing")
        if !isFocused("play") { _ = moveUntilFocused("play", pressing: .up, limit: 6) }
        press(.select, wait: 2)
        XCTAssertTrue(app.buttons["pick.Extended"].waitForExistence(timeout: 5),
                      "the edition picker did not open on a multi-edition movie")
        sleep(1)
        shot("p2-t2-02-picker-resume-line")
        _ = moveUntilFocused("pick.Extended", pressing: .up, limit: 3)
        note("landing: select Extended at \(stamp())")
        press(.select, wait: 2)
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 30), "the player did not appear")
        sleep(12)
        press(.select, wait: 1)      // pause: the overlay shows the clock
        sleep(1)
        shot("p2-t2-03-resumed-clock")
        note("resumed clock shot at \(stamp())")
        press(.select, wait: 1)      // play again
        sleep(6)
        leavePlayer()
        sleep(3)
        shot("p2-t2-04-back-on-detail")
    }

    // MARK: 3 — Start over, Mark watched, Mark unwatched on a movie (step 4)

    func t3_StartOverAndMarks() {
        launch()
        openPoster("poster.Wonder Woman", tab: "Movies")
        shot("p2-t3-01-detail-before")
        if !isFocused("play") { _ = moveUntilFocused("play", pressing: .up, limit: 6) }
        // Start over sits to the right of the Resume button.
        _ = moveUntilFocused("startover", pressing: .right, limit: 3)
        note("start over pressed at \(stamp())")
        press(.select, wait: 3)
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 30), "Start over did not open the player")
        sleep(10)
        shot("p2-t3-02-started-over")
        leavePlayer()
        sleep(3)
        shot("p2-t3-03-detail-after-start-over")

        _ = moveUntilFocused("mark", pressing: .right, limit: 4)
        note("mark watched pressed at \(stamp())")
        press(.select, wait: 4)
        shot("p2-t3-04-marked-watched-pill")
        XCTAssertTrue(app.staticTexts["watched.pill"].waitForExistence(timeout: 10),
                      "the watched pill did not appear after Mark watched")
        _ = moveUntilFocused("mark", pressing: .right, limit: 4)
        note("mark unwatched pressed at \(stamp())")
        press(.select, wait: 4)
        shot("p2-t3-05-marked-unwatched")
    }

    // MARK: 4 — the Continue Watching row on TV Shows, and a card playing an episode with
    // thumbnails (steps 3, 8). Seeded: file 8 (Magicians S1E1) at 900 s.

    func t4_ContinueRowEpisode() {
        launch()
        selectTab("TV Shows")
        sleep(2)
        shot("p2-t4-01-shows-continue-row")
        // Where the focus engine actually goes, rather than an assumption: down from the tabs,
        // then back up if it landed in the grid.
        press(.down)
        note("after down from the header: \(focusedIds())")
        if !isFocused(prefix: "continue.") {
            press(.up)
            note("after up from there: \(focusedIds())")
        }
        if !isFocused(prefix: "continue.") {
            press(.down)
            note("after down again: \(focusedIds())")
        }
        XCTAssertTrue(isFocused(prefix: "continue."), "the continue-watching card could not be focused: \(focusedIds())")
        shot("p2-t4-02-card-focused")
        note("card select at \(stamp())")
        press(.select, wait: 3)
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 40),
                      "the card did not open the player")
        sleep(12)
        press(.select, wait: 1)      // pause
        sleep(1)
        shot("p2-t4-03-episode-resumed")
        // The scrub, with the pass-2g thumbnails, through the Page Up hook.
        note("scrub drag at \(stamp())")
        remote.press(.pageUp)
        usleep(900_000)
        shot("p2-t4-04-scrub-thumbnail")
        sleep(2)
        press(.menu, wait: 2)        // cancel the scrub, still paused
        shot("p2-t4-05-scrub-cancelled")
        press(.select, wait: 1)      // play on
        sleep(5)
        leavePlayer()
        sleep(3)
    }

    // MARK: 5 — the 90 % watched mark and the row losing the entry (steps 3, 7).
    // Seeded: file 5 (Food That Built America S4E2) just under 90 %.

    func t5_NinetyPercent() {
        launch()
        selectTab("TV Shows")
        sleep(2)
        shot("p2-t5-01-row-before")
        press(.down)
        note("entered the row at: \(focusedIds())")
        // The row remembers its own last focused card, so the wanted one is found explicitly
        // rather than assumed to be the first.
        let found = moveUntilFocused("continue.5", pressing: .right, limit: 6)
            || moveUntilFocused("continue.5", pressing: .left, limit: 6)
        XCTAssertTrue(found, "the card for file 5 could not be focused: \(focusedIds())")
        note("card select (file 5, seeded just under 90 %) at \(stamp())")
        press(.select, wait: 3)
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 40), "the player did not appear")
        // Started just under 90 %: the mark is written within seconds of the first picture.
        sleep(40)
        shot("p2-t5-02-past-ninety")
        leavePlayer()
        sleep(4)
        shot("p2-t5-03-row-after")
        note("back on the library at \(stamp())")
    }

    // MARK: 6 — a peek under two minutes leaves no saved spot (step 6)

    func t6_ShortPeek() {
        launch()
        openPoster("poster.Divergent", tab: "Movies")
        shot("p2-t6-01-detail-play-only")
        XCTAssertFalse(app.buttons["startover"].exists, "Start over is showing on a movie with no saved position")
        if !isFocused("play") { _ = moveUntilFocused("play", pressing: .up, limit: 6) }
        note("play (peek) at \(stamp())")
        press(.select, wait: 3)
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 30), "the player did not appear")
        sleep(45)                    // well under the 120 s floor
        note("leaving at \(stamp())")
        leavePlayer()
        sleep(3)
        shot("p2-t6-02-back-on-detail-no-resume")
    }

    // MARK: 7 — the episode hold menu (step 5)

    func t7_EpisodeHoldMenu() {
        launch()
        openPoster("poster.The Magicians", tab: "TV Shows")
        XCTAssertTrue(app.buttons["season.1"].waitForExistence(timeout: 30), "the show detail did not load")
        sleep(2)
        shot("p2-t7-01-show-detail-states")
        _ = moveUntilFocused("episode.1.2", pressing: .down, limit: 5)
        note("press and hold on S1E2 at \(stamp())")
        remote.press(.select, forDuration: 1.2)
        sleep(2)
        shot("p2-t7-02-hold-menu")
        if app.buttons["episode.mark"].waitForExistence(timeout: 5) {
            note("hold menu opened; marking")
            press(.select, wait: 4)
            shot("p2-t7-03-after-mark")
        } else {
            note("HOLD MENU DID NOT OPEN — focus is \(focusedIds())")
            shot("p2-t7-03-hold-menu-missing")
        }
    }

    // MARK: 8 — skips, frame step and the scrub are unchanged (the D008/D021 controls)

    func t8_PlayerUnchanged() {
        launch()
        openPoster("poster.Divergent", tab: "Movies")
        if !isFocused("play") { _ = moveUntilFocused("play", pressing: .up, limit: 6) }
        press(.select, wait: 3)
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 30), "the player did not appear")
        sleep(20)
        note("skip +30 at \(stamp())")
        remote.press(.right); usleep(400_000)
        shot("p2-t8-01-skip-forward")
        sleep(2)
        note("skip −10 at \(stamp())")
        remote.press(.left); usleep(400_000)
        shot("p2-t8-02-skip-back")
        sleep(2)
        press(.select, wait: 2)      // pause
        note("frame steps at \(stamp())")
        for n in 1...3 {
            remote.press(.left)
            sleep(2)
            shot("p2-t8-03-frame-back-\(n)")
        }
        for n in 1...3 {
            remote.press(.right)
            sleep(2)
            shot("p2-t8-04-frame-forward-\(n)")
        }
        note("scrub drag at \(stamp())")
        remote.press(.pageUp)
        usleep(900_000)
        shot("p2-t8-05-scrub")
        sleep(2)
        press(.select, wait: 3)      // land and play
        shot("p2-t8-06-landed")
        sleep(5)
        leavePlayer()
    }
}
