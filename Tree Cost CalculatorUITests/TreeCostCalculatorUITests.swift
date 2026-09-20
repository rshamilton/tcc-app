//
//  TreeCostCalculatorUITests.swift
//  Tree Cost CalculatorUITests
//
//  These tests rely on the DEBUG-only launch arguments in DebugLaunch.swift.
//

import XCTest
import UIKit

final class TreeCostCalculatorUITests: XCTestCase {
    private var app: XCUIApplication!

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // On iPad the estimates list is a sidebar, which is visible in landscape.
        XCUIDevice.shared.orientation = isPad ? .landscapeLeft : .portrait
    }

    private func launch(onboarded: Bool = true, _ extra: [String] = []) {
        // "-hasCompletedOnboarding YES" would override anything the app writes, so only use it to skip onboarding.
        let onboarding = onboarded ? ["-hasCompletedOnboarding", "YES"] : ["-resetOnboarding"]
        app.launchArguments = onboarding + ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        app.launch()
    }

    /// Saves a screenshot when SHOT_DIR is set (used for visual review); always attaches it to the result.
    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SHOT_DIR"] {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }

    private func tapKeyboardDone() {
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        done.tap()
    }

    // MARK: - Flows

    func testOnboardingLeadsToEmptyList() {
        launch(onboarded: false, ["-resetData"])
        for _ in 0..<3 {
            app.buttons["Continue"].tap()
        }
        snap("onboarding-setup")
        app.buttons["Start Estimating"].tap()
        XCTAssertTrue(app.staticTexts["Quote your first tree"].waitForExistence(timeout: 3))
        snap("empty-state")
    }

    func testNewEstimateCalculatesPrice() {
        launch(["-resetData", "-startingFee", "0", "-pricePerCubicFoot", "10", "-taxRate", "0"])
        app.buttons["New Estimate"].tap()

        // A new estimate opens with the first measurement focused.
        let next = app.buttons["Next field"]
        if !next.waitForExistence(timeout: 4) { snap("new-estimate-failed") }
        XCTAssertTrue(next.exists)
        app.typeText("6")
        next.tap()
        app.typeText("50")
        snap("editor-typing")
        tapKeyboardDone()

        // 6² × 50 ÷ 12.56 = 143.31 cu ft → $1,433.12 at $10/cu ft
        XCTAssertTrue(app.staticTexts["$1,433.12"].firstMatch.waitForExistence(timeout: 3))

        app.buttons["Add Another Tree"].tap()
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        app.typeText("4")
        next.tap()
        app.typeText("20")
        tapKeyboardDone()

        // + 4² × 20 ÷ 12.56 = 25.48 cu ft
        XCTAssertTrue(app.staticTexts["$1,687.90"].firstMatch.waitForExistence(timeout: 3))
        snap("editor-two-trees")

        // Going back (iPhone) keeps the estimate in the list; on iPad the list is already showing.
        if !isPad { app.navigationBars.buttons.firstMatch.tap() }
        XCTAssertTrue(app.staticTexts["Untitled Estimate"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["$1,687.90"].exists)
    }

    func testBlankEstimateIsDiscarded() throws {
        try XCTSkipIf(isPad, "iPad keeps the list on screen; covered by the iPad test")
        launch(["-resetData"])
        app.buttons["New Estimate"].tap()
        XCTAssertTrue(app.buttons["Next field"].waitForExistence(timeout: 4))
        tapKeyboardDone()
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Quote your first tree"].waitForExistence(timeout: 3))
    }

    func testPDFPreviewOpens() {
        launch(["-demoData", "-openEstimate", "1", "-showPreview"])
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        sleep(3)
        snap("pdf-preview")
        app.swipeUp(velocity: .slow)
        snap("pdf-preview-2")
        let labels = app.navigationBars.buttons.allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(labels.contains { $0.hasPrefix("Share") }, "Toolbar buttons: \(labels)")
    }

    /// Multi-state work: switching the tax region changes the rate and the label on the summary.
    func testSwitchingTaxRegionUpdatesTax() throws {
        try XCTSkipIf(isPad, "Covered on iPhone")
        launch(["-demoData", "-openEstimate", "0"])
        XCTAssertTrue(app.navigationBars["EST-0005"].waitForExistence(timeout: 5))
        let regionMenu = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Texas'")).firstMatch
        for _ in 0..<4 where !regionMenu.exists { app.swipeUp() }
        snap("tax-region-before")
        XCTAssertTrue(regionMenu.exists, "Menu not found")
        regionMenu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        snap("tax-region-menu")
        app.buttons["Oklahoma (4.5%)"].tap()
        for _ in 0..<3 where !app.staticTexts["Tax – Oklahoma (4.5%)"].exists { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Tax – Oklahoma (4.5%)"].exists)
        snap("tax-region-oklahoma")
    }

    // MARK: - Navigation

    /// Reopening an estimate after going back must work (selection is reset when navigating back).
    func testCanReopenEstimateAfterGoingBack() throws {
        try XCTSkipIf(isPad, "Back navigation is iPhone-only")
        launch(["-demoData"])
        app.staticTexts["Priya Raman"].tap()
        XCTAssertTrue(app.navigationBars["EST-0002"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Priya Raman"].waitForExistence(timeout: 3))
        app.staticTexts["Priya Raman"].tap()
        XCTAssertTrue(app.navigationBars["EST-0002"].waitForExistence(timeout: 3))
    }

    // MARK: - iPad

    func testIPadSplitView() throws {
        try XCTSkipUnless(isPad, "iPad only")
        launch(["-demoData"])
        // Sidebar and a placeholder detail pane.
        XCTAssertTrue(app.staticTexts["Priya Raman"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Select an estimate"].exists)
        snap("ipad-1-landscape-empty-detail")

        // Opening an estimate fills the detail pane while the list stays visible.
        app.staticTexts["Priya Raman"].tap()
        XCTAssertTrue(app.navigationBars["EST-0002"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Jordan Ellis"].exists)
        snap("ipad-2-landscape-editor")
        app.swipeUp(velocity: .slow)
        snap("ipad-3-landscape-editor-scrolled")

        // Switching estimates swaps the detail.
        app.staticTexts["Jordan Ellis"].tap()
        XCTAssertTrue(app.navigationBars["EST-0005"].waitForExistence(timeout: 3))

        // New estimate opens in the detail pane, focused on the first measurement.
        app.buttons["New Estimate"].tap()
        XCTAssertTrue(app.buttons["Next field"].waitForExistence(timeout: 4))
        app.typeText("6")
        app.buttons["Next field"].tap()
        app.typeText("50")
        snap("ipad-4-landscape-typing")
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Untitled Estimate"].waitForExistence(timeout: 3))

        // Portrait: sidebar collapses behind a button, editor takes the width.
        XCUIDevice.shared.orientation = .portraitUpsideDown
        XCUIDevice.shared.orientation = .portrait
        sleep(1)
        snap("ipad-5-portrait")
    }

    func testIPadPreviewAndSettings() throws {
        try XCTSkipUnless(isPad, "iPad only")
        launch(["-demoData", "-openEstimate", "1", "-showPreview"])
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        sleep(3)
        snap("ipad-6-preview")
        app.buttons["Done"].tap()
        sleep(2)
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        sleep(1)
        snap("ipad-7-settings")
    }

    // MARK: - App Store screenshots

    /// Writes App Store screenshots to STORE_DIR (skipped otherwise). Run on the iPhone 6.9" and iPad 13" simulators.
    func testAppStoreScreenshots() throws {
        guard let dir = ProcessInfo.processInfo.environment["STORE_DIR"] else { throw XCTSkip("Only runs when STORE_DIR is set") }
        XCUIDevice.shared.orientation = .portrait
        let device = isPad ? "ipad" : "iphone"
        func store(_ name: String) {
            sleep(1)
            let shot = XCUIScreen.main.screenshot()
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(device)-\(name).png"))
        }
        func scroll(_ times: Int) { for _ in 0..<times { app.swipeUp(velocity: .slow) } }

        launch(["-demoData"])
        XCTAssertTrue(app.staticTexts["Jordan Ellis"].waitForExistence(timeout: 8))
        sleep(2)
        store("01-estimates")

        app.staticTexts["Priya Raman"].tap()
        XCTAssertTrue(app.navigationBars["EST-0002"].waitForExistence(timeout: 5))
        sleep(1)
        store("02-trees-and-photos")
        scroll(1)
        store("03-customer-and-pricing")
        scroll(1)
        store("04-summary")

        app.buttons["Preview & Share"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 6))
        sleep(3)
        store("05-pdf-estimate")
        app.swipeUp(velocity: .slow)
        store("06-pdf-signature")
        app.buttons["Done"].tap()
        sleep(2)

        if !isPad { app.navigationBars.buttons.firstMatch.tap() }
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 4))
        store("07-settings")
        scroll(1)
        store("08-tax-regions")
        scroll(2)
        store("09-your-data")
    }

    // MARK: - Screens for visual review

    func testCaptureScreens() throws {
        try XCTSkipIf(isPad, "See the iPad tests")
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SHOT_DIR"] != nil, "Only runs when SHOT_DIR is set")
        launch(["-demoData"])
        snap("s01-list")

        app.staticTexts["Priya Raman"].tap()
        sleep(1)
        snap("s02-editor-top")
        app.swipeUp(velocity: .slow)
        snap("s03-editor-mid")
        app.swipeUp(velocity: .slow)
        snap("s04-editor-pricing")
        app.swipeUp(velocity: .fast)
        snap("s05-editor-bottom")
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons["Settings"].tap()
        sleep(1)
        snap("s06-settings-top")
        app.swipeUp(velocity: .slow)
        snap("s06b-settings-regions")
        if app.staticTexts["Texas"].firstMatch.exists {
            app.staticTexts["Texas"].firstMatch.tap()
            sleep(1)
            snap("s06c-region-editor")
            app.navigationBars.buttons.firstMatch.tap()
        }
        app.swipeUp(velocity: .fast)
        snap("s07-settings-bottom")
    }
}
