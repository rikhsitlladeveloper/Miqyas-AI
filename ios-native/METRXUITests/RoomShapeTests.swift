import XCTest

/// Order location, the start dialog and room shapes (design/room-shapes/BUILD_SPEC.md, room-editor mockup v2): a
/// furniture maker's new order with the GPS skipped, "Nimadan boshlaymiz?" → "Xonani o‘lchash", an L-shaped room
/// through the shape flow, a door placed from the icon row with its style and sizes, the summary, the gallery on the
/// room's type, the one room editor (a tool's options, the wall view, the 3D), and the order card's location line.
final class RoomShapeTests: ScreenTestCase {
    func testOrderLocationAndAnLShapedRoom() {
        let app = launch()
        firstRun(app, "ind.furn")

        // the new order: the "Joylashuv" block under the address, skipped with "Keyinroq"
        app.buttons["home.new"].tap(); usleep(900_000)
        app.textFields.element(boundBy: 0).typeText("Aziza Nazarova")
        XCTAssertTrue(app.buttons["loc.get"].waitForExistence(timeout: 4)); shot("rs-01-form-location")
        if !app.buttons["loc.later"].isHittable { app.swipeUp(); usleep(500_000) }
        app.buttons["loc.later"].tap(); usleep(600_000)
        XCTAssertTrue(app.descendants(matching: .any)["loc.no"].waitForExistence(timeout: 3)); shot("rs-02-location-later")
        app.buttons["no.create"].tap(); usleep(1_200_000)

        // "Nimadan boshlaymiz?": two cards and "Keyinroq"; the room first
        XCTAssertTrue(app.buttons["sd.a"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["sd.b"].exists)
        XCTAssertTrue(app.buttons["sd.later"].exists); shot("rs-02a-start-dialog")
        app.buttons["sd.a"].tap(); usleep(900_000); shot("rs-03-room-sheet")
        XCTAssertTrue(app.buttons["fr.create"].waitForExistence(timeout: 4))
        app.buttons["fr.create"].tap(); sleep(1)
        XCTAssertTrue(app.buttons["rsh.shapeGo"].waitForExistence(timeout: 5)); shot("rs-04-shapes")

        // the L shape, mirrored and back
        app.buttons["rsh.shape.L"].tap(); usleep(500_000)
        app.buttons["rsh.mirror"].firstMatch.tap(); usleep(500_000); shot("rs-05-L-mirrored")
        app.buttons["rsh.mirror"].firstMatch.tap(); usleep(500_000)
        app.buttons["rsh.shapeGo"].tap(); usleep(900_000); shot("rs-06-wall-A")

        // the walls, one a step: a live plan while typing; a wall above 30 m is asked about, not stopped
        let f = app.textFields["rsh.value"]
        XCTAssertTrue(f.waitForExistence(timeout: 4))
        f.tap(); f.typeText("45000"); usleep(500_000)
        XCTAssertTrue(app.descendants(matching: .any)["re.bigNote"].waitForExistence(timeout: 3)); shot("rs-07a-big-wall")
        for _ in 0..<5 { f.typeText(XCUIKeyboardKey.delete.rawValue) }
        f.typeText("1800"); usleep(500_000); shot("rs-07-wall-A-typed")
        app.buttons["rsh.next"].tap(); usleep(700_000)
        flowType(app, "1800")
        flowType(app, "2400")
        shot("rs-08-wall-D")
        flowType(app, "1800")

        // the height: the last one (2 700) is kept with one tap
        XCTAssertTrue(app.textFields["rsh.value"].waitForExistence(timeout: 4)); shot("rs-09-height")
        app.buttons["rsh.next"].tap(); usleep(800_000)

        // the openings step: the hand shows how, the icon row, the wall chips
        XCTAssertTrue(app.buttons["rsh.opsDone"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["re.tile.door"].exists)
        sleep(2); shot("rs-10-openings-hand")
        // a door: its icon, wall A's chip, the style window
        app.buttons["re.tile.door"].tap(); usleep(700_000); shot("rs-11-door-armed")
        app.buttons["re.wchip.A"].tap(); usleep(900_000)
        XCTAssertTrue(app.buttons["re.sty.single"].waitForExistence(timeout: 4)); shot("rs-12-style-window")
        app.buttons["re.sty.single"].tap(); usleep(900_000)
        // its sizes one per step: the width's chips, then the height typed
        XCTAssertTrue(app.textFields["rsh.value"].waitForExistence(timeout: 4)); shot("rs-12a-size-width")
        app.buttons["rsh.next"].tap(); usleep(800_000)
        shot("rs-12b-size-height")
        flowType(app, "2100")
        sleep(1); shot("rs-13-door-placed"); noToast(app)
        // the floating card of the placed door: its type, size, delete; folded to a line and back
        XCTAssertTrue(app.buttons["re.cType"].waitForExistence(timeout: 4))
        app.buttons["re.cardMin"].tap(); usleep(600_000); shot("rs-13a-card-folded")
        app.buttons["re.cardMin"].tap(); usleep(600_000)
        // a second door: the style window offers "Yana shu"
        app.buttons["re.desel"].tap(); usleep(500_000); noToast(app)
        app.buttons["re.tile.door"].tap(); usleep(600_000)
        app.buttons["re.wchip.C"].tap(); usleep(900_000)
        XCTAssertTrue(app.buttons["re.again"].waitForExistence(timeout: 4)); shot("rs-13b-same-again")
        app.buttons["re.again"].tap(); usleep(900_000); noToast(app)
        XCTAssertTrue(app.buttons["re.list"].waitForExistence(timeout: 4))
        app.buttons["re.list"].tap(); usleep(700_000); shot("rs-13c-list")
        app.buttons.matching(identifier: "re.row.door").firstMatch.tap(); usleep(700_000)

        // the summary, then the gallery on the room's type
        app.buttons["rsh.opsDone"].tap(); usleep(900_000)
        XCTAssertTrue(app.buttons["rsh.open"].waitForExistence(timeout: 4)); shot("rs-14-summary")
        app.swipeUp(); usleep(500_000); shot("rs-15-summary-scrolled")
        app.buttons["rsh.open"].tap(); sleep(2)
        if app.buttons["ux.coachOk"].waitForExistence(timeout: 2) { app.buttons["ux.coachOk"].tap(); usleep(600_000) }
        XCTAssertTrue(app.buttons["re.editRoom"].waitForExistence(timeout: 5)); shot("rs-16-gallery-for-room")

        // the one room editor: the tools follow the selection, a tool's options with "←", the wall view, the 3D
        if !app.buttons["re.editRoom"].isHittable { app.swipeUp(); usleep(500_000) }
        app.buttons["re.editRoom"].tap(); sleep(1)
        XCTAssertTrue(app.buttons["re.t.add"].waitForExistence(timeout: 5)); shot("rs-17-editor")
        reTool(app, "rh"); shot("rs-18-editor-height-options")
        XCTAssertTrue(app.buttons["dzc.back"].waitForExistence(timeout: 3))
        app.buttons["dzc.back"].tap(); usleep(500_000)
        reTool(app, "checks"); shot("rs-19-editor-checks")
        app.buttons["dzc.back"].tap(); usleep(500_000)
        app.buttons["re.vFront"].tap(); usleep(800_000); shot("rs-20-editor-wall-view")
        app.buttons["re.v3d"].tap(); usleep(900_000); shot("rs-21-editor-3d")
        app.buttons["re.v2d"].tap(); usleep(700_000)
        app.buttons["re.vPlan"].tap(); usleep(700_000)

        // the order card: "Joylashuv yo‘q" with "+ Qo‘shish"
        sleep(6)    // the "added" toast goes first
        for _ in 0..<8 where !app.buttons["home.new"].exists { backVisible(app) }
        XCTAssertTrue(app.descendants(matching: .any)["loc.add"].waitForExistence(timeout: 4)); shot("rs-22-card-location")
        app.descendants(matching: .any)["loc.add"].firstMatch.tap(); usleep(900_000)
        XCTAssertTrue(app.buttons["loc.get"].waitForExistence(timeout: 3)); shot("rs-23-location-sheet")
        app.buttons["sheet.close"].tap(); usleep(600_000)
    }
}
