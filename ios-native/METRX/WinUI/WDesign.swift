import SwiftUI
import UIKit

/*
 * A product's designer (22 Oct 2026; Android ui/win/WDesign.kt): its drawing from inside, a sash tapped to choose it
 * and the mullions dragged to move them (or their positions typed); each sash's way of opening and hinge side; its size
 * (from its opening less the gap, or typed); the profile, glass and colours; the extras; a door's hinge side and swing.
 * The same product in a piece of wall in 3D, and in its room. Every change is saved at once.
 */

struct WDesignScreen: View {
    let app: AppModel
    let pid: String
    let iid: String
    @State private var mode = "draw"
    @State private var selC = 0
    @State private var selR = 0
    /// The product as a mullion is being dragged (saved when it is let go).
    @State private var drag: WinItem? = nil

    var body: some View {
        if let p = Store.shared.get(pid), let it0 = p.win.item(iid) {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    bar(p, it0)
                    content(p, it0, geo.size.height)
                }
            }
            .onAppear { refitWin(pid) }
        }
    }

    private func viewRid(_ it: WinItem) -> String { it.inRoom ? (it.roomId ?? "") : "free:" + it.id }

    private func bar(_ p: Project, _ it0: WinItem) -> some View {
        let snap = AppSettings.shared.angleSnap
        var whr = tr("dw.noRoom")
        if it0.inRoom {
            whr = wRoomName(p, it0.roomId)
            if let c = wCtxOf(p, it0.roomId ?? "", snap), let pl = wPlaced(c, it0) { whr += " · " + wOpeningName(c.room, pl.o) }
        }
        return HStack(spacing: 6) {
            GlassIconButton("back", tr("nt.back")) { app.pop() }.padding(.leading, 6).accessibilityIdentifier("back")
            BarTitle(title: wItemTitle(it0), eyebrow: whr).frame(maxWidth: .infinity, alignment: .leading)
            GlassIconButton("cube", tr("dw.inRoom")) { app.push(.wView(pid: p.id, rid: viewRid(it0))) }
        }
        .padding(.trailing, 12).frame(minHeight: 64)
        .background(G.sheet(0.55).ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
    }

    @ViewBuilder private func content(_ p: Project, _ it0: WinItem, _ h: CGFloat) -> some View {
        let snap = AppSettings.shared.angleSnap
        let c: WCtx? = it0.inRoom ? wCtxOf(p, it0.roomId ?? "", snap) : wFreeCtx(it0)
        let pl: WPlaced? = c.flatMap { wPlaced($0, it0) }
        let wallT = c?.T ?? it0.freeT
        let R = wRevealOf(wallT, wFrameDepth(it0))
        let floor = pl?.doorOpening ?? (it0.isDoor || it0.kind == "balc")
        let warns = WinCalcCache.shared.of(p).warns.filter { $0.target == it0.id }
        let ci = selC < it0.cols.count ? selC : 0
        let rowsN = ci < it0.cols.count ? it0.cols[ci].rows.count : 1
        let ri = selR < rowsN ? selR : 0
        let shown = drag ?? it0
        Seg(items: [("draw", tr("dw.draw")), ("3d", "3D")], cur: mode) { mode = $0 }
            .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
        view(shown, wallT, floor, ci, ri, !warns.isEmpty)
            .frame(height: max(180, h * 0.42))
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color(argb: 0xFFF6F8FC)))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
            .padding(.horizontal, 16)
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if !warns.isEmpty { WWarnings(app: app, p: p, ws: warns, open: false) }
                if !it0.isDoor { WDSashCard(it: it0, ci: ci, ri: ri, onSel: { a, b in selC = a; selR = b }, upd: upd) }
                WDSizeCard(app: app, pid: p.id, it: it0, o: it0.inRoom ? pl?.o : nil, ci: ci)
                    .id([AnyHashable(it0), AnyHashable(ci)])
                if it0.isDoor { WDDoorCard(it: it0, upd: upd) } else { WDProfileCard(it: it0, upd: upd) }
                if !it0.isDoor { WDExtrasCard(app: app, it: it0, r: R, floor: floor, upd: upd).id(it0.sill) }
                if AppSettings.shared.advanced {
                    let t = AppSettings.shared.trade.win
                    WCountCard(title: tr("dw.itemCount"), c: wCountItems([(it0, R)]), price: wItemCost(it0, R, t))
                }
                GBtn(tr("dw.inRoom"), kind: .secondary, icon: "cube", height: 46, fontSize: 14.5) { app.push(.wView(pid: p.id, rid: viewRid(it0))) }
                GBtn(tr("common.delete"), kind: .danger, icon: "trash", height: 46, fontSize: 14.5) { delete(p, it0) }
                    .accessibilityIdentifier("dw.delete")
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder private func view(_ shown: WinItem, _ wallT: Int, _ floor: Bool, _ ci: Int, _ ri: Int, _ bad: Bool) -> some View {
        if mode == "3d" {
            ZStack(alignment: .bottomTrailing) {
                WPicView(spec: WPicSpec(it: shown, t: wallT, floor: floor), lo: -1.1, hi: 0.7)
                T(tr("fx.drag"), ui(11, 600, G.ink3)).padding(10).allowsHitTesting(false)
            }
        } else {
            let sel: (Int, Int)? = shown.isDoor ? nil : (ci, ri)
            WDElevation(it: shown, sel: sel, bad: bad,
                        onPick: { a, b in selC = a; selR = b },
                        onDrag: { d in drag = d },
                        onDrop: { d in
                            drag = nil
                            if let d { upd { _ in d } }
                        })
        }
    }

    private func upd(_ f: @escaping (WinItem) -> WinItem) { updateWinItem(pid, iid, f) }

    private func delete(_ p: Project, _ it0: WinItem) {
        guard let items = Store.shared.get(p.id)?.win.items, let at = items.firstIndex(where: { $0.id == it0.id }) else { return }
        let gone = items[at], id = it0.id, p0 = p.id
        updateWin(p0) { e in e.items.removeAll { $0.id == id } }
        app.pop()
        // Undo puts back only this product, where it was
        app.say("dw.deleted", action: "common.undo", onAction: {
            updateWin(p0) { e in if !e.items.contains(where: { $0.id == gone.id }) { e.items = e.items.putBack(gone, at: at) } }
        })
    }
}

/* ---------------- the drawing ---------------- */

/// The drawing: a tap picks a sash, a mullion or transom is dragged along.
private struct WDElevation: View {
    let it: WinItem
    let sel: (Int, Int)?
    let bad: Bool
    let onPick: (Int, Int) -> Void
    let onDrag: (WinItem?) -> Void
    let onDrop: (WinItem?) -> Void
    @State private var grab: WBar? = nil
    @State private var start: WinItem? = nil
    @State private var started = false

    private func map(_ size: CGSize) -> WElevMap {
        WElevMap(Double(it.w), Double(it.h), CGRect(origin: .zero, size: size), 30, 36, 12)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                Canvas { ctx, size in draw(ctx, size) }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { v in changed(v, geo.size) }.onEnded { v in ended(v, geo.size) })
                T(tr(it.isDoor ? "dw.drawDoor" : "dw.drawHint"), ui(11, 600, G.ink3)).padding(.leading, 10).padding(.bottom, 4).allowsHitTesting(false)
            }
        }
        .accessibilityLabel("drawing")
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize) {
        let m = map(size)
        let item = it, s = sel, b = bad
        let big: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11, weight: .bold), .foregroundColor: uiColor(0x334155)]
        let sm: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9, weight: .medium), .foregroundColor: uiColor(0x475569)]
        let label: (String) -> NSAttributedString = { t in NSAttributedString(string: t, attributes: big) }
        let small: (String) -> NSAttributedString = { t in NSAttributedString(string: t, attributes: sm) }
        ctx.withCGContext { cg in
            drawWinElevation(cg, item, m, sel: s, bad: b, label: label, small: small, stroke: 1.6)
        }
    }

    /// The mullion or transom nearest q (mm), within reach.
    private func barAt(_ q: V2, _ reach: Double) -> WBar? {
        var best: WBar? = nil
        var bd = Double.greatestFiniteMagnitude
        for b in wBarsOf(it) {
            let d: Double
            if b.vertical {
                if q.y < b.y0 || q.y > b.y1 { continue }
                d = abs(q.x - b.x0)
            } else {
                if q.x < b.x0 || q.x > b.x1 { continue }
                d = abs(q.y - b.y0)
            }
            if d < reach && d < bd { bd = d; best = b }
        }
        return best
    }

    private func changed(_ v: DragGesture.Value, _ size: CGSize) {
        let m = map(size)
        if !started {
            started = true
            start = it
            grab = barAt(m.back(v.startLocation), 22 / m.k)
        }
        guard let b = grab, let s0 = start, hypot(v.translation.width, v.translation.height) > 4 else { return }
        let q = m.back(v.location)
        if b.vertical {
            onDrag(wMoveMullion(s0, b.col, wdSnap5(q.x)))
        } else {
            onDrag(wMoveTransom(s0, b.col, b.row, wdSnap5(Double(s0.h) - q.y)))
        }
    }

    private func ended(_ v: DragGesture.Value, _ size: CGSize) {
        let moved = hypot(v.translation.width, v.translation.height) > 4
        let had = grab != nil
        grab = nil; start = nil; started = false
        if moved {
            onDrop(had ? it : nil)
            return
        }
        onDrop(nil)
        let q = map(size).back(v.startLocation)
        if let s = wSashesOf(it).first(where: { q.x >= $0.r.x0 && q.x <= $0.r.x1 && q.y >= $0.r.y0 && q.y <= $0.r.y1 }) { onPick(s.col, s.row) }
    }
}

/// mm to the nearest 5.
private func wdSnap5(_ v: Double) -> Int { tInt(eMathRoundP(v / 5)) * 5 }

/* ---------------- the cards ---------------- */

private struct WDCardBox<Content: View>: View {
    let title: String
    var sub: String? = nil
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                T(title, ui(15, 800)).frame(maxWidth: .infinity, alignment: .leading)
                if let sub { T(sub, ui(12.5, 500, G.ink2)) }
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.6))
    }
}

/// The chosen sash: how it opens, its hinge side; a mullion or transom added or taken away.
private struct WDSashCard: View {
    let it: WinItem
    let ci: Int
    let ri: Int
    let onSel: (Int, Int) -> Void
    let upd: (@escaping (WinItem) -> WinItem) -> Void

    var body: some View {
        let ss = wSashesOf(it)
        let idx = max(0, ss.firstIndex { $0.col == ci && $0.row == ri } ?? 0)
        if idx < ss.count {
            let s = ss[idx]
            WDCardBox(title: tr("dw.sashN", ["n": idx + 1]), sub: "\(tInt(eMathRoundP(s.r.w))) × \(tInt(eMathRoundP(s.r.h)))") {
                if ss.count > 1 { pickRow(ss, idx) }
                FlowLayout(spacing: 8) {
                    ForEach(W_SASH_TYPES, id: \.self) { t in FChip(label: tr("dw.t." + t), on: s.t == t) { setType(t) } }
                }
                if s.t == "turn" || s.t == "tt" || s.t == "slide" { hinges(s) }
                T(tr("dw.tS." + s.t), ui(12.5, 400, G.ink2, lh: 1.35))
                buttons(ss.count)
            }
        }
    }

    private func pickRow(_ ss: [WSash], _ idx: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(ss.enumerated()), id: \.offset) { i, x in FChip(label: "\(i + 1)", on: i == idx) { onSel(x.col, x.row) } }
            }
        }
    }

    private func hinges(_ s: WSash) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(["L", "R"], id: \.self) { h in
                FChip(label: tr(s.t == "slide" ? "dw.slide" + h : "dw.hinge" + h), on: s.cell.hinge == h) { setHinge(h) }
            }
        }
    }

    private func buttons(_ n: Int) -> some View {
        let a = ci, b = ri
        return HStack(spacing: 8) {
            // too narrow (low) to split: it says why instead of making a sash with no room for its glass
            GBtn(tr("dw.addV"), kind: .secondary, height: 42, corner: 14, fontSize: 13.5, lines: 2) {
                if wCanSplitCol(it, a) { upd { w in wSplitCol(w, a) } } else { AppModel.shared.say("dw.tooNarrow", ["n": 2 * W_SPLIT_MIN], kind: .error) }
            }
            GBtn(tr("dw.addH"), kind: .secondary, height: 42, corner: 14, fontSize: 13.5, lines: 2) {
                if wCanSplitRow(it, a, b) { upd { w in wSplitRow(w, a, b) } } else { AppModel.shared.say("dw.tooLow", ["n": 2 * W_SPLIT_MIN], kind: .error) }
            }
            GBtn(tr("dw.merge"), kind: .secondary, enabled: n > 1, height: 42, corner: 14, fontSize: 13.5, lines: 2) {
                upd { w in wMergeAt(w, a, b) }
                onSel(0, 0)
            }
        }
    }

    private func setType(_ t: String) {
        let a = ci, b = ri
        upd { w in
            wSetCell(w, a, b) { c in
                var x = c
                x.t = t
                return x
            }
        }
    }

    private func setHinge(_ h: String) {
        let a = ci, b = ri
        upd { w in
            wSetCell(w, a, b) { c in
                var x = c
                x.hinge = h
                return x
            }
        }
    }
}

private enum WDSF: Hashable { case w, h, gap, name, wall, col(Int), row(Int) }

/// The size: from the opening less the gap (or typed by hand), a product without a room's count and name, the
/// mullions' and transoms' places.
private struct WDSizeCard: View {
    let app: AppModel
    let pid: String
    let it: WinItem
    let o: Opening?
    let ci: Int
    @State private var tw: String
    @State private var th: String
    @State private var tg: String
    @State private var tName: String
    @State private var tT: String
    @State private var cols: [String]
    @State private var rows: [String]
    @FocusState private var focus: WDSF?

    init(app: AppModel, pid: String, it: WinItem, o: Opening?, ci: Int) {
        self.app = app; self.pid = pid; self.it = it; self.o = o; self.ci = ci
        _tw = State(initialValue: "\(it.w)")
        _th = State(initialValue: "\(it.h)")
        _tg = State(initialValue: "\(it.gap)")
        _tName = State(initialValue: it.name)
        _tT = State(initialValue: "\(it.freeT)")
        _cols = State(initialValue: it.cols.map { "\($0.w)" })
        let rs: [String] = ci < it.cols.count ? it.cols[ci].rows.map { "\($0.h)" } : []
        _rows = State(initialValue: rs)
    }

    // its sashes need room: a size under what they take is refused and said
    private var ok: Bool {
        let mn = wMinSize(it)
        guard let W = Int(tw), let H = Int(th), W >= mn.0, W <= 8000, H >= mn.1, H <= 4000 else { return false }
        if let g = Int(tg) { return g >= W_GAP_MIN && g <= W_GAP_MAX }
        return true
    }

    /// The size typed fits the usual limits but not what its sashes take.
    private var small: Bool {
        let mn = wMinSize(it)
        guard let W = Int(tw), let H = Int(th), (300...8000).contains(W), (300...4000).contains(H) else { return false }
        return W < mn.0 || H < mn.1
    }

    var body: some View {
        let mm = tr("dw.mm")
        WDCardBox(title: tr("dw.size"), sub: wSizeText(it.w, it.h)) {
            if let o {
                T(tr("dw.fromOp", ["s": wSizeText(o.w, o.h)]) + (it.fit ? "" : " · " + tr("dw.byHand")), ui(12.5, 400, G.ink2, lh: 1.35))
                GField(label: tr("dw.gapEach"), value: wDigits($tg, 2), placeholder: "20", focus: $focus, me: .gap, labelRight: mm, number: true)
            }
            HStack(alignment: .top, spacing: 8) {
                GField(label: tr("tl.pbW"), value: wDigits($tw, 4), placeholder: "1300", focus: $focus, me: .w, labelRight: mm, number: true).frame(maxWidth: .infinity)
                GField(label: tr("tl.pbH"), value: wDigits($th, 4), placeholder: "1400", focus: $focus, me: .h, labelRight: mm, number: true).frame(maxWidth: .infinity)
            }
            if it.cols.count > 1 { colFields }
            if rows.count > 1 { rowFields }
            if it.cols.count > 1 || rows.count > 1 { T(tr("dw.lastTakes"), ui(12, 400, G.ink3, lh: 1.3)) }
            if !it.inRoom { freeFields(mm) }
            if !ok {
                let mn = wMinSize(it)
                T(small ? tr("dw.sizeMin", ["w": mn.0, "h": mn.1]) : tr("dw.sizeErr"), ui(13, 500, G.err))
            }
            HStack(spacing: 8) {
                GBtn(tr("dw.apply"), enabled: ok, height: 44, corner: 14, fontSize: 14) { apply() }.accessibilityIdentifier("dw.sizeApply")
                if let o, !it.fit {
                    GBtn(tr("dw.refit"), kind: .secondary, height: 44, corner: 14, fontSize: 14, lines: 2) {
                        updateWinItem(pid, it.id) { x in
                            var y = wRefit(x, o.w, o.h, o.type)
                            y.fit = true
                            return y
                        }
                    }
                }
            }
        }
    }

    private var colFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            T(tr("dw.colsT"), ui(13.5, 700))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(cols.indices, id: \.self) { i in
                        GField(label: tr("dw.colN", ["n": i + 1]), value: listBinding(true, i), placeholder: "650", focus: $focus, me: .col(i), number: true).frame(width: 96)
                    }
                }
            }
        }
    }

    private var rowFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            T(tr("dw.rowsT", ["n": ci + 1]), ui(13.5, 700))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(rows.indices, id: \.self) { j in
                        GField(label: tr("dw.rowN", ["n": j + 1]), value: listBinding(false, j), placeholder: "450", focus: $focus, me: .row(j), number: true).frame(width: 96)
                    }
                }
            }
        }
    }

    @ViewBuilder private func freeFields(_ mm: String) -> some View {
        GField(label: tr("fr.name"), value: $tName, placeholder: tr("dw.k." + it.kind), optional: true, focus: $focus, me: .name)
            .onChange(of: tName) { _, n in if n.count > NAME_MAX { tName = String(n.prefix(NAME_MAX)) } }
        HStack {
            T(tr("dw.qty"), ui(15, 600)).frame(maxWidth: .infinity, alignment: .leading)
            EStepper(v: it.qty) { v in
                let q = min(max(v, 1), 99)
                updateWinItem(pid, it.id) { x in
                    var y = x
                    y.qty = q
                    return y
                }
            }
        }
        .frame(minHeight: 52)
        GField(label: tr("dw.wallT"), value: wDigits($tT, 3), placeholder: "300", focus: $focus, me: .wall, labelRight: mm, number: true)
    }

    private func listBinding(_ isCol: Bool, _ i: Int) -> Binding<String> {
        Binding(get: {
            let l = isCol ? cols : rows
            return i < l.count ? l[i] : ""
        }, set: { v in
            let s = String(v.filter { $0.isASCII && $0.isNumber }.prefix(4))
            if isCol { if i < cols.count { cols[i] = s } } else { if i < rows.count { rows[i] = s } }
        })
    }

    private func apply() {
        guard ok, let W = Int(tw), let H = Int(th) else { return }
        let g = Int(tg), op = o, c = ci
        let name = tName.trimmingCharacters(in: .whitespaces), wallT = Int(tT)
        let cs = cols, rs = rows
        // the fields as they were first shown: only a changed one is applied (a new size does not bring back old columns)
        let cs0: [String] = it.cols.map { "\($0.w)" }
        let rs0: [String] = c < it.cols.count ? it.cols[c].rows.map { "\($0.h)" } : []
        updateWinItem(pid, it.id) { x in
            var y = wSizeApplied(x, op, W, H, g, (cs0, cs), c, (rs0, rs))
            if !x.inRoom {
                y.name = name
                y.freeT = min(max(wallT ?? x.freeT, 80), 800)
            }
            return y
        }
        app.say("common.save")
    }
}

/// Colour swatches: cur ringed.
private struct WDSwatches: View {
    let cur: String
    let onPick: (String) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(W_COLOURS, id: \.self) { c in swatch(c) }
            }
        }
    }
    private func swatch(_ c: String) -> some View {
        let on = c == cur
        return VStack(spacing: 2) {
            Circle().fill(eColor(wColourRgb(c))).frame(width: 34, height: 34)
                .overlay(Circle().strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 3 : 1))
            T(tr("dw.col." + c), ui(11, on ? 700 : 500, on ? G.cobalt2 : G.ink2), lines: 1)
        }
        .padding(4).frame(minWidth: 52)
        .pressable(0.96) { onPick(c) }
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
    }
}

private struct WDProfileCard: View {
    let it: WinItem
    let upd: (@escaping (WinItem) -> WinItem) -> Void
    var body: some View {
        WDCardBox(title: tr("dw.profile"), sub: tr("dw.p." + it.profile) + " · " + tr("dw.chN", ["n": it.chambers])) {
            FlowLayout(spacing: 8) {
                ForEach(W_PROFILES, id: \.self) { pr in FChip(label: tr("dw.p." + pr), on: it.profile == pr) { setProfile(pr) } }
            }
            T(tr("dw.chambers"), ui(13.5, 700))
            FlowLayout(spacing: 8) {
                ForEach(wChambersOf(it.profile), id: \.self) { n in FChip(label: chamberName(n), on: it.chambers == n) { edit { $0.chambers = n } } }
            }
            T(tr("dw.glass"), ui(13.5, 700))
            FlowLayout(spacing: 8) {
                ForEach(W_GLASSES, id: \.self) { n in FChip(label: tr("dw.g.\(n)"), on: it.glass == n) { edit { $0.glass = n } } }
            }
            T(tr("dw.colIn"), ui(13.5, 700))
            WDSwatches(cur: it.colIn) { c in edit { $0.colIn = c } }
            T(tr("dw.colOut"), ui(13.5, 700))
            WDSwatches(cur: it.colOut) { c in edit { $0.colOut = c } }
            T(tr("dw.lamS"), ui(12, 400, G.ink3, lh: 1.3))
        }
    }
    private func chamberName(_ n: Int) -> String {
        if it.profile == "alu" { return tr(n >= 3 ? "dw.alu.warm" : "dw.alu.cold") }
        return tr("dw.chN", ["n": n])
    }
    private func edit(_ f: @escaping (inout WinItem) -> Void) {
        upd { x in
            var y = x
            f(&y)
            return y
        }
    }
    private func setProfile(_ pr: String) {
        upd { x in
            if x.profile == pr { return x }
            var y = x
            y.profile = pr
            y.chambers = pr == "alu" ? 3 : 5
            return y
        }
    }
}

/// The extras: the sill and its depth against the reveal, the drip, the reveals, nets and handles.
private struct WDExtrasCard: View {
    let app: AppModel
    let it: WinItem
    let r: Int
    let floor: Bool
    let upd: (@escaping (WinItem) -> WinItem) -> Void
    @State private var ts: String
    @FocusState private var focus: Bool?

    init(app: AppModel, it: WinItem, r: Int, floor: Bool, upd: @escaping (@escaping (WinItem) -> WinItem) -> Void) {
        self.app = app; self.it = it; self.r = r; self.floor = floor; self.upd = upd
        _ts = State(initialValue: it.sill > 0 ? "\(it.sill)" : "\(wSillFor(r))")
    }

    var body: some View {
        WDCardBox(title: tr("dw.extras")) {
            if !floor { sillPart }
            WNSwitchRow(title: tr("dw.x.reveals"), sub: tr("dw.x.revealsS", ["r": r]), on: it.reveals) { edit { $0.reveals.toggle() } }
            WNSwitchRow(title: tr("dw.x.net"), sub: tr("dw.x.netS"), on: it.net) { edit { $0.net.toggle() } }
            WNSwitchRow(title: tr("dw.x.handles"), sub: tr("dw.x.handlesS"), on: it.handles) { edit { $0.handles.toggle() } }
        }
    }

    @ViewBuilder private var sillPart: some View {
        let rr = r
        WNSwitchRow(title: tr("dw.x.sill"), sub: tr("dw.x.sillS", ["r": r]), on: it.sill > 0) { edit { $0.sill = $0.sill > 0 ? 0 : wSillFor(rr) } }
        if it.sill > 0 {
            HStack(alignment: .bottom, spacing: 8) {
                GField(label: tr("dw.x.sillD"), value: wDigits($ts, 3), placeholder: "250", focus: $focus, me: true, labelRight: tr("dw.mm"), number: true)
                    .frame(maxWidth: .infinity)
                GBtn(tr("dw.apply"), kind: .secondary, height: 52, corner: 14, fontSize: 14, fill: false) { applySill() }
            }
        }
        if it.sill > 0 && it.sill > r + W_SILL_OVER_MAX {
            T(tr("dw.x.sillWarn", ["m": it.sill - r]), ui(12.5, 500, G.amberInk, lh: 1.35))
        }
        WNSwitchRow(title: tr("dw.x.drip"), sub: tr("dw.x.dripS"), on: it.drip) { edit { $0.drip.toggle() } }
    }

    private func applySill() {
        guard let v = Int(ts), v >= 50, v <= 800 else { return }
        edit { $0.sill = v }
        app.say("common.save")
    }

    private func edit(_ f: @escaping (inout WinItem) -> Void) {
        upd { x in
            var y = x
            f(&y)
            return y
        }
    }
}

/// A door: its hinge side, which way it opens (a sliding one: which way it slides), its colour, the handle.
private struct WDDoorCard: View {
    let it: WinItem
    let upd: (@escaping (WinItem) -> WinItem) -> Void
    var body: some View {
        let sliding = it.kind == "dsl"
        WDCardBox(title: tr("dw.door")) {
            T(tr(sliding ? "dw.slideT" : "dw.hingeT"), ui(13.5, 700))
            FlowLayout(spacing: 8) {
                ForEach(["L", "R"], id: \.self) { h in
                    FChip(label: tr(sliding ? "dw.slide" + h : "dw.hinge" + h), on: it.hinge == h) { edit { $0.hinge = h } }
                }
            }
            if !sliding {
                T(tr("dw.swingT"), ui(13.5, 700))
                FlowLayout(spacing: 8) {
                    ForEach(["in", "out"], id: \.self) { s in FChip(label: tr("dw.swing." + s), on: it.swing == s) { edit { $0.swing = s } } }
                }
            }
            T(tr("dw.colDoor"), ui(13.5, 700))
            WDSwatches(cur: it.colIn) { c in edit { $0.colIn = c; $0.colOut = c } }
            WNSwitchRow(title: tr("dw.x.handles"), on: it.handles) { edit { $0.handles.toggle() } }
            T(tr("dw.doorS"), ui(12, 400, G.ink3, lh: 1.3))
        }
    }
    private func edit(_ f: @escaping (inout WinItem) -> Void) {
        upd { x in
            var y = x
            f(&y)
            return y
        }
    }
}
