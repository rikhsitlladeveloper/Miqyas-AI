import XCTest

/// Walks the app's screens on the simulator and saves a picture of each (CI uploads them for review).
/// Texts are found by their Uzbek (Latin) or Russian labels from strings.json, or by accessibility identifiers.
final class ScreenTests: XCTestCase {
    private var dir: URL? { ProcessInfo.processInfo.environment["SHOTS"].map { URL(fileURLWithPath: $0) } }

    override func setUp() { continueAfterFailure = true }

    func shot(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        if let dir { try? png.write(to: dir.appendingPathComponent(name + ".png")) }
        let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png"); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    private func launch(lang: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiReset"]
        if let lang { app.launchEnvironment["UI_LANG"] = lang }
        app.launch()
        return app
    }

    /// A button or switch whose spoken label starts with text (rows announce their value after the title;
    /// the on/off rows are switches).
    private func btn(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        let p = NSPredicate(format: "label BEGINSWITH %@", text)
        let b = app.buttons.matching(p).firstMatch
        return b.exists ? b : app.switches.matching(p).firstMatch
    }

    private func tapOutside(_ app: XCUIApplication) { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)).tap() }

    /// First start without an account, then the three tabs, the laser sheet, Profile's pages and sheets, dark mode.
    func testFirstRunAndTabs() {
        let app = launch()
        XCTAssertTrue(app.buttons["welcome.skip"].waitForExistence(timeout: 8))
        sleep(1); shot("03-welcome")

        app.buttons["welcome.lang"].tap(); usleep(500_000); shot("04-welcome-lang-menu")
        tapOutside(app)

        app.buttons["Hisob yaratish"].tap(); usleep(700_000); shot("05-signup")
        app.textFields.element(boundBy: 0).tap(); app.textFields.element(boundBy: 0).typeText("Sanjar Usta")
        app.textFields.element(boundBy: 1).tap(); usleep(400_000); shot("06-signup-typing")
        app.buttons["Orqaga"].firstMatch.tap(); usleep(700_000)

        app.buttons["welcome.skip"].tap(); usleep(700_000)
        app.textFields.element(boundBy: 0).tap(); app.textFields.element(boundBy: 0).typeText("Sanjar Usta")
        app.textFields.element(boundBy: 1).tap(); app.textFields.element(boundBy: 1).typeText("901234567")
        shot("07-local-filled")
        app.buttons["local.start"].tap()
        XCTAssertTrue(app.buttons["laser"].waitForExistence(timeout: 5))
        sleep(1); shot("08-home")

        app.buttons["laser"].firstMatch.tap(); usleep(700_000); shot("09-laser-sheet")
        app.buttons["Qidirish"].tap(); sleep(2); shot("10-laser-found")
        app.buttons["Ulash"].tap(); usleep(900_000); shot("11-laser-connected")

        app.buttons["tab.projects"].tap(); usleep(700_000); shot("12-projects-empty")
        app.buttons["tab.profile"].tap(); usleep(700_000); shot("13-profile")
        app.swipeUp(); usleep(500_000); shot("14-profile-scrolled")
        btn(app, "Boshqa sozlamalar").tap(); usleep(800_000); shot("15-settings-more")
        btn(app, "O‘lchov birliklari").tap(); usleep(700_000); shot("16-units-sheet")
        app.buttons["sheet.close"].tap(); usleep(500_000)
        app.buttons["Orqaga"].firstMatch.tap(); usleep(700_000)
        app.swipeDown(); usleep(400_000)
        btn(app, "Ilova tili").tap(); usleep(700_000); shot("17-language-sheet")
        app.buttons["sheet.close"].tap(); usleep(500_000)

        btn(app, "Tungi rejim").tap(); usleep(700_000); shot("18-profile-dark")
        app.buttons["tab.home"].tap(); usleep(700_000); shot("19-home-dark")
        app.buttons["laser"].firstMatch.tap(); usleep(700_000); shot("20-laser-sheet-dark")
    }

    /// The same first screens in Russian, to see long labels and Cyrillic.
    func testRussian() {
        let app = launch(lang: "ru")
        XCTAssertTrue(app.buttons["welcome.skip"].waitForExistence(timeout: 8))
        sleep(1); shot("30-ru-welcome")
        app.buttons["welcome.skip"].tap(); usleep(700_000)
        app.textFields.element(boundBy: 0).tap(); app.textFields.element(boundBy: 0).typeText("Санжар Уста")
        app.textFields.element(boundBy: 1).tap(); app.textFields.element(boundBy: 1).typeText("901234567")
        app.buttons["local.start"].tap()
        XCTAssertTrue(app.buttons["laser"].waitForExistence(timeout: 5))
        sleep(1); shot("31-ru-home")
        app.buttons["tab.profile"].tap(); usleep(700_000); shot("32-ru-profile")
    }
}
