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

    var body: some View {
        let kit = KitOps.shared
        let _ = kit.tick
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }) {
            let s = AppSettings.shared, snap = s.angleSnap, en = s.lang == .en
            let room = roomOf(p, f)
            let runs = kRuns(f, room, snap)
            let run = runs.first { $0.wall == wall } ?? runs.first
            let ws = s.workshop, mats = s.mats
            let found = checks(f, runs, ws, room?.openings ?? [], room?.points ?? [])
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
                        GlassIconButton("redo", "redo", tint: kit.canRedo(f.id) ? G.ink : PC.offIcon) { kit.redo(p.id, f.id) }
                        GlassIconButton("more", "menu") { app.sheet = .fMenu(pid: p.id, fid: f.id) }.accessibilityIdentifier("kt.menu")
                    }
                    .padding(.horizontal, 16).frame(height: 64)
                    if let room, let run {
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
                                            let n = kit.change(p.id, f.id) { x in autoFill(x, kRuns(x, room, snap).filter { $0.wall == run.wall }, ws, room.openings, room.points) }
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
                                CostCard(p: p, f: f)
                            }
                            .padding(.horizontal, 16).padding(.bottom, 28)
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
                GBtn(tr("kt.left"), kind: .secondary, icon: "back", enabled: i > 0, height: 44, corner: 14, fontSize: 14) { move(-1) }.accessibilityIdentifier("kt.moveL")
                GBtn(tr("kt.right"), kind: .secondary, icon: "chev", enabled: i < row.count - 1, height: 44, corner: 14, fontSize: 14) { move(1) }.accessibilityIdentifier("kt.moveR")
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
        if !f.modules.isEmpty {
            let s = AppSettings.shared
            let cost = costOf([f], s.workshop, s.mats, s.hws, order: false)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    T(tr("kt.cost"), ui(14.5, 700)).frame(maxWidth: .infinity, alignment: .leading)
                    T(Money.str(cost.total, p.precision, s.lang == .en) + " " + Money.cur(p.currency), num(17, 800)).accessibilityIdentifier("kt.costV")
                }
                T(tr(f.kind == "kitchen" ? "kt.costNote" : "wd.costNote"), ui(12.5, 400, G.ink2, lh: 1.4))
                if cost.missing > 0 { T(tr("kt.noPrice", ["n": cost.missing]), ui(12.5, 600, G.amberInk)) }
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
        switch s { case .newFurniture, .fMenu, .fRename, .fMats, .fModule, .fLibrary: return true; default: return false }
    }
    var body: some View {
        switch sheet {
        case .newFurniture(let pid, let wid): NewFurnitureSheet(app: app, pid: pid, wid: wid)
        case .fMenu(let pid, let fid): FMenuSheet(app: app, pid: pid, fid: fid)
        case .fRename(let pid, let fid): FRenameSheet(app: app, pid: pid, fid: fid)
        case .fMats(let pid, let fid): FMatsSheet(app: app, pid: pid, fid: fid)
        case .fModule(let pid, let fid, let mid): ModuleSheet(app: app, pid: pid, fid: fid, mid: mid)
        case .fLibrary(let pid, let fid, let wall, let group): LibrarySheet(app: app, pid: pid, fid: fid, wall: wall, group: group)
        default: EmptyView()
        }
    }
}

private let LAYOUT_ICON = ["I": "M3 9h18", "L": "M3 6h18v13", "U": "M3 19V6h18v13", "O": "M3 6h18 M8 16h8", "P": "M3 6h18v4 M12 6v12"]

/// The wall combinations a layout can take in a room with walls ids: consecutive walls, or a wall and the island.
private func combos(_ layout: String, _ ids: [String]) -> [[String]] {
    let n = ids.count
    switch layout {
    case "L": return n >= 2 ? ids.indices.map { [ids[$0], ids[($0 + 1) % n]] } : []
    case "U": return n >= 3 ? ids.indices.map { [ids[$0], ids[($0 + 1) % n], ids[($0 + 2) % n]] } : []
    case "O", "P": return ids.map { [$0, ISLAND] }
    default: return ids.map { [$0] }
    }
}

private struct NewFurnitureSheet: View {
    let app: AppModel
    let pid: String, wid: String
    @State private var rid: String? = nil
    @State private var kind = "kitchen"
    @State private var layout = "L"
    @State private var combo = 0
    var body: some View {
        if let p = Store.shared.get(pid) {
            let s = AppSettings.shared, snap = s.angleSnap, en = s.lang == .en
            let rooms = p.rooms.filter { $0.floorId == wid }
            let room = rooms.first { $0.id == rid } ?? rooms.first
            let ids = room.map { Geo.walls($0, snap).map(\.id) } ?? []
            let list = combos(layout, ids)
            let pick = combo < list.count ? list[combo] : list.first
            GlassSheet(tr("kt.addT"), onClose: { app.sheet = nil }) {
                T(tr("kt.type"), ui(15, 700))
                HStack(spacing: 8) {
                    ForEach([("kitchen", "kt.kitchen"), ("wardrobe", "kt.wardrobe"), ("living", "kt.living"), ("bedroom", "kt.bedroom")], id: \.0) { k, t in
                        let on = k == kind, later = k != "kitchen"
                        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
                        VStack(spacing: 4) {
                            MIcon(k == "kitchen" ? "kitchen" : "board", on ? G.cobalt : G.ink3, 24, 2)
                            T(tr(t), ui(11, on ? 700 : 600, later ? G.ink3 : G.ink), align: .center, lines: 2)
                            if later {
                                T(tr("kt.later"), ui(10.5, 700, G.ink2)).padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(RoundedRectangle(cornerRadius: 8).fill(G.ink3.opacity(0.14)))
                            }
                        }
                        .padding(.horizontal, 2).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, minHeight: 84)
                        .background(shape.fill(on ? G.cobalt.opacity(0.1) : G.glass(0.5)))
                        .overlay(shape.strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 2 : 1))
                        .pressable(0.97) {
                            // the wardrobe designer comes with the next part; living rooms and bedrooms in Stage 2
                            if k == "wardrobe" { app.say("kt.wardLater", kind: .info) }
                            else if later { app.say("kt.stage2", ["n": tr(t)], kind: .info) }
                            else { kind = k; combo = 0 }
                        }
                        .accessibilityAddTraits(on ? .isSelected : [])
                        .accessibilityIdentifier("nf." + k)
                    }
                }
                if let room {
                    if rooms.count > 1 {
                        T(tr("kt.room"), ui(15, 700))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) { ForEach(rooms) { r in FChip(label: dn(r.name), on: r.id == room.id) { rid = r.id; combo = 0 } } }
                        }
                    }
                    T(tr("kt.layout"), ui(15, 700))
                    HStack(spacing: 6) {
                        ForEach(["I", "L", "U", "O", "P"], id: \.self) { l in
                            let on = l == layout, shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
                            VStack(spacing: 6) {
                                PathIcon(LAYOUT_ICON[l]!, on ? G.cobalt : G.ink, 26, 2.4)
                                T(tr("kt.l" + l), ui(11.5, on ? 700 : 500, on ? G.cobalt2 : G.ink), align: .center, lines: 2)
                            }
                            .padding(.vertical, 8).padding(.horizontal, 2)
                            .frame(maxWidth: .infinity, minHeight: 72)
                            .background(shape.fill(on ? G.cobalt.opacity(0.1) : G.glass(0.5)))
                            .overlay(shape.strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 2 : 1))
                            .pressable(0.97) { layout = l; combo = 0 }
                            .accessibilityAddTraits(on ? .isSelected : [])
                            .accessibilityIdentifier("nf.l" + l)
                        }
                    }
                    T(tr("kt.walls"), ui(15, 700))
                    if list.isEmpty { T(tr("kt.noRoom"), ui(13.5, 400, G.ink2, lh: 1.4)) }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(list.enumerated()), id: \.offset) { i, c in
                                let label = c.map { w in
                                    w == ISLAND ? tr(layout == "P" ? "kt.peninsula" : "kt.island") : w + (layout == "I" ? wallLen(room, snap, w).map { " · \($0)" } ?? "" : "")
                                }.joined(separator: " + ")
                                FChip(label: label, on: c == pick) { combo = i }.accessibilityIdentifier("nf.c\(i)")
                            }
                        }
                    }
                    if let pick {
                        let lens = pick.filter { $0 != ISLAND }.map { ($0, wallLen(room, snap, $0)) }
                        let total = lens.reduce(0) { $0 + ($1.1 ?? 0) }
                        T(lens.map { "\($0.0) \($0.1.map(String.init) ?? "?")" }.joined(separator: " + ") + " → " + metres1(total, en) + " " + tr("kt.pm"), num(15, 700))
                        ForEach(pick.filter { $0 != ISLAND && !measured(room, snap, $0) }, id: \.self) { w in T(tr("kt.noLen", ["w": w]), ui(12.5, 500, G.amberInk, lh: 1.4)) }
                        if pick.contains(ISLAND) { T(tr("kt.islandNote"), ui(12.5, 400, G.ink2, lh: 1.4)) }
                    }
                    GBtn(tr("kt.start"), enabled: pick != nil) {
                        guard let walls = pick else { return }
                        let n = p.furniture.filter { $0.kind == "kitchen" }.count + 1
                        let f = Furniture(id: uid(), kind: "kitchen", name: tr("kt.nameN", ["n": n]), roomId: room.id, walls: walls, created: nowMs(), layout: layout, ws: wid)
                        let moved = p.stage == "measure"
                        Store.shared.update(p.id) { pr in pr.furniture.append(f); if pr.stage == "measure" { pr.stage = "design" } }
                        app.sheet = nil; KitOps.shared.sel = nil
                        app.push(.kitchen(pid: p.id, fid: f.id, wall: nil))
                        if moved { app.say("kt.stageTo", ["s": tr("fs.design")]) }
                    }
                    .accessibilityIdentifier("nf.start")
                } else {
                    T(tr("kt.noRoom"), ui(14, 400, G.ink2, lh: 1.45))
                    GBtn(tr("kt.drawRoom"), icon: "room") { app.sheet = .newRoom(pid: p.id, wid: wid) }
                }
            }
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
            let ws = s.workshop, island = run.wall == ISLAND
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
                           submit: .done, labelRight: "mm", number: true, id: "lib.w")
                        .onAppear { if w.isEmpty { w = String(min(600, max(10, free ?? 50))) } }
                        .onChange(of: w) { _, v in let t = String(v.filter(\.isNumber).prefix(4)); if t != v { w = t } }
                    if let lowLeft { T(tr("kt.spLeft", ["v": lowLeft]) + (!island && upLeft != nil ? " · " + tr("kt.up") + ": \(upLeft!)" : ""), ui(13, 400, G.ink2)) }
                    LibRow(kind: "fillerLow", ws: ws, w: wi) { if ok { add("fillerLow", wi) } }
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
    }
    var body: some View {
        let s = AppSettings.shared, kit = KitOps.shared
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }), let m = f.modules.first(where: { $0.id == mid }) {
            let ws = s.workshop
            let run = kRuns(f, roomOf(p, f), s.angleSnap).first { $0.wall == m.wall }
            let boxed = m.type == "base" || m.type == "wall" || m.type == "tall"
            // an appliance's panels (a built-in fridge) stay as they are
            let frontsEditable = boxed && m.fronts.kind != "panel"
            let wMin = m.type == "filler" ? 10 : 150
            let (hMin, hMax): (Int, Int) = m.type == "wall" ? (200, 1200) : m.type == "tall" ? (1200, 2500) : m.type == "filler" ? (100, 2500) : m.type == "gap" ? (300, 2200) : (300, 900)
            let wi = Int(w).flatMap { (wMin...1200).contains($0) ? $0 : nil }
            let hi = Int(h).flatMap { (hMin...hMax).contains($0) ? $0 : nil }
            let di = Int(d).flatMap { (16...800).contains($0) ? $0 : nil }
            let fronts: Fronts = fr == "d" ? Fronts("drawer", drawers) : fr == "o" ? Fronts("open", 0) : fr == "2" ? Fronts("door", 2) : fr == "1" ? Fronts("door", 1) : m.fronts
            let inserts = m.inserts.filter { $0.kind != "shelf" } + (fr != "d" && shelves > 0 && boxed ? [Insert("shelf", qty: shelves)] : [])
            let next: Module = { var n = m; n.w = wi ?? m.w; n.h = hi ?? m.h; n.d = di ?? m.d; n.fronts = fronts; n.inserts = inserts; n.soft = soft; n.handles = handles; return n }()
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
                    GField(label: tr("km.w"), value: $w, placeholder: "600", error: tr("km.bad", ["a": wMin, "b": 1200]), showError: wi == nil, focus: $focus, me: .a, labelRight: "mm", number: true, id: "km.w")
                    GField(label: tr("km.h"), value: $h, placeholder: "720", error: tr("km.bad", ["a": hMin, "b": hMax]), showError: hi == nil, focus: $focus, me: .b, labelRight: "mm", number: true, id: "km.h")
                    GField(label: tr("km.d"), value: $d, placeholder: "560", error: tr("km.bad", ["a": 16, "b": 800]), showError: di == nil, focus: $focus, me: .c, submit: .done, labelRight: "mm", number: true, id: "km.d")
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
                        FToggle(label: tr("km.handles"), on: handles, id: "km.handles") { handles.toggle() }
                        if fr != "d" { FToggle(label: tr("km.soft"), on: soft, id: "km.soft") { soft.toggle() } }
                    }
                }
                // what the workshop will cut and fit for it
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
                    T(tr("km.hw", ["v": hw.map { k, v in tr("hk." + k) + " × " + (k == "rail" ? "\(v) mm" : "\(v)") }.joined(separator: ", ")]), ui(12.5, 400, G.ink2, lh: 1.4))
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

/* ---------------- in the workspace ---------------- */

/// The workspace's furniture as cards: a small picture of the first wall, the name, units and layout.
struct FurnitureCard: View {
    let app: AppModel
    let p: Project
    let f: Furniture
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                KitchenThumb(p: p, f: f).padding(8).frame(maxWidth: .infinity).frame(height: 129).background(PC.white)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) { MIcon("kitchen", G.ink3, 15, 2); T(tr("kt.kitchen"), ui(12, 400, G.ink3), lines: 1) }
                    T(dn(f.name), ui(14.5, 600, G.ink, lh: 1.25), lines: 1)
                    T(tr("kt.card", ["n": f.modules.count, "l": tr("kt.l" + f.layout)]), ui(12.5, 400, G.ink2), lines: 1)
                }
                .padding(.leading, 10).padding(.trailing, 42).padding(.top, 8).padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onTapGesture { KitOps.shared.sel = nil; app.push(.kitchen(pid: p.id, fid: f.id, wall: nil)) }
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
