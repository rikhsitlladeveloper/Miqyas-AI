import XCTest
@testable import METRX

/// The order location's "Yo‘l" links and coordinates (room-shapes spec §1), and that only a builder's PDF has the
/// location (Android MapLinksTest).
final class MapLinksTests: XCTestCase {
    private let lat = 41.3111
    private let lng = 69.2797

    func testCoordinatesHaveFiveDecimalsAndADot() {
        XCTAssertEqual(MapLinks.coords(lat, lng), "41.31110, 69.27970")
        XCTAssertEqual(MapLinks.c(-0.0000149), "-0.00001")
        XCTAssertEqual(MapLinks.coords(41.328456, 69.335174), "41.32846, 69.33517")
        XCTAssertEqual(MapLinks.googleWeb(lat, lng), "https://maps.google.com/?q=41.31110,69.27970")
    }

    func testAppLinksPutYandexLongitudeFirst() {
        XCTAssertEqual(MapLinks.yandexMaps(lat, lng), "yandexmaps://maps.yandex.ru/?pt=69.27970,41.31110&z=17")
        XCTAssertEqual(MapLinks.yandexNavi(lat, lng), "yandexnavi://build_route_on_map?lat_to=41.31110&lon_to=69.27970")
        XCTAssertEqual(MapLinks.googleApp(lat, lng), "comgooglemaps://?q=41.31110,69.27970&center=41.31110,69.27970&zoom=17")
        XCTAssertEqual(MapLinks.yandexWeb(lat, lng), "https://yandex.uz/maps/?pt=69.27970,41.31110&z=17")
    }

    func testAnInstalledAppGetsItsOwnLinkAMissingOneTheHttpsMap() {
        for a in MapLinks.App.allCases {
            XCTAssertEqual(MapLinks.open(a, lat, lng, installed: { _ in true }), MapLinks.appLink(a, lat, lng))
            XCTAssertEqual(MapLinks.open(a, lat, lng, installed: { _ in false }), MapLinks.webLink(a, lat, lng))
        }
        XCTAssertEqual(MapLinks.webLink(.yandexNavi, lat, lng), "https://yandex.uz/maps/?pt=69.27970,41.31110&z=17")
        // only the asked app's scheme counts
        let onlyNavi: (String) -> Bool = { $0 == "yandexnavi" }
        XCTAssertEqual(MapLinks.open(.yandexMaps, lat, lng, installed: onlyNavi), MapLinks.yandexWeb(lat, lng))
        XCTAssertEqual(MapLinks.open(.yandexNavi, lat, lng, installed: onlyNavi), MapLinks.yandexNavi(lat, lng))
    }

    func testOnlyABuildersReportCarriesTheLocation() {
        let l = Location(lat: lat, lng: lng, acc: 8, ts: 1)
        func snap(_ industry: String) -> Snap {
            var p = newProject("QA", "QA", "", "", l, "UZS", "uz")
            p.industry = industry
            return snapshotOf(p)
        }
        XCTAssertEqual(snap("build").location, l)
        for t in ["furniture", "tiler", "elec", "plumb", "win"] { XCTAssertNil(snap(t).location, t) }
    }
}
