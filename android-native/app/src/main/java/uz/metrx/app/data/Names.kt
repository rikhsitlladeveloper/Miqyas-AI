package uz.metrx.app.data

import uz.metrx.app.core.Lang
import uz.metrx.app.core.Strings
import java.util.Calendar

/* Names, counts and small numbers shown about projects and workspaces (prototype: dn, floorName, wsSuggest, wsCounts, pcStats). */

/**
 * A stored name: typed text as it is, "@key" names in the current language. "@key?w=300&a=12.5" fills the text's
 * values (the trades' calculator lines); a decimal point is shown as the language's mark.
 */
fun dn(s: String?, l: Lang): String = when {
    s == null -> ""
    s.startsWith("@") && '?' in s -> Strings.t(s.substring(1, s.indexOf('?')), l, keyVars(s.substringAfter('?'), l))
    s.startsWith("@") -> Strings.t(s.drop(1), l)
    else -> s
}

// a value "~key" is itself a strings key (a tile's look in the tiler's lines), shown in the language too
private fun keyVars(q: String, l: Lang): Map<String, Any?> = q.split('&').filter { '=' in it }
    .associate { it.substringBefore('=') to it.substringAfter('=').let { v -> if (v.startsWith("~")) Strings.t(v.drop(1), l) else if (l == Lang.EN) v else v.replace('.', ',') } }

/** The stored form of a text with values ("@key?w=300&a=12.5"), which [dn] shows in any language. */
fun keyName(key: String, vars: Map<String, Any>): String =
    "@" + key + if (vars.isEmpty()) "" else "?" + vars.entries.joinToString("&") { (k, v) -> k + "=" + v.toString().replace(",", "").replace(" ", "") }

fun floorName(w: Workspace, l: Lang): String = when {
    w.name == "@floor1" -> Strings.t("pr.floorName", l, mapOf("n" to 1))
    w.name.startsWith("@floor:") -> Strings.t("pr.floorName", l, mapOf("n" to w.name.removePrefix("@floor:")))
    else -> dn(w.name, l)
}

val WS_TYPES = listOf("floor" to "layers", "room" to "room", "bath" to "bath", "kitchen" to "kitchen", "balcony" to "balcony", "outdoor" to "tree", "other" to "folder")
fun wsIcon(type: String) = WS_TYPES.firstOrNull { it.first == type }?.second ?: "layers"

/** The name offered for a new workspace of this type: "2-qavat", "Hammom", "Hammom 2"…; never one already there (after a delete). */
fun wsSuggest(p: Project, type: String, l: Lang): String {
    val taken = p.floors.map { floorName(it, l) }.toSet()
    if (type == "floor") {
        var k = p.floors.count { it.type == "floor" } + 1
        while (Strings.t("pr.floorName", l, mapOf("n" to k)) in taken) k++
        return Strings.t("pr.floorName", l, mapOf("n" to k))
    }
    val base = Strings.t("ws.t.$type", l)
    val n = p.floors.count { val nm = floorName(it, l); nm == base || nm.startsWith("$base ") }
    if (n == 0 && base !in taken) return base
    var k = maxOf(2, n + 1)
    while ("$base $k" in taken) k++
    return "$base $k"
}

/** Stores a suggested name as a key, so it follows the language later; typed names stay as typed. */
fun wsStoreName(p: Project, nm: String, type: String, l: Lang): String {
    if (type == "floor") for (k in 1..2 * p.floors.size + 1) if (nm == Strings.t("pr.floorName", l, mapOf("n" to k))) return "@floor:$k"
    return if (nm == Strings.t("ws.t.$type", l)) "@ws.t.$type" else nm
}

/** "5 ta xona, 1 ta chizma, 2 ta surat" */
fun wsCounts(p: Project, w: Workspace, l: Lang): String {
    val rooms = p.rooms.count { it.floorId == w.id }
    fun c(k: String) = w.items.count { it.kind == k }
    return listOf(rooms to "ws.cRoom", c("drawing") to "ws.cDraw", c("photo") to "ws.cPhoto", c("note") to "ws.cNote")
        .filter { it.first > 0 }.joinToString(", ") { (n, k) -> Strings.t(k, l, mapOf("n" to n)) }
}

fun itemName(it: Item, l: Lang): String = if (it.kind == "note") dn(it.name, l).ifBlank { Strings.t("it.untitled", l) } else dn(it.name, l)

fun fmtDate(ts: Long): String {
    val c = Calendar.getInstance().apply { timeInMillis = ts }
    return "%02d.%02d.%d".format(c.get(Calendar.DAY_OF_MONTH), c.get(Calendar.MONTH) + 1, c.get(Calendar.YEAR))
}

/** Measurements needed and confirmed, net wall area and how many rooms it covers (prototype pcStats). */
data class ProjectStats(val need: Int, val conf: Int, val net: Long, val nets: Int, val total: Long)

fun stats(p: Project, snap: Boolean = true): ProjectStats {
    var need = 0; var conf = 0; var net = 0L; var nets = 0
    p.rooms.forEach { r ->
        val ks = uz.metrx.app.geo.stepKeys(r, snap); need += ks.size; conf += ks.count { r.dim(it).status == "conf" }
        uz.metrx.app.geo.areas(r, snap)?.net?.let { net += it; nets++ }
    }
    return ProjectStats(need, conf, net, nets, 0)
}

/** Net wall area of one workspace's rooms, and how many rooms have it. */
fun wsNet(p: Project, w: Workspace, snap: Boolean = true): Pair<Long, Int> {
    var net = 0L; var n = 0
    p.rooms.filter { it.floorId == w.id }.forEach { r -> uz.metrx.app.geo.areas(r, snap)?.net?.let { net += it; n++ } }
    return net to n
}

/** New project, as the prototype's saveProject(): no workspace yet, currency and report language from Profile. */
fun newProject(name: String, customer: String, phone: String, address: String, loc: Location?, currency: String, reportLang: String): Project {
    val now = System.currentTimeMillis()
    return Project(uid(), name, customer, phone, address, loc, currency, 0, reportLang, "measure", emptyList(), created = now, edited = now)
}
