import XCTest

/// The pre-publishing tour (final check, 28 Oct 2026; .github/workflows/ios-tour.yml): every screen of the app, for all
/// six roles, photographed in one language (TOUR_LANG: uz, uzc, ru or en) on the job's simulator. Each picture is saved
/// as <lang>-<role>-<nnn>-<name>.png in TOUR_SHOTS, next to <same>.txt, the screen's accessibility tree (for finding
/// untranslated keys and {x} placeholders without reading every picture), and attached to the test.
/// A step that cannot be reached is written to skips.txt (with the screen's picture as <...>-SKIP-<what>.png) and the
/// tour goes on: there are no assertions, so one broken step never hides the screens after it.
/// Texts are found by accessibility identifiers, or by their strings.json text in the tour's language (the table is in
/// this bundle). Without TOUR_SHOTS the class is skipped, so the usual CI run does not spend time on it.
class TourBase: ScreenTestCase {
    private static let env = ProcessInfo.processInfo.environment
    var lang: String { TourBase.env["TOUR_LANG"] ?? "uz" }
    /// "1": every furniture model in the designer; else one model of each gallery group.
    var allModels: Bool { (TourBase.env["TOUR_MODELS"] ?? "all") == "all" }
    private var out: URL? { TourBase.env["TOUR_SHOTS"].map { URL(fileURLWithPath: $0) } }
    var role = "app"
    private var seq = 0
    var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(TourBase.env["TOUR_SHOTS"] != nil, "the tour: run by ios-tour.yml (TEST_RUNNER_TOUR_SHOTS)")
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = true
        // the location question of the new order's "Joylashuv" (the workflow grants it; this is in case it does not)
        addUIInterruptionMonitor(withDescription: "location") { alert in
            for l in ["Allow While Using App", "Allow Once", "Allow", "OK"] where alert.buttons[l].exists { alert.buttons[l].tap(); return true }
            return false
        }
    }

    // MARK: - texts

    private static let table: [String: [String]] = {
        guard let url = Bundle(for: TourBase.self).url(forResource: "strings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: [Any]] else { return [:] }
        var t: [String: [String]] = [:]
        for (k, v) in obj { t[k] = v.map { $0 as? String ?? "" } }
        return t
    }()

    /// The text of key in the tour's language (or in l), up to its first {placeholder}.
    func tr(_ k: String, in l: String? = nil) -> String {
        guard let e = TourBase.table[k] else { return k }
        let i = ["uz": 0, "uzc": 1, "ru": 2, "en": 3][l ?? lang] ?? 0
        let s = i < e.count && !e[i].isEmpty ? e[i] : (e.first ?? k)
        return s.components(separatedBy: "{").first?.trimmingCharacters(in: .whitespaces) ?? s
    }

    // MARK: - pictures

    /// A picture of the screen (and its accessibility tree).
    func S(_ name: String) {
        seq += 1
        let n = String(format: "%@-%@-%03d-%@", lang, role, seq, name)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        if let out {
            try? png.write(to: out.appendingPathComponent(n + ".png"))
            if let app { try? app.debugDescription.write(to: out.appendingPathComponent(n + ".txt"), atomically: true, encoding: .utf8) }
        }
        let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png"); a.name = n; a.lifetime = .keepAlways; add(a)
    }

    /// A step that could not be reached: noted, with a picture of what was on the screen.
    func skip(_ what: String) {
        XCTContext.runActivity(named: "tour: skipped \(role) \(what)") { _ in }
        S("SKIP-" + what)
        if let out {
            let f = out.appendingPathComponent("skips.txt")
            let line = "\(lang) \(role) \(what)\n"
            if let h = try? FileHandle(forWritingTo: f) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close() }
            else { try? line.write(to: f, atomically: true, encoding: .utf8) }
        }
    }

    /// Pictures a few moments apart (an animation on its way).
    func frames(_ name: String, _ gaps: [Double]) {
        for (i, g) in gaps.enumerated() { usleep(UInt32(g * 1_000_000)); S(name + "-\(i + 1)") }
    }

    // MARK: - starting

    /// A fresh start in the tour's language. industry: straight to its Home (past the first-run pages); nil: the first
    /// run itself. radar: the staged radar state every laser button then opens (RealLaser.uiStage).
    @discardableResult
    func start(_ industry: String?, radar: String? = "search", extra: [String] = []) -> XCUIApplication {
        let a = XCUIApplication()
        var args = ["-uiReset", "-uiSimLaser"]
        if let industry {
            args += ["-firstRunDone", "YES", "-industry", industry, "-builderName", lang == "ru" || lang == "uzc" ? "Санжар Уста" : "Sanjar Usta",
                     "-builderPhone", "901234567"]
        }
        if let radar { args += ["-uiRadar", radar] }
        a.launchArguments = args + extra
        a.launchEnvironment["UI_LANG"] = lang
        a.launch()
        app = a
        if industry != nil {
            if find("laser", 25) == nil { skip("home-after-start") }
            sleep(4)    // the opening animation over Home
        }
        return a
    }

    // MARK: - finding and tapping

    func find(_ id: String, _ t: TimeInterval = 4) -> XCUIElement? { findAny([id], t) }

    func findAny(_ ids: [String], _ t: TimeInterval) -> XCUIElement? {
        let end = Date().addingTimeInterval(t)
        repeat {
            for id in ids {
                let b = app.buttons[id]
                if b.exists { return b }
                let a = app.descendants(matching: .any).matching(identifier: id).firstMatch
                if a.exists { return a }
            }
            usleep(250_000)
        } while Date() < end
        return nil
    }

    /// The first element on the screen whose identifier starts with p.
    func findPrefix(_ p: String, _ t: TimeInterval = 3) -> XCUIElement? {
        let q = NSPredicate(format: "identifier BEGINSWITH %@", p)
        let end = Date().addingTimeInterval(t)
        repeat {
            let b = app.buttons.matching(q).firstMatch
            if b.exists { return b }
            let a = app.descendants(matching: .any).matching(q).firstMatch
            if a.exists { return a }
            usleep(250_000)
        } while Date() < end
        return nil
    }

    /// A button (or switch) whose label starts with text.
    func labelled(_ text: String, _ t: TimeInterval = 3) -> XCUIElement? {
        let p = NSPredicate(format: "label BEGINSWITH %@", text)
        let end = Date().addingTimeInterval(t)
        repeat {
            let b = app.buttons.matching(p).firstMatch
            if b.exists { return b }
            let s = app.switches.matching(p).firstMatch
            if s.exists { return s }
            let o = app.descendants(matching: .any).matching(p).firstMatch
            if o.exists { return o }
            usleep(250_000)
        } while Date() < end
        return nil
    }

    /// Taps element e at its middle once it is in sight.
    @discardableResult
    func hit(_ e: XCUIElement?) -> Bool {
        guard let e, bring(e) else { return false }
        e.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        return true
    }

    /// Taps id (waiting up to t s); false, and nothing tapped, when it is not there.
    @discardableResult
    func tap(_ id: String, _ t: TimeInterval = 4, wait: Double = 0.9) -> Bool {
        guard hit(find(id, t)) else { return false }
        usleep(UInt32(wait * 1_000_000))
        return true
    }

    /// Taps the button labelled with key's text.
    @discardableResult
    func tapText(_ key: String, _ t: TimeInterval = 3, wait: Double = 0.9) -> Bool {
        guard hit(labelled(tr(key), t)) else { return false }
        usleep(UInt32(wait * 1_000_000))
        return true
    }

    /// In sight already, or scrolled until it is in the middle part of the screen, then sideways in its row.
    func bring(_ el: XCUIElement, vertical: Bool = true) -> Bool {
        guard el.exists else { return false }
        if el.m3Seen { return true }
        let win = app.windows.firstMatch.frame
        guard win.height > 0 else { return el.m3Seen }
        for _ in 0..<(vertical ? 14 : 0) {
            guard el.exists else { return false }
            let f = el.frame
            if f.midY < win.minY + win.height * 0.16 { drag(down: true); continue }
            if f.midY > win.minY + win.height * 0.84 { drag(down: false); continue }
            break
        }
        if el.m3Seen { return true }
        let f = el.frame
        let y = (f.midY - win.minY) / win.height
        guard y > 0.03 && y < 0.97 else { return el.m3Seen }
        for _ in 0..<5 where !el.m3Seen {
            let left = el.frame.midX > win.maxX
            let a = app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.85 : 0.15, dy: y))
            let b = app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.2 : 0.8, dy: y))
            a.press(forDuration: 0.05, thenDragTo: b); usleep(700_000)
        }
        return el.m3Seen
    }

    /// A slow drag of about a third of the screen: down shows what is above, else what is below.
    func drag(down: Bool) {
        let a = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.4 : 0.76))
        let b = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.76 : 0.4))
        a.press(forDuration: 0.05, thenDragTo: b); usleep(700_000)
    }

    /// Pictures of a long page from its top down (at most n), until it stops moving.
    func scrollShots(_ name: String, _ n: Int = 4) {
        S(name)
        var last = XCUIScreen.main.screenshot().pngRepresentation
        for i in 1..<n {
            app.swipeUp(); usleep(900_000)
            let now = XCUIScreen.main.screenshot().pngRepresentation
            if now == last { break }
            last = now
            S(name + "-\(i + 1)")
        }
        for _ in 0..<n { app.swipeDown(); usleep(250_000) }
        usleep(500_000)
    }

    func type(_ field: XCUIElement?, _ v: String, clear: Bool = false) {
        guard let field, hit(field) else { return }
        usleep(500_000)
        // typed into whatever has the focus now (the field's own snapshot can be gone once the keyboard moved it)
        app.typeText((clear ? String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12) : "") + v)
        usleep(300_000)
    }

    /// Waits until the toast has gone.
    func calm(_ t: TimeInterval = 8) { noToast(app, t) }

    /// Closes the open sheets.
    func closeSheets() {
        for _ in 0..<3 {
            let c = app.buttons["sheet.close"]
            guard c.exists, c.m3Seen else { return }
            c.tap(); usleep(800_000)
        }
    }

    /// The page's own back button.
    func back() {
        // a page's back button, or a full-page form's X (the new order)
        let p = NSPredicate(format: "identifier == 'back' OR label == %@ OR label == 'Orqaga' OR (label == %@ AND NOT (identifier == 'sheet.close'))",
                            tr("nt.back"), tr("common.close"))
        if let b = app.buttons.matching(p).allElementsBoundByIndex.last(where: { $0.m3Seen }) { b.tap(); usleep(1_200_000) }
        else { app.swipeRight(); usleep(800_000) }
    }

    /// Back until id is on the screen (at most n pages).
    @discardableResult
    func backTo(_ id: String, _ n: Int = 8) -> Bool {
        for _ in 0..<n {
            if let e = find(id, 1), e.m3Seen { return true }
            if app.buttons["sheet.close"].exists && app.buttons["sheet.close"].m3Seen { closeSheets(); continue }
            calm(4)
            back()
        }
        return find(id, 2) != nil
    }

    func toHome() -> Bool {
        for _ in 0..<8 {
            if let b = find("home.new", 1), b.m3Seen { return true }
            if let h = find("tab.home", 1), h.m3Seen { h.tap(); usleep(1_000_000); continue }
            closeSheets(); calm(4); back()
        }
        return find("home.new", 2) != nil
    }

    /// Back to the order's page.
    @discardableResult
    func toOrder() -> Bool { backTo("ptab.rooms") || backTo("ptab.info", 2) }

    /// Taps every button whose identifier starts with one of prefixes (not delete, share or call ones), with a
    /// picture of what each opens, coming back to this screen (marker on it) after each.
    func explore(_ name: String, _ prefixes: [String], marker: String, max: Int = 14) {
        let bad = ["del", "Del", "share", "Share", "call", "send", "tg.", "issue", "back", "close", "Close", "undo", "redo", "remove"]
        var ids: [String] = []
        for p in prefixes {
            let q = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", p))
            for e in q.allElementsBoundByIndex.prefix(40) {
                let id = e.identifier
                if !id.isEmpty && !ids.contains(id) && !bad.contains(where: { id.contains($0) }) { ids.append(id) }
            }
        }
        for id in ids.prefix(max) {
            guard tap(id, 2, wait: 1.4) else { continue }
            S(name + "-" + id)
            closeSheets()
            if find(marker, 1.5) == nil { back() }
            if find(marker, 2) == nil { skip(name + "-return-" + id); return }
        }
    }

    // MARK: - shared flows

    /// The new order (or project) form with its location, then "Buyurtma yaratish": true at the start dialog or the
    /// order's page.
    func newOrder(_ who: String, _ name: String = "order") -> Bool {
        guard tap("home.new", 8) else { skip(name + "-home.new"); return false }
        let f = app.textFields.element(boundBy: 0)
        guard f.waitForExistence(timeout: 8) else { skip(name + "-form"); return false }
        S(name + "-form")
        type(f, who)
        // a builder's project: the customer too
        if app.buttons["np.save"].exists && app.textFields.count > 1 { type(app.textFields.element(boundBy: 1), "Ali Valiyev") }
        // "Joylashuv": the GPS (the simulator's location is set by the workflow); the keyboard goes first, the button
        // was under it (the tap went to a key)
        for _ in 0..<2 where app.keyboards.count > 0 { app.swipeDown(); usleep(700_000) }
        if tap("loc.get", 2, wait: 1.5) || tap("np.locate", 1, wait: 1.5) {
            S(name + "-location-asked")
            sleep(4)
            S(name + "-location")
        }
        S(name + "-form-filled")
        guard tap("no.create", 2) || tap("np.save", 2) else { skip(name + "-create"); return false }
        usleep(800_000)
        return true
    }

    /// Types v into the room-shape flow's field and goes on.
    func flowType(_ v: String, shot: String? = nil) {
        guard let f = find("rsh.value", 4) else { skip("flow-field"); return }
        type(f, v, clear: true)
        if let shot { S(shot) }
        tap("rsh.next", 3, wait: 0.8)
    }

    /// The room-shape flow from its shape screen to the room editor, with a picture of every step: the shapes (the L
    /// and the free one shown), the walls, the height, the openings step (a door: its style window and size steps; a
    /// window), the summary. mm: the furniture maker's millimetres, else metres.
    func roomFlow(mm: Bool) {
        guard find("rsh.shapeGo", 6) != nil else { skip("flow-shapes"); return }
        S("flow-shapes")
        if tap("rsh.shape.L", 2, wait: 0.6) { S("flow-shape-L"); tap("rsh.mirror", 1, wait: 0.6); S("flow-shape-L-mirrored") }
        if tap("rsh.shape.free", 2, wait: 0.8) { S("flow-shape-free"); }
        tap("rsh.shape.rect", 2, wait: 0.6)
        tap("rsh.shapeGo", 3)
        let walls = mm ? ["3400", "2600"] : ["4,2", "3,6"]
        if find("rsh.value", 4) != nil { S("flow-wall-A") }
        // the laser button under the field: the radar (no made-up values)
        if tap("fx.laser", 2, wait: 1.5) {
            S("flow-laser-radar")
            if find("rsh.value", 1.5) == nil { back() }
        }
        flowType(walls[0], shot: "flow-wall-A-typed")
        flowType(walls[1], shot: "flow-wall-B-typed")
        if find("rsh.value", 4) != nil { S("flow-height") }
        flowType(mm ? "2700" : "2,7")
        guard find("rsh.opsDone", 5) != nil else { skip("flow-openings"); return }
        sleep(2); S("flow-openings")
        // a door on A: its icon, the wall chip, the style window, its sizes one per step
        if tap("re.tile.door", 3, wait: 0.7) {
            S("flow-door-armed")
            if tap("re.wchip.A", 3) {
                if find("re.sty.single", 4) != nil { S("flow-door-styles") }
                tap("re.sty.single", 3)
                if find("rsh.value", 3) != nil { S("flow-door-width") }
                tap("rsh.next", 3, wait: 0.8)
                if find("rsh.value", 3) != nil { S("flow-door-height") }
                tap("rsh.next", 3, wait: 0.8)
                sleep(1); S("flow-door-placed")
                tap("re.desel", 2, wait: 0.5)
                calm()
            } else { skip("flow-door-wall") }
        } else { skip("flow-door-tile") }
        // a window on C
        if tap("re.tile.window", 3, wait: 0.7) {
            if tap("re.wchip.C", 3) {
                if find("re.sty.double", 4) != nil { S("flow-window-styles") }
                tap("re.sty.double", 3)
                for i in 0..<3 {
                    guard find("rsh.value", 2) != nil else { break }
                    S("flow-window-size-\(i + 1)")
                    tap("rsh.next", 2, wait: 0.8)
                }
                sleep(1); S("flow-window-placed")
                tap("re.desel", 2, wait: 0.5)
                calm()
            }
        }
        // a pipe or socket tile, when the trade has one
        if tap("re.tiles", 1, wait: 0.5) { S("flow-tiles") }
        tap("rsh.opsDone", 3)
        guard find("rsh.open", 5) != nil else { skip("flow-summary"); return }
        scrollShots("flow-summary", 3)
        tap("rsh.open", 3, wait: 2)
        calm(5)
    }

    /// The one room editor: the plan, its tools (inner walls with a piece placed, Tekshiruv, the shape, the height, the
    /// dimensions, "Qo‘shimcha"), the wall view and the 3D.
    func roomEditor() {
        if tap("ux.coachOk", 2, wait: 0.5) {}
        if find("re.t.add", 3) == nil, tap("re.editRoom", 4, wait: 1.5) {}
        guard find("re.t.add", 6) != nil else { skip("room-editor"); return }
        calm()
        S("re-plan")
        for t in ["add", "shape", "rh", "rot", "dims"] {
            if reToolT(t) { S("re-tool-" + t); tap("dzc.back", 2, wait: 0.5) }
        }
        // inner walls: the window of ready pieces, an L piece placed and selected, its tools
        if reToolT("inner") {
            S("re-inner-window")
            if tap("iw.card.L", 3, wait: 1.2) {
                S("re-inner-placed")
                calm()
                for t in ["iwLen", "iwTh", "iwRot"] where reToolT(t, wait: 0.8) { S("re-inner-" + t); tap("dzc.back", 2, wait: 0.5) }
                tap("re.desel", 2, wait: 0.5)
            } else { skip("re-inner-card"); tap("iw.cancel", 2) }
            if reToolT("inner") && tap("iw.card.arch", 3, wait: 1.2) { S("re-inner-arch"); calm(); tap("re.desel", 2, wait: 0.5) }
        }
        if reToolT("checks") { S("re-checks"); tap("dzc.back", 2, wait: 0.5) }
        if tap("re.vFront", 3) { S("re-wall-view"); tap("re.vPlan", 2) }
        if tap("re.v3d", 3, wait: 3) { S("re-3d"); tap("re.v2d", 2) }
        if reToolT("more") { S("re-more"); tap("dzc.back", 2, wait: 0.5) }
        // nothing selected at the end (the inner wall piece's tools have no "Qo‘shimcha")
        tap("re.desel", 1, wait: 0.5)
        if find("re.t.add", 1) == nil {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.24)).tap(); usleep(700_000)
        }
    }

    /// The editor's tool t ("re.t.<t>"), its slider dragged until it is on the screen.
    @discardableResult
    func reToolT(_ t: String, wait: Double = 0.8) -> Bool {
        guard let b = find("re.t." + t, 2) else { return false }
        var n = 0
        while (b.frame.maxX > app.frame.width - 4 || b.frame.minX < 0) && n < 6 {
            let y = b.frame.midY
            let from = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.width * (b.frame.minX < 0 ? 0.15 : 0.85), dy: y))
            let to = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.width * (b.frame.minX < 0 ? 0.85 : 0.15), dy: y))
            from.press(forDuration: 0.05, thenDragTo: to)
            usleep(600_000); n += 1
        }
        b.tap(); usleep(UInt32(wait * 1_000_000))
        return true
    }

    /// Each tab of the order's page, scrolled.
    func orderTabs(_ name: String = "order") {
        guard find("ptab.rooms", 4) != nil || find("ptab.info", 2) != nil else { skip(name + "-page"); return }
        calm()
        let tabs = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'ptab.'")).allElementsBoundByIndex.map(\.identifier)
        for t in tabs where tap(t, 2, wait: 1) { scrollShots(name + "-" + t, 3) }
        tap("ptab.rooms", 2)
    }

    /// Profile, from top to bottom, plus its role rows.
    func profile() {
        guard tap("tab.profile", 5, wait: 1) else { skip("profile"); return }
        scrollShots("profile", 5)
    }

    /// Profile → "Kengaytirilgan" on (prices, stages, estimates); back to Home.
    func advancedOn() {
        _ = toHome()
        guard tap("tab.profile", 5, wait: 1) else { skip("advanced-profile"); return }
        if tap("pf.advanced", 4, wait: 1.2) { S("profile-advanced-on") } else { skip("advanced-switch") }
        calm()
        tap("tab.home", 3)
    }

    /// The order (or project) named who opened from the Projects tab.
    func openOrder(_ who: String) -> Bool {
        if find("ptab.rooms", 1) != nil { return true }
        _ = toHome()
        tap("tab.projects", 3, wait: 1)
        let p = NSPredicate(format: "label CONTAINS %@", who)
        let c = app.buttons.matching(p).firstMatch.exists ? app.buttons.matching(p).firstMatch : app.staticTexts.matching(p).firstMatch
        guard hit(c) else { skip("open-" + who); return false }
        sleep(1)
        return find("ptab.rooms", 4) != nil || find("ptab.info", 2) != nil
    }

    /// The report (PDF preview) from the order's estimate tab: its pages, the set-up, the issue sheet (not issued).
    func report(_ name: String) {
        guard tap("es.preview", 3, wait: 3) || tap("fp.quote", 2, wait: 4) else { skip(name + "-report"); return }
        S(name + "-report")
        for i in 0..<2 where tap("rp.next", 2, wait: 1.2) { S(name + "-report-p\(i + 2)") }
        if tap("rp.setup", 2) { S(name + "-report-setup"); tap("rp.done", 2, wait: 2) }
        if tap("rp.issue", 2) { S(name + "-report-issue"); closeSheets() }
        back()
    }
}

/// App-wide: the opening animation, the first run, Home, the tabs, Profile and its pages and sheets, the language
/// switch, dark mode, the Device sheet, the secret taps to "Lazer sinovi", and the laser radar in every state.
final class TourAppTests: TourBase {
    func test1FirstRunAndProfile() {
        role = "app"
        start(nil, radar: nil)
        // the opening animation (3.4 s), then the welcome page
        frames("opening", [0.3, 0.6, 0.8, 0.9, 1.2])
        guard find("welcome.skip", 20) != nil else { skip("welcome"); return }
        sleep(2); S("welcome")
        if tap("welcome.lang", 3, wait: 0.6) { S("welcome-lang-menu"); tapOutside(app); usleep(500_000) }
        tap("welcome.skip", 3)
        S("local-form")
        type(app.textFields.element(boundBy: 0), lang == "ru" || lang == "uzc" ? "Санжар Уста" : "Sanjar Usta")
        type(app.textFields.element(boundBy: 1), "901234567")
        S("local-filled")
        tap("local.start", 3, wait: 1.2)
        if find("ind.go", 6) != nil {
            S("industry")
            app.swipeUp(); usleep(600_000); S("industry-2")
            tap("ind.elec", 2, wait: 0.5); S("industry-picked")
            tap("ind.build", 2, wait: 0.5)
            tap("ind.go", 3, wait: 1.5)
        } else { skip("industry") }
        guard find("laser", 10) != nil else { skip("home"); return }
        sleep(1); scrollShots("home-build", 3)
        tap("home.measure", 3, wait: 1.2); scrollShots("measure", 3); back()
        tap("home.calc", 3, wait: 1.2); S("calc"); back()
        tap("tab.projects", 3); S("projects-empty")
        tap("tab.measure", 2); S("tab-measure")
        // the Device sheet (the simulator has no Bluetooth: the sheet, not the radar)
        tap("tab.home", 3)
        if tap("laser", 3) { S("device-sheet"); closeSheets() }
        profile()
        if tapText("pf.more", 3, wait: 1.2) {
            scrollShots("settings-more", 3)
            if tapText("se.units") { S("units-sheet"); closeSheets() }
            back()
        }
        for (k, n) in [("ind.row", "industry-sheet"), ("se.reportLang", "report-lang-sheet"), ("se.pdf", "pdf-parts-sheet"),
                       ("np.currency", "currency-sheet"), ("se.defaults", "defaults-sheet")] {
            if tapText(k) { scrollShots(n, 2); closeSheets() }
        }
        if tap("profile.me", 2) { S("profile-me"); closeSheets(); if find("tab.profile", 1) == nil { back() } }
        // the language switch: the next language, Home and Profile in it, then back
        let next = ["uz": "Русский", "ru": "English", "en": "Ўзбекча (кирилл)", "uzc": "O‘zbekcha (lotin)"][lang] ?? "Русский"
        let mine = ["uz": "O‘zbekcha (lotin)", "ru": "Русский", "en": "English", "uzc": "Ўзбекча (кирилл)"][lang] ?? "O‘zbekcha (lotin)"
        let nextCode = ["uz": "ru", "ru": "en", "en": "uzc", "uzc": "uz"][lang] ?? "ru"
        if tapText("se.lang") {
            S("language-sheet")
            if hit(labelled(next, 2)) {
                sleep(1); S("language-switched-profile")
                tap("tab.home", 2); S("language-switched-home")
                tap("tab.profile", 2)
                if hit(labelled(tr("se.lang", in: nextCode), 3)) { usleep(800_000); if hit(labelled(mine, 2)) { sleep(1) } else { closeSheets() } }
                else { skip("language-back") }
            } else { closeSheets() }
        }
        // dark mode
        tap("tab.profile", 2)
        if hit(labelled(tr("nt.dark"), 3)) {
            S("profile-dark"); tap("tab.home", 2); S("home-dark")
            if tap("laser", 2) { S("device-sheet-dark"); closeSheets() }
            tap("tab.projects", 2); S("projects-dark")
            tap("tab.profile", 2); hit(labelled(tr("nt.dark"), 3)); usleep(600_000)
        }
        // seven taps on the version line: test mode, then the Device sheet's "Lazer sinovi"
        for _ in 0..<8 { app.swipeUp(); usleep(200_000) }
        if let v = find("pf.version", 3) {
            for _ in 0..<7 { v.tap(); usleep(150_000) }
            sleep(1); S("dev-mode-on")
            tap("tab.home", 2)
            if tap("laser", 3) {
                S("device-sheet-test-row")
                if tapText("lt.title", 3, wait: 1.5) { scrollShots("laser-test", 3); back() } else { skip("laser-test-row") }
                closeSheets()
            }
        } else { skip("version-line") }
    }

    /// The radar page in each of its states (staged: RealLaser.uiStage), opened from Home's laser button.
    func test2Radar() {
        role = "radar"
        let stages = ["search", "nothing", "found", "connecting", "connected", "lost", "fail-timeout", "fail-busy", "fail-notLaser",
                      "fail-btOff", "fail-permission", "fail-many", "off", "denied"]
        for st in stages {
            start("build", radar: st)
            guard tap("laser", 6, wait: 0.4) else { skip("radar-" + st); app.terminate(); continue }
            switch st {
            case "search", "connecting": frames("radar-" + st, [0.3, 1.0])
            case "nothing": sleep(9); S("radar-nothing")
            case "found", "lost": frames("radar-" + st, [0.6, 1.6])
            default: frames("radar-" + st, [0.5, 1.5])
            }
            if st == "search" || st == "found" {
                // the other Bluetooth devices
                if hit(labelled(tr("lr.others"), 2)) { usleep(900_000); S("radar-" + st + "-others") }
            }
            if st == "fail-many" { app.swipeUp(); usleep(600_000); S("radar-fail-many-scrolled") }
            app.terminate()
        }
    }
}

/// The builder: a project with GPS, the start dialog, the room flow, the room editor, the estimate, the report.
final class TourBuildTests: TourBase {
    func testBuilder() {
        role = "build"
        start("build")
        S("home")
        tap("tab.projects", 3); S("projects-empty"); tap("tab.home", 3)
        guard newOrder("Yangi uy", "project") else { return }
        if find("sd.a", 4) != nil {
            S("start-dialog")
            tap("sd.a", 3)
            if find("nr.create", 4) != nil { S("room-sheet") }
            tap("nr.create", 3)
            roomFlow(mm: false)
            roomEditor()
            // "Smeta" from the editor's main button
            if tap("re.main", 3, wait: 1.5) { S("re-main") }
        } else { skip("start-dialog") }
        toOrder()
        orderTabs("project")
        // the estimate: a material, then the report
        if tap("ptab.estimate", 3) {
            if tap("es.addMat", 3) { S("estimate-material-sheet"); typeName(app, "Bo‘yoq"); typeIn(app, "gs.qty", "12"); typeIn(app, "gs.price", "50000"); S("estimate-material-filled"); tap("gs.save", 3) }
            if tap("es.quick", 2) { S("estimate-quick"); closeSheets() }
            scrollShots("estimate", 3)
            report("estimate")
        }
        if tap("project.menu", 3) { S("project-menu"); closeSheets() }
        // a second project's other start: the estimate first
        if toHome(), newOrder("Ofis ta’miri", "project2"), tap("sd.b", 4, wait: 1.2) { S("start-b-estimate") }
        _ = toHome()
        tap("tab.projects", 3); S("projects-list")
        profile()
    }
}

/// The furniture maker (simple, then Advanced): the order with GPS, the start dialog, the room flow, the gallery for the
/// room, the room editor, "Mebel joylash", every model in Designer C and its 3D, the price, the documents.
final class TourFurnTests: TourBase {
    func testFurniture() {
        role = "furn"
        start("furniture")
        S("home")
        guard newOrder("Dilnoza Karimova") else { return }
        if find("sd.a", 4) != nil {
            S("start-dialog")
            tap("sd.a", 3)
            if find("fr.create", 4) != nil { S("room-sheet") }
            tap("fr.create", 3)
            roomFlow(mm: true)
            if tap("ux.coachOk", 3, wait: 0.5) {}
            if find("re.editRoom", 5) != nil { scrollShots("gallery-for-room", 3) }
            roomEditor()
            // "Mebel joylash" under "Qo‘shimcha"
            if reToolT("more"), tap("re.o.fp", 3, wait: 1.5) { S("arrange"); back() } else { skip("arrange") }
            if tap("re.main", 3, wait: 1.5) { S("re-main-gallery") }
        } else { skip("start-dialog") }
        // an L-kitchen placed on the measured room's walls
        if find("model.L", 4) != nil || (toOrder() && tap("fz.addMore", 4, wait: 1.2)) {
            if hit(find("model.L", 4)) {
                usleep(1_200_000)
                S("place-walls-step")
                if tap("fz.place", 4, wait: 3) { calm(); S("kitchen-designer"); designerC("kitchen") }
            }
        }
        toOrder()
        orderTabs("order")
        if tap("fz.addMore", 3, wait: 1.2) { S("add-more-gallery"); back() }
        // every model in Designer C, without a room
        models()
        // Advanced: the price, the parts, the workshop pack, the quote
        advancedOn()
        if openOrder("Dilnoza Karimova") {
            orderTabs("adv-order")
            if tap("ptab.price", 3, wait: 1.2) {
                scrollShots("price", 4)
                if tap("fp.days", 2) { S("price-days"); closeSheets() }
                if tap("fp.cut", 3, wait: 2) { scrollShots("cut-list", 2); tapText("fc.sheets", 2); S("cut-sheets"); back() }
                if tap("fp.pack", 3, wait: 4) { S("pack"); app.swipeLeft(); usleep(900_000); S("pack-p2"); back() }
                if tap("fp.quote", 3, wait: 4) { S("quote"); app.swipeLeft(); usleep(900_000); S("quote-p2"); if tap("rp.issue", 2) { S("quote-issue"); closeSheets() }; back() }
            } else { skip("price-tab") }
            if tap("ptab.info", 2) { scrollShots("adv-stages", 3) }
        }
        _ = toHome()
        S("home-with-order")
        tap("tab.projects", 3); S("orders-list")
        profile()
        if tap("pf.workshop", 3) { scrollShots("workshop", 3); back() }
        if tap("pf.mats", 3) { scrollShots("materials", 2); back() }
    }

    /// Designer C on what is open: the slider, Tekshiruv, Batafsil, a unit selected and its tools, the 3D.
    func designerC(_ name: String) {
        if find("dzc.t.checks", 5) == nil && find("dim.3D", 2) == nil { skip(name + "-designer"); return }
        if tap("kt.auto", 1, wait: 2) {}
        calm()
        S(name + "-dzc")
        dzcTool(app, "checks"); S(name + "-dzc-checks"); dzcBack(app)
        if find("dzc.t.more", 1) != nil { dzcTool(app, "more"); usleep(800_000); scrollShots(name + "-dzc-more", 2); closeSheets() }
        let unit = app.descendants(matching: .any).matching(NSPredicate(format: "identifier MATCHES %@", "dzc\\.(m\\.[a-z]+[0-9]+|s[0-9]+)")).firstMatch
        if unit.exists {
            dzcTapEl(app, unit.identifier)
            S(name + "-dzc-selected")
            for t in ["width", "type", "decor", "handle", "in"] where app.buttons["dzc.t." + t].exists {
                dzcTool(app, t); S(name + "-dzc-" + t); dzcBack(app)
            }
            tap("dzc.desel", 1, wait: 0.5)
        }
        if tap("dim.3D", 3, wait: 5) || tap("seg.r", 2, wait: 5) {
            S(name + "-3d")
            if tap("f3.openAll", 3, wait: 3) { S(name + "-3d-open"); tap("f3.close", 2, wait: 1) }
            if !tap("dim.2D", 2) { tap("seg.l", 2) }
        }
    }

    /// Every model of the gallery (or one of each group) through its size steps into the designer.
    func models() {
        guard toOrder(), tap("fz.addMore", 4, wait: 1.5) else { skip("models-gallery"); return }
        // the model ids, group by group
        var groups: [String] = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'fg.chip.'")).allElementsBoundByIndex.map(\.identifier)
        if groups.isEmpty { groups = ["fg.chip.kitchen"] }
        var list: [(String, String)] = []
        for g in groups {
            if let c = find(g, 2), bring(c, vertical: false) { c.tap(); usleep(1_000_000) }
            S("gallery-" + g.replacingOccurrences(of: "fg.chip.", with: ""))
            var seen = 0
            for _ in 0..<6 {
                let ms = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'model.'")).allElementsBoundByIndex
                for m in ms where m.m3Seen && !list.contains(where: { $0.1 == m.identifier }) { list.append((g, m.identifier)) }
                if list.count == seen { break }
                seen = list.count
                if !allModels { break }
                drag(down: false)
            }
        }
        back()
        var done: Set<String> = []
        var firstOfGroup: Set<String> = []
        for (g, m) in list where !done.contains(m) {
            if !allModels && firstOfGroup.contains(g) { continue }
            firstOfGroup.insert(g); done.insert(m)
            let name = m.replacingOccurrences(of: "model.", with: "m-")
            guard toOrder(), tap("fz.addMore", 4, wait: 1.2) else { skip(name + "-gallery"); continue }
            if let c = find(g, 2), bring(c, vertical: false) { c.tap(); usleep(900_000) }
            guard hit(find(m, 4)) else { skip(name + "-card"); continue }
            usleep(1_200_000)
            // a tap while the list was still gliding to the group: once more
            if find("fx.next", 1.5) == nil && find("fx.value", 0.5) == nil && find("fx.go", 0.5) == nil { hit(find(m, 2)); usleep(1_200_000) }
            S(name + "-step1")
            guard sizes(name) else { skip(name + "-sizes"); continue }
            S(name + "-summary")
            tap("fx.go", 3, wait: 1.5)
            if tap("fq.none", 2, wait: 1.5) {}
            sleep(2); calm()
            designerC(name)
        }
    }

    /// The size steps with the model's own usual sizes; true at the summary.
    func sizes(_ name: String) -> Bool {
        var shots = 0
        for _ in 0..<14 {
            if app.buttons["fx.go"].exists { return true }
            let f = app.textFields["fx.value"]
            if f.exists {
                let raw = (f.placeholderValue ?? "").isEmpty ? (f.value as? String ?? "") : (f.placeholderValue ?? "")
                let v = String(raw.filter { $0.isNumber || $0 == "," || $0 == "." })
                if v.isEmpty { return false }
                type(f, v, clear: true)
                if shots < 2 { shots += 1; S(name + "-size-\(shots)") }
            }
            guard let next = find("fx.next", 4) else { return find("fx.go", 2) != nil }
            guard next.isEnabled else { return false }
            hit(next); usleep(900_000)
        }
        return find("fx.go", 3) != nil
    }
}

/// The four trades: the order with GPS, the start dialog, the trade's room sheet, the room flow, the room editor, the
/// trade's own page for the room (and what its buttons open), its gallery, the order's tabs; then Advanced with the
/// prices, the calculator, the estimate and the report; and the other start (without a room).
class TourTradeBase: TourBase {
    func trade(_ industry: String, sheet: String, view: String, viewPrefixes: [String], galleryLater: String, kit: String, steps: (String, String)) {
        role = industry
        start(industry)
        S("home")
        // the trade's own gallery tile and the Measure page from Home
        for t in ["home.tGallery", "home.eGallery", "home.pGallery", "home.wGallery"] where tap(t, 1, wait: 1.5) {
            S("home-tile"); closeSheets(); if !(find("home.new", 1)?.m3Seen ?? false) { backTo("home.new", 3) }; tap("re.pkX", 0.5)
            _ = toHome()
        }
        if tap("home.measure", 2, wait: 1.2) { S("home-measure"); _ = toHome() }
        guard newOrder("Aziza Nazarova") else { return }
        if find("sd.a", 4) != nil {
            S("start-dialog")
            tap("sd.a", 3)
            if find(sheet, 4) != nil { S("room-sheet") }
            tap(sheet, 3)
            roomFlow(mm: false)
            roomEditor()
            // the editor's main button: the trade's own page for the room
            if tap("re.main", 3, wait: 2.5) {
                calm()
                S("view")
                if let k = findPrefix(kit, 2) {
                    // a tiler's gallery for the room first: a layout, its steps
                    S("view-gallery")
                    hit(k); usleep(1_200_000)
                    tradeSteps(steps)
                    sleep(2); calm(); S("view-after-steps")
                }
                explore("view", viewPrefixes, marker: view, max: 12)
            } else { skip("re-main") }
        } else { skip("start-dialog") }
        toOrder()
        orderTabs("order")
        // the other start: an order without a room, its gallery and first kit
        if toHome(), newOrder("Bobur Rahimov", "order2") {
            if tap("sd.b", 4, wait: 1.5) {
                scrollShots("gallery", 3)
                if hit(findPrefix(kit, 3)) {
                    usleep(1_200_000)
                    tradeSteps(steps)
                    sleep(2); calm(); S("gallery-kit-done")
                    explore("gallery-view", viewPrefixes, marker: view, max: 6)
                } else { skip("gallery-kit") }
            } else { skip("start-b") }
        }
        // Advanced: the prices, the calculator on the estimate, the report
        advancedOn()
        _ = toHome()
        if tap("tab.profile", 3) {
            let pr = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'pf.' AND identifier ENDSWITH 'Prices'")).firstMatch
            if hit(pr) { usleep(900_000); scrollShots("prices", 3); closeSheets() } else { skip("prices") }
        }
        if openOrder("Aziza Nazarova") {
            orderTabs("adv-order")
            if tap("ptab.estimate", 3) {
                if tap("trc.set", 3) { scrollShots("calc-settings", 3); closeSheets() }
                if tap("trc.apply", 3, wait: 1.5) { S("calc-applied") }
                scrollShots("estimate", 3)
                report("estimate")
            } else { skip("estimate-tab") }
        }
        _ = toHome()
        S("home-with-orders")
        tap("tab.projects", 3); S("orders-list")
        profile()
    }

    /// A kit's or layout's steps: next until save (the steps' own usual values).
    func tradeSteps(_ ids: (String, String)) {
        if ids.0 == ids.1 {
            if find(ids.0, 3) != nil { S("steps-1"); tap(ids.0, 2, wait: 1.5) } else { skip("steps-" + ids.0) }
            return
        }
        for i in 0..<10 {
            if let s = find(ids.1, 1), s.m3Seen, !(find(ids.0, 0.5)?.m3Seen ?? false) { S("steps-last"); hit(s); usleep(1_500_000); return }
            guard let n = find(ids.0, 2) else {
                if let s = find(ids.1, 1) { S("steps-last"); hit(s); usleep(1_500_000) }
                return
            }
            if i < 4 { S("steps-\(i + 1)") }
            guard n.isEnabled else { skip("steps-disabled"); return }
            hit(n); usleep(900_000)
        }
    }
}

final class TourTilerTests: TourTradeBase {
    func testTiler() {
        trade("tiler", sheet: "tl.roomCreate", view: "tv.addLayout", viewPrefixes: ["tv.", "3d."], galleryLater: "tg.later",
              kit: "tmodel.", steps: ("ts.next", "ts.save"))
    }
}

final class TourElecTests: TourTradeBase {
    func testElectrician() {
        trade("elec", sheet: "el.roomCreate", view: "3d.save", viewPrefixes: ["ev.", "el.", "3d."], galleryLater: "eg.later",
              kit: "ekit.", steps: ("es.next", "es.save"))
    }
}

final class TourPlumbTests: TourTradeBase {
    func testPlumber() {
        trade("plumb", sheet: "sx.roomCreate", view: "pv.addPt", viewPrefixes: ["pv.", "sx.", "3d."], galleryLater: "pg.later",
              kit: "pkit.", steps: ("ps.next", "ps.save"))
    }
}

final class TourWinTests: TourTradeBase {
    func testWindows() {
        trade("win", sheet: "dw.roomCreate", view: "wv.addItem", viewPrefixes: ["wv.", "dw.", "3d."], galleryLater: "wg.later",
              kit: "wkind.", steps: ("dw.put", "dw.put"))
    }
}
