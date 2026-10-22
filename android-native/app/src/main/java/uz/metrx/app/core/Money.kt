package uz.metrx.app.core

import uz.metrx.app.data.Project
import java.math.BigInteger

/*
 * Money and quantities as the prototype keeps them: typed text stored in a canonical form ("150", "12.5"),
 * read back as whole numbers of the smallest unit (BigInt there, BigInteger here), so no sum is ever rounded
 * by floating point. Quantities have 3 decimals; prices and amounts the project's precision (0 for so'm).
 */

sealed interface Dec {
    data class Ok(val v: BigInteger) : Dec
    data object Empty : Dec
    data object Format : Dec
    data object Negative : Dec
    /** More decimals than allowed; [n] = how many are allowed (0: a whole number). */
    data class Precision(val n: Int) : Dec
}

private val SPACES = Regex("[\\s  ]")
private val SHAPE = Regex("^-?\\d*([.,]\\d*)?$")

/** prototype parseDec: "4,25", "4.25", "120 000"; [maxDec] digits after the mark at most. */
fun parseDec(str: String?, maxDec: Int): Dec {
    var s = (str ?: "").replace(SPACES, "")
    if (s.isEmpty()) return Dec.Empty
    if (!SHAPE.matches(s) || Regex("^-?[.,]?$").matches(s)) return Dec.Format
    if (s.startsWith("-")) return Dec.Negative
    s = s.replace(',', '.')
    val parts = s.split('.'); val i = parts[0]; val f = parts.getOrElse(1) { "" }
    if (f.length > maxDec) return Dec.Precision(maxDec)
    return Dec.Ok(BigInteger((i.ifEmpty { "0" }) + f.padEnd(maxDec, '0')))
}

fun Dec.value(): BigInteger? = (this as? Dec.Ok)?.v

/** prototype canonOf: what is stored ("120 000" → "120000", "4,50" → "4.50", "007" → "7", "5." → "5", ",5" → "0.5"). */
fun canonOf(str: String): String = str.replace(SPACES, "").replace(',', '.').replace(Regex("^0+(?=\\d)"), "").replace(Regex("^\\.(?=\\d)"), "0.")
    .replace(Regex("\\.$"), "")

private fun dec(en: Boolean) = if (en) "." else ","
private fun group(s: String, en: Boolean) = s.replace(Regex("\\B(?=(\\d{3})+(?!\\d))"), if (en) "," else " ")

/** prototype moneyStr: 18000000 → "18 000 000"; with precision 2, 1850 → "18,50". */
fun moneyStr(big: BigInteger, precision: Int, en: Boolean): String {
    val neg = big.signum() < 0
    val s = big.abs().toString().padStart(precision + 1, '0')
    val ip = s.substring(0, s.length - precision); val fp = if (precision > 0) s.takeLast(precision) else ""
    return (if (neg) "−" else "") + group(ip, en) + (if (precision > 0) dec(en) + fp else "")
}

/** prototype fmtNumStr: a stored quantity for display ("1500.5" → "1 500,5"). */
fun fmtNumStr(canon: String?, en: Boolean): String {
    if (canon.isNullOrEmpty()) return ""
    val parts = canon.split('.')
    return group(parts[0], en) + (if (parts.size > 1 && parts[1].isNotEmpty()) dec(en) + parts[1] else "")
}

/** Quantity × price, rounded half up to the price's precision (prototype lineTotal: quantities have 3 decimals). */
fun lineTotal(qty: String?, price: String?, precision: Int): BigInteger {
    val q = parseDec(qty, 3).value() ?: return BigInteger.ZERO
    val p = parseDec(price, precision).value() ?: return BigInteger.ZERO
    return (q * p + BigInteger.valueOf(500)) / BigInteger.valueOf(1000)
}

data class Totals(val m: BigInteger, val l: BigInteger) { val g: BigInteger get() = m + l }

/** Materials, labour and the grand total of a project (prototype totals). */
fun totals(p: Project): Totals {
    var m = BigInteger.ZERO; var l = BigInteger.ZERO
    p.estimate.materials.forEach { m += lineTotal(it.qty, it.price, p.precision) }
    p.estimate.labor.forEach { r -> parseDec(r.amount, p.precision).value()?.let { l += it } }
    return Totals(m, l)
}

/** "so‘m" for UZS, the code for other currencies (prototype curSuffix). */
fun curSuffix(c: String, l: Lang) = if (c == "UZS") Strings.t("cur.UZS", l) else c

/** A row that still lacks its quantity or price (materials) or its amount (labour). */
fun rowsMissing(p: Project) = p.estimate.materials.count { it.qty.isBlank() || it.price.isBlank() } + p.estimate.labor.count { it.amount.isBlank() }

/**
 * The short estimate figure on project cards (prototype pcMoney): "—" when nothing, "19,5" + "mln" for a million so'm
 * and more, else the full number and the currency code. Returns the number and its small unit.
 */
fun shortMoney(p: Project, g: BigInteger, en: Boolean, mln: String): Pair<String, String?> {
    if (g.signum() == 0) return "—" to null
    val v = g.toBigDecimal().movePointLeft(p.precision).toDouble()
    if (p.currency == "UZS" && v >= 1e6) {
        val s = "%.2f".format(java.util.Locale.ROOT, v / 1e6).replace(Regex("\\.?0+$"), "").replace(".", dec(en))
        return s to mln
    }
    return moneyStr(g, p.precision, en) to p.currency
}
