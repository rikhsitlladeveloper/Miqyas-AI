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
        ZStack {
            RoomGrid().ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    GlassIconButton("back", tr("nt.back")) { app.pop() }.accessibilityIdentifier("back")
                    VStack(alignment: .leading, spacing: 0) {
                        T(dn(f.name), ui(19, 800, G.ink, lh: 1.2), lines: 1)
                        T(pieceLine(f, ws), ui(12, 400, G.ink2), lines: 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    GlassIconButton("undo", tr("common.undo"), tint: kit.canUndo(f.id) ? G.ink : PC.offIcon) { kit.undo(p.id, f.id) }.accessibilityIdentifier("kt.undo")
                    GlassIconButton("redo", tr("common.redo"), tint: kit.canRedo(f.id) ? G.ink : PC.offIcon) { kit.redo(p.id, f.id) }
                    GlassIconButton("more", tr("common.menu")) { app.sheet = .fMenu(pid: p.id, fid: f.id) }.accessibilityIdentifier("kt.menu")
                }
                .padding(.horizontal, 16).frame(height: 64)
                if let room = roomOf(p, f) { content(room) } else {
                    T(tr("kt.roomLost"), ui(15, 500, G.ink2, lh: 1.45)).padding(24)
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder private func content(_ room: Room) -> some View {
        let pid = p.id, fid = f.id
        HStack {
            Seg(items: [("p", tr("it.piece")), ("r", tr("it.inRoom"))], cur: d3 ? "r" : "p") { k in
                app.setTop(.wardrobe(pid: pid, fid: fid, step: 1, sec: 0, d3: k == "r"))
            }
            .frame(maxWidth: 280)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.bottom, 10)
        if d3 { Furniture3DPane(app: app, p: p, room: room) } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ItemPicture(f: f)
                    if let m = wardOfF(f) { card { ItemOptions(app: app, p: p, f: f, m: m) } }
                    card { ItemWhere(app: app, p: p, f: f, room: room) }
                    card { MatStep(app: app, p: p, f: f) }
                    CostCard(p: p, f: f)
                }
                .padding(.horizontal, 16).padding(.bottom, 28)
            }
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
    var body: some View {
        let s = AppSettings.shared
        let scene = pieceScene(f, s.workshop, s.mats)
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        ZStack(alignment: .bottomTrailing) {
            PieceView(scene: scene, hi: nil, label: nil)
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
            if o.bed == "drawers" {
                FToggle(label: tr("km.handles"), on: m.handles, id: "it.handles") { changeItem(p, f, m.id) { x in var n = x; n.handles.toggle(); return n } }
            }
        }
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
