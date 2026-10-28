import SwiftUI
import Observation

/*
 * The room editor v2's state and actions (room-editor mockup v2, approved 28 Oct 2026), shared by the room-shape
 * flow's openings step (Rooms/ReOpsStep.swift) and the one room editor of every trade (Rooms/ReEditor.swift): what is
 * selected, the armed icon, the style window and its size steps, a finger's drag, the views' zoom, the tool row's
 * options, the history with "Ortga qaytarish", and every change made to the room.
 */

/// What is selected: a wall or an item (door, window, point) by id.
/// What is selected: a wall (or an inner face, by its key), an item, or an inner wall piece (room-editor mockup v3).
enum ReSel: Equatable { case wall(String), item(String), piece(String) }

/// Where the room comes from and goes back to: the room-shape draft (the openings step) or the saved project (the
/// editor). industry: the order's trade (the icon row's order, the main button).
struct ReHost {
    let pid: String
    let industry: String
    let room: () -> Room?
    let put: (Room) -> Void
}

/// The style window and its size steps (mockup S.pk): a new item's ghost on its wall (mode "new"), or a placed item's
/// type ("retype") or sizes ("resize"); phase "style" or "size"; v the sizes so far; input the size step's text.
struct RePk: Equatable {
    var mode: String
    var how: String
    var kind: String
    var wall: String
    var centre: Int
    var it: ReItem
    var orig: ReItem? = nil
    var phase: String
    var style: String = ""
    var v: ReVals = [:]
    var step = 0
    var note = ""
    var input = ""
    var fresh = true
    var again = false
    /// A point dropped on the wall's front view keeps the height it was dropped at.
    var ph0: Int? = nil
}

/// A finger's drag on the drawing: sliding an item along its wall ("slide"), an opening's edge on the front view
/// ("edge" l, r, t or b), panning or pinching the view. snap: the room when it began; grab: where along the item it
/// was taken.
struct ReLive {
    var mode: String
    var id = ""
    var edge = ""
    var snap: Room? = nil
    var grab: CGFloat = 0
    var hgrab: CGFloat = 0
    var cam0 = ReCam()
    var changed = false
    var longPress = false
}

/// A number typed for a size outside the style window (a distance pill, Uzunlik, Qalinlik, Balandlik…): its title,
/// the value now, the range and what to do with it.
struct ReKp {
    let title: String
    let cur: Int
    let lo: Int
    let hi: Int
    var big = false
    let apply: (Int) -> Void
}

@Observable
final class ReState: RshFieldHost {
    static var map: [String: ReState] = [:]
    static func of(_ key: String) -> ReState { if let s = map[key] { return s }; let s = ReState(); map[key] = s; return s }

    var sel: ReSel? = nil
    var arm: String? = nil
    var pk: RePk? = nil
    /// The room while a finger drags (shown instead of the saved one) and the drag.
    var preview: Room? = nil
    var live: ReLive? = nil
    /// An icon dragged from the row: its kind, the finger (in the page's "re" space), the ghost on a wall and its magnet.
    var tileKind: String? = nil
    var tilePt: CGPoint = .zero
    var ghost: ReItem? = nil
    var mag: String? = nil
    var magId: String? = nil
    /// The editor's view (plan, front, 3d), the last 2D one, the wall the front view shows, each view's zoom.
    var view = "plan"
    var last2d = "plan"
    var fw = "A"
    var cams: [String: ReCam] = [:]
    /// The tool whose options replace the slider (nil: the tools).
    var strip: String? = nil
    var dimLen = true
    var dimChain = false
    var dimArea = false
    /// The openings step's floating card folded to one line (kept for the next selection).
    var cardMin = false
    /// The hand animation: stops at the first item; "?" plays it twice more (coachRuns > 0).
    var coachStop = false
    var coachRuns = 0
    var coachT0 = Date()
    /// The "N ta belgi" list.
    var list = false
    var kp: ReKp? = nil
    var kpText = ""
    /// The history: the room before each change and what the change was.
    var past: [(room: Room, msg: String)] = []
    var future: [(room: Room, msg: String)] = []
    /// "Yana shu": the last style and sizes of each kind in this flow.
    var last: [String: (style: String, v: ReVals)] = [:]
    /// The size field's voice, flash and laser (RshFieldHost).
    var heard: (before: String, words: String)? = nil
    var flash = 0
    var busy = false
    /// The openings step's plan moved up so the selected item stays above the floating card.
    var pan: CGFloat = 0
    /// The page's frames in its "re" space: the drawing, the first icon of the row (for the hand animation).
    var canvas: CGRect = .zero
    var tile0: CGRect = .zero

    /// Inner walls (room-editor mockup v3): the "Devor qo‘shish" window open, the piece just added (dashed until it
    /// is moved), what a dragged piece touches ("o<wall>", "p<piece>").
    var iwWin = false
    var newPiece: String? = nil
    var iwGlow: Set<String> = []

    func cam(_ v: String) -> ReCam { cams[v] ?? ReCam() }
    var selItem: String? { if case .item(let id)? = sel { return id }; return nil }
    var selWall: String? { if case .wall(let id)? = sel { return id }; return nil }
    var selPiece: String? { if case .piece(let id)? = sel { return id }; return nil }

    /// The room shown: the drag's preview, else the saved one.
    func shown(_ h: ReHost) -> Room? { preview ?? h.room() }

    func reset() {
        sel = nil; arm = nil; pk = nil; preview = nil; live = nil; tileKind = nil; ghost = nil; mag = nil; strip = nil; kp = nil; list = false
        iwWin = false; newPiece = nil; iwGlow = []
    }
}

/* ---------------- words ---------------- */

private var reUnit: LenUnit { AppSettings.shared.unit }
/// A length in the app's unit, without the unit ("3 400" or "3,4").
func reLen(_ mm: Int) -> String { lenWords(mm, reUnit) }
/// … with the unit.
func reLenU(_ mm: Int) -> String { lenWords(mm, reUnit) + " " + unitWord(reUnit) }
func reKindName(_ k: String) -> String { tr("re.k." + k) }
func reStyleName(_ k: String, _ s: String) -> String { tr("st." + k + "." + reStyle(k, s).id) }
func reItemName(_ it: ReItem) -> String { reKindName(it.kind) + " · " + reStyleName(it.kind, it.style) }

/// "800 × 2 100 · tokcha 900", "eshik 700 × 2 100 + deraza 1 200 × 1 400", "eni 640 · h 600" (mockup sizeLine).
func reSizeLine(_ it: ReItem) -> String {
    if it.isOpening {
        if it.isBalcony { return tr("re.szBal", ["dw": reLen(it.dw), "h": reLen(it.h), "ww": reLen(it.w - it.dw), "wh": reLen(it.wh), "a": reLen(it.dw), "b": reLen(it.h), "c": reLen(it.w - it.dw), "d": reLen(it.wh)]) }
        var s = reLen(it.w) + " × " + reLen(it.h)
        if it.kind == "window" { s += it.style == "pano" ? " · " + tr("re.fromFloor") : " · " + tr("re.sill", ["v": reLen(it.sill)]) }
        return s
    }
    return (it.pw > 0 ? tr("re.pwV", ["v": reLen(it.pw)]) + " · " : "") + tr("re.phV", ["v": reLen(it.ph)])
}

/// A style card's line: its note and standard sizes (mockup cardLine).
func reCardLine(_ k: String, _ st: ReStyle, _ roomH: Int) -> String {
    let v = reStd(k, st.id, roomH)
    var s: String
    if (k == "door" || k == "window") && st.id == "balcony" { s = tr("re.balLine", ["d": reLen(v["dw"] ?? 0), "w": reLen(v["ww"] ?? 0), "a": reLen(v["dw"] ?? 0), "b": reLen(v["ww"] ?? 0)]) }
    else if k == "door" || k == "window" { s = reLen(v["w"] ?? 0) + " × " + (st.v["h"] == RE_CEIL ? tr("re.toCeil") : reLen(v["h"] ?? 0)) }
    else { s = (v["pw"].map { tr("re.pwV", ["v": reLen($0)]) + " · " } ?? "") + tr("re.phV", ["v": reLen(v["ph"] ?? 0)]) }
    if k == "window", let sl = v["sill"] { s += " · " + tr("re.sill", ["v": reLen(sl)]) }
    if k == "window" && st.id == "pano" { s += " · " + tr("re.sill", ["v": "0"]) }
    return (st.hasD ? tr("st." + k + "." + st.id + ".d") + " · " : "") + s
}

/// What is wrong with a size, in words.
func reErrText(_ e: ReErr, wall: String) -> String {
    var vars: [String: Any] = ["w": reWL(wall)]
    for (k, v) in e.vars { vars[k] = reLen(v) }
    vars["u"] = unitWord(reUnit)
    // the Android texts' names for the same values (its text wins in the shared strings)
    if let v = vars["v"] { vars["x"] = v }
    if let c = vars["c"] { vars["r"] = c }
    return tr("re.e." + e.code, vars)
}

/// A Tekshiruv problem in words.
func reIssueText(_ q: ReIssue) -> String {
    // an inner wall in a door's swing or doorway (room-editor mockup v3 iwIssues)
    if q.code.hasPrefix("iw.") { return tr("iw.i." + q.code.dropFirst(3), ["n": iwName(q.kinds.first ?? "straight"), "w": reWL(q.wall)]) }
    var vars: [String: Any] = ["w": reWL(q.wall), "a": q.kinds.first.map(reKindName) ?? "", "b": q.kinds.count > 1 ? reKindName(q.kinds[1]).lowercased() : ""]
    for (k, v) in q.vars { vars[k] = reLen(v) }
    vars["u"] = unitWord(reUnit)
    // the Android texts' names for the same words and values
    vars["k"] = vars["a"]; vars["o"] = vars["b"]
    if let c = vars["c"] { vars["r"] = c }
    return tr("re.i." + q.code, vars)
}

/* ---------------- the actions ---------------- */

extension ReState {
    /// A change to the room with its message: kept for Undo, said in a toast with "Ortga qaytarish". False when the
    /// change was refused (it returned a reason, shown as a warning) or changed nothing.
    @discardableResult
    func commit(_ app: AppModel, _ h: ReHost, _ msg: String, haptic: Bool = true, _ change: (inout Room) -> String?) -> Bool {
        guard let before = h.room() else { return false }
        var r = before
        if let why = change(&r) { warn(app, why); return false }
        if r == before { return false }
        past.append((before, msg)); if past.count > 60 { past.removeFirst() }
        future = []
        h.put(r)
        fixSel(h)
        if haptic { Haptic.confirm() }
        sayUndo(app, h, msg)
        return true
    }

    private func sayUndo(_ app: AppModel, _ h: ReHost, _ msg: String) {
        app.toast = ToastMsg(text: msg, kind: .ok, action: tr("ux.undo"), onAction: { [weak self] in self?.undo(app, h) })
    }

    func warn(_ app: AppModel, _ text: String) {
        Haptic.warn()
        app.toast = ToastMsg(text: text, kind: .error)
    }

    func undo(_ app: AppModel, _ h: ReHost) {
        guard let e = past.popLast(), let now = h.room() else { return }
        future.append((now, e.msg))
        h.put(e.room)
        fixSel(h)
        Haptic.tick()
        app.toast = ToastMsg(text: tr("re.undone", ["m": e.msg]), kind: .info, action: tr("re.redo"), onAction: { [weak self] in self?.redo(app, h) })
    }

    func redo(_ app: AppModel, _ h: ReHost) {
        guard let e = future.popLast(), let now = h.room() else { return }
        past.append((now, e.msg))
        h.put(e.room)
        fixSel(h)
        Haptic.tick()
        app.toast = ToastMsg(text: tr("re.redone", ["m": e.msg]), kind: .info)
    }

    /// A selection whose item or wall is gone is dropped.
    func fixSel(_ h: ReHost) {
        guard let r = h.room() else { sel = nil; return }
        let g = reGeo(r)
        switch sel {
        case .item(let id)?: if reFind(r, id) == nil { sel = nil }
        case .wall(let id)?: if g.wall(id) == nil { sel = nil }
        case .piece(let id)?: if !r.inner.contains(where: { $0.id == id }) { sel = nil }
        default: break
        }
        if g.wall(fw) == nil { fw = g.walls.first?.id ?? "A" }
    }

    /* selection */

    func select(_ id: String, _ h: ReHost) {
        if let r = h.room(), r.inner.contains(where: { $0.id == id }) { selectPiece(id, h); return }
        guard let r = h.room(), let it = reFind(r, id) else { return }
        sel = .item(id); arm = nil; fw = it.wall
        if let s = strip, !reToolIds(self, h).contains(s) { strip = nil }
        Haptic.tick()
    }
    func selectWall(_ id: String, _ h: ReHost, toggle: Bool = false) {
        if toggle && sel == .wall(id) { deselect(); return }
        sel = .wall(id); fw = id
        if let s = strip, !reToolIds(self, h).contains(s) { strip = nil }
        Haptic.tick()
    }
    func deselect() { sel = nil; strip = nil; arm = nil }

    /* placing: a tapped icon, a wall or chip, a drop → the style window */

    /// An icon of the row tapped: with a wall selected it goes in its middle; else it is armed (or disarmed).
    func tileTap(_ kind: String, _ app: AppModel, _ h: ReHost) {
        if let w = selWall, let r = h.room() { placeAt(kind, wall: w, centre: reGeo(r).len(w) / 2, how: "chip", app, h); return }
        arm = arm == kind ? nil : kind
        sel = nil
        Haptic.tick()
    }

    /// A new item of kind on wall at centre: its ghost goes on the wall and the style window opens.
    func placeAt(_ kind: String, wall: String, centre: Int, how: String, ph: Int? = nil, _ app: AppModel, _ h: ReHost) {
        guard let r = h.room() else { return }
        let g = reGeo(r)
        let L = g.len(wall)
        var it = reNewItem(kind, wall: wall, centre: centre, wallL: L, roomH: g.H)
        if it.isOpening {
            let others = reItems(r)
            if let fs = reFreeSpot(it, others, L) { it.dist = fs }
        } else if let ph { it.ph = ph }
        arm = nil; ghost = nil; mag = nil; tileKind = nil
        pk = RePk(mode: "new", how: how, kind: kind, wall: wall, centre: it.isOpening ? it.dist + it.w / 2 : it.dist, it: it, phase: "style", ph0: ph)
        Haptic.tick()
    }

    /// "Turi" (retype) or "O‘lcham" (resize) of the selected item: the same window, its place kept.
    func pickFor(_ mode: String, _ h: ReHost) {
        guard let id = selItem, let r = h.room(), let it = reFind(r, id) else { return }
        var p = RePk(mode: mode, how: "", kind: it.kind, wall: it.wall, centre: it.isOpening ? it.dist + it.w / 2 : it.dist, it: it, orig: it,
                     phase: mode == "retype" ? "style" : "size", style: it.style, v: reVals(it))
        p.input = ""; p.fresh = true
        pk = p
        if mode == "resize" { stepInto(0, h) }
        Haptic.tick()
    }

    /// The ghost or the item as the window's choices so far make it.
    func pkItem(_ h: ReHost) -> ReItem? {
        guard let p = pk, let r = h.room() else { return nil }
        if p.style.isEmpty { return p.it }
        return reApply(p.it, p.style, p.v, wallL: reGeo(r).len(p.wall), centre: p.centre)
    }

    /// A style card tapped: its standard sizes (or the item's own when it keeps its style), then the first size.
    func pkStyle(_ id: String, _ h: ReHost) {
        guard var p = pk, let r = h.room() else { return }
        let g = reGeo(r)
        p.style = id
        if p.mode != "new", let o = p.orig, o.style == id { p.v = reVals(o) }
        else {
            p.v = reStd(p.kind, id, g.H)
            if let ph = p.ph0, p.v["ph"] != nil { p.v["ph"] = ph }
        }
        p.phase = "size"; p.step = 0; p.note = ""; p.again = false
        pk = p
        stepInto(0, h)
        Haptic.tick()
    }

    /// Opens size step i: its value shown for the maker, replaced by the first key.
    func stepInto(_ i: Int, _ h: ReHost) {
        guard var p = pk else { return }
        let steps = reSteps(p.kind, p.style)
        p.step = max(0, min(i, steps.count - 1))
        let f = steps[p.step]
        p.input = p.v[f].map { rshFieldText($0, reUnit) } ?? ""
        p.fresh = !p.input.isEmpty
        heard = nil
        pk = p
    }

    /// The size being asked now.
    func pkField() -> String? {
        guard let p = pk, p.phase == "size" else { return nil }
        let st = reSteps(p.kind, p.style)
        return st[min(p.step, st.count - 1)]
    }

    /// What is typed (or a chip, the laser, the voice) into the size being asked.
    func pkSet(_ mm: Int, typed: String? = nil) {
        guard var p = pk, let f = pkField() else { return }
        p.v[f] = mm
        p.input = typed ?? rshFieldText(mm, reUnit)
        p.fresh = false
        pk = p
    }

    func pkText(_ t: String) {
        guard var p = pk, let f = pkField() else { return }
        p.input = t; p.fresh = false; p.note = ""
        if let v = rshParse(t, reUnit, zeroOk: f == "sill" || f == "ph") { p.v[f] = v }
        heard = nil
        pk = p
    }

    /// The asked size's problem, in words, or nil.
    func pkErr(_ h: ReHost) -> String? {
        guard let p = pk, let f = pkField(), let r = h.room() else { return nil }
        let g = reGeo(r)
        if p.input.isEmpty && !p.fresh { return tr("re.e.empty") }
        if !p.fresh, rshParse(p.input, reUnit, zeroOk: f == "sill" || f == "ph") == nil { return tr("re.e.empty") }
        return reFieldErr(p.kind, p.style, p.v, f, wallL: g.len(p.wall), roomH: g.H).map { reErrText($0, wall: p.wall) }
    }

    func pkNext(_ app: AppModel, _ h: ReHost) {
        guard let p = pk else { return }
        if let e = pkErr(h) { warn(app, e); return }
        let n = reSteps(p.kind, p.style).count
        if p.step < n - 1 { stepInto(p.step + 1, h); Haptic.tick() } else { pkFinish(app, h) }
    }

    func pkBack(_ h: ReHost) {
        guard var p = pk else { return }
        if p.phase == "size" && p.step > 0 { stepInto(p.step - 1, h); return }
        p.phase = "style"
        if p.mode == "resize" { p.mode = "retype" }
        p.note = ""
        pk = p
    }

    /// "Standart": the remaining sizes take the style's standard, then it is placed (a wrong one goes back to its step).
    func pkStd(_ app: AppModel, _ h: ReHost) {
        guard var p = pk, let r = h.room() else { return }
        let steps = reSteps(p.kind, p.style), sv = reStd(p.kind, p.style, reGeo(r).H)
        for j in (p.step + 1)..<max(p.step + 1, steps.count) { p.v[steps[j]] = sv[steps[j]] }
        pk = p
        pkFinish(app, h)
    }

    /// "Yana shu": the last style and sizes of this kind, at once.
    func pkAgain(_ app: AppModel, _ h: ReHost) {
        guard var p = pk, let l = last[p.kind] else { return }
        p.style = l.style; p.v = l.v; p.again = true; p.phase = "size"
        pk = p
        pkFinish(app, h)
    }

    func pkCancel() { pk = nil; Haptic.tick() }

    /// Places the new item (moved to the nearest free place when it overlaps another), or saves the new type or sizes.
    func pkFinish(_ app: AppModel, _ h: ReHost) {
        guard let p = pk, let r = h.room() else { return }
        let g = reGeo(r), L = g.len(p.wall)
        if let e = reCheckAll(p.kind, p.style, p.v, wallL: L, roomH: g.H) {
            var q = p
            q.phase = "size"
            pk = q
            stepInto(e.step, h)
            warn(app, reErrText(e.err, wall: p.wall))
            return
        }
        last[p.kind] = (p.style, p.v)
        var it = reApply(p.it, p.style, p.v, wallL: L, centre: p.centre)
        let others = reItems(r).filter { $0.id != it.id }
        var moved = false
        if it.isOpening && others.contains(where: { reOverlap(it, $0) }), let fs = reFreeSpot(it, others, L) { it.dist = fs; moved = true }
        pk = nil
        let d = reDists(it, L)
        if p.mode == "new" {
            let msg = tr("re.m.placed", ["n": reItemName(it), "w": reWL(it.wall), "l": reLen(d.l), "r": reLen(d.r)]) + (moved ? " · " + tr("re.m.moved") : "")
            let id = it.id
            if commit(app, h, msg, { rePut(&$0, it); return nil }) {
                sel = .item(id); fw = it.wall; strip = nil
                coachStop = true; coachRuns = 0
            }
            return
        }
        let msg = reItemName(it) + " · " + reSizeLine(it)
        commit(app, h, msg) { rePut(&$0, it); return nil }
    }

    /* the selected item */

    func delSel(_ app: AppModel, _ h: ReHost) {
        guard let id = selItem, let r = h.room(), let it = reFind(r, id) else { return }
        if commit(app, h, tr("re.m.deleted", ["n": reKindName(it.kind)]), { reRemove(&$0, id); return nil }) { sel = nil; strip = nil }
    }

    func dupSel(_ app: AppModel, _ h: ReHost) {
        guard let id = selItem, let r = h.room(), let it = reFind(r, id) else { return }
        let L = reGeo(r).len(it.wall)
        var cp = it
        cp.id = uid()
        if it.isOpening {
            var ok: Int? = nil
            for d in [it.dist + it.w + 150, it.dist - it.w - 150] where ok == nil {
                cp.dist = d
                if d >= 0 && d + cp.w <= L && !reItems(r).contains(where: { reOverlap(cp, $0) }) { ok = d }
            }
            guard let ok else { warn(app, tr("re.m.noCopy", ["w": reWL(it.wall)])); return }
            cp.dist = ok
        } else { cp.dist = it.dist + 250 <= L ? it.dist + 250 : max(0, it.dist - 250) }
        let nid = cp.id
        if commit(app, h, tr("re.m.copied", ["n": reKindName(it.kind), "v": reLen(cp.dist)]), { rePut(&$0, cp); return nil }) { sel = .item(nid) }
    }

    /// Surish: by a step ("-100" … "100"), or to the start ("s"), the middle ("c") or the end ("e").
    func moveSel(_ a: String, _ app: AppModel, _ h: ReHost) {
        guard let id = selItem, let r = h.room(), var it = reFind(r, id) else { return }
        let L = reGeo(r).len(it.wall), hi = max(0, L - it.along)
        let v: Int
        switch a {
        case "s": v = 0
        case "e": v = hi
        case "c": v = hi / 2
        default: v = reClamp(it.dist + (Int(a) ?? 0), 0, hi)
        }
        if v == it.dist { warn(app, tr("re.m.noMove")); return }
        it.dist = v
        let x = it
        commit(app, h, tr("re.m.moved2", ["n": reKindName(it.kind), "l": reLen(v), "r": reLen(hi - v)])) { rePut(&$0, x); return nil }
    }

    /// Sets the selected item's distance to its start corner (dl) or end corner (dr) from a typed value.
    func setDist(_ which: String, _ mm: Int, _ app: AppModel, _ h: ReHost) {
        guard let id = selItem, let r = h.room(), var it = reFind(r, id) else { return }
        let g = reGeo(r), L = g.len(it.wall)
        let d = which == "dl" ? mm : L - it.along - mm
        it.dist = reClamp(d, 0, max(0, L - it.along))
        let x = it, corner = which == "dl" ? g.prev(it.wall) : g.next(it.wall)
        commit(app, h, tr("re.m.dist", ["n": reKindName(it.kind), "c": corner, "v": reLen(mm)])) { rePut(&$0, x); return nil }
    }

    /// One size of the selected item from an editor tool: w, h, sill, thr, ph, sw (a swing side as text in s).
    func setSize(_ key: String, _ v: Int, s: String = "", _ app: AppModel, _ h: ReHost) {
        guard let id = selItem, let r = h.room(), var it = reFind(r, id) else { return }
        let g = reGeo(r), L = g.len(it.wall)
        let name = reKindName(it.kind)
        switch key {
        case "w":
            if v > L { warn(app, reErrText(ReErr(code: "wide", vars: ["v": v, "l": L]), wall: it.wall)); return }
            if it.isBalcony && v < it.dw + 300 { warn(app, tr("re.e.balMin", ["v": reLen(it.dw + 300), "u": unitWord(reUnit)])); return }
            let c = it.dist + it.w / 2
            it.w = v; it.dist = reClamp(reR10(c - v / 2), 0, max(0, L - v))
        case "h":
            if it.z0 + v > g.H { warn(app, reErrText(ReErr(code: "ceil", vars: ["v": it.z0 + v, "c": g.H]), wall: it.wall)); return }
            if it.isBalcony && v < it.wh + 100 { warn(app, reErrText(ReErr(code: "balDoor", vars: ["m": it.wh + 100]), wall: it.wall)); return }
            it.h = v
        case "sill":
            if v + it.h > g.H { warn(app, reErrText(ReErr(code: "ceil", vars: ["v": v + it.h, "c": g.H]), wall: it.wall)); return }
            it.sill = v
        case "thr": it.thr = v
        case "ph":
            if v > g.H { warn(app, reErrText(ReErr(code: "ceil", vars: ["v": v, "c": g.H]), wall: it.wall)); return }
            it.ph = v
        case "sw": it.sw = s
        default: return
        }
        let x = it
        let msg: String
        switch key {
        case "w": msg = tr("re.m.w", ["n": name, "v": reLen(v)])
        case "h", "ph": msg = tr("re.m.h", ["n": name, "v": reLen(v)])
        case "sill": msg = tr("re.m.sill", ["v": reLen(v)])
        case "thr": msg = tr("re.m.thr", ["v": reLen(v)])
        default: msg = tr("re.m.sw", ["n": name, "s": tr("re.sw." + s)])
        }
        commit(app, h, msg) { rePut(&$0, x); return nil }
    }

    /* the room itself (the editor) */

    func setWallLen(_ id: String, _ v: Int, _ app: AppModel, _ h: ReHost, laser: Bool = false) {
        // an inner face's length follows its piece (the piece's Uzunlik)
        guard let r = h.room(), iwPieceOf(id) == nil else { return }
        let old = reGeo(r).len(id)
        if v == old { app.toast = ToastMsg(text: tr("re.m.same", ["w": reWL(id), "v": reLen(v)]), kind: .info); return }
        let msg = (laser ? tr("re.m.laser") + " · " : "") + tr("re.m.len", ["w": reWL(id), "a": reLen(old), "b": reLen(v)]) + (reWallBig(v) ? " · " + tr("re.big") : "")
        commit(app, h, msg) { room in
            switch reSetWallLen(&room, id, v) {
            case "auto"?: return tr("re.m.auto")
            case "range"?: return tr("re.m.range")
            case "shape"?: return tr("re.m.shape")
            default: return nil
            }
        }
    }

    func setThick(_ v: Int, _ app: AppModel, _ h: ReHost) {
        guard let id = selWall, let r = h.room() else { return }
        let old = r.thickOf(id)
        if old == v { return }
        commit(app, h, tr("re.m.thick", ["w": reWL(id), "a": "\(old)", "b": "\(v)"])) { reSetThick(&$0, id, v); return nil }
    }

    func setRoomH(_ v: Int, _ app: AppModel, _ h: ReHost) {
        guard let r = h.room() else { return }
        let old = reHeight(r)
        if old == v { return }
        commit(app, h, tr("re.m.rh", ["a": reLen(old), "b": reLen(v)])) { reSetHeight(&$0, v); return nil }
    }

    func turn(_ dir: Int, _ app: AppModel, _ h: ReHost) {
        commit(app, h, tr(dir > 0 ? "re.m.rotR" : "re.m.rotL")) { reTurn(&$0, dir); return nil }
    }

    func mirror(_ app: AppModel, _ h: ReHost) {
        commit(app, h, tr("re.m.mirror")) { reMirror(&$0); return nil }
    }

    func setShape(_ k: String, _ app: AppModel, _ h: ReHost) {
        guard let r = h.room(), let shape = RoomShape.of(k), reShapeOf(r) != k else { return }
        if shape == .free { app.toast = ToastMsg(text: tr("re.m.free"), kind: .info); return }
        var lost = 0
        let ok = commit(app, h, tr("re.m.shapeTo", ["a": tr("rsh.s." + reShapeOf(r)), "b": tr("rsh.s." + k)])) { room in
            guard let n = reChangeShape(&room, shape) else { return tr("re.m.free") }
            lost = n
            return nil
        }
        if ok && lost > 0 { app.toast = ToastMsg(text: tr("re.m.lost", ["n": lost]), kind: .info) }
        if ok { sel = nil }
    }
}

/// The tools the editor's slider shows now (their ids), for keeping an options row only while it still fits.
func reToolIds(_ st: ReState, _ h: ReHost) -> [String] {
    guard let r = h.room() else { return [] }
    switch st.sel {
    case nil: return ["add", "inner", "shape", "rh", "rot", "dims", "checks", "v3d", "more"]
    case .wall(let w)?:
        // an inner wall's face: its doors, windows and points, the piece's thickness, or the whole piece
        if iwPieceOf(w) != nil { return ["addDoor", "addWin", "pt", "iwTh", "iwOf"] }
        return ["len", "laser", "addDoor", "addWin", "pt", "thick", "corner"]
    case .piece(let id)?:
        guard let p = r.inner.first(where: { $0.id == id }) else { return [] }
        var t = ["iwLen"]
        if p.k != "col" { t.append("iwTh") }
        if p.k == "half" { t.append("iwH") }
        if p.k == "arch" { t.append("iwOp") }
        if p.k == "col" { t.append("iwShape") } else { t += ["iwRot", "iwFace"] }
        return t + ["iwCopy", "iwDel"]
    case .item(let id)?:
        guard let it = reFind(r, id) else { return [] }
        if it.isOpening {
            var t = ["w", "h"]
            if !(it.style == "pano" || it.isBalcony) { t.append("sill") }
            t += ["move", "type"]
            if it.style != "arch" { t.append("swing") }
            return t + ["copy", "del"]
        }
        return ["ptype", "ph", "move", "del"]
    }
}
