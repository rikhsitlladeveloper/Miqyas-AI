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
                .background(G.sheet(0.55).ignoresSafeArea(edges: .top))
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
    func m(_ v: Int) -> String { Geo.fmtLen(v, .m, en) }
    if f.kind == "wardrobe" {
        guard let w = wardOfF(f) else { return "" }
        let name: String? = f.model.isEmpty ? nil : tr(!f.type.isEmpty ? "ft." + f.model : "fz.m." + f.model)
        // the height as asked: a cabinet's with its legs
        let h = valsOf(f, AppSettings.shared.workshop)["h"] ?? w.h
        return [name, m(w.w) + " × " + m(h) + " × " + m(w.d) + " m"].compactMap { $0 }.joined(separator: " · ")
    }
    let fs = f.free
    let run = fs.map { freeRunMm(f.layout, $0.sides, $0.island) } ?? runMm(f)
    let t = (max(0, run) + 50) / 100
    let sizes = fs.map { ($0.sides + ($0.island > 0 ? [$0.island] : [])).map { m($0) }.joined(separator: " + ") + " m" }
    return [tr(f.model.isEmpty ? "kt.l" + f.layout : "fz.m." + f.model), sizes, "\(t / 10)\(en ? "." : ",")\(t % 10) " + tr("kt.pm")].compactMap { $0 }.joined(separator: " · ")
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
            let m = { (v: Int?) -> String in v.map { Geo.fmtLen($0, .m, en) } ?? "?" }
            GlassSheet(tr("fz.pickT", ["n": dn(f.name)]), onClose: { app.sheet = nil }) {
                if rooms.isEmpty { T(tr("fz.noMeasured"), ui(14, 400, G.ink2, lh: 1.45)) }
                ForEach(rooms) { r in
                    let w = p.floors.first { $0.id == r.floorId }
                    HStack(spacing: 12) {
                        MIcon(w?.type == "kitchen" ? "kitchen" : "room", G.cobalt, 22, 2)
                        VStack(alignment: .leading, spacing: 1) {
                            T(w.map { floorName($0) } ?? dn(r.name), ui(15.5, 700), lines: 1)
                            T(m(r.dim("A").v) + " × " + m(r.dim("B").v) + " m · h " + m(r.dim("H").v), num(12.5, 500, G.ink2), lines: 1)
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
func addPiece(_ pid: String, _ f: Furniture) {
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
    @FocusState private var focus: PF?

    init(app: AppModel, pid: String, fid: String?, rid: String, model: String? = nil, vals: String? = nil) {
        self.app = app; self.pid = pid; self.fid = fid; self.rid = rid; self.model = model; self.vals = vals
        let p = Store.shared.get(pid)
        let room = p?.rooms.first { $0.id == rid }
        let ids = room.map { Geo.walls($0, AppSettings.shared.angleSnap).map(\.id) } ?? []
        let taken = p?.furniture.filter { $0.roomId == rid && $0.id != fid }.flatMap(\.walls).filter { $0 != ISLAND } ?? []
        _first = State(initialValue: ids.first { !taken.contains($0) } ?? ids.first ?? "A")
        let existing = fid.flatMap { id in p?.furniture.first { $0.id == id } }
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
            let base: Furniture? = {
                if let existing { return existing }
                guard let m else { return nil }
                let now = nowMs()
                if known && m.kind == "kitchen" { return roomKitchen(m, ids, first, len, roomH, ws, name, now: now) }
                if known {
                    let c = roomCabinet(m, len(first), roomH, ws, name, now: now)
                    return parseLen(wTxt, unit).map { resized(c, ["w": min(6000, max(300, $0))], ws) } ?? c
                }
                return pieceOf(m, decodeVals(vals), ws, name, now: now)
            }()
            if let base {
                let others = p.furniture.filter { $0.roomId == room.id && $0.id != base.id }
                let taken = others.flatMap(\.walls).filter { $0 != ISLAND }
                let ward = base.kind == "wardrobe"
                let offMm: Int? = { let v = mm(off); return v > 0 ? v : nil }()
                let f = fitted ?? base
                let on = placeWalls(f, ids, first)
                let issues = fitIssues(f, on, len, roomH, ws, off: offMm)
                let roomName = p.floors.first { $0.id == room.floorId }.map { floorName($0) } ?? dn(room.name)
                let clash = on.first { taken.contains($0) }
                FPage(eyebrow: dn(f.name) + " → " + roomName, title: tr("fz.toRoom"), back: { app.pop() }) {
                    PlacePlan(room: room, f: f, on: on, off: offMm, snap: snap)
                    T(tr(ward ? "fz.wallQ" : "fz.first"), ui(15, 700))
                    FlowLayout(spacing: 8) {
                        ForEach(wl, id: \.id) { w in
                            FChip(label: tr("kt.wallN", ["w": w.id]) + (len(w.id).map { " · \($0)" } ?? ""), on: w.id == first) { if w.id != first { first = w.id; reset() } }
                                .accessibilityIdentifier("fz.wall." + w.id)
                        }
                    }
                    let next = on.dropFirst().filter { $0 != ISLAND }
                    if !ward && !next.isEmpty { T(tr("fz.nextWalls", ["w": next.joined(separator: ", ")]), ui(13, 400, G.ink2, lh: 1.4)) }
                    // a kitchen for a measured room takes its walls whole
                    if known && !ward {
                        T(tr("fq.whole", ["v": (f.free?.sides ?? []).map { Geo.fmtLen($0, unit, en) }.joined(separator: " + ") + " " + unitWord(unit),
                                          "h": Geo.fmtLen(roomH, unit, en) + " " + unitWord(unit)]), ui(13, 400, G.ink2, lh: 1.4))
                    }
                    if let clash, let who = others.first(where: { $0.walls.contains(clash) }) {
                        T(tr("kt.wallTaken", ["w": clash, "n": dn(who.name)]), ui(12.5, 500, G.amberInk, lh: 1.4))
                    }
                    if ward {
                        if known {
                            GField(label: tr("wd.w"), value: Binding(get: { wTxt }, set: { wTxt = String($0.filter { $0.isNumber || $0 == "," || $0 == "." }.prefix(6)); reset() }),
                                   placeholder: wardOfF(base).map { Geo.fmtLen($0.w, unit, en, full: $0.w % 10 != 0) } ?? "", focus: $focus, me: .w, onSubmit: { focus = .off },
                                   labelRight: unitWord(unit), decimal: true, id: "fz.width")
                        }
                        T(tr("fz.offset"), ui(15, 700))
                        HStack(spacing: 8) {
                            FChip(label: tr("fz.corner"), on: offMm == nil) { off = ""; reset() }
                            GField(label: nil, value: Binding(get: { off }, set: { off = String($0.filter { $0.isASCII && $0.isNumber }.prefix(5)); reset() }), placeholder: "0",
                                   focus: $focus, me: .off, submit: .done, onSubmit: { focus = nil }, labelRight: "mm", number: true)
                        }
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
                        HStack(spacing: 8) {
                            GBtn(tr(heightOnly ? "fz.fitH" : "fz.fit"), kind: .secondary, height: 46, corner: 14, fontSize: 14) {
                                // a distance from the corner that leaves no room for a cabinet comes back to where 300 mm still fit
                                let wl = on.first.flatMap { len($0) }
                                var o = offMm
                                if ward, let v = offMm, let wl, v > wl - 300 - W_GAP_SIDE { let b = wl - 300 - W_GAP_SIDE; o = b > 0 ? b : nil; off = o.map { String($0) } ?? "" }
                                fitted = fitTo(placed(f, on, room.id, room.floorId, off: o, ws: ws), on, len, roomH, ws, off: o); keep = false; app.say("fz.fitted")
                            }
                            .accessibilityIdentifier("fz.fit")
                            GBtn(tr("fz.keep"), kind: keep ? .primary : .secondary, height: 46, corner: 14, fontSize: 14) { keep = true }.accessibilityIdentifier("fz.keep")
                        }
                    }
                } footer: {
                    GBtn(tr("fz.placeHere"), enabled: issues.isEmpty || keep) {
                        if !issues.isEmpty && !keep { app.say("fz.pickFirst", kind: .error); return }
                        guard app.once() else { return }
                        let g = placed(f, on, room.id, room.floorId, off: offMm, keep: !issues.isEmpty, len: len, ws: ws)
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
            }
        }
    }

    private func reset() { fitted = nil; keep = false }
}

/// The room from above with the piece's place: each side along its wall (red past the wall's end), the wardrobe at its distance.
private struct PlacePlan: View {
    let room: Room
    let f: Furniture
    let on: [String]
    let off: Int?
    let snap: Bool
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Canvas { ctx, size in
            let wl = Geo.walls(room, snap)
            guard !wl.isEmpty else { return }
            let runs = runsOf(f) { _ in nil }
            let xs = wl.flatMap { [$0.p0.x, $0.p1.x] }, ys = wl.flatMap { [$0.p0.y, $0.p1.y] }
            let x0 = xs.min()!, y0 = ys.min()!
            let spanX = max(xs.max()! - x0, 1), spanY = max(ys.max()! - y0, 1)
            let pad: CGFloat = 34
            let k = min((size.width - 2 * pad) / spanX, (size.height - 2 * pad) / spanY)
            let ox = (size.width - spanX * k) / 2, oy = (size.height - spanY * k) / 2
            func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: ox + (x - x0) * k, y: oy + (y - y0) * k) }
            var outline = Path()
            for (i, w) in wl.enumerated() { let a = P(w.p0.x, w.p0.y); if i == 0 { outline.move(to: a) } else { outline.addLine(to: a) } }
            outline.closeSubpath()
            ctx.fill(outline, with: .color(Color(argb: 0xFFF3F6FB)))
            ctx.stroke(outline, with: .color(Color(argb: 0xFF0F172A)), lineWidth: 5)
            func quad(_ q: [CGPoint], _ c: Color) {
                var pp = Path(); pp.move(to: q[0]); q.dropFirst().forEach { pp.addLine(to: $0) }; pp.closeSubpath()
                ctx.fill(pp, with: .color(c.opacity(0.22))); ctx.stroke(pp, with: .color(c), lineWidth: 2)
            }
            let blue = Color(argb: 0xFF3550E0), red = Color(argb: 0xFFDC2626)
            let sidesOn = on.filter { $0 != ISLAND }.count
            for w in wl {
                let dx = w.p1.x - w.p0.x, dy = w.p1.y - w.p0.y, l = max(hypot(dx, dy), 1)
                let ux = dx / l, uy = dy / l, nx = -uy, ny = ux              // into the room
                let mid = P(w.p0.x + dx / 2, w.p0.y + dy / 2)
                ctx.draw(Text(w.id).font(.system(size: 12)).foregroundColor(Color(argb: 0xFF475569)), at: CGPoint(x: mid.x - nx * 20, y: mid.y - ny * 20))
                // the piece along this wall
                func bar(_ a: Double, _ b: Double, _ depth: Double, _ over: Bool) {
                    quad([P(w.p0.x + ux * a, w.p0.y + uy * a), P(w.p0.x + ux * b, w.p0.y + uy * b),
                          P(w.p0.x + ux * b + nx * depth, w.p0.y + uy * b + ny * depth), P(w.p0.x + ux * a + nx * depth, w.p0.y + uy * a + ny * depth)], over ? red : blue)
                }
                guard let i = on.firstIndex(of: w.id) else { continue }
                if f.kind == "wardrobe" {
                    guard let m = wardOfF(f) else { continue }
                    let a = Double(off ?? W_GAP_SIDE)
                    bar(a, a + Double(m.w), Double(m.d), a + Double(m.w) > l + 1)
                } else {
                    guard i < runs.count else { continue }
                    let r = runs[i]
                    var need = runEnd(f, r)
                    if f.roomId == nil, let s = f.free?.sides, i < s.count { need = max(s[i], need) }
                    // a corner kitchen's first side ends in the corner
                    let a = i == 0 && sidesOn > 1 ? max(0, l - Double(need)) : 0
                    bar(a, a + Double(need), 600, Double(need) > l + 1)
                }
            }
            // the island or peninsula, 900 out in front of the first side
            if on.contains(ISLAND) && f.kind == "kitchen", let w = wl.first(where: { $0.id == on[0] }) {
                let isl = Double(f.modules.filter { $0.wall == ISLAND && !isUpper($0) }.reduce(0) { $0 + $1.w })
                if isl > 0 {
                    let dx = w.p1.x - w.p0.x, dy = w.p1.y - w.p0.y, l = max(hypot(dx, dy), 1)
                    let ux = dx / l, uy = dy / l, nx = -uy, ny = ux
                    let a = (l - isl) / 2, b = a + isl, d0 = 1500.0, d1 = 2100.0
                    quad([P(w.p0.x + ux * a + nx * d0, w.p0.y + uy * a + ny * d0), P(w.p0.x + ux * b + nx * d0, w.p0.y + uy * b + ny * d0),
                          P(w.p0.x + ux * b + nx * d1, w.p0.y + uy * b + ny * d1), P(w.p0.x + ux * a + nx * d1, w.p0.y + uy * a + ny * d1)], blue)
                }
            }
        }
        .aspectRatio(1.5, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(shape.fill(G.glass(0.6)))
        .clipShape(shape)
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .accessibilityHidden(true)
    }
}
