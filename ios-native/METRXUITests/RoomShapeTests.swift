import XCTest

/// Order location and room shapes (design/room-shapes/BUILD_SPEC.md): a furniture maker's new order with the GPS
/// skipped, then a room through the shape flow — an L shape, its walls, the height, one door, the summary — into the
/// editor, and the order card's location line.
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

        // the gallery's "Avval xonani o‘lchash", the room's type and name, then the shapes
        if app.buttons["lk.later"].waitForExistence(timeout: 4) { if !app.buttons["lk.later"].isHittable { app.swipeUp(); usleep(600_000) }; app.buttons["lk.later"].tap(); usleep(900_000) }
        XCTAssertTrue(app.buttons["fg.measure"].waitForExistence(timeout: 4))
        app.buttons["fg.measure"].tap(); usleep(900_000); shot("rs-03-room-sheet")
        XCTAssertTrue(app.buttons["fr.create"].waitForExistence(timeout: 4))
        app.buttons["fr.create"].tap(); sleep(1)
        XCTAssertTrue(app.buttons["rsh.shapeGo"].waitForExistence(timeout: 5)); shot("rs-04-shapes")

        // the L shape, mirrored and back
        app.buttons["rsh.shape.L"].tap(); usleep(500_000)
        app.buttons["rsh.mirror"].firstMatch.tap(); usleep(500_000); shot("rs-05-L-mirrored")
        app.buttons["rsh.mirror"].firstMatch.tap(); usleep(500_000)
        app.buttons["rsh.shapeGo"].tap(); usleep(900_000); shot("rs-06-wall-A")

        // the walls, one a step: a live plan while typing
        let f = app.textFields["rsh.value"]
        XCTAssertTrue(f.waitForExistence(timeout: 4))
        f.tap(); f.typeText("1800"); usleep(500_000); shot("rs-07-wall-A-typed")
        app.buttons["rsh.next"].tap(); usleep(700_000)
        flowType(app, "1800")
        flowType(app, "2400")
        shot("rs-08-wall-D")
        flowType(app, "1800")

        // the height: the last one (2 700) is kept with one tap
        XCTAssertTrue(app.textFields["rsh.value"].waitForExistence(timeout: 4)); shot("rs-09-height")
        app.buttons["rsh.next"].tap(); usleep(800_000)

        // one door on wall A: the wall on the plan, its distance, width and height
        XCTAssertTrue(app.buttons["rsh.opsDone"].waitForExistence(timeout: 4)); shot("rs-10-openings")
        app.buttons["rsh.op.door"].tap(); usleep(800_000); shot("rs-11-which-wall")
        let wallA = app.descendants(matching: .any).matching(identifier: "rsh.wall.A").firstMatch
        XCTAssertTrue(wallA.waitForExistence(timeout: 4))
        wallA.tap(); usleep(800_000); shot("rs-12-door-distance")
        flowType(app, "600")
        flowType(app, "900")
        flowType(app, "2100")
        sleep(1); shot("rs-13-door-added")
        XCTAssertTrue(app.buttons["rsh.opX"].exists)

        // the summary, then the room's editor
        app.buttons["rsh.opsDone"].tap(); usleep(900_000)
        XCTAssertTrue(app.buttons["rsh.open"].waitForExistence(timeout: 4)); shot("rs-14-summary")
        app.swipeUp(); usleep(500_000); shot("rs-15-summary-scrolled")
        app.buttons["rsh.open"].tap(); sleep(2)
        if app.buttons["tip.ok"].waitForExistence(timeout: 2) { app.buttons["tip.ok"].tap(); usleep(700_000) }
        XCTAssertTrue(app.buttons["ed.walls"].waitForExistence(timeout: 5)); shot("rs-16-editor")

        // the order card: "Joylashuv yo‘q" with "+ Qo‘shish"
        sleep(6)    // the "added" toast goes first
        for _ in 0..<6 where !app.buttons["home.new"].exists { backVisible(app) }
        XCTAssertTrue(app.descendants(matching: .any)["loc.add"].waitForExistence(timeout: 4)); shot("rs-17-card-location")
        app.descendants(matching: .any)["loc.add"].firstMatch.tap(); usleep(900_000)
        XCTAssertTrue(app.buttons["loc.get"].waitForExistence(timeout: 3)); shot("rs-18-location-sheet")
        app.buttons["sheet.close"].tap(); usleep(600_000)
    }
}
