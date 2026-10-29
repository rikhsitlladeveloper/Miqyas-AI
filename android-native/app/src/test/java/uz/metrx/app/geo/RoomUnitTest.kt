package uz.metrx.app.geo

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.BeforeClass
import org.junit.Test
import uz.metrx.app.core.Lang
import uz.metrx.app.core.Strings
import java.io.File

/**
 * 1.0.2: the shared room editor, the room flow, its openings and the inner walls in the role's unit (a builder's m or
 * cm, a furniture maker's mm), the lengths kept in mm: what is shown, what the keypad takes, the texts' "mm".
 */
class RoomUnitTest {
    companion object {
        @BeforeClass @JvmStatic fun texts() {
            val f = listOf("src/main/assets/strings.json", "app/src/main/assets/strings.json").map(::File).first { it.exists() }
            Json.parseToJsonElement(f.readText()).jsonObject.forEach { (k, v) -> Strings.put(k, v.jsonArray.map { it.jsonPrimitive.content }.toTypedArray()) }
        }
    }

    @After fun back() = RoomUnit.set(LenUnit.MM, false)

    @Test fun lengthsAreShownInTheUnit() {
        assertEquals("3 400", RoomUnit.text(3400, LenUnit.MM, false))
        assertEquals("3,40", RoomUnit.text(3400, LenUnit.M, false))
        assertEquals("3.40", RoomUnit.text(3400, LenUnit.M, true))
        assertEquals("3,405", RoomUnit.text(3405, LenUnit.M, false))
        assertEquals("340", RoomUnit.text(3400, LenUnit.CM, false))
        assertEquals("340,5", RoomUnit.text(3405, LenUnit.CM, false))
        // the limits, converted
        assertEquals("999,999", RoomUnit.text(WALL_MAX, LenUnit.M, false)); assertEquals("0,30", RoomUnit.text(WALL_MIN, LenUnit.M, false))
        assertEquals("30,00", RoomUnit.text(30_000, LenUnit.M, false))
        RoomUnit.set(LenUnit.M, false); assertEquals("2,70", RoomUnit.text(2700))
    }

    @Test fun whatIsTypedIsKeptInMm() {
        assertEquals(3400, RoomUnit.parse("3,4", LenUnit.M)); assertEquals(3400, RoomUnit.parse("3.40", LenUnit.M))
        assertEquals(3405, RoomUnit.parse("3,405", LenUnit.M)); assertNull(RoomUnit.parse("3,4055", LenUnit.M))
        assertEquals(3405, RoomUnit.parse("340,5", LenUnit.CM)); assertEquals(3400, RoomUnit.parse("3400", LenUnit.MM))
        assertEquals(0, RoomUnit.parse("0", LenUnit.M)); assertEquals(WALL_MAX, RoomUnit.parse("999,999", LenUnit.M))
        assertNull(RoomUnit.parse("", LenUnit.M)); assertNull(RoomUnit.parse("3,4", LenUnit.MM))
        // the 30 m note and the limits look at the mm
        assertEquals(true, bigWall(RoomUnit.parse("35", LenUnit.M))); assertEquals(false, bigWall(RoomUnit.parse("29,9", LenUnit.M)))
        // a value put in for the maker (the laser, the voice) as the keypad shows it
        assertEquals("3,4", RoomUnit.field(3400, LenUnit.M, false)); assertEquals("3.405", RoomUnit.field(3405, LenUnit.M, true))
        assertEquals("340", RoomUnit.field(3400, LenUnit.CM, false)); assertEquals("3400", RoomUnit.field(3400, LenUnit.MM, false))
        listOf(1, 300, 2705, 3400, 30_000, WALL_MAX).forEach { mm ->
            listOf(LenUnit.M, LenUnit.CM, LenUnit.MM).forEach { u -> assertEquals("$mm $u", mm, RoomUnit.parse(RoomUnit.field(mm, u, false), u)) }
        }
    }

    @Test fun theKeypadTakesDecimalsInMetresAndCentimetres() {
        fun type(u: LenUnit, keys: String): String? { var v = ""; keys.forEach { c -> v = RoomUnit.typed(v, c.toString(), u) ?: return null }; return v }
        assertEquals("3,45", type(LenUnit.M, "3,45")); assertEquals("0,5", type(LenUnit.M, ",5"))
        assertNull(type(LenUnit.M, "3,4,5")); assertNull(type(LenUnit.M, "3,4567")); assertNull(type(LenUnit.M, "1000"))
        assertEquals("999,999", type(LenUnit.M, "999,999"))
        assertEquals("340,5", type(LenUnit.CM, "340,5")); assertNull(type(LenUnit.CM, "340,55"))
        // mm: whole numbers only, 6 digits
        assertNull(type(LenUnit.MM, "34,5")); assertEquals("999999", type(LenUnit.MM, "999999")); assertNull(type(LenUnit.MM, "1000000"))
        assertEquals("5", type(LenUnit.MM, "05"))
        assertEquals("3,", RoomUnit.typed("3,4", "bk", LenUnit.M)); assertEquals("3.", RoomUnit.typed("3", ".", LenUnit.M))
    }

    @Test fun theEditorsTextsSayTheirUnit() {
        // mm: as written
        RoomUnit.set(LenUnit.MM, false)
        assertEquals("Devor A: 3 400 → 3 500 mm", Strings.t("re.wallCh", Lang.UZ, mapOf("w" to "A", "a" to "3 400", "b" to "3 500")))
        assertEquals("Devor 300 mm dan kam bo‘lmaydi.", Strings.t("re.e.wallMin", Lang.UZ))
        // m: the word and the lengths written in the text follow
        RoomUnit.set(LenUnit.M, false)
        assertEquals("Devor A: 3,40 → 3,50 m", Strings.t("re.wallCh", Lang.UZ, mapOf("w" to "A", "a" to RoomUnit.text(3400), "b" to RoomUnit.text(3500))))
        assertEquals("Devor 0,30 m dan kam bo‘lmaydi.", Strings.t("re.e.wallMin", Lang.UZ))
        assertEquals("Стена — до 999,999 м.", Strings.t("re.e.wallMax", Lang.RU))
        assertEquals("От 0,30 до 999,999 м", Strings.t("re.wallRange", Lang.RU))
        assertEquals("Стена A · 0,12 м · стандарт 0,10", Strings.t("iw.thSub", Lang.RU, mapOf("n" to "Стена A", "v" to RoomUnit.text(120))))
        assertEquals("Wall A · 3.40 · up to 999.999", Strings.t("re.lenSub", Lang.EN, mapOf("w" to "A", "v" to RoomUnit.text(3400, LenUnit.M, true))))
        assertEquals("Lazer o‘lchadi: 2,70 m", Strings.t("re.laserGot", Lang.UZ, mapOf("v" to RoomUnit.text(2700))))
        // cm
        RoomUnit.set(LenUnit.CM, false)
        assertEquals("Стена не короче 30 см.", Strings.t("re.e.wallMin", Lang.RU))
        // other texts never change
        RoomUnit.set(LenUnit.M, false)
        assertEquals("O‘tish 900 mm — tor", Strings.t("fp.pl.pass", Lang.UZ, mapOf("v" to "900")))
        assertEquals("Burish 90°", Strings.t("fp.pl.turn", Lang.UZ))
        assertEquals("90° o‘ngga", Strings.t("re.rotR", Lang.UZ))
    }
}
