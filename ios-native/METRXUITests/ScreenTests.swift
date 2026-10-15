import XCTest

/// Walks the app's screens on the simulator and saves a picture of each (CI uploads them for review).
final class ScreenTests: XCTestCase {
    private var dir: URL? { ProcessInfo.processInfo.environment["SHOTS"].map { URL(fileURLWithPath: $0) } }

    func shot(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        if let dir { try? png.write(to: dir.appendingPathComponent(name + ".png")) }
        let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png"); a.name = name; a.lifetime = .keepAlways; add(a)
    }

    func testLaunch() {
        let app = XCUIApplication()
        app.launch()
        sleep(2)
        shot("00-launch")
    }
}
