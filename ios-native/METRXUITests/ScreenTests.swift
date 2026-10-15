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

    /// First start without an account, straight to Home.
    private func firstRun(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["welcome.skip"].waitForExistence(timeout: 8))
        app.buttons["welcome.skip"].tap(); usleep(700_000)
        app.textFields.element(boundBy: 0).tap(); app.textFields.element(boundBy: 0).typeText("Sanjar Usta")
        app.textFields.element(boundBy: 1).tap(); app.textFields.element(boundBy: 1).typeText("901234567")
        app.buttons["local.start"].tap()
        XCTAssertTrue(app.buttons["laser"].waitForExistence(timeout: 5))
        usleep(800_000)
    }

    /// Part 2: a new project, a workspace, a note with a checklist, the item menu, Details, the list, delete and Undo.
    func testProjects() {
        let app = launch()
        firstRun(app)
        app.buttons["home.new"].tap(); usleep(900_000); shot("40-new-project")
        app.textFields.element(boundBy: 0).typeText("Yangi uy")
        app.textFields.element(boundBy: 1).tap(); app.textFields.element(boundBy: 1).typeText("Ali Valiyev")
        app.textFields.element(boundBy: 2).tap(); app.textFields.element(boundBy: 2).typeText("901112233")
        app.textFields.element(boundBy: 3).tap(); app.textFields.element(boundBy: 3).typeText("Chilonzor 9")
        shot("41-new-project-filled")
        app.buttons["np.save"].tap(); usleep(1_000_000); shot("42-project")
        app.buttons["ws.create"].tap(); usleep(800_000); shot("43-new-workspace")
        btn(app, "Hammom").tap(); usleep(400_000); shot("44-new-workspace-bath")
        app.buttons["ws.save"].tap(); usleep(1_000_000); shot("45-workspace-blank")
        app.buttons["space.add"].tap(); usleep(800_000); shot("46-add-sheet")
        app.buttons["add.note"].tap(); usleep(1_000_000)
        app.typeText("Bo‘yoq rangi")
        app.textViews.firstMatch.exists ? app.textViews.firstMatch.tap() : app.textFields.element(boundBy: 1).tap()
        app.typeText("Devorlarni oq rangga bo‘yash")
        app.buttons["note.addCheck"].tap(); usleep(500_000); app.typeText("Eshik almashtirilmaydi")
        app.buttons["note.addCheck"].tap(); usleep(500_000); app.typeText("Pol laminat")
        btn(app, "☐").tap(); usleep(400_000)
        shot("47-note")
        app.buttons["Orqaga"].firstMatch.tap(); usleep(900_000); shot("48-workspace-with-note")
        // the note card's own menu (the page's menu comes first)
        let menus = app.buttons.matching(NSPredicate(format: "label == %@", "menu"))
        menus.element(boundBy: max(0, menus.count - 1)).tap(); usleep(700_000); shot("49-item-menu")
        app.buttons["sheet.close"].tap(); usleep(500_000)
        app.buttons["Orqaga"].firstMatch.tap(); usleep(900_000); shot("50-project-with-workspace")
        app.buttons["ptab.info"].tap(); usleep(700_000); shot("51-project-info")
        // the project was made from Home, so its back pill returns there (as on Android); the list is on its own tab
        app.buttons["back"].firstMatch.tap(); usleep(900_000)
        app.buttons["tab.projects"].tap(); usleep(900_000); shot("52-projects-list")
        app.textFields.firstMatch.tap(); app.typeText("Ali"); usleep(500_000); shot("53-projects-search")
        btn(app, "Yangi uy").tap(); usleep(900_000)
        app.buttons["project.menu"].tap(); usleep(600_000)
        btn(app, "Loyihani o‘chirish").tap(); usleep(600_000); shot("54-delete-ask")
        app.buttons["pj.delete"].tap(); usleep(700_000); shot("55-deleted-toast")
        btn(app, "Qaytarish").tap(); usleep(900_000); shot("56-undo")

        // closed and opened again: the project, its workspace and the note are still there
        app.terminate()
        let again = XCUIApplication()
        again.launch()
        XCTAssertTrue(again.buttons["tab.projects"].waitForExistence(timeout: 10))
        again.buttons["tab.projects"].tap(); usleep(900_000)
        XCTAssertTrue(btn(again, "Yangi uy").waitForExistence(timeout: 3))
        btn(again, "Yangi uy").tap(); usleep(900_000)
        XCTAssertTrue(btn(again, "Hammom").waitForExistence(timeout: 3))
        shot("57-after-restart")
    }

    /// A project with one workspace, opened at the workspace page (for the editor tests).
    private func newWorkspace(_ app: XCUIApplication, _ name: String) {
        app.buttons["home.new"].tap(); usleep(900_000)
        app.textFields.element(boundBy: 0).typeText(name)
        app.textFields.element(boundBy: 1).tap(); app.textFields.element(boundBy: 1).typeText(name == "Дом" ? "Иван" : "Ali Valiyev")
        app.buttons["np.save"].tap(); usleep(1_000_000)
        XCTAssertTrue(app.buttons["ws.create"].waitForExistence(timeout: 4))
        app.buttons["ws.create"].tap(); usleep(800_000)
        app.buttons["ws.save"].tap(); usleep(1_000_000)
    }

    private func typeValue(_ app: XCUIApplication, _ v: String) {
        let f = app.textFields["ms.value"]
        XCTAssertTrue(f.waitForExistence(timeout: 3))
        f.tap(); f.typeText(v); usleep(300_000)
    }

    /// Part 3: a rectangle room measured by hand, a door and a window, the full list, the wall view, the laser,
    /// room info, the room card, an L-shaped room and a room drawn by tapping its corners.
    func testEditor() {
        let app = launch()
        firstRun(app)
        newWorkspace(app, "Uy 3")
        app.buttons["space.add"].tap(); usleep(700_000)
        app.buttons["add.sketch"].tap(); usleep(700_000)
        app.buttons["add.plan"].tap(); usleep(800_000); shot("60-new-room")
        app.buttons["nr.create"].tap(); sleep(1); shot("61-editor-tip")
        app.buttons["tip.ok"].tap(); usleep(700_000); shot("62-editor-A")

        app.buttons["ed.manual"].tap(); usleep(700_000)
        typeValue(app, "4"); shot("63-measure-sheet")
        app.textFields["ms.value"].typeText("x"); usleep(300_000)
        app.buttons["ms.save"].tap(); usleep(500_000); shot("64-measure-invalid")
        let f = app.textFields["ms.value"]
        f.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + "5")
        app.buttons["ms.save"].tap(); usleep(900_000); shot("65-editor-A-confirmed")
        app.buttons["ed.manual"].tap(); usleep(700_000); typeValue(app, "4"); app.buttons["ms.save"].tap(); usleep(900_000)
        app.buttons["ed.manual"].tap(); usleep(700_000); typeValue(app, "3"); app.buttons["ms.save"].tap(); usleep(900_000)
        shot("66-editor-measured")

        app.buttons["ed.openings"].tap(); usleep(700_000); shot("67-add-opening")
        app.buttons["ao.door"].tap(); usleep(800_000); shot("68-door-sheet")
        app.buttons["op.save"].tap(); usleep(900_000)
        app.buttons["ed.openings"].tap(); usleep(700_000)
        app.buttons["ao.window"].tap(); usleep(800_000); shot("69-window-sheet")
        app.buttons["op.save"].tap(); usleep(900_000); shot("70-plan-door-window")
        app.buttons["ed.all"].firstMatch.tap(); usleep(900_000); shot("71-full-list")
        app.swipeUp(); usleep(500_000); shot("72-full-list-scrolled")
        app.buttons["ed.all"].firstMatch.tap(); usleep(700_000)

        app.buttons["ed.walls"].tap(); usleep(900_000); shot("73-wall-A")
        app.buttons["wv.next"].tap(); usleep(500_000)
        app.buttons["wv.next"].tap(); usleep(700_000); shot("74-wall-C-window")
        app.buttons["back"].firstMatch.tap(); usleep(900_000)

        // the simulated laser: connect, measure the height again, confirm
        app.buttons["laser"].firstMatch.tap(); usleep(700_000)
        app.buttons["Qidirish"].tap(); sleep(2); app.buttons["Ulash"].tap(); usleep(900_000)
        app.buttons["ed.all"].firstMatch.tap(); usleep(800_000)
        app.otherElements["row.H"].tap(); usleep(700_000)
        app.buttons["ed.all"].firstMatch.tap(); usleep(700_000)
        btn(app, "Qayta o‘lchash").tap(); usleep(700_000); shot("75-remeasure")
        app.buttons["ed.laser"].tap(); usleep(900_000); shot("76-laser-reading")
        app.buttons["ed.confirm"].tap(); usleep(900_000); shot("77-laser-confirmed")

        app.buttons["ed.menu"].tap(); usleep(800_000); shot("78-room-info")
        app.buttons["sheet.close"].tap(); usleep(600_000)
        app.buttons["back"].firstMatch.tap(); usleep(1_000_000); shot("79-workspace-room-card")

        // an L-shaped room
        app.buttons["space.addTile"].tap(); usleep(700_000)
        app.buttons["add.sketch"].tap(); usleep(700_000)
        app.buttons["add.plan"].tap(); usleep(800_000)
        app.buttons["nr.lshape"].tap(); sleep(1); shot("80-lshape-editor")
        app.buttons["back"].firstMatch.tap(); usleep(1_000_000)

        // a room drawn by tapping four corners and the first one again
        app.buttons["space.addTile"].firstMatch.tap(); usleep(700_000)
        app.buttons["add.sketch"].tap(); usleep(700_000)
        app.buttons["add.plan"].tap(); usleep(800_000)
        app.buttons["nr.sketch"].tap(); usleep(900_000); shot("81-sketch")
        app.buttons["seg.t"].tap(); usleep(400_000)
        let pad = app.otherElements["pad"].exists ? app.otherElements["pad"] : app.images["pad"]
        for (x, y) in [(0.2, 0.2), (0.8, 0.2), (0.8, 0.7), (0.2, 0.7), (0.2, 0.2)] {
            pad.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap(); usleep(350_000)
        }
        shot("82-sketch-closed")
        app.buttons["sk.create"].tap(); sleep(1); shot("83-sketch-editor")
        app.buttons["back"].firstMatch.tap(); usleep(1_000_000); shot("84-workspace-three-rooms")
        app.buttons["back"].firstMatch.tap(); usleep(1_000_000); shot("85-project-thumb")
    }

    /// The editor in Russian, to see long labels in the step card and the sheets.
    func testEditorRussian() {
        let app = launch(lang: "ru")
        XCTAssertTrue(app.buttons["welcome.skip"].waitForExistence(timeout: 8))
        app.buttons["welcome.skip"].tap(); usleep(700_000)
        app.textFields.element(boundBy: 0).tap(); app.textFields.element(boundBy: 0).typeText("Санжар Уста")
        app.textFields.element(boundBy: 1).tap(); app.textFields.element(boundBy: 1).typeText("901234567")
        app.buttons["local.start"].tap()
        XCTAssertTrue(app.buttons["laser"].waitForExistence(timeout: 5)); usleep(800_000)
        newWorkspace(app, "Дом")
        app.buttons["space.add"].tap(); usleep(700_000)
        app.buttons["add.sketch"].tap(); usleep(700_000)
        app.buttons["add.plan"].tap(); usleep(800_000)
        app.buttons["nr.create"].tap(); sleep(1)
        app.buttons["tip.ok"].tap(); usleep(700_000); shot("90-ru-editor")
        app.buttons["ed.manual"].tap(); usleep(700_000); typeValue(app, "5,2"); app.buttons["ms.save"].tap(); usleep(900_000)
        app.buttons["ed.openings"].tap(); usleep(700_000)
        app.buttons["ao.window"].tap(); usleep(800_000); shot("91-ru-window-sheet")
        app.buttons["op.save"].tap(); usleep(900_000)
        app.buttons["ed.all"].firstMatch.tap(); usleep(900_000); shot("92-ru-full-list")
    }
}
