import SwiftUI

/*
 * The electrician's own app (22 Oct 2026, built like the tiler's; Android ui/elec/ElecScreens.kt): the Home with new
 * orders, an order's rooms with their devices, the next step, and in the advanced app the cable, breakers and labour
 * going into the estimate.
 */

private let E_RULER = "M4 8h16a2 2 0 0 1 2 2v4a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2v-4a2 2 0 0 1 2-2z M6 8v3M10 8v4M14 8v3M18 8v4"
private let E_ARROW = "M7 17L17 7M9 7h8v8"
let BOLT = "M13 2L4 14h7l-1 8 9-12h-7l1-8z"

private var en: Bool { AppSettings.shared.lang == .en }

/* ---------------- changing the order ---------------- */

func updateElec(_ pid: String, _ f: (inout ElecOrder) -> Void) {
    Store.shared.update(pid) { p in f(&p.elec) }
}

func updateERoom(_ pid: String, _ rid: String, _ f: (inout ElecRoom) -> Void) {
    updateElec(pid) { e in
        var cur = e.room(rid)
        f(&cur)
        e.rooms = e.rooms.filter { $0.roomId != rid } + [cur]
    }
}

func updateDev(_ pid: String, _ did: String, _ f: (inout ElecDev) -> Void) {
    updateElec(pid) { e in
        if let i = e.devs.firstIndex(where: { $0.id == did }) { f(&e.devs[i]) }
    }
}

/// The rooms an electrician adds (strings keys el.k.*): a kitchen first.
func eKindKey(_ k: String) -> String { "el.k." + k }

/// The strings once each, in their order.
private func eUniq(_ xs: [String]) -> [String] {
    var seen = Set<String>()
    return xs.filter { seen.insert($0).inserted }
}

/// A workspace with a rectangular room in it, named name, of kind; returns the room's id.
@discardableResult func addElecRoom(_ pid: String, _ kind: String, _ name: String) -> String {
    let now = nowMs()
    let wt: String
    switch kind { case "kitchen": wt = "kitchen"; case "bath": wt = "bath"; default: wt = "room" }
    let w = Workspace(id: uid(), name: name, type: wt, created: now)
    let r = Room(id: uid(), floorId: w.id, name: name, created: now)
    Store.shared.update(pid) { p in
        p.floors.append(w); p.rooms.append(r)
        p.elec.rooms.append(ElecRoom(roomId: r.id, kind: kind))
    }
    return r.id
}

/// Takes the room's sockets and switches marked on its walls in as devices (once each).
func takeInPoints(_ pid: String, _ rid: String) {
    guard let p = Store.shared.get(pid), let c = ctxOf(p, rid, AppSettings.shared.angleSnap) else { return }
    let got = fromSitePoints(c, { uid() })
    if got.isEmpty { return }
    Store.shared.update(pid) { pr in
        var er = pr.elec.room(rid)
        er.seen = eUniq(er.seen + got.compactMap(\.from))
        pr.elec.devs += got
        pr.elec.rooms = pr.elec.rooms.filter { $0.roomId != rid } + [er]
    }
}

/// Puts kit k with choices o into measured room rid; the panel goes in the hallway when there is none yet. Returns how
/// many points.
@discardableResult func applyKit(_ pid: String, _ rid: String, _ k: ElecKit, _ o: KitOpts) -> Int {
    takeInPoints(pid, rid)
    let snap = AppSettings.shared.angleSnap
    guard let p = Store.shared.get(pid), let c = ctxOf(p, rid, snap) else { return 0 }
    let ds = placeKit(k, c, p.elec.devs.filter { $0.roomId == rid }, { uid() }, o, livePanel(p))
    let kind = c.kind
    Store.shared.update(pid) { pr in
        var er = pr.elec.room(rid)
        if er.kind.isEmpty { er.kind = kind }
        er.kits.append(k.id)
        pr.elec.devs += ds
        pr.elec.rooms = pr.elec.rooms.filter { $0.roomId != rid } + [er]
        // a panel left on a deleted room counts as none
        if livePanel(pr) == nil {
            let d = defaultPanel(pr, snap)
            if let d { pr.elec.panel = d }
        }
    }
    return ds.count
}

/// Kits chosen for rooms before they were measured go in once the rooms are.
func applyPending(_ app: AppModel, _ pid: String) {
    guard let p = Store.shared.get(pid) else { return }
    let snap = AppSettings.shared.angleSnap
    for er in p.elec.rooms where !er.pend.isEmpty {
        guard let r = p.rooms.first(where: { $0.id == er.roomId }), Geo.ready3D(r, snap) else { continue }
        let picks = er.pend
        updateERoom(pid, er.roomId) { $0.pend = [] }
        for kp in picks {
            if let k = kitOf(kp.kit) { applyKit(pid, er.roomId, k, KitOpts(light: kp.light, led: kp.led, ac: kp.ac, low: kp.low)) }
        }
        app.say("el.pendDone", ["r": dn(r.name)])
    }
}

/// The order's circuits, routes, counts and warnings, worked out again only when the order changes.
final class ElecCalcCache {
    static let shared = ElecCalcCache()
    private struct In: Equatable { let elec: ElecOrder; let rooms: [Room]; let floors: [Workspace]; let snap: Bool }
    private var memo: [String: (In, ElecCalc)] = [:]
    func of(_ p: Project) -> ElecCalc {
        let i = In(elec: p.elec, rooms: p.rooms, floors: p.floors, snap: AppSettings.shared.angleSnap)
        if let m = memo[p.id], m.0 == i { return m.1 }
        let c = calcOf(p, i.snap)
        if memo.count > 40 { memo = [:] }
        memo[p.id] = (i, c)
        return c
    }
}

/// Each device's circuit.
func circuitByDev(_ calc: ElecCalc) -> [String: Circuit] {
    var out: [String: Circuit] = [:]
    for cc in calc.circuits { for d in cc.devs { out[d.id] = cc } }
    return out
}

/* ---------------- names ---------------- */

/// "6 rozetka · 2 vyklyuchatel · 3 chiroq" — a room's devices by kind.
func devSummary(_ ds: [ElecDev]) -> String {
    var parts: [String] = []
    for c in CATS {
        let n = ds.filter { devType($0.t).cat == c }.count
        if n > 0 { parts.append(tr("el.cn." + c, ["n": n])) }
    }
    return parts.isEmpty ? tr("el.noDevs") : parts.joined(separator: " · ")
}

/// A room's name in the order: its workspace's, or its own.
func eRoomName(_ p: Project, _ r: Room) -> String { p.floors.first { $0.id == r.floorId }.map { floorName($0) } ?? dn(r.name) }

/* ---------------- Home ---------------- */

struct ElecHome: View {
    let app: AppModel
    var body: some View {
        let s = AppSettings.shared
        let first = s.builderName.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        let lines = tr("el.lines").split(separator: "|").map(String.init)
        let orders = Store.shared.projects.filter(\.isElec).sorted { $0.created > $1.created }
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
                        ETile(icon: E_RULER, title: tr("gl.meas"), sub: tr("gl.measS")) { app.push(.measure(calc: false)) }.accessibilityIdentifier("home.measure")
                        // the gallery needs an order: a new one, as on the big card
                        ETile(icon: BOLT, title: tr("el.gal"), sub: tr("el.galS")) { app.push(.newProject(editId: nil)) }.accessibilityIdentifier("home.eGallery")
                    }
                    HStack {
                        T(tr("fo.recent"), ui(17, 800)).frame(maxWidth: .infinity, alignment: .leading)
                        if !orders.isEmpty { T(tr("fo.all"), ui(13.5, 700, G.cobalt2)).padding(.horizontal, 6).padding(.vertical, 8).pressable(0.97) { app.selectTab(.projects) } }
                    }
                    .padding(.top, 6)
                    if orders.isEmpty { T(tr("fo.noOrders"), ui(14, 400, G.ink2, lh: 1.45)) }
                    ForEach(orders.prefix(3)) { p in EOrderRow(p: p) { app.push(.project(id: p.id, tab: "rooms")) } }
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
            VStack(alignment: .leading, spacing: 2) { T(tr("fo.new"), ui(22, 800, G.ink, lh: 1.15, ls: -0.01)); T(tr("el.newS"), ui(14, 400, G.ink2)) }
                .frame(maxWidth: .infinity, alignment: .leading)
            PathIcon(E_ARROW, G.ink, 20, 2.2)
        }
        .padding(18)
        .glassCard(big, shadowBlur: 36, shadowY: 16, shadowAlpha: 0.15)
        .pressable(0.985) { app.push(.newProject(editId: nil)) }
        .accessibilityElement(children: .combine).accessibilityIdentifier("home.new")
    }
}

private struct ETile: View {
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

/// An electrician's order in a list: its name, its devices; the call button.
struct EOrderRow: View {
    let p: Project
    let action: () -> Void
    var body: some View {
        let e = p.elec
        let sub: String = e.devs.isEmpty && e.free.isEmpty ? tr("el.noDevs")
            : devSummary(e.devs) + (e.free.isEmpty ? "" : " · " + tr("el.freeN", ["n": e.free.count]))
        HStack(spacing: 12) {
            PathIcon(BOLT, G.cobalt, 22, 2)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.cobalt.opacity(0.1)))
            VStack(alignment: .leading, spacing: 3) {
                T(dn(p.name), ui(15, 700), lines: 1)
                T(sub, ui(12.5, 500, G.ink2), lines: 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            CallButton(p: p)
        }
        .orderCard(p, action)
    }
}

/* ---------------- the order's rooms ---------------- */

struct ERoomsTab: View {
    let app: AppModel
    let p: Project
    var view = "list"
    var body: some View {
        let calc = ElecCalcCache.shared.of(p)
        let pid = p.id
        VStack(spacing: 10) {
            if p.floors.isEmpty && p.elec.free.isEmpty {
                T(tr("el.empty"), ui(14.5, 400, G.ink2), align: .center).padding(22).frame(maxWidth: .infinity)
                    .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
            }
            if !calc.ctxs.isEmpty { EOrderCard(app: app, p: p, calc: calc) }
            // every room of each workspace (an older project may have several in one), a workspace without one once
            ForEach(wsRooms(p)) { s in ERoomCard(app: app, p: p, w: s.w, room: s.room, several: s.several, calc: calc) }
            // rooms typed by size, without a plan
            if !p.elec.free.isEmpty { freeCard }
            HStack(spacing: 8) {
                dashed("plus", tr("el.addKit"), "el.addKit") { app.push(.eGallery(pid: pid)) }
                dashed("room", tr("fo.addRoom"), "el.addRoom") { app.sheet = .eNewRoom(pid: pid) }
            }
            T(tr("el.addFree"), ui(14, 700, G.cobalt2)).padding(.horizontal, 14).padding(.vertical, 10)
                .pressable(0.97) { app.sheet = .eFree(pid: pid, fid: nil) }
                .accessibilityAddTraits(.isButton).accessibilityIdentifier("el.addFree")
            if !p.rooms.isEmpty && view == "list" {
                GBtn(tr("pj.v2d"), kind: .secondary, icon: "room", height: 46, fontSize: 14.5) { app.setProjectView("2d") }.accessibilityIdentifier("pj.v2d")
            }
        }
        .padding(.horizontal, 16).padding(.top, 12)
        // kits chosen before a room was measured go in now that it is
        .onAppear { takeInAll(pid); applyPending(app, pid) }
        .onChange(of: p.rooms) { _, _ in takeInAll(pid); applyPending(app, pid) }
    }

    /// The rooms' marked sockets and switches taken in (once each), so the tab and the next step count them.
    private func takeInAll(_ pid: String) {
        guard let p = Store.shared.get(pid) else { return }
        for r in p.rooms { takeInPoints(pid, r.id) }
    }

    private var freeCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            T(tr("el.freeT"), ui(16, 700))
            ForEach(p.elec.free) { f in EFreeLine(f: f) { app.push(.eView(pid: p.id, rid: "free:" + f.id)) } }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
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

/// A room typed by size in the order's list.
private struct EFreeLine: View {
    let f: ElecFree
    let action: () -> Void
    var body: some View {
        let size = Geo.fmtLen(f.L, .m, en) + " × " + Geo.fmtLen(f.W, .m, en) + U_M + " · "
        let cnt = tr("el.freeCnt", ["s": f.sock + f.power, "k": f.sw, "l": f.light])
        HStack(spacing: 10) {
            MIcon("cube", G.cobalt, 18, 2)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(G.cobalt.opacity(0.1)))
            VStack(alignment: .leading, spacing: 1) {
                T(dn(f.name).trimmingCharacters(in: .whitespaces).isEmpty ? tr(eKindKey(f.kind)) : dn(f.name), ui(14.5, 700), lines: 1)
                T(size + cnt, ui(12.5, 500, G.ink2), lines: 1)
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

/// One workspace of an electrician's order: its room, its devices, what to do next.
private struct ERoomCard: View {
    let app: AppModel
    let p: Project
    let w: Workspace
    let room: Room?
    var several = false
    let calc: ElecCalc
    var body: some View {
        let snap = AppSettings.shared.angleSnap
        let ready = room.map { Geo.ready3D($0, snap) } ?? false
        let ds: [ElecDev] = room.map { r in p.elec.devs.filter { $0.roomId == r.id } } ?? []
        let er = room.map { p.elec.room($0.id) }
        VStack(alignment: .leading, spacing: 10) {
            head(room, ready)
            if let room, !ds.isEmpty { devLine(room, ds) }
            if let er, !er.pend.isEmpty {
                T(tr("el.pending", ["k": er.pend.map { tr("el.kit." + $0.kit) }.joined(separator: ", ")]), ui(12.5, 500, G.amberInk, lh: 1.35))
            }
            if let room {
                if !ready { TodoRow(label: tr("ns.measureT")) { openRoom(app, p.id, room.id) } }
                else { TodoRow(label: tr("el.addKit")) { app.push(.eGallery(pid: p.id, rid: room.id)) } }
            } else {
                TodoRow(label: tr("fo.drawRoom")) { drawTileRoom(app, p.id, w) }
            }
        }
        .padding(12)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
    }

    private func head(_ room: Room?, _ ready: Bool) -> some View {
        let a = room?.dim("A").v, b = room?.dim("B").v, h = room?.dim("H").v
        let sub: String = {
            if ready, let a, let b, room?.isPoly != true {
                return Geo.fmtLen(a, .m, en) + " × " + Geo.fmtLen(b, .m, en) + U_M + (h.map { " · h " + Geo.fmtLen($0, .m, en) } ?? "")
            }
            if ready { return tr("tl.measured") }
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
            if ready {
                T("3D", ui(13, 800, G.cobalt2)).padding(.horizontal, 10).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(G.cobalt.opacity(0.1)))
            }
            MIcon("chev", G.ink3, 16, 2)
        }
        .contentShape(Rectangle())
        .pressable(0.99) {
            if let room { if ready { app.push(.eView(pid: p.id, rid: room.id)) } else { openRoom(app, p.id, room.id) } }
            else { app.push(.space(pid: p.id, wid: w.id)) }
        }
    }

    private func devLine(_ room: Room, _ ds: [ElecDev]) -> some View {
        let ws = calc.warns.filter { $0.roomId == room.id }.count
        let panelHere = calc.routes.panel?.roomId == room.id
        return HStack(spacing: 10) {
            PathIcon(BOLT, G.cobalt, 18, 2)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(G.cobalt.opacity(0.1)))
            VStack(alignment: .leading, spacing: 1) {
                T(devSummary(ds), ui(14, 700), lines: 2)
                if ws > 0 { T(tr("el.warnN", ["n": ws]), ui(12.5, 600, G.amberInk)) }
                else if panelHere { T(tr("el.panelHere"), ui(12.5, 500, G.ink2)) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MIcon("chev", G.ink3, 16, 2)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.glass(0.75)))
        .pressable(0.985) { app.push(.eView(pid: p.id, rid: room.id)) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// The order's panel, how its cable runs and its warnings.
private struct EOrderCard: View {
    let app: AppModel
    let p: Project
    let calc: ElecCalc
    var body: some View {
        let pn = livePanel(p)
        let pr = pn.flatMap { x in p.rooms.first { $0.id == x.roomId } }
        let panelSub: String = {
            guard let pn, let pr else { return tr("el.panelNone") }
            return eRoomName(p, pr) + " · " + tr("tl.wallN", ["w": pn.wall])
        }()
        let nCirc = calc.circuits.filter { $0.amps > 0 }.count
        // the RCDs only in the advanced app
        let rcdOn = calc.count.rcds > 0 && AppSettings.shared.advanced
        let circSub = tr("el.circN", ["n": nCirc]) + (rcdOn ? " · " + tr("el.rcdN", ["n": calc.count.rcds]) : "")
        VStack(spacing: 0) {
            ELine(icon: "box", title: tr("el.panel"), sub: panelSub) { panelTap() }
            Hairline()
            ELine(icon: "layers", title: tr("el.method"), sub: tr("el.m." + p.elec.method)) { app.sheet = .eMethod(pid: p.id) }
            // the circuits (how many breakers) are the advanced app's
            if !calc.circuits.isEmpty && AppSettings.shared.advanced {
                Hairline()
                ELine(icon: "sliders", title: tr("el.circuits"), sub: circSub) {
                    if let c = calc.ctxs.first(where: { !calc.routes.inRoom($0.id).isEmpty }) { app.push(.eView(pid: p.id, rid: c.id)) }
                }
            }
            if !calc.warns.isEmpty {
                Hairline()
                ELine(icon: "alert", title: tr("el.warnN", ["n": calc.warns.count]), sub: nil, warn: true) {
                    if let rid = calc.warns.first(where: { $0.roomId != nil })?.roomId { app.push(.eView(pid: p.id, rid: rid)) }
                }
            }
        }
        .padding(.vertical, 4)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
    }

    private func panelTap() {
        if let pn = livePanel(p) { app.push(.eView(pid: p.id, rid: pn.roomId)); return }
        if let d = defaultPanel(p, AppSettings.shared.angleSnap) {
            updateElec(p.id) { $0.panel = d }
            app.push(.eView(pid: p.id, rid: d.roomId)); app.say("el.panelSet")
        } else { app.say("el.panelNeed") }
    }
}

private struct ELine: View {
    let icon: String
    let title: String
    let sub: String?
    var warn = false
    let action: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            MIcon(icon, warn ? G.amberInk : G.ink2, 20, 2)
            T(title, ui(14.5, 700, warn ? G.amberInk : G.ink), lines: 2).frame(maxWidth: .infinity, alignment: .leading)
            if let sub { T(sub, ui(13, 500, G.ink2), align: .trailing, lines: 2).frame(maxWidth: 190, alignment: .trailing) }
            MIcon("chev", G.ink3, 16, 2)
        }
        .padding(.horizontal, 14).padding(.vertical, 8).frame(minHeight: 52)
        .contentShape(Rectangle())
        .pressable(0.99, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/* ---------------- the next step ---------------- */

/// What to do now with an electrician's order, and the one button that does it.
struct ENextStep: View {
    let app: AppModel
    let p: Project
    private struct Step { let title: String; let sub: String?; let button: String; let go: () -> Void }

    private var step: Step? {
        let s = AppSettings.shared, snap = s.angleSnap
        let pid = p.id
        let rooms: [(Workspace, Room)] = roomsByWorkspace(p)
        let undrawn = p.floors.first { w in !p.rooms.contains { $0.floorId == w.id } }
        let unmeasured = rooms.first { wr in Geo.stepKeys(wr.1, snap).contains { wr.1.dim($0).status != "conf" } }
        let bare = rooms.first { wr in !p.elec.devs.contains { $0.roomId == wr.1.id } && p.elec.room(wr.1.id).pend.isEmpty }
        let made = madeBy(p, "el.e.")
        if p.floors.isEmpty && p.elec.free.isEmpty {
            return Step(title: tr("el.ns.pickT"), sub: tr("el.ns.pickS"), button: tr("ns.needB")) { app.push(.eGallery(pid: pid)) }
        }
        if let undrawn { return Step(title: tr("ns.measureT"), sub: floorName(undrawn), button: tr("fo.drawRoom")) { drawTileRoom(app, pid, undrawn) } }
        if let u = unmeasured {
            let (w, r) = u
            return Step(title: tr("ns.measureT"), sub: tr("ns.measureS", ["r": floorName(w)]), button: tr("ns.measureB")) { openRoom(app, pid, r.id) }
        }
        if let b = bare {
            let (w, r) = b
            return Step(title: tr("el.ns.roomT", ["r": floorName(w)]), sub: tr("el.ns.roomS"), button: tr("ns.needB")) { app.push(.eGallery(pid: pid, rid: r.id)) }
        }
        if livePanel(p) == nil && !p.elec.devs.isEmpty {
            return Step(title: tr("el.ns.panelT"), sub: tr("el.ns.panelS"), button: tr("el.ns.panelB")) {
                guard let cur = Store.shared.get(pid), let d = defaultPanel(cur, snap) else { return }
                updateElec(pid) { $0.panel = d }
                app.push(.eView(pid: pid, rid: d.roomId))
            }
        }
        if !s.advanced { return Step(title: tr("ns.shareT"), sub: tr("el.ns.shareS"), button: tr("ns.shareB")) { app.push(.report(pid: pid, no: nil)) } }
        if !made {
            return Step(title: tr("el.ns.estT"), sub: tr("el.ns.estS"), button: tr("trc.apply")) {
                if let cur = Store.shared.get(pid) { applyElecRows(app, cur) }
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

/// The order page's three numbers in the advanced app: points, cable, the estimate.
struct ENums: View {
    let p: Project
    var body: some View {
        if AppSettings.shared.advanced {
            let lang = AppSettings.shared.lang
            let c = ElecCalcCache.shared.of(p).count
            let est = Money.short(p, Money.totals(p).g, lang == .en, tr("pl.mln"))
            VStack(spacing: 0) {
                Hairline()
                HStack(spacing: 12) {
                    ECell(label: tr("el.points"), value: "\(c.points)", unit: nil)
                    ECell(label: tr("el.cable"), value: Num.fixed(c.cableM, 0, lang), unit: tr("u.m"))
                    ECell(label: tr("pl.est"), value: est.0, unit: est.1)
                }
                .padding(.horizontal, 4).padding(.top, 10)
            }
            .padding(.top, 11)
        }
    }
}

private struct ECell: View {
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

/// Puts the counted cable, devices and labour into the order's estimate in place of the calculator's lines; typed lines
/// stay. Names and units are stored as keys, so they follow the app's and the report's language.
func applyElecRows(_ app: AppModel, _ p: Project) {
    let st = AppSettings.shared
    let r = elecRows(p, st.trade, st.angleSnap) { k, v in k.hasPrefix("tu.") ? "@u." + String(k.dropFirst(3)) : keyName(k, v) }
    Store.shared.update(p.id) { pr in
        if pr.stage == "measure" { pr.stage = "estimate" }
        pr.estimate.materials = pr.estimate.materials.filter { !$0.id.hasPrefix("t-") } + r.mats.map { var x = $0; x.id = "t-" + uid(); return x }
        pr.estimate.labor = pr.estimate.labor.filter { !$0.id.hasPrefix("t-") } + r.labor.map { var x = $0; x.id = "t-" + uid(); return x }
    }
    app.say("trc.done", ["n": r.mats.count + r.labor.count])
}

/// The estimate tab's card (in place of the old calculator's): what the devices and routes take, and the button that puts
/// it in.
struct ElecCard: View {
    let app: AppModel
    let p: Project
    var body: some View {
        let lang = AppSettings.shared.lang
        let c = ElecCalcCache.shared.of(p).count
        let made = madeBy(p, "el.e.")
        VStack(alignment: .leading, spacing: 8) {
            T(tr("el.cardT"), ui(16, 800))
            T(tr("trc.elec", ["n": c.points, "m": Num.fixed(c.cableM, 1, lang)]), num(14.5, 700))
            T(tr("el.cardB"), ui(12.5, 400, G.ink2, lh: 1.4))
            if c.points == 0 { T(tr("el.noDevs"), ui(13, 500, G.amberInk, lh: 1.4)) }
            HStack(spacing: 8) {
                GBtn(tr(made ? "trc.update" : "trc.apply"), enabled: c.points > 0, height: 44, corner: 14, fontSize: 14, lines: 2) { applyElecRows(app, p) }
                    .accessibilityIdentifier("el.apply")
                GBtn(tr("tl.prices"), kind: .secondary, icon: "sliders", height: 44, corner: 14, fontSize: 14, lines: 2) { app.sheet = .ePrices(pid: p.id) }
                    .accessibilityIdentifier("el.prices")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.6))
    }
}

/// What the order takes, line by line (the advanced app).
struct ECountCard: View {
    let c: ECount
    var body: some View {
        let lang = AppSettings.shared.lang
        let d1 = { (v: Double) in Num.fixed(v, 1, lang) }
        let brk = c.breakers.keys.sorted().map { "\($0) A × \(c.breakers[$0] ?? 0)" }.joined(separator: ", ")
        VStack(alignment: .leading, spacing: 6) {
            T(tr("el.countT"), ui(15, 800))
            ForEach(Array(c.cables.enumerated()), id: \.offset) { _, n in
                let nm = lang == .en ? cableName(n.type) : cableName(n.type).replacingOccurrences(of: ".", with: ",")
                // a short run by the metre, a long one in whole coils (as the estimate buys it)
                let byM = n.coils == 0 || n.withSpare < Double(COIL_FROM)
                let v = byM ? tr("el.cabVm", ["m": d1(n.m), "s": d1(n.withSpare)]) : tr("el.cabV", ["m": d1(n.m), "s": d1(n.withSpare), "n": n.coils])
                EKv(k: tr("el.cab", ["c": nm]), v: v)
            }
            if !c.breakers.isEmpty {
                Hairline()
                EKv(k: tr("el.brk"), v: brk)
                if c.rcds > 0 { EKv(k: tr("el.rcd"), v: "× \(c.rcds)") }
                EKv(k: tr("el.panelSize"), v: tr("el.modV", ["n": c.panelModules, "u": c.modules]))
            }
            Hairline()
            EKv(k: tr("el.boxes"), v: "\(c.boxes)")
            EKv(k: tr("el.jboxes"), v: "\(c.jboxes)")
            if c.chaseM > 0 { EKv(k: tr("el.m.chase"), v: d1(c.chaseM) + U_M) }
            if c.gofraM > 0 { EKv(k: tr("el.m.gofra"), v: d1(c.gofraM) + U_M) }
            if c.channelM > 0 { EKv(k: tr("el.m.channel"), v: d1(c.channelM) + U_M) }
            EKv(k: tr("el.points"), v: "\(c.points)")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.6))
    }
}

struct EKv: View {
    let k: String
    let v: String
    var body: some View {
        HStack {
            T(k, ui(13, 500, G.ink2)).frame(maxWidth: .infinity, alignment: .leading)
            T(v, num(13.5, 700), align: .trailing)
        }
    }
}

/// A new device of type t in room c: on wall (or the main one) at its usual height, clear of what is there; a light in
/// the middle.
func newDev(_ c: ECtx, _ p: Project, _ t: String, _ wall: String?) -> ElecDev? {
    let ty = devType(t)
    if ty.ceil {
        let m = centreOf(c)
        return ElecDev(id: uid(), t: t, roomId: c.id, wall: nil, cx: tInt(m.x) + 150, cy: tInt(m.y))
    }
    let have = p.elec.devs.filter { $0.roomId == c.id }
    let h = usualH(t, c.H, c.kind)
    var ws: [TWall] = []
    if let w = c.wall(wall) { ws.append(w) }
    for w in c.g.walls where !ws.contains(where: { $0.id == w.id }) { ws.append(w) }
    for w in ws {
        if t == "led" {
            let l = tInt(eClamp(w.len - 400, 300, 2000))
            return ElecDev(id: uid(), t: t, roomId: c.id, wall: w.id, off: tInt(w.len / 2), h: h, len: l)
        }
        guard let x = spotOn(w, w.len / 2, h, ty.dw, ty.dh, blocksOn(c, w.id, t, have, livePanel(p))) else { continue }
        return ElecDev(id: uid(), t: t, roomId: c.id, wall: w.id, off: x, h: h)
    }
    return nil
}

/// A kit pick for a room not measured yet.
func pickOf(_ k: ElecKit, _ o: KitOpts) -> KitPick { KitPick(kit: k.id, light: o.light, led: o.led, ac: o.ac, low: o.low) }
