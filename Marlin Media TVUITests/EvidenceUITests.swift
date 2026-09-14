//
//  EvidenceUITests.swift
//  Marlin Media TVUITests
//
//  Pass 1's evidence harness, not a standing test (the Marlin DVR TV convention). It runs on
//  the physical Apple TV "Home Theater", drives the Siri Remote through XCUIRemote, and
//  photographs the screen with XCUIScreen. Navigation reads which element has focus (the
//  `hasFocus == YES` predicate) and presses from there, never a counted number of presses.
//  The app's own log (VLCKit's file logger plus the "[player]" lines, in Library/Caches) is
//  copied off the device afterwards with `devicectl device copy from`.
//  It makes no server write of any kind: every request the app sends is a GET.
//
//  Library order under Title sort on 2026-09-13: Divergent, Stargate, Wonder Woman;
//  The Food That Built America, The Magicians.
//

import XCTest

final class EvidenceUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["tab.Movies"].waitForExistence(timeout: 60),
                      "the library did not load: \(app.staticTexts["error.message"].exists ? app.staticTexts["error.message"].label : "no error shown")")
        sleep(3)
    }

    // MARK: helpers

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        note("shot \(name) — focus: \(focusedIds())")
    }

    private func note(_ text: String) {
        let attachment = XCTAttachment(string: text)
        attachment.name = "note"
        attachment.lifetime = .keepAlways
        add(attachment)
        NSLog("[harness] %@", text)
    }

    private func press(_ button: XCUIRemote.Button, _ times: Int = 1, wait: UInt32 = 1) {
        for _ in 0..<times {
            remote.press(button)
            sleep(wait)
        }
    }

    private func focusedIds() -> [String] {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == YES")).allElementsBoundByIndex
            .map { $0.identifier.isEmpty ? "(\($0.label))" : $0.identifier }
    }

    private func isFocused(_ id: String) -> Bool { focusedIds().contains(id) }

    private func isFocused(prefix: String) -> Bool { focusedIds().contains { $0.hasPrefix(prefix) } }

    /// Presses `button` until `id` has focus (up to `limit` presses).
    @discardableResult
    private func moveUntilFocused(_ id: String, pressing button: XCUIRemote.Button, limit: Int = 8) -> Bool {
        for _ in 0..<limit {
            if isFocused(id) { return true }
            press(button)
        }
        let ok = isFocused(id)
        XCTAssertTrue(ok, "could not focus \(id); focus is \(focusedIds())")
        return ok
    }

    /// Up until the header row (a tab or the sort control) has focus.
    private func focusHeader() {
        for _ in 0..<8 {
            if isFocused(prefix: "tab.") || isFocused("sort") { return }
            press(.up)
        }
        XCTFail("could not reach the header; focus is \(focusedIds())")
    }

    private let headerOrder = ["tab.Movies", "tab.TV Shows", "tab.Videos", "sort"]

    private func focusHeaderItem(_ id: String) {
        focusHeader()
        guard let target = headerOrder.firstIndex(of: id) else { return }
        for _ in 0..<8 {
            if isFocused(id) { return }
            let current = headerOrder.firstIndex { isFocused($0) } ?? 0
            press(current < target ? .right : .left)
        }
        XCTAssertTrue(isFocused(id), "could not focus \(id); focus is \(focusedIds())")
    }

    /// Tabs switch on click: focus the tab, then Select.
    private func selectTab(_ name: String) {
        focusHeaderItem("tab.\(name)")
        press(.select, wait: 2)
    }

    private func pickSort(_ option: String) {
        focusHeaderItem("sort")
        press(.select)
        XCTAssertTrue(app.buttons["sort.\(option)"].waitForExistence(timeout: 5), "the sort menu did not open; focus is \(focusedIds())")
        sleep(1)
        if option == "Year" { moveUntilFocused("sort.Year", pressing: .down, limit: 3) } else { moveUntilFocused("sort.Title", pressing: .up, limit: 3) }
        press(.select, wait: 2)
    }

    /// From anywhere in the library: the Movies tab, down into the grid, along to the poster, select.
    private func openPoster(_ id: String, tab: String) {
        selectTab(tab)
        press(.down)
        if !isFocused(prefix: "poster.") { press(.down) }
        let ok = moveUntilFocused(id, pressing: .right, limit: 6) || moveUntilFocused(id, pressing: .left, limit: 6)
        XCTAssertTrue(ok, "poster \(id) not reached; focus is \(focusedIds())")
        press(.select, wait: 3)
        XCTAssertTrue(app.staticTexts["detail.title"].waitForExistence(timeout: 20), "the detail screen did not open; focus is \(focusedIds())")
        sleep(2)
    }

    private func pressPlay() {
        if !isFocused("play") { moveUntilFocused("play", pressing: .up, limit: 6) }
        press(.select, wait: 2)
    }

    private func waitForPlayer(_ seconds: UInt32) {
        XCTAssertTrue(app.otherElements["player"].waitForExistence(timeout: 20), "the player did not appear; focus is \(focusedIds())")
        note("player up; state text: \(app.staticTexts["player.state"].exists ? app.staticTexts["player.state"].label : "(overlay hidden)")")
        sleep(seconds)
    }

    /// Pause then resume: the overlay is visible for the next 4 s while playing.
    private func bumpOverlay() {
        press(.select, wait: 1)
        press(.select, wait: 1)
    }

    private func leavePlayer() {
        press(.menu, wait: 3)
        XCTAssertFalse(app.otherElements["player"].exists, "the player did not close on Menu")
    }

    // MARK: 1 — library, sort, tabs (frames 01, 02, 04, 05)

    func test1_Library() {
        note("launch focus: \(focusedIds())")
        shot("01-library-movies-title")
        focusHeaderItem("sort")
        press(.select)
        XCTAssertTrue(app.buttons["sort.Year"].waitForExistence(timeout: 5), "the sort menu did not open; focus is \(focusedIds())")
        sleep(1)
        shot("05-sort-open")
        moveUntilFocused("sort.Year", pressing: .down, limit: 3)
        press(.select, wait: 2)
        shot("01b-library-movies-year")
        pickSort("Title")
        selectTab("TV Shows")
        shot("02-library-shows")
        selectTab("Videos")
        XCTAssertTrue(app.staticTexts["No videos yet"].waitForExistence(timeout: 5), "the Videos empty state did not show")
        shot("04-videos-empty")
    }

    // MARK: 2 — Divergent (4K HDR HEVC, DTS 7.1)

    func test2_Divergent() {
        openPoster("poster.Divergent", tab: "Movies")
        shot("06-movie-detail-divergent")
        pressPlay()                      // one edition: plays directly
        waitForPlayer(25)
        bumpOverlay()
        shot("10-player-divergent")
        leavePlayer()
    }

    // MARK: 3 — Stargate, both editions, frame step while paused (frame 13)

    func test3_Stargate() {
        openPoster("poster.Stargate", tab: "Movies")
        shot("06-movie-detail-stargate")
        pressPlay()                      // two editions: the picker
        XCTAssertTrue(app.buttons["pick.Extended"].waitForExistence(timeout: 5), "the edition picker did not open; focus is \(focusedIds())")
        sleep(1)
        shot("07-edition-picker")
        moveUntilFocused("pick.Extended", pressing: .up, limit: 3)
        press(.select, wait: 2)
        waitForPlayer(15)
        bumpOverlay()
        shot("10-player-stargate-extended")
        press(.select, wait: 2)          // pause
        shot("13-paused-stargate")
        press(.right, wait: 2)           // frame forward (native next-frame), first
        press(.right, wait: 0)
        usleep(350_000)
        shot("13-frame-forward-stargate")
        sleep(3)
        press(.left, wait: 3)            // frame back (seek), second
        press(.left, wait: 0)
        usleep(350_000)
        shot("13-frame-back-stargate")
        sleep(3)
        press(.select, wait: 2)          // resume
        leavePlayer()
        pressPlay()
        XCTAssertTrue(app.buttons["pick.Theatrical"].waitForExistence(timeout: 5), "the edition picker did not reopen; focus is \(focusedIds())")
        sleep(1)
        moveUntilFocused("pick.Theatrical", pressing: .down, limit: 3)
        press(.select, wait: 2)
        waitForPlayer(15)
        bumpOverlay()
        shot("10-player-stargate-theatrical")
        leavePlayer()
    }

    // MARK: 4 — Wonder Woman (4K HDR HEVC, TrueHD 7.1): skips (14, 15), audio (11) and subtitle (12) panels

    func test4_WonderWoman() {
        openPoster("poster.Wonder Woman", tab: "Movies")
        pressPlay()
        waitForPlayer(25)
        bumpOverlay()
        shot("10-player-wonder-woman")
        press(.right, wait: 0)           // +30 s while playing
        usleep(250_000)
        shot("15-skip-forward")
        sleep(2)
        press(.left, wait: 0)            // −10 s while playing
        usleep(250_000)
        shot("14-skip-back")
        sleep(2)
        bumpOverlay()
        press(.up)                       // focus Audio
        press(.select, wait: 2)          // open the audio panel
        XCTAssertTrue(app.staticTexts["AUDIO"].waitForExistence(timeout: 5), "the audio panel did not open")
        shot("11-audio-panel")
        press(.up)                       // first track (TrueHD 7.1) — VLC chose AC-3 on its own
        press(.select, wait: 6)          // switch: the log shows whether TrueHD decodes
        shot("11-audio-truehd-selected")
        sleep(6)                         // let the TrueHD decoder run
        bumpOverlay()
        press(.up)
        press(.select, wait: 2)          // reopen the audio panel: the check should sit on TrueHD
        shot("11-audio-panel-truehd-checked")
        press(.down)                     // third track (AC-3 5.1)
        press(.down)
        press(.select, wait: 4)
        bumpOverlay()
        press(.up)                       // Audio
        press(.right)                    // Subtitles
        press(.select, wait: 2)          // open the subtitle panel
        XCTAssertTrue(app.staticTexts["SUBTITLES"].waitForExistence(timeout: 5), "the subtitle panel did not open")
        shot("12-subtitle-panel")
        press(.down)                     // the PGS track
        press(.select, wait: 6)          // switch on
        bumpOverlay()
        shot("10-player-wonder-woman-after-switch")
        leavePlayer()
    }

    // MARK: 5 — The Magicians S1E1 (1080p H.264, AAC stereo; frame 08)

    func test5_MagiciansEpisode() {
        openPoster("poster.The Magicians", tab: "TV Shows")
        XCTAssertTrue(app.buttons["season.1"].waitForExistence(timeout: 30), "the show detail did not load its seasons")
        sleep(2)
        shot("08-show-detail-magicians")
        moveUntilFocused("episode.1.1", pressing: .down, limit: 4)
        press(.select, wait: 2)
        waitForPlayer(20)
        bumpOverlay()
        shot("10-player-magicians-s01e01")
        leavePlayer()
    }
}
