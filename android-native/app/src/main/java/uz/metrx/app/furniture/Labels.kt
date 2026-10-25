package uz.metrx.app.furniture

/*
 * Part labels (bazis ideas, 23 Oct 2026; Advanced only): one sticker for every part of an order, 3 × 8 to an A4 sheet
 * of 70 × 37 mm stickers: the part's name and size, which edges are banded, the material, the order and an optional QR
 * code with the part's id. Pure Kotlin, unit-tested (BazisTest); the pages are drawn in report/LabelPages.kt.
 */

/** Stickers across and down an A4 sheet. */
const val LABEL_COLS = 3
const val LABEL_ROWS = 8
const val LABELS_PER_PAGE = LABEL_COLS * LABEL_ROWS

/**
 * One sticker: [n] its number in the order (from 1), the part's name key [key], [mod] the module it belongs to (its
 * label, "Sh1/2"), [piece] the piece's name, finished [L] × [W], its [bands], material id [mat], [grain] kept upright.
 */
data class PartLabel(val n: Int, val key: String, val mod: String, val piece: String, val L: Int, val W: Int, val bands: Bands, val mat: String, val grain: Boolean)

/** A sticker per part of [fs] (each of a line's pieces its own), piece by piece and module by module. */
fun labelsOf(fs: List<Furniture>, ws: Workshop): List<PartLabel> {
    val out = ArrayList<PartLabel>()
    fs.forEach { f ->
        partsWithMat(f, ws).forEach { (p, mat) ->
            repeat(p.qty) { out += PartLabel(out.size + 1, p.key, p.mod, f.name, p.L, p.W, p.bands, mat, p.grain) }
        }
    }
    return out
}

/** How many A4 sheets [n] stickers take. */
fun labelPages(n: Int) = (n + LABELS_PER_PAGE - 1) / LABELS_PER_PAGE

/** Where sticker [i] (from 0) goes: its page, column and row. */
fun labelSlot(i: Int): Triple<Int, Int, Int> = Triple(i / LABELS_PER_PAGE, i % LABELS_PER_PAGE % LABEL_COLS, i % LABELS_PER_PAGE / LABEL_COLS)

/** The id a sticker's QR code carries: the order's short id and the sticker's number ("MX-4f2a9c-017"). */
fun labelId(order: String, n: Int) = "MX-" + order.filter { it.isLetterOrDigit() }.take(6) + "-" + n.toString().padStart(3, '0')
