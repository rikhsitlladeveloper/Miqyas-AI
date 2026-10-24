import XCTest

/// The App Store screenshots, in Uzbek, Russian and English (run by .github/workflows/ios-screenshots.yml on the biggest
/// iPhone simulator, status bar set to 9:41). Six pictures a language, saved as attachments and as PNG files in the
/// folder APPSTORE_SHOTS names (the workflow passes TEST_RUNNER_APPSTORE_SHOTS), named like uz-01-home.png:
///   01-home          the builder's Home with a project
///   02-laser         what the laser button opens (on the simulator, without Bluetooth: the device sheet)
///   03-kitchen-3d    a furniture maker's L-shaped kitchen in 3D
///   04-tiles-3d      a tiler's bathroom, marble walls and a diagonal floor, in 3D
///   05-wiring        the electrician's living room from above, with the cable routes (05b-wiring-3d: the same in 3D)
///   06-estimate-pdf  the report (PDF preview) of the builder's estimate
/// Without APPSTORE_SHOTS the class is skipped, so the usual CI run (ios-native.yml) does not spend time on it.
/// Every sample is made through the app's own screens (there is no seeding hook); the opening screens are passed by
/// whatever of them shows (welcome, "continue without an account", the trade question), so the test does not depend on the
/// sign-in buttons. Labels are found by accessibility identifiers; the few that have none are found by their text from
/// strings.json in the shot's language.
final class AppStoreShots: ScreenTestCase {
    private var lang = "uz"
    private var outDir: URL? {
        let env = ProcessInfo.processInfo.environment
        return (env["APPSTORE_SHOTS"] ?? env["SHOTS"]).map { URL(fileURLWithPath: $0) }
    }

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["APPSTORE_SHOTS"] != nil,
                          "App Store screenshots: run by ios-screenshots.yml (TEST_RUNNER_APPSTORE_SHOTS)")
    }

    override func setUp() {
        super.setUp()
        // a step that did not happen stops the test, so no wrong picture is saved under a good name
        continueAfterFailure = false
    }

    // ---------- the tests: four starts a language, so one failed part keeps the others ----------

    func testUz1Builder() { builder("uz") }
    func testUz2Kitchen() { kitchen("uz") }
    func testUz3Tiles() { tiles("uz") }
    func testUz4Electrician() { electrician("uz") }
    func testRu1Builder() { builder("ru") }
    func testRu2Kitchen() { kitchen("ru") }
    func testRu3Tiles() { tiles("ru") }
    func testRu4Electrician() { electrician("ru") }
    func testEn1Builder() { builder("en") }
    func testEn2Kitchen() { kitchen("en") }
    func testEn3Tiles() { tiles("en") }
    func testEn4Electrician() { electrician("en") }

    // ---------- 01 home, 02 laser, 06 estimate: a builder's project with a measured room and its estimate ----------

    private func builder(_ l: String) {
        let app = start(l, "ind.build")
        let s = sample(l)
        // a project with one workspace (the new-project page puts the cursor in its first field)
        app.buttons["home.new"].tap(); usleep(900_000)
        app.textFields.element(boundBy: 0).typeText(s.project)
        app.textFields.element(boundBy: 1).tap(); app.textFields.element(boundBy: 1).typeText(s.customer)
        app.buttons["np.save"].tap(); usleep(1_000_000)
        XCTAssertTrue(app.buttons["ws.create"].waitForExistence(timeout: 5))
        app.buttons["ws.create"].tap(); usleep(800_000)
        app.buttons["ws.save"].tap(); usleep(1_000_000)
        // a room measured by hand, with a door and a window
        app.buttons["space.add"].tap(); usleep(700_000)
        app.buttons["add.sketch"].tap(); usleep(700_000)
        app.buttons["add.plan"].tap(); usleep(800_000)
        app.buttons["nr.create"].tap(); sleep(1)
        tipOk(app)
        measuredRoom(app, "5", "4", "3", openings: true)
        sleep(6)    // the last toast goes away
        backUntil(app) { app.buttons["ptab.estimate"].exists && app.buttons["ptab.estimate"].isHittable }
        // its estimate: two materials and the labour
        app.buttons["ptab.estimate"].tap(); usleep(900_000)
        app.buttons["es.addMat"].tap(); usleep(900_000)
        typeName(app, s.mat1); typeIn(app, "gs.qty", "12"); typeIn(app, "gs.price", "50000")
        app.buttons["gs.again"].tap(); usleep(900_000)
        typeName(app, s.mat2); typeIn(app, "gs.qty", "22"); typeIn(app, "gs.price", "120000")
        app.buttons["gs.save"].tap(); usleep(1_000_000)
        app.swipeUp(); usleep(600_000)
        app.buttons["gs.addLab"].tap(); usleep(900_000)
        typeName(app, s.labour); typeIn(app, "gs.sum", "1000000")
        app.buttons["gs.save"].tap(); sleep(4)
        app.swipeDown(); usleep(600_000)
        // 06: the report as the customer gets it
        XCTAssertTrue(app.buttons["es.preview"].waitForExistence(timeout: 4))
        app.buttons["es.preview"].tap(); sleep(4)
        save("06-estimate-pdf")
        // 01: Home with the project
        backUntil(app) { app.buttons["home.new"].exists && app.buttons["home.new"].isHittable }
        sleep(5)
        save("01-home")
        // 02: the laser. On the simulator (no Bluetooth) the button opens the device sheet; on a phone, the radar page
        app.buttons["laser"].firstMatch.tap(); sleep(2)
        save("02-laser")
    }

    // ---------- 03: a furniture maker's L-shaped kitchen in 3D ----------

    private func kitchen(_ l: String) {
        let app = start(l, "ind.furn")
        newFurnitureRoom(app, sample(l).customer, "kitchen")
        measuredRoom(app, "3.4", "2.6", "2.7", openings: true)
        sleep(6)
        placeFromEditor(app, "L"); sleep(4)
        if app.buttons["kt.auto"].exists { app.buttons["kt.auto"].tap(); sleep(5) }
        if app.buttons["kt.wall.B"].exists {
            app.buttons["kt.wall.B"].tap(); usleep(900_000)
            // the first fill covers every wall of a new kitchen; B has its own button only when still empty
            if app.buttons["kt.auto"].exists { app.buttons["kt.auto"].tap() }
        }
        sleep(5)
        XCTAssertTrue(app.buttons["dim.3D"].waitForExistence(timeout: 4))
        app.buttons["dim.3D"].tap(); sleep(6)
        save("03-kitchen-3d")
    }

    // ---------- 04: a tiler's bathroom: marble walls and a diagonal floor, in 3D ----------

    private func tiles(_ l: String) {
        let app = start(l, "ind.build")
        switchTrade(app, "ind.tiler")
        newOrder(app, sample(l).customer)
        // a bathroom (the new room sheet's first choice), measured with its door
        XCTAssertTrue(app.buttons["tl.addRoom"].waitForExistence(timeout: 5))
        app.buttons["tl.addRoom"].tap(); usleep(900_000)
        app.buttons["tl.roomCreate"].tap(); sleep(1)
        tipOk(app)
        measureRoom(app, "2.8", "2.2", "2.7", door: true, window: false)
        sleep(6)
        // the next step: tiles for the room, from the gallery
        backUntil(app) { app.buttons["ns.go"].exists && app.buttons["ns.go"].isHittable }
        app.buttons["ns.go"].tap(); usleep(1_200_000)
        tapId(app, "tmodel.bt.marble")
        throughSteps(app, next: "ts.next", done: "ts.save")
        sleep(6)    // the tiles are worked out away from the screen, and the "added" toast goes
        save("04-tiles-3d")
        // the floor too, then the picture again with both
        if app.buttons["tv.addLayout"].exists {
            // scrolled by a drag on the list under the picture (a swipe on the picture would turn the room)
            if !app.buttons["tv.addLayout"].isHittable {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62)))
                usleep(800_000)
            }
            app.buttons["tv.addLayout"].tap(); usleep(1_200_000)
            if app.buttons["tmodel.bt.diag"].waitForExistence(timeout: 4) {
                tapId(app, "tmodel.bt.diag")
                throughSteps(app, next: "ts.next", done: "ts.save")
                sleep(7)
                save("04-tiles-3d")
            }
        }
    }

    // ---------- 05: an electrician's living room: the kit placed, the panel set, the cable routes ----------

    private func electrician(_ l: String) {
        let app = start(l, "ind.build")
        switchTrade(app, "ind.elec")
        newOrder(app, sample(l).customer)
        XCTAssertTrue(app.buttons["el.addRoom"].waitForExistence(timeout: 5))
        app.buttons["el.addRoom"].tap(); usleep(900_000)
        let living = app.buttons.matching(NSPredicate(format: "label == %@", word("el.k.living"))).firstMatch
        if living.waitForExistence(timeout: 3) { living.tap(); usleep(500_000) }
        app.buttons["el.roomCreate"].tap(); sleep(1)
        tipOk(app)
        measureRoom(app, "4.5", "3.6", "2.7", door: true, window: true)
        sleep(6)
        // the next step: a kit for the room
        backUntil(app) { app.buttons["ns.go"].exists && app.buttons["ns.go"].isHittable }
        app.buttons["ns.go"].tap(); usleep(1_200_000)
        tapId(app, "ekit.lv.tv")
        throughSteps(app, next: "es.next", done: "es.save")
        sleep(3)
        // the next step after it: the panel, which gives the cable its routes
        backUntil(app) { app.buttons["ns.go"].exists && app.buttons["ns.go"].isHittable }
        app.buttons["ns.go"].tap(); sleep(7)
        save("05b-wiring-3d")
        let plan = app.buttons.matching(NSPredicate(format: "label == %@", word("ed.plan"))).firstMatch
        XCTAssertTrue(plan.waitForExistence(timeout: 4))
        plan.tap(); sleep(3)
        save("05-wiring")
    }

    // ---------- steps ----------

    /// A clean start in language l, through whatever opening screens show, to the Home; industry is the trade question's
    /// card ("ind.build", "ind.furn") when that question is asked.
    private func start(_ l: String, _ industry: String) -> XCUIApplication {
        lang = l
        let app = launch(lang: l)
        let name = l == "ru" ? "Санжар Уста" : "Sanjar Usta"
        var welcomed = false, typed = false, asked = false
        let until = Date().addingTimeInterval(90)
        while Date() < until {
            if app.buttons["laser"].exists && app.buttons["tab.home"].exists { break }
            if app.buttons["ind.go"].exists {
                asked = true
                if app.buttons[industry].exists { app.buttons[industry].tap(); usleep(500_000) }
                app.buttons["ind.go"].tap(); sleep(1); continue
            }
            if app.buttons["local.start"].exists {
                if !typed {
                    typed = true
                    // the builder's name and phone (empty after -uiReset)
                    let f0 = app.textFields.element(boundBy: 0), f1 = app.textFields.element(boundBy: 1)
                    if f0.exists { f0.tap(); f0.typeText(name) }
                    if f1.exists { f1.tap(); f1.typeText("901234567") }
                }
                app.buttons["local.start"].tap(); sleep(1); continue
            }
            if app.buttons["welcome.skip"].exists {
                if !welcomed { welcomed = true; sleep(4) }   // the launch animation (3.4 s) covers the welcome screen first
                app.buttons["welcome.skip"].tap(); usleep(900_000); continue
            }
            sleep(1)
        }
        XCTAssertTrue(app.buttons["laser"].waitForExistence(timeout: 10), "Home did not open")
        sleep(2)
        // no trade question at the start: the furniture maker is chosen in Profile instead
        if !asked && industry == "ind.furn" { switchTrade(app, "ind.furn") }
        return app
    }

    /// Profile → Trade → the trade (strings key "ind.tiler", "ind.elec"), then that trade's Home.
    private func switchTrade(_ app: XCUIApplication, _ key: String) {
        app.buttons["tab.profile"].tap(); usleep(900_000)
        let row = btn(app, word("ind.row"))
        for _ in 0..<4 where !(row.exists && row.isHittable) { app.swipeUp(); usleep(500_000) }
        row.tap(); usleep(900_000)
        let opt = btn(app, word(key))
        XCTAssertTrue(opt.waitForExistence(timeout: 4))
        if !opt.isHittable { opt.swipeUp(); usleep(500_000) }
        opt.tap(); sleep(1)
        if app.buttons["sheet.close"].exists && app.buttons["sheet.close"].isHittable { app.buttons["sheet.close"].tap(); usleep(500_000) }
        sleep(3)    // the "trade set" toast
        app.buttons["tab.home"].tap(); usleep(900_000)
        if !(app.buttons["home.new"].exists && app.buttons["home.new"].isHittable) { app.buttons["tab.home"].tap(); usleep(900_000) }
        XCTAssertTrue(app.buttons["home.new"].waitForExistence(timeout: 5))
    }

    /// A trade's new order for who; the gallery that opens after it is left with its back button, to the order's page.
    private func newOrder(_ app: XCUIApplication, _ who: String) {
        app.buttons["home.new"].tap(); usleep(1_000_000)
        let f = app.textFields["no.who"].exists ? app.textFields["no.who"] : app.textFields.element(boundBy: 0)
        XCTAssertTrue(f.waitForExistence(timeout: 4))
        f.tap(); f.typeText(who)
        app.buttons["no.create"].tap(); sleep(2)
        app.buttons["back"].firstMatch.tap(); sleep(2)
    }

    /// The room editor's first-time tip, when it shows.
    private func tipOk(_ app: XCUIApplication) {
        if app.buttons["tip.ok"].waitForExistence(timeout: 2) { app.buttons["tip.ok"].tap(); usleep(700_000) }
    }

    /// A rectangle room measured by hand, with a door and a window if asked.
    private func measureRoom(_ app: XCUIApplication, _ a: String, _ b: String, _ h: String, door: Bool, window: Bool) {
        for v in [a, b, h] {
            XCTAssertTrue(app.buttons["ed.manual"].waitForExistence(timeout: 4))
            app.buttons["ed.manual"].tap(); usleep(700_000); typeValue(app, v); app.buttons["ms.save"].tap(); usleep(900_000)
        }
        if door { app.buttons["ed.openings"].tap(); usleep(700_000); app.buttons["ao.door"].tap(); usleep(800_000); app.buttons["op.save"].tap(); usleep(900_000) }
        if window { app.buttons["ed.openings"].tap(); usleep(700_000); app.buttons["ao.window"].tap(); usleep(800_000); app.buttons["op.save"].tap(); usleep(900_000) }
    }

    /// A gallery card by its identifier, scrolled to when it is below the fold.
    private func tapId(_ app: XCUIApplication, _ id: String) {
        let m = app.buttons[id]
        XCTAssertTrue(m.waitForExistence(timeout: 5), "no \(id)")
        for _ in 0..<5 where !m.isHittable { app.swipeUp(); usleep(600_000) }
        m.tap(); usleep(1_000_000)
    }

    /// A one-question-a-screen flow: Next until the last step's button, which is tapped.
    private func throughSteps(_ app: XCUIApplication, next: String, done: String) {
        for _ in 0..<10 {
            if app.buttons[done].exists { app.buttons[done].tap(); return }
            XCTAssertTrue(app.buttons[next].waitForExistence(timeout: 3), "no \(next)")
            app.buttons[next].tap(); usleep(800_000)
        }
        XCTFail("\(done) never showed")
    }

    /// The page's back button (identifier "back", or a back link labelled with the language's "Back") until cond holds.
    private func backUntil(_ app: XCUIApplication, _ cond: () -> Bool) {
        for _ in 0..<6 where !cond() {
            let p = NSPredicate(format: "identifier == 'back' OR label == %@", word("nt.back"))
            guard let b = app.buttons.matching(p).allElementsBoundByIndex.last(where: { $0.isHittable }) else { sleep(2); continue }
            b.tap(); sleep(2)
        }
        XCTAssertTrue(cond(), "the page wanted did not show")
    }

    /// The screen as an attachment and as <lang>-<name>.png in the shots folder.
    private func save(_ name: String) {
        let file = lang + "-" + name
        let png = XCUIScreen.main.screenshot().pngRepresentation
        if let dir = outDir {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? png.write(to: dir.appendingPathComponent(file + ".png"))
        }
        let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png"); a.name = file; a.lifetime = .keepAlways; add(a)
    }

    // ---------- words ----------

    private struct Sample { let project, customer, mat1, mat2, labour: String }

    private func sample(_ l: String) -> Sample {
        switch l {
        case "ru": return Sample(project: "Квартира на Чиланзаре", customer: "Ольга Ким", mat1: "Краска", mat2: "Ламинат", labour: "Работа")
        case "en": return Sample(project: "Yunusabad flat", customer: "Akmal Yusupov", mat1: "Paint", mat2: "Laminate", labour: "Labour")
        default: return Sample(project: "Yunusobod 12-uy", customer: "Akmal Yusupov", mat1: "Bo'yoq", mat2: "Laminat", labour: "Ish haqi")
        }
    }

    /// A screen text in the shot's language: strings.json (key → [uz, uz-Cyrl, ru, en]) read from the checkout (the
    /// simulator sees the Mac's files), or the copy below when it cannot be read.
    private func word(_ key: String) -> String {
        let i = ["uz": 0, "uzc": 1, "ru": 2, "en": 3][lang] ?? 0
        if let v = AppStoreShots.table[key], v.count > i, !v[i].isEmpty { return v[i] }
        return AppStoreShots.fallback[key]?[i] ?? key
    }

    private static let table: [String: [String]] = {
        let env = ProcessInfo.processInfo.environment["STRINGS_JSON"]
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let url = env.map { URL(fileURLWithPath: $0) } ?? repo.appendingPathComponent("android-native/app/src/main/assets/strings.json")
        guard let d = try? Data(contentsOf: url), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return [:] }
        var t: [String: [String]] = [:]
        for (k, v) in o { if let a = v as? [String] { t[k] = a } }
        return t
    }()

    private static let fallback: [String: [String]] = [
        "nt.back": ["Orqaga", "Орқага", "Назад", "Back"],
        "ind.row": ["Soha", "Соҳа", "Сфера работы", "Trade"],
        "ind.tiler": ["Kafelchi", "Кафелчи", "Плиточник", "Tiler"],
        "ind.elec": ["Elektrik", "Электрик", "Электрик", "Electrician"],
        "ind.furn": ["Mebelchi", "Мебелчи", "Мебельщик", "Furniture maker"],
        "el.k.living": ["Mehmonxona", "Меҳмонхона", "Гостиная", "Living room"],
        "ed.plan": ["Reja", "Режа", "План", "Plan"],
    ]
}
