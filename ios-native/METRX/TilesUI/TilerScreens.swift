import SwiftUI
import Observation

/*
 * The tiler's own app (22 Oct 2026, built like the furniture maker's; Android ui/tiles/TilerScreens.kt): the Home with
 * new orders, an order's rooms with their tile layouts, the next step, and in the advanced app the counted tiles going
 * into the estimate.
 */

private let T_RULER = "M4 8h16a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2z M6 8v3M10 8v4M14 8v3M18 8v4"
private let T_ARROW = "M7 17L17 7M9 7h8v8"
let TILE_ICON = "M4 4h7v7H4z M13 4h7v7h-7z M4 13h7v7H4z M13 13h7v7h-7z"

private var en: Bool { AppSettings.shared.lang == .en }

/* ---------------- names ---------------- */

/// "Pol · Archa" — where a layout goes and its pattern.
func layoutTitle(_ l: TileLayout) -> String { tr(placeKey(l)) + " · " + tr("tl.p." + l.pattern) }

/// Where a layout goes, in words: the floor, the walls, a backsplash, a typed surface.
func placeKey(_ l: TileLayout) -> String {
    if l.roomId == nil, let pn = l.panel { return "tl.pk." + pn.kind }
    let ids = l.surfs.map(\.id)
    if ids.isEmpty { return "tl.pl." + l.place }
    if ids.allSatisfy({ $0 == "floor" }) { return "tl.pk.floor" }
    if ids.contains("floor") { return "tl.su.both" }
    if l.surfs.allSatisfy({ $0.mode == "band" }) { return "tl.pk.apron" }
    return "tl.su.walls"
}

/// "300 × 600 · 2 mm" — the tile and the joint.
func layoutSub(_ l: TileLayout) -> String {
    "\(l.a) × \(l.b) · " + tr("tl.jointV", ["n": l.joint]) + (l.rot != 0 ? " · \(l.rot)°" : "")
}

/* ---------------- rooms made behind the scenes ---------------- */

/// The rooms a tiler adds (string keys): a bathroom first.
let T_ROOMS = ["bath", "toilet", "kitchen", "hall", "living", "balcony", "other"]

func tRoomKey(_ t: String) -> String {
    switch t { case "toilet": return "tl.r.toilet"; case "balcony": return "tl.r.balcony"; default: return "fr." + t }
}

/// A workspace with a rectangular room in it, named name; returns the room's id.
@discardableResult func addTileRoom(_ pid: String, _ type: String, _ name: String) -> String {
    let now = nowMs()
    let wt: String
    switch type { case "bath", "toilet": wt = "bath"; case "kitchen": wt = "kitchen"; case "balcony": wt = "balcony"; default: wt = "room" }
    let w = Workspace(id: uid(), name: name, type: wt, created: now)
    let r = Room(id: uid(), floorId: w.id, name: name, created: now)
    Store.shared.update(pid) { $0.floors.append(w); $0.rooms.append(r) }
    return r.id
}

/// A room's extras, made when first needed.
func tileRoomOf(_ p: Project, _ rid: String) -> TileRoom { p.troom.first { $0.roomId == rid } ?? TileRoom(roomId: rid) }

func updateTileRoom(_ pid: String, _ rid: String, _ f: (inout TileRoom) -> Void) {
    Store.shared.update(pid) { p in
        var cur = tileRoomOf(p, rid)
        f(&cur)
        p.troom = p.troom.filter { $0.roomId != rid } + [cur]
    }
}

func updateLayout(_ pid: String, _ lid: String, _ f: (inout TileLayout) -> Void) {
    Store.shared.update(pid) { p in
        if let i = p.tiles.firstIndex(where: { $0.id == lid }) { f(&p.tiles[i]) }
    }
}

/* ---------------- Home ---------------- */

struct TilerHome: View {
    let app: AppModel
    var body: some View {
        let s = AppSettings.shared
        let first = s.builderName.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        let lines = tr("tl.lines").split(separator: "|").map(String.init)
        let orders = Store.shared.projects.filter(\.isTiler).sorted { $0.created > $1.created }
        VStack(spacing: 0) {
            GlassHeader { app.openLaser() }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        T(first.isEmpty ? tr("hm.hi0") : tr("hm.hi", ["n": first]), ui(34, 800, G.ink, lh: 1.1, ls: -0.02)).accessibilityAddTraits(.isHeader)
                        T(lines.isEmpty ? "" : lines[s.visit % lines.count], ui(17, 500, G.slate, lh: 1.35)).frame(maxWidth: 320, alignment: .leading)
                    }
                    .padding(.top, 18).padding(.bottom, 8)
                    newCard
                    HStack(spacing: 12) {
                        TTile(icon: T_RULER, title: tr("gl.meas"), sub: tr("gl.measS")) { app.push(.measure(calc: false)) }.accessibilityIdentifier("home.measure")
                        // the gallery needs an order: a new one, as on the big card
                        TTile(icon: TILE_ICON, title: tr("tl.gal"), sub: tr("tl.galS")) { app.push(.newProject(editId: nil)) }.accessibilityIdentifier("home.tGallery")
                    }
                    HStack {
                        T(tr("fo.recent"), ui(17, 800)).frame(maxWidth: .infinity, alignment: .leading)
                        if !orders.isEmpty { T(tr("fo.all"), ui(13.5, 700, G.cobalt2)).padding(.horizontal, 6).padding(.vertical, 8).pressable(0.97) { app.selectTab(.projects) } }
                    }
                    .padding(.top, 6)
                    if orders.isEmpty { T(tr("fo.noOrders"), ui(14, 400, G.ink2, lh: 1.45)) }
                    ForEach(orders.prefix(3)) { p in TOrderRow(p: p) { app.push(.project(id: p.id, tab: "rooms")) } }
                }
                .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 24 + NAV_SPACE)
            }
        }
    }

    private var newCard: some View {
        let big = RoundedRectangle(cornerRadius: 30, style: .continuous)
        return HStack(spacing: 14) {
            MIcon("plus", .white, 26, 2.4).frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(G.cobalt))
                .boxShadow(G.cobalt.opacity(0.4), blur: 22, y: 10)
            VStack(alignment: .leading, spacing: 2) { T(tr("fo.new"), ui(22, 800, G.ink, lh: 1.15, ls: -0.01)); T(tr("tl.newS"), ui(14, 400, G.ink2)) }
                .frame(maxWidth: .infinity, alignment: .leading)
            PathIcon(T_ARROW, G.ink, 20, 2.2)
        }
        .padding(18)
        .glassCard(big, shadowBlur: 36, shadowY: 16, shadowAlpha: 0.15)
        .pressable(0.985) { app.push(.newProject(editId: nil)) }
        .accessibilityElement(children: .combine).accessibilityIdentifier("home.new")
    }
}

private struct TTile: View {
    let icon: String
    let title: String
    let sub: String
    let action: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PathIcon(icon, G.cobalt, 24, 2)
            Spacer(minLength: 18)
            T(title, ui(17, 700)); T(sub, ui(12.5, 400, G.ink2))
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .glassCard(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .pressable(0.985, action)
        .accessibilityElement(children: .combine)
    }
}

/// A tiler's order in a list: its name, who, its layouts; the call button.
struct TOrderRow: View {
    let p: Project
    let action: () -> Void
    var body: some View {
        let sub = p.tiles.isEmpty ? tr("tl.noLayouts") : uniq(p.tiles.map { layoutTitle($0) }).joined(separator: ", ")
        HStack(spacing: 12) {
            Group {
                if let l = p.tiles.first { LookSwatch(id: l.look) }
                else { PathIcon(TILE_ICON, G.cobalt, 22, 2).frame(maxWidth: .infinity, maxHeight: .infinity).background(G.cobalt.opacity(0.1)) }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                T(dn(p.name), ui(15, 700), lines: 1)
                T(sub, ui(12.5, 500, G.ink2), lines: 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            CallButton(p: p)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .pressable(0.985, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// The strings once each, in their order.
private func uniq(_ xs: [String]) -> [String] {
    var seen = Set<String>()
    return xs.filter { seen.insert($0).inserted }
}

/* ---------------- the order's rooms and their layouts ---------------- */

struct TRoomsTab: View {
    let app: AppModel
    let p: Project
    var view = "list"
    var body: some View {
        let loose = p.tiles.filter { $0.roomId == nil }
        VStack(spacing: 10) {
            if p.floors.isEmpty && p.tiles.isEmpty {
                T(tr("tl.empty"), ui(14.5, 400, G.ink2), align: .center).padding(22).frame(maxWidth: .infinity)
                    .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
            }
            // every room of each workspace (an older project may have several in one), a workspace without one once
            ForEach(wsRooms(p)) { s in TRoomCard(app: app, p: p, w: s.w, room: s.room, several: s.several) }
            // layouts typed by their sizes, without a room
            if !loose.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    T(tr("tl.noRoomT"), ui(16, 700))
                    ForEach(loose) { l in LayoutLine(l: l) { app.push(.tView(pid: p.id, rid: nil, lid: l.id)) } }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
            }
            HStack(spacing: 8) {
                dashed("plus", tr("tl.addLayout"), "tl.addLayout") { app.push(.tGallery(pid: p.id)) }
                dashed("room", tr("fo.addRoom"), "tl.addRoom") { app.sheet = .tNewRoom(pid: p.id) }
            }
            if !p.rooms.isEmpty && view == "list" {
                GBtn(tr("pj.v2d"), kind: .secondary, icon: "room", height: 46, fontSize: 14.5) { app.setProjectView("2d") }.accessibilityIdentifier("pj.v2d")
            }
        }
        .padding(.horizontal, 16).padding(.top, 12)
    }

    private func dashed(_ icon: String, _ label: String, _ id: String, _ action: @escaping () -> Void) -> some View {
        HStack(spacing: 6) { MIcon(icon, G.cobalt2, 20, 2.2); T(label, ui(15, 700, G.cobalt2), lines: 1) }
            .frame(maxWidth: .infinity).frame(height: 56)
            .dashedGlass(20)
            .pressable(0.98, action)
            .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
            .accessibilityIdentifier(id)
    }
}

/// One workspace of a tiler's order: its room, its layouts, what to do next.
private struct TRoomCard: View {
    let app: AppModel
    let p: Project
    let w: Workspace
    let room: Room?
    var several = false
    var body: some View {
        let snap = AppSettings.shared.angleSnap
        let measured = room.map { measuredRoom($0, snap) } ?? false
        let ls = room.map { r in p.tiles.filter { $0.roomId == r.id } } ?? []
        let n = w.items.count
        VStack(alignment: .leading, spacing: 10) {
            head(room, measured)
            ForEach(ls) { l in LayoutLine(l: l) { app.push(.tView(pid: p.id, rid: l.roomId, lid: l.id)) } }
            if let room {
                if !measured { TodoRow(label: tr("ns.measureT")) { openRoom(app, p.id, room.id) } }
                else { TodoRow(label: tr("tl.addLayout")) { app.push(.tGallery(pid: p.id, rid: room.id)) } }
            } else {
                TodoRow(label: tr("fo.drawRoom")) { drawTileRoom(app, p.id, w) }
            }
            if n > 0 || room != nil {
                T(tr("fo.photos") + (n > 0 ? " · \(n)" : ""), ui(13, 600, G.cobalt2)).padding(.horizontal, 4).padding(.vertical, 6)
                    .pressable(0.97) { app.push(.space(pid: p.id, wid: w.id)) }
            }
        }
        .padding(12)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
    }

    private func head(_ room: Room?, _ measured: Bool) -> some View {
        let a = room?.dim("A").v, b = room?.dim("B").v, h = room?.dim("H").v
        let sub: String = {
            if measured, let a, let b, room?.isPoly != true {
                return Geo.fmtLen(a, .m, en) + " × " + Geo.fmtLen(b, .m, en) + U_M + (h.map { " · h " + Geo.fmtLen($0, .m, en) } ?? "")
            }
            if measured { return tr("tl.measured") }
            return tr(room != nil ? "fo.notMeasured" : "fo.notDrawn")
        }()
        return HStack(spacing: 12) {
            Group {
                if let room { RoomThumb(r: room).padding(4) } else { MIcon("room", G.cobalt, 24, 2) }
            }
            .frame(width: 64, height: 52)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(Theme.shared.dark ? 0.1 : 0.8)))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                T(wsRoomTitle(w, room, several), ui(16, 700), lines: 1)
                T(sub, ui(12.5, 400, G.ink2), lines: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if measured {
                T("3D", ui(13, 800, G.cobalt2)).padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(G.cobalt.opacity(0.1)))
            }
            MIcon("chev", G.ink3, 16, 2)
        }
        .contentShape(Rectangle())
        .pressable(0.99) {
            if let room { if measured { app.push(.tView(pid: p.id, rid: room.id)) } else { openRoom(app, p.id, room.id) } }
            else { app.push(.space(pid: p.id, wid: w.id)) }
        }
    }
}

/// One layout under its room: the tile's swatch, where and how, the tile and joint.
struct LayoutLine: View {
    let l: TileLayout
    let action: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            LookSwatch(id: l.look).frame(width: 34, height: 34).clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                T(layoutTitle(l), ui(14.5, 700), lines: 1)
                T(layoutSub(l), num(12.5, 500, G.ink2), lines: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MIcon("chev", G.ink3, 16, 2)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.glass(0.75)))
        .pressable(0.985, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Draws the first room of a workspace that has none yet.
func drawTileRoom(_ app: AppModel, _ pid: String, _ w: Workspace) {
    // a second tap does not add a second room
    if let have = Store.shared.get(pid)?.rooms.first(where: { $0.floorId == w.id }) { openRoom(app, pid, have.id); return }
    if !app.once() { return }
    let r = Room(id: uid(), floorId: w.id, name: floorName(w), created: nowMs())
    Store.shared.update(pid) { $0.rooms.append(r) }
    openRoom(app, pid, r.id)
}

/* ---------------- the next step ---------------- */

/// What to do now with a tiler's order, and the one button that does it.
struct TNextStep: View {
    let app: AppModel
    let p: Project
    private struct Step { let title: String; let sub: String?; let button: String; let go: () -> Void }

    private var step: Step? {
        let s = AppSettings.shared, snap = s.angleSnap
        let pid = p.id
        let rooms: [(Workspace, Room)] = roomsByWorkspace(p)
        let undrawn = p.floors.first { w in !p.rooms.contains { $0.floorId == w.id } }
        let unmeasured = rooms.first { wr in Geo.stepKeys(wr.1, snap).contains { wr.1.dim($0).status != "conf" } }
        let bare = rooms.first { wr in !p.tiles.contains { $0.roomId == wr.1.id } }
        let made = madeBy(p, "tl.e.")
        let pick = Step(title: tr("tl.ns.pickT"), sub: tr("tl.ns.pickS"), button: tr("ns.needB")) { app.push(.tGallery(pid: pid)) }
        if p.floors.isEmpty && p.tiles.isEmpty { return pick }
        if let undrawn { return Step(title: tr("ns.measureT"), sub: floorName(undrawn), button: tr("fo.drawRoom")) { drawTileRoom(app, pid, undrawn) } }
        if let u = unmeasured {
            let (w, r) = u
            return Step(title: tr("ns.measureT"), sub: tr("ns.measureS", ["r": floorName(w)]), button: tr("ns.measureB")) { openRoom(app, pid, r.id) }
        }
        if let b = bare {
            let (w, r) = b
            return Step(title: tr("tl.ns.roomT", ["r": floorName(w)]), sub: tr("tl.ns.roomS"), button: tr("ns.needB")) { app.push(.tGallery(pid: pid, rid: r.id)) }
        }
        if p.tiles.isEmpty { return pick }
        if !s.advanced { return Step(title: tr("ns.shareT"), sub: tr("ns.shareS"), button: tr("ns.shareB")) { app.push(.report(pid: pid, no: nil)) } }
        if !made {
            return Step(title: tr("tl.ns.estT"), sub: tr("tl.ns.estS"), button: tr("trc.apply")) {
                if let cur = Store.shared.get(pid) { applyTiles(app, cur) }
                app.setProjectTab("estimate")
            }
        }
        if p.quotes.isEmpty { return Step(title: tr("ns.quoteT"), sub: nil, button: tr("ns.quoteB")) { app.sheet = .issue(pid: pid) } }
        return nil
    }

    var body: some View {
        if let st = step {
            let navy = Color(argb: 0xFF0F1626)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    T(tr("ns.label"), ui(11.5, 600, Color.white.opacity(0.62)))
                    T(st.title, ui(15.5, 800, .white, lh: 1.25), lines: 2)
                    if let sub = st.sub { T(sub, ui(12.5, 500, Color.white.opacity(0.75)), lines: 2) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                T(st.button, ui(14, 800, navy), align: .center, lines: 2)
                    .padding(.horizontal, 14).padding(.vertical, 13).frame(minHeight: 46).frame(maxWidth: 150)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.white))
                    .pressable(0.97, st.go)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("ns.go")
            }
            .padding(.leading, 16).padding(.trailing, 10).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.shared.dark ? G.blueWash : navy))
            .padding(.horizontal, 16).padding(.top, 12)
        }
    }
}

/* ---------------- the advanced app: counts and the estimate ---------------- */

/// The adhesive's kg a m² as set (0 kept: no adhesive bought; 5 when unset or wrong).
func tileGlueBase() -> Double { glueBaseOf(AppSettings.shared.trade.glueKg) }

/// The order's counted tiles, worked out again only when the order or the settings change, away from the main thread
/// (a mosaic is many thousand tiles): the last count shows until the new one is ready, which is set on the main thread.
@Observable final class TileCountCache {
    static let shared = TileCountCache()
    struct In: Equatable { let tiles: [TileLayout]; let troom: [TileRoom]; let rooms: [Room]; let snap: Bool; let glue: Double }
    struct Made { let i: In; let c: TileCount }
    /// The counts made lately, by order and room ("pid|rid", "pid|*"): only set on the main thread.
    private var memo: [String: Made] = [:]
    /// What each count is being worked out from; only touched on the main thread.
    @ObservationIgnored private var want: [String: In] = [:]

    func of(_ p: Project, _ roomId: String? = nil) -> TileCount {
        let snap = AppSettings.shared.angleSnap
        let i = In(tiles: p.tiles, troom: p.troom, rooms: p.rooms, snap: snap, glue: tileGlueBase())
        let k = p.id + "|" + (roomId ?? "*")
        let m = memo[k]
        if let m, m.i == i { return m.c }
        if want[k] != i {
            want[k] = i
            let pp = p, rid = roomId, glue = i.glue
            DispatchQueue.global(qos: .userInitiated).async {
                let c = countOrder(pp, snap, glue, rid, all: rid == nil)
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.want[k] == i else { return }
                    if self.memo.count > 40 { self.memo = [:] }
                    self.memo[k] = Made(i: i, c: c)
                }
            }
        }
        return m?.c ?? TileCount()
    }
}

/// The order page's three numbers in the advanced app: tiled area, boxes, the estimate.
struct TNums: View {
    let p: Project
    var body: some View {
        if AppSettings.shared.advanced {
            let lang = AppSettings.shared.lang
            let c = TileCountCache.shared.of(p)
            let est = Money.short(p, Money.totals(p).g, lang == .en, tr("pl.mln"))
            VStack(spacing: 0) {
                Hairline()
                HStack(spacing: 12) {
                    TCell(label: tr("tl.area"), value: Num.fixed(c.m2, 1, lang), unit: tr("u.m2"))
                    TCell(label: tr("tl.boxes"), value: "\(c.boxes)", unit: nil)
                    TCell(label: tr("pl.est"), value: est.0, unit: est.1)
                }
                .padding(.horizontal, 4).padding(.top, 10)
            }
            .padding(.top, 11)
        }
    }
}

private struct TCell: View {
    let label: String
    let value: String
    let unit: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            T(label, ui(11.5, 400, G.ink2), lines: 1)
            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text(value).st(num(17, 800)).lineLimit(1)
                if let unit { Text(" " + unit).st(ui(10.5, 600, G.ink2)) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Puts the counted tiles into the order's estimate, in place of the calculator's lines made before; lines typed by hand
/// stay. Names and units are stored as keys, so they follow the app's and the report's language.
func applyTiles(_ app: AppModel, _ p: Project) {
    let st = AppSettings.shared
    let r = tileRows(p, st.trade, st.angleSnap) { k, v in k.hasPrefix("tu.") ? "@u." + String(k.dropFirst(3)) : keyName(k, v) }
    Store.shared.update(p.id) { pr in
        if pr.stage == "measure" { pr.stage = "estimate" }
        pr.estimate.materials = pr.estimate.materials.filter { !$0.id.hasPrefix("t-") } + r.mats.map { var x = $0; x.id = "t-" + uid(); return x }
        pr.estimate.labor = pr.estimate.labor.filter { !$0.id.hasPrefix("t-") } + r.labor.map { var x = $0; x.id = "t-" + uid(); return x }
    }
    app.say("trc.done", ["n": r.mats.count + r.labor.count])
}

/// The estimate tab's card: what the layouts take, and the button that puts it into the estimate.
struct TilesCard: View {
    let app: AppModel
    let p: Project
    var body: some View {
        let lang = AppSettings.shared.lang
        let c = TileCountCache.shared.of(p)
        let made = madeBy(p, "tl.e.")
        VStack(alignment: .leading, spacing: 8) {
            T(tr("tl.cardT"), ui(16, 800))
            T(tr("trc.tiler", ["a": Num.fixed(c.m2, 1, lang), "b": c.boxes]), num(14.5, 700))
            T(tr("tl.cardB"), ui(12.5, 400, G.ink2, lh: 1.4))
            if p.tiles.isEmpty { T(tr("tl.noLayouts"), ui(13, 500, G.amberInk, lh: 1.4)) }
            // a surface of too many tiles to count is not in these numbers: said before they go into the estimate
            if c.tooMany { T(tr("tl.tooMany"), ui(12.5, 600, G.amberInk, lh: 1.4)) }
            HStack(spacing: 8) {
                GBtn(tr(made ? "trc.update" : "trc.apply"), enabled: c.m2 > 0, height: 44, corner: 14, fontSize: 14, lines: 2) {
                    applyTiles(app, p)
                    if c.tooMany { app.say("tl.tooMany", kind: .info) }
                }
                    .accessibilityIdentifier("tl.apply")
                GBtn(tr("tl.prices"), kind: .secondary, icon: "sliders", height: 44, corner: 14, fontSize: 14, lines: 2) { app.sheet = .tPrices(pid: p.id) }
                    .accessibilityIdentifier("tl.prices")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.6))
    }
}

/// What a room's or an order's layouts take, line by line (the advanced app).
struct CountCard: View {
    let c: TileCount
    let title: String
    var onLayout: (() -> Void)? = nil
    var body: some View {
        let lang = AppSettings.shared.lang
        let d1 = { (v: Double) in Num.fixed(v, 1, lang) }
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                T(title, ui(15, 800)).frame(maxWidth: .infinity, alignment: .leading)
                T(d1(c.m2) + " " + tr("u.m2"), num(14, 700))
            }
            if c.tooMany { T(tr("tl.tooMany"), ui(12.5, 500, G.amberInk, lh: 1.35)) }
            ForEach(Array(c.needs.enumerated()), id: \.offset) { _, n in
                Hairline()
                needRow(n)
            }
            Hairline()
            TKv(k: tr("tl.e.glue0"), v: tr("tl.bagsV", ["n": c.glueBags, "k": d1(c.glueKg)]))
            TKv(k: tr("tl.e.grout0"), v: d1(c.groutKg) + " " + tr("u.kg"))
            if c.skirtM > 0 { TKv(k: tr("tl.skirt"), v: d1(c.skirtM) + U_M) }
            if c.profileM > 0 { TKv(k: tr("tl.prof"), v: d1(c.profileM) + U_M) }
            if c.wpM2 > 0 { TKv(k: tr("tl.wp"), v: d1(c.wpM2) + " " + tr("u.m2")) }
            if let onLayout {
                T(tr("tl.countSet"), ui(13.5, 700, G.cobalt2)).padding(.vertical, 6).padding(.horizontal, 2)
                    .pressable(0.97, onLayout).accessibilityAddTraits(.isButton)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.6))
    }

    private func needRow(_ n: TileNeed) -> some View {
        let sk = n.skirtTiles > 0 ? " · " + tr("tl.cntSk", ["n": n.skirtTiles]) : ""
        return HStack(spacing: 10) {
            LookSwatch(id: n.look).frame(width: 30, height: 30).clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                T("\(n.a) × \(n.b) · " + tr("tl.lk." + n.look), ui(13.5, 700), lines: 1)
                T(tr("tl.cnt", ["w": n.whole, "c": n.cut, "r": n.reused]) + sk, ui(12, 400, G.ink2, lh: 1.35))
                // layouts of this tile with different spares: no single % to show
                T(n.spare >= 0 ? tr("tl.cntSpare", ["t": n.tiles + n.skirtTiles, "p": n.spare, "s": n.withSpare])
                    : tr("tl.cntSpareMix", ["t": n.tiles + n.skirtTiles, "s": n.withSpare]), ui(12, 400, G.ink2, lh: 1.35))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 1) {
                T(tr("tl.boxN", ["n": n.boxes]), num(14, 800))
                if n.perBox > 0 { T(tr("tl.perBox", ["n": n.perBox]), ui(11, 400, G.ink3)) }
            }
        }
    }
}

private struct TKv: View {
    let k: String
    let v: String
    var body: some View {
        HStack {
            T(k, ui(13, 500, G.ink2)).frame(maxWidth: .infinity, alignment: .leading)
            T(v, num(13.5, 700))
        }
    }
}

/* ---------------- sheets ---------------- */

struct TileSheet: View {
    let app: AppModel
    let sheet: Sheet
    static func handles(_ s: Sheet) -> Bool {
        switch s { case .tNewRoom, .tFixForm, .tCount, .tPrices: return true; default: return false }
    }
    var body: some View {
        switch sheet {
        case .tNewRoom(let pid): TNewRoomSheet(app: app, pid: pid)
        case .tFixForm(let pid, let rid, let fid, let type): TFixSheet(app: app, pid: pid, rid: rid, fid: fid, type: type)
        case .tCount(let pid, let lid): TCountSheet(app: app, pid: pid, lid: lid)
        case .tPrices(let pid): TPricesSheet(app: app, pid: pid)
        default: EmptyView()
        }
    }
}

private enum TRF: Hashable { case name }

private struct TNewRoomSheet: View {
    let app: AppModel
    let pid: String
    @State private var type: String
    @State private var name: String
    @FocusState private var focus: TRF?
    init(app: AppModel, pid: String) {
        self.app = app; self.pid = pid
        let p = Store.shared.get(pid)
        let t = (p?.floors.contains { $0.type == "bath" } ?? false) ? "kitchen" : "bath"
        _type = State(initialValue: t)
        _name = State(initialValue: TNewRoomSheet.nameFor(t, p))
    }
    static func nameFor(_ t: String, _ p: Project?) -> String {
        guard let p else { return tr(tRoomKey(t)) }
        return nextName(p, tRoomKey(t))
    }
    var body: some View {
        let p = Store.shared.get(pid)
        GlassSheet(tr("fo.addRoom"), onClose: { app.sheet = nil }) {
            T(tr("fr.type"), ui(15, 700))
            FlowLayout(spacing: 8) {
                ForEach(T_ROOMS, id: \.self) { t in FChip(label: tr(tRoomKey(t)), on: t == type) { type = t; name = TNewRoomSheet.nameFor(t, p) } }
            }
            GField(label: tr("fr.name"), value: $name, placeholder: tr(tRoomKey(type)), error: name.trimmingCharacters(in: .whitespaces).isEmpty ? tr("nr.nameReq") : nil,
                   showError: true, focus: $focus, me: .name, submit: .done, onSubmit: create)
                .onChange(of: name) { _, n in if n.count > NAME_MAX { name = String(n.prefix(NAME_MAX)) } }
        } footer: {
            GBtn(tr("fo.drawRoom"), enabled: !name.trimmingCharacters(in: .whitespaces).isEmpty, create).accessibilityIdentifier("tl.roomCreate")
        }
    }
    private func create() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, app.once() else { return }
        // a suggested name is kept as its key, so it follows the language
        let rid = addTileRoom(pid, type, suggestedName(n, tRoomKey(type)))
        app.sheet = nil
        openRoom(app, pid, rid)
    }
}

private enum TFF: Hashable { case f(Int) }

/// A shower tray or a bath: which wall, where along it, its size.
private struct TFixSheet: View {
    let app: AppModel
    let pid: String
    let rid: String
    let fid: String?
    let type: String
    @State private var wall: String
    @State private var texts: [String]
    @FocusState private var focus: TFF?
    private let start: TFix
    private let old: TFix?
    private static let KEYS = ["off", "w", "d", "h"]

    init(app: AppModel, pid: String, rid: String, fid: String?, type: String) {
        self.app = app; self.pid = pid; self.rid = rid; self.fid = fid; self.type = type
        let s = AppSettings.shared
        let p = Store.shared.get(pid)
        let r = p?.rooms.first { $0.id == rid }
        let old = fid.flatMap { id in p.flatMap { tileRoomOf($0, rid).fixes.first { $0.id == id } } }
        self.old = old
        var st: TFix
        if let old { st = old } else {
            st = type == "bath" ? TFix(id: uid(), type: "bath", wall: "A", off: 0, w: 1700, d: 700, h: 560) : TFix(id: uid(), type: "tray", wall: "A", off: 0, w: 900, d: 900, h: 150)
            // a new one goes against the first wall it fits on without a door in the way
            if let r {
                let ws = Geo.walls(r, s.angleSnap)
                let need = st.w
                let fit = ws.first { w in (w.len ?? 0) >= need && !r.openings.contains { o in o.wall == w.id && o.type == "door" && o.off < need } }
                st.wall = fit?.id ?? ws.first?.id ?? "A"
            }
        }
        self.start = st
        _wall = State(initialValue: st.wall)
        _texts = State(initialValue: [st.off, st.w, st.d, st.h].map { Geo.fmtField($0, s.unit, s.lang == .en) })
    }

    /// The typed values in mm: the offset may be 0 (in the corner); the sizes may not.
    private func vals(_ unit: LenUnit) -> [Int?] {
        var out: [Int?] = []
        for (i, t) in texts.enumerated() {
            if i > 0 { out.append(parseLen(t, unit)); continue }
            if t.trimmingCharacters(in: .whitespaces).isEmpty { out.append(0); continue }
            if let v = Geo.parseDec(t, Geo.unitDecimals(unit)).value { out.append(Int(v)) } else { out.append(nil) }
        }
        return out
    }

    var body: some View {
        let s = AppSettings.shared, unit = s.unit
        if let p = Store.shared.get(pid), let r = p.rooms.first(where: { $0.id == rid }) {
            let ws = Geo.walls(r, s.angleSnap)
            let v = vals(unit)
            let len = ws.first { $0.id == wall }?.len
            let err: String? = {
                if v.contains(where: { $0 == nil }) { return tr("tl.fixErr") }
                if let len, (v[0] ?? 0) + (v[1] ?? 0) > len { return tr("tl.fixLong") }
                return nil
            }()
            GlassSheet(tr(start.type == "bath" ? "tl.bath" : "tl.tray"), onClose: { app.sheet = nil }) {
                T(tr("tl.fixB"), ui(13.5, 400, G.ink2, lh: 1.4))
                T(tr("tl.fixWall"), ui(15, 700))
                FlowLayout(spacing: 8) {
                    ForEach(ws.map(\.id), id: \.self) { id in FChip(label: tr("tl.wallN", ["w": id]), on: id == wall) { wall = id } }
                }
                ForEach([0, 2], id: \.self) { i in
                    HStack(alignment: .top, spacing: 10) { field(i, unit); field(i + 1, unit) }
                }
                if let err { T(err, ui(13, 500, G.err)) }
            } footer: {
                GBtn(tr("common.save"), enabled: err == nil) { save(p, r, v, err) }.accessibilityIdentifier("tl.fixSave")
                if let old { GBtn(tr("common.delete"), kind: .secondary) { delete(p, r, old) }.accessibilityIdentifier("tl.fixDel") }
            }
        }
    }

    private func field(_ i: Int, _ unit: LenUnit) -> some View {
        let text = Binding(get: { i < texts.count ? texts[i] : "" }, set: { nv in
            if i < texts.count { texts[i] = String(nv.filter { $0.isNumber || $0 == "," || $0 == "." }.prefix(8)) }
        })
        return GField(label: tr("tl.fix." + TFixSheet.KEYS[i]), value: text, placeholder: "0", focus: $focus, me: .f(i), labelRight: unitWord(unit), decimal: true)
            .frame(maxWidth: .infinity)
    }

    private func save(_ p: Project, _ r: Room, _ v: [Int?], _ err: String?) {
        guard err == nil, app.once(), let off = v[0], let w = v[1], let d = v[2], let h = v[3] else { return }
        var f = start
        f.wall = wall; f.off = off; f.w = w; f.d = d; f.h = h
        let fx = f
        updateTileRoom(p.id, r.id) { t in t.fixes = t.fixes.filter { $0.id != fx.id } + [fx] }
        // a new bath: its front goes into the room's wall layouts that cover its wall
        if old == nil && fx.type == "bath" {
            Store.shared.update(p.id) { pr in
                for i in pr.tiles.indices where pr.tiles[i].roomId == r.id && pr.tiles[i].surfs.contains(where: { $0.id == fx.wall }) {
                    pr.tiles[i].surfs.append(TSurf(id: "bath:" + fx.id))
                }
            }
        }
        app.sheet = nil; app.say("tl.fixSaved")
    }

    private func delete(_ p: Project, _ r: Room, _ old: TFix) {
        updateTileRoom(p.id, r.id) { t in t.fixes = t.fixes.filter { $0.id != old.id } }
        Store.shared.update(p.id) { pr in
            for i in pr.tiles.indices { pr.tiles[i].surfs = pr.tiles[i].surfs.filter { $0.id != "bath:" + old.id } }
        }
        app.sheet = nil; app.say("tl.fixDel")
    }
}

private enum TCF: Hashable { case spare, pcs, price }

/// A layout's counting in the advanced app: the spare, what a box holds, the tile's price.
private struct TCountSheet: View {
    let app: AppModel
    let pid: String
    let lid: String
    @State private var spare: String
    @State private var pcs: String
    @State private var price: String
    @FocusState private var focus: TCF?
    init(app: AppModel, pid: String, lid: String) {
        self.app = app; self.pid = pid; self.lid = lid
        let l = Store.shared.get(pid)?.tiles.first { $0.id == lid }
        _spare = State(initialValue: l.map { "\(spareOf($0))" } ?? "5")
        _pcs = State(initialValue: l.map { "\(perBox($0))" } ?? "4")
        let pr = l?.price ?? ""
        _price = State(initialValue: pr.trimmingCharacters(in: .whitespaces).isEmpty ? AppSettings.shared.trade.pTile : pr)
    }
    var body: some View {
        if let p = Store.shared.get(pid), let l = p.tiles.first(where: { $0.id == lid }) {
            let sp = Int(spare).flatMap { (0...50).contains($0) ? $0 : nil }
            let pc = Int(pcs).flatMap { (1...500).contains($0) ? $0 : nil }
            let ok = sp != nil && pc != nil
            GlassSheet(tr("tl.countSet"), onClose: { app.sheet = nil }) {
                T(layoutTitle(l) + " · " + layoutSub(l), ui(14, 600, G.ink2))
                GField(label: tr("tl.spare"), value: digits($spare, 2), placeholder: "5", error: sp == nil ? tr("tl.spareErr") : nil, showError: true,
                       focus: $focus, me: .spare, labelRight: "%", number: true)
                GField(label: tr("tl.perBoxF"), value: digits($pcs, 3), placeholder: "4", error: pc == nil ? tr("err.zero") : nil, showError: true,
                       focus: $focus, me: .pcs, labelRight: tr("u.pcs"), number: true)
                GField(label: tr("trf.pTile"), value: digits($price, 12), placeholder: "0", focus: $focus, me: .price, submit: .done, labelRight: "/" + tr("u.m2"), number: true)
                T(tr("tl.countNote"), ui(12.5, 400, G.ink2, lh: 1.4))
            } footer: {
                GBtn(tr("common.save"), enabled: ok) {
                    guard let sp, let pc else { return }
                    let pr = price.filter { $0.isNumber }
                    updateLayout(pid, lid) { x in x.spare = sp; x.boxPcs = pc; x.boxM2 = ""; x.price = pr }
                    app.sheet = nil; app.say("common.save")
                }
                .accessibilityIdentifier("tl.countSave")
            }
        }
    }
    private func digits(_ b: Binding<String>, _ n: Int) -> Binding<String> {
        Binding(get: { b.wrappedValue }, set: { v in b.wrappedValue = String(v.filter { $0.isASCII && $0.isNumber }.prefix(n)) })
    }
}

/// One price of the tiler's: its key, unit, and how it is read from and written into the settings.
private struct TPField {
    let key: String
    let unit: String
    let get: (TradeSet) -> String
    let set: (inout TradeSet, String) -> Void
}

private let T_PRICE_FIELDS: [TPField] = [
    TPField(key: "pTile", unit: "/m²", get: { $0.pTile }, set: { t, v in t.pTile = v }),
    TPField(key: "glueKg", unit: "kg/m²", get: { $0.glueKg }, set: { t, v in t.glueKg = v }),
    TPField(key: "pGlue", unit: "/25 kg", get: { $0.pGlue }, set: { t, v in t.pGlue = v }),
    TPField(key: "pGrout", unit: "/kg", get: { $0.pGrout }, set: { t, v in t.pGrout = v }),
    TPField(key: "pProf", unit: "/m", get: { $0.pProf }, set: { t, v in t.pProf = v }),
    TPField(key: "pWp", unit: "/m²", get: { $0.pWp }, set: { t, v in t.pWp = v }),
    TPField(key: "lTile", unit: "/m²", get: { $0.lTile }, set: { t, v in t.lTile = v }),
    TPField(key: "lSkirt", unit: "/m", get: { $0.lSkirt }, set: { t, v in t.lSkirt = v }),
    TPField(key: "lProf", unit: "/m", get: { $0.lProf }, set: { t, v in t.lProf = v }),
    TPField(key: "lWp", unit: "/m²", get: { $0.lWp }, set: { t, v in t.lWp = v })
]

/// The tiler's prices, one set for all orders: adhesive, grout, profiles, waterproofing and the labour.
private struct TPricesSheet: View {
    let app: AppModel
    let pid: String?
    @State private var texts: [String]
    @FocusState private var focus: String?
    init(app: AppModel, pid: String?) {
        self.app = app; self.pid = pid
        let t0 = AppSettings.shared.trade
        _texts = State(initialValue: T_PRICE_FIELDS.map { $0.get(t0) })
    }
    var body: some View {
        GlassSheet(tr("tl.prices"), onClose: { app.sheet = nil }) {
            ForEach(Array(stride(from: 0, to: T_PRICE_FIELDS.count, by: 2)), id: \.self) { i in
                HStack(alignment: .top, spacing: 10) {
                    field(i)
                    if i + 1 < T_PRICE_FIELDS.count { field(i + 1) } else { Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                }
            }
            T(tr("tl.pricesNote"), ui(12.5, 400, G.ink2, lh: 1.4))
        } footer: {
            GBtn(tr("common.save")) { save() }.accessibilityIdentifier("tl.pricesSave")
        }
    }

    private func label(_ key: String) -> String {
        tr(key.hasPrefix("l") || key.hasPrefix("pP") || key.hasPrefix("pW") ? "tl.f." + key : "trf." + key)
    }

    private func field(_ i: Int) -> some View {
        let f = T_PRICE_FIELDS[i]
        let dec = f.key == "glueKg"
        let text = Binding(get: { i < texts.count ? texts[i] : "" }, set: { v in
            let c = v.filter { $0.isASCII && ($0.isNumber || (dec && ($0 == "," || $0 == "."))) }.replacingOccurrences(of: ",", with: ".")
            if i < texts.count { texts[i] = String(c.prefix(12)) }
        })
        return GField(label: label(f.key), value: text, placeholder: "0", focus: $focus, me: f.key, labelRight: unitText(f.unit), number: !dec, decimal: dec, id: "tlf." + f.key)
            .frame(maxWidth: .infinity)
    }

    private func save() {
        var t = AppSettings.shared.trade
        for (i, f) in T_PRICE_FIELDS.enumerated() where i < texts.count {
            let v = texts[i].trimmingCharacters(in: .whitespaces)
            if !v.isEmpty { f.set(&t, v) }
        }
        AppSettings.shared.setTradeSet(t)
        app.sheet = nil
        if let id = pid, let pr = Store.shared.get(id), madeBy(pr, "tl.e.") { applyTiles(app, pr) }
        else { app.say("common.save") }
    }
}
