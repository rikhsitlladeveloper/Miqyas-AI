import SwiftUI

/*
 * Furniture makers, Stage 1a part 4 (furniture plan section 7; design canvas screens 7–9; Android
 * ui/furniture/KitchenScreens.kt): new furniture in a workspace, the kitchen designer (each wall seen from inside the
 * room, its lower and upper rows to scale, the fit checks), the unit library and a unit's settings. The drawing is in
 * KitchenDraw.swift; the rules in Furniture/Core/Kitchen.swift.
 */

private var OK_GREEN: Color { Theme.shared.dark ? G.green : Color(argb: 0xFF15803D) }

/* ---------------- the designer ---------------- */

struct KitchenScreen: View {
    let app: AppModel
    let pid: String
    let fid: String
    let wall: String?
    var d3 = false

    var body: some View {
        let kit = KitOps.shared
        let _ = kit.tick
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }) {
            let s = AppSettings.shared, snap = s.angleSnap, en = s.lang == .en
            let room = roomOf(p, f)
            let runs = kRuns(f, room, snap)
            let run = runs.first { $0.wall == wall } ?? runs.first
            let ws = wsOf(f, s.workshop), mats = s.mats
            // the designer's checks and the board rules of the order's Check list (a part bigger than the sheet, a drawer, a long shelf)
            let board: [FCheck] = boardIssues(f, ws, mats).map { FCheck(level: $0.level, key: $0.key, vars: $0.vars, mid: $0.mid) }
            let found = checks(f, runs, ws, room?.openings ?? [], room?.points ?? []) + board
            let bad = badOf(found)
            let sel = f.modules.first { $0.id == kit.sel && $0.wall == run?.wall }
            ZStack {
                RoomGrid().ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        GlassIconButton("back", tr("nt.back")) { app.pop() }.accessibilityIdentifier("back")
                        VStack(alignment: .leading, spacing: 0) {
                            T(dn(f.name), ui(19, 800, G.ink, lh: 1.2), lines: 1)
                            T(tr("kt.sub", ["n": f.modules.count, "v": runMetres(f, en)]), ui(12, 400, G.ink2), lines: 1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        GlassIconButton("undo", tr("common.undo"), tint: kit.canUndo(f.id) ? G.ink : PC.offIcon) { kit.undo(p.id, f.id) }.accessibilityIdentifier("kt.undo")
                        GlassIconButton("redo", tr("common.redo"), tint: kit.canRedo(f.id) ? G.ink : PC.offIcon) { kit.redo(p.id, f.id) }
                        GlassIconButton("more", tr("common.menu")) { app.sheet = .fMenu(pid: p.id, fid: f.id) }.accessibilityIdentifier("kt.menu")
                    }
                    .padding(.horizontal, 16).frame(height: 64)
                    if let room, let run {
                        HStack { DimSeg(d3: d3) { app.setTop(.kitchen(pid: pid, fid: fid, wall: wall, d3: $0)) }; Spacer() }
                            .padding(.horizontal, 16).padding(.bottom, 10)
                        if d3 { Furniture3DPane(app: app, p: p, room: room) } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(runs, id: \.wall) { r in
                                            let on = r.wall == run.wall
                                            T(runName(f, r), ui(14, 700, on ? G.solid : G.ink), lines: 1)
                                                .padding(.horizontal, 16).frame(minHeight: 40)
                                                .background(Capsule().fill(on ? G.ink : G.glass(0.6)))
                                                .overlay(Capsule().strokeBorder(on ? G.ink : G.rim, lineWidth: 1))
                                                .pressable(0.97) { go(r.wall) }
                                                .accessibilityAddTraits(on ? .isSelected : [])
                                                .accessibilityIdentifier("kt.wall." + r.wall)
                                        }
                                    }
                                }
                                HStack(spacing: 8) {
                                    FillPill(label: tr("kt.low"), fl: fillOf(f, run, false))
                                    if run.wall != ISLAND { FillPill(label: tr("kt.up"), fl: fillOf(f, run, true)) }
                                }
                                if f.roomId == nil { FreeBanner(app: app, p: p, f: f) }
                                if run.wall != ISLAND && !measured(room, snap, run.wall) {
                                    T(tr("kt.noLen", ["w": run.wall]), ui(13, 500, G.amberInk, lh: 1.4))
                                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.amberWash))
                                }
                                if run.wall == ISLAND { T(tr("kt.islandNote"), ui(13, 400, G.ink2, lh: 1.4)) }
                                KElevation(f: f, run: run, room: room, ws: ws, mats: mats, sel: sel?.id, bad: bad,
                                           onPick: { id in kit.sel = kit.sel == id ? nil : id },
                                           onSwipe: { step in
                                               guard runs.count > 1, let i = runs.firstIndex(of: run) else { return }
                                               go(runs[(i + step + runs.count) % runs.count].wall)
                                           })
                                if !f.modules.contains(where: { $0.wall == run.wall }) && run.wall != ISLAND {
                                    VStack(alignment: .leading, spacing: 10) {
                                        T(tr("kt.emptyT", ["w": run.wall]), ui(16, 800))
                                        T(tr("kt.emptyB"), ui(13.5, 400, G.ink2, lh: 1.45))
                                        GBtn(tr("kt.auto"), icon: "plus") {
                                            let before = f.modules.count
                                            let n = kit.change(p.id, f.id) { x in autoFill(x, kRuns(x, room, snap).filter { x.modules.isEmpty || $0.wall == run.wall }, ws, room.openings, room.points) }
                                            app.say("kt.autoDone", ["n": (n?.modules.count ?? before) - before])
                                        }
                                        .accessibilityIdentifier("kt.auto")
                                    }
                                    .padding(16)
                                    .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.6))
                                } else {
                                    T(tr("kt.hint"), ui(12.5, 400, G.ink2))
                                }
                                HStack(spacing: 8) {
                                    ForEach([("module", "kt.module"), ("appl", "kt.appl"), ("space", "kt.space")], id: \.0) { g, k in
                                        GBtn(tr(k), kind: .secondary, icon: g == "module" ? "plus" : nil, height: 46, corner: 16, fontSize: 14.5) {
                                            app.sheet = .fLibrary(pid: p.id, fid: f.id, wall: run.wall, group: g)
                                        }
                                        .accessibilityIdentifier("kt.lib." + g)
                                    }
                                }
                                if let sel { SelCard(app: app, p: p, f: f, m: sel) }
                                ChecksCard(f: f, found: found) { id in
                                    if let m = f.modules.first(where: { $0.id == id }) {
                                        if m.wall != run.wall { app.setTop(.kitchen(pid: p.id, fid: f.id, wall: m.wall)) }
                                        kit.sel = m.id
                                    }
                                }
                                ExtrasCard(app: app, p: p, f: f)
                                CostCard(p: p, f: f)
                            }
                            .padding(.horizontal, 16).padding(.bottom, 28)
                        }
                        LivePrice(app: app, p: p, f: f)
                        }
                    } else {
                        T(tr("kt.roomLost"), ui(15, 500, G.ink2, lh: 1.45)).padding(24)
                        Spacer()
                    }
                }
            }
        }
    }

    private func go(_ w: String) { app.setTop(.kitchen(pid: pid, fid: fid, wall: w)); KitOps.shared.sel = nil }
}

/// The kitchen's extras (plan 1b-1): worktop corners and cut-outs, backsplash, plinth, cornice, LED, end panels.
private struct ExtrasCard: View {
    let app: AppModel
    let p: Project
    let f: Furniture
    var body: some View {
        let en = AppSettings.shared.lang == .en
        let x = f.kx ?? KExtras()
        let joints = worktopJoints(f), wu = wallUnitsMm(f)
        func set(_ fn: (inout KExtras) -> Void) {
            KitOps.shared.change(p.id, f.id) { y in var g = y; var k = g.kx ?? KExtras(); fn(&k); g.kx = k; return g }
        }
        func m(_ mm: Int) -> String { String(format: "%.1f", Double(mm) / 1000).replacingOccurrences(of: ".", with: en ? "." : ",") }
        return VStack(alignment: .leading, spacing: 8) {
            T(tr("kx.title"), ui(16, 800))
            if joints > 0 {
                T(tr("kx.joint", ["n": joints]), ui(14, 600))
                Seg(items: [("butt", tr("kx.butt")), ("mitre", tr("kx.mitre"))], cur: x.joint) { k in set { $0.joint = k } }
            }
            FToggle(label: tr("kx.cutouts", ["n": f.modules.filter { $0.app == "sink" || $0.app == "hob" }.count]), on: x.cutouts, id: "kx.cutouts") { set { $0.cutouts.toggle() } }
            T(tr("kx.splash"), ui(14.5, 500))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach([0, 500, 600, 700], id: \.self) { h in
                        FChip(label: h == 0 ? tr("kx.none") : "\(h)", on: x.splash == h) { set { $0.splash = h } }.accessibilityIdentifier("kx.splash\(h)")
                    }
                }
            }
            // the units' legs (the plinth covers them): the carcass stays 720, the worktop follows
            let legH = wsOf(f, AppSettings.shared.workshop).legH
            let wtAt = worktopTop(wsOf(f, AppSettings.shared.workshop))
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    T(tr("kx.legs"), ui(14.5, 500))
                    T(tr("kx.worktopAt", ["v": wtAt]), ui(12.5, 400, G.ink2))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                T("\(legH)" + U_MM, num(14.5, 700)); MIcon("chev", G.ink3, 16, 2)
            }
            .padding(.horizontal, 4).frame(minHeight: 48)
            .pressable(0.99) { app.sheet = .kLegs(pid: p.id, fid: f.id) }
            .accessibilityIdentifier("kx.legs")
            FToggle(label: tr("kx.plinth") + " · " + m(plinthMm(f)) + U_M, on: x.plinth, id: "kx.plinth") { set { $0.plinth.toggle() } }
            FToggle(label: tr("kx.cornice") + " · " + m(wu) + U_M, on: x.cornice, id: "kx.cornice") { set { $0.cornice.toggle() } }
            FToggle(label: tr("kx.led") + " · " + m(wu) + U_M, on: x.led, id: "kx.led") { set { $0.led.toggle() } }
            FStepper(label: tr("kx.ends"), v: x.ends, lo: 0, hi: 8, id: "kx.ends") { v in set { $0.ends = v } }
            FStepper(label: tr("kx.endsUp"), v: x.endsUp, lo: 0, hi: 8, id: "kx.endsUp") { v in set { $0.endsUp = v } }
            if AppSettings.shared.advanced { T(tr("kx.note"), ui(12.5, 400, G.ink2, lh: 1.4)) }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.6))
    }
}

/// The worst finding of each module: err over warn.
func badOf(_ found: [FCheck]) -> [String: String] {
    var bad: [String: String] = [:]
    for c in found { if let id = c.mid, c.level == "err" || (c.level == "warn" && bad[id] != "err") { bad[id] = c.level } }
    return bad
}

private struct FillPill: View {
    let label: String
    let fl: Fill
    var body: some View {
        let left = fl.left
        let (txt, c): (String, Color) = left == nil ? ("\(fl.used)", G.ink2) : left! < 0 ? (tr("kt.overV", ["v": -left!]), G.err)
            : left! == 0 ? (tr("kt.full"), OK_GREEN) : (tr("kt.freeV", ["v": left!]), G.amberInk)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            T(label, ui(11.5, 500, G.ink2), lines: 1)
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                T(fl.avail != nil ? "\(fl.used) / \(fl.avail!)" : "\(fl.used)", num(15, 700), lines: 1)
                if fl.avail != nil { T(txt, ui(12, 700, c), lines: 1) }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(G.glass(0.5)))
        .overlay(shape.strokeBorder((left ?? 0) < 0 ? G.err.opacity(0.6) : G.rim, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// The run drawn to scale: a tap picks a unit, a sideways swipe goes to the next wall.
private struct KElevation: View {
    let f: Furniture, run: Run, room: Room, ws: Workshop, mats: [Mat]
    let sel: String?
    let bad: [String: String]
    let onPick: (String) -> Void
    let onSwipe: (Int) -> Void
    @State private var swiped = false
    var body: some View {
        let lay = KLay(runLen(f, run), roomH(room), 360, true, runExt(f, run))
        let mods = f.modules.filter { $0.wall == run.wall }
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        GeometryReader { geo in
            Canvas { ctx, size in
                var c = ctx; let k = size.width / lay.vw; c.scaleBy(x: k, y: k)
                drawRun(c, lay, f, run, room, ws, mats, sel, bad)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                let d = v.location - v.startLocation
                if !swiped && abs(d.x) >= 48 && abs(d.x) >= 1.5 * abs(d.y) { swiped = true; onSwipe(d.x < 0 ? 1 : -1) }
            }.onEnded { v in
                defer { swiped = false }
                if swiped || (v.location - v.startLocation).len > 10 { return }
                let k = geo.size.width / lay.vw, px = v.startLocation.x / k, py = v.startLocation.y / k
                func within(_ m: Module) -> Bool {
                    px >= lay.x(m.x) && px <= lay.x(m.x + m.w) && py >= lay.y(m.elev + m.h) && py <= (!isUpper(m) && m.elev < 300 ? lay.yF : lay.y(m.elev))
                }
                // the upper row first (it is drawn over tall units), then the lower row with its plinth
                let hit = mods.filter(isUpper).first(where: within) ?? mods.filter { !isUpper($0) }.first(where: within)
                if let hit { onPick(hit.id) }
            })
        }
        .aspectRatio(lay.vw / lay.vh, contentMode: .fit)
        .background(shape.fill(G.glass(0.55)))
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .clipShape(shape)
        .accessibilityElement()
        .accessibilityLabel(runName(f, run))
        .accessibilityIdentifier("kt.elev")
    }
}

private struct SelCard: View {
    let app: AppModel
    let p: Project, f: Furniture, m: Module
    var body: some View {
        let kit = KitOps.shared
        let row = f.modules.filter { $0.wall == m.wall && isUpper($0) == isUpper(m) }
        let i = row.firstIndex { $0.id == m.id } ?? 0
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        func move(_ step: Int) {
            guard i + step >= 0 && i + step < row.count else { return }
            let other = row[i + step]
            kit.change(p.id, f.id) { x in
                var y = x
                if let a = y.modules.firstIndex(where: { $0.id == m.id }), let b = y.modules.firstIndex(where: { $0.id == other.id }) { y.modules.swapAt(a, b) }
                return y
            }
        }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    T(modName(m), ui(16, 800), lines: 1)
                    T(modSub(m), ui(12.5, 400, G.ink2), lines: 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                MIcon("trash", G.err, 20, 2).frame(width: 44, height: 44).pressable(0.95, label: tr("common.delete")) {
                    let name = modName(m)
                    kit.change(p.id, f.id) { x in var y = x; y.modules.removeAll { $0.id == m.id }; return y }
                    kit.sel = nil
                    app.say("kt.deleted", ["m": name], action: "common.undo") { kit.undo(p.id, f.id) }
                }
                .accessibilityIdentifier("kt.del")
            }
            HStack(spacing: 8) {
                // long words ("O‘ngga", "Вправо") take a second line rather than being cut
                MoveBtn(label: tr("kt.left"), icon: "back", enabled: i > 0) { move(-1) }.accessibilityIdentifier("kt.moveL")
                MoveBtn(label: tr("kt.right"), icon: "chev", enabled: i < row.count - 1) { move(1) }.accessibilityIdentifier("kt.moveR")
                GBtn(tr("kt.setup"), icon: "sliders", height: 44, corner: 14, fontSize: 14) { app.sheet = .fModule(pid: p.id, fid: f.id, mid: m.id) }
                    .accessibilityIdentifier("kt.setup")
            }
        }
        .padding(14)
        .glassCard(shape, fill: G.glass(0.7))
        .overlay(shape.strokeBorder(G.cobalt.opacity(0.55), lineWidth: 2))
    }
}

func checkText(_ c: FCheck, _ f: Furniture) -> String {
    var vars: [String: Any] = c.vars.mapValues { $0.base }
    if let id = c.mid, let m = f.modules.first(where: { $0.id == id }) { vars["m"] = modName(m) }
    if c.key == "kc.socket", let t = c.vars["t"]?.base as? String { vars["t"] = tr("pt." + t) }
    // the board rules (Furniture/Core/FurnChecks.swift): the part's name
    if c.key.hasPrefix("bz.ck."), let pk = c.vars["p"]?.base as? String { vars["p"] = tr(pk) }
    let key = c.key == "kc.sinkFar" && ((c.vars["v"]?.base as? Int) ?? 0) < 0 ? "kc.sinkWall" : c.key
    return tr(key, vars)
}

struct ChecksCard: View {
    let f: Furniture
    let found: [FCheck]
    let onModule: (String) -> Void
    var body: some View {
        if !f.modules.isEmpty {
            let rank = ["err": 0, "warn": 1]
            let list = found.enumerated().sorted { (rank[$0.element.level] ?? 2, $0.offset) < (rank[$1.element.level] ?? 2, $1.offset) }.map(\.element)
            VStack(alignment: .leading, spacing: 8) {
                T(tr("kt.checks"), ui(15, 800))
                if !list.contains(where: { $0.level != "ok" }) {
                    HStack(alignment: .top, spacing: 8) { MIcon("check", OK_GREEN, 18, 2.4); T(tr("kt.allOk"), ui(13.5, 500, OK_GREEN, lh: 1.4)) }
                }
                ForEach(Array(list.enumerated()), id: \.offset) { _, c in
                    let (bg, fg, icon): (Color, Color, String) = c.level == "err" ? (G.errWash, G.err, "alert") : c.level == "warn" ? (G.amberWash, G.amberInk, "alert") : (Color(argb: 0x2416A34A), OK_GREEN, "check")
                    HStack(spacing: 8) {
                        MIcon(icon, fg, 18, 2)
                        T(checkText(c, f), ui(13.5, 500, fg, lh: 1.35)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(bg))
                    .pressable(0.99) { if let id = c.mid { onModule(id) } }
                    .accessibilityIdentifier("kc." + c.level)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
        }
    }
}

struct CostCard: View {
    let p: Project
    let f: Furniture
    var body: some View {
        if !f.modules.isEmpty && AppSettings.shared.advanced {
            let s = AppSettings.shared
            let cost = costOf([f], s.workshop, s.mats, s.hws, order: false)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    T(tr("kt.cost"), ui(14.5, 700)).frame(maxWidth: .infinity, alignment: .leading)
                    T(Money.str(cost.total, p.precision, s.lang == .en) + " " + Money.cur(p.currency), num(17, 800)).accessibilityIdentifier("kt.costV")
                }
                T(tr(f.kind == "kitchen" ? "kt.costNote" : "wd.costNote"), ui(12.5, 400, G.ink2, lh: 1.4))
                if cost.missing > 0 { T(tr("kt.noPrice", ["n": cost.missing]), ui(12.5, 600, G.amberInk)) }
                // parts longer than a sheet: priced a sheet each, said here too (not only on the cut list)
                ForEach(cost.layouts.filter { !$0.unplaced.isEmpty }, id: \.mat) { lay in
                    let nm = s.mats.first { $0.id == lay.mat }?.name ?? lay.mat
                    T(tr("fw.unplaced", ["m": dn(nm), "n": lay.unplaced.count]), ui(12.5, 600, G.err, lh: 1.4))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
        }
    }
}

/* ---------------- small controls of the furniture sheets ---------------- */

struct FChip: View {
    let label: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        T(label, ui(14, 700, on ? G.cobalt2 : G.ink), lines: 1)
            .padding(.horizontal, 16).frame(minHeight: 44)
            .background(Capsule().fill(on ? G.cobalt.opacity(0.1) : G.glass(0.5)))
            .overlay(Capsule().strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 2 : 1))
            .pressable(0.97, action)
            .accessibilityAddTraits(on ? .isSelected : [])
    }
}

struct FMenuRow: View {
    let icon: String, label: String, color: Color
    let action: () -> Void
    var body: some View {
        HStack(spacing: 12) { MIcon(icon, color, 20, 2); T(label, ui(15.5, 600, color)).frame(maxWidth: .infinity, alignment: .leading) }
            .padding(.horizontal, 14).frame(minHeight: 56)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.ink.opacity(0.05)))
            .pressable(0.98, action)
    }
}

struct FStepper: View {
    let label: String
    let v: Int, lo: Int, hi: Int
    var id = ""
    let onValue: (Int) -> Void
    var body: some View {
        HStack(spacing: 8) {
            T(label, ui(14.5, 500)).frame(maxWidth: .infinity, alignment: .leading)
            step("−", v > lo) { onValue(v - 1) }.accessibilityIdentifier(id + ".minus")
            T("\(v)", num(17, 700), align: .center).frame(width: 28).accessibilityIdentifier(id + ".v")
            step("+", v < hi) { onValue(v + 1) }.accessibilityIdentifier(id + ".plus")
        }
        .frame(minHeight: 52)
    }
    private func step(_ t: String, _ on: Bool, _ a: @escaping () -> Void) -> some View {
        T(t, ui(20, 600, on ? G.ink : G.ink3)).frame(width: 44, height: 44)
            .background(Circle().fill(G.ink.opacity(on ? 0.07 : 0.03)))
            .pressable(0.95, label: t) { if on { a() } }
    }
}

struct FToggle: View {
    let label: String
    let on: Bool
    var id = ""
    let action: () -> Void
    var body: some View {
        HStack { T(label, ui(14.5, 500)).frame(maxWidth: .infinity, alignment: .leading); GSwitch(on: on) }
            .frame(minHeight: 52).pressable(0.99, action)
            .accessibilityValue(on ? "1" : "0").accessibilityAddTraits(.isToggle).accessibilityIdentifier(id)
    }
}

/* ---------------- sheets ---------------- */

struct KitchenSheet: View {
    let app: AppModel
    let sheet: Sheet
    static func handles(_ s: Sheet) -> Bool {
        switch s { case .fMenu, .fRename, .fMats, .fModule, .fLibrary, .kLegs: return true; default: return false }
    }
    var body: some View {
        switch sheet {
        case .fMenu(let pid, let fid): FMenuSheet(app: app, pid: pid, fid: fid)
        case .fRename(let pid, let fid): FRenameSheet(app: app, pid: pid, fid: fid)
        case .fMats(let pid, let fid): FMatsSheet(app: app, pid: pid, fid: fid)
        case .fModule(let pid, let fid, let mid): ModuleSheet(app: app, pid: pid, fid: fid, mid: mid)
        case .fLibrary(let pid, let fid, let wall, let group): LibrarySheet(app: app, pid: pid, fid: fid, wall: wall, group: group)
        case .kLegs(let pid, let fid): LegsSheet(app: app, pid: pid, fid: fid)
        default: EmptyView()
        }
    }
}

private struct FMenuSheet: View {
    let app: AppModel
    let pid: String, fid: String
    var body: some View {
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }) {
            GlassSheet(dn(f.name), onClose: { app.sheet = nil }) {
                VStack(spacing: 8) {
                    FMenuRow(icon: "edit", label: tr("kt.rename"), color: G.ink) { app.sheet = .fRename(pid: p.id, fid: f.id) }.accessibilityIdentifier("fm.rename")
                    FMenuRow(icon: "layers", label: tr("wd.mats"), color: G.ink) { app.sheet = .fMats(pid: p.id, fid: f.id) }.accessibilityIdentifier("fm.mats")
                    if f.roomId == nil {
                        FMenuRow(icon: "room", label: tr("fz.toRoom"), color: G.ink) { app.sheet = .fPickRoom(pid: p.id, fid: f.id) }.accessibilityIdentifier("fm.toRoom")
                        FMenuRow(icon: "ruler", label: tr("fz.editSizes"), color: G.ink) {
                            app.sheet = nil; app.push(.fSteps(pid: p.id, model: modelOf(f).id, fid: f.id))
                        }
                        .accessibilityIdentifier("fm.sizes")
                    } else {
                        if let rid = f.roomId {
                            FMenuRow(icon: "room", label: tr("fz.move"), color: G.ink) { app.sheet = nil; app.push(.fPlace(pid: p.id, fid: f.id, rid: rid)) }.accessibilityIdentifier("fm.move")
                        }
                        FMenuRow(icon: "room", label: tr("fz.takeOut"), color: G.ink) { app.sheet = nil; takeOut(app, p.id, f.id) }.accessibilityIdentifier("fm.takeOut")
                    }
                    FMenuRow(icon: "trash", label: tr("kt.del"), color: G.err) {
                        let i = p.furniture.firstIndex { $0.id == f.id } ?? 0
                        Store.shared.update(p.id) { pr in pr.furniture.removeAll { $0.id == f.id } }
                        app.sheet = nil; app.dropMissing()
                        app.say("kt.deleted", ["m": dn(f.name)], action: "common.undo") {
                            Store.shared.update(p.id) { pr in pr.furniture.insert(f, at: min(i, pr.furniture.count)) }
                        }
                    }
                    .accessibilityIdentifier("fm.del")
                }
                .padding(.bottom, 6)
            }
        }
    }
}

private enum KF: Hashable { case a, b, c }

/// A kitchen's legs' height: every unit moves up or down with it, so the worktop and the wall units follow.
private struct LegsSheet: View {
    let app: AppModel
    let pid: String, fid: String
    @State private var v: String
    @FocusState private var focus: KF?
    init(app: AppModel, pid: String, fid: String) {
        self.app = app; self.pid = pid; self.fid = fid
        let f = Store.shared.get(pid)?.furniture.first { $0.id == fid }
        let ws = AppSettings.shared.workshop
        _v = State(initialValue: String(f.map { wsOf($0, ws).legH } ?? ws.legH))
    }
    var body: some View {
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }) {
            let ws = AppSettings.shared.workshop
            let now = wsOf(f, ws).legH
            let vi = Int(v).flatMap { (50...250).contains($0) ? $0 : nil }
            let wtAt: Int = { var at = ws; at.legH = vi ?? now; return worktopTop(at) }()
            let save = {
                guard let x = vi else { return }
                let dy = x - now
                KitOps.shared.change(p.id, f.id) { g in
                    var n = g; n.baseH = x
                    // what stands on the legs or hangs over them moves; a free-standing fridge stays on the floor
                    n.modules = g.modules.map { m0 in
                        if m0.app == "fridge" || m0.elev == 0 { return m0 }
                        var m = m0; m.elev += dy; return m
                    }
                    return n
                }
                app.sheet = nil
            }
            GlassSheet(tr("kx.legs"), onClose: { app.sheet = nil }) {
                GField(label: tr("kx.legs"), value: $v, placeholder: "\(now)", error: tr("km.bad", ["a": 50, "b": 250]), showError: vi == nil, focus: $focus, me: .a,
                       submit: .done, onSubmit: save, labelRight: tr("u.mm"), number: true, id: "kl.value")
                T(tr("kx.worktopAt", ["v": wtAt]), ui(13, 400, G.ink2, lh: 1.4))
            } footer: {
                GBtn(tr("common.save"), enabled: vi != nil) { save() }.accessibilityIdentifier("kl.save")
            }
            .onChange(of: v) { _, x in let t = String(x.filter(\.isNumber).prefix(3)); if t != x { v = t } }
            // the keyboard comes up with the sheet
            .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focus = .a } }
        }
    }
}

/// A secondary button of the selected unit's row whose word may take two lines (GBtn keeps one).
private struct MoveBtn: View {
    let label: String
    let icon: String
    let enabled: Bool
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        HStack(spacing: 6) {
            MIcon(icon, G.ink, 18, 2.2)
            T(label, ui(13, 700, G.ink), align: .center, lines: 2)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(shape.fill(G.ink.opacity(0.06)))
        .opacity(enabled ? 1 : 0.42)
        .pressable(0.98) { if enabled { action() } }
        .accessibilityAddTraits(enabled ? [] : .isStaticText)
    }
}

private struct FRenameSheet: View {
    let app: AppModel
    let pid: String, fid: String
    @State private var name: String
    @FocusState private var focus: KF?
    init(app: AppModel, pid: String, fid: String) {
        self.app = app; self.pid = pid; self.fid = fid
        _name = State(initialValue: Store.shared.get(pid)?.furniture.first { $0.id == fid }.map { dn($0.name) } ?? "")
    }
    var body: some View {
        let ok = !name.trimmingCharacters(in: .whitespaces).isEmpty
        func save() {
            guard ok else { return }
            Store.shared.update(pid) { pr in if let i = pr.furniture.firstIndex(where: { $0.id == fid }) { pr.furniture[i].name = name.trimmingCharacters(in: .whitespaces) } }
            app.sheet = nil
        }
        return GlassSheet(tr("kt.rename"), onClose: { app.sheet = nil }) {
            GField(label: tr("kt.name"), value: $name, placeholder: tr("kt.kitchen"), focus: $focus, me: .a, submit: .done, onSubmit: save, id: "fr.name")
        } footer: {
            GBtn(tr("common.save"), enabled: ok) { save() }.accessibilityIdentifier("fr.save")
        }
    }
}

/// The boards of a piece: carcass, fronts, back (Android WardrobeScreens FMatsSheet).
private struct FMatsSheet: View {
    let app: AppModel
    let pid: String, fid: String
    var body: some View {
        let _ = KitOps.shared.tick
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }) {
            let mats = AppSettings.shared.mats
            GlassSheet(tr("wd.mats"), onClose: { app.sheet = nil }) {
                ForEach(Array(["carcass", "front", "back"].enumerated()), id: \.offset) { k, role in
                    if k > 0 { Hairline() }
                    T(tr("wd." + role), ui(15, 800))
                    let cur = role == "carcass" ? f.mats.carcass : role == "front" ? f.mats.front : f.mats.back
                    ForEach(mats.filter { role == "back" ? $0.kind == "back" : $0.kind == "board" }) { mt in
                        let on = mt.id == cur, tile = RoundedRectangle(cornerRadius: 8, style: .continuous)
                        HStack(spacing: 10) {
                            tile.fill(matColor(mt.rgb)).overlay(tile.strokeBorder(G.ink.opacity(0.2), lineWidth: 1)).frame(width: 26, height: 26)
                            T(mt.name, ui(14.5, on ? 700 : 500, on ? G.cobalt2 : G.ink)).frame(maxWidth: .infinity, alignment: .leading)
                            if on { MIcon("check", G.cobalt2, 18, 2.4) }
                        }
                        .padding(.horizontal, 10).frame(minHeight: 48)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? G.cobalt.opacity(0.1) : .clear))
                        .pressable(0.98) {
                            KitOps.shared.change(p.id, f.id) { x in
                                var y = x
                                switch role { case "carcass": y.mats.carcass = mt.id; case "front": y.mats.front = mt.id; default: y.mats.back = mt.id }
                                return y
                            }
                        }
                        .accessibilityAddTraits(on ? .isSelected : [])
                        .accessibilityIdentifier("fmat." + role + "." + mt.id)
                    }
                }
            }
        }
    }
}

/* ---------------- the library ---------------- */

private struct LibrarySheet: View {
    let app: AppModel
    let pid: String, fid: String, wall: String, group: String
    @State private var tab = "low"
    @State private var w = ""
    @FocusState private var focus: KF?
    var body: some View {
        let s = AppSettings.shared, kit = KitOps.shared
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }),
           let run = kRuns(f, roomOf(p, f), s.angleSnap).first(where: { $0.wall == wall }) {
            let ws = wsOf(f, s.workshop), island = run.wall == ISLAND
            let lowLeft = fillOf(f, run, false).left, upLeft = fillOf(f, run, true).left
            // a new unit goes after the selected one of its row, else at the row's end
            let after = f.modules.first { $0.id == kit.sel && $0.wall == run.wall }
            let add = { (kind: String, width: Int?) in addUnit(kind, width, ws, run, after) }
            let title = group == "appl" ? "kt.applT" : group == "space" ? "kt.spaceT" : "kt.libT"
            GlassSheet(tr(title), onClose: { app.sheet = nil }) {
                switch group {
                case "space":
                    let free = [lowLeft, island ? nil : upLeft].compactMap { $0 }.first { $0 > 0 }
                    let wi = Int(w)
                    let ok = wi != nil && (10...1200).contains(wi!)
                    GField(label: tr("kt.spW"), value: $w, placeholder: "50", error: tr("km.bad", ["a": 10, "b": 1200]), showError: !ok && !w.isEmpty, focus: $focus, me: .a,
                           submit: .done, labelRight: tr("u.mm"), number: true, id: "lib.w")
                        .onAppear { if w.isEmpty { w = String(min(600, max(10, free ?? 50))) } }
                        .onChange(of: w) { _, v in let t = String(v.filter(\.isNumber).prefix(4)); if t != v { w = t } }
                    if let lowLeft { T(tr("kt.spLeft", ["v": lowLeft]) + (!island && upLeft != nil ? " · " + tr("kt.up") + ": \(upLeft!)" : ""), ui(13, 400, G.ink2)) }
                    LibRow(kind: "fillerLow", ws: ws, w: wi) { if ok { add("fillerLow", wi) } }
                    LibRow(kind: "spaceLow", ws: ws, w: wi) { if ok { add("spaceLow", wi) } }
                    if !island {
                        LibRow(kind: "fillerUp", ws: ws, w: wi) { if ok { add("fillerUp", wi) } }
                        LibRow(kind: "spaceUp", ws: ws, w: wi) { if ok { add("spaceUp", wi) } }
                    }
                case "appl":
                    note(false, after, lowLeft, upLeft, run)
                    ForEach(["sink", "hob", "dishwasher", "fridge"] + LIB_TALL.filter { $0 != "pantry" } + (island ? [] : ["hood", "micro"]), id: \.self) { k in
                        LibRow(kind: k, ws: ws, w: nil) { add(k, nil) }
                    }
                default:
                    Seg(items: [("low", tr("kt.gLow"))] + (island ? [] : [("up", tr("kt.gUp"))]) + [("tall", tr("kt.gTall"))], cur: tab) { tab = $0 }
                    note(tab == "up", after, lowLeft, upLeft, run)
                    let kinds = tab == "up" ? LIB_UP.filter { $0 != "hood" && $0 != "micro" } : tab == "tall" ? ["pantry"] : LIB_LOW.filter { $0 != "sink" && $0 != "hob" }
                    let widths = tab == "tall" ? [400, 450, 600] : [300, 400, 450, 500, 600, 800, 900]
                    ForEach(kinds, id: \.self) { k in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                LibGlyph(kind: k, ws: ws)
                                VStack(alignment: .leading, spacing: 1) { T(tr("kn." + k), ui(15, 700)); T(tr("kd." + k), ui(12.5, 400, G.ink2)) }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(widths, id: \.self) { wv in
                                        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        T("\(wv)", num(14, 700, G.cobalt2)).padding(.horizontal, 14).frame(minHeight: 40)
                                            .background(shape.fill(G.glass(0.8))).overlay(shape.strokeBorder(G.rim, lineWidth: 1))
                                            .pressable(0.96) { add(k, wv) }
                                            .accessibilityIdentifier("lib.\(k).\(wv)")
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.ink.opacity(0.05)))
                    }
                }
            }
        }
    }

    private func addUnit(_ kind: String, _ width: Int?, _ ws: Workshop, _ run: Run, _ after: Module?) {
        let kit = KitOps.shared
        let m = template(kind, ws, run.wall, width)
        let n = kit.change(pid, fid) { x in
            var y = x
            if let a = after, let i = y.modules.firstIndex(where: { $0.id == a.id }), isUpper(y.modules[i]) == isUpper(m) { y.modules.insert(m, at: i + 1) }
            else { y.modules.append(m) }
            return y
        }
        kit.sel = m.id
        app.sheet = nil
        if let added = n?.modules.first(where: { $0.id == m.id }) { app.say("kt.added", ["m": modName(added)]) }
    }

    @ViewBuilder private func note(_ upper: Bool, _ after: Module?, _ lowLeft: Int?, _ upLeft: Int?, _ run: Run) -> some View {
        let left = upper ? upLeft : lowLeft
        if let after, isUpper(after) == upper { T(tr("kt.afterSel", ["m": modName(after)]), ui(13, 600, G.cobalt2, lh: 1.4)) }
        if let left {
            T(left > 0 ? tr("kt.toEnd", ["w": run.wall, "v": left]) : tr("kt.toEndFull", ["w": run.wall]), ui(13, 500, left > 0 ? G.ink2 : G.amberInk, lh: 1.4))
        }
    }
}

private struct LibRow: View {
    let kind: String
    let ws: Workshop
    let w: Int?
    let action: () -> Void
    var body: some View {
        let m = template(kind, ws, "A", w)
        HStack(spacing: 10) {
            LibGlyph(kind: kind, ws: ws)
            VStack(alignment: .leading, spacing: 1) {
                T(tr("kn." + kind), ui(15, 700))
                T(tr("kd." + kind) + " · \(m.w) × \(m.h)", ui(12.5, 400, G.ink2), lines: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MIcon("plus", G.cobalt2, 20, 2.4)
        }
        .padding(.horizontal, 12).padding(.vertical, 8).frame(minHeight: 64)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.ink.opacity(0.05)))
        .pressable(0.98, action)
        .accessibilityIdentifier("lib." + kind)
    }
}

/// The unit drawn small, as it looks on the wall.
private struct LibGlyph: View {
    let kind: String
    let ws: Workshop
    var body: some View {
        let tile = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Canvas { ctx, size in
            var m = template(kind, ws, "A"); m.x = 0
            let lift = isUpper(m) ? m.elev : 0
            let H = max(m.h + m.elev - lift + (m.app == "sink" ? 300 : 0), 800)
            let lay = KLay(max(m.w, 600), H, 100, false)
            let k = min(size.width / lay.vw, size.height / lay.vh)
            m.elev -= lift; m.x = (lay.L - m.w) / 2
            var c = ctx
            c.translateBy(x: (size.width - lay.vw * k) / 2, y: (size.height - lay.vh * k) / 2); c.scaleBy(x: k, y: k)
            let front = rgbOf(AppSettings.shared.mats.first { $0.id == "ldsp16k" }?.rgb ?? "#CDBFAE")
            drawUnit(c, lay, m, ws, front, rgbOf("#F5F5F2"), max(0.8, CGFloat(ws.gap10) / 10 * lay.s))
            appliance(c, lay, m, ws)
        }
        .padding(6)
        .frame(width: 48, height: 48)
        .background(tile.fill(G.solid))
        .overlay(tile.strokeBorder(G.rim, lineWidth: 1))
    }
}

/* ---------------- a unit's settings ---------------- */

private struct ModuleSheet: View {
    let app: AppModel
    let pid: String, fid: String, mid: String
    @State private var w: String
    @State private var h: String
    @State private var d: String
    @State private var fr: String
    @State private var drawers: Int
    @State private var shelves: Int
    @State private var soft: Bool
    @State private var handles: Bool
    /// The fronts left without a handle (HandleRules.swift).
    @State private var noH: [String]
    @FocusState private var focus: KF?
    init(app: AppModel, pid: String, fid: String, mid: String) {
        self.app = app; self.pid = pid; self.fid = fid; self.mid = mid
        let m = Store.shared.get(pid)?.furniture.first { $0.id == fid }?.modules.first { $0.id == mid }
        _w = State(initialValue: String(m?.w ?? 600)); _h = State(initialValue: String(m?.h ?? 720)); _d = State(initialValue: String(m?.d ?? 560))
        let fk = m?.fronts.kind ?? "door"
        _fr = State(initialValue: fk == "drawer" ? "d" : fk == "open" ? "o" : fk == "panel" ? "p" : (m?.fronts.n ?? 1) >= 2 ? "2" : "1")
        _drawers = State(initialValue: fk == "drawer" ? (m?.fronts.n ?? 3) : 3)
        _shelves = State(initialValue: m?.inserts.filter { $0.kind == "shelf" }.reduce(0) { $0 + $1.qty } ?? 0)
        _soft = State(initialValue: m?.soft ?? true); _handles = State(initialValue: m?.handles ?? true)
        _noH = State(initialValue: m?.noHandle ?? [])
    }
    var body: some View {
        let s = AppSettings.shared, kit = KitOps.shared
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }), let m = f.modules.first(where: { $0.id == mid }) {
            let ws = wsOf(f, s.workshop)
            let run = kRuns(f, roomOf(p, f), s.angleSnap).first { $0.wall == m.wall }
            let boxed = m.type == "base" || m.type == "wall" || m.type == "tall"
            // an appliance's panels (a built-in fridge) stay as they are
            let frontsEditable = boxed && m.fronts.kind != "panel"
            let wMin = m.type == "filler" || m.type == "gap" ? 10 : 150
            let (hMin, hMax): (Int, Int) = m.type == "wall" ? (200, 1200) : m.type == "tall" ? (1200, 2500) : m.type == "filler" ? (100, 2500) : m.type == "gap" ? (300, 2200) : (300, 900)
            let wi = Int(w).flatMap { (wMin...1200).contains($0) ? $0 : nil }
            let hi = Int(h).flatMap { (hMin...hMax).contains($0) ? $0 : nil }
            let di = Int(d).flatMap { (16...800).contains($0) ? $0 : nil }
            let fronts: Fronts = fr == "d" ? Fronts("drawer", drawers) : fr == "o" ? Fronts("open", 0) : fr == "2" ? Fronts("door", 2) : fr == "1" ? Fronts("door", 1) : m.fronts
            let inserts = m.inserts.filter { $0.kind != "shelf" } + (fr != "d" && shelves > 0 && boxed ? [Insert("shelf", qty: shelves)] : [])
            let typed: Module = { var n = m; n.w = wi ?? m.w; n.h = hi ?? m.h; n.d = di ?? m.d; n.fronts = fronts; n.inserts = inserts; n.soft = soft; n.handles = handles; n.noHandle = noH; return n }()
            // new fronts: the ones chosen without a handle before are other fronts now
            let next: Module = frontsChanged(m, typed)
            let ok = wi != nil && hi != nil && di != nil
            let type = tr(m.type == "gap" ? "km.tGap" : m.type == "filler" ? "km.tFiller" : m.type == "tall" ? "km.tTall" : isUpper(m) ? "km.tUp" : "km.tLow")
            GlassSheet(modName(m), onClose: { app.sheet = nil }) {
                T(m.wall == ISLAND ? tr("km.whereI", ["t": type, "x": m.x]) : tr("km.where", ["t": type, "w": m.wall ?? "", "x": m.x]), ui(13, 400, G.ink2))
                // width: the usual sizes, or typed
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(m.type == "filler" ? [20, 30, 50, 80, 100, 150] : [300, 400, 450, 500, 600, 800, 900, 1000], id: \.self) { v in
                            FChip(label: "\(v)", on: wi == v) { w = String(v) }.accessibilityIdentifier("km.w\(v)")
                        }
                    }
                }
                HStack(alignment: .top, spacing: 8) {
                    GField(label: tr("km.w"), value: $w, placeholder: "600", error: tr("km.bad", ["a": wMin, "b": 1200]), showError: wi == nil, focus: $focus, me: .a, labelRight: tr("u.mm"), number: true, id: "km.w")
                    GField(label: tr("km.h"), value: $h, placeholder: "720", error: tr("km.bad", ["a": hMin, "b": hMax]), showError: hi == nil, focus: $focus, me: .b, labelRight: tr("u.mm"), number: true, id: "km.h")
                    GField(label: tr("km.d"), value: $d, placeholder: "560", error: tr("km.bad", ["a": 16, "b": 800]), showError: di == nil, focus: $focus, me: .c, submit: .done, labelRight: tr("u.mm"), number: true, id: "km.d")
                }
                if let run, let wi, let avail = fillOf(f, run, isUpper(m)).avail {
                    let used = fillOf(f, run, isUpper(m)).used - m.w + wi
                    let (t, c): (String, Color) = used > avail ? (tr("km.fitOver", ["w": run.wall, "v": used - avail]), G.err)
                        : used == avail ? (tr("km.fitFull", ["w": run.wall, "u": used, "a": avail]), OK_GREEN) : (tr("km.fitFree", ["w": run.wall, "v": avail - used]), G.amberInk)
                    T(t, ui(13, 600, c, lh: 1.4))
                }
                if frontsEditable {
                    T(tr("km.fronts"), ui(15, 700))
                    Seg(items: [("1", tr("km.f1")), ("2", tr("km.f2")), ("d", tr("km.fd")), ("o", tr("km.fo"))], cur: fr) { fr = $0 }
                    if fr == "d" { FStepper(label: tr("km.drawers"), v: drawers, lo: 2, hi: 5, id: "km.drawers") { drawers = $0 } }
                    else { FStepper(label: tr("km.shelves"), v: shelves, lo: 0, hi: 8, id: "km.shelves") { shelves = $0 } }
                    if fr != "o" {
                        // the unit's fronts: each one tapped to give it a handle or take it away (25 Oct 2026)
                        UnitHandles(app: app, pid: p.id, fid: f.id, mid: m.id, next: next, ws: ws, f: f, showSoft: fr != "d", soft: $soft) { x in
                            self.handles = x.handles; self.noH = x.noHandle
                        }
                    }
                }
                // what the workshop will cut and fit for it: the advanced app only
                if s.advanced {
                    let parts = partsOf(next, ws)
                    Hairline()
                    T(tr("km.parts"), ui(15, 700))
                    if parts.isEmpty { T(tr("km.noParts"), ui(13, 400, G.ink2, lh: 1.4)) }
                    ForEach(Array(parts.enumerated()), id: \.offset) { _, pt in
                        HStack {
                            T(tr(pt.key), ui(13.5, 500), lines: 1).frame(maxWidth: .infinity, alignment: .leading)
                            T("\(pt.L) × \(pt.W) × \(pt.qty)", num(13.5, 700))
                        }
                    }
                    let hw = hardwareOf(next, ws).pairs
                    if !hw.isEmpty {
                        T(tr("km.hw", ["v": hw.map { k, v in tr("hk." + k) + " × " + hwAmount(k, v, s.lang == .en) }.joined(separator: ", ")]), ui(12.5, 400, G.ink2, lh: 1.4))
                    }
                }
            } footer: {
                HStack(spacing: 8) {
                    GBtn(tr("common.delete"), kind: .danger, icon: "trash", height: 48, corner: 16, fontSize: 15) {
                        let name = modName(m)
                        kit.change(p.id, f.id) { x in var y = x; y.modules.removeAll { $0.id == m.id }; return y }
                        kit.sel = nil; app.sheet = nil
                        app.say("kt.deleted", ["m": name], action: "common.undo") { kit.undo(p.id, f.id) }
                    }
                    GBtn(tr("common.save"), enabled: ok, height: 48, corner: 16, fontSize: 15) {
                        guard ok else { return }
                        kit.change(p.id, f.id) { x in var y = x; if let i = y.modules.firstIndex(where: { $0.id == m.id }) { var n = next; n.x = y.modules[i].x; y.modules[i] = n }; return y }
                        app.sheet = nil; app.say("km.saved", ["m": modName(next)])
                    }
                    .accessibilityIdentifier("km.save")
                }
            }
            .onChange(of: w) { _, v in let t = String(v.filter(\.isNumber).prefix(4)); if t != v { w = t } }
            .onChange(of: h) { _, v in let t = String(v.filter(\.isNumber).prefix(4)); if t != v { h = t } }
            .onChange(of: d) { _, v in let t = String(v.filter(\.isNumber).prefix(3)); if t != v { d = t } }
        }
    }
}

/// A unit sheet's handles (its fronts drawn small, each tapped; "Tutqichlar" with "Hammasiga" / "Hech biriga") and its
/// soft close, with "Hammasiga" for every unit with doors. onSet takes the unit with its new handles (not saved yet).
private struct UnitHandles: View {
    let app: AppModel
    let pid: String, fid: String, mid: String
    let next: Module
    let ws: Workshop
    let f: Furniture
    let showSoft: Bool
    @Binding var soft: Bool
    let onSet: (Module) -> Void
    var body: some View {
        let next = self.next, onSet = self.onSet
        VStack(alignment: .leading, spacing: 10) {
            UnitFronts(m: next, ws: ws, f: f) { k in onSet(toggleHandle(next, k.key)) }
            T(tr("hd.tap"), ui(12.5, 400, G.ink2, lh: 1.4))
            HandleButtons(ms: [next], onAll: { onSet(allHandles(next, true)) }, onNone: { onSet(allHandles(next, false)) })
            if showSoft { softRow }
        }
    }

    private var softRow: some View {
        HStack(spacing: 8) {
            FToggle(label: tr("km.soft"), on: soft, id: "km.soft") { self.soft.toggle() }
                .frame(maxWidth: .infinity)
            GBtn(tr("hd.all"), kind: .secondary, height: 40, corner: 14, fontSize: 14, fill: false) { self.softEverywhere() }
                .accessibilityIdentifier("hd.softAll")
        }
    }

    /// Every unit with doors (and this one) closing the same.
    private func softEverywhere() {
        let on = soft, mid = self.mid
        KitOps.shared.change(pid, fid) { x in
            var y = x
            y.modules = x.modules.map { u in
                guard u.fronts.kind == "door" || u.id == mid else { return u }
                var n = u; n.soft = on
                return n
            }
            return y
        }
        app.say("hd.softAllK", ["v": tr(on ? "hd.yes" : "hd.no")])
    }
}

/* ---------------- in the workspace ---------------- */

/// The workspace's furniture as cards: a small picture of the first wall, the name, units and layout.
struct FurnitureCard: View {
    let app: AppModel
    let p: Project
    let f: Furniture
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let ward = f.kind == "wardrobe"
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                Group { if ward { WardThumb(f: f) } else { KitchenThumb(p: p, f: f) } }
                    .padding(8).frame(maxWidth: .infinity).frame(height: 129).background(PC.white)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) { MIcon(ward ? "board" : "kitchen", G.ink3, 15, 2); T(f.type.isEmpty ? tr(ward ? "kt.wardrobe" : "kt.kitchen") : tr("ft." + f.type), ui(12, 400, G.ink3), lines: 1) }
                    T(dn(f.name), ui(14.5, 600, G.ink, lh: 1.25), lines: 1)
                    if ward && (isItemPiece(f) || boxes(f).count > 1) {
                        T(pieceLine(f, AppSettings.shared.workshop), ui(12.5, 400, G.ink2), lines: 1)
                    } else if ward, let wm = wardOf(f) {
                        T(tr("wd.card", ["w": wm.w, "h": outerH(wm, AppSettings.shared.workshop), "n": wm.sections.count]), ui(12.5, 400, G.ink2), lines: 1)
                    } else {
                        T(tr("kt.card", ["n": f.modules.count, "l": tr("kt.l" + f.layout)]), ui(12.5, 400, G.ink2), lines: 1)
                    }
                }
                .padding(.leading, 10).padding(.trailing, 42).padding(.top, 8).padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                KitOps.shared.sel = nil
                app.push(ward ? .wardrobe(pid: p.id, fid: f.id, step: 1, sec: 0) : .kitchen(pid: p.id, fid: f.id, wall: nil))
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("furn.card")
            MIcon("more", G.ink, 18, 2).frame(width: 44, height: 44).pressable(0.95, label: "menu") { app.sheet = .fMenu(pid: p.id, fid: f.id) }
                .padding(.bottom, 4)
                .accessibilityIdentifier("furn.menu")
        }
        .frame(maxWidth: .infinity).frame(height: 205)
        .clipShape(shape)
        .glassCard(shape, shadowBlur: 24, shadowY: 10, shadowAlpha: 0.1)
    }
}
