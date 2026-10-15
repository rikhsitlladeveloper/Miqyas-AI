import SwiftUI

/// Drawing a room's outline: one stroke, or corner taps (prototype PAGES.sketch); Android SketchScreen.
struct SketchScreen: View {
    let app: AppModel
    let pid: String
    let wid: String
    let name: String

    @State private var tapMode = false
    @State private var stroke: [Pt] = []          // the live finger path, pad units
    @State private var raw: [Pt]? = nil
    @State private var taps: [Pt] = []
    @State private var tapClosed = false
    @State private var forceClosed = false

    private var result: Sketch.Result? {
        let snap = AppSettings.shared.angleSnap
        if tapMode && !taps.isEmpty { return Sketch.process(taps, tap: true, tapClosed: tapClosed, snap: snap) }
        if !tapMode, let raw {
            let r = Sketch.process(raw, tap: false, tapClosed: false, snap: snap)
            if forceClosed && r.err == "open" && r.verts.count >= 3 {
                if let x = Geo.selfIntersects(r.verts) { return Sketch.Result(verts: r.verts, closed: true, err: "cross", cross: x) }
                return Sketch.Result(verts: Geo.orient(r.verts), closed: true, err: nil)
            }
            return r
        }
        return nil
    }

    var body: some View {
        let snap = AppSettings.shared.angleSnap
        let res = result
        ZStack {
            RoomGrid().ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    GlassIconButton("x", tr("common.close")) { app.pop() }.accessibilityIdentifier("back")
                    VStack(alignment: .leading, spacing: 0) { T(tr("sk.title"), ui(20, 800), lines: 1); T(name, ui(12, 400, G.ink2), lines: 1) }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 16).frame(height: 64)
                HStack(spacing: 8) {
                    Seg(items: [("d", tr("sk.draw")), ("t", tr("sk.tap"))], cur: tapMode ? "t" : "d") { tapMode = $0 == "t"; clear() }
                    if tapMode && !taps.isEmpty && !tapClosed {
                        MIcon("undo", G.ink, 20, 2).padding(10).background(Circle().fill(G.glass(0.7)))
                            .pressable(0.94, label: tr("common.undo")) { taps.removeLast(); tapClosed = false }
                    }
                    T("90°/45°", ui(13.5, 700, snap ? .white : G.ink), lines: 1)
                        .padding(.horizontal, 14).frame(minHeight: 44)
                        .background(Capsule().fill(snap ? G.cobalt : G.glass(0.7)))
                        .overlay(Capsule().strokeBorder(snap ? G.cobalt : G.rim, lineWidth: 1))
                        .pressable(0.96) { AppSettings.shared.setSnap(!snap) }
                        .accessibilityAddTraits(snap ? .isSelected : [])
                }
                .padding(.horizontal, 16)
                // the pad
                GeometryReader { geo in
                    Canvas { ctx, size in
                        var c = ctx; Fit(size, Sketch.PAD_W, Sketch.PAD_H).apply(&c)
                        drawSketch(c, res)
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                        guard !tapMode else { return }
                        let q = pad(v.location, geo.size)
                        if stroke.isEmpty { raw = nil; forceClosed = false; stroke = [pad(v.startLocation, geo.size)] }
                        if let l = stroke.last, hypot(q.x - l.x, q.y - l.y) >= 1.5 { stroke.append(q) }
                    }.onEnded { v in
                        if !tapMode {
                            raw = stroke.map { Pt(x: $0.x.rounded(), y: $0.y.rounded()) }
                            stroke = []
                        } else if (v.location - v.startLocation).len <= 10 && !tapClosed {
                            let q = pad(v.startLocation, geo.size)
                            if taps.count >= 3 && hypot(q.x - taps[0].x, q.y - taps[0].y) <= 22 { tapClosed = true }
                            else { taps.append(Pt(x: q.x.rounded(), y: q.y.rounded())) }
                        }
                    })
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(tr(tapMode ? "sk.tapHint" : "sk.drawHint")))
                    .accessibilityIdentifier("pad")
                }
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(G.glass(0.5)))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
                .padding(16)
                // the message line
                let msg: (String, String) = {
                    guard let r = res else { return (tr(tapMode ? "sk.tapHint" : "sk.drawHint"), "hint") }
                    if r.err == "open" { return (tr("sk.open"), "warn") }
                    if let e = r.err { return (tr("sk." + e), e == "cross" ? "err" : "warn") }
                    return (tr("sk.ready", ["n": r.verts.count]), "ok")
                }()
                let bg: Color = msg.1 == "err" ? G.errWash : msg.1 == "warn" ? G.amberWash : msg.1 == "ok" ? G.green.opacity(0.1) : G.glass(0.6)
                let fg: Color = msg.1 == "err" ? G.err : msg.1 == "warn" ? PC.amber : msg.1 == "ok" ? PC.okGreen : G.ink2
                HStack(spacing: 8) {
                    T(msg.0, ui(13.5, 500, fg, lh: 1.35)).frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("sk.msg")
                    if let r = res, r.err == "open", r.verts.count >= 3, !tapMode {
                        T(tr("sk.close"), ui(14, 700, G.cobalt)).padding(6).pressable(0.96) { forceClosed = true }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(bg))
                .padding(.horizontal, 16)
                HStack(spacing: 8) {
                    GBtn(tr("sk.redraw"), kind: .secondary, enabled: raw != nil || !taps.isEmpty) { clear() }
                    GBtn(tr("nr.create"), enabled: res.map { $0.closed && $0.err == nil } ?? false) { create(res) }.accessibilityIdentifier("sk.create")
                }
                .padding(16)
            }
        }
    }

    private func pad(_ p: CGPoint, _ size: CGSize) -> Pt {
        let q = Fit(size, Sketch.PAD_W, Sketch.PAD_H).vb(p)
        return Pt(x: (Double(q.x) * 10).rounded() / 10, y: (Double(q.y) * 10).rounded() / 10)
    }

    private func clear() { stroke = []; raw = nil; taps = []; tapClosed = false; forceClosed = false }

    private func create(_ res: Sketch.Result?) {
        guard let r = res, r.err == nil, r.closed else { return }
        let mm = Sketch.toMm(r.verts)
        if mm.count < 3 || Geo.selfIntersects(mm) != nil { app.say("sk.cross", kind: .error); return }
        var room = Room(id: uid(), floorId: wid, name: name, created: nowMs())
        room.template = "poly"; room.shape = "poly"; room.dims = Geo.polyDims(mm.count); room.poly = Poly(verts: mm, template: "sketch")
        Store.shared.update(pid) { $0.rooms.append(room) }
        app.replaceTop(.editor(pid: pid, rid: room.id, mode: "plan"))
        app.say("sk.created", ["n": mm.count])
    }

    private func drawSketch(_ ctx: GraphicsContext, _ res: Sketch.Result?) {
        let o = { (p: Pt) in CGPoint(p) }
        // the finger stroke: live in blue, finished in grey
        if stroke.count > 1 { ctx.stroke(polyPath(stroke.map(o), close: false), with: .color(PC.cob), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)) }
        if let rw = raw, rw.count > 1, !tapMode { ctx.stroke(polyPath(rw.map(o), close: false), with: .color(pc(0xFF9AA8BF, 0xFF5E6A82)), style: StrokeStyle(lineWidth: 2, lineCap: .round)) }
        if tapMode && taps.count >= 3 && !tapClosed { ctx.ring(PC.cob, 14, o(taps[0]), 1.5, dash: [3, 3]) }
        guard let r = res, r.verts.count >= 2 else { return }
        let v = r.verts
        let path = polyPath(v.map(o), close: r.closed)
        let crossing = r.err == "cross"
        if r.closed && r.err == nil { ctx.fill(path, with: .color(PC.cobWash)) }
        ctx.stroke(path, with: .color(crossing ? PC.red : PC.ink), style: StrokeStyle(lineWidth: 3, lineJoin: .round, dash: crossing ? [7, 5] : []))
        if r.closed && r.err == nil {
            let ids = Geo.polyWallIds(v.count)
            for i in v.indices {
                let a = o(v[i]), b = o(v[(i + 1) % v.count])
                ctx.disc(PC.white, 4.5, a); ctx.ring(PC.ink, 4.5, a, 1.2)
                let d = b - a, l = max(1, d.len)
                let c = mid(a, b) + CGPoint(x: -d.y / l, y: d.x / l) * 14
                ctx.disc(PC.white, 9, c); ctx.ring(PC.ink3, 9, c, 1)
                ctx.text(ids[i], c, .ui, 11, 600, PC.ink)
            }
        } else if !r.closed {
            ctx.line(PC.amber, o(v.last!), o(v.first!), 1.5, dash: [5, 4])
            ctx.disc(PC.cob, 8, o(v.first!)); ctx.disc(PC.white, 3, o(v.first!))
            ctx.disc(PC.white, 8, o(v.last!)); ctx.ring(PC.cob, 8, o(v.last!), 2)
        }
        if let x = r.cross {
            let p = o(x)
            ctx.disc(PC.red, 11, p)
            ctx.line(PC.onFill, p + CGPoint(x: -4, y: -4), p + CGPoint(x: 4, y: 4), 2); ctx.line(PC.onFill, p + CGPoint(x: 4, y: -4), p + CGPoint(x: -4, y: 4), 2)
        }
    }
}
