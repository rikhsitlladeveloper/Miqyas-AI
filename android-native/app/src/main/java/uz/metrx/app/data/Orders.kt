package uz.metrx.app.data

import java.math.BigInteger
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/*
 * A furniture order's stages and money (furniture plan section 4): measured → designed → quote sent → approved with
 * a prepayment → in production → installed → paid in full. Money is whole numbers of the smallest unit, as in Money.kt.
 */

/** The agreed price (null until the order is approved), what was paid, and what is left (null without a price). */
data class OrderMoney(val agreed: BigInteger?, val paid: BigInteger, val left: BigInteger?)

fun orderMoney(p: Project): OrderMoney {
    val agreed = p.agreed.toBigIntegerOrNull()
    val paid = p.payments.fold(BigInteger.ZERO) { a, x -> a + (x.amount.toBigIntegerOrNull() ?: BigInteger.ZERO) }
    return OrderMoney(agreed, paid, agreed?.let { (it - paid).max(BigInteger.ZERO) })
}

/** Where the order is among [F_STAGES], 0 for anything unknown. */
fun fStage(p: Project): Int = F_STAGES.indexOf(p.stage).coerceAtLeast(0)

private const val APPROVED = 3
private const val INSTALLED = 5

/** What customers still owe on approved orders that are not paid yet, and on how many orders. */
fun owed(ps: List<Project>): Pair<BigInteger, Int> {
    var sum = BigInteger.ZERO; var n = 0
    ps.filter { it.isFurniture && !it.sample && fStage(it) in APPROVED..INSTALLED }.forEach { p ->
        val left = orderMoney(p).left ?: return@forEach
        if (left.signum() > 0) { sum += left; n++ }
    }
    return sum to n
}

/** An installed order with nothing left to pay becomes "paid". */
fun settle(p: Project): Project =
    if (fStage(p) == INSTALLED && orderMoney(p).left?.signum() == 0) p.copy(stage = "paid") else p

/** Approving: the agreed price, the prepayment as the first payment (when there is one), stage "approved". */
fun approve(p: Project, agreed: BigInteger, pre: BigInteger, now: Long): Project = p.copy(
    agreed = agreed.toString(), stage = "approved", approvedAt = now,
    payments = if (pre.signum() > 0) p.payments + Payment(uid(), pre.toString(), now, pre = true) else p.payments
)

/** The next stage; approving goes through [approve] instead, and "paid" only comes from the payments. */
fun nextStage(p: Project): Project {
    val i = fStage(p)
    if (i == APPROVED - 1 || i >= INSTALLED) return p
    return settle(p.copy(stage = F_STAGES[i + 1]))
}

/** One stage back, for a mistake; the price and the payments stay. */
fun prevStage(p: Project): Project = p.copy(stage = F_STAGES[(fStage(p) - 1).coerceAtLeast(0)])

fun addPayment(p: Project, amount: BigInteger, note: String, now: Long): Project =
    settle(p.copy(payments = p.payments + Payment(uid(), amount.toString(), now, note.trim())))

/** Removing a payment of a paid order puts it back to "installed" when something is left again. */
fun removePayment(p: Project, id: String): Project {
    val q = p.copy(payments = p.payments.filter { it.id != id })
    return if (q.stage == "paid" && (orderMoney(q).left?.signum() ?: 0) > 0) q.copy(stage = "installed") else q
}

/** Half the price, rounded half up: the usual prepayment. */
fun halfOf(v: BigInteger): BigInteger = (v + BigInteger.ONE).divide(BigInteger.valueOf(2))

/* ---------------- the install date (furniture orders UX, 20 Oct 2026) ---------------- */

/** [d] plus [n] working days: Monday to Saturday, Sunday off. */
fun addWorkDays(d: LocalDate, n: Int): LocalDate {
    var x = d; var left = n
    while (left > 0) { x = x.plusDays(1); if (x.dayOfWeek != DayOfWeek.SUNDAY) left-- }
    return x
}

fun dayOf(ms: Long, zone: ZoneId = ZoneId.systemDefault()): LocalDate = Instant.ofEpochMilli(ms).atZone(zone).toLocalDate()

/** When the order is to be installed: the date set by hand, else the approval day plus the Narx tab's making and
 * installing days; null until the order is approved. Older approved orders take the prepayment's day. */
fun installDate(p: Project, zone: ZoneId = ZoneId.systemDefault()): LocalDate? {
    if (p.install > 0) return dayOf(p.install, zone)
    val at = p.approvedAt.takeIf { it > 0 } ?: p.payments.firstOrNull { it.pre }?.ts?.takeIf { fStage(p) >= APPROVED } ?: return null
    return addWorkDays(dayOf(at, zone), p.fprice.days + p.fprice.inst)
}

/** Active orders with the soonest install first (late ones on top), the ones without a date after them, newest first. */
fun sortOrders(ps: List<Project>, zone: ZoneId = ZoneId.systemDefault()): List<Project> {
    val (dated, undated) = ps.partition { installDate(it, zone) != null && fStage(it) < INSTALLED }
    return dated.sortedBy { installDate(it, zone) } + undated.sortedByDescending { it.created }
}
