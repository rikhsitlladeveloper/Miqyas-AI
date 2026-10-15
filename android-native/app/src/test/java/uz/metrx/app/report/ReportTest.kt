package uz.metrx.app.report

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test
import uz.metrx.app.data.Dim
import uz.metrx.app.data.Estimate
import uz.metrx.app.data.Row
import uz.metrx.app.data.Room
import uz.metrx.app.data.Snap
import uz.metrx.app.data.SnapRoom
import uz.metrx.app.data.View3D
import java.math.BigInteger

/** What makes a draft differ from an issued quote, and a quote's total (prototype fingerprint, totals). */
class ReportTest {
    private val room = Room("r", "f", "Xona", dims = mapOf("A" to Dim(5000, "manual"), "B" to Dim(4000, "manual"), "H" to Dim(3000, "manual"), "T" to Dim(200, "default")))
    private val sn = Snap("Uy", builderName = "Sanjar", rooms = listOf(SnapRoom(room, "1-qavat")),
        estimate = Estimate(listOf(Row("a", "Paint", "@u.can", "12", "50000"), Row("b", "Floor", "@u.m2", "22", "120000")), listOf(Row("c", "Labour", amount = "1000000"))))

    @Test fun sameContentSameFingerprint() = assertEquals(fingerprint(sn), fingerprint(sn.copy(rooms = listOf(SnapRoom(room.copy(), "1-qavat")))))

    @Test fun changesThatMakeANewQuote() {
        val f = fingerprint(sn)
        assertNotEquals(f, fingerprint(sn.copy(estimate = sn.estimate.copy(materials = sn.estimate.materials.map { if (it.id == "a") it.copy(qty = "14") else it }))))
        assertNotEquals(f, fingerprint(sn.copy(lang = "ru")))
        assertNotEquals(f, fingerprint(sn.copy(rooms = listOf(SnapRoom(room.copy(dims = room.dims + ("A" to Dim(5100, "manual"))), "1-qavat")))))
        assertNotEquals(f, fingerprint(sn.copy(rooms = listOf(SnapRoom(room.copy(views = listOf(View3D("v", "views/v.jpg", 1))), "1-qavat")))))
        assertNotEquals(f, fingerprint(sn.copy(builderName = "Bobur")))
    }

    @Test fun picturesMovingForAQuoteDoNotCount() {
        // a quote keeps copies of its 3D pictures under another path; only which views are in it counts
        val a = sn.copy(rooms = listOf(SnapRoom(room.copy(views = listOf(View3D("v", "views/v.jpg", 1))), "1-qavat")))
        val b = sn.copy(rooms = listOf(SnapRoom(room.copy(views = listOf(View3D("v", "quotes/p-1/v.jpg", 1))), "1-qavat")))
        assertEquals(fingerprint(a), fingerprint(b))
    }

    @Test fun reportExtras() {
        // notes chosen for the report, drawings with marks and photos; an empty drawing is left out
        val now = 1L
        val its = listOf(
            uz.metrx.app.data.Item("n", "note", "Eslatma", rep = true, created = now),
            uz.metrx.app.data.Item("d0", "drawing", "Bo‘sh", created = now + 1),
            uz.metrx.app.data.Item("d1", "drawing", "Chizma", created = now + 2, els = listOf(uz.metrx.app.data.MkEl("x", "pen", listOf(listOf(1f, 1f))))),
            uz.metrx.app.data.Item("p", "photo", "Surat", created = now + 3, src = "photos/p.jpg", H = 750, caption = "Deraza"),
            uz.metrx.app.data.Item("n2", "note", "Yashirin", created = now + 4)
        )
        val p = uz.metrx.app.data.Project("pj", "Uy", floors = listOf(uz.metrx.app.data.Workspace("w", "1-qavat", items = its)))
        val ex = snapshotOf(p, uz.metrx.app.geo.LenUnit.M, "Sanjar", "901234567", uz.metrx.app.data.PdfParts()).extras
        assertEquals(listOf("n", "d1", "p"), ex.map { it.id })
        assertEquals("Deraza", ex.last().caption)
    }

    @Test fun quoteTotal() = assertEquals(BigInteger.valueOf(4_240_000), snapTotal(sn))

    @Test fun fileName() = assertEquals("Yangi_uy_Taklif_1.pdf", pdfName("Yangi uy", "Taklif №1"))
}
