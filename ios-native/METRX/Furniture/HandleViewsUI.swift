import SwiftUI

/*
 * Handles per door and per drawer (25 Oct 2026; Android ui/furniture/HandleViews.kt): the fronts of a drawing as tap
 * targets (each one's handle on or off, read out by VoiceOver, found by the tests as "front:<key>"), the "Hammasiga" /
 * "Hech biriga" buttons and the count line, a kitchen unit's fronts drawn small, the drawers behind the doors as a row of
 * chips, and the push latch's mark in the drawings and the PDF. The rules are in Furniture/Core/HandleRules.swift.
 */

/// Where a front without a handle is pushed open (a push latch): a small ring with a dot, in the drawings and the PDF.
func pushMark(_ c: GraphicsContext, _ at: CGPoint, _ color: Color, _ r: CGFloat = 2.8) {
    c.ring(color, r, at, 0.9)
    c.disc(color, r * 0.32, at)
}

/// A front's place in a drawing, mm: left, bottom, right, top.
struct FrontBox {
    let f: HFront
    let x0: Int, y0: Int, x1: Int, y1: Int
}

/// Where each front of a wardrobe-engine box is as drawWard draws it (the box from its legs' or plinth's bottom).
func wardFrontBoxes(_ m: Module, _ ws: Workshop) -> [FrontBox] {
    let z0 = legsOf(m, ws) + m.elev, base = wardBase(m), g = ws.gap10 / 10
    var starts: [Int] = [m.x]
    for s in m.sections { starts.append((starts.last ?? m.x) + s.w) }
    // a drawer behind the doors is not on the doors' picture: it has its row (InnerDrawers)
    return handleFronts(m).filter { !$0.inner }.compactMap { f -> FrontBox? in
        guard f.sec >= 0 && f.sec < m.sections.count else { return nil }
        let s = m.sections[f.sec], a = starts[f.sec]
        if f.key.contains(":d") {
            guard let x = s.inserts.first(where: { $0.kind == "drawer" && "s\(f.sec):d\($0.pos)" == f.key }) else { return nil }
            let y0 = z0 + base + ws.t + x.pos
            return FrontBox(f: f, x0: a + 2, y0: y0, x1: a + s.w - 2, y1: y0 + blockH(x))
        }
        let n = max(1, s.fronts.n)
        let j = f.key.range(of: ":f").flatMap { Int(f.key[$0.upperBound...]) } ?? 0
        let fw = (s.w - s.blind - g * (n + 1)) / n
        let x0 = a + g + j * (fw + g)
        return FrontBox(f: f, x0: x0, y0: z0 + base + g, x1: x0 + fw, y1: z0 + m.h - g)
    }
}

/// Where each front of a kitchen unit is as drawUnit draws it, the unit at 0 from its own bottom: doors left to right,
/// drawers top down.
func unitFrontBoxes(_ m: Module, _ ws: Workshop) -> [FrontBox] {
    let g = ws.gap10 / 10
    let fr = handleFronts(m).filter { $0.sec < 0 }
    let n = max(1, fr.count)
    let drawers = m.fronts.kind == "drawer"
    return fr.enumerated().map { i, f -> FrontBox in
        if drawers {
            let fh = (m.h - g * (n + 1)) / n
            let top = m.h - g - i * (fh + g)
            return FrontBox(f: f, x0: g, y0: top - fh, x1: m.w - g, y1: top)
        }
        let fw = (m.w - g * (n + 1)) / n
        let x0 = g + i * (fw + g)
        return FrontBox(f: f, x0: x0, y0: g, x1: x0 + fw, y1: m.h - g)
    }
}

/// A front's name for VoiceOver and the chips: "2-bo‘lim, 1-eshik" or "3-tortma".
func frontName(_ m: Module, _ f: HFront) -> String {
    let fr = handleFronts(m).filter { $0.sec == f.sec }
    if f.sec < 0 { return tr(f.drawer ? "hd.uDrawer" : "hd.uDoor", ["n": (fr.firstIndex(of: f) ?? 0) + 1]) }
    let drawers = f.key.contains(":d")
    let same = fr.filter { $0.key.contains(":d") == drawers }
    return tr(drawers ? "hd.drawer" : "hd.door", ["s": f.sec + 1, "n": (same.firstIndex(of: f) ?? 0) + 1])
}

/// The fronts of a drawing lay wide (ox mm at its left) as tap targets over it, in the drawing's box: each toggles its
/// handle; a glass door has none to toggle. edge: the piece opens by its edge, not by a push latch.
struct FrontTargets: View {
    let lay: KLay
    let ox: Int
    let m: Module
    let boxes: [FrontBox]
    let onTap: (HFront) -> Void
    var edge = false
    var body: some View {
        GeometryReader { geo in
            let k = geo.size.width / lay.vw
            ForEach(boxes, id: \.f.key) { b in self.target(b, k) }
        }
    }

    @ViewBuilder private func target(_ b: FrontBox, _ k: CGFloat) -> some View {
        let l = lay.x(b.x0 - ox) * k, r = lay.x(b.x1 - ox) * k
        let t = lay.y(b.y1) * k, bt = lay.y(b.y0) * k
        if r - l >= 2 && bt - t >= 2 {
            FrontTarget(name: frontName(m, b.f), on: hasHandle(m, b.f.key), glass: b.f.glass, edge: edge, key: b.f.key) { self.onTap(b.f) }
                .frame(width: r - l, height: bt - t)
                .position(x: (l + r) / 2, y: (t + bt) / 2)
        }
    }
}

/// One front's tap target: clear, the size of the front in the drawing.
private struct FrontTarget: View {
    let name: String
    let on: Bool
    let glass: Bool
    let edge: Bool
    let key: String
    let action: () -> Void
    var body: some View {
        let state = tr(glass ? "hd.glass" : on ? "hd.on" : edge ? "hd.edge" : "hd.off")
        if glass {
            Rectangle().fill(Color.black.opacity(0.001))
                .accessibilityElement()
                .accessibilityLabel(name).accessibilityValue(state)
                .accessibilityIdentifier("front:" + key)
        } else {
            Button(action: action) { Rectangle().fill(Color.black.opacity(0.001)) }
                .buttonStyle(.plain)
                .accessibilityLabel(name).accessibilityValue(state)
                .accessibilityAddTraits(.isToggle)
                .accessibilityIdentifier("front:" + key)
        }
    }
}

/// "Hammasiga" / "Hech biriga" for the handles, and how many fronts have one; edge: the rest open by the edge, not a push.
struct HandleButtons: View {
    let ms: [Module]
    let onAll: () -> Void
    let onNone: () -> Void
    var edge = false
    var body: some View {
        let sp = ms.map { handleSplit($0) }
        let a = sp.reduce(0) { $0 + $1.on }, b = sp.reduce(0) { $0 + $1.off }
        if a + b > 0 {
            VStack(alignment: .leading, spacing: 8) {
                T(tr("hd.title"), ui(14.5, 700))
                T(tr(edge ? "hd.countE" : "hd.count", ["a": a, "b": b]), ui(12.5, 500, G.ink2, lh: 1.4))
                HStack(spacing: 8) {
                    GBtn(tr("hd.all"), kind: .secondary, enabled: b > 0, height: 44, corner: 14, fontSize: 14, onAll)
                        .accessibilityIdentifier("hd.all")
                    GBtn(tr("hd.none"), kind: .secondary, enabled: a > 0, height: 44, corner: 14, fontSize: 14, onNone)
                        .accessibilityIdentifier("hd.none")
                }
            }
        }
    }
}

/// The drawers behind the doors (hinged or sliding), hidden by them on the doors' picture: a row of chips, one a drawer,
/// each tapped to give it a handle or take it away (founder's decision, 25 Oct 2026). Nothing when the box has none.
struct InnerDrawers: View {
    let m: Module
    let onTap: (HFront) -> Void
    var body: some View {
        let inner = handleFronts(m).filter(\.inner)
        if !inner.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                T(tr("hd.inner"), ui(13.5, 700))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(inner, id: \.key) { fr in self.chip(fr) }
                    }
                }
            }
        }
    }

    private func chip(_ fr: HFront) -> some View {
        let on = hasHandle(m, fr.key)
        let onTap = self.onTap
        return FChip(label: frontName(m, fr) + " · " + tr(on ? "hd.yes" : "hd.no"), on: on) { onTap(fr) }
            .accessibilityIdentifier("front:" + fr.key)
    }
}

/// A kitchen unit's fronts as a small drawing, each door or drawer a tap target for its handle.
struct UnitFronts: View {
    let m: Module
    let ws: Workshop
    let f: Furniture
    let onTap: (HFront) -> Void
    var body: some View {
        let mats = AppSettings.shared.mats
        let one = unitAlone(m)
        let lay = KLay(one.w, one.h, 220, false)
        let front = rgbOf(mats.first { $0.id == f.mats.front }?.rgb ?? "#CDBFAE")
        let carcass = rgbOf(mats.first { $0.id == f.mats.carcass }?.rgb ?? "#F5F5F2")
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let ws = self.ws
        Canvas { ctx, size in
            var c = ctx
            let k = size.width / lay.vw
            c.scaleBy(x: k, y: k)
            drawUnit(c, lay, one, ws, front, carcass, max(0.8, CGFloat(ws.gap10) / 10 * lay.s))
        }
        .aspectRatio(lay.vw / lay.vh, contentMode: .fit)
        .background(shape.fill(PC.white))
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .clipShape(shape)
        .overlay { FrontTargets(lay: lay, ox: 0, m: one, boxes: unitFrontBoxes(one, ws), onTap: onTap) }
        .frame(maxWidth: 230)
        .frame(maxWidth: .infinity)
    }
}

/// The unit on its own: at 0, from its own bottom, without legs.
private func unitAlone(_ m: Module) -> Module {
    var n = m
    n.x = 0; n.elev = 0; n.legs = false
    return n
}
