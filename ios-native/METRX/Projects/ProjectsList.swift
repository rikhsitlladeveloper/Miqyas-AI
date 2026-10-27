import SwiftUI
import CoreLocation

/// Whether the app speaks of orders (a furniture maker's or a tradesman's) rather than a builder's projects.
func orderWords() -> Bool {
    guard let i = AppSettings.shared.industry else { return false }
    return i != "build"
}

/// Projects: search with a round +, three chips, compact rows (prototype glass PAGES.projects).
struct ProjectsList: View {
    let app: AppModel
    @State private var q = ""

    /// A paid furniture order counts as done in the chips.
    private func stageOf(_ p: Project) -> String { p.isFurniture && p.stage == "paid" ? "done" : p.stage }

    /// This industry's own projects: a furniture maker's orders, a tiler's, an electrician's, or the builders' and the
    /// other trades'.
    private func mine(_ p: Project, _ furniture: Bool, _ tiler: Bool, _ elec: Bool) -> Bool {
        if furniture { return p.isFurniture }
        if tiler { return p.isTiler }
        if elec { return p.isElec }
        if AppSettings.shared.plumb { return p.isPlumb }
        if AppSettings.shared.win { return p.isWin }
        return !p.isFurniture && !p.isTiler && !p.isElec && !p.isPlumb && !p.isWin
    }

    /// The list in its order: furniture orders by install date (advanced), the simple apps' newest first, as on Home.
    private func listOrder(_ list: [Project], _ furniture: Bool, _ tiler: Bool, _ staged: Bool, _ seg: String) -> [Project] {
        let simple = furniture || tiler || AppSettings.shared.elec || AppSettings.shared.plumb || AppSettings.shared.win
        if !simple || seg == "other" { return list }
        if staged && furniture { return sortOrders(list) }
        return list.sorted { $0.created > $1.created }
    }

    var body: some View {
        let furniture = AppSettings.shared.furniture
        let tiler = AppSettings.shared.tiler
        let elec = AppSettings.shared.elec
        let plumb = AppSettings.shared.plumb || AppSettings.shared.win
        let all = Store.shared.projects
        // each industry sees its own projects (furniture orders, tilers' orders, the rest); the others stay one chip away
        // (furniture plan section 3)
        let ps = all.filter { mine($0, furniture, tiler, elec) }
        let others = all.filter { !mine($0, furniture, tiler, elec) }
        // the simple furniture and tiler apps have no stages: no "in work / finished", just all of them (and the other industry's)
        let staged = !(furniture || tiler || elec || plumb) || AppSettings.shared.advanced
        // the filter lives with the app, so opening or deleting an order does not reset it
        let seg0 = app.ordersSeg
        let seg: String = seg0 == "other" && others.isEmpty ? (staged ? "active" : "all") : (!staged && seg0 != "other" ? "all" : seg0)
        let stages: [(String, String)] = staged ? [("active", "pl.active"), ("done", "pl.doneSeg")] : []
        let chips: [(String, String)] = stages + [("all", "pl.allSeg")] + (others.isEmpty ? [] : [("other", "fo.other")])
        VStack(alignment: .leading, spacing: 0) {
            GlassHeader { app.openLaser() }
            PageTitle(text: tr(furniture || tiler || elec || plumb ? "fo.tab" : "tab.projects")).padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 4)
            if all.isEmpty {
                ProjectsEmpty(app: app)
            } else {
                // the sample order is never counted (UX upgrades section 11)
                let real = ps
                let n = ["active": real.filter { stageOf($0) != "done" }.count, "done": real.filter { stageOf($0) == "done" }.count, "all": real.count, "other": others.count]
                let needle = q.trimmingCharacters(in: .whitespaces).lowercased()
                let list = (seg == "other" ? others : ps).filter { p in
                    let inSeg = seg == "all" || seg == "other" || (seg == "done" ? stageOf(p) == "done" : stageOf(p) != "done")
                    return inSeg && (needle.isEmpty || [dn(p.name), dn(p.customer), dn(p.address), p.phone].joined(separator: " ").lowercased().contains(needle))
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            SearchBox(value: $q, placeholder: tr("gl.search"))
                            MIcon("plus", .white, 24, 2.4).frame(width: 52, height: 52)
                                .background(Circle().fill(G.cobalt)).topHighlight(Circle(), 0.4)
                                .boxShadow(G.cobalt.opacity(0.38), blur: 22, y: 10)
                                .pressable(0.95, label: tr(orderWords() ? "fo.new" : "hm.t.new")) { app.push(.newProject(editId: nil)) }
                                .accessibilityIdentifier("projects.new")
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(chips, id: \.0) { k, l in
                                    let on = seg == k
                                    T("\(tr(l)) · \(n[k] ?? 0)", ui(14, on ? 700 : 600, on ? G.solid : G.slate))
                                        .padding(.horizontal, 16).padding(.vertical, 10).frame(minHeight: 40)
                                        .background(Capsule().fill(on ? G.ink : G.glass(0.45)))
                                        .overlay(Capsule().strokeBorder(on ? G.ink : G.rim, lineWidth: 1))
                                        .pressable(0.97) { app.ordersSeg = k }
                                        .accessibilityAddTraits(on ? .isSelected : [])
                                }
                            }
                        }
                        VStack(spacing: 10) {
                            // the simple app has no install dates: the newest first, as on Home
                            ForEach(listOrder(list, furniture, tiler, staged, seg)) { p in
                                if p.isFurniture { OrderRow(p: p) { app.push(.project(id: p.id, tab: "rooms")) } }
                                else if p.isTiler && !staged { TOrderRow(p: p) { app.push(.project(id: p.id, tab: "rooms")) } }
                                else if p.isElec && !staged { EOrderRow(p: p) { app.push(.project(id: p.id, tab: "rooms")) } }
                                else if p.isPlumb && !staged { POrderRow(p: p) { app.push(.project(id: p.id, tab: "rooms")) } }
                                else if p.isWin && !staged { WOrderRow(p: p) { app.push(.project(id: p.id, tab: "rooms")) } }
                                else { ProjectRow(p: p) { app.push(.project(id: p.id, tab: "rooms")) } }
                            }
                            if list.isEmpty {
                                let ow = orderWords()
                                let emptyKey = needle.isEmpty ? (ow ? "fo.none" : "pl.none") : (ow ? "fo.noMatch" : "pl.noMatch")
                                T(tr(emptyKey), ui(14.5, 400, G.ink2), align: .center).frame(maxWidth: .infinity).padding(.vertical, 24)
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 24 + NAV_SPACE)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }
}

/// Projects with no project yet: one card that invites the first one (prototype plEmpty).
struct ProjectsEmpty: View {
    let app: AppModel
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    MIcon("folder", G.cobalt, 40, 1.8).frame(width: 88, height: 88)
                        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(G.cobalt.opacity(0.12)))
                    MIcon("plus", .white, 16, 2.4).frame(width: 28, height: 28).background(Circle().fill(G.cobalt))
                        .padding(3).background(Circle().fill(G.solid.opacity(0.9))).offset(x: 9, y: -9)
                }
                .padding(.bottom, 8)
                // a furniture maker's or a tradesman's words are orders
                let pre = orderWords() ? "fo.e." : "pl.e."
                T(tr(pre + "t"), ui(21, 800, G.ink, lh: 1.2, ls: -0.01), align: .center)
                T(tr(pre + "b"), ui(15, 400, G.ink2, lh: 1.5), align: .center).frame(maxWidth: 300).padding(.bottom, 10)
                GlassButton(tr(pre + "new"), icon: "plus") { app.push(.newProject(editId: nil)) }.accessibilityIdentifier("projects.first")
            }
            .padding(.horizontal, 22).padding(.top, 34).padding(.bottom, 22)
            .frame(maxWidth: .infinity)
            .glassCard(RoundedRectangle(cornerRadius: 26, style: .continuous), fill: G.glass(0.55))
            T(tr(orderWords() ? "fo.e.foot" : "pl.e.foot"), ui(13.5, 400, G.ink3), align: .center).frame(maxWidth: .infinity).padding(.top, 8)
        }
        .padding(.horizontal, 20).padding(.top, 14)
        .contentMargins(.bottom, 24 + NAV_SPACE, for: .scrollContent)
    }
}

private let EMPTY_THUMB = "M5 6h22v12h8v16H5z M5 22h14 M19 22v12"

/// One project row: a small plan, the name and stage, the customer and area, the measuring progress.
private struct ProjectRow: View {
    let p: Project
    let action: () -> Void
    var body: some View {
        let st = stats(p)
        let (bg, fg): (Color, Color) = p.rooms.isEmpty ? (G.ink.opacity(0.07), G.slate)
            : p.stage == "done" ? (Color(argb: 0x2416A34A), Theme.shared.dark ? G.green : Color(argb: 0xFF15803D))
            : p.stage == "measure" ? (Color(argb: 0x24EA8C00), Theme.shared.dark ? G.amberInk : Color(argb: 0xFF9A5800))
            : (G.cobalt.opacity(0.12), G.cobalt2)
        let label = p.rooms.isEmpty ? tr("gl.new") : tr("stage." + p.stage)
        let pct = st.need > 0 ? Double(st.conf) / Double(st.need) : 0
        let en = AppSettings.shared.lang == .en
        let area = st.nets > 0 ? Geo.fmtArea(st.net, en) + " " + tr("u.m2") : "— " + tr("u.m2")
        HStack(spacing: 12) {
            Group {
                if let r0 = p.rooms.first { RoomThumb(r: r0).frame(width: 46, height: 40) }
                else { PathIcon(EMPTY_THUMB, G.cobalt, 40, 1.8, viewBox: 40) }
            }
                .frame(width: 64, height: 64)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.7)))
                .topHighlight(RoundedRectangle(cornerRadius: 18, style: .continuous), 1, width: 1)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    T(dn(p.name), ui(16, 800), lines: 1).frame(maxWidth: .infinity, alignment: .leading)
                    T(label, ui(12, 700, fg), lines: 1).padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(bg))
                }
                T([dn(p.customer), area].filter { !$0.isEmpty }.joined(separator: " · "), ui(13, 400, G.ink2), lines: 1)
                HStack(spacing: 8) {
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(G.ink.opacity(0.08))
                            Capsule().fill(pct >= 1 ? G.green : G.cobalt).frame(width: g.size.width * pct)
                        }
                    }
                    .frame(height: 6)
                    T("\(st.conf)/\(st.need)", ui(12, 700, G.slate))
                }
            }
        }
        .padding(.leading, 12).padding(.trailing, 14).padding(.vertical, 12)
        .glassCard(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .pressable(0.985, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/* ---------------- New project and Edit project (prototype PAGES.newProject) ---------------- */

private enum NF: Hashable { case name, cust, phone, addr }

struct NewProjectScreen: View {
    let app: AppModel
    let editId: String?
    @State private var name = ""
    @State private var customer = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var loc: Location? = nil
    @State private var tried = false
    @State private var touched: Set<String> = []
    @State private var loaded = false
    // the location, read at its best accuracy for up to 30 s (UX/OrderLocation.swift Gps)
    @State private var gps = Gps()
    @FocusState private var focus: NF?

    private var edit: Project? { editId.flatMap { Store.shared.get($0) } }
    /// A furniture order (new for a furniture maker, or one being edited) says "order" instead of "project".
    // a furniture maker's or a tradesman's project is an order
    private var furn: Bool { edit.map { $0.industry != "build" } ?? orderWords() }

    var body: some View {
        let nameErr = name.trimmingCharacters(in: .whitespaces).isEmpty ? tr("np.nameReq") : nil
        let custErr = customer.trimmingCharacters(in: .whitespaces).isEmpty ? tr("np.customerReq") : nil
        let phErr = Phone.errorKey(phone, required: false).map { tr($0) }
        let ok = nameErr == nil && custErr == nil && phErr == nil
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    GlassIconButton(edit != nil ? "back" : "x", tr(edit != nil ? "nt.back" : "common.close")) { app.pop() }.padding(.leading, 6)
                    BarTitle(title: tr(furn ? "fo.details" : "np.editTitle"), eyebrow: edit == nil ? tr(furn ? "fo.new" : "np.title") : nil)
                }
                .padding(.trailing, 12).frame(minHeight: 64)
                .background(barTint.ignoresSafeArea(edges: .top))
                .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        GField(label: tr(furn ? "fo.name" : "np.name"), value: $name, placeholder: tr(furn ? "fo.namePh" : "smp.project"), error: nameErr, showError: show("name"), focus: $focus, me: .name,
                               onSubmit: { focus = .cust }, onBlur: { touched.insert("name") })
                        GField(label: tr("np.customerName"), value: $customer, placeholder: tr("smp.customer"), error: custErr, showError: show("customer"), focus: $focus, me: .cust,
                               onSubmit: { focus = .phone }, onBlur: { touched.insert("customer") }, caps: .words)
                        GField(label: tr("np.customerPhone"), value: $phone, placeholder: "90 123 45 67", optional: true, phone: true, error: phErr, showError: show("phone"),
                               focus: $focus, me: .phone, onBlur: { touched.insert("phone") })
                        GField(label: tr("np.address"), value: $address, placeholder: tr("smp.address"), optional: true, focus: $focus, me: .addr, submit: .done,
                               onSubmit: { focus = nil })
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { T(tr("np.location"), ui(15, 700)).frame(maxWidth: .infinity, alignment: .leading); T(tr("common.optional").capitalizedFirst, ui(13, 500, G.ink3)) }
                            LocationBlock(loc: loc, gps: gps, onLocate: locate, onRemove: { loc = nil })
                            T(tr("loc.note"), ui(13, 400, G.ink2))
                        }
                        HStack(alignment: .top, spacing: 10) {
                            MIcon("sliders", G.ink2, 18, 2)
                            let cur = edit?.currency ?? AppSettings.shared.currency
                            let rl = edit.map { Lang.of($0.reportLang) } ?? AppSettings.shared.reportLang
                            // the simple furniture app has no prices, so no currency either
                            T(furn && !AppSettings.shared.advanced ? tr("np.fromSettingsL", ["l": rl.longName]) : tr("np.fromSettings", ["c": cur, "l": rl.longName]),
                              ui(13.5, 400, G.ink2, lh: 1.4)).frame(maxWidth: .infinity, alignment: .leading)
                            if edit == nil { T(tr("np.change"), ui(13.5, 700, G.cobalt)).padding(.horizontal, 4).pressable(0.97) { app.sheet = .currency } }
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(G.ink.opacity(0.06)))
                    }
                    .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 120)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            FloatingFooter {
                GBtn(tr(edit != nil ? "common.save" : furn ? "fo.create" : "np.create"), enabled: ok) { save(ok) }.accessibilityIdentifier("np.save")
            }
        }
        .onAppear {
            // updates start quietly when METRX is already allowed, so the tap is instant; nothing is saved without it
            gps.warm()
            guard !loaded else { return }
            loaded = true
            if let e = edit { name = dn(e.name); customer = dn(e.customer); phone = e.phone; address = dn(e.address); loc = e.location }
            // a new project opens with the cursor in its name, as in the prototype
            else { DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focus = .name } }
        }
        .onDisappear { gps.stop() }
    }

    private func show(_ k: String) -> Bool { tried || touched.contains(k) }

    /// A name that was a sample key stays a key when the text is unchanged.
    private func keep(_ old: String, _ typed: String) -> String { dn(old) == typed ? old : typed }

    private func save(_ ok: Bool) {
        tried = true
        guard ok else { return }
        focus = nil
        let n = name.trimmingCharacters(in: .whitespaces), c = customer.trimmingCharacters(in: .whitespaces), a = address.trimmingCharacters(in: .whitespaces)
        if let e = edit {
            Store.shared.update(e.id) { p in p.autoName = p.autoName && keep(p.name, n) == p.name; p.name = keep(p.name, n); p.customer = keep(p.customer, c); p.phone = Phone.digits(phone); p.address = keep(p.address, a); p.location = loc }
            app.pop(); app.say("op.saved", ["o": n])
        } else {
            var p = newProject(n, c, Phone.digits(phone), a, loc, AppSettings.shared.currency, AppSettings.shared.reportLang.code)
            if AppSettings.shared.furniture { p.industry = "furniture" } else if let t = AppSettings.shared.industry, isTrade(t) { p.industry = t }
            Store.shared.add(p)
            app.replaceTop(.project(id: p.id, tab: "rooms"))
            app.say("np.created", ["n": n])
        }
    }

    private func locate() {
        gps.locate { end in
            switch end {
            case .ok(let l): loc = l
            case .fail: app.say("loc.fail", kind: .error)
            // iOS cannot turn the location on from an app: the toast says where and opens METRX's page in Settings
            case .off: app.say("loc.offT", kind: .error, action: "loc.settings") { openAppSettings() }
            case .denied: app.say("loc.deniedT", kind: .error, action: "loc.settings") { openAppSettings() }
            }
        }
    }
}

private struct LocationBlock: View {
    let loc: Location?
    let gps: Gps
    let onLocate: () -> Void
    let onRemove: () -> Void
    var body: some View {
        let locating = gps.locating
        if loc == nil && !locating {
            GBtn(tr("loc.get"), kind: .secondary, icon: "pin", onLocate).accessibilityIdentifier("np.locate")
        } else {
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
            VStack(spacing: 0) {
                // a small drawn map: a pale grid, the accuracy circle and the pin
                ZStack {
                    Canvas { ctx, size in
                        var x: CGFloat = 0; while x < size.width { ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(Color(argb: 0x1A3550E0))); x += 22 }
                        var y: CGFloat = 0; while y < size.height { ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)), with: .color(Color(argb: 0x1A3550E0))); y += 22 }
                        ctx.fill(Path(ellipseIn: CGRect(x: size.width / 2 - 26, y: size.height / 2 - 26, width: 52, height: 52)), with: .color(G.cobalt.opacity(0.14)))
                    }
                    if !locating { MIcon("pin", G.cobalt, 28, 2.2) }
                }
                .frame(height: 96).background(Theme.shared.dark ? G.blueWash : Color(argb: 0xFFE8EEF8))
                HStack(spacing: 8) {
                    MIcon("pin", G.ink2, 18, 2)
                    if locating {
                        // the best reading so far while it gets better, and "Shu yetarli" to keep it now
                        if let b = gps.best { T(tr(b.cached ? "loc.liveC" : "loc.live", ["m": b.loc.acc]), ui(14, 700), lines: 2).accessibilityIdentifier("loc.live") }
                        else { T(tr("loc.locating"), ui(14, 500, G.ink2)) }
                    }
                    else if let loc {
                        T(String(format: "%.5f, %.5f", loc.lat, loc.lng), ui(14, 700))
                        T(tr("loc.acc", ["m": loc.acc]), ui(13, 400, G.ink2))
                    }
                    Spacer(minLength: 0)
                    if locating && gps.best != nil {
                        T(tr("loc.enough"), ui(14, 700, G.cobalt)).padding(.horizontal, 8).frame(minHeight: 44)
                            .pressable(0.97) { Haptic.tick(); gps.enough() }
                            .accessibilityIdentifier("loc.enough")
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                if locating && gps.reduced { ApproxNote().padding(.horizontal, 14).padding(.bottom, 10) }
                if !locating && loc != nil {
                    HStack {
                        T(tr("loc.again"), ui(14, 700, G.cobalt)).padding(.horizontal, 8).padding(.vertical, 12).pressable(0.97, onLocate)
                        T(tr("loc.remove"), ui(14, 700, G.err)).padding(.horizontal, 8).padding(.vertical, 12).pressable(0.97, onRemove)
                        Spacer()
                    }
                    .padding(.horizontal, 6).padding(.bottom, 6)
                }
            }
            .clipShape(shape)
            .background(shape.fill(G.glass(0.6)))
            .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        }
    }
}

