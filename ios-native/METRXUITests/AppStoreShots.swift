import XCTest

/// The App Store screenshots, in Uzbek, Russian and English (run by .github/workflows/ios-screenshots.yml on the biggest
/// iPhone simulator, status bar set to 9:41). Saved as attachments and as PNG files in the folder APPSTORE_SHOTS names
/// (the workflow passes TEST_RUNNER_APPSTORE_SHOTS), named like uz-01-home.png:
///   01-home          the builder's Home (01b-projects: the Projects tab with the project; 01c-orders: the furniture
///                    maker's Home with the order under "recent")
///   02-kitchen-3d    an L-kitchen in the "twotone" design style, in the designer's 3D (02b-kitchen-open: its doors open)
///   03-gallery       the furniture gallery right after the style step, once its 3D cards are made
///   04-wardrobe-3d   a kupe in the "dark" style in 3D with a door slid open (04b-wardrobe-closed: shut)
///   05-gorka-3d      the gorka in the "dark" style in 3D (a bed instead when the gorka cannot be reached)
///   06-estimate      the report (PDF preview) of the builder's estimate (06b-estimate-tab: the Smeta tab)
/// Three starts a language, each a fresh launch with -uiReset and UI_LANG, so one broken part keeps the others.
/// The furniture steps are Modern3DShots' (CI-proven): the order's style step, the gallery card, the model's usual
/// sizes typed in, "Xonasiz qoldirish", then the designer's 3D. A step that cannot be reached saves
/// "<lang>-skip-<shot>-<where>.png" and the test goes on; there are no assertions, so no picture is saved under a good
/// name from a wrong screen and the run is not stopped by one bad step.
/// Without APPSTORE_SHOTS the class is skipped, so the usual CI run (ios-native.yml) does not spend time on it.
/// Labels are found by accessibility identifiers; the back link without one by its text from strings.json in the
/// shot's language.
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
        continueAfterFailure = true
    }

    // ---------- the tests: three starts a language ----------

    func testEn1Builder() { builder("en") }
    func testEn2Kitchen() { kitchen("en") }
    func testEn3Cabinets() { cabinets("en") }
    func testRu1Builder() { builder("ru") }
    func testRu2Kitchen() { kitchen("ru") }
    func testRu3Cabinets() { cabinets("ru") }
    func testUz1Builder() { builder("uz") }
    func testUz2Kitchen() { kitchen("uz") }
    func testUz3Cabinets() { cabinets("uz") }

    // ---------- 01 home, 06 estimate: a builder's project with a measured room and its estimate ----------

    private func builder(_ l: String) {
        guard let app = start(l, "ind.build") else { return }
        let s = sample(l)
        sleep(1)
        save("01-home")
        // a project with one workspace (the new-project page puts the cursor in its first field)
        guard tap(app, "home.new", 8) else { skip("06-estimate", "new-project"); return }
        usleep(1_000_000)
        guard typeAt(app, 0, s.project), typeAt(app, 1, s.customer) else { skip("06-estimate", "project-fields"); return }
        guard tap(app, "np.save", 5) else { skip("06-estimate", "project-save"); return }
        usleep(1_000_000)
        guard tap(app, "ws.create", 8) else { skip("06-estimate", "workspace"); return }
        usleep(800_000)
        guard tap(app, "ws.save", 5) else { skip("06-estimate", "workspace-save"); return }
        usleep(1_000_000)
        // a room measured by hand, with a door and a window
        for id in ["space.add", "add.sketch", "add.plan", "nr.create"] {
            guard tap(app, id, 6) else { skip("06-estimate", id); return }
            usleep(900_000)
        }
        if let ok = find(app, "tip.ok", 3) { ok.tap(); usleep(700_000) }
        for v in ["5", "4", "3"] {
            guard tap(app, "ed.manual", 6), typeField(app, "ms.value", v), tap(app, "ms.save", 3) else { skip("06-estimate", "measure"); return }
            usleep(900_000)
        }
        for kind in ["ao.door", "ao.window"] {
            guard tap(app, "ed.openings", 5) else { break }
            usleep(700_000)
            guard tap(app, kind, 4) else { break }
            usleep(800_000)
            guard tap(app, "op.save", 4) else { break }
            usleep(900_000)
        }
        noToast(app, 8)
        // its estimate: two materials and the labour
        guard backUntil(app, { self.seenId(app, "ptab.estimate") }) else { skip("06-estimate", "project-page"); return }
        guard tap(app, "ptab.estimate", 4) else { skip("06-estimate", "estimate-tab"); return }
        usleep(900_000)
        guard tap(app, "es.addMat", 6) else { skip("06-estimate", "add-material"); return }
        usleep(900_000)
        guard typeAt(app, 0, s.mat1), typeField(app, "gs.qty", "12"), typeField(app, "gs.price", "50000"), tap(app, "gs.again", 4)
        else { skip("06-estimate", "material-1"); return }
        usleep(900_000)
        guard typeAt(app, 0, s.mat2), typeField(app, "gs.qty", "22"), typeField(app, "gs.price", "120000"), tap(app, "gs.save", 4)
        else { skip("06-estimate", "material-2"); return }
        usleep(1_000_000)
        if tap(app, "gs.addLab", 6) {
            usleep(900_000)
            if typeAt(app, 0, s.labour), typeField(app, "gs.sum", "1000000"), tap(app, "gs.save", 4) { sleep(1) } else { skip("06-estimate", "labour") }
        } else { skip("06-estimate", "add-labour") }
        noToast(app, 8)
        // the Smeta tab from its top
        for _ in 0..<3 { drag(app, down: true) }
        sleep(1)
        save("06b-estimate-tab")
        // 06: the report as the customer gets it
        guard tap(app, "es.preview", 6) else { skip("06-estimate", "preview"); return }
        _ = findAny(app, ["rp.page", "rp.total"], 10)
        sleep(3)
        save("06-estimate")
        // 01b: the Projects tab with the project
        if backUntil(app, { self.seenId(app, "home.new") || self.seenId(app, "tab.projects") }), tap(app, "tab.projects", 4) {
            sleep(3)
            save("01b-projects")
        } else { skip("01b-projects", "tab") }
    }

    // ---------- 03 gallery, 02 kitchen: an L-kitchen in "twotone" ----------

    private func kitchen(_ l: String) {
        guard let app = start(l, "ind.furn") else { return }
        let who = ["ru": "Камола Рашидова"][l] ?? "Kamola Rashidova"
        guard newOrder(app, who, "twotone", "02-kitchen-3d") else { return }
        // the gallery's cards are made from the real 3D: until the screen stops changing
        waitStill(45)
        save("03-gallery")
        piece(app, "L", "kitchen", "02-kitchen-3d", after: {
            if self.tap(app, "f3.openAll", 6) { sleep(4); self.waitStill(8); self.save("02b-kitchen-open") }
        })
    }

    // ---------- 04 wardrobe, 05 gorka, 01c: a kupe and a gorka in "dark" ----------

    private func cabinets(_ l: String) {
        guard let app = start(l, "ind.furn") else { return }
        let who = ["ru": "Азиза Назарова"][l] ?? "Aziza Nazarova"
        guard newOrder(app, who, "dark", "04-wardrobe-3d") else { return }
        piece(app, "s2", "bedroom", "04-wardrobe-3d", before: {
            self.save("04b-wardrobe-closed")
            // a tap on the middle of the picture slides the door there (Modern3DShots' kupe-door)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42)).tap()
            sleep(4); self.waitStill(8)
        })
        if !piece(app, "gorka", "living", "05-gorka-3d") {
            // the bed (its own upholstered headboard) when the gorka could not be shown
            piece(app, "bed", "bedroom", "05-gorka-3d")
        }
        // 01c: the furniture maker's Home with the order
        if toHome(app) { sleep(3); save("01c-orders") } else { skip("01c-orders", "home") }
    }

    // ---------- one furniture piece ----------

    /// From the gallery (or the order page's "add more"): the model in the gallery's group, its usual sizes, no room,
    /// the designer's 3D; before runs in the 3D before the shot <name>, after once it is saved. Back to the order.
    @discardableResult
    private func piece(_ app: XCUIApplication, _ model: String, _ group: String, _ name: String,
                       before: (() -> Void)? = nil, after: (() -> Void)? = nil) -> Bool {
        defer { _ = toOrder(app) }
        guard gallery(app) else { skip(name, "gallery"); return false }
        guard let card = find(app, "model." + model, 12) else { skip(name, "card"); return false }
        // the group's chip jumps the list to it (the chip row scrolls sideways)
        if let chip = find(app, "fg.chip." + group, 2), bring(app, chip, vertical: false) { chip.tap(); usleep(1_200_000) }
        guard bring(app, card) else { skip(name, "card-hidden"); return false }
        card.tap(); usleep(1_200_000)
        guard sizes(app) else { skip(name, "sizes"); return false }
        guard tap(app, "fx.go", 6) else { skip(name, "summary"); return false }
        usleep(1_000_000)
        guard let none = find(app, "fq.none", 10), bring(app, none) else { skip(name, "where"); return false }
        none.tap(); sleep(2)
        guard open3D(app, name) else { return false }
        before?()
        save(name)
        after?()
        return true
    }

    // ---------- steps ----------

    /// A clean start in language l, through whatever opening screens show, to the Home; industry is the trade question's
    /// card ("ind.build", "ind.furn"). Nil (and a skip picture) when Home did not open.
    private func start(_ l: String, _ industry: String) -> XCUIApplication? {
        lang = l
        let app = launch(lang: l)
        let name = l == "ru" ? "Санжар Уста" : "Sanjar Usta"
        var welcomed = false, typed = false, asked = false
        let until = Date().addingTimeInterval(90)
        while Date() < until {
            if app.buttons["laser"].exists && app.buttons["tab.home"].exists && !app.buttons["ind.go"].exists { break }
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
                    if f0.exists { f0.tap(); usleep(300_000); f0.typeText(name) }
                    if f1.exists { f1.tap(); usleep(300_000); f1.typeText("901234567") }
                }
                app.buttons["local.start"].tap(); sleep(1); continue
            }
            if app.buttons["welcome.skip"].exists {
                if !welcomed { welcomed = true; sleep(4) }   // the launch animation (3.4 s) covers the welcome screen first
                app.buttons["welcome.skip"].tap(); usleep(900_000); continue
            }
            sleep(1)
        }
        guard app.buttons["laser"].waitForExistence(timeout: 10) else { skip("start", industry); return nil }
        sleep(2)
        // no trade question at the start: the trade is chosen in Profile instead
        if !asked && industry != "ind.build" && !switchTrade(app, industry) { skip("start", "trade"); return nil }
        return app
    }

    /// Profile → Trade → the trade (strings key "ind.furn"), then that trade's Home.
    private func switchTrade(_ app: XCUIApplication, _ key: String) -> Bool {
        guard tap(app, "tab.profile", 5) else { return false }
        usleep(900_000)
        let row = btn(app, word("ind.row"))
        for _ in 0..<5 where !seen(row) { drag(app, down: false) }
        guard seen(row) else { return false }
        row.tap(); usleep(900_000)
        let opt = btn(app, word(key))
        guard opt.waitForExistence(timeout: 4), bring(app, opt) else { return false }
        opt.tap(); sleep(1)
        if seenId(app, "sheet.close") { app.buttons["sheet.close"].tap(); usleep(500_000) }
        noToast(app, 5)
        return toHome(app)
    }

    /// A new furniture order for who, preset picked on its style step; true once its gallery is open.
    private func newOrder(_ app: XCUIApplication, _ who: String, _ preset: String, _ name: String) -> Bool {
        guard tap(app, "home.new", 12) else { skip(name, "new-order"); return false }
        usleep(900_000)
        let field = app.textFields.element(boundBy: 0)
        guard field.waitForExistence(timeout: 10) else { skip(name, "order-name"); return false }
        field.tap(); usleep(300_000); field.typeText(who)
        guard tap(app, "no.create", 6) else { skip(name, "order-create"); return false }
        usleep(1_200_000)
        if let card = find(app, "lk.p." + preset, 12), bring(app, card) {
            card.tap(); usleep(1_200_000)
        } else {
            // without the style the pictures would be wrong: stop this part
            skip(name, "style-" + preset)
            return false
        }
        guard find(app, "fg.chip.kitchen", 12) != nil else { skip(name, "gallery"); return false }
        return true
    }

    /// The gallery on screen: already there, or from the order page's dashed "add more" button.
    private func gallery(_ app: XCUIApplication) -> Bool {
        if app.buttons["fg.chip.kitchen"].exists { return true }
        guard toOrder(app) else { return false }
        if !app.buttons["fz.addMore"].exists, app.buttons["ptab.rooms"].exists { app.buttons["ptab.rooms"].tap(); usleep(900_000) }
        guard let more = find(app, "fz.addMore", 8), bring(app, more) else { return false }
        more.tap(); usleep(1_200_000)
        return find(app, "fg.chip.kitchen", 10) != nil
    }

    /// The size steps with the model's usual sizes (each field's placeholder typed in); choice and picture steps keep
    /// their usual answer. True at the summary.
    private func sizes(_ app: XCUIApplication) -> Bool {
        for _ in 0..<14 {
            if app.buttons["fx.go"].exists { return true }
            let f = app.textFields["fx.value"]
            if f.exists {
                let raw = (f.placeholderValue ?? "").isEmpty ? (f.value as? String ?? "") : (f.placeholderValue ?? "")
                let v = String(raw.filter { $0.isNumber || $0 == "," || $0 == "." })
                guard !v.isEmpty else { return false }
                f.tap(); usleep(300_000)
                f.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + v); usleep(400_000)
            }
            let next = app.buttons["fx.next"]
            guard next.waitForExistence(timeout: 5) else { return app.buttons["fx.go"].waitForExistence(timeout: 2) }
            guard next.isEnabled else { return false }
            next.tap(); usleep(900_000)
        }
        return app.buttons["fx.go"].waitForExistence(timeout: 3)
    }

    /// The designer's 3D: the kitchen / wardrobe designers' "3D" switch, or the item designer's "Xonada 3D"; true once
    /// its buttons are there and the picture has stopped changing (or had its time).
    private func open3D(_ app: XCUIApplication, _ name: String) -> Bool {
        noToast(app, 7)    // the "created" toast lies over the top bar
        // a new kitchen comes filled; "Avto" only when a wall is still empty
        if app.buttons["kt.auto"].exists { app.buttons["kt.auto"].tap(); sleep(3) }
        guard let sw = findAny(app, ["dim.3D", "seg.r"], 12) else { skip(name, "no-3d-switch"); return false }
        sw.tap()
        guard find(app, "f3.openAll", 15) != nil else { sleep(3); skip(name, "3d-not-shown"); return false }
        sleep(5)    // RealityKit's first frames on the simulator
        noToast(app, 4)
        waitStill(10)
        return true
    }

    /// Back to the order's page (its tabs), past sheets and pages.
    @discardableResult
    private func toOrder(_ app: XCUIApplication) -> Bool {
        for _ in 0..<7 {
            if app.buttons["ptab.rooms"].exists { return true }
            if seenId(app, "sheet.close") { app.buttons["sheet.close"].tap(); usleep(800_000); continue }
            noToast(app, 4)
            back(app)
        }
        return app.buttons["ptab.rooms"].waitForExistence(timeout: 3)
    }

    /// Back to Home, where the "new" card is.
    private func toHome(_ app: XCUIApplication) -> Bool {
        for _ in 0..<7 {
            if seenId(app, "home.new") { return true }
            if seenId(app, "tab.home") { app.buttons["tab.home"].tap(); usleep(1_000_000) } else { noToast(app, 4); back(app) }
        }
        return app.buttons["home.new"].waitForExistence(timeout: 3)
    }

    /// The page's back button (identifier "back", or a back link labelled with the language's "Back") until cond holds.
    private func backUntil(_ app: XCUIApplication, _ cond: () -> Bool) -> Bool {
        for _ in 0..<6 where !cond() {
            noToast(app, 4)
            back(app)
        }
        return cond()
    }

    /// One tap on the last back button in sight.
    private func back(_ app: XCUIApplication) {
        let p = NSPredicate(format: "identifier == 'back' OR label == %@", word("nt.back"))
        if let b = app.buttons.matching(p).allElementsBoundByIndex.last(where: { seen($0) }) { b.tap() }
        sleep(2)
    }

    /// Waits (at most maxWait) until the screen stops changing: the gallery's cards or the 3D have finished drawing.
    private func waitStill(_ maxWait: TimeInterval) {
        let end = Date().addingTimeInterval(maxWait)
        sleep(2)
        var last = XCUIScreen.main.screenshot().pngRepresentation
        var same = 0
        while Date() < end {
            sleep(2)
            let now = XCUIScreen.main.screenshot().pngRepresentation
            if now == last { same += 1; if same >= 2 { return } } else { same = 0 }
            last = now
        }
    }

    // ---------- small helpers (Modern3DShots' m3Find, m3Tap, m3Bring, m3Seen, here under their own names) ----------

    /// The element with identifier id (a button first, else anything), waiting up to t seconds.
    private func find(_ app: XCUIApplication, _ id: String, _ t: TimeInterval) -> XCUIElement? { findAny(app, [id], t) }

    private func findAny(_ app: XCUIApplication, _ ids: [String], _ t: TimeInterval) -> XCUIElement? {
        let end = Date().addingTimeInterval(t)
        repeat {
            for id in ids {
                let b = app.buttons[id]
                if b.exists { return b }
                let a = app.descendants(matching: .any).matching(identifier: id).firstMatch
                if a.exists { return a }
            }
            usleep(300_000)
        } while Date() < end
        return nil
    }

    /// Taps the element id once it is there and in sight.
    private func tap(_ app: XCUIApplication, _ id: String, _ t: TimeInterval) -> Bool {
        guard let e = find(app, id, t), bring(app, e) else { return false }
        e.tap()
        return true
    }

    /// Types v into the text field id (tapped first).
    private func typeField(_ app: XCUIApplication, _ id: String, _ v: String) -> Bool {
        let f = app.textFields[id]
        guard f.waitForExistence(timeout: 4), bring(app, f) else { return false }
        f.tap(); usleep(300_000); f.typeText(v); usleep(300_000)
        return true
    }

    /// Types v into the page's or sheet's i-th text field.
    private func typeAt(_ app: XCUIApplication, _ i: Int, _ v: String) -> Bool {
        let f = app.textFields.element(boundBy: i)
        guard f.waitForExistence(timeout: 4), seen(f) else { return false }
        f.tap(); usleep(300_000); f.typeText(v); usleep(300_000)
        return true
    }

    /// The button id is there and in sight.
    private func seenId(_ app: XCUIApplication, _ id: String) -> Bool { seen(app.buttons[id]) }

    /// On screen and its middle inside the window: unlike isHittable, never fails the test for an element past the
    /// side of a scrolling row.
    private func seen(_ el: XCUIElement) -> Bool {
        guard el.exists else { return false }
        let f = el.frame
        guard !f.isEmpty, f.width > 1, f.height > 1 else { return false }
        let w = XCUIApplication().windows.firstMatch.frame
        return w.isEmpty || w.contains(CGPoint(x: f.midX, y: f.midY))
    }

    /// In sight already, or scrolled until el is in the middle part of the screen (vertical: false only sideways), then
    /// sideways in its row when it is past the edge.
    private func bring(_ app: XCUIApplication, _ el: XCUIElement, vertical: Bool = true) -> Bool {
        guard el.exists else { return false }
        if seen(el) { return true }
        let win = app.windows.firstMatch.frame
        guard win.height > 0 else { return seen(el) }
        for _ in 0..<(vertical ? 18 : 0) {
            guard el.exists else { return false }
            let f = el.frame
            if f.midY < win.minY + win.height * 0.18 { drag(app, down: true); continue }
            if f.midY > win.minY + win.height * 0.82 { drag(app, down: false); continue }
            break
        }
        if seen(el) { return true }
        // a chip or card past the side of its row
        let f = el.frame
        let y = (f.midY - win.minY) / win.height
        guard y > 0.05 && y < 0.95 else { return seen(el) }
        for _ in 0..<4 where !seen(el) {
            let left = f.midX > win.maxX
            let a = app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.8 : 0.2, dy: y))
            let b = app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.25 : 0.75, dy: y))
            a.press(forDuration: 0.05, thenDragTo: b); usleep(700_000)
        }
        return seen(el)
    }

    /// A slow drag (no fling) of about a third of the screen: down true shows what is above, false what is below. It
    /// starts low (or high) so it does not land on a piece's 3D picture at the top, which turns on a drag.
    private func drag(_ app: XCUIApplication, down: Bool) {
        let a = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.4 : 0.76))
        let b = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.76 : 0.4))
        a.press(forDuration: 0.05, thenDragTo: b); usleep(700_000)
    }

    /// "<lang>-skip-<shot>-<where>": what was on screen when a step could not be reached.
    private func skip(_ name: String, _ at: String) {
        XCTContext.runActivity(named: "AppStoreShots: skipped \(name) at \(at)") { _ in }
        save("skip-" + name + "-" + at)
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
        "ind.furn": ["Mebelchi", "Мебелчи", "Мебельщик", "Furniture maker"],
    ]
}
