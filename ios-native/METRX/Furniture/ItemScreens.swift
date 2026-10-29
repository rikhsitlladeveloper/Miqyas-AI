import SwiftUI
import UIKit

/*
 * The short designer of a bed, a bunk or loft bed, a table, the bar counter and the hallway's mirror panel (decided
 * 22 Oct 2026; Android ui/furniture/ItemScreens.kt): the piece in 3D, its sizes and its few options; materials, the
 * room and (Advanced) the cost as the wardrobe's. The rules are in Furniture/Core/Items.swift and Pieces.swift.
 */

/// Changes box mid of piece f (on the designer's undo list), its outer size following its options.
func changeItem(_ p: Project, _ f: Furniture, _ mid: String, _ fn: @escaping (Module) -> Module) {
    let s = AppSettings.shared, ws = s.workshop, snap = s.angleSnap
    KitOps.shared.change(p.id, f.id) { x in
        let room: Room? = x.roomId == nil ? nil : roomOf(p, x)
        var y = x
        y.modules = x.modules.map { $0.id == mid ? itemSized(fn($0), ws) : $0 }
        let lenA = room.flatMap { wallLen($0, snap, x.walls.first ?? "") }
        return packPiece(y, lenA, changed: mid, ws: ws)
    }
}

/// A size's label in the item designer.
private func sizeLabel(_ m: Module, _ key: String) -> String {
    switch key {
    case "w": return m.type == "mirror" ? "fz.mirW" : "wd.w"
    case "h": return m.type == "mirror" ? "fz.mirH" : m.type == "bed" ? "fb.h" : "fz.wH"
    case "d": return m.type == "bar" ? "fb.barD" : "wd.d"
    case "e": return "fz.elev"
    default: return "fb." + key
    }
}

struct ItemScreen: View {
    let app: AppModel
    let p: Project, f: Furniture
    let d3: Bool
    var body: some View {
        let kit = KitOps.shared
        let ws = AppSettings.shared.workshop
        let _ = kit.tick
        ZStack {
            RoomGrid().ignoresSafeArea()
            VStack(spacing: 0) {
                // "?" plays the hint again: tap a tool, turn the 3D, zoom (as the cabinets' designers)
                DesignerHead(app: app, p: p, f: f, sub: pieceLine(f, ws), sub2: floorLineText(f, .mm), onHelp: { DzcState.shared.startTeach() })
                if let room = roomOf(p, f) {
                    ZStack(alignment: .top) {
                        VStack(spacing: 0) { content(room) }
                        if DzcState.shared.teachOn { DzcTeach(item: true) { DzcState.shared.teachOn = false } }
                    }
                    .frame(maxHeight: .infinity)
                    // Designer C's slider (its tools' options in its place), then Undo/Redo · 2D/3D · "Narxni ko‘rish"
                    DzcItemBottom(app: app, p: p, f: f)
                    DesignerBar(app: app, p: p, f: f) {
                        DzcMiddle(canRedo: kit.canRedo(f.id), d3: d3, onRedo: { kit.redo(p.id, f.id); Haptic.tick() }) { v in
                            Haptic.tick()
                            app.setTop(.wardrobe(pid: p.id, fid: f.id, step: 1, sec: 0, d3: v))
                        }
                    }
                } else {
                    T(tr("kt.roomLost"), ui(15, 500, G.ink2, lh: 1.45)).padding(24)
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder private func content(_ room: Room) -> some View {
        if d3 { Furniture3DPane(app: app, p: p, room: room) } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ItemPicture(f: f)
                    if let m = wardOfF(f) { card { ItemOptions(app: app, p: p, f: f, m: m) } }
                    card { ItemWhere(app: app, p: p, f: f, room: room) }
                    card { MatStep(app: app, p: p, f: f) }
                    DesignCard(app: app, p: p, f: f)
                    CostCard(p: p, f: f)
                }
                .padding(.horizontal, 16).padding(.bottom, 28)
            }
            LivePrice(app: app, p: p, f: f)
        }
    }

    private func card<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) { c() }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.6))
    }
}

/// The piece in 3D, turned by a sideways drag.
private struct ItemPicture: View {
    let f: Furniture
    /// "See inside": the fronts hidden.
    @State private var bare = false
    var body: some View {
        let s = AppSettings.shared
        let scene = pieceScene(f, s.workshop, s.mats, bare: bare)
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        // a bed's drawers, a loft's cabinet: hide the fronts to see inside
        let fronts = f.modules.contains { m in m.sections.contains { $0.fronts.kind != "open" } || m.opt?.bed == "drawers" }
        ZStack(alignment: .bottomTrailing) {
            PieceView(scene: scene, hi: nil, label: nil)
            if fronts {
                InsidePill(on: bare) { bare.toggle() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(10)
            }
            T(tr("fx.drag"), ui(11, 600, G.ink3)).padding(10).allowsHitTesting(false)
        }
        .aspectRatio(1 / 0.8, contentMode: .fit)
        .clipShape(shape)
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
    }
}

/// Where the piece stands: against a wall or free in the room, and the plan to move it.
private struct ItemWhere: View {
    let app: AppModel
    let p: Project, f: Furniture
    let room: Room
    var body: some View {
        if f.roomId == nil { FreeBanner(app: app, p: p, f: f) } else {
            T(tr("it.where"), ui(15.5, 800))
            T(tr(canStandFree(f) ? "it.whereFree" : "it.whereWall"), ui(12.5, 400, G.ink2, lh: 1.4))
            GBtn(tr("fz.move"), kind: .secondary, icon: "room", height: 44, corner: 14, fontSize: 14) { app.push(.fPlace(pid: p.id, fid: f.id, rid: room.id)) }
                .accessibilityIdentifier("it.move")
        }
    }
}

/// One size of an item as a row; a tap opens its sheet.
private struct ISize: View {
    let app: AppModel
    let p: Project, f: Furniture, m: Module
    let key: String
    var body: some View {
        let v = itemGet(m, key)
        let none = (key == "mirW" || key == "mirH") && v == 0
        WValRow(label: tr(sizeLabel(m, key)), value: none ? tr("fb.none") : "\(v)" + U_MM, id: "it." + key) {
            app.sheet = .iField(pid: p.id, fid: f.id, mid: m.id, key: key)
        }
    }
}

/// The options of the piece's main box, by what it is.
private struct ItemOptions: View {
    let app: AppModel
    let p: Project, f: Furniture, m: Module
    var body: some View {
        T(tr("it.title"), ui(15.5, 800))
        switch m.type {
        case "bed": BedOptions(app: app, p: p, f: f, m: m)
        case "bunk", "loft": BunkOptions(app: app, p: p, f: f, m: m)
        // the big dining table: its seats, legs, top and chairs (GorkaViews.swift)
        case "table" where (m.opt?.seats ?? 0) > 0: BigTableOptions(app: app, p: p, f: f, m: m)
        case "table": TableOptions(app: app, p: p, f: f, m: m)
        case "bar": BarOptions(app: app, p: p, f: f, m: m)
        case "hooks": HooksOptions(app: app, p: p, f: f, m: m)
        default: EmptyView()
        }
    }
}

/// The main box's options changed (its outer size following).
private func setOpt(_ p: Project, _ f: Furniture, _ m: Module, _ fn: @escaping (ItemOpt) -> ItemOpt) {
    changeItem(p, f, m.id) { x in var n = x; n.opt = fn(x.opt ?? ItemOpt()); return n }
}

private struct BedOptions: View {
    let app: AppModel
    let p: Project, f: Furniture, m: Module
    var body: some View {
        let o = m.opt ?? ItemOpt()
        let kinds: [(String, String)] = BED_KINDS.map { ($0, tr("fb.bt." + $0)) }
        VStack(alignment: .leading, spacing: 10) {
            T(tr("fb.bt"), ui(14.5, 700))
            Seg(items: kinds, cur: o.bed) { k in setOpt(p, f, m) { var x = $0; x.bed = k; return x } }
            T(tr("fb.bt." + o.bed + ".s"), ui(12.5, 400, G.ink2, lh: 1.4))
            ForEach(["mw", "ml", "h", "hb"], id: \.self) { k in ISize(app: app, p: p, f: f, m: m, key: k) }
            // the drawers' handles one by one (25 Oct 2026), or all at once
            if o.bed == "drawers" { BedHandles(p: p, f: f, m: m) }
        }
    }
}

/// A bed's drawers as chips, each tapped to give it a handle or take it away, with "Hammasiga" / "Hech biriga".
private struct BedHandles: View {
    let p: Project, f: Furniture, m: Module
    var body: some View {
        let p = self.p, f = self.f, mid = m.id
        VStack(alignment: .leading, spacing: 10) {
            HandleButtons(ms: [m], onAll: { changeItem(p, f, mid) { allHandles($0, true) } }, onNone: { changeItem(p, f, mid) { allHandles($0, false) } })
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(handleFronts(m), id: \.key) { fr in self.chip(fr) }
                }
            }
        }
    }

    private func chip(_ fr: HFront) -> some View {
        let on = hasHandle(m, fr.key), p = self.p, f = self.f, mid = m.id, key = fr.key
        return FChip(label: frontName(m, fr) + " · " + tr(on ? "hd.yes" : "hd.no"), on: on) { changeItem(p, f, mid) { toggleHandle($0, key) } }
            .accessibilityIdentifier("front:" + key)
    }
}

private struct BunkOptions: View {
    let app: AppModel
    let p: Project, f: Furniture, m: Module
    var body: some View {
        let o = m.opt ?? ItemOpt()
        VStack(alignment: .leading, spacing: 10) {
            ForEach(["mw", "ml", "h"], id: \.self) { k in ISize(app: app, p: p, f: f, m: m, key: k) }
            T(tr("fb.lad"), ui(14.5, 700))
            Seg(items: [("L", tr("fb.lad.L")), ("R", tr("fb.lad.R"))], cur: o.ladder) { k in setOpt(p, f, m) { var x = $0; x.ladder = k; return x } }
            if m.type == "loft" { LoftUnder(app: app, p: p, f: f, under: o.under) }
        }
    }
}

/// What a loft bed has under it, and the button to design its desk or cabinet.
private struct LoftUnder: View {
    let app: AppModel
    let p: Project, f: Furniture
    let under: String
    var body: some View {
        let kinds: [(String, String)] = UNDER_KINDS.map { ($0, tr("fb.und." + $0)) }
        let pid = p.id, fid = f.id
        VStack(alignment: .leading, spacing: 10) {
            T(tr("fb.und"), ui(14.5, 700))
            Seg(items: kinds, cur: under, lines: 2) { k in
                if k != under { KitOps.shared.change(pid, fid) { x in withUnder(x, k, AppSettings.shared.workshop) } }
            }
            if let u = f.modules.first(where: { $0.type == "wardrobe" }) {
                GBtn(tr("it.under"), kind: .secondary, icon: "board", height: 44, corner: 14, fontSize: 14) {
                    KitOps.shared.sel = u.id
                    app.push(.wardrobe(pid: pid, fid: fid, step: 3, sec: 0, mod: u.id))
                }
                .accessibilityIdentifier("it.under")
            }
        }
    }
}

private struct TableOptions: View {
    let app: AppModel
    let p: Project, f: Furniture, m: Module
    var body: some View {
        let o = m.opt ?? ItemOpt()
        let legs: [(String, String)] = LEG_KINDS.map { ($0, tr("fb.lg." + $0)) }
        VStack(alignment: .leading, spacing: 10) {
            ForEach(["w", "d", "h"], id: \.self) { k in ISize(app: app, p: p, f: f, m: m, key: k) }
            T(tr("fb.lg"), ui(14.5, 700))
            Seg(items: legs, cur: o.legs, lines: 2) { k in setOpt(p, f, m) { var x = $0; x.legs = k; return x } }
            T(tr("fb.tp"), ui(14.5, 700))
            Seg(items: [("ldsp", tr("fb.tp.ldsp")), ("wt", tr("fb.tp.wt"))], cur: o.top, lines: 2) { k in setOpt(p, f, m) { var x = $0; x.top = k; return x } }
            FToggle(label: tr("fb.rc"), on: o.round, id: "it.round") { setOpt(p, f, m) { var x = $0; x.round.toggle(); return x } }
        }
    }
}

private struct BarOptions: View {
    let app: AppModel
    let p: Project, f: Furniture, m: Module
    var body: some View {
        let o = m.opt ?? ItemOpt()
        VStack(alignment: .leading, spacing: 10) {
            ForEach(["w", "d", "h", "over"], id: \.self) { k in ISize(app: app, p: p, f: f, m: m, key: k) }
            T(tr("fb.tp"), ui(14.5, 700))
            Seg(items: [("ldsp", tr("fb.tp.ldsp")), ("wt", tr("fb.tp.wt"))], cur: o.top, lines: 2) { k in setOpt(p, f, m) { var x = $0; x.top = k; return x } }
            FToggle(label: tr("fb.shelves"), on: o.shelves, id: "it.shelves") { setOpt(p, f, m) { var x = $0; x.shelves.toggle(); return x } }
            FToggle(label: tr("fb.foot"), on: o.foot, id: "it.foot") { setOpt(p, f, m) { var x = $0; x.foot.toggle(); return x } }
        }
    }
}

private struct HooksOptions: View {
    let app: AppModel
    let p: Project, f: Furniture, m: Module
    var body: some View {
        let o = m.opt ?? ItemOpt()
        VStack(alignment: .leading, spacing: 10) {
            ForEach(["w", "h", "e"], id: \.self) { k in ISize(app: app, p: p, f: f, m: m, key: k) }
            FStepper(label: tr("fb.hooks"), v: o.hooks, lo: 0, hi: 10, id: "it.hooks") { v in setOpt(p, f, m) { var x = $0; x.hooks = v; return x } }
            FToggle(label: tr("fb.shelf"), on: o.shelf, id: "it.shelf") { setOpt(p, f, m) { var x = $0; x.shelf.toggle(); return x } }
            ForEach(["mirW", "mirH"], id: \.self) { k in ISize(app: app, p: p, f: f, m: m, key: k) }
        }
    }
}

private enum IF2: Hashable { case a }

/// One size of an item (or of a dressing table's mirror), typed.
struct IFieldSheet: View {
    let app: AppModel
    let pid: String, fid: String, mid: String, key: String
    @State private var v: String
    @FocusState private var focus: IF2?
    init(app: AppModel, pid: String, fid: String, mid: String, key: String) {
        self.app = app; self.pid = pid; self.fid = fid; self.mid = mid; self.key = key
        let m = Store.shared.get(pid)?.furniture.first { $0.id == fid }?.modules.first { $0.id == mid }
        _v = State(initialValue: String(m.map { itemGet($0, key) } ?? 0))
    }
    var body: some View {
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }), let m = f.modules.first(where: { $0.id == mid }) {
            let range = itemRange(m, key)
            let start = itemGet(m, key)
            let vi = Int(v).flatMap { range.contains($0) ? $0 : nil }
            let title = tr(sizeLabel(m, key))
            let k = key
            let save = {
                guard let x = vi else { return }
                changeItem(p, f, m.id) { itemSet($0, k, x, AppSettings.shared.workshop) }
                app.sheet = nil
            }
            GlassSheet(title, onClose: { app.sheet = nil }) {
                GField(label: title, value: $v, placeholder: "\(start)", error: tr("km.bad", ["a": range.lowerBound, "b": range.upperBound]), showError: vi == nil,
                       focus: $focus, me: .a, submit: .done, onSubmit: save, labelRight: tr("u.mm"), number: true, id: "if.value")
                if key == "mirW" || key == "mirH" { T(tr("fb.mirNote"), ui(12.5, 400, G.ink2, lh: 1.4)) }
            } footer: {
                GBtn(tr("common.save"), enabled: vi != nil) { save() }.accessibilityIdentifier("if.save")
            }
            .onChange(of: v) { _, x in let t = String(x.filter(\.isNumber).prefix(4)); if t != x { v = t } }
            // the keyboard comes up with the sheet
            .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focus = .a } }
        }
    }
}

/// A piece's sizes in a line: a bed's mattress, a corner piece's two arms, else width × height × depth (mm).
func pieceLine(_ f: Furniture, _ ws: Workshop) -> String { sizeLine(f, ws, tr("u.mm")) }

/// A wall-hung piece's own short line, "poldan 1500 mm", in unit (the app's by default; the designers' mm); nil for a
/// piece on the floor (founder 29 Oct 2026).
func floorLineText(_ f: Furniture, _ unit: LenUnit? = nil) -> String? {
    guard let e = floorElev(f) else { return nil }
    let u = unit ?? AppSettings.shared.unit
    return tr("fz.offFloor", ["v": Geo.fmtLen(e, u, AppSettings.shared.lang == .en), "u": unitWord(u)])
}

/// What a card's picture is made from: the piece, its size, the workshop and the boards.
private struct PieceThumbKey: Equatable {
    let f: Furniture
    let w: Int, h: Int
    let ws: Workshop
    let mats: [Mat]
}

/// A small 3D picture of a piece (a bed, a stenka…) for its card, made off the main thread.
struct PieceThumb: View {
    let f: Furniture
    @State private var img: UIImage? = nil
    var body: some View {
        GeometryReader { geo in
            let w = min(900, max(40, geo.size.width)), h = min(900, max(40, geo.size.height))
            let s = AppSettings.shared
            let key = PieceThumbKey(f: f, w: Int(w), h: Int(h), ws: s.workshop, mats: s.mats)
            ZStack {
                if let img {
                    Image(uiImage: img).resizable().scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .task(id: key) {
                let piece = key.f, ws = key.ws, mats = key.mats, size = CGSize(width: w, height: h)
                let pic = await Task.detached(priority: .utility) { piecePicture(pieceScene(piece, ws, mats), size) }.value
                img = pic
            }
        }
    }
}

/* ---------------- Designer C: the short designer's slider ---------------- */

/// A bed's, a table's, a bar counter's or a mirror panel's tools (Designer C, the same slider as the cabinets'): its
/// sizes, the fronts' colour, the handles, where it stands, the boards.
struct DzcItemBottom: View {
    let app: AppModel
    let p: Project
    let f: Furniture
    var body: some View {
        let st = DzcState.shared
        VStack(spacing: 0) {
            if let t = st.tool, let m = wardOfF(f) { options(t, m) } else { DzcSlider(tools: tools()) { tap($0) } }
        }
        .frame(maxWidth: .infinity)
        .background { ZStack { Rectangle().fill(.ultraThinMaterial); Rectangle().fill(barTint) } }
        .overlay(alignment: .top) { Rectangle().fill(G.rim).frame(height: 1) }
        .bottomBar()
        .onAppear { DzcState.shared.enter(f.id) }
    }

    private func tools() -> [DzcTool] {
        var a = [DzcTool(id: "size", label: tr("dzc.t.size")), DzcTool(id: "decor", label: tr("dzc.t.decor"))]
        if f.modules.contains(where: { !handleFronts($0).isEmpty }) { a.append(DzcTool(id: "handle", label: tr("dzc.t.handle"))) }
        a += [DzcTool(id: "place", label: tr("dzc.t.place")), DzcTool(id: "mats", label: tr("dzc.t.mats"))]
        return a
    }

    private func tap(_ id: String) {
        Haptic.tick()
        switch id {
        case "place":
            if let rid = f.roomId { app.push(.fPlace(pid: p.id, fid: f.id, rid: rid)) } else { app.say("dzc.noRoomYet") }
        case "mats": app.sheet = .fMats(pid: p.id, fid: f.id)
        default: DzcState.shared.tool = id
        }
    }

    private static func keys(_ m: Module) -> [String] {
        switch m.type {
        case "bed": return ["mw", "ml", "h", "hb"]
        case "bunk", "loft": return ["mw", "ml", "h"]
        case "bar": return ["w", "d", "h", "over"]
        case "hooks": return ["w", "h", "e"]
        default: return ["w", "d", "h"]
        }
    }

    @ViewBuilder private func options(_ t: String, _ m: Module) -> some View {
        let back = { DzcState.shared.tool = nil }
        let pid = p.id, fid = f.id
        switch t {
        case "size":
            DzcOptRow(title: tr("dzc.t.size"), onBack: back) {
                ForEach(Self.keys(m), id: \.self) { k in
                    DzcOpt(label: tr(sizeLabel(m, k)) + " · \(itemGet(m, k))", glyph: "size", id: "dzc.it." + k) { app.sheet = .iField(pid: pid, fid: fid, mid: m.id, key: k) }
                }
            }
        case "handle":
            let cur = handleType(f)
            DzcOptRow(title: tr("dzc.t.handle"), sub: tr("dzc.wholeP"), onBack: back) {
                ForEach(["bar", "long", "knob", "push"], id: \.self) { k in
                    DzcOpt(label: tr("lk.h." + k), glyph: "h-" + k, on: cur == k, id: "dzc.h." + k) {
                        KitOps.shared.change(pid, fid) { withLook(withHandleType($0, k)) { $0 } }
                        dzcSaid(app, pid, fid, "dzc.handleAll", ["h": tr("lk.h." + k)])
                    }
                }
            }
        default:
            let cur = colourOf(frontOf(f, nil))
            DzcOptRow(title: tr("dzc.t.decor"), sub: tr("dzc.wholeP"), onBack: back) {
                ForEach(DZC_FRONTS, id: \.self) { s in
                    DzcSwatch(rgb: s.rgb, label: dzcFrontName(s.key), wood: s.wood, on: cur == s.key, id: "dzc.sw." + s.key) {
                        let board = dzcBoard(f, s.key)
                        KitOps.shared.change(pid, fid) { withLook(dzcFrontAll($0, board)) { $0 } }
                        dzcSaid(app, pid, fid, "dzc.decorAll", ["c": dzcFrontName(s.key), "d": dzcFrontName(s.key)])
                    }
                }
            }
        }
    }
}
