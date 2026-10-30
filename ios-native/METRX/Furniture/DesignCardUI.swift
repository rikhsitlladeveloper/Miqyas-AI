import SwiftUI

/*
 * The design of a piece (modern 3D part 2, 25 Oct 2026; the approved mockup's bottom sheet; Android
 * ui/furniture/DesignViews.kt): the six design style presets as cards, then the fine options as rows of swatches and
 * chips, the extras tagged "qo‘shimcha". The order's own style, picked when it is made, is what new pieces start with
 * (FStyleScreen). The look is everyone's; prices stay in Advanced (the cost card). The rules are in
 * Furniture/Core/PieceLook.swift.
 */

/// A "#RRGGBB" colour.
private func dzColor(_ hex: String) -> Color { Color(argb: 0xFF00_0000 | UInt32(rgbOf(hex))) }

/// A colour or wood key's colour.
private func dzKeyRgb(_ key: String) -> String {
    LOOK_COLOURS.first { $0.key == key }?.rgb ?? LOOK_WOODS.first { $0.key == key }?.rgb ?? "#CCCCCC"
}

private let DZ_WOODS = Set(LOOK_WOODS.map(\.key))

/// A front colour or wood key's name.
private func dzFrontName(_ k: String) -> String { DZ_WOODS.contains(k) ? tr("lk.w." + k) : tr("lk.c." + k) }

/// A front board's name: a decor's colour, else the workshop's name for it.
private func dzBoardName(_ id: String?) -> String {
    if let k = colourOf(id) { return dzFrontName(k) }
    return matShown(id ?? "")
}

/// Changes piece fid of order pid (the designer's undo list keeps the version before).
private func dzChange(_ pid: String, _ fid: String, _ fn: (Furniture) -> Furniture) { KitOps.shared.change(pid, fid, fn); dzSaid(pid, fid) }

/// A quick design change (style, handle, colour…): a toast with Undo, which takes the piece one change back (UX upgrades
/// section 3).
private func dzSaid(_ pid: String, _ fid: String) {
    Haptic.tick()
    AppModel.shared.say("ux.changed", action: "common.undo") { KitOps.shared.undo(pid, fid); Haptic.tick() }
}

/// Changes the piece's look (it is then no longer its preset).
private func dzLook(_ pid: String, _ fid: String, _ fn: @escaping (PieceLook) -> PieceLook) { KitOps.shared.change(pid, fid) { withLook($0, fn) }; dzSaid(pid, fid) }

/// The piece with a look of its own (no longer its preset), the rest as it was.
private func dzOwn(_ f: Furniture) -> Furniture { withLook(f) { $0 } }

/* ---------------- swatches and chips ---------------- */

/// A swatch: key, colour, kind (wood, stone, velvet or "").
private struct DzSwatch { let key: String, rgb: String, kind: String }

/// A chip: value, label, an extra ("qo‘shimcha").
private struct DzChip { let v: String, label: String; var extra = false }

/// A swatch's picture: a colour, a wood's grain, a stone's vein, a velvet's sheen.
private func drawDzSwatch(_ c: GraphicsContext, _ size: CGSize, _ rgb: String, _ kind: String) {
    let w = size.width, h = size.height
    c.fill(Path(CGRect(origin: .zero, size: size)), with: .color(dzColor(rgb)))
    let v = rgbOf(rgb)
    let r = Double((v >> 16) & 0xFF), g = Double((v >> 8) & 0xFF), b = Double(v & 0xFF)
    let lum: Double = (0.3 * r + 0.59 * g + 0.11 * b) / 255
    let base: Color = lum > 0.55 ? .black : .white
    let a = lum > 0.55 ? 0.14 : 0.16
    func line(_ p0: CGPoint, _ p1: CGPoint, _ col: Color, _ lw: CGFloat) {
        var p = Path(); p.move(to: p0); p.addLine(to: p1)
        c.stroke(p, with: .color(col), lineWidth: lw)
    }
    switch kind {
    case "wood":
        for i in 1...5 {
            let y = h * CGFloat(i) / 6
            line(CGPoint(x: 0, y: y), CGPoint(x: w, y: y + h * 0.08 * (i % 2 == 0 ? 1 : -1)), base.opacity(a), 0.7)
        }
    case "stone":
        line(CGPoint(x: 0, y: h * 0.3), CGPoint(x: w, y: h * 0.75), base.opacity(0.3), 0.8)
        line(CGPoint(x: w * 0.2, y: 0), CGPoint(x: w * 0.55, y: h), base.opacity(a), 0.5)
    case "velvet":
        c.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 0.45)), with: .color(Color.white.opacity(0.12)))
    default: break
    }
}

/// A row title, with the value chosen after it.
private struct DzTitle: View {
    let label: String
    var value: String? = nil
    var body: some View { T(value.map { label + ": " + $0 } ?? label, ui(14, 700), lines: 2) }
}

/// A row of swatches that scrolls sideways, cur the one on.
private struct DzSwatches: View {
    let items: [DzSwatch]
    let cur: String?
    let name: (String) -> String
    let onPick: (String) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.key) { s in one(s) }
            }
            .padding(.vertical, 2)
        }
    }
    private func one(_ s: DzSwatch) -> some View {
        let on = s.key == cur
        let rgb = s.rgb, kind = s.kind, key = s.key
        let pick = onPick
        return Canvas { ctx, size in drawDzSwatch(ctx, size, rgb, kind) }
            .clipShape(Circle())
            .padding(on ? 4 : 1)
            .frame(width: 44, height: 44)
            .overlay(Circle().strokeBorder(on ? G.cobalt : G.ink.opacity(0.2), lineWidth: on ? 3 : 1))
            .contentShape(Circle())
            .pressable(0.95, label: name(key)) { pick(key) }
            .accessibilityAddTraits(on ? .isSelected : [])
            .accessibilityIdentifier("lk.sw." + key)
    }
}

/// A row of chips that scrolls sideways; an extra's label says so.
private struct DzChips: View {
    let items: [DzChip]
    let cur: String
    let onPick: (String) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.v) { c in one(c) }
            }
            .padding(.vertical, 2)
        }
    }
    private func one(_ c: DzChip) -> some View {
        let v = c.v, pick = onPick
        return FChip(label: c.extra ? c.label + " · " + tr("lk.extra") : c.label, on: v == cur) { pick(v) }
            .accessibilityIdentifier("lk.ch." + (v.isEmpty ? "none" : v))
    }
}

/* ---------------- a preset's card ---------------- */

/// A preset as a small kitchen: the upper and lower fronts in its colours, the worktop, its handles and crown.
private func drawPresetPicture(_ c: GraphicsContext, _ size: CGSize, _ p: DesignPreset) {
    let w = size.width, h = size.height
    // the Android picture's pixel sizes in points
    let u: CGFloat = 0.45
    let up = dzColor(dzKeyRgb(p.up)), low = dzColor(dzKeyRgb(p.two ? p.low : p.up))
    let hc = dzColor(HANDLE_RGB[p.hcol] ?? "#1E1F22")
    let topC = dzColor(p.top == "wood" ? dzKeyRgb(p.accent) : LOOK_STONES.first { $0.key == p.stone }?.rgb ?? "#F1EFEB")
    let x0 = w * 0.1, x1 = w * 0.9
    let upY0 = p.crown == "ceiling" ? h * 0.08 : h * 0.16, upY1 = h * 0.44
    let topY = h * 0.6, lowY1 = h * 0.9, lowY0 = topY + h * 0.045
    func fill(_ r: CGRect, _ col: Color, _ corner: CGFloat = 0) {
        c.fill(corner > 0 ? Path(roundedRect: r, cornerRadius: corner) : Path(r), with: .color(col))
    }
    func line(_ a: CGPoint, _ b: CGPoint, _ col: Color, _ lw: CGFloat) {
        var path = Path(); path.move(to: a); path.addLine(to: b)
        c.stroke(path, with: .color(col), style: StrokeStyle(lineWidth: lw, lineCap: .round))
    }
    if p.crown == "cornice" { fill(CGRect(x: x0 - 3 * u, y: upY0 - h * 0.05, width: x1 - x0 + 6 * u, height: h * 0.05), up) }
    // the backsplash
    let sp: Color = p.splash == "tile" ? Color(argb: 0xFFF4F2EE) : p.splash == "print" ? Color(argb: 0xFFC9D6E2) : Color(argb: 0xFFE6E2DA)
    fill(CGRect(x: x0, y: upY1, width: x1 - x0, height: topY - upY1), sp)
    if p.splash == "tile" {
        for i in 1...3 {
            let y = upY1 + (topY - upY1) * CGFloat(i) / 4
            line(CGPoint(x: x0, y: y), CGPoint(x: x1, y: y), Color.black.opacity(0.08), u)
        }
    }
    let gap = 2 * u
    let dw = (x1 - x0 - gap * 2) / 3
    for i in 0..<3 {
        let lx = x0 + CGFloat(i) * (dw + gap)
        fill(CGRect(x: lx, y: upY0, width: dw, height: upY1 - upY0), up, 2 * u)
        fill(CGRect(x: lx, y: lowY0, width: dw, height: lowY1 - lowY0), low, 2 * u)
        if p.style == "shaker" {
            let i4 = 4 * u
            c.stroke(Path(CGRect(x: lx + i4, y: upY0 + i4, width: dw - 2 * i4, height: upY1 - upY0 - 2 * i4)), with: .color(Color.black.opacity(0.1)), lineWidth: 1.2 * u)
            c.stroke(Path(CGRect(x: lx + i4, y: lowY0 + i4, width: dw - 2 * i4, height: lowY1 - lowY0 - 2 * i4)), with: .color(Color.black.opacity(0.1)), lineWidth: 1.2 * u)
        }
        // the handles: bars, long bars, knobs, the Gola channel
        let cx = lx + dw / 2
        switch p.handle {
        case "gola": break
        case "knob":
            let r = 2.4 * u
            fill(CGRect(x: cx - r, y: upY1 - 6 * u - r, width: 2 * r, height: 2 * r), hc, r)
            fill(CGRect(x: cx - r, y: lowY0 + 6 * u - r, width: 2 * r, height: 2 * r), hc, r)
        default:
            let l: CGFloat = p.handle == "long" ? 0.5 : 0.25
            line(CGPoint(x: cx, y: upY1 - 4 * u - (upY1 - upY0) * l), CGPoint(x: cx, y: upY1 - 4 * u), hc, 2.2 * u)
            line(CGPoint(x: cx - dw * l / 2, y: lowY0 + 5 * u), CGPoint(x: cx + dw * l / 2, y: lowY0 + 5 * u), hc, 2.2 * u)
        }
    }
    if p.handle == "gola" { fill(CGRect(x: x0, y: lowY0 - u, width: x1 - x0, height: 3 * u), Color(argb: 0xFF2A2B2E)) }
    // the worktop
    let wt = CGRect(x: x0 - 3 * u, y: topY, width: x1 - x0 + 6 * u, height: h * 0.045)
    fill(wt, topC)
    c.stroke(Path(wt), with: .color(Color.black.opacity(0.08)), lineWidth: 0.8 * u)
}

/// A preset's picture on its light ground.
struct PresetPicture: View {
    let p: DesignPreset
    var body: some View {
        let d = p
        Canvas { ctx, size in drawPresetPicture(ctx, size, d) }
            .background(Color(argb: 0xFFEDEAE4))
    }
}

/// A preset's card: its picture, name and line; on: the one chosen.
struct PresetCard: View {
    let p: DesignPreset
    let on: Bool
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(alignment: .leading, spacing: 6) {
            PresetPicture(p: p)
                .aspectRatio(1.45, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            T(tr("lk.p." + p.id), ui(14, 800), lines: 2).minimumScaleFactor(0.85)
            T(tr("lk.p." + p.id + ".d"), ui(11.5, 500, G.ink2, lh: 1.3), lines: 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .glassCard(shape, fill: on ? G.cobalt.opacity(0.1) : G.glass(0.62))
        .overlay(shape.strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 2 : 1))
        .pressable(0.98, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("lk.p." + p.id)
    }
}

/// The presets in a row that scrolls sideways (a piece's design).
private struct PresetStrip: View {
    let cur: String
    let onPick: (String) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 8) {
                ForEach(DESIGN_PRESETS, id: \.id) { d in card(d) }
            }
            .padding(.vertical, 2)
        }
    }
    private func card(_ d: DesignPreset) -> some View {
        let id = d.id, pick = onPick
        return PresetCard(p: d, on: cur == id) { pick(id) }.frame(width: 150)
    }
}

/* ---------------- the design of a piece ---------------- */

/// What the piece is for the rows shown: a kitchen, a sliding wardrobe (kupe), a bed, another cabinet.
private func designKind(_ f: Furniture) -> String {
    if f.kind == "kitchen" { return "kitchen" }
    if f.modules.contains(where: { $0.slide != nil }) { return "kupe" }
    if f.modules.contains(where: { $0.type == "bed" }) { return "bed" }
    return "case"
}

/// A piece's "Dizayn" section: the preset cards, the fronts' colours (two-tone where it applies), surface, style,
/// handles and their colour, the mirror, a bed's fabric and headboard, a kitchen's worktop, backsplash, LED, legs and
/// crown, and the extras. No prices here: they stay in the cost card (Advanced).
struct DesignCard: View {
    let app: AppModel
    let p: Project
    let f: Furniture
    var body: some View {
        let kind = designKind(f)
        let pid = p.id, fid = f.id
        let a = app
        VStack(alignment: .leading, spacing: 10) {
            T(tr("lk.title"), ui(16, 800))
            T(tr("lk.presets"), ui(12.5, 400, G.ink2, lh: 1.4))
            PresetStrip(cur: presetOf(f)) { id in
                dzChange(pid, fid) { withPreset($0, id, ws: AppSettings.shared.workshop) }
                a.say("lk.applied", ["n": tr("lk.p." + id)])
            }
            Hairline()
            DzFronts(p: p, f: f, kind: kind)
            DzHandles(p: p, f: f, kind: kind)
            if kind == "bed" { DzBed(p: p, f: f) }
            if kind == "kitchen" { DzWorktop(p: p, f: f) }
            DzExtras(p: p, f: f, kind: kind)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.6))
        .accessibilityIdentifier("lk.card")
    }
}

/// The fronts' colours (one, or the upper and the lower: a kitchen's rows, a kupe's doors above and below the split),
/// the colour fronts' surface and the fronts' style: the boards follow (an enamel board for milled or fluted fronts).
private struct DzFronts: View {
    let p: Project
    let f: Furniture
    let kind: String
    private static let fronts: [DzSwatch] = LOOK_COLOURS.map { DzSwatch(key: $0.key, rgb: $0.rgb, kind: "") } + LOOK_WOODS.map { DzSwatch(key: $0.key, rgb: $0.rgb, kind: "wood") }
    var body: some View {
        let l = f.look ?? PieceLook()
        let style = l.style
        let finish = l.finish.isEmpty ? (f.mats.front.hasPrefix("ag_") ? "gloss" : "matte") : l.finish
        let pid = p.id, fid = f.id
        let twoOn = f.mats.frontUp != nil
        VStack(alignment: .leading, spacing: 10) {
            if kind == "kitchen" || kind == "kupe" {
                FToggle(label: tr("lk.two"), on: twoOn, id: "lk.two") {
                    dzChange(pid, fid) { g in var x = dzOwn(g); x.mats.frontUp = x.mats.frontUp != nil ? nil : x.mats.front; return x }
                }
            }
            if twoOn {
                DzTitle(label: tr("lk.upFront"), value: dzBoardName(f.mats.frontUp))
                DzSwatches(items: Self.fronts, cur: colourOf(f.mats.frontUp), name: dzFrontName) { k in Self.setFront(pid, fid, true, k, finish, style) }
                DzTitle(label: tr("lk.lowFront"), value: dzBoardName(f.mats.front))
                DzSwatches(items: Self.fronts, cur: colourOf(f.mats.front), name: dzFrontName) { k in Self.setFront(pid, fid, false, k, finish, style) }
            } else {
                DzTitle(label: tr(kind == "bed" ? "lk.bedColour" : "lk.front"), value: dzBoardName(f.mats.front))
                DzSwatches(items: Self.fronts, cur: colourOf(f.mats.front), name: dzFrontName) { k in Self.setFront(pid, fid, false, k, finish, style) }
            }
            DzTitle(label: tr("lk.finish"))
            DzChips(items: [DzChip(v: "gloss", label: tr("lk.f.gloss")), DzChip(v: "matte", label: tr("lk.f.matte"))], cur: finish) { v in
                Self.refit(pid, fid, v, style)
            }
            DzTitle(label: tr("lk.style"))
            DzChips(items: [DzChip(v: "flat", label: tr("lk.s.flat")), DzChip(v: "shaker", label: tr("lk.s.shaker")),
                            DzChip(v: "fluted", label: tr("lk.s.fluted"), extra: true)], cur: style) { v in
                Self.refit(pid, fid, finish, v)
            }
        }
    }
    private static func setFront(_ pid: String, _ fid: String, _ up: Bool, _ k: String, _ finish: String, _ style: String) {
        dzChange(pid, fid) { g in
            var x = dzOwn(g)
            let b = boardFor(k, finish, style)
            if up { x.mats.frontUp = b } else { x.mats.front = b }
            return x
        }
    }
    private static func refit(_ pid: String, _ fid: String, _ fin: String, _ st: String) {
        dzChange(pid, fid) { g in
            var x = withLook(g) { l in var n = l; n.finish = fin; n.style = st; return n }
            x.mats.front = refinish(x.mats.front, fin, st)
            x.mats.frontUp = x.mats.frontUp.map { refinish($0, fin, st) }
            return x
        }
    }
}

/// The handles (sliding doors have none: their profile's colour only), their colour, and the mirror: a kupe's middle
/// door (a mirror in its tint, lacobel glass or the front board) or a mirror's tint.
private struct DzHandles: View {
    let p: Project
    let f: Furniture
    let kind: String
    var body: some View {
        let l = f.look ?? PieceLook()
        let pid = p.id, fid = f.id
        let mirrors = f.modules.contains { m in m.sections.contains { $0.face == "mirror" } || m.type == "mirror" || (m.opt?.mirW ?? 0) > 0 }
        VStack(alignment: .leading, spacing: 10) {
            if kind != "kupe" {
                DzTitle(label: tr("lk.handle"))
                DzChips(items: handleChips(), cur: handleType(f)) { v in dzChange(pid, fid) { dzOwn(withHandleType($0, v)) } }
            }
            DzTitle(label: tr(kind == "kupe" ? "lk.hcolK" : "lk.hcol"))
            DzChips(items: HANDLE_COLOURS.map { DzChip(v: $0, label: tr("lk.hc." + $0)) }, cur: l.hcol) { v in
                dzLook(pid, fid) { x in var n = x; n.hcol = v; return n }
            }
            if kind == "kupe" {
                DzTitle(label: tr("lk.mirror"))
                DzChips(items: ["silver", "bronze", "graphite", "lacobel", "ldsp"].map { DzChip(v: $0, label: tr("lk.m." + $0)) }, cur: middleCur(l)) { v in
                    Self.setMiddle(pid, fid, v)
                }
            } else if mirrors {
                DzTitle(label: tr("lk.mirrorTint"))
                DzChips(items: MIRROR_TINTS.map { DzChip(v: $0, label: tr("lk.m." + $0)) }, cur: l.mirror.isEmpty ? "silver" : l.mirror) { v in
                    dzLook(pid, fid) { x in var n = x; n.mirror = v; return n }
                }
            }
        }
    }
    private func handleChips() -> [DzChip] {
        var out = [DzChip(v: "bar", label: tr("lk.h.bar")), DzChip(v: "long", label: tr("lk.h.long")), DzChip(v: "knob", label: tr("lk.h.knob"))]
        if kind == "kitchen" { out.append(DzChip(v: "gola", label: tr("lk.h.gola"))) }
        out.append(DzChip(v: "push", label: tr("lk.h.push")))
        return out
    }
    private func middleCur(_ l: PieceLook) -> String {
        switch middleFill(f) ?? "ldsp" {
        case "mirror": return l.mirror.isEmpty ? "silver" : l.mirror
        case "glass": return "lacobel"
        default: return "ldsp"
        }
    }
    private static func setMiddle(_ pid: String, _ fid: String, _ v: String) {
        dzChange(pid, fid) { g in
            switch v {
            case "lacobel": return withMiddleFill(dzOwn(g), "glass")
            case "ldsp": return withMiddleFill(dzOwn(g), "ldsp")
            default: return withMiddleFill(withLook(g) { x in var n = x; n.mirror = v; return n }, "mirror")
            }
        }
    }
}

/// A bed: the fabric, the headboard, the soft wall panel and, with it, its LED.
private struct DzBed: View {
    let p: Project
    let f: Furniture
    private static let fabrics: [DzSwatch] = LOOK_FABRICS.map { DzSwatch(key: $0.key, rgb: $0.rgb, kind: $0.velvet ? "velvet" : "") }
    var body: some View {
        let l = f.look ?? PieceLook()
        let pid = p.id, fid = f.id
        VStack(alignment: .leading, spacing: 10) {
            DzTitle(label: tr("lk.fabric"), value: l.fabric.isEmpty ? nil : tr("lk.fab." + l.fabric))
            DzSwatches(items: Self.fabrics, cur: l.fabric, name: { tr("lk.fab." + $0) }) { v in
                dzLook(pid, fid) { x in var n = x; n.fabric = v; return n }
            }
            DzTitle(label: tr("lk.head"))
            DzChips(items: ["", "vertical", "tufted", "panels"].map { DzChip(v: $0, label: tr("lk.hb." + ($0.isEmpty ? "board" : $0))) }, cur: l.head) { v in
                dzLook(pid, fid) { x in var n = x; n.head = v; return n }
            }
            FToggle(label: tr("lk.panel"), on: l.panel, id: "lk.panel") { dzLook(pid, fid) { x in var n = x; n.panel.toggle(); return n } }
            // the LED strip over the wall panel (Geo/ItemsScene3D.swift wallPanel; priced in Core/PieceLook.swift lookHardware)
            if l.panel {
                FToggle(label: tr("kx.led"), on: l.led, id: "lk.bedLed") { dzLook(pid, fid) { x in var n = x; n.led.toggle(); return n } }
            }
            if f.modules.contains(where: { $0.type == "bed" && $0.opt?.bed == "legs" }) { DzBedFoot(p: p, f: f) }
        }
    }
}

/// A bed on legs: a hidden base set in under it (the mockup's floating bed) or its metal legs in the handle colour
/// (Geo/ItemsScene3D.swift bedFoot).
private struct DzBedFoot: View {
    let p: Project
    let f: Furniture
    var body: some View {
        let l = f.look ?? PieceLook()
        let pid = p.id, fid = f.id
        VStack(alignment: .leading, spacing: 10) {
            DzTitle(label: tr("lk.legs"))
            DzChips(items: [DzChip(v: "plinth", label: tr("lk.l.plinth")), DzChip(v: "metal", label: tr("lk.l.metal"))], cur: l.legs ? "metal" : "plinth") { v in
                dzLook(pid, fid) { x in var n = x; n.legs = v == "metal"; return n }
            }
        }
    }
}

/// A kitchen's worktop (its kind, then its decor) and backsplash (the workshop's panel, skinali plain or printed, tile;
/// 600 high when there was none).
private struct DzWorktop: View {
    let p: Project
    let f: Furniture
    var body: some View {
        let pid = p.id, fid = f.id
        let tk = worktopKind(f.mats.top)
        VStack(alignment: .leading, spacing: 10) {
            DzTitle(label: tr("lk.top"))
            DzChips(items: [DzChip(v: "plain", label: tr("lk.t.plain")), DzChip(v: "stone", label: tr("lk.t.stone")),
                            DzChip(v: "wood", label: tr("lk.t.wood")), DzChip(v: "slim", label: tr("lk.t.slim"), extra: true)], cur: tk) { v in
                Self.setKind(pid, fid, v)
            }
            if tk != "plain" { decorRow(tk) }
            DzTitle(label: tr("lk.splash"))
            DzChips(items: [DzChip(v: "", label: tr("lk.sp.panel")), DzChip(v: "glass", label: tr("lk.sp.glass")),
                            DzChip(v: "print", label: tr("lk.sp.print")), DzChip(v: "tile", label: tr("lk.sp.tile"))], cur: splashKind(f.mats.splash)) { v in
                dzChange(pid, fid) { g in
                    var x = dzOwn(g)
                    x.mats.splash = splashFor(v)
                    var k = x.kx ?? KExtras()
                    if k.splash == 0 { k.splash = K_SPLASH }
                    x.kx = k
                    return x
                }
            }
        }
    }
    private func decorRow(_ tk: String) -> some View {
        let pid = p.id, fid = f.id
        let wood = tk == "wood"
        let decors: [DzSwatch] = wood ? LOOK_WOODS.filter { $0.key == "craft" || $0.key == "halifax" }.map { DzSwatch(key: $0.key, rgb: $0.rgb, kind: "wood") }
            : LOOK_STONES.map { DzSwatch(key: $0.key, rgb: $0.rgb, kind: "stone") }
        let name: (String) -> String = { k in wood ? tr("lk.w." + k) : tr("lk.st." + k) }
        let cur = worktopDecor(f.mats.top)
        return VStack(alignment: .leading, spacing: 10) {
            DzTitle(label: tr("lk.topDecor"), value: name(cur))
            DzSwatches(items: decors, cur: cur, name: name) { v in
                dzChange(pid, fid) { g in var x = dzOwn(g); x.mats.top = worktopFor(tk, v); return x }
            }
        }
    }
    private static func setKind(_ pid: String, _ fid: String, _ v: String) {
        dzChange(pid, fid) { g in
            var x = dzOwn(g)
            let d0 = worktopDecor(x.mats.top)
            let d = v == "wood" ? (d0 == "craft" || d0 == "halifax" ? d0 : "craft") : (["marble", "onyx", "dark"].contains(d0) ? d0 : "marble")
            x.mats.top = v == "plain" ? nil : worktopFor(v, d)
            return x
        }
    }
}

/// A wood accent (open shelves and insides, a bed's bedside tops), the LED (a kitchen's under the wall units, its
/// extras; a wardrobe's inside with a door sensor), a kitchen's legs and crown, and the extras.
private struct DzExtras: View {
    let p: Project
    let f: Furniture
    let kind: String
    private static let woods: [DzSwatch] = LOOK_WOODS.map { DzSwatch(key: $0.key, rgb: $0.rgb, kind: "wood") }
    var body: some View {
        let l = f.look ?? PieceLook()
        let pid = p.id, fid = f.id
        let kitchen = kind == "kitchen"
        let cur = l.accent.hasPrefix("wd_") ? String(l.accent.dropFirst(3)) : l.accent
        // (a gorka's LED is on its own card: GorkaViews.swift)
        let wardLed = kind == "kupe" || (kind == "case" && f.type != "gorka" && f.modules.contains { m in m.type == "wardrobe" && m.sections.contains { $0.fronts.kind == "door" } })
        VStack(alignment: .leading, spacing: 10) {
            if kitchen || kind == "bed" {
                DzTitle(label: tr("lk.accent"), value: cur.isEmpty ? nil : tr("lk.w." + cur))
                DzSwatches(items: Self.woods, cur: cur, name: { tr("lk.w." + $0) }) { v in
                    dzLook(pid, fid) { x in var n = x; n.accent = "wd_" + v; return n }
                }
            }
            if kitchen {
                FToggle(label: tr("lk.led"), on: f.kx?.led == true, id: "lk.led") {
                    dzChange(pid, fid) { g in var x = dzOwn(g); var k = x.kx ?? KExtras(); k.led = x.kx?.led != true; x.kx = k; return x }
                }
            } else if wardLed {
                FToggle(label: tr("lk.ledW"), on: l.led, id: "lk.ledW") { dzLook(pid, fid) { x in var n = x; n.led.toggle(); return n } }
            }
            if kitchen { DzKitchenTop(p: p, f: f) }
            if dzTakesCrown(f, kind) { DzWardCrown(p: p, f: f) }
            DzOptions(p: p, f: f, kind: kind)
        }
    }
}

/// A kitchen's base (hidden plinth or metal legs) and top (plain, cornice, to the ceiling).
private struct DzKitchenTop: View {
    let p: Project
    let f: Furniture
    var body: some View {
        let l = f.look ?? PieceLook()
        let pid = p.id, fid = f.id
        VStack(alignment: .leading, spacing: 10) {
            DzTitle(label: tr("lk.legs"))
            DzChips(items: [DzChip(v: "plinth", label: tr("lk.l.plinth")), DzChip(v: "metal", label: tr("lk.l.metal"), extra: true)], cur: l.legs ? "metal" : "plinth") { v in
                dzLook(pid, fid) { x in var n = x; n.legs = v == "metal"; return n }
            }
            DzTitle(label: tr("lk.crown"))
            DzChips(items: [DzChip(v: "", label: tr("lk.c0")), DzChip(v: "cornice", label: tr("lk.cCornice")), DzChip(v: "ceiling", label: tr("lk.cCeiling"))],
                    cur: crownOf(f)) { v in
                dzChange(pid, fid) { dzOwn(withCrown($0, v)) }
            }
        }
    }
}

/// A tall wardrobe takes the crown chooser (Android DesignViews.kt, modern 3D part 5): a kupe or another cabinet with a
/// wardrobe box standing on the floor 1700 high or more; not a gorka (its own cornice: GorkaViews.swift).
private func dzTakesCrown(_ f: Furniture, _ kind: String) -> Bool {
    (kind == "kupe" || kind == "case") && f.type != "gorka" && f.modules.contains { $0.type == "wardrobe" && !hung($0) && $0.elev + $0.h >= 1700 }
}

/// A tall wardrobe's crown: plain, a cornice, or a panel up to the ceiling, as the 3D draws them (priced in Advanced).
private struct DzWardCrown: View {
    let p: Project
    let f: Furniture
    var body: some View {
        let pid = p.id, fid = f.id
        VStack(alignment: .leading, spacing: 10) {
            DzTitle(label: tr("lk.crown"))
            DzChips(items: [DzChip(v: "", label: tr("lk.c0")), DzChip(v: "cornice", label: tr("lk.cCornice")), DzChip(v: "ceiling", label: tr("lk.cCeiling"))],
                    cur: crownOf(f)) { v in
                dzChange(pid, fid) { dzOwn(withCrown($0, v)) }
            }
        }
    }
}

/// The extras: fluted glass in the glass doors, a kitchen island's waterfall ends.
private struct DzOptions: View {
    let p: Project
    let f: Furniture
    let kind: String
    var body: some View {
        let l = f.look ?? PieceLook()
        let pid = p.id, fid = f.id
        let kitchen = kind == "kitchen"
        let glass = hasGlassDoors(f)
        VStack(alignment: .leading, spacing: 10) {
            if kitchen || glass {
                FToggle(label: tr("lk.fglass") + " · " + tr("lk.extra"), on: l.fglass, id: "lk.fglass") {
                    dzLook(pid, fid) { x in var n = x; n.fglass.toggle(); return n }
                }
            }
            if kitchen && (f.layout == "O" || f.layout == "P") {
                FToggle(label: tr("lk.waterfall") + " · " + tr("lk.extra"), on: l.waterfall, id: "lk.waterfall") {
                    dzLook(pid, fid) { x in var n = x; n.waterfall.toggle(); return n }
                }
            }
            if kitchen && !glass { T(tr("lk.fglassNote"), ui(12, 400, G.ink2, lh: 1.4)) }
        }
    }
}

/* ---------------- the order's style ---------------- */

/// The order's design style (a new order's first step, or from the gallery): six preset cards; new pieces start with
/// the one picked. fromNew goes on to the gallery.
struct FStyleScreen: View {
    let app: AppModel
    let pid: String
    let fromNew: Bool
    var body: some View {
        if let p = Store.shared.get(pid) {
            FPage(eyebrow: dn(p.name), title: tr("lk.styleT"), back: { app.pop() }) {
                T(tr("lk.styleS"), ui(13.5, 400, G.ink2, lh: 1.45))
                ForEach(0..<((DESIGN_PRESETS.count + 1) / 2), id: \.self) { i in row(p, i) }
                if fromNew {
                    T(tr("lk.later"), ui(14.5, 700, G.cobalt2))
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .pressable(0.97) { if app.once() { next() } }
                        .accessibilityAddTraits(.isButton).accessibilityIdentifier("lk.later")
                }
            }
        }
    }
    private func row(_ p: Project, _ i: Int) -> some View {
        let ds = Array(DESIGN_PRESETS[(i * 2)..<min(i * 2 + 2, DESIGN_PRESETS.count)])
        let cur = p.fstyle
        return HStack(alignment: .top, spacing: 10) {
            ForEach(ds, id: \.id) { d in
                PresetCard(p: d, on: cur == d.id) { pick(d.id) }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    private func next() {
        if fromNew { app.replaceTop(.fGallery(pid: pid, fromNew: true)) } else { app.pop() }
    }
    private func pick(_ id: String) {
        guard app.once() else { return }
        Store.shared.update(pid) { $0.fstyle = id }
        next()
    }
}

/// On the gallery: the order's style as a row of the six presets (UX upgrades section 7: picked here, the cards repaint at
/// once; no separate "Dizayn uslubi" page in a new order).
struct StyleRow: View {
    let app: AppModel
    let p: Project
    var body: some View {
        let pid = p.id
        VStack(alignment: .leading, spacing: 6) {
            T(tr("ux.styleRow"), ui(12, 600, G.ink3)).padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DESIGN_PRESETS, id: \.id) { d in
                        let on = p.fstyle == d.id
                        HStack(spacing: 8) {
                            PresetPicture(p: d).frame(width: 40, height: 30).clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            T(tr("lk.p." + d.id), ui(13.5, on ? 800 : 600, on ? G.cobalt2 : G.ink), lines: 1)
                        }
                        .padding(.leading, 5).padding(.trailing, 12).frame(minHeight: 44)
                        .background(Capsule().fill(on ? G.cobalt.opacity(0.12) : G.glass(0.6)))
                        .overlay(Capsule().strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 2 : 1))
                        .pressable(0.97) {
                            guard !on else { return }
                            Haptic.tick()
                            Store.shared.update(pid) { $0.fstyle = d.id }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
                        .accessibilityIdentifier("lk.p." + d.id)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lk.styleRow")
    }
}
