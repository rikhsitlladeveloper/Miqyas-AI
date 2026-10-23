import SwiftUI
import UIKit

/*
 * A room's windows and doors (Android ui/win/WView.kt): the room in 3D with each product fitted in its opening (frame,
 * sashes, glass, handles, the sill and the drip), or from above with where the sashes and leaves sweep and what stands
 * in their way. Under it the warnings, the room's openings each with its product (or a button to fill it), and in the
 * advanced app what they take.
 */

struct WViewScreen: View {
    let app: AppModel
    let pid: String
    let rid: String
    @State private var mode = "3d"

    var body: some View {
        if let p = Store.shared.get(pid) {
            let free = rid.hasPrefix("free:")
            let calc = WinCalcCache.shared.of(p)
            let c = calc.ctxs.first { $0.id == rid }
            let room: Room? = free ? nil : p.rooms.first { $0.id == rid }
            GeometryReader { geo in
                VStack(spacing: 0) {
                    bar(p, c, room)
                    if let c { content(p, c, room, calc, free, geo.size.height) } else { needMeasure(room) }
                }
            }
            .onAppear { refitWin(pid) }
        }
    }

    private func title(_ p: Project, _ c: WCtx?) -> String {
        if let f = c?.free { return wItemTitle(f) }
        return wRoomName(p, rid)
    }

    private func bar(_ p: Project, _ c: WCtx?, _ room: Room?) -> some View {
        HStack(spacing: 6) {
            GlassIconButton("back", tr("nt.back")) { app.pop() }.padding(.leading, 6).accessibilityIdentifier("back")
            BarTitle(title: title(p, c), eyebrow: dn(p.name)).frame(maxWidth: .infinity, alignment: .leading)
            if let room { GlassIconButton("edit", tr("common.edit")) { openRoom(app, p.id, room.id) } }
        }
        .padding(.trailing, 12).frame(minHeight: 64)
        .background(G.sheet(0.55).ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
    }

    private func needMeasure(_ room: Room?) -> some View {
        VStack(spacing: 14) {
            T(tr("dw.needMeasure"), ui(16, 700, G.ink, lh: 1.35), align: .center)
            if let room { GBtn(tr("ns.measureB"), fill: false) { openRoom(app, pid, room.id) } }
        }
        .padding(24).frame(maxWidth: .infinity)
    }

    @ViewBuilder private func content(_ p: Project, _ c: WCtx, _ room: Room?, _ calc: WinCalc, _ free: Bool, _ h: CGFloat) -> some View {
        let warns = calc.warns.filter { $0.roomId == rid }
        let bad = Set(warns.compactMap(\.target))
        Seg(items: [("3d", "3D"), ("plan", tr("ed.plan"))], cur: mode) { mode = $0 }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
        Group {
            if mode == "plan" { WVPlanView(app: app, p: p, c: c, bad: bad) } else { WVRoom3D(app: app, p: p, c: c, room: room) }
        }
        .frame(height: max(160, h * 0.46))
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if !warns.isEmpty { WWarnings(app: app, p: p, ws: warns) }
                WVOpenings(app: app, p: p, c: c, bad: bad)
                if !free { addButton(p, c) }
                if AppSettings.shared.advanced { countCard(p, c) }
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 28)
        }
    }

    private func addButton(_ p: Project, _ c: WCtx) -> some View {
        HStack(spacing: 6) { MIcon("plus", G.cobalt2, 20, 2.2); T(tr("dw.addItem"), ui(15, 700, G.cobalt2), lines: 1) }
            .frame(maxWidth: .infinity).frame(height: 54)
            .dashedGlass(20)
            .pressable(0.98) { app.push(.wGallery(pid: p.id, rid: c.id)) }
            .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("wv.addItem")
    }

    @ViewBuilder private func countCard(_ p: Project, _ c: WCtx) -> some View {
        let list: [(WinItem, Int)] = wItemsIn(p, c).map { ($0, wRevealOf(c.T, wFrameDepth($0))) }
        if !list.isEmpty {
            let t = AppSettings.shared.trade.win
            let price = list.reduce(0.0) { $0 + wItemCost($1.0, $1.1, t) }
            WCountCard(title: tr("dw.roomCount"), c: wCountItems(list), price: price)
        }
    }
}

/// The room in 3D with its products, the picture's buttons over it.
private struct WVRoom3D: View {
    let app: AppModel
    let p: Project
    let c: WCtx
    let room: Room?
    @State private var cam = Cam3D()
    @State private var shot = Shot3D()
    @State private var taking = false
    @State private var wb = WinShellBox()
    var body: some View {
        let snap = AppSettings.shared.angleSnap
        let r = room ?? c.room
        let made = wb.shell(p, r, snap)
        let shell = made.0
        Scene3D(shell: shell, key: made.1, cam: cam, shot: shot, points: shell.labels.map(\.p), label: { AnyView(Lbl3D(text: shell.labels[$0].text)) }) {
            if room != nil {
                ShotPill(icon: "camera", label: tr("3d.save")) { save() }
                    .accessibilityIdentifier("3d.save")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(.top, 10).padding(.trailing, 10)
            }
            HStack(spacing: 8) {
                ForEach([("3d.top", true), ("3d.corner", false)], id: \.0) { k, top in
                    T(tr(k), ui(13, 700), lines: 1).padding(.horizontal, 12).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.sheet(0.7)))
                        .pressable(0.97) { cam.preset(top: top) }
                        .accessibilityIdentifier(k)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(10)
        }
    }

    /// "Add to report": at most 4 views a room, counted in the store; a second tap while a picture is taken does nothing.
    private func save() {
        guard let r = room else { return }
        let pid = p.id, rid = r.id
        func full() -> Bool { (Store.shared.get(pid)?.rooms.first { $0.id == rid }?.views.count ?? 4) >= 4 }
        if taking { return }
        // a double tap takes one picture, not two alike
        if !app.once() { return }
        if full() { app.say("3d.max", kind: .error); return }
        taking = true
        shot.take { img in
            DispatchQueue.main.async {
                taking = false
                if full() { app.say("3d.max", kind: .error); return }
                let id = uid()
                guard let img, let file = ViewFiles.save(id, img) else { app.say("3d.fail", kind: .error); return }
                Store.shared.update(pid) { pp in
                    if let i = pp.rooms.firstIndex(where: { $0.id == rid }), pp.rooms[i].views.count < 4 { pp.rooms[i].views.append(View3D(id: id, img: file, ts: nowMs())) }
                }
                app.say("3d.saved")
            }
        }
    }
}

/// The room from above: a tap on a product opens it.
private struct WVPlanView: View {
    let app: AppModel
    let p: Project
    let c: WCtx
    let bad: Set<String>

    var body: some View {
        let snap = AppSettings.shared.angleSnap
        let pls = wPlacedIn(p, c)
        let obs = wObstaclesIn(p, c, snap)
        let sw: [WSweep] = pls.flatMap { wSashSweeps($0) }
        GeometryReader { geo in
            let m = EPlanMap(c.g.floor, CGRect(origin: .zero, size: geo.size), 26)
            ZStack(alignment: .bottomLeading) {
                Canvas { ctx, _ in
                    let cc = self.c, b = self.bad
                    ctx.withCGContext { cg in drawWinPlan(cg, cc, m, pls, sw, obs, 9, bad: b) }
                }
                .contentShape(Rectangle())
                .onTapGesture { pos in tap(pos, m, pls) }
                T(tr("dw.planHint"), ui(11.5, 600, G.ink3)).padding(10).allowsHitTesting(false)
            }
        }
        .background(Color(argb: 0xFFF6F8FC))
    }

    private func tap(_ pos: CGPoint, _ m: EPlanMap, _ pls: [WPlaced]) {
        var best: WPlaced? = nil
        var bd = CGFloat.greatestFiniteMagnitude
        for pl in pls {
            let at = m.at(pl.w.at(pl.a0 + Double(pl.it.w) / 2, -Double(pl.r)))
            let d = hypot(at.x - pos.x, at.y - pos.y)
            if d < bd { bd = d; best = pl }
        }
        if let best, bd < 40 { app.push(.wDesign(pid: p.id, iid: best.it.id)) }
    }
}

/// The warnings, each opening its product (open) with the product's name in front.
struct WWarnings: View {
    let app: AppModel
    let p: Project
    let ws: [WWarn]
    var open = true
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                MIcon("alert", G.amberInk, 18, 2)
                T(tr("el.warnN", ["n": ws.count]), ui(15, 800, G.amberInk))
            }
            ForEach(Array(ws.enumerated()), id: \.offset) { _, w in line(w) }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(G.amberWash))
    }

    private func line(_ w: WWarn) -> some View {
        let it0 = w.target.flatMap { p.win.item($0) }
        let who: String? = open ? it0.map { wItemTitle($0) } : nil
        let text: String = who.map { $0 + ": " + wWarnText(w) } ?? wWarnText(w).capitalizedFirst
        let pid = p.id
        return T(text, ui(13, 500, G.ink, lh: 1.35))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .onTapGesture { if open, let it0 { app.push(.wDesign(pid: pid, iid: it0.id)) } }
    }
}

/// The room's openings, each with its product or a button to fill it; a product without a room on its own.
private struct WVOpenings: View {
    let app: AppModel
    let p: Project
    let c: WCtx
    let bad: Set<String>
    var body: some View {
        let items = wItemsIn(p, c)
        VStack(spacing: 0) {
            HStack {
                T(tr(c.free != nil ? "dw.item" : "dw.openings"), ui(15, 800)).frame(maxWidth: .infinity, alignment: .leading)
                T(wSummary(items), ui(12, 500, G.ink2), lines: 1)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            if let f = c.free {
                WVItemRow(app: app, p: p, it: f, sub: wSizeText(f.w, f.h) + " · " + tr("dw.qtyN", ["n": f.qty]), bad: bad.contains(f.id))
            } else {
                rows(items)
            }
        }
        .padding(.vertical, 6)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.55))
    }

    @ViewBuilder private func rows(_ items: [WinItem]) -> some View {
        if c.room.openings.isEmpty {
            T(tr("dw.noOps"), ui(13.5, 400, G.ink2)).padding(.horizontal, 14).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
        }
        ForEach(c.room.openings) { o in opening(o, items) }
        ForEach(items.filter { i in !c.room.openings.contains { $0.id == i.opening } }) { it in
            WVItemRow(app: app, p: p, it: it, sub: tr("dw.w.gone"), bad: true)
        }
    }

    @ViewBuilder private func opening(_ o: Opening, _ items: [WinItem]) -> some View {
        let head = wOpeningName(c.room, o) + " · " + tr("tl.wallN", ["w": o.wall]) + " · " + wSizeText(o.w, o.h)
        if let it0 = items.first(where: { $0.opening == o.id }) {
            WVItemRow(app: app, p: p, it: it0, sub: head + " → " + wSizeText(it0.w, it0.h), bad: bad.contains(it0.id))
        } else {
            HStack(spacing: 10) {
                MIcon(o.type == "door" ? "door" : "window", G.ink3, 20, 2)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(G.ink.opacity(0.05)))
                VStack(alignment: .leading, spacing: 1) {
                    T(head, ui(14, 700), lines: 1)
                    T(tr("dw.fillOne"), ui(12.5, 600, G.cobalt2))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                MIcon("plus", G.cobalt2, 16, 2.2)
            }
            .padding(.horizontal, 14).padding(.vertical, 6).frame(minHeight: 54)
            .contentShape(Rectangle())
            .pressable(0.99) { app.push(.wGallery(pid: p.id, rid: c.id, oid: o.id)) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
        }
    }
}

/// A product in a room's list: its little drawing, its name and its line.
private struct WVItemRow: View {
    let app: AppModel
    let p: Project
    let it: WinItem
    let sub: String
    let bad: Bool
    var body: some View {
        HStack(spacing: 10) {
            Canvas { ctx, size in
                let item = self.it, b = self.bad
                let m = WElevMap(Double(item.w), Double(item.h), CGRect(origin: .zero, size: size), 2)
                ctx.withCGContext { cg in drawWinElevation(cg, item, m, bad: b, stroke: 1) }
            }
            .frame(width: 40, height: 46)
            VStack(alignment: .leading, spacing: 1) {
                T(wItemTitle(it), ui(14, 700, bad ? G.amberInk : G.ink), lines: 1)
                T(sub, ui(12, 400, G.ink2), lines: 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MIcon("chev", G.ink3, 14, 2)
        }
        .padding(.horizontal, 14).padding(.vertical, 6).frame(minHeight: 60)
        .contentShape(Rectangle())
        .pressable(0.99) { app.push(.wDesign(pid: p.id, iid: it.id)) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
