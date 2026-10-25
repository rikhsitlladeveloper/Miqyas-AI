import SwiftUI

/*
 * The gorka's and the big dining table's own options (modern 3D part 6a; Android ui/furniture/GorkaViews.kt; the
 * rules in Furniture/Core/Gorka.swift). The gorka has the wardrobe designer for its boxes (sections, doors, inside,
 * materials) and this card over it: two towers or one, the bridge, glass doors, LED, the cornice, the TV panel's
 * facing and the TV. The big table has the short designer of tables with its seats, legs, top and the chairs' fabric.
 */

/// Changes piece fid of order pid (the designer's undo list keeps the version before).
private func gkChange(_ pid: String, _ fid: String, _ fn: (Furniture) -> Furniture) { KitOps.shared.change(pid, fid, fn) }

/// The piece built again with one step value changed (the boxes' own changes are reset, as with new sizes).
private func gkRebuild(_ pid: String, _ fid: String, _ k: String, _ x: Int) {
    let ws = AppSettings.shared.workshop
    gkChange(pid, fid) { pieceResized($0, [k: x], ws) }
}

/// A row of chips that scrolls sideways, cur the one on.
private struct GkChipRow: View {
    let items: [(String, String)]
    let cur: String
    let onPick: (String) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.0) { it in chip(it.0, it.1) }
            }
            .padding(.vertical, 2)
        }
    }
    private func chip(_ k: String, _ label: String) -> some View {
        let pick = onPick
        return FChip(label: label, on: k == cur) { pick(k) }.accessibilityIdentifier("gk.ch." + k)
    }
}

/// The gorka's card in its designer.
struct GorkaCard: View {
    let app: AppModel
    let p: Project, f: Furniture
    var body: some View {
        if gorkaRoles(f) != nil {
            VStack(alignment: .leading, spacing: 10) {
                T(tr("gk.title"), ui(15.5, 800))
                GkBuild(p: p, f: f)
                GkLook(p: p, f: f)
                GkPanel(p: p, f: f)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.6))
            .accessibilityIdentifier("gk.card")
        }
    }
}

/// The towers (two or one) and the bridge: they build the gorka again.
private struct GkBuild: View {
    let p: Project, f: Furniture
    var body: some View {
        let v = gorkaVals(f, AppSettings.shared.workshop)
        let one = v["one"] == 1, bridge = v["nobr"] != 1
        let pid = p.id, fid = f.id
        VStack(alignment: .leading, spacing: 10) {
            T(tr("gk.towers"), ui(14.5, 700))
            Seg(items: [("2", tr("gk.towers.2")), ("1", tr("gk.towers.1"))], cur: one ? "1" : "2") { k in
                if (k == "1") != one { gkRebuild(pid, fid, "one", k == "1" ? 1 : 0) }
            }
            FToggle(label: tr("gk.bridge"), on: bridge, id: "gk.bridge") { gkRebuild(pid, fid, "nobr", bridge ? 1 : 0) }
            T(tr("gk.rebuild"), ui(12, 400, G.ink2, lh: 1.4))
        }
    }
}

/// Glass doors, the LED strips and the neoclassic cornice.
private struct GkLook: View {
    let p: Project, f: Furniture
    var body: some View {
        let pid = p.id, fid = f.id
        let glass = gorkaGlass(f), led = f.look?.led == true, cornice = f.look?.crown == "cornice"
        VStack(alignment: .leading, spacing: 10) {
            FToggle(label: tr("gk.glass"), on: glass, id: "gk.glass") { gkChange(pid, fid) { withGorkaGlass($0, !gorkaGlass($0)) } }
            FToggle(label: tr("gk.led"), on: led, id: "gk.led") { gkChange(pid, fid) { withLook($0) { l in var n = l; n.led.toggle(); return n } } }
            FToggle(label: tr("gk.cornice"), on: cornice, id: "gk.cornice") {
                gkChange(pid, fid) { withLook($0) { l in var n = l; n.crown = l.crown == "cornice" ? "" : "cornice"; return n } }
            }
        }
    }
}

/// The TV panel's facing (a stone slab's decor too) and the TV, with whether it fits.
private struct GkPanel: View {
    let p: Project, f: Furniture
    var body: some View {
        let pid = p.id, fid = f.id
        let panel = gorkaRoles(f)?.panel
        let pn0 = panel?.opt?.panel ?? ""
        let pn = pn0.isEmpty ? "stone" : pn0
        let tv0 = panel?.opt?.tv ?? 0
        let tv = tv0 > 0 ? tv0 : 65
        VStack(alignment: .leading, spacing: 10) {
            T(tr("gk.panelT"), ui(14.5, 700))
            Seg(items: GK_PANELS.map { ($0, tr("gk.pn." + $0)) }, cur: pn, lines: 2) { k in gkChange(pid, fid) { withGorkaPanel($0, panel: k) } }
            T(tr("gk.pn." + pn + ".s"), ui(12.5, 400, G.ink2, lh: 1.4))
            if pn == "stone" { GkStone(p: p, f: f) }
            T(tr("gk.tv"), ui(14.5, 700))
            GkChipRow(items: GK_TVS.map { ("\($0)", tr("gk.tv.\($0)")) }, cur: "\(tv)") { k in
                if let n = Int(k) { gkChange(pid, fid) { withGorkaPanel($0, tv: n) } }
            }
            if let panel {
                let fits = tvFits(f)
                T(tr(fits ? "gk.tvFits" : "gk.tvWide", ["t": tvSize(tv).0, "p": panel.w]), ui(12.5, 400, fits ? G.ink2 : G.err, lh: 1.4))
            }
        }
    }
}

/// The stone slab's decor: marble, onyx or dark stone (the piece's worktop board).
private struct GkStone: View {
    let p: Project, f: Furniture
    var body: some View {
        let pid = p.id, fid = f.id
        let d = worktopDecor(f.mats.top)
        let cur = ["marble", "onyx", "dark"].contains(d) ? d : "marble"
        GkChipRow(items: ["marble", "onyx", "dark"].map { ($0, tr("lk.st." + $0)) }, cur: cur) { k in
            gkChange(pid, fid) { g in var x = withLook(g) { $0 }; x.mats.top = worktopFor("stone", k); return x }
        }
    }
}

/* ---------------- the big dining table ---------------- */

/// The big table's options in the short designer: its sizes, seats, legs, top and the chairs' fabric.
struct BigTableOptions: View {
    let app: AppModel
    let p: Project, f: Furniture, m: Module
    var body: some View {
        let o = m.opt ?? ItemOpt()
        let pid = p.id, fid = f.id
        let seated = seatsOf(m)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(["w", "d", "h"], id: \.self) { k in sizeRow(k) }
            T(tr("dt.st"), ui(14.5, 700))
            Seg(items: DT_SEATS.map { ("\($0)", tr("dt.st.\($0)")) }, cur: "\(o.seats)") { k in
                if let n = Int(k), let i = DT_SEATS.firstIndex(of: n) { gkRebuild(pid, fid, "st", i) }
            }
            T(seated < o.seats ? tr("dt.short", ["n": o.seats, "m": seated]) : tr("dt.seated", ["n": seated]),
              ui(12.5, 400, seated < o.seats ? G.err : G.ink2, lh: 1.4))
            T(tr("fb.lg"), ui(14.5, 700))
            Seg(items: DT_LEGS.map { ($0, tr("fb.lg." + $0)) }, cur: o.legs, lines: 2) { k in
                if let i = DT_LEGS.firstIndex(of: k) { gkRebuild(pid, fid, "lg", i) }
            }
            BigTableTop(p: p, f: f)
            BigTableFabric(p: p, f: f)
        }
    }
    private func sizeRow(_ k: String) -> some View {
        let label = k == "w" ? "wd.w" : k == "d" ? "wd.d" : "fz.wH"
        let now = k == "w" ? m.w : k == "d" ? m.d : m.h
        let a = app, pid = p.id, fid = f.id, mid = m.id
        return WValRow(label: tr(label), value: "\(now)" + U_MM, id: "it." + k) { a.sheet = .iField(pid: pid, fid: fid, mid: mid, key: k) }
    }
}

/// The big table's top: stone or wood, and its decor.
private struct BigTableTop: View {
    let p: Project, f: Furniture
    var body: some View {
        let pid = p.id, fid = f.id
        let tk = worktopKind(f.mats.top) == "wood" ? "wood" : "stone"
        let decors: [(String, String)] = tk == "wood" ? ["halifax", "craft"].map { ($0, tr("lk.w." + $0)) } : ["marble", "onyx", "dark"].map { ($0, tr("lk.st." + $0)) }
        VStack(alignment: .leading, spacing: 10) {
            T(tr("dt.tk"), ui(14.5, 700))
            Seg(items: [("stone", tr("dt.tk.stone")), ("wood", tr("dt.tk.wood"))], cur: tk) { k in gkRebuild(pid, fid, "tk", k == "wood" ? 1 : 0) }
            GkChipRow(items: decors, cur: worktopDecor(f.mats.top)) { k in
                gkChange(pid, fid) { g in var x = withLook(g) { $0 }; x.mats.top = worktopFor(tk, k); return x }
            }
        }
    }
}

/// The chairs' fabric (the look's, as a bed's), and that the chairs are only drawn.
private struct BigTableFabric: View {
    let p: Project, f: Furniture
    var body: some View {
        let pid = p.id, fid = f.id
        VStack(alignment: .leading, spacing: 10) {
            T(tr("dt.fabric"), ui(14.5, 700))
            GkChipRow(items: LOOK_FABRICS.map { ($0.key, tr("lk.fab." + $0.key)) }, cur: f.look?.fabric ?? "") { k in
                gkChange(pid, fid) { withLook($0) { l in var n = l; n.fabric = k; return n } }
            }
            T(tr("dt.chairsNote"), ui(12, 400, G.ink2, lh: 1.4))
        }
    }
}
