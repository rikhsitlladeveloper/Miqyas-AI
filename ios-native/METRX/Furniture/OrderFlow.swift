import SwiftUI

/*
 * The easier path for furniture makers (decided 20 Oct 2026, mockup design/furniture/orders-flow-mockup.html; Android
 * ui/furniture/OrderFlow.kt): a short new-order form that names the order itself and goes straight into the room; the
 * order's rooms with their furniture; the install date worked out from the approval and the Narx tab's days, on the
 * order and its card.
 */

private var en: Bool { AppSettings.shared.lang == .en }
private var gregorian: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = .current; return c }

/* ---------------- dates ---------------- */

/// "11-noy": the day and the month's short name in the app language.
func fmtDay(_ d: Date) -> String {
    let c = gregorian.dateComponents([.day, .month], from: d)
    let months = tr("fo.months").split(separator: ",").map(String.init)
    let m = c.month ?? 1
    return "\(c.day ?? 1)-" + (m - 1 < months.count ? months[m - 1] : "\(m)")
}

/// Whole days from today to d (negative when d has passed).
func daysFromToday(_ d: Date) -> Int { gregorian.dateComponents([.day], from: gregorian.startOfDay(for: Date()), to: gregorian.startOfDay(for: d)).day ?? 0 }

/// Epoch milliseconds of a day's midnight, here.
func msOf(_ d: Date) -> Ms { Ms(gregorian.startOfDay(for: d).timeIntervalSince1970 * 1000) }

/// The order's install date as a chip: grey, amber from 3 days before, red when late (until it is installed).
struct InstallChip: View {
    let p: Project
    var body: some View {
        if !AppSettings.shared.advanced {
            EmptyView()   // no install dates in the simple app
        } else if let d = installDate(p) {
            let left = daysFromToday(d)
            let open = fStage(p) < 5
            let late = open && left < 0, soon = open && !late && left <= 3
            let tail = late ? " · " + tr("fo.lateV", ["n": -left]) : soon ? " · " + (left == 0 ? tr("fo.todayV") : tr("fo.soonV", ["n": left])) : ""
            let (bg, fg): (Color, Color) = late ? (G.errWash, G.err) : soon ? (G.amberWash, G.amberInk) : (G.ink.opacity(0.06), G.ink2)
            HStack(spacing: 5) {
                MIcon("calendar", fg, 14, 2.2)
                T(tr("fo.installV", ["d": fmtDay(d)]) + tail, ui(12.5, 700, fg), lines: 1)
            }
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(bg))
        } else {
            T(tr("fo.noDate"), ui(12.5, 600, G.ink3), lines: 1)
        }
    }
}

/// The green round call button of an order (nothing when it has no phone).
struct CallButton: View {
    let p: Project
    @Environment(\.openURL) private var openURL
    var body: some View {
        if !p.phone.isEmpty {
            MIcon("phone", Theme.shared.dark ? G.green : Color(argb: 0xFF15803D), 20, 2.2)
                .frame(width: 46, height: 46)
                .background(Circle().fill(G.greenWash))
                .pressable(0.95, label: tr("pl.call")) { if let u = URL(string: "tel:+998" + Phone.digits(p.phone)) { openURL(u) } }
        }
    }
}

/// Under the order's name: the customer, or (when the name already says who) the address or phone.
func orderSub(_ p: Project, _ sep: String) -> String {
    let who = dn(p.customer), addr = dn(p.address)
    if !who.isEmpty && dn(p.name).hasSuffix(who) { return !addr.isEmpty ? addr : p.phone.isEmpty ? "" : Phone.format(p.phone) }
    return [who, addr].filter { !$0.isEmpty }.joined(separator: sep)
}

/* ---------------- rooms made behind the scenes ---------------- */

/// The room kinds a furniture maker adds (string keys fr.*); the first two decide kitchen or wardrobe.
let F_ROOMS = ["kitchen", "bedroom", "living", "kids", "hall", "bath", "other"]

/// What furniture a room is for: the kitchen room gets a kitchen, the others a wardrobe.
func roomKind(_ w: Workspace?) -> String { w?.type == "kitchen" ? "kitchen" : "wardrobe" }

/// A workspace with a rectangular room in it, named name; returns the room's id.
@discardableResult func addFurnRoom(_ pid: String, _ type: String, _ name: String) -> String {
    let now = nowMs()
    let w = Workspace(id: uid(), name: name, type: type == "kitchen" ? "kitchen" : "room", created: now)
    let r = Room(id: uid(), floorId: w.id, name: name, created: now)
    Store.shared.update(pid) { $0.floors.append(w); $0.rooms.append(r) }
    return r.id
}

/// Opens a room in the editor with wall A waiting for the laser or typing.
func openRoom(_ app: AppModel, _ pid: String, _ rid: String) { app.push(.editor(pid: pid, rid: rid, mode: "plan")); RoomOps.shared.focus(rid, "A") }

/// Draws the first room of a workspace that has none yet.
func drawRoomIn(_ app: AppModel, _ pid: String, _ w: Workspace) {
    let r = Room(id: uid(), floorId: w.id, name: floorName(w), created: nowMs())
    Store.shared.update(pid) { $0.rooms.append(r) }
    openRoom(app, pid, r.id)
}

/// The customer price of each piece, by furniture id.
func pieceAmounts(_ p: Project) -> [String: Decimal] {
    let s = AppSettings.shared
    if !s.advanced { return [:] }   // no prices in the simple app
    let priced = priceOf(p.furniture.filter { !$0.modules.isEmpty }, p.fprice, s.workshop, s.mats, s.hws)
    return Dictionary(priced.lines.map { ($0.key, $0.amount) }, uniquingKeysWith: { a, _ in a })
}

/// "2,4 mln" of an amount in the order's money.
func shortStr(_ p: Project, _ v: Decimal) -> String { let (a, u) = Money.short(p, v, en, tr("pl.mln")); return a + (u.map { " " + $0 } ?? "") }

/* ---------------- New order ---------------- */

private enum OF: Hashable { case who, phone, addr }

struct NewOrderScreen: View {
    let app: AppModel
    @State private var who = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var tried = false
    @State private var loaded = false
    @FocusState private var focus: OF?

    var body: some View {
        let wt = who.trimmingCharacters(in: .whitespaces)
        let whoErr = wt.isEmpty ? tr("np.customerReq") : wt.count < 2 ? tr("np.customerShort") : nil
        let phErr = Phone.errorKey(phone, required: false).map { tr($0) }
        let ok = whoErr == nil && phErr == nil
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    GlassIconButton("x", tr("common.close")) { app.pop() }.padding(.leading, 6)
                    BarTitle(title: tr("fz.whoT"), eyebrow: tr("fo.new"))
                }
                .padding(.trailing, 12).frame(minHeight: 64)
                .background(G.sheet(0.55).ignoresSafeArea(edges: .top))
                .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        GField(label: tr("np.customerName"), value: $who, placeholder: tr("smp.customer"), error: whoErr, showError: tried, focus: $focus, me: .who,
                               onSubmit: { focus = .phone }, caps: .words, id: "no.who")
                        GField(label: tr("np.customerPhone"), value: $phone, placeholder: "90 123 45 67", optional: true, phone: true, error: phErr,
                               showError: tried || phone.count >= 9, focus: $focus, me: .phone)
                        GField(label: tr("np.address"), value: $address, placeholder: tr("smp.address"), optional: true, focus: $focus, me: .addr, submit: .done,
                               onSubmit: { create(ok) })
                        T(tr("fz.nextNote"), ui(13.5, 400, G.ink2, lh: 1.4))
                    }
                    .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 120)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            FloatingFooter {
                GBtn(tr("fo.create"), enabled: !tried || ok) { create(ok) }.accessibilityIdentifier("no.create")
            }
        }
        .onAppear {
            guard !loaded else { return }
            loaded = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focus = .who }
        }
    }

    private func create(_ ok: Bool) {
        tried = true
        guard ok, app.once() else { return }
        focus = nil
        // named after the customer; "Oshxona — Akmal" once they say what they need (renameOrder)
        let name = who.trimmingCharacters(in: .whitespaces)
        var p = newProject(name, name, Phone.digits(phone), address.trimmingCharacters(in: .whitespaces), nil, AppSettings.shared.currency, AppSettings.shared.reportLang.code)
        p.industry = "furniture"; p.autoName = true
        Store.shared.add(p)
        app.replaceTop(.project(id: p.id, tab: "rooms"))
        app.push(.fGallery(pid: p.id, fromNew: true))
        app.say("np.created", ["n": name])
    }
}

/* ---------------- the order's rooms with their furniture ---------------- */

struct FRoomsTab: View {
    let app: AppModel
    let p: Project
    var body: some View {
        let snap = AppSettings.shared.angleSnap
        let amounts = pieceAmounts(p)
        VStack(spacing: 10) {
            FreeCard(app: app, p: p)
            if p.floors.isEmpty && !p.furniture.contains(where: { $0.roomId == nil }) {
                T(tr("fz.empty"), ui(14.5, 400, G.ink2), align: .center).padding(22).frame(maxWidth: .infinity)
                    .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
            }
            ForEach(p.floors) { w in roomCard(w, snap, amounts) }
            if !p.rooms.isEmpty {
                HStack(spacing: 8) {
                    GBtn(tr("pj.v2d"), kind: .secondary, icon: "room", height: 48, fontSize: 15) { app.setProjectView("2d") }.accessibilityIdentifier("pj.v2d")
                    GBtn(tr("pj.v3d"), kind: .secondary, icon: "cube", height: 48, fontSize: 15) { app.setProjectView("3d") }.accessibilityIdentifier("pj.v3d")
                }
            }
            HStack(spacing: 8) { MIcon("plus", G.cobalt2, 22, 2.2); T(tr("fz.addMore"), ui(16, 700, G.cobalt2)) }
                .frame(maxWidth: .infinity).frame(height: 60)
                .dashedGlass(22)
                .pressable(0.98) { app.push(.fGallery(pid: p.id)) }
                .accessibilityIdentifier("fz.addMore")
        }
        .padding(.horizontal, 16).padding(.top, 12)
    }

    private func roomCard(_ w: Workspace, _ snap: Bool, _ amounts: [String: Decimal]) -> some View {
        let room = p.rooms.first { $0.floorId == w.id }
        let drawn = room.map { measuredRoom($0, snap) } ?? false
        let furn = p.furniture.filter { $0.ws == w.id || (room != nil && $0.roomId == room?.id) }
        let kind = roomKind(w)
        let a = room?.dim("A").v, b = room?.dim("B").v, h = room?.dim("H").v
        let sub: String = {
            if drawn, let a, let b { return Geo.fmtLen(a, .m, en) + " × " + Geo.fmtLen(b, .m, en) + " m" + (h.map { " · h " + Geo.fmtLen($0, .m, en) } ?? "") }
            return tr(room != nil ? "fo.notMeasured" : "fo.notDrawn")
        }()
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Group {
                    if let room { RoomThumb(r: room).padding(4) } else { MIcon(kind == "kitchen" ? "kitchen" : "room", G.cobalt, 24, 2) }
                }
                .frame(width: 64, height: 52)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(Theme.shared.dark ? 0.1 : 0.8)))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    T(floorName(w), ui(16, 700), lines: 1)
                    T(sub, ui(12.5, 400, G.ink2), lines: 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                MIcon("chev", G.ink3, 16, 2)
            }
            .contentShape(Rectangle())
            .pressable(0.99) { if let room { openRoom(app, p.id, room.id) } else { app.push(.space(pid: p.id, wid: w.id)) } }
            ForEach(furn) { f in pieceRow(f, amounts[f.id]) }
            todo(w, room, drawn, furn.isEmpty, kind)
            let n = w.items.count
            if n > 0 || room != nil {
                T(tr("fo.photos") + (n > 0 ? " · \(n)" : ""), ui(13, 600, G.cobalt2)).padding(.horizontal, 4).padding(.vertical, 6)
                    .pressable(0.97) { app.push(.space(pid: p.id, wid: w.id)) }
            }
        }
        .padding(12)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
    }

    private func pieceRow(_ f: Furniture, _ amount: Decimal?) -> some View {
        let ward = f.kind == "wardrobe"
        let sub: String
        if ward && (isItemPiece(f) || boxes(f).count > 1) { sub = freeSub(f, en) }
        else if ward { sub = wardOfF(f).map { Geo.fmtLen($0.w, .m, en) + " × " + Geo.fmtLen(valsOf(f, AppSettings.shared.workshop)["h"] ?? $0.h, .m, en) + " m" } ?? "" }
        else { sub = tr("kt.l" + f.layout) + " · " + runMetres(f, en) + " " + tr("kt.pm") }
        return HStack(spacing: 10) {
            MIcon(ward ? "board" : "kitchen", G.ink3, 18, 2)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    T(dn(f.name), ui(14.5, 700), lines: 1)
                    if f.keep {
                        T(tr("fz.big"), ui(11, 700, G.err), lines: 1).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(G.errWash))
                    }
                }
                if !sub.isEmpty { T(sub, num(12.5, 500, G.ink2), lines: 1) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let amount, amount > 0 { T(shortStr(p, amount), num(14, 700)) }
            MIcon("chev", G.ink3, 16, 2)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.glass(0.75)))
        .pressable(0.985) { KitOps.shared.sel = nil; app.push(designer(p.id, f)) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private func todo(_ w: Workspace, _ room: Room?, _ drawn: Bool, _ empty: Bool, _ kind: String) -> some View {
        if let room {
            if !drawn { TodoRow(label: tr("ns.measureT")) { openRoom(app, p.id, room.id) } }
            else if empty {
                if let loose = p.furniture.first(where: { $0.roomId == nil && $0.kind == kind }) {
                    TodoRow(label: tr("fz.placeN", ["n": dn(loose.name)])) { app.push(.fPlace(pid: p.id, fid: loose.id, rid: room.id)) }
                } else {
                    TodoRow(label: tr(kind == "kitchen" ? "fo.addK" : "fo.addW")) { app.push(.fGallery(pid: p.id, rid: room.id)) }
                }
            }
        } else {
            TodoRow(label: tr("fo.drawRoom")) { drawRoomIn(app, p.id, w) }
        }
    }
}

struct TodoRow: View {
    let label: String
    let action: () -> Void
    var body: some View {
        HStack(spacing: 8) { MIcon("plus", G.cobalt2, 18, 2.2); T(label, ui(14.5, 700, G.cobalt2)).frame(maxWidth: .infinity, alignment: .leading) }
            .padding(.horizontal, 12).frame(minHeight: 48)
            .dashedGlass(14)
            .pressable(0.98, action)
            .accessibilityAddTraits(.isButton)
    }
}

/* ---------------- sheets: a new room, the install date ---------------- */

struct OrderFlowSheet: View {
    let app: AppModel
    let sheet: Sheet
    static func handles(_ s: Sheet) -> Bool {
        switch s { case .fNewRoom, .fInstall, .fPickRoom: return true; default: return false }
    }
    var body: some View {
        switch sheet {
        case .fNewRoom(let pid, let kind, let fid): NewRoomSheet(app: app, pid: pid, kind: kind, fid: fid)
        case .fInstall(let pid): InstallSheet(app: app, pid: pid)
        case .fPickRoom(let pid, let fid): PickRoomSheet(app: app, pid: pid, fid: fid)
        default: EmptyView()
        }
    }
}

private enum RF: Hashable { case name }

private struct NewRoomSheet: View {
    let app: AppModel
    let pid: String
    let kind: String?
    let fid: String?
    @State private var type: String
    @State private var name: String
    @FocusState private var focus: RF?
    init(app: AppModel, pid: String, kind: String?, fid: String?) {
        self.app = app; self.pid = pid; self.kind = kind; self.fid = fid
        let p = Store.shared.get(pid)
        let t: String
        switch kind {
        case "kitchen": t = "kitchen"
        case "wardrobe": t = "bedroom"
        case "other": t = "living"
        default: t = (p?.floors.contains { $0.type == "kitchen" } ?? false) ? "bedroom" : "kitchen"
        }
        _type = State(initialValue: t)
        _name = State(initialValue: NewRoomSheet.nameFor(t, p))
    }
    static func nameFor(_ t: String, _ p: Project?) -> String {
        let base = tr("fr." + t)
        let n = p?.floors.filter { $0.name.hasPrefix(base) }.count ?? 0
        return n > 0 ? "\(base) \(n + 1)" : base
    }
    var body: some View {
        let p = Store.shared.get(pid)
        GlassSheet(tr("fo.addRoom"), onClose: { app.sheet = nil }) {
            T(tr("fr.type"), ui(15, 700))
            FlowLayout(spacing: 8) {
                ForEach(F_ROOMS, id: \.self) { t in FChip(label: tr("fr." + t), on: t == type) { type = t; name = NewRoomSheet.nameFor(t, p) } }
            }
            GField(label: tr("fr.name"), value: $name, placeholder: tr("fr." + type), focus: $focus, me: .name, submit: .done, onSubmit: create)
        } footer: {
            GBtn(tr("fo.drawRoom"), enabled: !name.trimmingCharacters(in: .whitespaces).isEmpty, create).accessibilityIdentifier("fr.create")
        }
    }
    private func create() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, app.once() else { return }
        let rid = addFurnRoom(pid, type, n)
        if let fid { app.placeAfter = (rid, fid) }
        app.sheet = nil
        openRoom(app, pid, rid)
    }
}

private struct InstallSheet: View {
    let app: AppModel
    let pid: String
    @State private var day: Date
    init(app: AppModel, pid: String) {
        self.app = app; self.pid = pid
        _day = State(initialValue: Store.shared.get(pid).flatMap { installDate($0) } ?? Date())
    }
    var body: some View {
        if let p = Store.shared.get(pid) {
            let auto: Date? = { var q = p; q.install = 0; return installDate(q) }()
            let same = { (a: Date?, b: Date) in a.map { gregorian.isDate($0, inSameDayAs: b) } ?? false }
            GlassSheet(tr("fo.dateT"), onClose: { app.sheet = nil }) {
                T(tr("fo.dateB", ["m": p.fprice.days, "i": p.fprice.inst]), ui(13.5, 400, G.ink2, lh: 1.45))
                HStack(spacing: 10) {
                    GBtn("−", kind: .secondary, height: 56, fontSize: 22, fill: false) { day = gregorian.date(byAdding: .day, value: -1, to: day)! }.frame(width: 56)
                    VStack(spacing: 0) {
                        T(fmtDay(day), num(26, 800))
                        T("\(gregorian.component(.year, from: day))", ui(13, 500, G.ink2))
                    }
                    .frame(maxWidth: .infinity)
                    GBtn("+", kind: .secondary, height: 56, fontSize: 22, fill: false) { day = gregorian.date(byAdding: .day, value: 1, to: day)! }.frame(width: 56)
                }
                if let auto, !same(auto, day) {
                    T(tr("fo.dateAuto") + " (" + fmtDay(auto) + ")", ui(14, 700, G.cobalt2)).padding(.horizontal, 4).padding(.vertical, 8)
                        .pressable(0.97) { day = auto }
                }
            } footer: {
                GBtn(tr("common.save")) {
                    let v: Ms = same(auto, day) ? 0 : msOf(day)
                    Store.shared.update(pid) { $0.install = v }
                    app.sheet = nil; app.say("fo.dateSaved")
                }
                .accessibilityIdentifier("fo.dateSave")
            }
        }
    }
}

/* ---------------- the next step, under the order's header on every tab ---------------- */

/// What to do now with a furniture order, and the one button that does it (decided 20 Oct 2026). Nothing once paid.
struct NextStep: View {
    let app: AppModel
    let p: Project
    private struct Step { let title: String; let sub: String?; let button: String; let go: () -> Void }

    private var step: Step? {
        let s = AppSettings.shared, snap = s.angleSnap
        let k = fStage(p)
        let m = orderMoney(p)
        let rooms: [(Workspace, Room)] = p.floors.compactMap { w in p.rooms.first { $0.floorId == w.id }.map { (w, $0) } }
        let undrawn = p.floors.first { w in !p.rooms.contains { $0.floorId == w.id } }
        let unmeasured = rooms.first { !measuredRoom($0.1, snap) }
        let bare = rooms.first { wr in !p.furniture.contains { $0.ws == wr.0.id || $0.roomId == wr.1.id } }
        // a measured room with nothing in it and a room-less piece of its kind: the piece goes in
        let loose = bare.flatMap { wr in measuredRoom(wr.1, snap) ? p.furniture.first { $0.roomId == nil && $0.kind == roomKind(wr.0) } : nil }
        // what they wanted that has neither a room nor a piece yet
        let pend = p.want?.first { k in !p.furniture.contains { kindKey($0) == k } && (k == "other" || !p.floors.contains { roomKind($0) == k }) }
        let installed = installDate(p).map { tr("fo.installV", ["d": fmtDay($0)]) }
        let pid = p.id
        // the simple app has no stages: the steps of making the furniture, then sending the design
        let share = Step(title: tr("ns.shareT"), sub: tr("ns.shareS"), button: tr("ns.shareB")) { app.push(.report(pid: pid, no: nil)) }
        if !s.advanced && k >= 2 { return share }
        if k >= 6 { return nil }
        if k == 5 {
            guard let left = m.left, left > 0 else { return nil }
            return Step(title: tr("ns.payT"), sub: tr("fo.leftV", ["v": shortStr(p, left)]), button: tr("fo.addPay")) { app.sheet = .fPay(pid: pid) }
        }
        if k == 4 {
            return Step(title: tr("ns.installT"), sub: installed, button: tr("ns.installB")) {
                // installed today: the date becomes today's, so the card and the list say when it really happened
                guard app.once() else { return }
                let q = Store.shared.update(pid) { $0 = nextStage($0); $0.install = msOf(Date()) }
                if q?.stage == "paid" { app.say("fs.paid") }
            }
        }
        if k == 3 { return Step(title: tr("ns.makeT"), sub: installed, button: tr("ns.makeB")) { if app.once() { Store.shared.update(pid) { $0 = nextStage($0) } } } }
        if k == 2 {
            let sub = p.quotes.last.map { q in tr("ns.approveS", ["n": q.no, "v": shortStr(p, Decimal(string: q.total) ?? 0)]) }
            return Step(title: tr("ns.approveT"), sub: sub, button: tr("fo.approve")) { app.sheet = .fApprove(pid: pid) }
        }
        if p.want == nil && p.floors.isEmpty && p.furniture.isEmpty {
            return Step(title: tr("ns.needT"), sub: tr("ns.needS"), button: tr("ns.needB")) { app.push(.fGallery(pid: pid)) }
        }
        if let undrawn { return Step(title: tr("ns.measureT"), sub: floorName(undrawn), button: tr("fo.drawRoom")) { drawRoomIn(app, pid, undrawn) } }
        if let u = unmeasured {
            let (w, r) = u
            return Step(title: tr("ns.measureT"), sub: tr("ns.measureS", ["r": floorName(w)]), button: tr("ns.measureB")) { openRoom(app, pid, r.id) }
        }
        if let loose, let b = bare {
            let (w, r) = b
            let vars = ["n": dn(loose.name), "r": floorName(w)]
            return Step(title: tr("ns.placeT", vars), sub: tr("ns.placeS", vars), button: tr("fz.toRoom")) { app.push(.fPlace(pid: pid, fid: loose.id, rid: r.id)) }
        }
        if let b = bare {
            let (w, r) = b
            let kind = roomKind(w)
            return Step(title: tr(kind == "kitchen" ? "ns.designK" : "ns.designW"), sub: tr("ns.designS", ["r": floorName(w)]), button: tr(kind == "kitchen" ? "fo.addK" : "fo.addW")) {
                app.push(.fGallery(pid: pid, rid: r.id))
            }
        }
        if let pend {
            return Step(title: tr(pend == "kitchen" ? "ns.designK" : pend == "other" ? "ns.designO" : "ns.designW"), sub: tr("ns.pendS"), button: tr("ns.pendB")) {
                app.push(.fGallery(pid: pid))
            }
        }
        if p.floors.isEmpty && p.furniture.isEmpty {
            return Step(title: tr("ns.needT"), sub: tr("ns.needS"), button: tr("ns.needB")) { app.push(.fGallery(pid: pid)) }
        }
        if !s.advanced { return share }
        let price = priceOf(p.furniture.filter { !$0.modules.isEmpty }, p.fprice, s.workshop, s.mats, s.hws).price
        return Step(title: tr("ns.quoteT"), sub: price > 0 ? tr("ns.quoteS", ["v": shortStr(p, price)]) : nil, button: tr("ns.quoteB")) { app.sheet = .issue(pid: pid) }
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
