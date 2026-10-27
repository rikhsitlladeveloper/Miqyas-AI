package uz.metrx.app.furniture

import java.math.BigInteger

/*
 * "3 xil narx", three price options for the customer (Joylan ideas, founder 26 Oct 2026; the approved mockup
 * scratchpad joylan-ideas/mockup.html tierO / priceOf), Advanced only. The same drawing, the materials swapped:
 *  - Ekonom: LDSP fronts (a wood decor stays: it is LDSP), flat, the plain 38 mm HPL worktop "wt38" (a wood one stays),
 *    the usual hinges and runners, the MDF wall panel "splash6", no LED, no cornice, bar handles for knobs and Gola;
 *  - Standart: as designed;
 *  - Premium: MDF enamel fronts, or acrylic gloss where the design is gloss; an artificial stone (quartz) worktop and a
 *    stone backsplash to match it; Blum-type soft-close hinges and runners; LED.
 * Each option is priced by the workshop's own Costing on the swapped copy (its boards, hardware and labour prices).
 * The swaps are the iPhone app's too (agreed 26 Oct 2026), but for Premium's backsplash (its own stone presets
 * spStone*, by the m²) and hardware (the Blum-type items hingeBlum and runnerBlum).
 * Pure Kotlin, unit-tested (PriceTiersTest).
 */

const val TIER_EKO = "eko"
const val TIER_STD = "std"
const val TIER_PRE = "pre"

/** The three options, cheapest first. */
val TIERS = listOf(TIER_EKO, TIER_STD, TIER_PRE)

/** The LDSP board of a front colour (the workshop's three presets): light, beige or dark. */
private fun ldspFor(colour: String): String = when (colour) {
    "white", "cream", "ivory", "lgrey" -> "ldsp16w"
    "cashmere", "olive" -> "ldsp16k"
    else -> "ldsp18a"
}

/** The colour an older plain board stands for, so Premium can give it in enamel. */
private fun colourOfPlain(id: String): String? = when (id) { "ldsp16w", "ldsp16mr", "mdf18" -> "white"; "ldsp16k" -> "cashmere"; "ldsp18a" -> "graphite"; else -> null }

private val WOODS = LOOK_WOODS.map { it.key }.toSet()

/** Ekonom's front: a wood decor as it is (LDSP), a colour as its LDSP. */
private fun ekoFront(id: String): String {
    val c = colourOf(id) ?: return if (id == "mdf18") "ldsp16w" else id
    return if (c in WOODS) "wd_$c" else ldspFor(c)
}

/** Premium's front: a wood decor as it is; a colour in acrylic gloss when the design is gloss, else MDF enamel. */
private fun preFront(id: String, gloss: Boolean): String {
    val c = colourOf(id) ?: colourOfPlain(id) ?: return id
    return if (c in WOODS) "wd_$c" else if (gloss) "ag_$c" else "en_$c"
}

/** A piece [f] with its materials swapped for price option [tier] (Standart: as it is). */
fun tierPiece(f: Furniture, tier: String): Furniture {
    if (tier == TIER_STD) return f
    val kitchen = f.kind == "kitchen"
    val look = f.look
    val gloss = look?.finish == "gloss" || f.mats.front.startsWith("ag_") || f.mats.frontUp?.startsWith("ag_") == true
    return if (tier == TIER_EKO) {
        var g = f.copy(
            mats = f.mats.copy(front = ekoFront(f.mats.front), frontUp = f.mats.frontUp?.let(::ekoFront),
                // the plain 38 mm HPL worktop (a wood one stays), the MDF wall panel
                top = if (kitchen || f.mats.top != null) (if (worktopKind(f.mats.top) == "wood") f.mats.top else "wt38") else null,
                splash = if (kitchen) "splash6" else f.mats.splash),
            kx = f.kx?.copy(led = false, cornice = false),
            look = look?.copy(style = "flat", finish = "matte", hcol = if (look.hcol == "gold" || look.hcol == "brass") "chrome" else look.hcol,
                crown = if (look.crown == "cornice") "" else look.crown, led = false, fglass = false),
            // the usual hinges: no soft close
            modules = f.modules.map { m -> m.copy(soft = false, sections = m.sections.map { it.copy(soft = null) }) }
        )
        // knobs and the Gola profile become the usual bar handle
        if (handleType(g) == "gola" || handleType(g) == "knob") g = withHandleType(g, "bar")
        mapOwnFronts(g, ::ekoFront)
    } else mapOwnFronts(run {
        // the stone: a stone worktop keeps its decor; a wood or plain one becomes onyx, the dark plain one dark stone
        val top = worktopOf(f)
        val decor = when (worktopKind(top)) { "stone", "slim" -> worktopDecor(top); "wood" -> "onyx"; else -> if (top == "wt38") "dark" else "onyx" }
        f.copy(
            mats = f.mats.copy(front = preFront(f.mats.front, gloss), frontUp = f.mats.frontUp?.let { preFront(it, gloss) },
                top = if (kitchen) worktopFor("slim", decor) else f.mats.top,
                splash = if (kitchen) stoneSplash(decor) else f.mats.splash),
            kx = if (kitchen) (f.kx ?: KExtras()).copy(led = true, splash = f.kx?.splash?.takeIf { it > 0 } ?: K_SPLASH) else f.kx,
            look = look?.copy(finish = if (gloss) "gloss" else (look.finish.ifEmpty { "matte" }), led = if (f.kind == "wardrobe" && f.type != "gorka") true else look.led)
                ?: if (f.kind == "wardrobe" && f.type != "gorka") Look(led = true) else null,
            // Blum-type soft close on every door
            modules = f.modules.map { m -> m.copy(soft = true, sections = m.sections.map { it.copy(soft = null) }) }
        )
    }) { preFront(it, gloss) }
}

/** The artificial stone backsplash of a decor (Decors.kt spStone*). */
fun stoneSplash(decor: String): String = when (decor) { "onyx" -> "spStoneO"; "dark" -> "spStoneD"; else -> "spStoneM" }

/**
 * The workshop's hardware list as price option [tier] buys it: Premium's hinges and runners at its Blum-type items
 * ("hingeBlum", "runnerBlum": the usual kind's last item is the one priced, Costing.kt usualHw); the others as they are.
 */
fun tierHws(hws: List<Hw>, tier: String): List<Hw> {
    if (tier != TIER_PRE) return hws
    val more = listOfNotNull(
        hws.firstOrNull { it.id == "hingeBlum" }?.copy(kind = "hingeSoft"),
        hws.firstOrNull { it.id == "runnerBlum" }?.copy(kind = "runner")
    )
    return hws + more
}

/** One option's cost to the workshop and its price for the customer. */
data class TierPrice(val tier: String, val cost: BigInteger, val price: BigInteger)

/**
 * The three options of [fs] (their furniture with pieces), Ekonom, Standart, Premium. Standart is the order's own price;
 * priced by the margin, each option is its own price ([priceOf]); priced by the running metre or by hand, the option
 * scales Standart's price by its cost against Standart's.
 */
fun tierPrices(fs: List<Furniture>, fp: FPrice, ws: Workshop, mats: List<Mat>, hws: List<Hw>, rems: List<Remnant> = emptyList()): List<TierPrice> {
    val built = fs.filter { it.modules.isNotEmpty() }
    val std = priceOf(built, fp, ws, mats, hws, rems)
    return TIERS.map { t ->
        if (t == TIER_STD) return@map TierPrice(t, std.cost.total, std.price)
        val tf = built.map { tierPiece(it, t) }
        val th = tierHws(hws, t)
        if (fp.mode == "margin") priceOf(tf, fp, ws, mats, th, rems).let { TierPrice(t, it.cost.total, it.price) }
        else {
            val c = costOf(tf, ws, mats, th, rems = rems).total
            val sc = std.cost.total
            TierPrice(t, c, if (sc.signum() == 0) std.price else java.math.BigDecimal(std.price).multiply(java.math.BigDecimal(c)).divide(java.math.BigDecimal(sc), 0, java.math.RoundingMode.HALF_UP).toBigInteger())
        }
    }
}

/**
 * What option [tier] is made of, line by line (fronts "f", worktop "t", hardware "h", backsplash "s", LED "l"): the
 * line's strings key pt.l.<line> (LED: pt.led) and its value, a strings key, or a material id after "#" (Standart: [f]'s own, the
 * order's first piece). A piece without a worktop has no worktop or backsplash line.
 */
fun tierWhat(f: Furniture?, tier: String, kitchen: Boolean = f?.kind == "kitchen"): List<Pair<String, String>> {
    val lines = if (kitchen) listOf("f", "t", "h", "s", "l") else listOf("f", "h", "l")
    return lines.map { k ->
        (if (k == "l") "pt.led" else "pt.l.$k") to when {
            k == "h" && (tier != TIER_STD || f == null) -> "pt.hw.$tier"
            tier != TIER_STD || f == null -> "pt.$tier.$k"
            k == "f" -> "#" + f.mats.front
            k == "t" -> "#" + worktopOf(f)
            k == "h" -> if (f.modules.any { it.soft }) "pt.hw.std" else "pt.hw.eko"
            k == "s" -> f.mats.splash?.let { "#$it" } ?: if ((f.kx?.splash ?: 0) > 0) "#splash6" else "pt.std.sNone"
            else -> if (f.kx?.led == true || f.look?.led == true) "pt.std.lOn" else "pt.std.lOff"
        }
    }
}
