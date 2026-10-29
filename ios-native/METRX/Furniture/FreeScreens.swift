import SwiftUI

/*
 * Furniture without a room (decided 20 Oct 2026, mockup design/furniture/orders-flow-mockup.html v4; Android
 * ui/furniture/FreeScreens.kt): after the three-field new order, "Nima kerak?"; for each piece the room or only its
 * sizes; a gallery of ready models with 3D pictures; the sizes; later "Xonaga qo‘yish" into a measured room, and
 * "Xonadan chiqarish" back out. The rules are in Furniture/Core/Free.swift.
 */

private var en: Bool { AppSettings.shared.lang == .en }

/* ---------------- the order's name and what is still wanted ---------------- */

/// While the order's name follows its furniture: "Oshxona — Akmal", "Shkaf — Akmal", "Oshxona va shkaf — Akmal".
func renameOrder(_ pid: String) {
    Store.shared.update(pid) { p in
        guard p.autoName else { return }
        let ks = Set(p.furniture.map(kindKey) + (p.want ?? []))
        let what: String? = ks.isEmpty ? nil : ks == ["kitchen", "wardrobe"] ? tr("fo.both") : ks == ["wardrobe"] ? tr("kt.wardrobe")
            : ks == ["kitchen"] ? tr("kt.kitchen") : tr("fz.furn")
        p.name = what.map { $0 + " — " + p.customer } ?? p.customer
    }
}

/// A room every wall and the height of which are confirmed.
func measuredRoom(_ r: Room, _ snap: Bool) -> Bool { Geo.stepKeys(r, snap).allSatisfy { r.dim($0).status == "conf" } }

/// Takes the piece out of its room: its sizes from what stands on the walls now.
func takeOut(_ app: AppModel, _ pid: String, _ fid: String) {
    guard let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }) else { return }
    let room = roomOf(p, f)
    let snap = AppSettings.shared.angleSnap
    let g = takenOut(f, { id in room.flatMap { wallLen($0, snap, id) } }, room?.dim("H").v)
    Store.shared.update(pid) { pr in pr.furniture = pr.furniture.map { $0.id == fid ? g : $0 } }
    KitOps.shared.forget(fid); KitOps.shared.sel = nil; KitOps.shared.tick += 1
    app.say("fz.outDone", ["n": dn(f.name)])
}

/// The order's furniture with the pieces of these rooms taken out (the rooms are going away).
func outOfRooms(_ p: Project, _ rids: Set<String>) -> [Furniture] {
    p.furniture.map { f in
        guard let rid = f.roomId, rids.contains(rid), let room = p.rooms.first(where: { $0.id == rid }) else { return f }
        return takenOut(f, { id in wallLen(room, AppSettings.shared.angleSnap, id) }, room.dim("H").v)
    }
}

/// The designer of a piece: the wardrobe's at step, or the kitchen's.
func designer(_ pid: String, _ f: Furniture, step: Int = 1) -> Route {
    f.kind == "wardrobe" ? .wardrobe(pid: pid, fid: f.id, step: step, sec: 0) : .kitchen(pid: pid, fid: f.id, wall: nil)
}

/* ---------------- the page frame ---------------- */

struct FPage<Content: View, Footer: View>: View {
    let eyebrow: String
    let title: String
    let back: () -> Void
    var hasFooter = true
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    GlassIconButton("back", tr("nt.back"), back).padding(.leading, 6).accessibilityIdentifier("back")
                    BarTitle(title: title, eyebrow: eyebrow)
                }
                .padding(.trailing, 12).frame(minHeight: 64)
                .background(barTint.ignoresSafeArea(edges: .top))
                .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) { content }
                        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, hasFooter ? 120 : 28)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            if hasFooter { FloatingFooter { footer } }
        }
    }
}

extension FPage where Footer == EmptyView {
    init(eyebrow: String, title: String, back: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.eyebrow = eyebrow; self.title = title; self.back = back; self.hasFooter = false; self.content = content(); self.footer = EmptyView()
    }
}

private func mm(_ s: String) -> Int { Int(String(s.filter { $0.isASCII && $0.isNumber }.prefix(5))) ?? 0 }

/* ---------------- on the designers and the order: room-less pieces ---------------- */

/// On a room-less piece's designer: it has no room yet, and the way into one.
struct FreeBanner: View {
    let app: AppModel
    let p: Project
    let f: Furniture
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            T(tr("fz.banner"), ui(13.5, 500, G.ink, lh: 1.4))
            HStack(spacing: 8) {
                GBtn(tr("fz.toRoom"), icon: "room", height: 44, corner: 14, fontSize: 14) { app.sheet = .fPickRoom(pid: p.id, fid: f.id) }.accessibilityIdentifier("fz.toRoom")
                GBtn(tr("fz.sizesBtn"), kind: .secondary, icon: "ruler", height: 44, corner: 14, fontSize: 14) {
                    app.push(.fSteps(pid: p.id, model: modelOf(f).id, fid: f.id))
                }
                .accessibilityIdentifier("fz.sizes")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(G.cobalt.opacity(0.08)))
        .overlay(shape.strokeBorder(G.cobalt.opacity(0.25), lineWidth: 1))
    }
}

/// A room-less piece's line: its model, sizes and running metres.
func freeSub(_ f: Furniture, _ en: Bool) -> String {
    func m(_ v: Int) -> String { Geo.fmtLen(v, AppSettings.shared.unit, en) }
    if f.kind == "wardrobe" {
        guard let w = wardOfF(f) else { return "" }
        // a sliding wardrobe is named by the doors it has now, not by the model it started from ("Kupe, 3 eshik" → 4)
        let modelName: String? = f.model.isEmpty ? nil : tr(!f.type.isEmpty ? "ft." + f.model : "fz.m." + f.model)
        let name: String? = w.slide.map { tr("fz.slideNow", ["n": $0.n]) } ?? modelName
        // the height as asked: a cabinet's with its legs
        let v = shownVals(f, AppSettings.shared.workshop)
        let h = v["h"] ?? w.h
        let sizes: String
        if let mw = v["mw"] { sizes = m(mw) + " × " + m(v["ml"] ?? 0) + U_L }
        else if let w2 = v["w2"] { sizes = m(v["w"] ?? w.w) + " + " + m(w2) + " × " + m(h) + U_L }
        else { sizes = m(v["w"] ?? w.w) + " × " + m(h) + " × " + m(v["d"] ?? w.d) + U_L }
        return [name, sizes].compactMap { $0 }.joined(separator: " · ")
    }
    let fs = f.free
    // the running metres are the units' (what the designer and the price count, runMm); the typed sides' only before
    // there are units
    let run = !f.modules.isEmpty ? runMm(f) : fs.map { freeRunMm(f.layout, $0.sides, $0.island) } ?? 0
    let t = (max(0, run) + 50) / 100
    let sizes = fs.map { ($0.sides + ($0.island > 0 ? [$0.island] : [])).map { m($0) }.joined(separator: " + ") + U_L }
    return [tr(f.model.isEmpty ? "kt.l" + f.layout : "fz.m." + f.model), sizes, "\(t / 10)\(en ? "." : ",")\(t % 10) " + tr("kt.pm")].compactMap { $0 }.joined(separator: " · ")
}

/// The place-in-room page's helpers: the room's depth in front of a wall, where "fit" moves a cabinet, whether it helps.
enum FPlaceDepth {
    /// How deep the room is in front of wall id, once every wall is measured (nil: not yet).
    static func of(_ ws: [Geo.Wall], _ id: String) -> Int? {
        guard ws.allSatisfy({ $0.len != nil }), let w = ws.first(where: { $0.id == id }) else { return nil }
        return depthFrom(w.p0, w.p1, ws.map(\.p0))
    }

    /// A distance from the corner that leaves no room for a cabinet comes back to where 300 mm still fit.
    static func fitOff(_ ward: Bool, _ offMm: Int?, _ wallL: Int?) -> Int? {
        guard ward, let v = offMm, let wl = wallL else { return offMm }
        let most = wl - 300 - W_GAP_SIDE
        if v <= most { return offMm }
        return most > 0 ? most : nil
    }

    /// Whether fitting the piece changes what does not fit.
    static func changes(_ fitTry: Furniture, _ f: Furniture, _ on: [String], _ len: (String) -> Int?, _ roomH: Int?, _ ws: Workshop,
                        _ fo: Int?, _ offMm: Int?, _ start: Int, _ deep: (String) -> Int?) -> Bool {
        var a = fitTry; a.pose = nil
        var b = f; b.pose = nil
        let after = fitIssues(a, on, len, roomH, ws, off: fo, start: start, deep: deep)
        let before = fitIssues(b, on, len, roomH, ws, off: offMm, start: start, deep: deep)
        return after != before
    }
}

/// "Xonasiz mebel": the order's pieces without a room, each with its price and "Xonaga qo‘yish".
struct FreeCard: View {
    let app: AppModel
    let p: Project
    var body: some View {
        let free = p.furniture.filter { $0.roomId == nil }
        if !free.isEmpty {
            let amounts = pieceAmounts(p)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    MIcon("ruler", G.cobalt, 24, 2).frame(width: 64, height: 52)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.cobalt.opacity(0.08)))
                    VStack(alignment: .leading, spacing: 1) { T(tr("fz.free"), ui(16, 700), lines: 1); T(tr("fz.freeS"), ui(12.5, 400, G.ink2), lines: 1) }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(free) { f in
                    HStack(spacing: 10) {
                        MIcon(f.kind == "wardrobe" ? "board" : "kitchen", G.ink3, 18, 2)
                        VStack(alignment: .leading, spacing: 1) {
                            T(dn(f.name), ui(14.5, 700), lines: 1)
                            T(freeSub(f, en), num(12.5, 500, G.ink2), lines: 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if let a = amounts[f.id], a > 0 { T(shortStr(p, a), num(14, 700)) }
                        MIcon("chev", G.ink3, 16, 2)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.glass(0.75)))
                    .pressable(0.985) { KitOps.shared.sel = nil; app.push(designer(p.id, f)) }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    TodoRow(label: tr("fz.toRoom")) { app.sheet = .fPickRoom(pid: p.id, fid: f.id) }
                }
            }
            .padding(12)
            .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
        }
    }
}

/* ---------------- which room ---------------- */

struct PickRoomSheet: View {
    let app: AppModel
    let pid: String
    let fid: String
    var body: some View {
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }) {
            let snap = AppSettings.shared.angleSnap
            let rooms = p.rooms.filter { measuredRoom($0, snap) }
            let m = { (v: Int?) -> String in v.map { Geo.fmtLen($0, AppSettings.shared.unit, en) } ?? "?" }
            GlassSheet(tr("fz.pickT", ["n": dn(f.name)]), onClose: { app.sheet = nil }) {
                if rooms.isEmpty { T(tr("fz.noMeasured"), ui(14, 400, G.ink2, lh: 1.45)) }
                ForEach(rooms) { r in
                    let w = p.floors.first { $0.id == r.floorId }
                    HStack(spacing: 12) {
                        MIcon(w?.type == "kitchen" ? "kitchen" : "room", G.cobalt, 22, 2)
                        VStack(alignment: .leading, spacing: 1) {
                            T(w.map { floorName($0) } ?? dn(r.name), ui(15.5, 700), lines: 1)
                            T({ let z = Geo.roomSize(r, AppSettings.shared.angleSnap); return m(z?.0) + " × " + m(z?.1) }() + U_L + " · h " + m(r.dim("H").v), num(12.5, 500, G.ink2), lines: 1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        MIcon("chev", G.ink3, 16, 2)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10).frame(minHeight: 60)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.ink.opacity(0.05)))
                    .pressable(0.98) { app.sheet = nil; app.push(.fPlace(pid: p.id, fid: f.id, rid: r.id)) }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                }
                HStack(spacing: 8) { MIcon("plus", G.cobalt2, 18, 2.2); T(tr("fz.newRoom"), ui(15, 700, G.cobalt2)).frame(maxWidth: .infinity, alignment: .leading) }
                    .padding(.horizontal, 12).frame(minHeight: 52)
                    .dashedGlass(14)
                    .pressable(0.98) { app.sheet = .fNewRoom(pid: p.id, kind: f.kind, fid: f.id) }
                    .accessibilityIdentifier("fz.newRoom")
            }
        }
    }
}

/* ---------------- into the room ---------------- */

/// A new piece's name: "Oshxona 2", "Shkaf 3", "Komod 1" (counted by kind, or by type for the other pieces).
func pieceName(_ p: Project, _ m: FModelDef) -> String {
    let n = p.furniture.filter { !m.type.isEmpty ? $0.type == m.type : $0.kind == m.kind && $0.type.isEmpty }.count + 1
    if !m.type.isEmpty { return tr("ft." + m.type) + " \(n)" }
    return tr(m.kind == "kitchen" ? "kt.nameN" : "wd.nameN", ["n": n])
}

/// Adds a new piece to the order: the stage moves on from measuring, what they want grows, the name follows.
func addPiece(_ pid: String, _ f0: Furniture) {
    // a new piece starts in the order's design style (Core/PieceLook.swift)
    let st = Store.shared.get(pid)?.fstyle ?? ""
    let f = f0.look == nil && !st.isEmpty ? withPreset(f0, st, fresh: true, ws: AppSettings.shared.workshop) : f0
    Store.shared.update(pid) { pr in
        pr.furniture.append(f)
        if pr.stage == "measure" { pr.stage = "design" }
        var w = pr.want ?? []; if !w.contains(kindKey(f)) { w.append(kindKey(f)) }; pr.want = w
    }
    renameOrder(pid)
}

/// A fit issue in words, the piece's name in the app language.
func issueText(_ i: FitIssue) -> String {
    tr(i.key, Dictionary(uniqueKeysWithValues: i.vars.map { k, v in (k, (k == "n" ? dn(v) : v) as Any) }))
}

private enum PF: Hashable { case off, w }

/// A new piece made once for the page's choices (key): redraws keep the same piece, its id and its time.
private final class BaseMemo {
    var key = ""
    var f: Furniture? = nil
    func get(_ k: String, _ make: () -> Furniture?) -> Furniture? {
        if k != key || f == nil { key = k; f = make() }
        return f
    }
}

struct FPlaceScreen: View {
    let app: AppModel
    let pid: String
    let fid: String?
    let rid: String
    let model: String?
    let vals: String?
    @State private var first: String
    @State private var off = ""          // a wardrobe's distance from the corner; "" = in the corner
    @State private var wTxt = ""         // a new cabinet's width in a known room; "" = as made
    @State private var keep = false
    @State private var fitted: Furniture? = nil
    @State private var name: String
    @State private var start = 0            // a one-wall kitchen's distance from the corner
    @State private var pose: Pose? = nil    // dragged off the walls: a desk, the island
    @State private var holding = false      // a finger holds the piece on the plan: the page does not scroll
    @State private var wher = ""            // a new piece: "wall" or "free", asked once (room-editor mockup v3 fpHtml)
    @State private var memo = BaseMemo()
    @FocusState private var focus: PF?

    init(app: AppModel, pid: String, fid: String?, rid: String, model: String? = nil, vals: String? = nil) {
        self.app = app; self.pid = pid; self.fid = fid; self.rid = rid; self.model = model; self.vals = vals
        let p = Store.shared.get(pid)
        let room = p?.rooms.first { $0.id == rid }
        let ids = room.map { Geo.walls($0, AppSettings.shared.angleSnap).map(\.id) } ?? []
        // a piece standing free in the room (a bed, a table) takes no wall
        let taken = p?.furniture.filter { $0.roomId == rid && $0.id != fid && ($0.pose == nil || $0.kind == "kitchen") }.flatMap(\.walls).filter { $0 != ISLAND } ?? []
        let existing = fid.flatMap { id in p?.furniture.first { $0.id == id } }
        // a piece already in this room starts where it stands
        let here = existing.flatMap { $0.roomId == rid ? $0 : nil }
        _first = State(initialValue: here?.walls.first { $0 != ISLAND && ids.contains($0) } ?? ids.first { !taken.contains($0) } ?? ids.first ?? "A")
        _off = State(initialValue: here.flatMap { h -> String? in
            guard h.kind == "wardrobe" else { return nil }
            let x = runStart(h)
            return x == cornerGap(h) ? "" : String(x)
        } ?? "")
        _start = State(initialValue: here.map { $0.walls.filter { $0 != ISLAND }.count == 1 ? leadOf($0) : 0 } ?? 0)
        _pose = State(initialValue: here?.pose)
        _name = State(initialValue: existing?.name ?? (p.flatMap { pp in model.flatMap { fModel($0) }.map { pieceName(pp, $0) } } ?? ""))
    }

    var body: some View {
        if let p = Store.shared.get(pid), let room = p.rooms.first(where: { $0.id == rid }) {
            let s = AppSettings.shared, snap = s.angleSnap, ws = s.workshop, unit = s.unit, en = s.lang == .en
            let wl = Geo.walls(room, snap)
            let ids = wl.map(\.id)
            let len = { (id: String) in wallLen(room, snap, id) }
            let roomH = room.dim("H").v
            // the piece: one of the order's, or a new one of a model (its typed sizes, or the room's own when vals is nil)
            let m = model.flatMap { fModel($0) }
            let known = fid == nil && vals == nil && m != nil
            let existing = fid.flatMap { id in p.furniture.first { $0.id == id } }
            // a new one is made once for the wall and the width chosen (as Android's remember(rt, first, wTxt)), not on each redraw
            let fresh: () -> Furniture? = {
                guard let m else { return nil }
                let now = nowMs()
                if known && m.kind == "kitchen" { return roomKitchen(m, ids, first, len, roomH, ws, name, now: now) }
                if known {
                    let c = roomCabinet(m, len(first), roomH, ws, name, now: now)
                    return parseLen(wTxt, unit).map { resized(c, ["w": min(6000, max(300, $0))], ws) } ?? c
                }
                return pieceOf(m, decodeVals(vals), ws, name, now: now)
            }
            let base: Furniture? = existing.map { withoutLead($0, len) } ?? memo.get(first + "|" + wTxt + "|" + (model ?? "") + "|" + (vals ?? ""), fresh)
            if let base {
                let others = p.furniture.filter { $0.roomId == room.id && $0.id != base.id }
                // a piece standing free in the room (a bed, a table) takes no wall
                let onWall = others.filter { $0.pose == nil || $0.kind == "kitchen" }
                let taken = onWall.flatMap(\.walls).filter { $0 != ISLAND }
                // a corner piece goes into a corner like a corner kitchen; the other cabinets stand along one wall
                let corner = CORNER_TYPES.contains(base.type)
                let ward = base.kind == "wardrobe" && !corner
                let offMm: Int? = { let v = mm(off); return v > 0 ? v : nil }()
                let f = fitted ?? base
                let on = placeWalls(f, ids, first)
                // a free-standing piece where it was dragged is not held to a wall's length
                // any cabinet-engine piece can stand free once asked (room-editor mockup v3)
                let fp: Furniture = { var x = f; x.pose = canBeFree(f) ? pose : nil; return x }()
                // the room's depth in front of a wall, once every wall is measured (a piece deeper than that goes through the wall opposite)
                let deep: (String) -> Int? = { id in FPlaceDepth.of(wl, id) }
                let issues = fitIssues(fp, on, len, roomH, ws, off: offMm, start: start, deep: deep)
                // a distance from the corner that leaves no room for a cabinet comes back to where 300 mm still fit
                let fo: Int? = FPlaceDepth.fitOff(ward, offMm, on.first.flatMap { len($0) })
                let fitTry: Furniture = fitTo(placed(f, on, room.id, room.floorId, off: fo, ws: ws), on, len, roomH, ws, off: fo)
                // fitting that changes nothing (a bed longer than the wall, a corner unit alone, too deep) is not offered
                let canFit = FPlaceDepth.changes(fitTry, f, on, len, roomH, ws, fo, offMm, start, deep)
                // where it would stand, and what it would be in the way of there
                let pw = planWalls(room, snap)
                let g = placed(f, on, room.id, room.floorId, off: offMm, keep: !issues.isEmpty, len: len, ws: ws, start: start, pose: pose)
                let warns = placeWarnings(g, others, room, pw, ws)
                let roomName = p.floors.first { $0.id == room.floorId }.map { floorName($0) } ?? dn(room.name)
                let clash = on.first { taken.contains($0) }
                FPage(eyebrow: dn(f.name) + " → " + roomName, title: tr("fz.toRoom"), back: { app.pop() }) {
                    // a new piece: against a wall, or in the middle of the room (free) — asked once, changeable later
                    if existing == nil && canBeFree(f) && !canStandFree(f) {
                        FWhereCard(cur: wher.isEmpty ? (pose == nil ? "" : "free") : wher) { k in
                            wher = k
                            if k == "wall" { pose = nil; return }
                            let geo = fpGeo(room, snap)
                            let c = iwRoomCentre(geo.g)
                            if let pc = fpPiece(placed(f, on, room.id, room.floorId, off: offMm, len: len, ws: ws), pw, ws) {
                                pose = fpPoseAt(pc, pw, first, c: PlanPt(c.x, c.y), ang: fpAngle(pc))
                            }
                        }
                    }
                    PlacePlan(room: room, walls: pw, g: g, others: others, ws: ws, red: !warns.isEmpty || !issues.isEmpty, label: tr("fz.planLabel"),
                              onSlide: { w, x in
                                  if w != first { first = w; reset() }
                                  if ward { off = x == cornerGap(f) ? "" : String(x); pose = nil } else { start = x }
                              },
                              onCorner: { w in if w != first { first = w; pose = nil; reset() } },
                              onPose: { pose = $0 }, onIsland: { pose = $0 }, onHold: { holding = $0 })
                    T(tr("fz.dragHint"), ui(12.5, 400, G.ink2, lh: 1.4))
                    // a desk or the island turns, 15° a tap, about its middle
                    if canStandFree(f) || f.walls.contains(ISLAND) || (canBeFree(f) && pose != nil) {
                        HStack(spacing: 8) {
                            ForEach([(-15, "fz.turnL"), (15, "fz.turnR")], id: \.0) { d, k in
                                GBtn(tr(k), kind: .secondary, icon: d < 0 ? "undo" : "redo", height: 44, corner: 14, fontSize: 14) {
                                    if f.walls.contains(ISLAND) {
                                        if let ip = islandPoseIn(g, pw), let fr = frameOf(pw, ip) { pose = poseOf(pw, first, turned(fr, Double(islandLen(g)), 600, d)) }
                                    } else if let m = wardOfF(g), let fr = mainFrame(g, pw) {
                                        pose = poseOf(pw, pose?.ref ?? first, turned(fr, Double(m.w), Double(m.d), d))
                                    }
                                }
                                .accessibilityIdentifier(k)
                            }
                        }
                    }
                    if !warns.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(warns.enumerated()), id: \.offset) { _, i in
                                HStack(alignment: .top, spacing: 8) { MIcon("alert", G.amberInk, 16, 2); T(issueText(i), ui(13, 600, G.amberInk, lh: 1.35)) }
                            }
                        }
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.amberWash))
                    }
                    T(tr(ward ? "fz.wallQ" : "fz.first"), ui(15, 700))
                    FlowLayout(spacing: 8) {
                        ForEach(wl, id: \.id) { w in
                            FChip(label: tr("kt.wallN", ["w": w.id]) + (len(w.id).map { " · " + Geo.fmtLen($0, unit, en) + " " + unitWord(unit) } ?? ""), on: w.id == first) { if w.id != first { first = w.id; start = 0; pose = nil; reset() } }
                                .accessibilityIdentifier("fz.wall." + w.id)
                        }
                    }
                    let next = on.dropFirst().filter { $0 != ISLAND }
                    if !ward && !next.isEmpty { T(tr("fz.nextWalls", ["w": next.joined(separator: ", ")]), ui(13, 400, G.ink2, lh: 1.4)) }
                    // a kitchen for a measured room takes its walls whole
                    if known && base.kind == "kitchen" {
                        T(tr("fq.whole", ["v": (f.free?.sides ?? []).map { Geo.fmtLen($0, unit, en) }.joined(separator: " + ") + " " + unitWord(unit),
                                          "h": Geo.fmtLen(roomH, unit, en) + " " + unitWord(unit)]), ui(13, 400, G.ink2, lh: 1.4))
                    }
                    if let clash, let who = onWall.first(where: { $0.walls.contains(clash) }) {
                        T(tr("kt.wallTaken", ["w": clash, "n": dn(who.name)]), ui(12.5, 500, G.amberInk, lh: 1.4))
                    }
                    if ward {
                        if known, let m, !ITEM_TYPES.contains(m.type) {
                            GField(label: tr("wd.w"), value: Binding(get: { wTxt }, set: { wTxt = String($0.filter { $0.isNumber || $0 == "," || $0 == "." }.prefix(6)); reset() }),
                                   placeholder: wardOfF(base).map { Geo.fmtLen($0.w, unit, en, full: $0.w % 10 != 0) } ?? "", focus: $focus, me: .w, onSubmit: { focus = .off },
                                   labelRight: unitWord(unit), decimal: true, id: "fz.width")
                        }
                        // standing free it has no distance from a corner
                        if pose == nil { T(tr("fz.offset"), ui(15, 700)) }
                        if pose == nil { HStack(spacing: 8) {
                            FChip(label: tr("fz.corner"), on: offMm == nil) { off = ""; pose = nil; reset() }
                            GField(label: nil, value: Binding(get: { off }, set: { off = String($0.filter { $0.isASCII && $0.isNumber }.prefix(5)); reset() }), placeholder: "0",
                                   focus: $focus, me: .off, submit: .done, onSubmit: { focus = nil }, labelRight: tr("u.mm"), number: true)
                        } }
                    }
                    if !issues.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 8) {
                                MIcon("alert", keep ? G.amberInk : G.err, 18, 2)
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(issues.enumerated()), id: \.offset) { _, i in T(issueText(i), ui(13.5, 600, keep ? G.amberInk : G.err, lh: 1.35)) }
                                }
                            }
                            if keep { T(tr("fz.kept"), ui(12.5, 500, G.amberInk, lh: 1.35)) }
                        }
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(keep ? G.amberWash : G.errWash))
                        let heightOnly = issues.allSatisfy { $0.key == "fz.high" }
                        if !canFit { T(tr(canStandFree(f) ? "fz.noFitFree" : "fz.noFit"), ui(12.5, 500, G.ink2, lh: 1.4)) }
                        HStack(spacing: 8) {
                            if canFit {
                                GBtn(tr(heightOnly ? "fz.fitH" : "fz.fit"), kind: .secondary, height: 46, corner: 14, fontSize: 14) {
                                    if fo != offMm { off = fo.map { String($0) } ?? "" }
                                    fitted = fitTry; keep = false; app.say("fz.fitted")
                                }
                                .accessibilityIdentifier("fz.fit")
                            }
                            GBtn(tr("fz.keep"), kind: keep ? .primary : .secondary, height: 46, corner: 14, fontSize: 14) { keep = true }.accessibilityIdentifier("fz.keep")
                        }
                    }
                } footer: {
                    GBtn(tr("fz.placeHere"), enabled: issues.isEmpty || keep) {
                        if !issues.isEmpty && !keep { app.say("fz.pickFirst", kind: .error); return }
                        guard app.once() else { return }
                        if existing != nil {
                            Store.shared.update(pid) { pr in
                                pr.furniture = pr.furniture.map { $0.id == g.id ? g : $0 }
                                if pr.stage == "measure" { pr.stage = "design" }
                            }
                        } else { addPiece(pid, g) }
                        KitOps.shared.forget(g.id); KitOps.shared.sel = nil; KitOps.shared.tick += 1
                        app.popTo { if case .project(let id, _, _, _) = $0 { return id == pid }; return false }
                        app.push(designer(pid, g, step: existing == nil ? 2 : 1))
                        app.say("fz.placed", ["n": dn(g.name), "r": roomName])
                    }
                    .accessibilityIdentifier("fz.place")
                }
                .scrollDisabled(holding)
            }
        }
    }

    private func reset() { fitted = nil; keep = false }
}

/// "Qayerga qo‘yamiz?" (room-editor mockup v3 fpHtml): against the nearest free wall, sliding along it, or in the
/// middle of the room, free to move and turn. A card on the page, so the rest stays at hand.
struct FWhereCard: View {
    let cur: String
    let pick: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            T(tr("fp.w.q"), ui(15, 700))
            T(tr("fp.w.s"), ui(12.5, 400, G.ink2, lh: 1.35))
            HStack(spacing: 8) {
                one("wall", tr("fp.w.wall"), tr("fp.w.wallS"))
                one("free", tr("fp.w.free"), tr("fp.w.freeS"))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(G.glass(0.7)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
    }
    private func one(_ k: String, _ t: String, _ s: String) -> some View {
        let on = cur == k
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return VStack(alignment: .leading, spacing: 4) {
            Canvas { ctx, sz in
                let fr = CGRect(x: 8, y: 6, width: sz.width - 16, height: sz.height - 12)
                ctx.box(fr, stroke: G.ink.opacity(0.25), 1, rx: 3)
                let wood = Color(argb: 0xFFD8B48A)
                if k == "wall" {
                    ctx.line(RD.wallc, CGPoint(x: fr.minX, y: fr.minY), CGPoint(x: fr.maxX, y: fr.minY), 4)
                    ctx.box(CGRect(x: fr.midX - 22, y: fr.minY + 2, width: 44, height: 16), fill: wood, stroke: Color(argb: 0xFF8A6238), 1, rx: 2)
                } else {
                    var c = ctx
                    c.translateBy(x: fr.midX, y: fr.midY); c.rotate(by: .degrees(-18))
                    c.box(CGRect(x: -22, y: -10, width: 44, height: 20), fill: wood, stroke: Color(argb: 0xFF8A6238), 1, rx: 2)
                    ctx.stroke(Path(ellipseIn: CGRect(x: fr.midX - 4, y: fr.minY + 6, width: 8, height: 8)), with: .color(G.cobalt), lineWidth: 1.6)
                }
            }
            .frame(height: 60)
            T(t, ui(13, 800, on ? G.cobalt2 : G.ink), lines: 2)
            T(s, ui(11, 500, G.ink2, lh: 1.25), lines: 3)
        }
        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(on ? G.cobalt.opacity(0.1) : G.solid))
        .overlay(shape.strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 2 : 1))
        .pressable(0.97, label: t) { Haptic.tick(); pick(k) }
        .accessibilityIdentifier("fp.w." + k)
    }
}
