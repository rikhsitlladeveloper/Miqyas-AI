import SwiftUI

/*
 * Choosing a layout (22 Oct 2026; Android ui/tiles/TGallery.kt): the gallery of layouts grouped by place, each card
 * drawn by the app; then one question a screen (the tile, the joint, where it starts, the second tile, the look, which
 * room, which surfaces), the layout shown on a corner of a room all along.
 */

private var en: Bool { AppSettings.shared.lang == .en }

/// The gallery group a room's layouts start with: a bathroom's, a kitchen's backsplashes, else the floors.
private func placeFor(_ p: Project, _ rid: String?) -> String? {
    guard let rid, let r = p.rooms.first(where: { $0.id == rid }) else { return nil }
    switch p.floors.first(where: { $0.id == r.floorId })?.type {
    case "bath": return "bath"
    case "kitchen": return "apron"
    default: return "floor"
    }
}

private func cardTitle(_ m: TModel) -> String { m.accent ? tr("tl.accentT") : tr("tl.p." + m.pattern) }

private func cardSub(_ m: TModel) -> String {
    let two = m.pattern == "chess" || m.pattern == "border" || m.accent
    return "\(m.a) × \(m.b) · " + tr("tl.lk." + m.look) + (two ? " + " + tr("tl.lk." + m.look2) : "")
}

private struct TGroupTops: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) { value.merge(nextValue()) { $1 } }
}

/* ---------------- the gallery ---------------- */

struct TGalleryScreen: View {
    let app: AppModel
    let pid: String
    let rid: String?
    let fromNew: Bool
    @State private var cur: String? = nil
    @State private var jumping = false
    @State private var viewH: CGFloat = 0

    var body: some View {
        if let p = Store.shared.get(pid) {
            let room = rid.flatMap { id in p.rooms.first { $0.id == id } }
            let groups = galleryGroups(placeFor(p, rid))
            let on = cur ?? groups[0].0
            let pics = TilePics.shared.pics
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    GlassIconButton("back", tr("nt.back")) { app.pop() }.padding(.leading, 6).accessibilityIdentifier("back")
                    BarTitle(title: tr("tl.galT"), eyebrow: dn(p.name))
                }
                .padding(.trailing, 12).frame(minHeight: 64)
                .background(G.sheet(0.55).ignoresSafeArea(edges: .top))
                .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
                ScrollViewReader { proxy in
                    chips(groups, on, proxy)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            T(intro(p, room), ui(13.5, 400, G.ink2, lh: 1.4))
                            ForEach(groups, id: \.0) { g, ms in group(p, g, ms, pics) }
                            if fromNew {
                                T(tr("fz.needL"), ui(14.5, 700, G.cobalt2)).padding(.horizontal, 16).padding(.vertical, 12).frame(maxWidth: .infinity)
                                    .pressable(0.97) { app.pop() }
                                    .accessibilityAddTraits(.isButton).accessibilityIdentifier("tg.later")
                            }
                            Color.clear.frame(height: 1)
                                .background(GeometryReader { geo in Color.clear.preference(key: TGroupTops.self, value: ["_end": geo.frame(in: .named("tgal")).maxY]) })
                        }
                        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 28)
                    }
                    .coordinateSpace(name: "tgal")
                    .background(GeometryReader { geo in Color.clear.onAppear { viewH = geo.size.height }.onChange(of: geo.size.height) { _, h in viewH = h } })
                    // the chip of the group at the top of the list
                    .onPreferenceChange(TGroupTops.self) { tops in
                        guard !jumping else { return }
                        let atEnd = viewH > 0 && (tops["_end"] ?? .infinity) <= viewH + 4
                        let top = atEnd ? groups[groups.count - 1].0 : groups.last { (tops[$0.0] ?? .infinity) <= 60 }?.0 ?? groups[0].0
                        if top != cur { cur = top }
                    }
                }
            }
            .onAppear { TilePics.shared.make() }
        }
    }

    /// The places with their cards, the room's own place first.
    private func galleryGroups(_ first: String?) -> [(String, [TModel])] {
        let gs: [(String, [TModel])] = PLACES.map { pl in (pl, T_MODELS.filter { $0.place == pl }) }
        guard let first else { return gs }
        return gs.filter { $0.0 == first } + gs.filter { $0.0 != first }
    }

    private func intro(_ p: Project, _ room: Room?) -> String {
        guard let room else { return tr("tl.galB") }
        let f = { (mm: Int?) in Geo.fmtLen(mm, .m, en) }
        let name = p.floors.first { $0.id == room.floorId }.map { floorName($0) } ?? dn(room.name)
        return tr("tl.forRoom", ["r": name, "a": f(room.dim("A").v), "b": f(room.dim("B").v), "h": f(room.dim("H").v)])
    }

    private func chips(_ groups: [(String, [TModel])], _ on: String, _ proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(groups, id: \.0) { g, _ in
                    let sel = g == on
                    T(tr("tl.pl." + g), ui(14, 700, sel ? G.solid : G.ink), lines: 1)
                        .padding(.horizontal, 16).frame(minHeight: 40)
                        .background(Capsule().fill(sel ? G.ink : G.glass(0.55)))
                        .pressable(0.97) {
                            cur = g; jumping = true
                            withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("tg-" + g, anchor: .top) }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { jumping = false }
                        }
                        .accessibilityAddTraits(sel ? [.isSelected, .isButton] : .isButton)
                        .accessibilityIdentifier("tg.chip." + g)
                }
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)
        }
    }

    @ViewBuilder private func group(_ p: Project, _ g: String, _ ms: [TModel], _ pics: [String: UIImage]) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 8) { T(tr("tl.pl." + g), ui(17, 800)); T("\(ms.count)", ui(12.5, 500, G.ink3)) }
            .padding(.top, 8).padding(.leading, 2)
            .background(GeometryReader { geo in Color.clear.preference(key: TGroupTops.self, value: [g: geo.frame(in: .named("tgal")).minY]) })
            .id("tg-" + g)
        ForEach(Array(stride(from: 0, to: ms.count, by: 2)), id: \.self) { i in
            HStack(alignment: .top, spacing: 10) {
                ForEach(ms[i..<min(i + 2, ms.count)], id: \.id) { m in
                    TModelCard(m: m, pic: pics[m.id], wide: i + 1 >= ms.count) { app.push(.tSteps(pid: p.id, model: m.id, rid: rid)) }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct TModelCard: View {
    let m: TModel
    let pic: UIImage?
    let wide: Bool
    let action: () -> Void
    var body: some View {
        let name = cardTitle(m)
        let img = ZStack {
            Color(argb: 0xFFF6F8FC)
            if let pic { Image(uiImage: pic).resizable().scaledToFill() } else { T("3D…", ui(11, 600, G.ink3)) }
        }
        .aspectRatio(200 / 170, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        let words = VStack(alignment: .leading, spacing: 2) {
            T(name, ui(14.5, 800), lines: 2)
            T(cardSub(m), ui(12, 500, G.ink2, lh: 1.3), lines: 2)
        }
        .padding(.horizontal, 4)
        Group {
            // the last card of an odd row takes the whole width, its picture beside the words
            if wide { HStack(spacing: 10) { img.frame(maxWidth: .infinity); words.frame(maxWidth: .infinity, alignment: .leading) } }
            else { VStack(alignment: .leading, spacing: 6) { img; words; Spacer(minLength: 0) } }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.62))
        .pressable(0.98, action)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("tmodel." + m.id)
    }
}

/* ---------------- the steps ---------------- */

/// The surfaces a new layout covers in room r: the floor, every wall (with the baths' fronts), or a backsplash band.
func defaultSurfs(_ l: TileLayout, _ r: Room?, _ p: Project, _ snap: Bool) -> [TSurf] {
    guard let r else { return [] }
    let ws = Geo.walls(r, snap)
    let kind = tModel(l.model)?.surf ?? (l.place == "floor" ? "floor" : "walls")
    switch kind {
    case "floor": return [TSurf(id: "floor")]
    case "apron": return ws.isEmpty ? [] : [TSurf(id: ws[0].id, mode: "band", h0: APRON_H0, h1: APRON_H1)]
    default:
        var out: [TSurf] = ws.enumerated().map { i, w in TSurf(id: w.id, alt: l.accent && i == 0) }
        if l.place == "bath" { out += tileRoomOf(p, r.id).fixes.filter { $0.type == "bath" }.map { TSurf(id: "bath:" + $0.id) } }
        return out
    }
}

/// A new layout's panel for a surface without a room, by its place.
func panelFor(_ place: String) -> TPanel {
    switch place {
    case "floor": return TPanel(kind: "floor", a: 3000, b: 2000)
    case "apron": return TPanel(kind: "apron", a: 2400, b: 600)
    default: return TPanel(kind: "wall", a: 2500, b: 2400)
    }
}

/// Which steps page set app.backOverride last: a page going away clears it only while it is still its own.
private enum TBackOwner { static var last = 0; static var seq = 0 }

private enum TSF: Hashable { case a, b, h(String) }

struct TStepsScreen: View {
    let app: AppModel
    let pid: String
    let model: String
    let lid: String?
    let rid: String?
    @State private var d: TileLayout
    @State private var at = 0
    @State private var backToken = 0
    @State private var pv = TPreviewCache()
    @FocusState private var focus: TSF?
    private let ok0: Bool

    init(app: AppModel, pid: String, model: String, lid: String?, rid: String?) {
        self.app = app; self.pid = pid; self.model = model; self.lid = lid; self.rid = rid
        let p = Store.shared.get(pid)
        let edit = lid.flatMap { id in p?.tiles.first { $0.id == id } }
        var start = TileLayout(id: uid())
        var ok = false
        if let edit { start = edit; ok = true }
        else if let m = tModel(model), let p {
            start = layoutOf(m, uid(), nowMs())
            let r = rid.flatMap { id in p.rooms.first { $0.id == id } }
            start.roomId = r?.id
            start.surfs = defaultSurfs(start, r, p, AppSettings.shared.angleSnap)
            ok = true
        }
        ok0 = ok
        _d = State(initialValue: start)
    }

    private var steps: [String] {
        var out = ["size", "joint", "start"]
        if d.pattern == "chess" || d.pattern == "border" || d.place != "floor" { out.append("second") }
        out.append("look")
        if lid == nil && rid == nil { out.append("where") }
        out.append("surf")
        return out
    }

    private func ok(_ s: String) -> Bool {
        switch s {
        case "size": return (20...3000).contains(d.a) && (20...3000).contains(d.b)
        case "where": return d.roomId != nil || d.panel != nil
        case "surf":
            if d.roomId != nil { return !d.surfs.isEmpty }
            if let pn = d.panel { return pn.a > 0 && pn.b > 0 }
            return false
        default: return true
        }
    }

    var body: some View {
        if let p = Store.shared.get(pid), ok0 {
            let st = steps, n = st.count
            let step = st[min(max(at, 0), n - 1)]
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        GlassIconButton("back", tr("nt.back")) { prev() }.padding(.leading, 6).accessibilityIdentifier("back")
                        BarTitle(title: tr("tl.p." + d.pattern), eyebrow: tr("tl.stepN", ["i": min(at, n - 1) + 1, "n": n]))
                    }
                    .padding(.trailing, 12).frame(minHeight: 64)
                    .background(G.sheet(0.55).ignoresSafeArea(edges: .top))
                    .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            dots(n)
                            if step != "where" && step != "surf" { picture }
                            stepBody(p, step)
                        }
                        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 120)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                FloatingFooter {
                    if at < n - 1 {
                        GBtn(tr("common.next"), enabled: ok(step)) { if ok(step) { at += 1 } }.accessibilityIdentifier("ts.next")
                    } else {
                        GBtn(tr("common.save"), enabled: st.allSatisfy { ok($0) }) { save(p, st) }.accessibilityIdentifier("ts.save")
                    }
                }
            }
            .onAppear {
                TBackOwner.seq += 1; backToken = TBackOwner.seq; TBackOwner.last = backToken
                app.backOverride = { prev() }
            }
            .onDisappear { if TBackOwner.last == backToken { app.backOverride = nil; TBackOwner.last = 0 } }
        }
    }

    private func dots(_ n: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<n, id: \.self) { i in
                Capsule().fill(i == at ? G.cobalt : i < at ? G.cobalt.opacity(0.45) : G.ink.opacity(0.15)).frame(width: i == at ? 22 : 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// The layout on a corner of the sample room; lower while the keyboard is up.
    private var picture: some View {
        ZStack(alignment: .bottomTrailing) {
            PreviewView(pv: pv.get(d))
            T(tr("fx.drag"), ui(11, 600, G.ink3)).padding(10).allowsHitTesting(false)
        }
        .aspectRatio(focus != nil ? 2.1 : 1.25, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
    }

    @ViewBuilder private func stepBody(_ p: Project, _ step: String) -> some View {
        let snap = AppSettings.shared.angleSnap
        switch step {
        case "size": TSizeStep(d: $d, focus: $focus)
        case "joint":
            TAsk(title: tr("tl.s.joint"), help: tr("tl.s.jointH")) {
                FlowLayout(spacing: 8) {
                    ForEach(1...5, id: \.self) { j in FChip(label: tr("tl.jointV", ["n": j]), on: d.joint == j) { d.joint = j } }
                }
            }
        case "start":
            TAsk(title: tr("tl.s.start"), help: tr("tl.s.startH")) {
                ForEach(["center", "corner", "door"], id: \.self) { k in
                    TOption(title: tr("tl.st." + k), sub: tr("tl.st." + k + "S"), on: d.start == k) { d.start = k; d.ox = 0; d.oy = 0 }
                }
                T(tr("tl.s.rot"), ui(15, 700)).padding(.top, 6)
                Seg(items: [("0", "0°"), ("90", "90°"), ("45", "45°")], cur: "\(d.rot)") { v in d.rot = Int(v) ?? 0 }
            }
        case "second": TSecondStep(d: $d)
        case "look": TAsk(title: tr("tl.s.look"), help: tr("tl.s.lookH")) { TLookGrid(cur: d.look) { d.look = $0 } }
        case "where": TWhereStep(app: app, p: p, d: $d, snap: snap) { at += 1 }
        default:
            if d.roomId != nil, let room = p.rooms.first(where: { $0.id == d.roomId }) { TSurfStep(app: app, p: p, r: room, d: $d, snap: snap, focus: $focus) }
            else { TPanelStep(d: $d, focus: $focus) }
        }
    }

    private func prev() {
        focus = nil
        if at > 0 { at -= 1 } else { app.pop() }
    }

    private func save(_ p: Project, _ st: [String]) {
        guard st.allSatisfy({ ok($0) }), app.once() else { return }
        // the short side first, whatever was typed
        var l = d
        l.a = min(d.a, d.b); l.b = max(d.a, d.b)
        if d.roomId != nil { l.panel = nil }
        let lay = l
        if lid != nil {
            updateLayout(p.id, lay.id) { $0 = lay }
            app.pop(); app.say("tl.saved")
        } else {
            Store.shared.update(p.id) { $0.tiles.append(lay) }
            app.popTo { if case .project(let id, _, _, _) = $0 { return id == p.id }; return false }
            app.push(.tView(pid: p.id, rid: lay.roomId, lid: lay.id))
            app.say("tl.added", ["n": tr(placeKey(lay))])
        }
    }
}

/// A step's question, its help line and its choices.
private struct TAsk<Content: View>: View {
    let title: String
    let help: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            T(title, ui(21, 800, G.ink, lh: 1.2)).padding(.top, 4)
            T(help, ui(13, 400, G.ink2, lh: 1.4))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One choice as a card with a line under it.
private struct TOption: View {
    let title: String
    let sub: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: 10) {
            ZStack {
                Circle().strokeBorder(on ? G.cobalt : G.ink3, lineWidth: 2).frame(width: 20, height: 20)
                if on { Circle().fill(G.cobalt).frame(width: 10, height: 10) }
            }
            VStack(alignment: .leading, spacing: 1) {
                T(title, ui(15, 700, on ? G.cobalt2 : G.ink))
                T(sub, ui(12.5, 400, G.ink2, lh: 1.35))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, 10).frame(minHeight: 56)
        .background(shape.fill(on ? G.cobalt.opacity(0.1) : G.glass(0.75)))
        .overlay(shape.strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 2 : 1))
        .pressable(0.98, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
    }
}

/// The tile's size: the usual ones, or typed.
private struct TSizeStep: View {
    @Binding var d: TileLayout
    let focus: FocusState<TSF?>.Binding
    @State private var custom: Bool
    @State private var ta: String
    @State private var tb: String
    init(d: Binding<TileLayout>, focus: FocusState<TSF?>.Binding) {
        _d = d; self.focus = focus
        let v = d.wrappedValue
        let listed = TILE_SIZES.contains { ($0.0 == v.a && $0.1 == v.b) || ($0.0 == v.b && $0.1 == v.a) }
        _custom = State(initialValue: !listed)
        _ta = State(initialValue: "\(v.a)"); _tb = State(initialValue: "\(v.b)")
    }
    var body: some View {
        TAsk(title: tr("tl.s.size"), help: tr("tl.s.sizeH")) {
            FlowLayout(spacing: 8) {
                ForEach(Array(TILE_SIZES.enumerated()), id: \.offset) { _, s in
                    FChip(label: "\(s.0) × \(s.1)", on: !custom && d.a == s.0 && d.b == s.1) { custom = false; d.a = s.0; d.b = s.1 }
                }
                FChip(label: tr("tl.custom"), on: custom) { custom = true; ta = "\(d.a)"; tb = "\(d.b)" }
            }
            if custom {
                HStack(alignment: .top, spacing: 10) {
                    side(tr("tl.side1"), $ta, "300", .a) { d.a = $0 }
                    side(tr("tl.side2"), $tb, "600", .b) { d.b = $0 }
                }
            }
        }
    }
    private func side(_ label: String, _ text: Binding<String>, _ ph: String, _ me: TSF, _ set: @escaping (Int) -> Void) -> some View {
        let v = Int(text.wrappedValue)
        let bad = v.map { !(20...3000).contains($0) } ?? true
        let b = Binding(get: { text.wrappedValue }, set: { nv in
            let c = String(nv.filter { $0.isASCII && $0.isNumber }.prefix(4))
            text.wrappedValue = c
            if let x = Int(c), (20...3000).contains(x) { set(x) }
        })
        return GField(label: label, value: b, placeholder: ph, error: bad ? tr("tl.sizeErr") : nil, showError: true, focus: focus, me: me, labelRight: "mm", number: true)
            .frame(maxWidth: .infinity)
    }
}

/// The second tile: the chessboard's, the border strip's, or an accent wall's.
private struct TSecondStep: View {
    @Binding var d: TileLayout
    private static let STRIPS: [(Int, Int)] = [(0, 0), (100, 300), (200, 600), (200, 200), (300, 600)]
    private static let BANDS = [900, 1200, 1500, 1800]
    var body: some View {
        let needs = d.pattern == "chess" || d.pattern == "border"
        let help: String = {
            switch d.pattern {
            case "chess": return "tl.s.secondC"
            case "border": return d.place == "floor" ? "tl.s.secondB" : "tl.s.secondF"
            default: return "tl.s.accentH"
            }
        }()
        TAsk(title: tr(needs ? "tl.s.second" : "tl.s.accent"), help: tr(help)) {
            if !needs {
                HStack {
                    T(tr("tl.accentOn"), ui(15, 700)).frame(maxWidth: .infinity, alignment: .leading)
                    GSwitch(on: d.accent)
                }
                .padding(.horizontal, 14).frame(minHeight: 56)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.glass(0.75)))
                .pressable(0.98) { d.accent.toggle() }
                .accessibilityAddTraits(.isButton)
            }
            if d.pattern == "border" { border }
            if needs || d.accent {
                T(tr("tl.s.look2"), ui(15, 700))
                TLookGrid(cur: d.look2) { d.look2 = $0 }
            }
        }
    }
    @ViewBuilder private var border: some View {
        T(tr("tl.s.strip"), ui(15, 700))
        FlowLayout(spacing: 8) {
            ForEach(Array(TSecondStep.STRIPS.enumerated()), id: \.offset) { _, s in
                FChip(label: s.0 == 0 ? tr("tl.sameTile") : "\(s.0) × \(s.1)", on: d.a2 == s.0 && d.b2 == s.1) { d.a2 = s.0; d.b2 = s.1 }
            }
        }
        if d.place != "floor" {
            T(tr("tl.s.bandAt"), ui(15, 700))
            FlowLayout(spacing: 8) {
                ForEach(TSecondStep.BANDS, id: \.self) { h in FChip(label: Geo.fmtLen(h, .m, en) + " m", on: d.band == h) { d.band = h } }
            }
        }
    }
}

/// The looks: colours, then the drawn marbles, woods and concretes.
private struct TLookGrid: View {
    let cur: String
    let onPick: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(["c", "m", "w", "k"], id: \.self) { kind in
                T(tr("tl.lkk." + kind), ui(13.5, 700, G.ink2)).padding(.top, 4)
                FlowLayout(spacing: 10) {
                    ForEach(LOOKS.filter { $0.kind == kind }, id: \.id) { lk in cell(lk) }
                }
            }
        }
    }
    private func cell(_ lk: TileLook) -> some View {
        let on = lk.id == cur
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return VStack(spacing: 4) {
            LookSwatch(id: lk.id)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .padding(on ? 3 : 0)
                .frame(width: 64, height: 64)
                .overlay(shape.strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 3 : 1))
            T(tr("tl.lk." + lk.id), ui(11.5, on ? 700 : 500, on ? G.cobalt2 : G.ink2, lh: 1.15), align: .center, lines: 2)
        }
        .frame(width: 72)
        .padding(2)
        .pressable(0.97) { onPick(lk.id) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
    }
}

/// Which room the layout goes in, a new room, or none (typed sizes).
private struct TWhereStep: View {
    let app: AppModel
    let p: Project
    @Binding var d: TileLayout
    let snap: Bool
    let onPicked: () -> Void
    var body: some View {
        TAsk(title: tr("fq.title"), help: tr("tl.s.whereH")) {
            ForEach(p.rooms) { r in roomOption(r) }
            HStack(spacing: 12) {
                MIcon("plus", G.cobalt2, 22, 2.2)
                VStack(alignment: .leading, spacing: 1) { T(tr("fz.newRoom"), ui(15, 700, G.cobalt2)); T(tr("tl.s.newRoomS"), ui(12.5, 400, G.ink2)) }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12).padding(.vertical, 10).frame(minHeight: 60)
            .dashedGlass(16)
            .pressable(0.98) { newRoom() }
            .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton).accessibilityIdentifier("ts.newRoom")
            TOption(title: tr("tl.s.noRoom"), sub: tr("tl.s.noRoomS"), on: d.roomId == nil && d.panel != nil) {
                d.roomId = nil; d.surfs = []
                if d.panel == nil { d.panel = panelFor(d.place) }
                onPicked()
            }
        }
    }
    private func roomOption(_ r: Room) -> some View {
        let w = p.floors.first { $0.id == r.floorId }
        let ready = measuredRoom(r, snap)
        let sub = ready && !r.isPoly ? Geo.fmtLen(r.dim("A").v, .m, en) + " × " + Geo.fmtLen(r.dim("B").v, .m, en) + " m" : tr(ready ? "tl.measured" : "fo.notMeasured")
        return TOption(title: w.map { floorName($0) } ?? dn(r.name), sub: sub, on: d.roomId == r.id) {
            d.roomId = r.id; d.panel = nil
            d.surfs = defaultSurfs(d, r, p, snap)
            onPicked()
        }
    }
    private func newRoom() {
        guard app.once() else { return }
        let type = d.place == "bath" ? "bath" : d.place == "apron" ? "kitchen" : "living"
        let base = tr(tRoomKey(type))
        let k = p.floors.filter { $0.name.hasPrefix(base) }.count
        let rid = addTileRoom(p.id, type, k > 0 ? "\(base) \(k + 1)" : base)
        let r = Store.shared.get(p.id)?.rooms.first { $0.id == rid }
        d.roomId = rid; d.panel = nil
        d.surfs = defaultSurfs(d, r, Store.shared.get(p.id) ?? p, snap)
        onPicked()
    }
}

/// Which of the room's surfaces the layout covers: the floor, each wall in full, up to a height or as a band, a bath's front.
private struct TSurfStep: View {
    let app: AppModel
    let p: Project
    let r: Room
    @Binding var d: TileLayout
    let snap: Bool
    let focus: FocusState<TSF?>.Binding
    var body: some View {
        let ws = Geo.walls(r, snap)
        let baths = tileRoomOf(p, r.id).fixes.filter { $0.type == "bath" }
        TAsk(title: tr("tl.s.surf"), help: tr("tl.s.surfH")) {
            TCheckRow(title: tr("tl.pk.floor"), sub: nil, on: d.surfs.contains { $0.id == "floor" }) { toggle("floor") }
            ForEach(ws.map(\.id), id: \.self) { id in wallBox(id, ws.first { $0.id == id }?.len) }
            ForEach(baths) { f in
                TCheckRow(title: tr("tl.bathFront"), sub: tr("tl.wallN", ["w": f.wall]), on: d.surfs.contains { $0.id == "bath:" + f.id }) { toggle("bath:" + f.id) }
            }
            if d.surfs.isEmpty { T(tr("tl.s.surfNone"), ui(13, 500, G.err)) }
        }
    }

    private func toggle(_ id: String) {
        if d.surfs.contains(where: { $0.id == id }) { d.surfs.removeAll { $0.id == id } } else { d.surfs.append(TSurf(id: id)) }
    }

    private func change(_ s: TSurf) {
        if let i = d.surfs.firstIndex(where: { $0.id == s.id }) { d.surfs[i] = s }
    }

    private func pickMode(_ s: TSurf, _ m: String) {
        var n = s
        switch m {
        case "to": n.mode = "to"; n.h0 = 0; n.h1 = s.h1 > 0 ? s.h1 : 1500
        case "band":
            n.mode = "band"
            n.h0 = s.h0 > 0 ? s.h0 : APRON_H0
            n.h1 = s.h1 > s.h0 && s.h1 > 0 ? s.h1 : APRON_H1
        default: n.mode = "full"
        }
        change(n)
    }

    private func wallBox(_ id: String, _ len: Int?) -> some View {
        let s = d.surfs.first { $0.id == id }
        let unit = AppSettings.shared.unit
        return VStack(alignment: .leading, spacing: 8) {
            TCheckRow(title: tr("tl.wallN", ["w": id]), sub: len.map { Geo.fmtLen($0, .m, en) + " m" }, on: s != nil) { toggle(id) }
            if let s {
                VStack(alignment: .leading, spacing: 8) {
                    Seg(items: [("full", tr("tl.m.full")), ("to", tr("tl.m.to")), ("band", tr("tl.m.band"))], cur: s.mode) { m in pickMode(s, m) }
                    if s.mode != "full" {
                        HStack(alignment: .top, spacing: 10) {
                            if s.mode == "band" {
                                THeightField(label: tr("tl.h0"), mm: s.h0, unit: unit, me: .h(id + "0"), focus: focus) { v in var x = s; x.h0 = v; change(x) }
                            }
                            THeightField(label: tr(s.mode == "band" ? "tl.h1b" : "tl.h1"), mm: s.h1, unit: unit, me: .h(id + "1"), focus: focus) { v in var x = s; x.h1 = v; change(x) }
                        }
                    }
                    if d.accent {
                        HStack {
                            T(tr("tl.accentWall"), ui(14, 600)).frame(maxWidth: .infinity, alignment: .leading)
                            GSwitch(on: s.alt)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .pressable(0.98) { var x = s; x.alt.toggle(); change(x) }
                    }
                }
                .padding(.horizontal, 12).padding(.bottom, 10)
            }
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.glass(0.6)))
    }
}

/// A height typed in the app's unit; the layout takes it once it reads as a length.
private struct THeightField: View {
    let label: String
    let mm: Int
    let unit: LenUnit
    let me: TSF
    let focus: FocusState<TSF?>.Binding
    let onMm: (Int) -> Void
    @State private var t: String
    init(label: String, mm: Int, unit: LenUnit, me: TSF, focus: FocusState<TSF?>.Binding, onMm: @escaping (Int) -> Void) {
        self.label = label; self.mm = mm; self.unit = unit; self.me = me; self.focus = focus; self.onMm = onMm
        _t = State(initialValue: mm > 0 ? Geo.fmtField(mm, unit, AppSettings.shared.lang == .en) : "")
    }
    var body: some View {
        let v = parseLen(t, unit)
        let b = Binding(get: { t }, set: { s in
            t = String(s.filter { $0.isNumber || $0 == "," || $0 == "." }.prefix(7))
            if let x = parseLen(t, unit), x <= 20_000 { onMm(x) }
        })
        GField(label: label, value: b, placeholder: "1,5", error: v == nil ? tr("tl.sizeErr") : nil, showError: !t.isEmpty, focus: focus, me: me,
               labelRight: unitWord(unit), decimal: true)
            .frame(maxWidth: .infinity)
    }
}

/// A tick box row: a surface the layout covers or not.
private struct TCheckRow: View {
    let title: String
    let sub: String?
    let on: Bool
    let action: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(on ? G.cobalt : Color.clear)
                RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(on ? G.cobalt : G.ink3, lineWidth: 2)
                if on { MIcon("check", .white, 14, 3) }
            }
            .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                T(title, ui(15, 700))
                if let sub { T(sub, num(12.5, 500, G.ink2)) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, 8).frame(minHeight: 56)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(on ? G.cobalt.opacity(0.08) : G.glass(0.6)))
        .pressable(0.98, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
    }
}

/// A surface without a room: a floor, a wall or a backsplash, and its two sizes.
private struct TPanelStep: View {
    @Binding var d: TileLayout
    let focus: FocusState<TSF?>.Binding
    var body: some View {
        let unit = AppSettings.shared.unit
        let pn = d.panel ?? panelFor(d.place)
        TAsk(title: tr("tl.s.panel"), help: tr("tl.s.panelH")) {
            Seg(items: [("floor", tr("tl.pk.floor")), ("wall", tr("tl.pk.wall")), ("apron", tr("tl.pk.apron"))], cur: pn.kind) { k in
                var np = panelFor(k); np.a = pn.a; d.panel = np
            }
            HStack(alignment: .top, spacing: 10) {
                THeightField(label: tr("tl.pa"), mm: pn.a, unit: unit, me: .h("pa" + pn.kind), focus: focus) { v in var x = d.panel ?? pn; x.a = v; d.panel = x }
                    .id("pa" + pn.kind)
                THeightField(label: tr(pn.kind == "floor" ? "tl.pbW" : "tl.pbH"), mm: pn.b, unit: unit, me: .h("pb" + pn.kind), focus: focus) { v in var x = d.panel ?? pn; x.b = v; d.panel = x }
                    .id("pb" + pn.kind)
            }
        }
    }
}
