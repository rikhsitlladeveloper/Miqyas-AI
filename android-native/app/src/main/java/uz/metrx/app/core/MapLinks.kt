package uz.metrx.app.core

import java.util.Locale

/**
 * The links of an order's "Yo‘l" sheet (room-shapes build spec §1): the pin in Yandex Maps, a route in Yandex Navigator,
 * Google Maps, and the coordinates to copy. An app that is not installed falls back to its https map link.
 * Pure, so the links are unit-tested; the screens only start them.
 */
object MapLinks {
    /** The map apps of the sheet, in its order, with their Android packages. */
    enum class App(val pkg: String) {
        YANDEX_MAPS("ru.yandex.yandexmaps"),
        YANDEX_NAVI("ru.yandex.yandexnavi"),
        GOOGLE_MAPS("com.google.android.apps.maps")
    }

    /** One coordinate with 5 decimals (about 1 m), always with a dot. */
    fun c(v: Double): String = String.format(Locale.ROOT, "%.5f", v)

    /** "41.31110, 69.27970": what the cards show and "Nusxa olish" copies. */
    fun coords(lat: Double, lng: Double): String = c(lat) + ", " + c(lng)

    fun yandexMaps(lat: Double, lng: Double) = "yandexmaps://maps.yandex.ru/?pt=${c(lng)},${c(lat)}&z=17"
    fun yandexNavi(lat: Double, lng: Double) = "yandexnavi://build_route_on_map?lat_to=${c(lat)}&lon_to=${c(lng)}"
    fun geo(lat: Double, lng: Double) = "geo:${c(lat)},${c(lng)}?q=${c(lat)},${c(lng)}"
    fun yandexWeb(lat: Double, lng: Double) = "https://yandex.uz/maps/?pt=${c(lng)},${c(lat)}&z=17"
    fun googleWeb(lat: Double, lng: Double) = "https://maps.google.com/?q=${c(lat)},${c(lng)}"

    /** The app's own link: Yandex note longitude first, Google and geo: latitude first. */
    fun appLink(a: App, lat: Double, lng: Double): String = when (a) {
        App.YANDEX_MAPS -> yandexMaps(lat, lng)
        App.YANDEX_NAVI -> yandexNavi(lat, lng)
        App.GOOGLE_MAPS -> geo(lat, lng)
    }

    /** The https map link used when the app is missing (both Yandex apps open Yandex's map in the browser). */
    fun webLink(a: App, lat: Double, lng: Double): String = when (a) {
        App.YANDEX_MAPS, App.YANDEX_NAVI -> yandexWeb(lat, lng)
        App.GOOGLE_MAPS -> googleWeb(lat, lng)
    }

    /** What to open for [a]: its own link (to its package) when [installed], else the https fallback (no package). */
    data class Open(val uri: String, val pkg: String?)

    fun open(a: App, lat: Double, lng: Double, installed: (String) -> Boolean): Open =
        if (installed(a.pkg)) Open(appLink(a, lat, lng), a.pkg) else Open(webLink(a, lat, lng), null)
}
