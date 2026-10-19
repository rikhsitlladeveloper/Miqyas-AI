import XCTest

/// Walks the app's screens on the simulator and saves a picture of each (CI uploads them for review). One class per
/// part, so CI lists the results part by part; the steps they share are here.
/// Texts are found by their Uzbek (Latin) or Russian labels from strings.json, or by accessibility identifiers.
class ScreenTestCase: XCTestCase {
    var dir: URL? { ProcessInfo.processInfo.environment["SHOTS"].map { URL(fileURLWithPath: $0) } }

    override func setUp() { continueAfterFailure = true }

    func shot(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        if let dir { try? png.write(to: dir.appendingPathComponent(name + ".png")) }
        let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png"); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    func launch(lang: String? = nil, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiReset"] + extra
        if let lang { app.launchEnvironment["UI_LANG"] = lang }
        app.launch()
        return app
    }

    /// A button or switch whose spoken label starts with text (rows announce their value after the title;
    /// the on/off rows are switches).
    func btn(_ app: XCUIApplication, _ text: String) -> XCUIElement {
        let p = NSPredicate(format: "label BEGINSWITH %@", text)
        let b = app.buttons.matching(p).firstMatch
        return b.exists ? b : app.switches.matching(p).firstMatch
    }

    /// The question after sign-in (furniture plan section 3): which trade; builders unless the test says otherwise.
    func pickIndustry(_ app: XCUIApplication, _ id: String = "ind.build") {
        XCTAssertTrue(app.buttons["ind.go"].waitForExistence(timeout: 8))
        app.buttons[id].tap(); usleep(400_000); app.buttons["ind.go"].tap(); usleep(600_000)
    }

    func tapOutside(_ app: XCUIApplication) { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)).tap() }

    /// First start without an account, straight to Home.
    func firstRun(_ app: XCUIApplication, _ industry: String = "ind.build") {
        XCTAssertTrue(app.buttons["welcome.skip"].waitForExistence(timeout: 20))
        sleep(4)    // the launch animation (3.4 s) covers the welcome screen until it rises
        app.buttons["welcome.skip"].tap(); usleep(700_000)
        XCTAssertTrue(app.textFields.element(boundBy: 0).waitForExistence(timeout: 5))
        app.textFields.element(boundBy: 0).tap(); app.textFields.element(boundBy: 0).typeText("Sanjar Usta")
        app.textFields.element(boundBy: 1).tap(); app.textFields.element(boundBy: 1).typeText("901234567")
        app.buttons["local.start"].tap(); pickIndustry(app, industry)
        XCTAssertTrue(app.buttons["laser"].waitForExistence(timeout: 10))
        usleep(800_000)
    }

    /// A project with one workspace, opened at the workspace page (for the editor tests).
    func newWorkspace(_ app: XCUIApplication, _ name: String) {
        app.buttons["home.new"].tap(); usleep(900_000)
        app.textFields.element(boundBy: 0).typeText(name)
        app.textFields.element(boundBy: 1).tap(); app.textFields.element(boundBy: 1).typeText(name == "Дом" ? "Иван" : "Ali Valiyev")
        app.buttons["np.save"].tap(); usleep(1_000_000)
        XCTAssertTrue(app.buttons["ws.create"].waitForExistence(timeout: 4))
        app.buttons["ws.create"].tap(); usleep(800_000)
        app.buttons["ws.save"].tap(); usleep(1_000_000)
    }

    func typeValue(_ app: XCUIApplication, _ v: String) {
        let f = app.textFields["ms.value"]
        XCTAssertTrue(f.waitForExistence(timeout: 3))
        f.tap(); f.typeText(v); usleep(300_000)
    }

    /// A rectangle room measured by hand with a door and a window (for the 3D tests).
    func measuredRoom(_ app: XCUIApplication, _ a: String, _ b: String, _ h: String, openings: Bool) {
        app.buttons["ed.manual"].tap(); usleep(700_000); typeValue(app, a); app.buttons["ms.save"].tap(); usleep(900_000)
        app.buttons["ed.manual"].tap(); usleep(700_000); typeValue(app, b); app.buttons["ms.save"].tap(); usleep(900_000)
        app.buttons["ed.manual"].tap(); usleep(700_000); typeValue(app, h); app.buttons["ms.save"].tap(); usleep(900_000)
        guard openings else { return }
        app.buttons["ed.openings"].tap(); usleep(700_000); app.buttons["ao.door"].tap(); usleep(800_000); app.buttons["op.save"].tap(); usleep(900_000)
        app.buttons["ed.openings"].tap(); usleep(700_000); app.buttons["ao.window"].tap(); usleep(800_000); app.buttons["op.save"].tap(); usleep(900_000)
    }

    /// Types a row's name into the open row sheet (its first field).
    func typeName(_ app: XCUIApplication, _ v: String) {
        let f = app.textFields.element(boundBy: 0)
        XCTAssertTrue(f.waitForExistence(timeout: 4))
        f.tap(); f.typeText(v); usleep(300_000)
    }

    /// Replaces a field's text.
    func retype(_ app: XCUIApplication, _ id: String, _ v: String) {
        let f = app.textFields[id]
        XCTAssertTrue(f.waitForExistence(timeout: 3))
        f.tap(); f.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 10) + v); usleep(300_000)
    }

    func typeIn(_ app: XCUIApplication, _ id: String, _ v: String) {
        let f = app.textFields[id]
        XCTAssertTrue(f.waitForExistence(timeout: 3))
        f.tap(); f.typeText(v); usleep(300_000)
    }

    func drag(_ el: XCUIElement, _ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) {
        el.coordinate(withNormalizedOffset: CGVector(dx: a.0, dy: a.1)).press(forDuration: 0.15, thenDragTo: el.coordinate(withNormalizedOffset: CGVector(dx: b.0, dy: b.1)))
        usleep(600_000)
    }
}

/// Part 1: first start, tabs, Profile, Russian.
final class Part1Tests: ScreenTestCase {
    /// First start without an account, then the three tabs, the laser sheet, Profile's pages and sheets, dark mode.
    func testFirstRunAndTabs() {
        let app = launch()
        XCTAssertTrue(app.buttons["welcome.skip"].waitForExistence(timeout: 20)); sleep(3)
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
        app.buttons["local.start"].tap(); pickIndustry(app)
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
        XCTAssertTrue(app.buttons["welcome.skip"].waitForExistence(timeout: 20)); sleep(3)
        sleep(1); shot("30-ru-welcome")
        app.buttons["welcome.skip"].tap(); usleep(700_000)
        app.textFields.element(boundBy: 0).tap(); app.textFields.element(boundBy: 0).typeText("Санжар Уста")
        app.textFields.element(boundBy: 1).tap(); app.textFields.element(boundBy: 1).typeText("901234567")
        app.buttons["local.start"].tap(); pickIndustry(app)
        XCTAssertTrue(app.buttons["laser"].waitForExistence(timeout: 5))
        sleep(1); shot("31-ru-home")
        app.buttons["tab.profile"].tap(); usleep(700_000); shot("32-ru-profile")
    }
}

/// Part 2: projects, workspaces, notes.
final class Part2Tests: ScreenTestCase {
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
        sleep(4)    // the launch animation covers the tabs for 3.4 s
        again.buttons["tab.projects"].tap(); usleep(900_000)
        XCTAssertTrue(btn(again, "Yangi uy").waitForExistence(timeout: 3))
        btn(again, "Yangi uy").tap(); usleep(900_000)
        XCTAssertTrue(btn(again, "Hammom").waitForExistence(timeout: 3))
        shot("57-after-restart")
    }
}

/// Part 3: the room editor.
final class Part3Tests: ScreenTestCase {
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

        sleep(6)    // the toast over the top bar (5.2 s with Undo) goes away first
        app.buttons["ed.menu"].tap(); usleep(800_000); shot("78-room-info")
        app.buttons["sheet.close"].tap(); usleep(600_000)
        app.buttons["back"].firstMatch.tap(); usleep(1_000_000); shot("79-workspace-room-card")

        // an L-shaped room
        app.buttons["space.addTile"].tap(); usleep(700_000)
        app.buttons["add.sketch"].tap(); usleep(700_000)
        app.buttons["add.plan"].tap(); usleep(800_000)
        app.buttons["nr.lshape"].tap(); sleep(1); shot("80-lshape-editor")
        sleep(4)    // the "created" toast covers the back button for 3.4 s
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
        sleep(4)
        app.buttons["back"].firstMatch.tap(); usleep(1_000_000); shot("84-workspace-three-rooms")
        app.buttons["Orqaga"].firstMatch.tap(); usleep(1_000_000); shot("85-project-thumb")
    }
    /// The editor in Russian, to see long labels in the step card and the sheets.
    func testEditorRussian() {
        let app = launch(lang: "ru")
        XCTAssertTrue(app.buttons["welcome.skip"].waitForExistence(timeout: 20)); sleep(3)
        app.buttons["welcome.skip"].tap(); usleep(700_000)
        app.textFields.element(boundBy: 0).tap(); app.textFields.element(boundBy: 0).typeText("Санжар Уста")
        app.textFields.element(boundBy: 1).tap(); app.textFields.element(boundBy: 1).typeText("901234567")
        app.buttons["local.start"].tap(); pickIndustry(app)
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

/// Part 4: 3D.
final class Part4Tests: ScreenTestCase {
    /// Part 4: the room in 3D (views, colours, a saved view, turning and zooming), then the project's 2D and 3D views.
    func testThreeD() {
        let app = launch()
        firstRun(app)
        newWorkspace(app, "Uy 4")
        app.buttons["space.add"].tap(); usleep(700_000)
        app.buttons["add.sketch"].tap(); usleep(700_000)
        app.buttons["add.plan"].tap(); usleep(800_000)
        app.buttons["nr.create"].tap(); sleep(1)
        app.buttons["tip.ok"].tap(); usleep(700_000)
        measuredRoom(app, "5", "4", "3", openings: true)
        sleep(6)    // the last toast goes away
        app.buttons["ed.3d"].tap(); sleep(3); shot("100-room-3d")
        app.buttons["3d.top"].tap(); sleep(1); shot("101-from-above")
        app.buttons["3d.corner"].tap(); usleep(500_000)
        app.buttons["wc.2"].tap(); usleep(500_000); app.buttons["fc.1"].tap(); sleep(1); shot("102-colours")
        app.buttons["3d.save"].tap(); sleep(2); shot("103-view-saved")
        let win = app.windows.firstMatch
        win.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4)).press(forDuration: 0.1, thenDragTo: win.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.45)))
        sleep(1); shot("104-turned")
        let scene = app.otherElements["scene3d"].firstMatch
        if scene.exists { scene.pinch(withScale: 1.6, velocity: 1.5) } else { win.pinch(withScale: 1.6, velocity: 1.5) }
        sleep(1); shot("105-zoomed")
        app.buttons["mode.plan"].tap(); usleep(900_000); shot("106-back-to-plan")

        // a second room, then the project's 2D and 3D views
        app.buttons["back"].firstMatch.tap(); usleep(1_000_000)
        app.buttons["space.addTile"].firstMatch.tap(); usleep(700_000)
        app.buttons["add.sketch"].tap(); usleep(700_000)
        app.buttons["add.plan"].tap(); usleep(800_000)
        app.buttons["nr.create"].tap(); sleep(1)
        measuredRoom(app, "4", "3", "3", openings: false)
        sleep(6)
        app.buttons["back"].firstMatch.tap(); usleep(1_000_000)
        app.buttons["Orqaga"].firstMatch.tap(); usleep(1_000_000); shot("107-project-buttons")
        app.buttons["pj.v2d"].tap(); sleep(1); shot("108-project-2d")
        app.buttons["view.3d"].tap(); sleep(3); shot("109-project-3d")
        app.buttons["v3.room"].firstMatch.tap(); sleep(1); shot("110-zoomed-to-room")
        app.buttons["3d.all"].tap(); sleep(1); shot("111-all-rooms")
    }
}

/// Part 5: the Smeta tab.
final class Part5Tests: ScreenTestCase {
    /// Part 5: the Smeta tab — empty state, a quick add from the walls with 10 % spare, materials and labour, a wrong
    /// amount, a draft kept and cleared, editing and deleting, and the BUILD_PLAN total 4 240 000.
    func testEstimate() {
        let app = launch()
        firstRun(app)
        newWorkspace(app, "Uy 5")
        app.buttons["space.add"].tap(); usleep(700_000)
        app.buttons["add.sketch"].tap(); usleep(700_000)
        app.buttons["add.plan"].tap(); usleep(800_000)
        app.buttons["nr.create"].tap(); sleep(1)
        app.buttons["tip.ok"].tap(); usleep(700_000)
        measuredRoom(app, "5", "4", "3", openings: true)
        sleep(6)
        app.buttons["back"].firstMatch.tap(); usleep(1_000_000)
        app.buttons["Orqaga"].firstMatch.tap(); usleep(1_000_000)
        app.buttons["ptab.estimate"].tap(); usleep(900_000); shot("120-estimate-empty")

        // a quick add: wallpaper by the net wall area, with 10 % spare
        app.buttons["es.quick"].firstMatch.tap(); usleep(900_000)
        app.buttons["gs.fromWall"].tap(); usleep(400_000)
        app.buttons["gs.reserve"].tap(); usleep(400_000)
        typeIn(app, "gs.price", "120000"); shot("121-row-from-walls")
        app.buttons["gs.save"].tap(); usleep(1_000_000); shot("122-estimate-one-row")

        // paint and flooring, the second with "Add another"
        app.buttons["gs.addMat"].tap(); usleep(900_000)
        app.typeText("Bo'yoq"); typeIn(app, "gs.qty", "12"); typeIn(app, "gs.price", "50000")
        app.buttons["gs.again"].tap(); usleep(900_000)
        app.typeText("Laminat"); typeIn(app, "gs.qty", "22"); typeIn(app, "gs.price", "120000")
        app.buttons["gs.save"].tap(); usleep(1_000_000)

        // labour: a wrong amount first, then a draft kept, brought back and cleared
        app.buttons["gs.addLab"].tap(); usleep(900_000)
        app.typeText("Ish haqi"); typeIn(app, "gs.sum", "12.5")
        app.buttons["gs.save"].tap(); usleep(600_000); shot("123-labour-wrong-amount")
        app.buttons["sheet.close"].tap(); usleep(900_000); shot("124-draft-kept")
        app.buttons["gs.addLab"].tap(); usleep(900_000); shot("125-draft-back")
        app.buttons["gs.dClear"].tap(); usleep(500_000)
        app.typeText("Ish haqi"); typeIn(app, "gs.sum", "1000000")
        app.buttons["gs.save"].tap(); usleep(1_000_000); shot("126-estimate-full")
        app.swipeUp(); usleep(600_000); shot("127-estimate-scrolled")

        // edit the wallpaper row and delete it: what is left is the BUILD_PLAN estimate
        app.swipeDown(); usleep(600_000)
        app.buttons["es.row"].firstMatch.tap(); usleep(900_000); shot("128-edit-row")
        app.buttons["gs.del"].tap(); sleep(1)
        let grand = app.staticTexts["es.grand"]
        XCTAssertTrue(grand.waitForExistence(timeout: 3))
        XCTAssertEqual(grand.label, "4 240 000")
        shot("129-build-plan-total")
        app.buttons["es.walls"].tap(); usleep(900_000); shot("130-areas-sheet")
        app.buttons["sheet.close"].tap(); usleep(600_000)
        app.buttons["ptab.rooms"].tap(); usleep(700_000); shot("131-header-estimate")
    }
}

/// Part 6: the report and quotes.
final class Part6Tests: ScreenTestCase {
    /// Part 6: the report of a measured room with its estimate — pages, the zoom viewer, set-up (language), sharing the
    /// draft, issuing quote №1, the Quotes tab, the frozen quote, and the Smeta tab noticing a change after it.
    func testReport() {
        let app = launch()
        firstRun(app)
        newWorkspace(app, "Uy 6")
        app.buttons["space.add"].tap(); usleep(700_000)
        app.buttons["add.sketch"].tap(); usleep(700_000)
        app.buttons["add.plan"].tap(); usleep(800_000)
        app.buttons["nr.create"].tap(); sleep(1)
        app.buttons["tip.ok"].tap(); usleep(700_000)
        measuredRoom(app, "5", "4", "3", openings: true)
        sleep(6)
        app.buttons["back"].firstMatch.tap(); usleep(1_000_000)
        app.buttons["Orqaga"].firstMatch.tap(); usleep(1_000_000)
        app.buttons["ptab.estimate"].tap(); usleep(900_000)
        app.buttons["es.addMat"].tap(); usleep(900_000)
        typeName(app, "Bo'yoq"); typeIn(app, "gs.qty", "12"); typeIn(app, "gs.price", "50000")
        app.buttons["gs.again"].tap(); usleep(900_000)
        typeName(app, "Laminat"); typeIn(app, "gs.qty", "22"); typeIn(app, "gs.price", "120000")
        app.buttons["gs.save"].tap(); usleep(1_000_000)
        app.swipeUp(); usleep(600_000)
        app.buttons["gs.addLab"].tap(); usleep(900_000); shot("139-labour-sheet")
        typeName(app, "Ish haqi"); typeIn(app, "gs.sum", "1000000")
        app.buttons["gs.save"].tap(); sleep(4)
        app.swipeDown(); usleep(600_000)

        app.buttons["es.preview"].tap(); sleep(3); shot("140-report")
        XCTAssertEqual(app.staticTexts["rp.total"].label, "4 240 000 so‘m")
        app.buttons["rp.next"].tap(); sleep(1); shot("141-report-page2")
        app.buttons["rp.next"].tap(); sleep(1); shot("142-report-page3")
        app.images["rp.page"].firstMatch.tap(); sleep(2); shot("143-viewer")
        app.buttons["pv.zoom"].tap(); sleep(2); shot("144-viewer-zoomed")
        app.buttons["pv.close"].tap(); usleep(700_000)
        app.buttons["rp.setup"].tap(); usleep(900_000); shot("145-setup")
        app.buttons["rl.ru"].tap(); usleep(900_000)
        app.buttons["rp.done"].tap(); sleep(3); shot("146-report-russian")
        app.buttons["rp.setup"].tap(); usleep(900_000); app.buttons["rl.uz"].tap(); usleep(600_000); app.buttons["rp.done"].tap(); sleep(3)

        // the draft as a PDF into the share sheet
        app.buttons["rp.shareDraft"].tap(); sleep(4); shot("147-share-sheet")
        let close = app.buttons["Close"].firstMatch
        if close.waitForExistence(timeout: 3) { close.tap() } else { app.swipeDown() }
        sleep(1)

        // issue quote №1, take the offer to move the stage
        app.buttons["rp.issue"].tap(); usleep(900_000); shot("148-issue-sheet")
        app.buttons["iss.go"].tap(); sleep(1); shot("149-quote-issued")
        let move = btn(app, "Ko‘chirish")
        if move.waitForExistence(timeout: 3) { move.tap(); usleep(700_000) }
        shot("150-quotes-tab")
        app.buttons["quote.card"].firstMatch.tap(); sleep(3); shot("151-quote-frozen")
        app.buttons["back"].firstMatch.tap(); usleep(900_000)

        // a change after the quote: the Smeta tab says so
        app.buttons["ptab.estimate"].tap(); usleep(900_000)
        app.buttons["es.row"].firstMatch.tap(); usleep(900_000)
        let qty = app.textFields["gs.qty"]
        qty.tap(); qty.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + "14")
        app.buttons["gs.save"].tap(); sleep(1); shot("152-estimate-changed")
        app.buttons["ptab.quotes"].tap(); usleep(900_000); shot("153-quote-differs")
    }
}

/// Part 7: the Measure page, drawings, photos, the camera.
final class Part7Tests: ScreenTestCase {
    /// Part 7a: the Measure page (manual readings, the area, wall and brick tools, the laser, the readings list, sending
    /// a reading), Kalkulyator, Profile's PDF parts and door/window sizes, and the editor's readings tray.
    func testMeasure() {
        let app = launch()
        firstRun(app)
        app.buttons["home.measure"].tap(); usleep(900_000); shot("160-measure")
        app.buttons["qm.manual"].tap(); usleep(800_000)
        typeIn(app, "qm.value", "4.2"); app.buttons["qm.save"].tap(); usleep(900_000)
        app.buttons["qm.manual"].tap(); usleep(800_000)
        typeIn(app, "qm.value", "3"); app.buttons["qm.save"].tap(); usleep(900_000); shot("161-area")
        XCTAssertEqual(app.staticTexts["qc.result"].label, "12,60 m²")
        app.buttons["qm.connect"].tap(); usleep(700_000)
        app.buttons["Qidirish"].tap(); sleep(2); app.buttons["Ulash"].tap(); usleep(900_000)
        app.buttons["qc.wall"].tap(); usleep(400_000)
        app.buttons["qm.measure"].tap(); usleep(500_000); app.buttons["qm.measure"].tap(); usleep(700_000); shot("162-wall-laser")
        app.buttons["qc.brick"].tap(); usleep(400_000)
        app.swipeUp(); usleep(600_000)    // the reading chips are under the button bar until the page scrolls
        app.buttons.matching(identifier: "qm.chip").element(boundBy: 0).tap(); usleep(300_000); app.buttons.matching(identifier: "qm.chip").element(boundBy: 1).tap(); usleep(600_000); shot("163-bricks")
        app.buttons["qb.change"].tap(); usleep(900_000); shot("164-brick-sheet")
        app.buttons["sheet.close"].tap(); usleep(600_000)
        app.buttons["meas.cont"].tap(); usleep(400_000); app.buttons["qc.live"].tap(); sleep(2); shot("165-continuous")
        app.buttons["qc.live"].tap(); usleep(500_000)
        app.swipeUp(); usleep(500_000)
        app.buttons["qc.list"].tap(); usleep(700_000); shot("166-readings-list")
        app.buttons["qm.send"].firstMatch.tap(); usleep(800_000); shot("167-send-no-rooms")
        app.buttons["sheet.close"].tap(); usleep(600_000)
        app.buttons["back"].firstMatch.tap(); usleep(900_000)
        app.buttons["home.calc"].tap(); usleep(1_200_000); shot("168-calculator")
        app.buttons["back"].firstMatch.tap(); usleep(900_000)

        // Profile: PDF parts, door and window sizes
        app.buttons["tab.profile"].tap(); usleep(800_000)
        btn(app, "PDF tarkibi").tap(); usleep(800_000)
        app.buttons["pdf.sign"].tap(); usleep(400_000); shot("169-pdf-parts")
        app.buttons["sheet.close"].tap(); usleep(600_000)
        btn(app, "Eshik va deraza").tap(); usleep(800_000)
        let dw = app.textFields["df.dw"]
        dw.tap(); dw.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + "0,8"); shot("170-defaults")
        app.buttons["df.save"].tap(); usleep(800_000); shot("171-profile-after")

        // the readings tray in a room
        app.buttons["tab.home"].tap(); usleep(800_000)
        newWorkspace(app, "Uy 7")
        app.buttons["space.add"].tap(); usleep(700_000)
        app.buttons["add.sketch"].tap(); usleep(700_000)
        app.buttons["add.plan"].tap(); usleep(800_000)
        app.buttons["nr.create"].tap(); sleep(1)
        app.buttons["tip.ok"].tap(); usleep(700_000)
        app.buttons["ed.tray"].tap(); usleep(900_000); shot("172-tray")
        app.buttons["tr.A"].firstMatch.tap(); usleep(900_000); shot("173-reading-on-wall-A")
    }
    /// Part 7b and 7c: a free drawing (pen, a line with its length, text), a photo with a dimension and a caption, the
    /// workspace cards, the Measure page's camera choice, the live camera's no-camera screen, a picture taken there and
    /// moved into the project. The photo pickers give a drawn sample picture (-uiSamplePhoto).
    func testMarkup() {
        let app = launch(extra: ["-uiSamplePhoto"])
        firstRun(app)
        newWorkspace(app, "Uy 8")
        app.buttons["space.add"].tap(); usleep(700_000)
        app.buttons["add.sketch"].tap(); usleep(700_000)
        app.buttons["add.free"].tap(); sleep(1); shot("180-drawing-empty")
        let cv = app.descendants(matching: .any).matching(identifier: "mk.canvas").firstMatch
        XCTAssertTrue(cv.waitForExistence(timeout: 3))
        drag(cv, (0.2, 0.3), (0.6, 0.5))
        app.buttons["mk.line"].tap(); usleep(400_000)
        drag(cv, (0.15, 0.7), (0.85, 0.7)); usleep(500_000); shot("181-line-length")
        typeIn(app, "mk.value", "3.6"); app.buttons["mk.save"].tap(); usleep(800_000)
        app.buttons["mk.text"].tap(); usleep(400_000)
        cv.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap(); usleep(900_000)
        typeName(app, "Shkaf"); app.buttons["mk.textSave"].tap(); usleep(800_000); shot("182-drawing")
        app.buttons["back"].firstMatch.tap(); usleep(900_000)

        app.buttons["space.addTile"].firstMatch.tap(); usleep(700_000)
        app.buttons["add.photo"].tap(); usleep(700_000)
        app.buttons["add.gallery"].tap(); sleep(2); shot("183-photo")
        app.buttons["mk.dim"].tap(); usleep(400_000)
        drag(cv, (0.36, 0.75), (0.62, 0.75)); usleep(500_000)
        typeIn(app, "mk.value", "0.9"); app.buttons["mk.save"].tap(); usleep(800_000)
        app.buttons["mk.caption"].tap(); usleep(800_000)
        typeName(app, "Eshik o'rni"); app.buttons["mk.captionSave"].tap(); usleep(800_000); shot("184-photo-dimension")
        app.buttons["back"].firstMatch.tap(); usleep(900_000); shot("185-workspace-cards")

        // the Measure page's camera
        app.buttons["Orqaga"].firstMatch.tap(); usleep(900_000)
        app.buttons["back"].firstMatch.tap(); usleep(900_000)
        app.buttons["tab.home"].tap(); usleep(700_000)
        app.buttons["home.measure"].tap(); usleep(900_000)
        app.buttons["qm.camera"].tap(); usleep(800_000); shot("186-camera-pick")
        app.buttons["cm.live"].tap(); sleep(2); shot("187-live-camera-ask")
        // iPhone asks for the camera first; refusing shows the screen with "Surat olish"
        let deny = XCUIApplication(bundleIdentifier: "com.apple.springboard").buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Don")).firstMatch
        if deny.waitForExistence(timeout: 4) { deny.tap(); sleep(1) }
        shot("187-live-camera-refused")
        app.buttons["lc.photo"].tap(); sleep(2); shot("188-picture")
        app.buttons["back"].firstMatch.tap(); usleep(900_000); shot("189-measure-pictures")
        app.buttons["qm.shot"].firstMatch.tap(); usleep(900_000)
        app.buttons["mk.menu"].tap(); usleep(800_000)
        app.buttons["cm.toProj"].tap(); usleep(800_000); shot("190-move-to-project")
        app.buttons["cm.toWs"].firstMatch.tap(); usleep(900_000); shot("191-moved")
    }
}

/// Furniture makers, part 1: the industry question, the furniture Home, a new order, its stages, approval with the
/// prepayment, a payment, the Orders list, Profile → Soha and the sheets tool.
final class Furniture1Tests: ScreenTestCase {
    func testOrders() {
        let app = launch()
        XCTAssertTrue(app.buttons["welcome.skip"].waitForExistence(timeout: 20)); sleep(4)
        app.buttons["welcome.skip"].tap(); usleep(700_000)
        app.textFields.element(boundBy: 0).tap(); app.textFields.element(boundBy: 0).typeText("Jasur Usta")
        app.textFields.element(boundBy: 1).tap(); app.textFields.element(boundBy: 1).typeText("932104455")
        app.buttons["local.start"].tap()
        XCTAssertTrue(app.buttons["ind.go"].waitForExistence(timeout: 8)); usleep(500_000); shot("f1-01-industry")
        app.buttons["ind.furn"].tap(); usleep(500_000); shot("f1-02-industry-picked")
        app.buttons["ind.go"].tap()
        XCTAssertTrue(app.buttons["laser"].waitForExistence(timeout: 8)); sleep(1); shot("f1-03-home")

        app.buttons["home.new"].tap(); usleep(900_000)
        app.textFields.element(boundBy: 0).typeText("Oshxona Chilonzor 9")
        app.textFields.element(boundBy: 1).tap(); app.textFields.element(boundBy: 1).typeText("Dilnoza Karimova")
        shot("f1-04-new-order")
        app.buttons["np.save"].tap(); sleep(1); shot("f1-05-order")

        app.buttons["ptab.info"].tap(); usleep(800_000); shot("f1-06-stages")
        app.buttons["fo.next"].tap(); usleep(700_000)          // measure → design
        app.buttons["fo.next"].tap(); usleep(700_000)          // design → quote
        app.buttons["fo.next"].tap(); usleep(900_000)          // quote → the approval sheet
        let price = app.textFields.element(boundBy: 0)
        XCTAssertTrue(price.waitForExistence(timeout: 4))
        price.tap(); price.typeText("32067100"); usleep(500_000); shot("f1-07-approve")
        app.buttons["fo.approve"].tap(); sleep(4); shot("f1-08-approved")
        app.swipeUp(); usleep(600_000); shot("f1-09-payments")
        app.buttons["fo.addPay"].tap(); usleep(900_000); shot("f1-10-add-payment")
        app.buttons["fo.paySave"].tap(); sleep(4); shot("f1-11-paid-off")

        app.buttons["tab.projects"].tap(); usleep(900_000); shot("f1-12-orders")
        app.buttons["tab.profile"].tap(); usleep(900_000)
        btn(app, "Soha").tap(); usleep(800_000); shot("f1-13-industry-sheet")
        app.buttons["sheet.close"].tap(); usleep(600_000)
        // Home's tab still shows the order: a second tap goes back to Home
        app.buttons["tab.home"].tap(); usleep(800_000); app.buttons["tab.home"].tap(); usleep(900_000)
        app.buttons["home.sheets"].tap(); sleep(1); shot("f1-14-sheets-tool")
    }
}

/// Furniture makers, part 2: sockets, water, sewer and gas marked on the walls of a measured room; the plan and 3D show them.
final class Furniture2Tests: ScreenTestCase {
    func testSitePoints() {
        let app = launch()
        firstRun(app, "ind.furn")
        newWorkspace(app, "Oshxona Chilonzor 9")
        app.buttons["space.add"].tap(); usleep(700_000)
        app.buttons["add.sketch"].tap(); usleep(700_000)
        app.buttons["add.plan"].tap(); usleep(800_000)
        app.buttons["nr.create"].tap(); sleep(1)
        app.buttons["tip.ok"].tap(); usleep(700_000)
        measuredRoom(app, "3,4", "2,6", "2,7", openings: false)
        sleep(6)    // the last toast goes away
        app.buttons["ed.walls"].tap(); usleep(900_000); shot("f2-01-wall-empty")
        app.buttons["pt.add"].tap(); usleep(900_000); shot("f2-02-point-sheet")
        app.buttons["pt.cold"].tap(); usleep(400_000)
        retype(app, "pt.off", "1,3"); retype(app, "pt.h", "0,55"); shot("f2-03-cold-water")
        app.buttons["pt.save"].tap(); sleep(1)
        app.buttons["pt.add"].tap(); usleep(900_000)
        app.buttons["pt.sewer"].tap(); usleep(400_000)
        retype(app, "pt.off", "1,34"); app.buttons["pt.save"].tap(); sleep(1)
        app.buttons["pt.add"].tap(); usleep(900_000)
        retype(app, "pt.off", "0,52"); app.buttons["pt.save"].tap(); sleep(1)       // a socket at 300
        app.buttons["pt.add"].tap(); usleep(900_000)
        app.buttons["pt.cold"].tap(); usleep(400_000)
        retype(app, "pt.off", "5"); app.buttons["pt.save"].tap(); usleep(800_000); shot("f2-04-past-the-wall")
        app.buttons["sheet.close"].tap(); sleep(5); shot("f2-05-wall-A-points")
        app.buttons["wv.next"].tap(); usleep(700_000)
        app.buttons["wv.add"].tap(); usleep(800_000); shot("f2-06-wall-add")
        app.buttons["wa.point"].tap(); usleep(900_000)
        app.buttons["pt.gas"].tap(); usleep(400_000)
        retype(app, "pt.off", "0,9"); app.buttons["pt.save"].tap(); sleep(5); shot("f2-07-wall-B-gas")
        app.buttons["back"].tap(); usleep(900_000); shot("f2-08-plan")
        app.buttons["ed.3d"].tap(); sleep(3); shot("f2-09-3d")
    }
}

/// iPhone furniture part 3: Profile → the workshop's rules (a value changes the sample unit's cost) and its boards and
/// hardware (a new handle).
final class Furniture3Tests: ScreenTestCase {
    func testWorkshop() {
        let app = launch()
        firstRun(app, "ind.furn")
        app.buttons["tab.profile"].tap(); usleep(900_000); shot("f3-01-profile")
        app.buttons["pf.workshop"].tap(); usleep(900_000); shot("f3-02-workshop")
        let before = app.staticTexts["wk.costV"].label
        app.buttons["wk.gap"].tap(); usleep(800_000)
        retype(app, "wk.value", "2"); shot("f3-03-gap-sheet")
        app.buttons["wk.save"].tap(); usleep(900_000)
        app.buttons["wk.margin"].tap(); usleep(800_000)
        retype(app, "wk.value", "abc"); shot("f3-04-bad-value")
        app.buttons["sheet.close"].tap(); usleep(700_000)
        app.buttons["wk.rAsm"].tap(); usleep(800_000)
        retype(app, "wk.value", "150000"); app.buttons["wk.save"].tap(); usleep(900_000)
        app.swipeUp(); usleep(600_000); shot("f3-05-sample")
        XCTAssertNotEqual(app.staticTexts["wk.costV"].label, before)
        sleep(5)    // the toast over the back button goes away
        app.buttons["back"].tap(); usleep(900_000)
        app.buttons["pf.mats"].tap(); usleep(900_000); shot("f3-06-materials")
        app.buttons["mt.ldsp16k"].tap(); usleep(900_000); shot("f3-07-board-sheet")
        app.buttons["sheet.close"].tap(); usleep(700_000)
        btn(app, "Furnitura").tap(); usleep(700_000); shot("f3-08-hardware")
        app.buttons["mt.add"].tap(); usleep(900_000)
        retype(app, "mt.name", "Tutqich GTV 160"); retype(app, "mt.price", "32000")
        app.buttons["hk.handle"].tap(); usleep(400_000); shot("f3-09-new-handle")
        app.buttons["mt.save"].tap(); usleep(900_000)
        app.swipeUp(); usleep(600_000); shot("f3-10-hardware-list")
        XCTAssertTrue(app.staticTexts["Tutqich GTV 160"].exists)
    }
}

/// iPhone furniture part 4: the kitchen designer on a measured room (A 3400, B 2600, cold water on A at 1300): an
/// L-kitchen, auto fill on both walls, a unit made narrower, a unit and a dishwasher from the library, the checks,
/// the boards, undo.
final class Furniture4Tests: ScreenTestCase {
    func testKitchen() {
        let app = launch()
        firstRun(app, "ind.furn")
        newWorkspace(app, "Oshxona Yunusobod")
        app.buttons["space.add"].tap(); usleep(700_000)
        app.buttons["add.sketch"].tap(); usleep(700_000)
        app.buttons["add.plan"].tap(); usleep(800_000)
        app.buttons["nr.create"].tap(); sleep(1)
        app.buttons["tip.ok"].tap(); usleep(700_000)
        measuredRoom(app, "3,4", "2,6", "2,7", openings: false)
        sleep(6)    // the last toast goes away
        app.buttons["ed.walls"].tap(); usleep(900_000)
        app.buttons["pt.add"].tap(); usleep(900_000)
        app.buttons["pt.cold"].tap(); usleep(400_000)
        retype(app, "pt.off", "1,3"); app.buttons["pt.save"].tap(); sleep(5)
        shot("f4-00a-wall"); app.buttons["back"].tap(); sleep(2); shot("f4-00b-after-back")
        // the plan's own back button (another page's may still be in the tree)
        app.buttons.matching(identifier: "back").allElementsBoundByIndex.last { $0.isHittable }?.tap(); sleep(2); shot("f4-01-workspace")
        XCTAssertTrue(app.buttons["space.addTile"].waitForExistence(timeout: 4))
        app.buttons["space.addTile"].tap(); usleep(900_000); shot("f4-02-add-sheet")
        app.buttons["add.furn"].tap(); usleep(900_000); shot("f4-03-new-furniture")
        app.buttons["nf.lL"].tap(); usleep(500_000); shot("f4-04-L-layout")
        app.buttons["nf.start"].tap(); sleep(2); shot("f4-05-empty-wall")
        app.buttons["kt.auto"].tap(); sleep(1); shot("f4-06-auto-A")
        sleep(4)
        app.swipeUp(); usleep(700_000); shot("f4-07-checks-cost")
        app.swipeDown(); usleep(700_000)
        // pick the first lower unit: near the left end of the drawing, just above the floor line
        let elev = app.otherElements["kt.elev"]
        elev.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.62)).tap(); usleep(800_000); shot("f4-08-selected")
        app.buttons["kt.setup"].tap(); usleep(900_000); shot("f4-09-unit-sheet")
        app.buttons["km.w400"].tap(); usleep(400_000)
        app.buttons["km.f1"].exists ? app.buttons["km.f1"].tap() : ()
        shot("f4-10-unit-400")
        app.buttons["km.save"].tap(); sleep(1); shot("f4-11-after-save")
        sleep(4)
        app.buttons["kt.lib.module"].tap(); usleep(900_000); shot("f4-12-library")
        app.buttons["lib.drawers.450"].tap(); sleep(1); shot("f4-13-drawers-added")
        sleep(4)
        app.buttons["kt.lib.appl"].tap(); usleep(900_000); shot("f4-14-appliances")
        app.buttons["lib.dishwasher"].tap(); sleep(1)
        sleep(4)
        app.swipeUp(); usleep(700_000); shot("f4-15-over-checks")
        app.swipeDown(); usleep(700_000)
        app.buttons["kt.undo"].tap(); usleep(800_000); shot("f4-16-undo")
        app.buttons["kt.wall.B"].tap(); usleep(900_000)
        // the first fill covers every wall of a new kitchen; B has its own button only when still empty
        if app.buttons["kt.auto"].exists { app.buttons["kt.auto"].tap() }; sleep(1); shot("f4-17-auto-B")
        sleep(4)
        app.buttons["kt.menu"].tap(); usleep(900_000)
        app.buttons["fm.mats"].tap(); usleep(900_000)
        app.buttons["fmat.front.ldsp18a"].tap(); usleep(700_000); shot("f4-18-mats")
        app.buttons["sheet.close"].tap(); usleep(900_000); shot("f4-19-dark-fronts")
        app.buttons["back"].tap(); usleep(900_000); shot("f4-20-workspace-card")
        XCTAssertTrue(app.buttons["furn.card"].exists || app.otherElements["furn.card"].exists)
    }
}

/// iPhone furniture part 5: the wardrobe designer on a measured room (A 3400, B 2600, height 2700): a built-in
/// wardrobe on wall D, five sections with one 500 wide, doors, the inside of a section, the boards.
final class Furniture5Tests: ScreenTestCase {
    func testWardrobe() {
        let app = launch()
        firstRun(app, "ind.furn")
        newWorkspace(app, "Shkaf Chilonzor")
        app.buttons["space.add"].tap(); usleep(700_000)
        app.buttons["add.sketch"].tap(); usleep(700_000)
        app.buttons["add.plan"].tap(); usleep(800_000)
        app.buttons["nr.create"].tap(); sleep(1)
        app.buttons["tip.ok"].tap(); usleep(700_000)
        measuredRoom(app, "3,4", "2,6", "2,7", openings: false)
        sleep(6)    // the last toast goes away
        app.buttons.matching(identifier: "back").allElementsBoundByIndex.last { $0.isHittable }?.tap(); sleep(2)
        XCTAssertTrue(app.buttons["space.addTile"].waitForExistence(timeout: 4))
        app.buttons["space.addTile"].tap(); usleep(900_000)
        app.buttons["add.furn"].tap(); usleep(900_000)
        app.buttons["nf.wardrobe"].tap(); usleep(600_000)
        app.buttons["nf.c3"].tap(); usleep(500_000); shot("f5-01-new-wardrobe")
        app.buttons["nf.start"].tap(); sleep(2); shot("f5-02-place")
        sleep(4)
        app.buttons["wd.step2"].tap(); usleep(800_000)
        app.buttons["wd.secs.plus"].tap(); usleep(800_000); shot("f5-03-five-sections")
        app.buttons["wd.secW1"].tap(); usleep(900_000)
        retype(app, "wf.value", "500"); shot("f5-04-section-width")
        app.buttons["wf.save"].tap(); usleep(900_000); shot("f5-05-sizes")
        app.buttons["wd.step3"].tap(); usleep(800_000)
        app.buttons["wd.sec2"].tap(); usleep(500_000)
        btn(app, "1 eshik").tap(); usleep(700_000); shot("f5-06-doors")
        app.buttons["wd.step4"].tap(); usleep(800_000)
        app.buttons["wd.sec1"].tap(); usleep(500_000)
        app.buttons["wd.add.drawer"].tap(); sleep(1)
        app.buttons["wd.add.drawer"].tap(); sleep(1)
        app.buttons["wd.more"].tap(); usleep(900_000); shot("f5-07-more")
        app.buttons["wm.shoe"].tap(); sleep(1); shot("f5-08-inside")
        sleep(4)
        app.swipeUp(); usleep(700_000); shot("f5-09-checks")
        app.swipeDown(); usleep(700_000)
        app.buttons["wd.step5"].tap(); usleep(800_000); shot("f5-10-materials")
        app.buttons["wd.mat.front"].tap(); usleep(900_000)
        app.buttons["fmat.front.mdf18"].tap(); usleep(700_000)
        app.buttons["sheet.close"].tap(); usleep(900_000); shot("f5-11-mdf-fronts")
        app.buttons["back"].tap(); sleep(1); shot("f5-12-workspace-card")
        XCTAssertTrue(app.buttons["furn.card"].exists || app.otherElements["furn.card"].exists)
    }
}

/// iPhone furniture part 6: the kitchen and a wardrobe in 3D (CI only: the VM's simulator has no GPU for RealityKit).
final class Furniture6Tests: ScreenTestCase {
    func testFurnitureIn3D() {
        let app = launch()
        firstRun(app, "ind.furn")
        newWorkspace(app, "Oshxona 3D")
        app.buttons["space.add"].tap(); usleep(700_000)
        app.buttons["add.sketch"].tap(); usleep(700_000)
        app.buttons["add.plan"].tap(); usleep(800_000)
        app.buttons["nr.create"].tap(); sleep(1)
        app.buttons["tip.ok"].tap(); usleep(700_000)
        measuredRoom(app, "3,4", "2,6", "2,7", openings: true)
        sleep(6)
        app.buttons.matching(identifier: "back").allElementsBoundByIndex.last { $0.isHittable }?.tap(); sleep(2)
        XCTAssertTrue(app.buttons["space.addTile"].waitForExistence(timeout: 4))
        // an L-kitchen on A and B, filled
        app.buttons["space.addTile"].tap(); usleep(900_000)
        app.buttons["add.furn"].tap(); usleep(900_000)
        app.buttons["nf.lL"].tap(); usleep(500_000)
        app.buttons["nf.start"].tap(); sleep(6)
        app.buttons["kt.auto"].tap(); sleep(5)
        app.buttons["kt.wall.B"].tap(); usleep(900_000)
        // the first fill covers every wall of a new kitchen; B has its own button only when still empty
        if app.buttons["kt.auto"].exists { app.buttons["kt.auto"].tap() }; sleep(5)
        app.buttons["dim.3D"].tap(); sleep(4); shot("f6-01-kitchen-3d")
        app.buttons["f3.openAll"].tap(); sleep(3); shot("f6-02-open-all")
        app.buttons["3d.top"].tap(); sleep(2); shot("f6-03-from-above")
        app.buttons["f3.close"].tap(); sleep(2)
        app.buttons["3d.corner"].tap(); sleep(2)
        // a tap in the middle of the picture opens what is there
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42)).tap(); sleep(2); shot("f6-04-tap")
        app.buttons["dim.2D"].tap(); sleep(2)
        app.buttons["back"].tap(); sleep(2)
        // a wardrobe on wall D next to it
        app.buttons["space.addTile"].exists ? app.buttons["space.addTile"].tap() : app.buttons["space.add"].tap()
        usleep(900_000)
        if app.buttons["add.furn"].waitForExistence(timeout: 3) {
            app.buttons["add.furn"].tap(); usleep(900_000)
            app.buttons["nf.wardrobe"].tap(); usleep(600_000)
            app.buttons["nf.c3"].tap(); usleep(500_000)
            app.buttons["nf.start"].tap(); sleep(6)
            app.buttons["dim.3D"].tap(); sleep(4); shot("f6-05-room-3d")
            app.buttons["f3.openAll"].tap(); sleep(3); shot("f6-06-wardrobe-open")
        }
    }
}

/// iPhone furniture part 7: the Narx tab (cost, margin, running metre, profit, lead time), the parts and sheet layout,
/// the workshop pack and the customer's quote, issued.
final class Furniture7Tests: ScreenTestCase {
    /// The page's own back button: "back", or the workspace's back link (labelled by its strings key).
    func backVisible(_ app: XCUIApplication) {
        let p = NSPredicate(format: "identifier == 'back' OR label == 'nt.back' OR label == 'Orqaga'")
        app.buttons.matching(p).allElementsBoundByIndex.last { $0.isHittable }?.tap(); sleep(2)
    }

    func testPriceAndDocuments() {
        let app = launch()
        firstRun(app, "ind.furn")
        newWorkspace(app, "Oshxona Sergeli")
        app.buttons["space.add"].tap(); usleep(700_000)
        app.buttons["add.sketch"].tap(); usleep(700_000)
        app.buttons["add.plan"].tap(); usleep(800_000)
        app.buttons["nr.create"].tap(); sleep(1)
        app.buttons["tip.ok"].tap(); usleep(700_000)
        measuredRoom(app, "3,4", "2,6", "2,7", openings: false)
        sleep(6)
        backVisible(app)
        app.buttons["space.addTile"].tap(); usleep(900_000)
        app.buttons["add.furn"].tap(); usleep(900_000)
        app.buttons["nf.lL"].tap(); usleep(500_000)
        app.buttons["nf.start"].tap(); sleep(6)
        app.buttons["kt.auto"].tap(); sleep(5)
        app.buttons["kt.wall.B"].tap(); usleep(900_000)
        // the first fill covers every wall of a new kitchen; B has its own button only when still empty
        if app.buttons["kt.auto"].exists { app.buttons["kt.auto"].tap() }; sleep(6)
        // back to the order's page (a toast or a sliding page can take a tap)
        for _ in 0..<5 where !app.buttons["ptab.price"].exists { backVisible(app) }
        app.buttons["ptab.price"].tap(); usleep(900_000); shot("f7-01-price-tab")
        app.buttons["fp.g.hw"].tap(); usleep(500_000)
        app.swipeUp(); usleep(600_000); shot("f7-02-price-how")
        btn(app, "Pog").tap(); usleep(700_000)
        app.swipeUp(); usleep(600_000); shot("f7-03-running-metre")
        app.buttons["fp.days"].tap(); usleep(900_000)
        retype(app, "pf.value", "21"); shot("f7-04-days-sheet")
        app.buttons["pf.save"].tap(); usleep(900_000)
        app.buttons["fp.cut"].tap(); sleep(2); shot("f7-05-cut-list")
        btn(app, "Raskroy").tap(); usleep(900_000); shot("f7-06-sheet-layout")
        app.buttons["fc.next"].tap(); usleep(700_000); shot("f7-07-sheet-2")
        backVisible(app)
        app.buttons["fp.pack"].tap(); sleep(5); shot("f7-08-pack")
        app.swipeLeft(); sleep(1); shot("f7-09-pack-p2")
        app.swipeLeft(); sleep(1); shot("f7-10-pack-p3")
        backVisible(app)
        app.buttons["fp.quote"].tap(); sleep(5); shot("f7-11-quote-draft")
        app.swipeLeft(); sleep(1); shot("f7-12-quote-p2")
        app.buttons["rp.issue"].tap(); usleep(900_000)
        if app.textFields.firstMatch.exists && !app.buttons["iss.go"].exists {
            typeName(app, "Sanjar Usta")
            app.textFields.element(boundBy: 1).tap(); app.textFields.element(boundBy: 1).typeText("901234567")
            app.buttons["bd.save"].tap(); usleep(900_000)
        }
        shot("f7-13-issue-sheet")
        app.buttons["iss.go"].tap(); sleep(2); shot("f7-14-quotes-tab")
    }
}

/// Photo edge measuring, parts 1–3: a photo's edges, the rectangle offer used as lines A and B, a pinch zoom and its
/// reset, and the "Qirralar" switch. The gallery gives the drawn sample picture (a wall with a doorway).
final class EdgeMeasureTests: ScreenTestCase {
    func testEdgesRectangleAndZoom() {
        let app = launch(extra: ["-uiSamplePhoto"])
        firstRun(app)
        newWorkspace(app, "Uy 9")
        app.buttons["space.add"].tap(); usleep(700_000)
        app.buttons["add.photo"].tap(); usleep(700_000)
        app.buttons["add.gallery"].tap(); sleep(3); shot("e1-edges")
        if app.buttons["mk.rectUse"].waitForExistence(timeout: 3) { app.buttons["mk.rectUse"].tap(); sleep(1); shot("e2-rect-sides") }
        let cv = app.descendants(matching: .any).matching(identifier: "mk.canvas").firstMatch
        XCTAssertTrue(cv.waitForExistence(timeout: 3))
        cv.pinch(withScale: 2.5, velocity: 1); usleep(900_000); shot("e3-zoomed")
        if app.buttons["mk.zoomReset"].exists { app.buttons["mk.zoomReset"].tap(); usleep(600_000) }
        app.buttons["mk.edges"].tap(); usleep(700_000); shot("e4-edges-off")
    }
}
