package uz.metrx.app.furniture

import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Opening
import uz.metrx.app.data.Project
import uz.metrx.app.data.Room
import uz.metrx.app.data.SitePoint

/** The three price options (PriceTiers.kt): what each swaps, their order, and the order's saved form. */
class PriceTiersTest {
    private val ws = Workshop()
    private val room = Room("r", "f", "Oshxona", dims = mapOf("A" to Dim(3400, "manual"), "B" to Dim(2800, "manual"), "H" to Dim(2700, "manual"), "T" to Dim(200, "default")),
        openings = listOf(Opening("w", "window", "A", 1200, 1250, 1000, 950), Opening("d", "door", "C", 800, 2050, 1300)),
        points = listOf(SitePoint("c", "cold", "A", 1600, 550), SitePoint("g", "gas", "B", 400, 1000)))
    private val site = akSite(room, { null })
    private fun kitchen(preset: String) = akPieces(akPlan(site, listOf("D", "A"), "L", AkApp(), preset, ws)!!, site, ws, listOf("Oshxona"))[0]

    @Test fun ekonomSwapsToLdspHplAndPlainHardware() {
        val f = kitchen("neo")      // ivory milled MDF enamel, gold knobs, onyx stone, tile, cornice
        val e = tierPiece(f, TIER_EKO)
        assertEquals("ldsp16w", e.mats.front)
        assertEquals("flat", e.look?.style); assertEquals("chrome", e.look?.hcol)
        assertEquals("wt38", e.mats.top)                  // the plain 38 mm HPL
        assertEquals("splash6", e.mats.splash)            // the MDF wall panel
        assertFalse(e.kx!!.cornice); assertFalse(e.kx!!.led)
        assertTrue(e.modules.none { it.soft })
        assertEquals("bar", handleType(e))                // knobs become the usual bar
        assertTrue(lookHardware(e, ws)["frontShaker"] == null)
        // the Gola profile goes, a wood decor stays (it is LDSP), the slim quartz back to 38 HPL
        val g = tierPiece(kitchen("gola"), TIER_EKO)
        assertEquals("", g.handle); assertEquals("ldsp16k", g.mats.front)
        val w = tierPiece(kitchen("wood"), TIER_EKO)
        assertEquals("wd_halifax", w.mats.front); assertEquals("ldsp16w", w.mats.frontUp)
        assertEquals("wt38", tierPiece(kitchen("twotone").let { it.copy(mats = it.mats.copy(top = "wt20d")) }, TIER_EKO).mats.top)
        // Standart is the piece as designed
        assertEquals(f, tierPiece(f, TIER_STD))
    }

    @Test fun premiumSwapsToEnamelOrGlossStoneBlumAndLed() {
        val m = tierPiece(kitchen("gola"), TIER_PRE)      // cashmere soft-touch matte, wood worktop
        assertEquals("en_cashmere", m.mats.front)
        assertEquals("wt20o", m.mats.top); assertEquals("spStoneO", m.mats.splash)
        assertTrue(m.kx!!.led); assertTrue(m.modules.all { it.soft })
        val gl = tierPiece(kitchen("twotone"), TIER_PRE)  // gloss white over graphite
        assertEquals("ag_graphite", gl.mats.front); assertEquals("ag_white", gl.mats.frontUp)
        assertEquals("wt20m", gl.mats.top); assertEquals("spStoneM", gl.mats.splash)
        // the Blum-type hinge and runner are what the usual kinds are priced at
        val hws = tierHws(HW_PRESETS, TIER_PRE)
        assertEquals("hingeBlum", usualHw(hws, "hingeSoft")?.id); assertEquals("runnerBlum", usualHw(hws, "runner")?.id)
        assertEquals("hingeSoft", usualHw(tierHws(HW_PRESETS, TIER_STD), "hingeSoft")?.id)
        assertEquals("runner", usualHw(HW_PRESETS, "runner")?.id)
        // the swapped materials are all in the workshop's lists
        listOf(m, gl).forEach { p -> listOfNotNull(p.mats.front, p.mats.frontUp, p.mats.top, p.mats.splash).forEach { id -> assertTrue(id, MAT_PRESETS.any { it.id == id }) } }
    }

    @Test fun ekonomCostsLessThanStandartLessThanPremium() {
        for (p in DESIGN_PRESETS) {
            val f = kitchen(p.id)
            for (mode in listOf("margin", "run", "fixed")) {
                val fp = FPrice(mode = mode, fixed = "40000000")
                val t = tierPrices(listOf(f), fp, ws, MAT_PRESETS, HW_PRESETS)
                assertEquals(TIERS, t.map { it.tier })
                assertTrue("${p.id} $mode cost ${t.map { it.cost }}", t[0].cost < t[1].cost && t[1].cost < t[2].cost)
                assertTrue("${p.id} $mode price ${t.map { it.price }}", t[0].price < t[1].price && t[1].price < t[2].price)
                // Standart is the order's own price
                assertEquals(priceOf(listOf(f), fp, ws, MAT_PRESETS, HW_PRESETS).price, t[1].price)
            }
        }
        // a wardrobe too: its fronts and hardware swap
        val ward = withPreset(pieceOf(fModel("h2")!!, emptyMap(), ws, "Shkaf"), "gloss", fresh = true, ws = ws)
        val t = tierPrices(listOf(ward), FPrice(), ws, MAT_PRESETS, HW_PRESETS)
        assertTrue(t.map { it.price }.toString(), t[0].price < t[1].price && t[1].price < t[2].price)
    }

    @Test fun whatEachOptionIsMadeOf() {
        val f = kitchen("twotone")
        assertEquals(listOf("pt.l.f", "pt.l.t", "pt.l.h", "pt.l.s", "pt.led"), tierWhat(f, TIER_EKO).map { it.first })
        assertEquals("pt.eko.f", tierWhat(f, TIER_EKO)[0].second)
        assertEquals("#" + f.mats.front, tierWhat(f, TIER_STD)[0].second)
        assertEquals("#" + f.mats.splash, tierWhat(f, TIER_STD)[3].second)
        assertEquals(listOf("pt.l.f", "pt.l.h", "pt.led"), tierWhat(f.copy(kind = "wardrobe"), TIER_PRE).map { it.first })
    }

    @Test fun theQuoteCarriesTheThreePricesOnlyWhenOn() {
        val p = Project("p", "QA auto kitchen", industry = "furniture", furniture = listOf(kitchen("twotone")))
        val base = uz.metrx.app.report.snapshotOf(p, uz.metrx.app.geo.LenUnit.M, "", "", uz.metrx.app.data.PdfParts())
        val off = uz.metrx.app.report.furnSnap(base, p, ws, MAT_PRESETS, HW_PRESETS)
        val on = uz.metrx.app.report.furnSnap(base, p.copy(tri = true), ws, MAT_PRESETS, HW_PRESETS)
        assertTrue(uz.metrx.app.report.tierLines(off).isEmpty())
        // the shared keys pt.eko, pt.std, pt.pre; Standart is the quote's total; the fingerprint does not change
        assertEquals(listOf("pt.eko", "pt.std", "pt.pre"), uz.metrx.app.report.tierLines(on).map { it.key })
        assertEquals(on.ftotal, uz.metrx.app.report.tierLines(on)[1].amount)
        assertEquals(uz.metrx.app.report.fingerprint(off), uz.metrx.app.report.fingerprint(on))
        assertEquals(off.flines, on.flines.filter { !it.key.startsWith("pt.") })
    }

    @Test fun theOrderSavesTheOptionOnlyWhenOn() {
        val js = Json { encodeDefaults = true; ignoreUnknownKeys = true }
        val p = Project("p", "Aliyevlar", industry = "furniture")
        val off = js.encodeToString(Project.serializer(), p)
        assertFalse(off.contains("\"tri\""))
        // an order saved before reads as before, and back
        assertEquals(p, js.decodeFromString(Project.serializer(), off))
        val on = js.encodeToString(Project.serializer(), p.copy(tri = true))
        assertTrue(on.contains("\"tri\":true"))
        assertTrue(js.decodeFromString(Project.serializer(), on).tri)
        val older = """{"id":"p","name":"Aliyevlar","industry":"furniture","furniture":[]}"""
        assertFalse(js.decodeFromString(Project.serializer(), older).tri)
        // a kitchen made by the auto kitchen saves and loads as itself
        val k = kitchen("dark")
        assertEquals(k, js.decodeFromString(Furniture.serializer(), js.encodeToString(Furniture.serializer(), k)))
    }
}
