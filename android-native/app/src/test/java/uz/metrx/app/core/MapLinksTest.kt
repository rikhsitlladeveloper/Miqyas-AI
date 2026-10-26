package uz.metrx.app.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import uz.metrx.app.data.Location
import uz.metrx.app.data.PdfParts
import uz.metrx.app.data.newProject
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.report.snapshotOf

/** The order location's "Yo‘l" links and coordinates (room-shapes spec §1), and that only a builder's PDF has the location. */
class MapLinksTest {
    private val lat = 41.3111
    private val lng = 69.2797

    @Test fun coordinatesHaveFiveDecimalsAndADot() {
        assertEquals("41.31110, 69.27970", MapLinks.coords(lat, lng))
        assertEquals("-0.00001", MapLinks.c(-0.0000149))
        assertEquals("41.32846, 69.33517", MapLinks.coords(41.328456, 69.335174))
        // a comma-decimal locale on the phone changes nothing
        val was = java.util.Locale.getDefault()
        try {
            java.util.Locale.setDefault(java.util.Locale("ru", "RU"))
            assertEquals("41.31110, 69.27970", MapLinks.coords(lat, lng))
            assertEquals("https://maps.google.com/?q=41.31110,69.27970", MapLinks.googleWeb(lat, lng))
        } finally { java.util.Locale.setDefault(was) }
    }

    @Test fun appLinksPutYandexLongitudeFirst() {
        assertEquals("yandexmaps://maps.yandex.ru/?pt=69.27970,41.31110&z=17", MapLinks.yandexMaps(lat, lng))
        assertEquals("yandexnavi://build_route_on_map?lat_to=41.31110&lon_to=69.27970", MapLinks.yandexNavi(lat, lng))
        assertEquals("geo:41.31110,69.27970?q=41.31110,69.27970", MapLinks.geo(lat, lng))
        assertEquals("https://yandex.uz/maps/?pt=69.27970,41.31110&z=17", MapLinks.yandexWeb(lat, lng))
        assertEquals("https://maps.google.com/?q=41.31110,69.27970", MapLinks.googleWeb(lat, lng))
    }

    @Test fun anInstalledAppGetsItsOwnLinkAMissingOneTheHttpsMap() {
        val all = { _: String -> true }
        val none = { _: String -> false }
        assertEquals(MapLinks.Open(MapLinks.yandexMaps(lat, lng), "ru.yandex.yandexmaps"), MapLinks.open(MapLinks.App.YANDEX_MAPS, lat, lng, all))
        assertEquals(MapLinks.Open(MapLinks.yandexNavi(lat, lng), "ru.yandex.yandexnavi"), MapLinks.open(MapLinks.App.YANDEX_NAVI, lat, lng, all))
        assertEquals(MapLinks.Open(MapLinks.geo(lat, lng), "com.google.android.apps.maps"), MapLinks.open(MapLinks.App.GOOGLE_MAPS, lat, lng, all))
        assertEquals(MapLinks.Open("https://yandex.uz/maps/?pt=69.27970,41.31110&z=17", null), MapLinks.open(MapLinks.App.YANDEX_MAPS, lat, lng, none))
        assertEquals(MapLinks.Open("https://yandex.uz/maps/?pt=69.27970,41.31110&z=17", null), MapLinks.open(MapLinks.App.YANDEX_NAVI, lat, lng, none))
        assertEquals(MapLinks.Open("https://maps.google.com/?q=41.31110,69.27970", null), MapLinks.open(MapLinks.App.GOOGLE_MAPS, lat, lng, none))
        // only the asked app's package counts
        val onlyNavi = { p: String -> p == "ru.yandex.yandexnavi" }
        assertNull(MapLinks.open(MapLinks.App.YANDEX_MAPS, lat, lng, onlyNavi).pkg)
        assertEquals("ru.yandex.yandexnavi", MapLinks.open(MapLinks.App.YANDEX_NAVI, lat, lng, onlyNavi).pkg)
    }

    @Test fun onlyABuildersReportCarriesTheLocation() {
        val l = Location(lat, lng, 8, 1L)
        fun snap(industry: String) = snapshotOf(newProject("QA", "QA", "", "", l, "UZS", "uz").copy(industry = industry), LenUnit.M, "", "", PdfParts())
        assertEquals(l, snap("build").location)
        listOf("furniture", "tiler", "elec", "plumb", "win").forEach { assertNull(it, snap(it).location) }
    }
}
