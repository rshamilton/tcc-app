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
        // The first launch checks iCloud for a backup before showing onboarding.
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 15))
        for _ in 0..<3 {
            app.buttons["Continue"].tap()
        }
        snap("onboarding-setup")
        let start = app.buttons["Start Estimating"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        // The setup page scrolls; the button can sit below the terms note on small screens.
        for _ in 0..<4 where !start.isHittable { app.swipeUp() }
        start.tap()
        XCTAssertTrue(app.staticTexts["Quote your first tree"].waitForExistence(timeout: 5))
        snap("empty-state")
    }

    func testNewEstimateCalculatesPrice() {
        launch(["-resetData", "-startingFee", "0", "-pricePerCubicFoot", "10", "-taxRate", "0"])
        app.buttons["New Estimate"].tap()

        // A new estimate opens with the first measurement focused.
        let next = app.buttons["Next field"]
        if !next.waitForExistence(timeout: 10) { snap("new-estimate-failed") }
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
        XCTAssertTrue(app.buttons["Next field"].waitForExistence(timeout: 10))
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
        XCTAssertTrue(editorTitle("EST-0005").waitForExistence(timeout: 5))
        let regionMenu = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Texas'")).firstMatch
        // Scroll until the menu is on screen and clear of the bottom bar.
        for _ in 0..<6 where !regionMenu.exists { app.swipeUp() }
        // The bottom bar can cover the row; nudge it up with a short drag.
        let frame = regionMenu.frame
        if frame.maxY > app.frame.height - 160 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
        }
        snap("tax-region-before")
        XCTAssertTrue(regionMenu.exists, "Menu not found")
        regionMenu.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        snap("tax-region-menu")
        app.buttons["Oklahoma (4.5%)"].tap()
        for _ in 0..<3 where !app.staticTexts["Tax – Oklahoma (4.5%)"].exists { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Tax – Oklahoma (4.5%)"].exists)
        snap("tax-region-oklahoma")
    }


    // MARK: - v1.1 features

    /// Scrolls up until the element can be tapped (not off-screen or under the bottom bar).
    private func reveal(_ element: XCUIElement, attempts: Int = 10, file: StaticString = #filePath, line: UInt = #line) {
        // Also clear the bottom total / Preview & Share bar, which floats over the last rows.
        // Once the row is on screen, nudge gently instead of swiping a full screen past it.
        let clearBottom = app.frame.height - 130
        for _ in 0..<attempts where !(element.exists && element.isHittable && element.frame.maxY < clearBottom) {
            if element.exists && element.frame.minY > 150 && element.frame.minY < app.frame.height {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
                    .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
            } else {
                app.swipeUp()
            }
        }
        XCTAssertTrue(element.exists && element.isHittable, "Couldn't scroll to \(element)", file: file, line: line)
    }

    /// Replaces whatever is in a number field.
    private func enter(_ text: String, in field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Missing field \(field)")
        field.tap()
        let current = (field.value as? String) ?? ""
        // An empty field reports its placeholder as the value, so always clear (extra deletes are harmless).
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count + 2))
        field.typeText(text)
    }

    /// The number caption at the top of the editor ("EST-0002 · created ..."). The navigation title shows the
    /// estimate's name now, so the document number is found here instead.
    private func editorTitle(_ number: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", number + " ·")).firstMatch
    }

    private func labelContains(_ text: String) -> NSPredicate { NSPredicate(format: "label CONTAINS %@", text) }

    /// A stump-only job (no trees measured) is priced from Other Work and can be shared.
    func testOtherWorkLineItemTotalsAndEnablesShare() {
        launch(["-resetData", "-startingFee", "0", "-pricePerCubicFoot", "10", "-taxRate", "0"])
        app.buttons["New Estimate"].tap()
        XCTAssertTrue(app.buttons["Next field"].waitForExistence(timeout: 10))
        tapKeyboardDone()

        XCTAssertFalse(app.buttons["Preview & Share"].isEnabled, "Share should be off with nothing to price")

        let addWork = app.buttons["Add Other Work"]
        reveal(addWork)
        addWork.tap()
        let stump = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Stump grinding'")).firstMatch
        XCTAssertTrue(stump.waitForExistence(timeout: 5))
        stump.tap()

        enter("20", in: app.textFields["Quantity for Stump grinding"])
        enter("3", in: app.textFields.matching(NSPredicate(format: "label BEGINSWITH 'Price per'")).firstMatch)
        tapKeyboardDone()
        snap("other-work")

        XCTAssertTrue(app.staticTexts.matching(labelContains("$60.00")).firstMatch.waitForExistence(timeout: 5), "Total should include $60.00. \(app.debugDescription)")
        XCTAssertTrue(app.buttons["Preview & Share"].isEnabled, "A priced line item should enable sharing")
    }

    /// Estimate -> invoice -> paid through the status menu.
    func testCreateInvoiceAndMarkPaid() {
        launch(["-demoData", "-openEstimate", "0"])
        XCTAssertTrue(editorTitle("EST-0005").waitForExistence(timeout: 8))

        app.buttons["Status: Sent"].tap()
        app.buttons["Create Invoice"].tap()
        XCTAssertTrue(editorTitle("INV-0005").waitForExistence(timeout: 5), "Title should become the invoice number")
        XCTAssertTrue(app.buttons["Invoice & Share"].exists)

        app.buttons["Status: Invoiced"].tap()
        app.buttons["Mark as Paid"].tap()
        XCTAssertTrue(app.buttons["Status: Paid"].waitForExistence(timeout: 5))
        snap("invoice-paid")
    }

    /// Naming an estimate shows the name as the navigation title and in the list.
    func testNamingAnEstimateShowsNameInTitleAndList() {
        launch(["-resetData"])
        app.buttons["New Estimate"].tap()
        XCTAssertTrue(app.buttons["Next field"].waitForExistence(timeout: 10))
        tapKeyboardDone()

        let name = app.textFields["estimateNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "No estimate name field")
        name.tap()
        name.typeText("Backyard oak removal")
        tapKeyboardDone()

        XCTAssertTrue(app.navigationBars["Backyard oak removal"].waitForExistence(timeout: 5), "Nav title should show the name")
        snap("named-estimate")

        if !isPad { app.navigationBars.buttons.firstMatch.tap() }
        XCTAssertTrue(app.staticTexts["Backyard oak removal"].waitForExistence(timeout: 5), "Name should show in the list")
    }

    /// A button that can't do anything yet is disabled (and greyed), then comes alive with real measurements.
    func testSignatureButtonDisabledUntilThereIsWork() {
        launch(["-resetData"])
        app.buttons["New Estimate"].tap()
        XCTAssertTrue(app.buttons["Next field"].waitForExistence(timeout: 10))
        tapKeyboardDone()

        let sign = app.buttons["getSignatureButton"]
        reveal(sign)
        XCTAssertFalse(sign.isEnabled, "Signature should be off on an empty estimate")
        snap("signature-disabled")

        for _ in 0..<6 { app.swipeDown() }
        enter("6", in: app.textFields["circumferenceField"])
        enter("50", in: app.textFields["heightField"])
        tapKeyboardDone()

        reveal(sign)
        XCTAssertTrue(sign.isEnabled, "Signature should be on once a tree is measured")
    }

    /// 24 in across is 6.28 ft around (24 x pi / 12).
    func testEnterTrunkDiameterSetsCircumference() {
        launch(["-resetData"])
        app.buttons["New Estimate"].tap()
        XCTAssertTrue(app.buttons["Next field"].waitForExistence(timeout: 10))
        tapKeyboardDone()

        let options = app.buttons["treeOptionsMenu"].firstMatch
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        options.tap()
        let enterDiameter = app.buttons["Enter Trunk Diameter…"]
        XCTAssertTrue(enterDiameter.waitForExistence(timeout: 5))
        enterDiameter.tap()

        let sheetBar = app.navigationBars["Trunk Diameter"]
        XCTAssertTrue(sheetBar.waitForExistence(timeout: 5))
        enter("24", in: app.textFields["trunkDiameterField"])
        snap("trunk-diameter-sheet")
        sheetBar.buttons["Done"].tap()
        XCTAssertTrue(sheetBar.waitForNonExistence(timeout: 5))

        let circumference = app.textFields["circumferenceField"]
        XCTAssertTrue(circumference.waitForExistence(timeout: 5))
        XCTAssertEqual(circumference.value as? String, "6.28")
        XCTAssertTrue(app.staticTexts.matching(labelContains("Diameter ≈ 24")).firstMatch.exists, "Caption should read about 24 in")
    }

    /// Stump grinding from a measured tree: 6 ft around is 22.9 in across, rounded up to 23.
    func testStumpGrindingFromTreeAddsLineItem() {
        launch(["-resetData"])
        app.buttons["New Estimate"].tap()
        XCTAssertTrue(app.buttons["Next field"].waitForExistence(timeout: 10))
        app.typeText("6")
        tapKeyboardDone()

        let addWork = app.buttons["Add Other Work"]
        reveal(addWork)
        addWork.tap()
        let stump = app.buttons.matching(labelContains("about 23 in")).firstMatch
        XCTAssertTrue(stump.waitForExistence(timeout: 5), "No stump grinding entry for the measured tree")
        stump.tap()

        let quantity = app.textFields["lineItemQuantityField"]
        XCTAssertTrue(quantity.waitForExistence(timeout: 5))
        XCTAssertEqual(quantity.value as? String, "23")
        let name = app.textFields["lineItemNameField"]
        XCTAssertEqual(name.value as? String, "Stump grinding – Tree 1")
        snap("stump-from-tree")
    }

    func testSettingsShowsNewRows() {
        launch(["-demoData"])
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 8))
        func item(_ text: String) -> XCUIElement { app.descendants(matching: .any).matching(labelContains(text)).firstMatch }

        for text in ["Services & Prices", "Export All Estimates (CSV)", "Suggest a Feature or Report a Bug", "Rate Tree Cost Calculator"] {
            for _ in 0..<10 where !item(text).exists { app.swipeUp() }
            XCTAssertTrue(item(text).exists, "Missing \(text)")
        }

        let about = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'About'")).firstMatch
        reveal(about)
        about.tap()
        XCTAssertTrue(app.navigationBars["About"].waitForExistence(timeout: 5))
        XCTAssertTrue(item("View Source Code on GitHub").waitForExistence(timeout: 5))
        app.navigationBars["About"].buttons.firstMatch.tap()

        // Services & Prices opens too (a mistyped navigation path used to swallow these taps).
        let services = app.staticTexts.matching(labelContains("Services & Prices")).firstMatch
        for _ in 0..<12 where !(services.exists && services.isHittable) { app.swipeDown() }
        // The list can still be settling after the swipes, which swallows the first tap; tap again if needed.
        for _ in 0..<2 where !app.navigationBars["Services & Prices"].waitForExistence(timeout: 3) {
            if services.isHittable { services.tap() }
        }
        XCTAssertTrue(app.navigationBars["Services & Prices"].waitForExistence(timeout: 5))
    }

    func testCustomerSignatureCanBeSigned() {
        launch(["-demoData", "-openEstimate", "1"])
        XCTAssertTrue(editorTitle("EST-0004").waitForExistence(timeout: 8))

        let sign = app.buttons["Get Customer Signature"]
        reveal(sign)
        sign.tap()

        let pad = app.descendants(matching: .any)["Signature pad"].firstMatch
        XCTAssertTrue(pad.waitForExistence(timeout: 5))
        pad.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: pad.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.6)))
        snap("signature-pad")
        app.buttons["Save"].tap()

        let caption = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Signed by'")).firstMatch
        for _ in 0..<4 where !caption.exists { app.swipeUp() }
        XCTAssertTrue(caption.waitForExistence(timeout: 5), "No signed-by caption")
        XCTAssertTrue(caption.label.contains("Lena Ortiz"))
    }

    // MARK: - Navigation

    /// Reopening an estimate after going back must work (selection is reset when navigating back).
    func testCanReopenEstimateAfterGoingBack() throws {
        try XCTSkipIf(isPad, "Back navigation is iPhone-only")
        launch(["-demoData"])
        app.staticTexts["Priya Raman"].tap()
        XCTAssertTrue(editorTitle("EST-0002").waitForExistence(timeout: 3))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Priya Raman"].waitForExistence(timeout: 3))
        app.staticTexts["Priya Raman"].tap()
        XCTAssertTrue(editorTitle("EST-0002").waitForExistence(timeout: 3))
    }

    /// New Estimate on an empty list opens the editor every time (it used to do nothing, intermittently).
    func testNewEstimateFromEmptyListRepeatedly() throws {
        try XCTSkipIf(isPad, "Covered on iPhone")
        for attempt in 1...4 {
            launch(["-resetData"])
            // Tapped as soon as it's there, and again once the screen has settled.
            if attempt.isMultiple(of: 2) { _ = app.staticTexts["Quote your first tree"].waitForExistence(timeout: 8); sleep(2) }
            app.buttons["New Estimate"].tap()
            XCTAssertTrue(editorTitle("EST-0001").waitForExistence(timeout: 10), "Editor didn't open on attempt \(attempt)")
            app.terminate()
        }
    }

    /// New Estimate works while a status filter hides new drafts (it used to do nothing).
    func testNewEstimateWhileFiltered() throws {
        try XCTSkipIf(isPad, "Covered on iPhone")
        launch(["-demoData"])
        XCTAssertTrue(app.staticTexts["Jordan Ellis"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Approved'")).firstMatch.tap()
        XCTAssertFalse(app.staticTexts["Jordan Ellis"].exists)
        app.buttons["New Estimate"].tap()
        XCTAssertTrue(app.buttons["Next field"].waitForExistence(timeout: 10))
        XCTAssertTrue(editorTitle("EST-0007").exists)
    }

    // MARK: - Backup and restore

    /// A folder the app uses in place of iCloud Drive (`-backupDir`), holding a backup of the demo data.
    private func makeBackup() -> URL {
        let dir = URL(fileURLWithPath: "/tmp/tcc-uitest-\(UUID().uuidString)", isDirectory: true)
        // Without "-hasCompletedOnboarding": -demoData saves it the way finishing onboarding does, so it is backed up.
        app.launchArguments = ["-demoData", "-linkBackup", "-backupDir", dir.path, "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Jordan Ellis"].waitForExistence(timeout: 8))
        XCUIDevice.shared.press(.home) // going to the background syncs straight away
        let fm = FileManager.default
        let deadline = Date().addingTimeInterval(30)
        func count(_ folder: String) -> Int { ((try? fm.contentsOfDirectory(atPath: dir.appendingPathComponent(folder).path)) ?? []).count }
        while Date() < deadline, !(fm.fileExists(atPath: dir.appendingPathComponent("Settings.json").path) && count("Estimates") == 6 && count("Photos") == 5) {
            sleep(1)
        }
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("Settings.json").path), "No settings in the backup")
        XCTAssertEqual(count("Estimates"), 6)
        XCTAssertEqual(count("Photos"), 5)
        app.terminate()
        return dir
    }

    /// Installing on a new device brings back estimates and settings (including having done onboarding).
    func testRestoreOnNewDevice() throws {
        try XCTSkipIf(isPad, "Covered on iPhone")
        let backup = makeBackup()
        app.launchArguments = ["-simulateFreshInstall", "-backupDir", backup.path, "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Jordan Ellis"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["Continue"].exists, "Onboarding shown after restoring")
        snap("restore-new-device")
        app.staticTexts["Priya Raman"].tap()
        XCTAssertTrue(editorTitle("EST-0002").waitForExistence(timeout: 3))
    }

    /// A backup iCloud only finds out about after launch is offered once it shows up.
    func testRestoreOfferedWhenBackupAppearsLater() throws {
        try XCTSkipIf(isPad, "Covered on iPhone")
        let backup = makeBackup()
        let late = URL(fileURLWithPath: "/tmp/tcc-uitest-\(UUID().uuidString)", isDirectory: true)
        app.launchArguments = ["-simulateFreshInstall", "-backupDir", late.path, "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 10), "Expected onboarding with no backup")

        let fm = FileManager.default
        try fm.createDirectory(at: late, withIntermediateDirectories: true)
        for name in try fm.contentsOfDirectory(atPath: backup.path) {
            try fm.copyItem(at: backup.appendingPathComponent(name), to: late.appendingPathComponent(name))
        }
        let alert = app.alerts["Restore from iCloud?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 20))
        snap("restore-offer")
        alert.buttons["Restore"].tap()
        XCTAssertTrue(app.staticTexts["Jordan Ellis"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["Continue"].exists)
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
        XCTAssertTrue(editorTitle("EST-0002").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Jordan Ellis"].exists)
        snap("ipad-2-landscape-editor")
        app.swipeUp(velocity: .slow)
        snap("ipad-3-landscape-editor-scrolled")

        // Switching estimates swaps the detail.
        app.staticTexts["Jordan Ellis"].tap()
        XCTAssertTrue(editorTitle("EST-0005").waitForExistence(timeout: 3))

        // New estimate opens in the detail pane, focused on the first measurement.
        app.buttons["New Estimate"].tap()
        XCTAssertTrue(app.buttons["Next field"].waitForExistence(timeout: 10))
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

    /// Writes App Store screenshots to STORE_DIR (skipped otherwise): `iphone-NN-name.png`, portrait.
    func testAppStoreScreenshots() throws {
        guard let dir = ProcessInfo.processInfo.environment["STORE_DIR"] else { throw XCTSkip("Only runs when STORE_DIR is set") }
        XCUIDevice.shared.orientation = .portrait
        let device = isPad ? "ipad" : "iphone"
        func store(_ name: String) {
            if app.keyboards.count > 0, app.buttons["Done"].firstMatch.exists { app.buttons["Done"].firstMatch.tap() }
            sleep(2)
            let shot = XCUIScreen.main.screenshot()
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(device)-\(name).png"))
        }
        func text(_ s: String) -> XCUIElement { app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", s)).firstMatch }
        /// Scrolls so the element's top sits near the top of the screen, below the navigation bar.
        func bringToTop(_ element: XCUIElement) {
            reveal(element)
            for _ in 0..<5 {
                let delta = element.frame.minY - 135
                if abs(delta) < 25 { break }
                let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
                let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55 - delta / app.frame.height))
                from.press(forDuration: 0.1, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.6)
                sleep(1)
            }
        }

        launch(["-demoData"])
        XCTAssertTrue(app.staticTexts["Jordan Ellis"].waitForExistence(timeout: 8))
        sleep(2)
        store("01-estimates")

        app.staticTexts["Priya Raman"].tap()
        XCTAssertTrue(editorTitle("EST-0002").waitForExistence(timeout: 5))
        sleep(1)
        store("02-estimate-top")

        let otherWork = app.staticTexts["OTHER WORK"].firstMatch.exists ? app.staticTexts["OTHER WORK"].firstMatch : app.staticTexts["Other Work"].firstMatch
        for _ in 0..<8 where !otherWork.exists { app.swipeUp() }
        bringToTop(otherWork)
        store("03-other-work")

        let signedBy = text("Signed by")
        // Start the shot at the Summary heading so every price line (tree removal, other work, …) is visible.
        let summary = app.staticTexts["SUMMARY"].firstMatch.exists ? app.staticTexts["SUMMARY"].firstMatch : app.staticTexts["Summary"].firstMatch
        for _ in 0..<10 where !summary.exists { app.swipeUp() }
        bringToTop(summary)
        store("04-summary")

        for _ in 0..<8 where !signedBy.exists { app.swipeUp() }
        reveal(signedBy)
        for _ in 0..<2 {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        }
        store("05-signature")

        app.buttons["previewShareButton"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 6))
        sleep(3)
        store("06-pdf-estimate")
        app.buttons["Done"].tap()
        sleep(2)
        if !isPad { app.navigationBars.buttons.firstMatch.tap() }

        // The invoice (Dana Whitfield, "Dead ash removal").
        app.staticTexts["Dana Whitfield"].tap()
        XCTAssertTrue(app.buttons["Invoice & Share"].waitForExistence(timeout: 5))
        app.buttons["Invoice & Share"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 6))
        sleep(3)
        store("07-pdf-invoice")
        app.buttons["Done"].tap()
        sleep(2)
        if !isPad { app.navigationBars.buttons.firstMatch.tap() }

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 4))
        let services = text("Services & Prices")
        for _ in 0..<10 where !services.exists { app.swipeUp() }
        reveal(services)
        // The form can still be settling after scrolling, which swallows a tap; tap again until it opens.
        for _ in 0..<3 where !app.navigationBars["Services & Prices"].exists {
            if services.isHittable { services.tap() }
            _ = app.navigationBars["Services & Prices"].waitForExistence(timeout: 3)
        }
        XCTAssertTrue(app.navigationBars["Services & Prices"].waitForExistence(timeout: 5))
        store("08-services")
        app.navigationBars["Services & Prices"].buttons.firstMatch.tap()

        for _ in 0..<3 { app.swipeDown() }
        store("09-settings")
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
