import XCTest

/// Modern 3D, for review from CI (there is no Mac to look at it): a kitchen in three design style presets, its doors
/// open, a kupe, a hinged wardrobe, a gorka, the big dining table, a bed with a tufted headboard and the soft wall
/// panel, a bunk bed and the sink vanity, each in the designers' 3D, plus the gallery once its cards are made.
/// Every piece is made the same way: the order's style step (a preset), the gallery's card, the model's own usual sizes
/// typed in (each step's placeholder), "Xonasiz qoldirish", then the designer's 3D (2D | 3D switch, or the item
/// designer's "Xonada 3D").
/// A step that cannot be reached saves "m3d-skip-<name>-<where>" and the test goes on: no assertion here fails the
/// run, so one broken screen does not hide the others' pictures.
final class Modern3DShots: ScreenTestCase {

    /// The gallery, a kitchen in "twotone" with its doors open, then the same kitchen in "neo" and in "dark" (new orders).
    func testKitchens() {
        let app = launch()
        firstRun(app, "ind.furn")
        if m3NewOrder(app, "Kamola Rashidova", "twotone", "kitchen-twotone") {
            m3WaitCards()
            shot("m3d-gallery")
            m3Piece(app, "L", "kitchen", "kitchen-twotone", after: {
                if self.m3Tap(app, "f3.openAll", 6) { sleep(4); self.shot("m3d-kitchen-open") } else { self.m3Skip("kitchen-open", "button") }
            })
        }
        for (who, preset) in [("Nigora Saidova", "neo"), ("Dilfuza Karimova", "dark")] {
            guard m3ToHome(app) else { m3Skip("kitchen-" + preset, "home"); continue }
            if m3NewOrder(app, who, preset, "kitchen-" + preset) { m3Piece(app, "L", "kitchen", "kitchen-" + preset) }
        }
    }

    /// A kupe (closed, all doors slid, one door slid by a tap), a hinged wardrobe (closed and open) and a gorka, in one
    /// "twotone" order.
    func testCabinets() {
        let app = launch()
        firstRun(app, "ind.furn")
        guard m3NewOrder(app, "Aziza Nazarova", "twotone", "cabinets") else { return }
        m3Piece(app, "s2", "bedroom", "kupe", after: {
            if self.m3Tap(app, "f3.openAll", 6) { sleep(4); self.shot("m3d-kupe-open") } else { self.m3Skip("kupe-open", "button") }
            // all shut again, then a tap on the middle of the picture slides the door there
            if self.m3Tap(app, "f3.close", 4) {
                sleep(3)
                // a first tap selects in the designer, a later one slides the door (three at most, until one is open)
                let close = app.descendants(matching: .any)["f3.close"].firstMatch
                for _ in 0..<3 {
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42)).tap(); sleep(2)
                    guard close.exists, let v = close.value as? String, v == "0" else { break }
                }
                sleep(2)
                self.shot("m3d-kupe-door")
            }
        })
        m3Piece(app, "h3", "bedroom", "wardrobe", after: {
            if self.m3Tap(app, "f3.openAll", 6) { sleep(4); self.shot("m3d-wardrobe-open") }
        })
        m3Piece(app, "gorka", "living", "gorka")
    }

    /// The big dining table, a bed (tufted headboard and the soft wall panel from its design card), a bunk bed and the
    /// sink vanity (ceramic basin), in one "twotone" order.
    func testBedsAndTables() {
        let app = launch()
        firstRun(app, "ind.furn")
        guard m3NewOrder(app, "Shahzoda Yuldosheva", "twotone", "items") else { return }
        m3Piece(app, "dining12", "living", "table12")
        m3Piece(app, "bed", "bedroom", "bed", design: { self.m3BedDesign(app) })
        m3Piece(app, "bunk", "kids", "bunk")
        m3Piece(app, "sinkV", "bath", "vanity")
    }

    // MARK: - one piece

    /// From the gallery (or the order page's "Yana mebel qo‘shish"): model in the gallery's group, its usual sizes,
    /// no room, then design (before the 3D), the 3D shot "m3d-<name>" and after (more shots in the 3D); back to the order.
    private func m3Piece(_ app: XCUIApplication, _ model: String, _ group: String, _ name: String,
                         design: (() -> Void)? = nil, after: (() -> Void)? = nil) {
        defer { _ = m3ToOrder(app) }
        guard m3Gallery(app) else { m3Skip(name, "gallery"); return }
        guard let card = m3Find(app, "model." + model, 12) else { m3Skip(name, "card"); return }
        // the group's chip jumps the list to it (the chip row scrolls sideways)
        if let chip = m3Find(app, "fg.chip." + group, 2), m3Bring(app, chip, vertical: false) { chip.tap(); usleep(1_200_000) }
        guard m3Bring(app, card) else { m3Skip(name, "card-hidden"); return }
        card.tap(); usleep(1_200_000)
        guard m3Sizes(app) else { m3Skip(name, "sizes"); return }
        guard m3Tap(app, "fx.go", 6) else { m3Skip(name, "summary"); return }
        usleep(1_000_000)
        // with no measured room "Qaysi xonaga?" is skipped and the designer opens (UX upgrades section 7)
        if let none = m3Find(app, "fq.none", 3), m3Bring(app, none) { none.tap() }
        sleep(2)
        design?()
        guard m3Open3D(app, name) else { return }
        shot("m3d-" + name)
        after?()
    }

    /// The bed's design card (the item designer's 2D page): the headboard "Karetka (tugmali)" and "Yumshoq devor paneli".
    private func m3BedDesign(_ app: XCUIApplication) {
        noToast(app, 7)
        guard m3Find(app, "dim.2D", 10) != nil else { m3Skip("bed", "designer"); return }
        if let chip = m3Find(app, "lk.ch.tufted", 6), m3Bring(app, chip) { chip.tap(); sleep(2) } else { m3Skip("bed", "tufted") }
        if let panel = m3Find(app, "lk.panel", 4), m3Bring(app, panel) {
            if (panel.value as? String) != "1" { panel.tap(); sleep(2) }
        } else { m3Skip("bed", "panel") }
        shot("m3d-bed-design")
        // back to the top: the piece's own 3D picture (the design card well down the page again)
        let win = app.windows.firstMatch.frame
        let card = app.descendants(matching: .any).matching(identifier: "lk.card").firstMatch
        for _ in 0..<8 where !(card.exists && card.frame.minY > win.minY + win.height * 0.55) { m3Drag(app, down: true) }
        sleep(2); shot("m3d-bed-piece")
    }

    // MARK: - steps

    /// A new order for who, preset picked on its style step; true once its gallery is open.
    private func m3NewOrder(_ app: XCUIApplication, _ who: String, _ preset: String, _ name: String) -> Bool {
        guard m3Tap(app, "home.new", 12) else { m3Skip(name, "new-order"); return false }
        usleep(900_000)
        let field = app.textFields.element(boundBy: 0)
        guard field.waitForExistence(timeout: 10) else { m3Skip(name, "order-name"); return false }
        field.tap(); usleep(300_000); field.typeText(who)
        guard m3Tap(app, "no.create", 6) else { m3Skip(name, "order-create"); return false }
        usleep(1_200_000)
        if let card = m3Find(app, "lk.p." + preset, 12), m3Bring(app, card) {
            card.tap(); usleep(1_200_000)
        } else {
            m3Skip(name, "style-" + preset)
            if let later = m3Find(app, "lk.later", 3), m3Bring(app, later) { later.tap(); usleep(1_000_000) }
        }
        guard m3Find(app, "fg.chip.kitchen", 12) != nil else { m3Skip(name, "gallery"); return false }
        return true
    }

    /// The gallery on screen: already there, or from the order page's dashed "add more" button.
    private func m3Gallery(_ app: XCUIApplication) -> Bool {
        if app.buttons["fg.chip.kitchen"].exists { return true }
        guard m3ToOrder(app) else { return false }
        if !app.buttons["fz.addMore"].exists, app.buttons["ptab.rooms"].exists { app.buttons["ptab.rooms"].tap(); usleep(900_000) }
        guard let more = m3Find(app, "fz.addMore", 8), m3Bring(app, more) else { return false }
        more.tap(); usleep(1_200_000)
        return m3Find(app, "fg.chip.kitchen", 10) != nil
    }

    /// The size steps with the model's usual sizes (each field's placeholder typed in); choice and picture steps keep
    /// their usual answer. True at the summary ("Davom etish").
    private func m3Sizes(_ app: XCUIApplication) -> Bool {
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
    /// its buttons are there and the picture has had time to render.
    private func m3Open3D(_ app: XCUIApplication, _ name: String) -> Bool {
        noToast(app, 7)    // the "created" toast lies over the top bar
        // a new kitchen comes filled; "Avto" only when a wall is still empty
        if app.buttons["kt.auto"].exists { app.buttons["kt.auto"].tap(); sleep(3) }
        guard let sw = m3FindAny(app, ["dim.3D", "seg.r"], 12) else { m3Skip(name, "no-3d-switch"); return false }
        sw.tap()
        guard m3Find(app, "f3.openAll", 15) != nil else { sleep(3); m3Skip(name, "3d-not-shown"); return false }
        sleep(5)    // RealityKit's first frames on the simulator
        return true
    }

    /// Back to the order's page (its tabs), past sheets and pages.
    @discardableResult
    private func m3ToOrder(_ app: XCUIApplication) -> Bool {
        for _ in 0..<7 {
            if app.buttons["ptab.rooms"].exists { return true }
            if app.buttons["sheet.close"].exists && app.buttons["sheet.close"].m3Seen { app.buttons["sheet.close"].tap(); usleep(800_000); continue }
            noToast(app, 4)
            backVisible(app)
        }
        return app.buttons["ptab.rooms"].waitForExistence(timeout: 3)
    }

    /// Back to Home, where "Yangi buyurtma" is.
    private func m3ToHome(_ app: XCUIApplication) -> Bool {
        for _ in 0..<7 {
            let nb = app.buttons["home.new"]
            if nb.exists && nb.m3Seen { return true }
            let home = app.buttons["tab.home"]
            if home.exists && home.m3Seen { home.tap(); usleep(1_000_000) } else { noToast(app, 4); backVisible(app) }
        }
        return app.buttons["home.new"].waitForExistence(timeout: 3)
    }

    /// Waits (at most maxWait) until the screen stops changing: the gallery's cards have come out of the real 3D.
    private func m3WaitCards(_ maxWait: TimeInterval = 20) {
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

    // MARK: - small helpers

    /// "m3d-skip-<name>-<where>": what was on screen when a step could not be reached.
    private func m3Skip(_ name: String, _ at: String) {
        XCTContext.runActivity(named: "Modern3DShots: skipped \(name) at \(at)") { _ in }
        shot("m3d-skip-" + name + "-" + at)
    }

    /// The element with identifier id (a button first, else anything), waiting up to t seconds.
    private func m3Find(_ app: XCUIApplication, _ id: String, _ t: TimeInterval) -> XCUIElement? { m3FindAny(app, [id], t) }

    private func m3FindAny(_ app: XCUIApplication, _ ids: [String], _ t: TimeInterval) -> XCUIElement? {
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
    private func m3Tap(_ app: XCUIApplication, _ id: String, _ t: TimeInterval) -> Bool {
        guard let e = m3Find(app, id, t), m3Bring(app, e) else { return false }
        e.tap()
        return true
    }

    /// In sight already, or scrolled until el is in the middle part of the screen (vertical: false only sideways), then
    /// sideways in its row when it is past the edge.
    private func m3Bring(_ app: XCUIApplication, _ el: XCUIElement, vertical: Bool = true) -> Bool {
        guard el.exists else { return false }
        if el.m3Seen { return true }
        let win = app.windows.firstMatch.frame
        guard win.height > 0 else { return el.m3Seen }
        for _ in 0..<(vertical ? 18 : 0) {
            guard el.exists else { return false }
            let f = el.frame
            if f.midY < win.minY + win.height * 0.18 { m3Drag(app, down: true); continue }
            if f.midY > win.minY + win.height * 0.82 { m3Drag(app, down: false); continue }
            break
        }
        if el.m3Seen { return true }
        // a chip or card past the side of its row
        let f = el.frame
        let y = (f.midY - win.minY) / win.height
        guard y > 0.05 && y < 0.95 else { return el.m3Seen }
        for _ in 0..<4 where !el.m3Seen {
            let left = f.midX > win.maxX
            let a = app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.8 : 0.2, dy: y))
            let b = app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.25 : 0.75, dy: y))
            a.press(forDuration: 0.05, thenDragTo: b); usleep(700_000)
        }
        return el.m3Seen
    }

    /// A slow drag (no fling) of about a third of the screen: down true shows what is above, false what is below. It
    /// starts low (or high) so it does not land on a piece's 3D picture at the top, which turns on a drag.
    private func m3Drag(_ app: XCUIApplication, down: Bool) {
        let a = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.4 : 0.76))
        let b = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.76 : 0.4))
        a.press(forDuration: 0.05, thenDragTo: b); usleep(700_000)
    }
}

extension XCUIElement {
    /// On screen and its middle inside the window: unlike isHittable, never fails the test for an element past the
    /// side of a scrolling row ("Activation point invalid").
    var m3Seen: Bool {
        guard exists else { return false }
        let f = frame
        guard !f.isEmpty, f.width > 1, f.height > 1 else { return false }
        let w = XCUIApplication().windows.firstMatch.frame
        return w.isEmpty || w.contains(CGPoint(x: f.midX, y: f.midY))
    }
}
