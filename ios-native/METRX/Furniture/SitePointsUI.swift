import SwiftUI

/*
 * Stage 1a part 2 (furniture plan section 5; design canvas screen 6; Android ui/furniture/SitePoints.kt): sockets,
 * switches, water, sewer, gas pipe and gas meter marked on the walls of a furniture order's rooms. Builders never see them.
 */

private let COLD = Color(argb: 0xFF2563EB)
private let HOT = Color(argb: 0xFFDC2626)
private let SEWER = Color(argb: 0xFF64748B)
private let GAS = Color(argb: 0xFFEAB308)
private let METER = Color(argb: 0xFFCA8A04)
private let PLATE_INK = Color(argb: 0xFF0E1C36)

/// The colour that tells a point's kind (with its shape: plates are square, pipes round, the meter a box).
func pointColor(_ t: String) -> Color {
    switch t { case "cold": return COLD; case "hot": return HOT; case "sewer": return SEWER; case "gas": return GAS; case "meter": return METER; default: return PLATE_INK }
}

/// A point at c, k units per mm, never smaller than minPx across: a socket plate with two holes, a switch plate with
/// its key, a round pipe (the sewer's ring shows its diameter), the meter's box.
func drawSitePoint(_ ctx: GraphicsContext, _ x: SitePoint, _ c: CGPoint, _ k: CGFloat, _ minPx: CGFloat, _ line: CGFloat = 1.2) {
    let sz = pointSize(x)
    let w = max(minPx, CGFloat(sz.w) * k), h = max(minPx, CGFloat(sz.h) * k)
    let rect = CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
    switch x.t {
    case "socket", "switch":
        ctx.fill(Path(rect), with: .color(.white)); ctx.stroke(Path(rect), with: .color(PLATE_INK), lineWidth: line)
        if x.t == "socket" { ctx.disc(PLATE_INK, w * 0.09, c + CGPoint(x: -w * 0.2, y: 0)); ctx.disc(PLATE_INK, w * 0.09, c + CGPoint(x: w * 0.2, y: 0)) }
        else { ctx.line(PLATE_INK, c + CGPoint(x: 0, y: -h * 0.25), c + CGPoint(x: 0, y: h * 0.25), line * 1.4) }
    case "sewer": ctx.disc(SEWER.opacity(0.35), w / 2, c); ctx.ring(SEWER, w / 2, c, line * 1.3)
    case "gas": ctx.disc(GAS, w / 2, c); ctx.ring(PLATE_INK, w / 2, c, line * 0.8)
    case "meter": ctx.fill(Path(rect), with: .color(METER.opacity(0.25))); ctx.stroke(Path(rect), with: .color(METER), lineWidth: line * 1.3)
    default: ctx.disc(pointColor(x.t), w / 2, c); ctx.ring(.white, w / 2, c, line * 0.8)
    }
}

/// A point's symbol as a small picture (type choices, cards).
struct PointGlyph: View {
    let t: String
    var size: CGFloat = 22
    var body: some View {
        Canvas { ctx, sz in
            let d = pointDefaults(t)
            let x = SitePoint(id: "g", t: t, wall: "A", off: 0, h: d.h, d: d.d, mh: d.mh)
            let ps = pointSize(x), m = min(sz.width, sz.height)
            let k = ["cold", "hot", "gas"].contains(t) ? m * 0.55 / 32 : m * 0.8 / CGFloat(max(ps.w, ps.h))
            drawSitePoint(ctx, x, CGPoint(x: sz.width / 2, y: sz.height / 2), k, m * 0.45, 1.6)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/* ---------------- the wall view's list ---------------- */

/// Under a wall's drawing: its points as cards, or what to mark.
struct PointsSection: View {
    let app: AppModel
    let p: Project
    let r: Room
    let wall: String
    var body: some View {
        let s = AppSettings.shared, unit = s.unit, en = s.lang == .en, ops = RoomOps.shared
        let list = r.points.filter { $0.wall == wall }.sorted { $0.off < $1.off }
        let corner = Geo.wallCorner(r, wall, s.angleSnap)
        let L = Geo.walls(r, s.angleSnap).first { $0.id == wall }?.len
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                T(tr("pt.title"), ui(15.5, 600)); CountPill(n: list.count)
                Spacer()
                T("+ " + tr("pt.add"), ui(14, 700, G.cobalt2)).padding(.horizontal, 6).padding(.vertical, 10)
                    .pressable(0.97) { app.sheet = .pointForm(pid: p.id, rid: r.id, wall: wall, id: nil) }
                    .accessibilityIdentifier("pt.add")
            }
            if list.isEmpty { T(tr("pt.none"), ui(13.5, 400, G.ink2, lh: 1.4)) }
            else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(list) { x in
                            let bad = pointProblem(x, L, r.dim("H").v) != nil
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) { PointGlyph(t: x.t, size: 18); T(ops.pointName(x.t), ui(14, 700), lines: 1) }
                                T(tr("wv.off", ["c": corner, "v": Geo.fmtLen(x.off, unit, en) + " " + unitName()]), ui(12.5, 400, G.ink2))
                                T(tr("pt.hV", ["v": Geo.fmtLen(x.h, unit, en) + " " + unitName()]), ui(12.5, 400, G.ink2))
                                if x.t == "sewer" { T("Ø \(x.d)", num(12.5, 600, G.ink2)) }
                                if bad { T(tr("room.bad"), ui(12.5, 600, G.err)) }
                            }
                            .padding(12).frame(width: 152, alignment: .leading)
                            .glassCard(RoundedRectangle(cornerRadius: 18, style: .continuous), fill: G.glass(0.55))
                            .pressable(0.98) { app.sheet = .pointForm(pid: p.id, rid: r.id, wall: wall, id: x.id) }
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("pt.card")
                        }
                    }
                    .padding(.vertical, 14).padding(.horizontal, 2)
                }
                .padding(.vertical, -14)
            }
        }
    }
}

/* ---------------- adding and editing a point ---------------- */

private enum PF: Hashable { case off, h, mw, mh }

struct PointSheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    let wall0: String
    let id: String?
    @State private var type = "socket"
    @State private var wall = "A"
    @State private var offv = ""
    @State private var hv = ""
    @State private var dv = 50
    @State private var mwv = ""
    @State private var mhv = ""
    @State private var src = "manual"
    @State private var tried = false
    @State private var loaded = false
    @FocusState private var focus: PF?
    private var ops: RoomOps { RoomOps.shared }

    var body: some View {
        if let r = ops.room(pid, rid) {
            let st = AppSettings.shared, unit = st.unit, en = st.lang == .en, dec = Geo.unitDecimals(unit), snap = st.angleSnap
            let edit = id.flatMap { i in r.points.first { $0.id == i } }
            let ws = Geo.walls(r, snap)
            let L = ws.first { $0.id == wall }?.len
            let po = Geo.parseDec(offv, dec), ph = Geo.parseDec(hv, dec)
            let pmw: Parsed = type == "meter" ? Geo.lenErr(mwv, 2000, unit, en) : .ok(0)
            let pmh: Parsed = type == "meter" ? Geo.lenErr(mhv, 2000, unit, en) : .ok(0)
            let x: SitePoint? = {
                guard let o = po.value, let h = ph.value, let mw = pmw.value, let mh = pmh.value else { return nil }
                return SitePoint(id: edit?.id ?? uid(), t: type, wall: wall, off: Int(o), h: Int(h),
                                 d: type == "sewer" ? dv : type == "meter" ? Int(mw) : 0, mh: type == "meter" ? Int(mh) : 0, src: src)
            }()
            let H = r.dim("H").v
            let prob = x.flatMap { pointProblem($0, L, H) }
            let probText: String? = prob.map { tr($0, ["v": Geo.fmtLen($0 == "pt.offBig" ? L : H, unit, en) + " " + unitName()]) }
            let corner = Geo.wallCorner(r, wall, snap)
            GlassSheet(edit != nil ? ops.pointName(edit!.t) : tr("pt.add"), onClose: { app.sheet = nil }) {
                T(tr("pt.type"), ui(15, 700))
                ForEach([Array(PT_TYPES.prefix(4)), Array(PT_TYPES.dropFirst(4))], id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { t in
                            let on = t == type
                            VStack(spacing: 5) {
                                PointGlyph(t: t, size: 20)
                                T(ops.pointName(t), ui(11.5, 700, on ? G.cobalt2 : G.ink), align: .center, lines: 2)
                            }
                            .padding(.horizontal, 4).padding(.vertical, 8)
                            .frame(maxWidth: .infinity, minHeight: 68)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(on ? G.cobalt.opacity(0.1) : G.glass(0.6)))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 2 : 1))
                            .pressable(0.97) { pick(t, edit == nil, unit, en) }
                            .accessibilityAddTraits(on ? .isSelected : [])
                            .accessibilityIdentifier("pt." + t)
                        }
                        ForEach(0..<(4 - row.count), id: \.self) { _ in Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    T(tr("op.wall"), ui(15, 700))
                    Seg(items: ws.map { ($0.id, $0.id) }, cur: wall, subs: Dictionary(uniqueKeysWithValues: ws.map { ($0.id, Geo.fmtLen($0.len, unit, en)) })) { wall = $0 }
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.ink.opacity(0.06)))
                }
                HStack(alignment: .top, spacing: 10) {
                    NumField(label: tr("op.offset", ["c": corner]), value: Binding(get: { offv }, set: { offv = $0; src = "manual" }), suffix: unitName(), error: errText(po),
                             showError: tried, focus: $focus, me: .off, id: "pt.off")
                    NumField(label: tr("pt.h"), value: Binding(get: { hv }, set: { hv = $0; src = "manual" }), suffix: unitName(), error: errText(ph),
                             showError: tried, focus: $focus, me: .h, id: "pt.h")
                }
                if ops.laserOn {
                    HStack(spacing: 16) {
                        // the laser's newest reading not used yet (its readings' inbox) first; with none, a made-up one until the real meter is here
                        laserLink(tr("pt.laserOff")) {
                            let hi = max(400, (L ?? 3000) - 100)
                            offv = Geo.fmtField(laserReading(tr("pt.laserOff")) { Int.random(in: 200..<hi) / 10 * 10 }, unit, en); src = "sim"
                        }
                        laserLink(tr("pt.laserH")) {
                            let h0 = pointDefaults(type).h
                            hv = Geo.fmtField(laserReading(tr("pt.laserH")) { h0 + Int.random(in: -30...30) }, unit, en); src = "sim"
                        }
                    }
                }
                if src == "sim" { HStack(spacing: 8) { MIcon("clock", G.amberInk, 16, 2); T(tr("pt.fromLaser"), ui(13, 500, G.amberInk)) } }
                if type == "sewer" {
                    VStack(alignment: .leading, spacing: 6) {
                        T(tr("pt.d"), ui(15, 700))
                        Seg(items: [("50", "Ø 50"), ("110", "Ø 110")], cur: "\(dv)") { dv = Int($0) ?? 50 }
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.ink.opacity(0.06)))
                    }
                }
                if type == "meter" {
                    HStack(alignment: .top, spacing: 10) {
                        NumField(label: tr("pt.mw"), value: $mwv, suffix: unitName(), error: errText(pmw), showError: tried, focus: $focus, me: .mw, id: "pt.mw")
                        NumField(label: tr("pt.mh"), value: $mhv, suffix: unitName(), error: errText(pmh), showError: tried, focus: $focus, me: .mh, id: "pt.mhh")
                    }
                }
                T(tr("pt.centre"), ui(13, 400, G.ink2))
                if let probText {
                    HStack(alignment: .top, spacing: 8) { MIcon("alert", G.err, 18, 2); T(probText, ui(13.5, 500, G.err, lh: 1.35)) }
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.errWash))
                }
            } footer: {
                HStack(spacing: 8) {
                    if let edit { GBtn(tr("common.delete"), kind: .danger, icon: "trash", height: 44, corner: 16, fontSize: 15) { ops.deletePoint(pid, rid, edit) } }
                    else { GBtn(tr("common.cancel"), kind: .secondary, height: 44, corner: 16, fontSize: 15) { app.sheet = nil } }
                    GBtn(tr("common.save"), enabled: x != nil && prob == nil, height: 44, corner: 16, fontSize: 15) {
                        tried = true
                        guard let x, prob == nil else { return }
                        ops.savePoint(pid, rid, x, isNew: edit == nil)
                    }
                    .accessibilityIdentifier("pt.save")
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                type = edit?.t ?? "socket"; wall = edit?.wall ?? wall0
                let len = ws.first { $0.id == wall }?.len
                offv = Geo.fmtField(edit?.off ?? ((len ?? 2000) / 2 / 10 * 10), unit, en)
                hv = Geo.fmtField(edit?.h ?? pointDefaults(type).h, unit, en)
                dv = edit.map { $0.d > 0 ? $0.d : 50 } ?? pointDefaults(type).d
                mwv = Geo.fmtField(edit.flatMap { $0.d > 0 ? $0.d : nil } ?? 300, unit, en)
                mhv = Geo.fmtField(edit.flatMap { $0.mh > 0 ? $0.mh : nil } ?? 400, unit, en)
                src = edit?.src ?? "manual"
            }
        }
    }

    private func pick(_ t: String, _ isNew: Bool, _ unit: LenUnit, _ en: Bool) {
        guard t != type else { return }
        type = t
        if isNew { hv = Geo.fmtField(pointDefaults(t).h, unit, en); dv = pointDefaults(t).d > 0 ? pointDefaults(t).d : 50 }
    }

    private func laserLink(_ label: String, _ action: @escaping () -> Void) -> some View {
        HStack(spacing: 6) { MIcon("laser", G.cobalt, 18, 2); T(label, ui(14, 600, G.cobalt)) }
            .padding(.horizontal, 4).frame(minHeight: 44).pressable(0.97, action)
    }

    /// The laser's newest reading not used yet, marked used for where; none: a made-up one (made) until the real meter is here.
    private func laserReading(_ where_: String, _ made: () -> Int) -> Int {
        guard let rd = AppSettings.shared.readings.last(where: { $0.used == nil && $0.src != "manual" }) else { return made() }
        AppSettings.shared.markReadingUsed(rd.id, where_)
        return rd.mm
    }
}
