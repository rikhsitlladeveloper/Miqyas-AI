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
        // -uiSimLaser: the Device sheet's simulated laser, which only the screen tests have (the App Store app makes up no
        // laser values; -uiReset alone turns it on too)
        app.launchArguments = ["-uiReset", "-uiSimLaser"] + extra
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
        // a tap on "Boshlash" while the keyboard is still settling is sometimes lost (the name page stays): once more
        if !app.buttons["ind.go"].waitForExistence(timeout: 6) && app.buttons["local.start"].exists {
            app.buttons["local.start"].tap(); usleep(800_000)
        }
        XCTAssertTrue(app.buttons["ind.go"].waitForExistence(timeout: 8))
        app.buttons[id].tap(); usleep(400_000); app.buttons["ind.go"].tap(); usleep(600_000)
    }

    func tapOutside(_ app: XCUIApplication) { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)).tap() }

    /// Waits until the toast has gone: one with Undo stays 6.5 s over the top bar, where it takes a tap meant for the
    /// back button.
    func noToast(_ app: XCUIApplication, _ timeout: TimeInterval = 9) {
        let t = app.descendants(matching: .any).matching(identifier: "toast").firstMatch
        let end = Date().addingTimeInterval(timeout)
        while t.exists && Date() < end { usleep(300_000) }
        usleep(400_000)    // its exit animation
    }

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

    /// A furniture order for who with one room, opened in the editor (the three-field order, then the gallery's
    /// "Avval xonani o‘lchash" card and the room sheet). need picks the room type: the kitchen is the sheet's default,
    /// a wardrobe goes in a bedroom.
    func newFurnitureRoom(_ app: XCUIApplication, _ who: String, _ need: String, openings: Bool = false) {
        app.buttons["home.new"].tap(); usleep(900_000)
        app.textFields.element(boundBy: 0).typeText(who)
        app.buttons["no.create"].tap(); usleep(1_200_000)
        // the design style step comes first (modern 3D part 2): chosen later
        if app.buttons["lk.later"].waitForExistence(timeout: 4) { if !app.buttons["lk.later"].isHittable { app.swipeUp(); usleep(600_000) }; app.buttons["lk.later"].tap(); usleep(900_000) }
        XCTAssertTrue(app.buttons["fg.measure"].waitForExistence(timeout: 4))
        app.buttons["fg.measure"].tap(); usleep(900_000)
        let roomType = ["wardrobe": "Yotoqxona"][need]
        if let roomType {
            // the sheet's room type chip, not the gallery's group chip of the same name behind the sheet (a tap on that
            // one lands on the sheet's backdrop and closes the sheet)
            let p = NSPredicate(format: "label == %@ AND NOT (identifier BEGINSWITH %@)", roomType, "fg.")
            let chip = app.buttons.matching(p).firstMatch
            if chip.waitForExistence(timeout: 3) { chip.tap(); usleep(400_000) }
        }
        XCTAssertTrue(app.buttons["fr.create"].waitForExistence(timeout: 4))
        app.buttons["fr.create"].tap(); sleep(1)
        // the room-shape flow: a 3 400 × 2 600 rectangle, 2 700 high
        shapeFlow(app, walls: ["3400", "2600"], h: "2700", door: openings ? ["600", "900", "2100"] : nil, window: openings ? ["900", "1500", "1500"] : nil)
    }

    /// Types v into the room-shape flow's size field and goes on ("Keyingi").
    func flowType(_ app: XCUIApplication, _ v: String) {
        let f = app.textFields["rsh.value"]
        XCTAssertTrue(f.waitForExistence(timeout: 4))
        f.tap(); usleep(300_000)
        f.typeText(v); usleep(300_000)
        app.buttons["rsh.next"].tap(); usleep(700_000)
    }

    /// A door, window or pipe in the flow's openings step: its card, its wall on the plan, then its sizes (a window's
    /// sill, 900 put in, is kept).
    func flowOp(_ app: XCUIApplication, _ kind: String, _ wall: String, _ vals: [String]) {
        XCTAssertTrue(app.buttons["rsh.op." + kind].waitForExistence(timeout: 4))
        app.buttons["rsh.op." + kind].tap(); usleep(800_000)
        let w = app.descendants(matching: .any).matching(identifier: "rsh.wall." + wall).firstMatch
        XCTAssertTrue(w.waitForExistence(timeout: 4))
        w.tap(); usleep(800_000)
        for v in vals { flowType(app, v) }
        if kind == "window" { app.buttons["rsh.next"].tap(); usleep(800_000) }
        usleep(400_000)
    }

    /// The room-shape flow from its shape screen to the editor (room-shapes spec §2): the shape (the rectangle unless
    /// said), each asked wall typed, the height (typed, or the one put in kept), a door on A and a window on C when
    /// given, the summary's "Xonani ochish". free: a drawn shape, already drawn, whose optional diagonal is skipped.
    /// shots: a prefix for a picture of each screen.
    func shapeFlow(_ app: XCUIApplication, shape: String = "rect", walls: [String], h: String?, door: [String]? = nil, window: [String]? = nil,
                   free: Bool = false, shots: String? = nil, fromWalls: Bool = false) {
        func pic(_ n: String) { if let shots { shot(shots + n) } }
        if !free && !fromWalls {
            XCTAssertTrue(app.buttons["rsh.shapeGo"].waitForExistence(timeout: 5))
            if shape != "rect" { app.buttons["rsh.shape." + shape].tap(); usleep(500_000) }
            pic("-shapes")
            app.buttons["rsh.shapeGo"].tap(); usleep(900_000)
        }
        for (i, w) in walls.enumerated() { if i == 0 { pic("-wall-first") }; flowType(app, w) }
        if free { pic("-diagonal"); app.buttons["rsh.next"].tap(); usleep(800_000) }
        XCTAssertTrue(app.textFields["rsh.value"].waitForExistence(timeout: 4)); pic("-height")
        if let h { flowType(app, h) } else { app.buttons["rsh.next"].tap(); usleep(800_000) }
        XCTAssertTrue(app.buttons["rsh.opsDone"].waitForExistence(timeout: 4)); pic("-openings")
        if let door { flowOp(app, "door", "A", door) }
        if let window { flowOp(app, "window", "C", window) }
        app.buttons["rsh.opsDone"].tap(); usleep(900_000)
        XCTAssertTrue(app.buttons["rsh.open"].waitForExistence(timeout: 4)); pic("-summary")
        app.buttons["rsh.open"].tap(); sleep(1)
        if app.buttons["tip.ok"].waitForExistence(timeout: 2) { app.buttons["tip.ok"].tap(); usleep(700_000) }
    }

    /// In a measured room's editor: the gallery for the room (ed.addFurn), a model, then the walls step's place button,
    /// which opens the designer.
    func placeFromEditor(_ app: XCUIApplication, _ model: String) {
        XCTAssertTrue(app.buttons["ed.addFurn"].waitForExistence(timeout: 4))
        app.buttons["ed.addFurn"].tap(); usleep(900_000)
        tapModel(app, model)
        XCTAssertTrue(app.buttons["fz.place"].waitForExistence(timeout: 4))
        app.buttons["fz.place"].tap(); sleep(2)
    }

    /// A gallery's model card (model.<id>), scrolled to when it is below the fold.
    func tapModel(_ app: XCUIApplication, _ model: String) {
        let m = app.buttons["model." + model]
        XCTAssertTrue(m.waitForExistence(timeout: 4))
        if !m.isHittable { app.swipeUp(); usleep(600_000) }
        m.tap(); usleep(900_000)
    }

    /// The page's own back button: "back", or the workspace's back link (labelled by its strings key).
    func backVisible(_ app: XCUIApplication) {
        let p = NSPredicate(format: "identifier == 'back' OR label == 'nt.back' OR label == 'Orqaga'")
        app.buttons.matching(p).allElementsBoundByIndex.last { $0.isHittable }?.tap(); sleep(2)
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

    /// Designer C: element e scrolled into the screen sideways (the slider and the options rows scroll; XCTest does not
    /// scroll them by itself): its row dragged at its own height.
    func dzcBring(_ app: XCUIApplication, _ e: XCUIElement) {
        let w = app.windows.firstMatch.frame
        for _ in 0..<8 {
            let f = e.frame
            if f.isEmpty || (f.minX >= w.minX + 4 && f.maxX <= w.maxX - 4) { return }
            let y = (f.midY - w.minY) / w.height
            let a = app.coordinate(withNormalizedOffset: CGVector(dx: f.maxX > w.maxX ? 0.75 : 0.3, dy: y))
            let b = app.coordinate(withNormalizedOffset: CGVector(dx: f.maxX > w.maxX ? 0.35 : 0.7, dy: y))
            a.press(forDuration: 0.05, thenDragTo: b); usleep(600_000)
        }
    }

    /// Designer C: a tool of the slider (brought past the faded edge first).
    func dzcTool(_ app: XCUIApplication, _ id: String) {
        let b = app.buttons["dzc.t." + id]
        guard b.waitForExistence(timeout: 4) else { XCTFail("no tool " + id); return }
        dzcBring(app, b)
        b.tap(); usleep(700_000)
    }

    /// Designer C: an option of an options row (or a catalogue tile), brought into the screen first; nothing when absent.
    func dzcOpt(_ app: XCUIApplication, _ id: String) {
        let b = app.buttons[id]
        guard b.waitForExistence(timeout: 2) else { return }
        dzcBring(app, b)
        b.tap(); usleep(700_000)
    }

    /// Designer C: a unit or a section on the drawing tapped where it is (the touches go to the drawing under it).
    func dzcTapEl(_ app: XCUIApplication, _ id: String) {
        let e = app.descendants(matching: .any).matching(identifier: id).firstMatch
        guard e.waitForExistence(timeout: 4) else { XCTFail("no " + id); return }
        e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap(); usleep(800_000)
        // the gesture hint the first time a unit is selected
        if app.buttons["dzc.teachSkip"].waitForExistence(timeout: 1.5) { shot("dzc-hint"); app.buttons["dzc.teachSkip"].tap(); usleep(600_000) }
    }

    /// Designer C: an options row back to the slider.
    func dzcBack(_ app: XCUIApplication) {
        if app.buttons["dzc.back"].exists { app.buttons["dzc.back"].tap(); usleep(500_000) }
    }

    func drag(_ el: XCUIElement, _ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) {
        el.coordinate(withNormalizedOffset: CGVector(dx: a.0, dy: a.1)).press(forDuration: 0.15, thenDragTo: el.coordinate(withNormalizedOffset: CGVector(dx: b.0, dy: b.1)))
        usleep(600_000)
    }
}

/// Part 1: first start, tabs, Profile, Russian.
final class Part1Tests: ScreenTestCase {
    /// First start (no accounts), then the three tabs, the laser sheet, Profile's pages and sheets, dark mode.
    func testFirstRunAndTabs() {
        let app = launch()
        XCTAssertTrue(app.buttons["welcome.skip"].waitForExistence(timeout: 20)); sleep(3)
        sleep(1); shot("03-welcome")

        app.buttons["welcome.lang"].tap(); usleep(500_000); shot("04-welcome-lang-menu")
        tapOutside(app)

        // App Store v1 has no accounts: no "Hisob yaratish / Kirish / Google" on the welcome screen
        XCTAssertFalse(app.buttons["Hisob yaratish"].exists)

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
        // the note card's own menu, labelled "Menyu" like the page's (space.menu), which comes first
        let menus = app.buttons.matching(NSPredicate(format: "(label == %@ OR label == %@) AND NOT (identifier IN %@)",
                                                      "Menyu", "menu", ["space.menu", "project.menu"]))
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
        // the toast's Undo reads "Ortga qaytarish" (UX upgrades section 3)
        btn(app, "Ortga qaytarish").tap(); usleep(900_000); shot("56-undo")

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
        // the room-shape flow: a 5 × 4 m rectangle, 3 m high (a wall too short first)
        app.buttons["nr.create"].tap(); sleep(1); shot("61-room-shapes")
        app.buttons["rsh.shapeGo"].tap(); usleep(900_000); shot("62-wall-A")
        let f = app.textFields["rsh.value"]
        XCTAssertTrue(f.waitForExistence(timeout: 4))
        f.tap(); f.typeText("0,1"); usleep(300_000)
        app.buttons["rsh.next"].tap(); usleep(600_000); shot("63-wall-too-short")
        XCTAssertTrue(app.descendants(matching: .any)["rsh.err"].exists)
        f.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + "5")
        app.buttons["rsh.next"].tap(); usleep(700_000); shot("64-wall-B")
        shapeFlow(app, walls: ["4"], h: "3", shots: "65", fromWalls: true)
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
        app.buttons["nr.create"].tap(); sleep(1)
        shapeFlow(app, shape: "L", walls: ["2", "2", "3", "2"], h: nil)
        shot("80-lshape-editor")
        sleep(4)    // the "created" toast covers the back button for 3.4 s
        app.buttons["back"].firstMatch.tap(); usleep(1_000_000)

        // a room drawn by tapping four corners and the first one again
        app.buttons["space.addTile"].firstMatch.tap(); usleep(700_000)
        app.buttons["add.sketch"].tap(); usleep(700_000)
        app.buttons["add.plan"].tap(); usleep(800_000)
        app.buttons["nr.create"].tap(); sleep(1)
        app.buttons["rsh.shape.free"].tap(); usleep(500_000)
        app.buttons["rsh.shapeGo"].tap(); usleep(900_000); shot("81-sketch")
        app.buttons["seg.t"].tap(); usleep(400_000)
        let pad = app.otherElements["pad"].exists ? app.otherElements["pad"] : app.images["pad"]
        for (x, y) in [(0.2, 0.2), (0.8, 0.2), (0.8, 0.7), (0.2, 0.7), (0.2, 0.2)] {
            pad.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap(); usleep(350_000)
        }
        shot("82-sketch-closed")
        app.buttons["sk.create"].tap(); sleep(1)
        // every drawn wall is asked, then the optional diagonal
        shapeFlow(app, walls: ["5", "5", "5", "5"], h: nil, free: true, shots: "83")
        shot("83-sketch-editor")
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
        shapeFlow(app, walls: ["5,2", "4"], h: nil, shots: "89-ru")
        shot("90-ru-editor")
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
        shapeFlow(app, walls: ["5", "4"], h: "3", door: ["0,6", "0,9", "2,1"], window: ["0,9", "1,5", "1,5"])
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
        shapeFlow(app, walls: ["4", "3"], h: "3")
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
        shapeFlow(app, walls: ["5", "4"], h: "3", door: ["0,6", "0,9", "2,1"], window: ["0,9", "1,5", "1,5"])
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
        shapeFlow(app, walls: ["5", "4"], h: "3", door: ["0,6", "0,9", "2,1"], window: ["0,9", "1,5", "1,5"])
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
        shapeFlow(app, walls: ["5", "4"], h: nil)
        noToast(app)    // the "added" toast lies over the tray button
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
        // prices, stages and the workshop: the advanced furniture app
        let app = launch(extra: ["-advanced", "YES"])
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
        app.textFields.element(boundBy: 0).typeText("Dilnoza Karimova")
        shot("f1-04-new-order")
        app.buttons["no.create"].tap(); sleep(1); shot("f1-04a-style")
        // the design style step comes first (modern 3D part 2): chosen later
        if app.buttons["lk.later"].waitForExistence(timeout: 4) { if !app.buttons["lk.later"].isHittable { app.swipeUp(); usleep(600_000) }; app.buttons["lk.later"].tap(); usleep(900_000) }
        shot("f1-04b-gallery")
        // the gallery's "Keyin hal qilaman" link goes to the order page
        XCTAssertTrue(app.buttons["fg.later"].waitForExistence(timeout: 4))
        if !app.buttons["fg.later"].isHittable { app.swipeUp(); usleep(600_000) }
        app.buttons["fg.later"].tap(); sleep(1); shot("f1-05-order")

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

        shot("f1-11b-order-bar")
        for _ in 0..<4 where !app.buttons["tab.projects"].exists { backVisible(app) }
        app.buttons["tab.projects"].tap(); usleep(900_000); shot("f1-12-orders")
        app.buttons["tab.profile"].tap(); usleep(900_000)
        btn(app, "Soha").tap(); usleep(800_000); shot("f1-13-industry-sheet")
        app.buttons["sheet.close"].tap(); usleep(600_000)
        app.buttons["tab.home"].tap(); usleep(800_000)
        for _ in 0..<4 where !app.buttons["home.sheets"].exists && app.buttons["back"].exists { backVisible(app) }
        app.buttons["home.sheets"].tap(); sleep(1); shot("f1-14-sheets-tool")
    }
}

/// Furniture makers, part 2: sockets, water, sewer and gas marked on the walls of a measured room; the plan and 3D show them.
final class Furniture2Tests: ScreenTestCase {
    func testSitePoints() {
        let app = launch()
        firstRun(app, "ind.furn")
        newFurnitureRoom(app, "Dilnoza Karimova", "kitchen")
        sleep(6)    // the last toast goes away
        app.buttons["ed.walls"].tap(); usleep(900_000); shot("f2-01-wall-empty")
        app.buttons["pt.add"].tap(); usleep(900_000); shot("f2-02-point-sheet")
        app.buttons["pt.cold"].tap(); usleep(400_000)
        retype(app, "pt.off", "1300"); retype(app, "pt.h", "550"); shot("f2-03-cold-water")
        app.buttons["pt.save"].tap(); sleep(1)
        app.buttons["pt.add"].tap(); usleep(900_000)
        app.buttons["pt.sewer"].tap(); usleep(400_000)
        retype(app, "pt.off", "1340"); app.buttons["pt.save"].tap(); sleep(1)
        app.buttons["pt.add"].tap(); usleep(900_000)
        retype(app, "pt.off", "520"); app.buttons["pt.save"].tap(); sleep(1)       // a socket at 300
        app.buttons["pt.add"].tap(); usleep(900_000)
        app.buttons["pt.cold"].tap(); usleep(400_000)
        retype(app, "pt.off", "5000"); app.buttons["pt.save"].tap(); usleep(800_000); shot("f2-04-past-the-wall")
        app.buttons["sheet.close"].tap(); sleep(5); shot("f2-05-wall-A-points")
        app.buttons["wv.next"].tap(); usleep(700_000)
        app.buttons["wv.add"].tap(); usleep(800_000); shot("f2-06-wall-add")
        app.buttons["wa.point"].tap(); usleep(900_000)
        app.buttons["pt.gas"].tap(); usleep(400_000)
        retype(app, "pt.off", "900"); app.buttons["pt.save"].tap(); sleep(1); shot("f2-07-wall-B-gas")
        noToast(app)    // the "added" toast with Undo covers the back button
        app.buttons["back"].tap(); usleep(900_000); shot("f2-08-plan")
        app.buttons["ed.3d"].tap(); sleep(3); shot("f2-09-3d")
    }
}

/// iPhone furniture part 3: Profile → the workshop's rules (a value changes the sample unit's cost) and its boards and
/// hardware (a new handle).
final class Furniture3Tests: ScreenTestCase {
    func testWorkshop() {
        // prices, stages and the workshop: the advanced furniture app
        let app = launch(extra: ["-advanced", "YES"])
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
/// L-kitchen from the gallery placed on the walls (it comes already filled), a unit made narrower, a unit and a
/// dishwasher from the library, the checks, the boards, undo.
final class Furniture4Tests: ScreenTestCase {
    func testKitchen() {
        // prices, stages and the workshop: the advanced furniture app
        let app = launch(extra: ["-advanced", "YES"])
        firstRun(app, "ind.furn")
        newFurnitureRoom(app, "Akmal Yusupov", "kitchen")
        sleep(6)    // the last toast goes away
        app.buttons["ed.walls"].tap(); usleep(900_000)
        app.buttons["pt.add"].tap(); usleep(900_000)
        app.buttons["pt.cold"].tap(); usleep(400_000)
        retype(app, "pt.off", "1300"); app.buttons["pt.save"].tap(); sleep(1)
        shot("f4-00a-wall")
        noToast(app)    // the "added" toast with Undo covers the back button
        app.buttons["back"].tap(); sleep(2); shot("f4-00b-after-back")
        // the measured room opens the gallery for its own group; the L-kitchen takes the walls whole
        XCTAssertTrue(app.buttons["ed.addFurn"].waitForExistence(timeout: 4))
        app.buttons["ed.addFurn"].tap(); usleep(900_000); shot("f4-03-gallery")
        tapModel(app, "L"); shot("f4-04-walls-step")
        XCTAssertTrue(app.buttons["fz.place"].waitForExistence(timeout: 4))
        app.buttons["fz.place"].tap(); sleep(2); shot("f4-05-designer")
        // a new kitchen comes filled; the button is there only when a wall is still empty
        if app.buttons["kt.auto"].exists { app.buttons["kt.auto"].tap() }; sleep(1); shot("f4-06-auto-A")
        sleep(4)
        // Designer C: the slider with nothing selected; Tekshiruv (its count) and "Batafsil" (the cards that were under
        // the drawing: fill, design, extras, checks, cost)
        dzcTool(app, "checks"); shot("f4-07-checks")
        dzcBack(app)
        dzcTool(app, "more"); sleep(1); shot("f4-07b-more")
        app.swipeUp(); usleep(700_000); shot("f4-07c-more-cost")
        app.buttons["sheet.close"].tap(); usleep(900_000)
        // a tap on a lower unit selects it: the slider changes, the mm bubble and the edge's handle show
        dzcTapEl(app, "dzc.m.low1"); shot("f4-08-selected")
        dzcTool(app, "width"); shot("f4-09-width")
        if app.buttons["dzc.w.400"].exists { dzcOpt(app, "dzc.w.400"); sleep(1) }
        shot("f4-10-unit-400")
        dzcBack(app)
        // the right edge's handle dragged to the left: a snap width, the neighbour or filler taking the difference
        let bubble = app.buttons["dzc.bubble"]
        if bubble.exists {
            bubble.tap(); usleep(900_000); shot("f4-10b-typed-width")
            if app.textFields["dzc.num"].exists { typeIn(app, "dzc.num", "450"); app.buttons["dzc.numOk"].tap(); sleep(1) }
            shot("f4-11-after-typed")
        }
        sleep(4)
        dzcTool(app, "type"); shot("f4-11b-type")
        if app.buttons["dzc.ty.drawer3"].exists { dzcOpt(app, "dzc.ty.drawer3"); sleep(1) }
        dzcBack(app)
        // the unit's full settings stay one tool away
        dzcTool(app, "setup"); usleep(900_000); shot("f4-11c-unit-sheet")
        if app.buttons["km.save"].exists { app.buttons["km.save"].tap(); sleep(1) } else if app.buttons["sheet.close"].exists { app.buttons["sheet.close"].tap(); usleep(800_000) }
        sleep(4)
        if app.buttons["dzc.desel"].exists { app.buttons["dzc.desel"].tap(); usleep(600_000) }
        // Qo‘shish: the whole catalogue, a tile tapped into the first space it fits
        dzcTool(app, "add"); shot("f4-12-library")
        if app.buttons["dzc.cat.drawer"].exists { dzcOpt(app, "dzc.cat.drawer"); usleep(600_000) }
        if app.buttons["dzc.tile.drawers.450"].exists { dzcOpt(app, "dzc.tile.drawers.450"); sleep(1) }
        shot("f4-13-drawers-added")
        sleep(4)
        if app.buttons["dzc.cat.tech"].exists { dzcOpt(app, "dzc.cat.tech"); usleep(600_000); shot("f4-14-appliances") }
        if app.buttons["dzc.tile.dishwasher.600"].exists { dzcOpt(app, "dzc.tile.dishwasher.600"); sleep(1) }
        sleep(4)
        dzcBack(app)
        app.buttons["kt.undo"].tap(); usleep(800_000); shot("f4-16-undo")
        app.buttons["kt.wall.B"].tap(); usleep(900_000)
        // the first fill covers every wall of a new kitchen; B has its own button only when still empty
        if app.buttons["kt.auto"].exists { app.buttons["kt.auto"].tap() }; sleep(1); shot("f4-17-auto-B")
        sleep(4)
        // Belgilash: two units marked, one colour for both
        dzcTool(app, "multi")
        dzcTapEl(app, "dzc.m.low1"); dzcTapEl(app, "dzc.m.low2"); shot("f4-17b-marked")
        dzcTool(app, "decor"); shot("f4-17c-marked-decor")
        dzcBack(app)
        if app.buttons["dzc.multiDone"].exists { app.buttons["dzc.multiDone"].tap(); usleep(600_000) }
        noToast(app)
        app.buttons["kt.menu"].tap(); usleep(900_000)
        app.buttons["fm.mats"].tap(); usleep(900_000)
        app.buttons["fmat.front.ldsp18a"].tap(); usleep(700_000); shot("f4-18-mats")
        app.buttons["sheet.close"].tap(); usleep(900_000); shot("f4-19-dark-fronts")
        app.buttons["back"].tap(); usleep(900_000); shot("f4-20-order-rooms")
        XCTAssertTrue(app.buttons["ptab.rooms"].waitForExistence(timeout: 4))
    }
}

/// iPhone furniture part 5: the wardrobe designer on a measured room (A 3400, B 2600, height 2700): a built-in
/// wardrobe on wall D, five sections with one 500 wide, doors, the inside of a section, the boards.
final class Furniture5Tests: ScreenTestCase {
    func testWardrobe() {
        // prices, stages and the workshop: the advanced furniture app
        let app = launch(extra: ["-advanced", "YES"])
        firstRun(app, "ind.furn")
        newFurnitureRoom(app, "Nodira Aliyeva", "wardrobe")
        sleep(6)    // the last toast goes away
        // the bedroom's gallery: a 3-section built-in wardrobe, placed on the walls step
        XCTAssertTrue(app.buttons["ed.addFurn"].waitForExistence(timeout: 4))
        app.buttons["ed.addFurn"].tap(); usleep(900_000); shot("f5-01-gallery")
        tapModel(app, "h3"); shot("f5-02-place")
        XCTAssertTrue(app.buttons["fz.place"].waitForExistence(timeout: 4))
        app.buttons["fz.place"].tap(); sleep(2)
        sleep(4)
        shot("f5-02b-designer")
        // Designer C: Bo‘limlar — five sections of the same width
        dzcTool(app, "secs")
        if app.buttons["dzc.secs.5"].exists { dzcOpt(app, "dzc.secs.5"); usleep(800_000) }
        shot("f5-03-five-sections")
        dzcBack(app)
        // the second section selected, typed 400 wide (its neighbour takes the difference)
        dzcTapEl(app, "dzc.s1"); shot("f5-04-section")
        dzcTool(app, "width")
        if app.buttons["dzc.w.kbd"].exists {
            dzcOpt(app, "dzc.w.kbd"); usleep(900_000)
            // five sections of 300 in 1500: its neighbour gives down to 150, so 450 at most
            if app.textFields["dzc.num"].exists { typeIn(app, "dzc.num", "400"); shot("f5-04-section-width"); app.buttons["dzc.numOk"].tap(); usleep(900_000) }
            if app.buttons["sheet.close"].exists { app.buttons["sheet.close"].tap(); usleep(800_000) }
        }
        shot("f5-05-sizes")
        dzcBack(app)
        // one door on it, then that door tapped on the drawing: no handle on it (a push latch)
        dzcTool(app, "type")
        if app.buttons["dzc.sty.d1"].exists { dzcOpt(app, "dzc.sty.d1"); usleep(700_000) }
        shot("f5-06-doors")
        dzcBack(app)
        noToast(app)
        dzcTapEl(app, "dzc.s1"); shot("f5-06a-door")
        if app.buttons["dzc.t.handle"].exists && app.buttons["dzc.selUp"].exists {
            dzcTool(app, "handle")
            if app.buttons["dzc.h.off"].exists { dzcOpt(app, "dzc.h.off"); usleep(800_000); shot("f5-06b-door-push") }
            dzcBack(app)
            app.buttons["dzc.selUp"].tap(); usleep(600_000)
        }
        // the inside: two drawers, then a shoe rack from "Boshqa…"
        dzcTool(app, "in")
        if app.buttons["dzc.in.drawer.plus"].exists { dzcOpt(app, "dzc.in.drawer.plus"); sleep(1); dzcOpt(app, "dzc.in.drawer.plus"); sleep(1) }
        if app.buttons["dzc.in.more"].exists {
            dzcOpt(app, "dzc.in.more"); usleep(900_000); shot("f5-07-more")
            if app.buttons["wm.shoe"].exists { app.buttons["wm.shoe"].tap(); sleep(1) }
        }
        shot("f5-08-inside")
        dzcBack(app)
        sleep(4)
        if app.buttons["dzc.desel"].exists { app.buttons["dzc.desel"].tap(); usleep(600_000) }
        dzcTool(app, "checks"); shot("f5-09-checks")
        dzcBack(app)
        // the materials ("Batafsil", Material tab)
        dzcTool(app, "mats"); sleep(1); shot("f5-10-materials")
        if app.buttons["wd.mat.front"].exists {
            app.buttons["wd.mat.front"].tap(); usleep(900_000)
            if app.buttons["fmat.front.mdf18"].exists { app.buttons["fmat.front.mdf18"].tap(); usleep(700_000) }
        }
        if app.buttons["sheet.close"].exists { app.buttons["sheet.close"].tap(); usleep(900_000) }; shot("f5-11-mdf-fronts")
        noToast(app)
        app.buttons["back"].tap(); sleep(1); shot("f5-12-order-rooms")
        XCTAssertTrue(app.buttons["ptab.rooms"].waitForExistence(timeout: 4))
    }
}

/// iPhone furniture part 6: the kitchen and a wardrobe in 3D (CI only: the VM's simulator has no GPU for RealityKit).
final class Furniture6Tests: ScreenTestCase {
    func testFurnitureIn3D() {
        let app = launch()
        firstRun(app, "ind.furn")
        newFurnitureRoom(app, "Bobur Rahimov", "kitchen", openings: true)
        sleep(6)
        // an L-kitchen on A and B, filled
        placeFromEditor(app, "L"); sleep(4)
        if app.buttons["kt.auto"].exists { app.buttons["kt.auto"].tap(); sleep(5) }
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
        XCTAssertTrue(app.buttons["ptab.rooms"].waitForExistence(timeout: 4))
        // a wardrobe in the same room: the room already has furniture, so it comes from the order page's dashed button,
        // through the size steps (no room is known there) and "Qaysi xonaga?"
        let more = app.buttons["fz.addMore"]
        if more.waitForExistence(timeout: 4) {
            if !more.isHittable { app.swipeUp(); usleep(600_000) }
            more.tap(); usleep(900_000)
            if app.buttons["fg.chip.bedroom"].waitForExistence(timeout: 3) { app.buttons["fg.chip.bedroom"].tap(); usleep(700_000) }
            if app.buttons["model.h3"].waitForExistence(timeout: 3) {
                tapModel(app, "h3")
                for v in ["1500", "2200", "600"] {          // width, height, depth in millimetres
                    guard app.textFields["fx.value"].waitForExistence(timeout: 3) else { break }
                    retype(app, "fx.value", v); app.buttons["fx.next"].tap(); usleep(800_000)
                }
                if app.buttons["fx.go"].waitForExistence(timeout: 3) { app.buttons["fx.go"].tap(); usleep(900_000) }
                let room = app.buttons.matching(identifier: "fq.room").firstMatch
                if room.waitForExistence(timeout: 3) { room.tap(); usleep(900_000) }
                if app.buttons["fz.place"].waitForExistence(timeout: 4) { app.buttons["fz.place"].tap(); sleep(6) }
                if app.buttons["dim.3D"].waitForExistence(timeout: 4) {
                    app.buttons["dim.3D"].tap(); sleep(4); shot("f6-05-room-3d")
                    if app.buttons["f3.openAll"].exists { app.buttons["f3.openAll"].tap(); sleep(3); shot("f6-06-wardrobe-open") }
                }
            }
        }
    }
}

/// iPhone furniture part 7: the Narx tab (cost, margin, running metre, profit, lead time), the parts and sheet layout,
/// the workshop pack and the customer's quote, issued.
final class Furniture7Tests: ScreenTestCase {
    func testPriceAndDocuments() {
        // prices, stages and the workshop: the advanced furniture app
        let app = launch(extra: ["-advanced", "YES"])
        firstRun(app, "ind.furn")
        newFurnitureRoom(app, "Kamola Tursunova", "kitchen")
        sleep(6)
        placeFromEditor(app, "L"); sleep(4)
        if app.buttons["kt.auto"].exists { app.buttons["kt.auto"].tap(); sleep(5) }
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

/// iPhone furniture part 8: a new order's gallery, a model with no room known — its three size steps (in metres), the
/// summary, "Qaysi xonaga?" left without a room — the designer, and back to the order.
final class Furniture8Tests: ScreenTestCase {
    func testGalleryAndSizeSteps() {
        let app = launch()
        firstRun(app, "ind.furn")
        app.buttons["home.new"].tap(); usleep(900_000)
        app.textFields.element(boundBy: 0).typeText("Dilnoza Karimova")
        app.buttons["no.create"].tap(); usleep(1_200_000)
        // the design style step comes first (modern 3D part 2): chosen later
        if app.buttons["lk.later"].waitForExistence(timeout: 4) { if !app.buttons["lk.later"].isHittable { app.swipeUp(); usleep(600_000) }; app.buttons["lk.later"].tap(); usleep(900_000) }
        XCTAssertTrue(app.buttons["model.L"].waitForExistence(timeout: 4)); shot("f8-01-gallery")
        tapModel(app, "L"); shot("f8-02-step1")
        // an L-kitchen is a corner piece: its shape and which sides were measured come first, as pictures; the usual
        // ones (corner on the right, measured along the walls) are kept
        for _ in 0..<3 where !app.textFields["fx.value"].exists && app.buttons["fx.next"].exists {
            app.buttons["fx.next"].tap(); usleep(800_000)
        }
        shot("f8-02b-first-size")
        retype(app, "fx.value", "3400"); app.buttons["fx.next"].tap(); usleep(800_000); shot("f8-03-step2")
        retype(app, "fx.value", "2600"); app.buttons["fx.next"].tap(); usleep(800_000)
        retype(app, "fx.value", "2700"); app.buttons["fx.next"].tap(); usleep(800_000); shot("f8-04-summary")
        XCTAssertTrue(app.buttons["fx.go"].waitForExistence(timeout: 3))
        app.buttons["fx.go"].tap(); sleep(2); shot("f8-05-designer")
        // no measured room in the order: no "Qaysi xonaga?" (UX upgrades section 7)
        XCTAssertFalse(app.buttons["fq.none"].exists)
        if app.buttons["dim.3D"].waitForExistence(timeout: 4) { app.buttons["dim.3D"].tap(); sleep(3); shot("f8-06-designer-3d"); app.buttons["dim.2D"].tap(); usleep(800_000) }
        // back to the order's page (a toast or a sliding page can take a tap)
        for _ in 0..<5 where !app.buttons["ptab.rooms"].exists { backVisible(app) }
        XCTAssertTrue(app.buttons["ptab.rooms"].waitForExistence(timeout: 4)); shot("f8-07-order")
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

/// The UX upgrades (26 Oct 2026, design/ux-upgrades/BUILD_SPEC.md): a furniture maker's first start with the three tour
/// cards and no sample order (removed by the founder, 27 Oct 2026), a new order's gallery with its style row, a size step
/// with the laser and the mic, the order's page (progress, price, bottom bar, coach mark), Ma'lumot with the stages and
/// Profile's new rows.
final class UXTests: ScreenTestCase {
    func testUXUpgrades() {
        let app = launch(extra: ["-uiTour"])
        firstRun(app, "ind.furn")
        XCTAssertTrue(app.buttons["ux.tourNext"].waitForExistence(timeout: 6)); usleep(600_000); shot("ux-01-tour-1")
        app.buttons["ux.tourNext"].tap(); usleep(700_000); shot("ux-02-tour-2")
        app.buttons["ux.tourNext"].tap(); usleep(700_000); shot("ux-03-tour-3")
        app.buttons["ux.tourNext"].tap(); sleep(1); shot("ux-04-home")
        // no "Namuna — oshxona" sample order any more
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Namuna")).firstMatch.exists)
        // a new order: the gallery with the style row on top
        app.buttons["home.new"].tap(); usleep(900_000)
        app.textFields.element(boundBy: 0).typeText("Aziza Nazarova")
        app.buttons["no.create"].tap(); sleep(2)
        if app.buttons["ux.coachOk"].waitForExistence(timeout: 2) { shot("ux-05-gallery-coach"); app.buttons["ux.coachOk"].tap(); usleep(600_000) }
        shot("ux-11-gallery")
        // the style row: another style (the second chip, on screen) repaints the cards
        if app.buttons["lk.p.gloss"].waitForExistence(timeout: 2) && app.buttons["lk.p.gloss"].isHittable { app.buttons["lk.p.gloss"].tap(); sleep(3); shot("ux-12-gallery-gloss") }
        // a model's size steps without a room (a coach mark or the toast that came late goes first)
        if app.buttons["ux.coachOk"].waitForExistence(timeout: 2) { app.buttons["ux.coachOk"].tap(); usleep(600_000) }
        noToast(app)
        tapModel(app, "I")
        for _ in 0..<3 where !app.textFields["fx.value"].exists && app.buttons["fx.next"].exists { app.buttons["fx.next"].tap(); usleep(800_000) }
        if app.buttons["ux.coachOk"].waitForExistence(timeout: 2) { shot("ux-13-size-coach"); app.buttons["ux.coachOk"].tap(); usleep(600_000) }
        shot("ux-14-size")
        retype(app, "fx.value", "12"); usleep(500_000); shot("ux-15-size-error")
        retype(app, "fx.value", "3400"); usleep(500_000)
        if app.buttons["fx.laser"].exists { app.buttons["fx.laser"].tap(); sleep(3); shot("ux-16-size-laser") }
        // back to the order's page: progress, price, the bottom bar and its coach mark; Ma'lumot with the stages
        for _ in 0..<8 where !app.buttons["ptab.info"].exists { backVisible(app) }
        if app.buttons["ux.coachOk"].waitForExistence(timeout: 2) { shot("ux-06-order-coach"); app.buttons["ux.coachOk"].tap(); usleep(600_000) }
        shot("ux-06-order")
        if app.buttons["ptab.info"].exists {
            app.buttons["ptab.info"].tap(); usleep(900_000); shot("ux-07-info-stages")
            app.swipeUp(); usleep(600_000); shot("ux-08-info-stages-2")
            app.swipeDown(); usleep(400_000)
            app.buttons["ptab.rooms"].tap(); usleep(900_000)
        }
        // Profile: haptics, the unit, the voice pack, the tips
        for _ in 0..<6 where !app.buttons["tab.profile"].exists { backVisible(app) }
        app.buttons["tab.profile"].tap(); usleep(900_000)
        app.swipeUp(); usleep(600_000); shot("ux-17-profile")
        app.swipeUp(); usleep(600_000); shot("ux-18-profile-2")
    }
}
