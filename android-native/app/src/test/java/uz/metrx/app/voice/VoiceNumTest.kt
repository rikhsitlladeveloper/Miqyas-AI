package uz.metrx.app.voice

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Test
import java.io.File

/** The spoken sizes shared with the iPhone app (design/ux-upgrades/voice-cases.json): both apps must pass all of them. */
class VoiceNumTest {
    private fun cases(): String {
        // the repo's shared file when the tests run inside the repo, else the copy in the test resources
        val shared = listOf(File("../../design/ux-upgrades/voice-cases.json"), File("../design/ux-upgrades/voice-cases.json")).firstOrNull { it.exists() }
        return shared?.readText() ?: javaClass.classLoader!!.getResource("voice-cases.json")!!.readText()
    }

    @Test
    fun sharedCases() {
        val a = Json.parseToJsonElement(cases()).jsonArray
        val bad = ArrayList<String>()
        a.forEach { e ->
            val c = e.jsonObject
            val want = c["mm"].let { if (it == null || it is JsonNull) null else it.jsonPrimitive.int }
            val text = c.getValue("text").jsonPrimitive.content
            val lang = c.getValue("lang").jsonPrimitive.content
            val got = VoiceNum.toMm(text, lang)
            if (got != want) bad += "$lang «$text»: $got, expected $want"
        }
        assertEquals(bad.joinToString("\n"), 0, bad.size)
        assertEquals(24, a.size)
    }

    @Test
    fun moreWays() {
        assertEquals(2500, VoiceNum.toMm("ikki yarim metr"))
        assertEquals(3400, VoiceNum.toMm("uch ming toʻrt yuz"))
        assertEquals(3400, VoiceNum.toMm("3 400"))
        assertEquals(500, VoiceNum.toMm("полметра", "ru"))
        assertEquals(1200, VoiceNum.toMm("сто двадцать сантиметров", "ru"))
        assertEquals(3400, VoiceNum.toMm("уч минг тўрт юз"))
        assertEquals(null, VoiceNum.toMm("metr"))
        assertEquals(null, VoiceNum.toMm(""))
        assertEquals(null, VoiceNum.toMm("[unk]"))
    }
}
