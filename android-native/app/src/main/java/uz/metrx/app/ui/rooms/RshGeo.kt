package uz.metrx.app.ui.rooms

import uz.metrx.app.data.Pt
import uz.metrx.app.data.Room
import uz.metrx.app.geo.AskKind
import uz.metrx.app.geo.FreeSketch
import uz.metrx.app.geo.LenUnit
import uz.metrx.app.geo.OpField
import uz.metrx.app.geo.OpKind
import uz.metrx.app.geo.RoomShape
import uz.metrx.app.geo.ShapeError
import uz.metrx.app.geo.ShapeErrorCode
import uz.metrx.app.geo.ShapeGeo
import uz.metrx.app.geo.ShapeOpening
import uz.metrx.app.geo.ShapeSpec
import uz.metrx.app.geo.asks
import uz.metrx.app.geo.diagonalCorner
import uz.metrx.app.geo.diagonalError
import uz.metrx.app.geo.expectedDiagonal
import uz.metrx.app.geo.opFieldError
import uz.metrx.app.geo.shapeGeometry
import uz.metrx.app.geo.shapeToRoom
import uz.metrx.app.geo.shapeWallIds
import uz.metrx.app.geo.stepError
import uz.metrx.app.ui.App
import uz.metrx.app.ui.editor.english

/*
 * The flow's link to the room-shape geometry (geo/RoomShapes.kt, geo/ShapeRoom.kt): which sizes a shape asks, the plan
 * they make (as the picture draws it), the step errors in words, the openings' hints and checks, and the real Room.
 */

/** The cards, in order. */
val SHAPES: List<String> = RoomShape.entries.map { it.id }

/** How many sizes a card says it asks. */
fun askCount(k: String) = RoomShape.of(k)?.askCount ?: 0

/** One asked value: a wall ([edge]) or the bay's width ([dim] 0) or depth ([dim] 1); [def] the field's hint. */
data class RAsk(val edge: Int?, val dim: Int?, val def: Int)

/** The plan worked out from the values: the picture's model, the first error in words, the spread gap, the cut's angle, the letters. */
class RGeo(val geo: ShapeGeo?, val model: PlanModel, val err: String?, val fixed: Double, val angles: Map<Int, Int>, val letters: List<String>)

/** The draft's shape as the geometry takes it; a free card not drawn yet is a rectangle until it is. */
fun specOf(d: RshDraft): ShapeSpec {
    val sh = RoomShape.of(d.shape) ?: RoomShape.RECT
    val sk = d.sk
    if (sh == RoomShape.FREE && sk == null) return ShapeSpec(RoomShape.RECT)
    return ShapeSpec(sh, d.mir, d.rot, sk?.let { s -> FreeSketch(s.dirs.map { Pt(it.x, it.y) }, s.hints) })
}

fun rshAsks(d: RshDraft): List<RAsk> = asks(specOf(d)).map { a ->
    RAsk(a.wall, when (a.kind) { AskKind.BAY_WIDTH -> 0; AskKind.BAY_DEPTH -> 1; else -> null }, a.default)
}

private fun valsList(d: RshDraft, vals: Map<Int, Int>): List<Int?> = (0 until rshAsks(d).size).map { vals[it] }

private fun p2(p: Pt) = P2(p.x, p.y)

/** The plan for [vals] (the asked values typed so far; the others take their defaults). */
fun rshGeo(d: RshDraft, vals: Map<Int, Int>, app: App? = null): RGeo {
    val spec = specOf(d)
    val g = shapeGeometry(spec, valsList(d, vals))
    val model = PlanModel(
        pts = g.corners.map(::p2),
        edges = g.walls.map { PlanEdge(it.ask, it.len, it.bad, p2(it.from), p2(it.to)) },
        dims = g.guides.map { PlanDim(p2(it.a), p2(it.b), it.ask, if (it.ask == 3) "w" else "d", g.values.getOrNull(it.ask)?.toDouble() ?: 0.0) },
        gap = g.gap?.let { p2(g.corners.last()) to p2(g.corners.first()) },
        gapLen = g.gap ?: 0.0
    )
    return RGeo(g, model, g.error?.let { e -> app?.let { errText(it, d, e) } ?: e.code.name }, g.gapFixed,
        g.walls.mapNotNull { w -> w.angle?.let { w.index to it } }.toMap(), shapeWallIds(spec, g.walls.size))
}

/** What stops "Keyingi" on walls step [st] with [vals] (this step's value in), in words; null when it may go on. */
fun rshStepErr(app: App, d: RshDraft, vals: Map<Int, Int>, st: Int): String? =
    stepError(specOf(d), valsList(d, vals), st, editingOne = d.ret)?.let { errText(app, d, it) }

/** The free sketch's diagonal: the corner it goes to, the length the walls give, and what is wrong with [v]. */
fun rshDiagK(d: RshDraft) = diagonalCorner(specOf(d))
fun rshDiagLen(d: RshDraft) = shapeGeometry(specOf(d), valsList(d, d.vals)).let { if (it.corners.size > rshDiagK(d)) expectedDiagonal(it) else 3000.0 }
fun rshDiagErr(app: App, d: RshDraft, v: Int?): String? = diagonalError(specOf(d), valsList(d, d.vals), v)?.let { errText(app, d, it) }

private fun kindOf(k: String) = OpKind.entries.first { it.id == k }
private fun fieldOf(k: String) = when (k) { "dist" -> OpField.DIST; "w" -> OpField.WIDTH; "h" -> OpField.HEIGHT; else -> OpField.SILL }

/** The value an opening's field starts from on its wall (the default, shrunk to fit). */
fun rshOpHint(d: RshDraft, op: OpEdit): Int {
    val g = shapeGeometry(specOf(d), valsList(d, d.vals))
    if (op.wall !in g.walls.indices) return opFields(op.kind)[op.sub].third
    return uz.metrx.app.geo.opHint(g, d.height, kindOf(op.kind), op.wall, fieldOf(opFields(op.kind)[op.sub].first), op.vals["dist"] ?: 0, op.vals["w"] ?: 0, op.vals["h"] ?: 0)
}

/** What is wrong with [v] typed into the opening's field being asked, in words. */
fun rshOpErr(app: App, d: RshDraft, op: OpEdit, v: Int?): String? {
    val g = shapeGeometry(specOf(d), valsList(d, d.vals))
    val f = fieldOf(opFields(op.kind)[op.sub].first)
    return opFieldError(g, d.height, kindOf(op.kind), op.wall, f, v, op.vals["dist"] ?: 0, op.vals["w"] ?: 0, op.vals["h"] ?: 0)?.let { e ->
        if (e.code == ShapeErrorCode.OUT_OF_RANGE && f == OpField.HEIGHT) {
            val unit = app.rshUnit(d); val en = app.english()
            app.t("rsh.e.opH", "a" to lenWords(300, unit, en), "b" to lenWords(d.height, unit, en), "u" to app.t(unitKeyOf(unit)))
        } else errText(app, d, e)
    }
}

/** An error in the maker's words, lengths in the flow's unit. */
fun errText(app: App, d: RshDraft, e: ShapeError): String {
    val unit: LenUnit = app.rshUnit(d); val en = app.english()
    val u = app.t(unitKeyOf(unit))
    fun len(x: Double?) = lenWords(Math.round(x ?: 0.0).toInt(), unit, en) + " " + u
    val ids = shapeWallIds(specOf(d), shapeGeometry(specOf(d), valsList(d, d.vals)).walls.size)
    fun wl(i: Int?) = ids.getOrElse(i ?: 0) { "?" }
    fun signed(x: Double?) = (if ((x ?: 0.0) < 0) "−" else "") + len(kotlin.math.abs(x ?: 0.0))
    return when (e.code) {
        ShapeErrorCode.OUT_OF_RANGE -> app.t("rsh.e.enter", "r" to app.t("rsh.range", "a" to lenWords(Math.round(e.min ?: 0.0).toInt(), unit, en),
            "b" to lenWords(Math.round(e.limit ?: 0.0).toInt(), unit, en), "u" to u))
        ShapeErrorCode.CUT_D_NOT_SHORTER -> app.t("rsh.e.cutD", "v" to len(e.limit), "d" to wl(3), "a" to wl(0))
        ShapeErrorCode.CUT_B_NOT_SHORTER -> app.t("rsh.e.cutB", "v" to len(e.limit), "b" to wl(1), "e" to wl(4))
        ShapeErrorCode.CUT_NO_CUT -> app.t("rsh.e.cut", "a" to wl(0), "b" to wl(1), "d" to wl(3), "e" to wl(4))
        ShapeErrorCode.BAY_NOT_FIT -> app.t("rsh.e.bayFit", "v" to len(e.value), "l" to len(e.limit), "a" to wl(0), "g" to wl(6))
        ShapeErrorCode.BAY_TOO_DEEP -> app.t("rsh.e.bayDeep")
        ShapeErrorCode.NOT_CLOSED -> app.t("rsh.e.open", "v" to len(e.value))
        ShapeErrorCode.WALL_NEGATIVE -> app.t("rsh.e.neg", "w" to wl(e.wall), "v" to signed(e.value))
        ShapeErrorCode.WALLS_CROSS -> app.t("rsh.e.cross")
        ShapeErrorCode.DIAG_MISMATCH -> app.t("rsh.e.diag", "v" to len(e.limit))
        ShapeErrorCode.EMPTY -> app.t("rsh.e.num")
        ShapeErrorCode.OP_PAST_WALL -> app.t("rsh.e.long", "w" to wl(e.wall), "l" to len(e.limit))
        ShapeErrorCode.OP_NOT_FIT -> app.t("rsh.e.fit", "s" to len(e.value), "l" to len(e.limit))
        ShapeErrorCode.OP_ABOVE_CEILING -> app.t("rsh.e.sill", "s" to len(e.value), "l" to len(e.limit))
    }
}

/**
 * The room being made, for the openings step (room editor v2): the shape as it stands with the doors, windows and
 * points already placed kept on their walls (a wall that is gone takes its items with it).
 */
fun rshTmpRoom(d: RshDraft, snap: Boolean, app: App): Room? {
    val base = shapeToRoom(specOf(d), valsList(d, d.vals), d.height, "rsh-" + d.key, d.wid ?: "rsh", d.name, 0, d.diag, emptyList(), snap)?.room ?: return d.tmp
    val old = d.tmp ?: return base
    val P = uz.metrx.app.geo.outline(base, snap)
    val inner = old.inner.filter { uz.metrx.app.geo.pip(uz.metrx.app.geo.V2(it.x.toDouble(), it.y.toDouble()), P) }
    return app.clampItems(uz.metrx.app.geo.syncFaces(base.copy(openings = old.openings, points = old.points, thick = old.thick, inner = inner), snap))
}

/** The room the flow made, into the trade's fresh [base] room (its id, workspace, name and date kept). */
fun rshRoom(base: Room, d: RshDraft, snap: Boolean): Room {
    val ops = d.ops.map { ShapeOpening(kindOf(it.kind), it.wall, it.dist, it.w, it.h, it.sill) }
    return shapeToRoom(specOf(d), valsList(d, d.vals), d.height, base.id, base.floorId, base.name, base.created, d.diag, ops, snap)?.room ?: base
}
