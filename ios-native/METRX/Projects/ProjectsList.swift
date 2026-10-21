import SwiftUI
import CoreLocation

/// Projects: search with a round +, three chips, compact rows (prototype glass PAGES.projects).
struct ProjectsList: View {
    let app: AppModel
    @State private var seg = "active"
    @State private var q = ""

    /// A paid furniture order counts as done in the chips.
    private func stageOf(_ p: Project) -> String { p.isFurniture && p.stage == "paid" ? "done" : p.stage }

    var body: some View {
        let furniture = AppSettings.shared.furniture
        let all = Store.shared.projects
        // each industry sees its own projects; the others stay one chip away (furniture plan section 3)
        let ps = all.filter { $0.isFurniture == furniture }
        let others = all.filter { $0.isFurniture != furniture }
        VStack(alignment: .leading, spacing: 0) {
            GlassHeader { app.sheet = .device }
            PageTitle(text: tr(furniture ? "fo.tab" : "tab.projects")).padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 4)
            if all.isEmpty {
                ProjectsEmpty(app: app)
            } else {
                let n = ["active": ps.filter { stageOf($0) != "done" }.count, "done": ps.filter { stageOf($0) == "done" }.count, "all": ps.count, "other": others.count]
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
                                .pressable(0.95, label: tr("hm.t.new")) { app.push(.newProject(editId: nil)) }
                                .accessibilityIdentifier("projects.new")
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach([("active", "pl.active"), ("done", "pl.doneSeg"), ("all", "pl.allSeg")] + (others.isEmpty ? [] : [("other", "fo.other")]), id: \.0) { k, l in
                                    let on = seg == k
                                    T("\(tr(l)) · \(n[k] ?? 0)", ui(14, on ? 700 : 600, on ? G.solid : G.slate))
                                        .padding(.horizontal, 16).padding(.vertical, 10).frame(minHeight: 40)
                                        .background(Capsule().fill(on ? G.ink : G.glass(0.45)))
                                        .overlay(Capsule().strokeBorder(on ? G.ink : G.rim, lineWidth: 1))
                                        .pressable(0.97) { seg = k }
                                        .accessibilityAddTraits(on ? .isSelected : [])
                                }
                            }
                        }
                        VStack(spacing: 10) {
                            ForEach(furniture && seg != "other" ? sortOrders(list) : list) { p in
                                if p.isFurniture { OrderRow(p: p) { app.push(.project(id: p.id, tab: "rooms")) } }
                                else { ProjectRow(p: p) { app.push(.project(id: p.id, tab: "rooms")) } }
                            }
                            if list.isEmpty {
                                T(tr(needle.isEmpty ? "pl.none" : "pl.noMatch"), ui(14.5, 400, G.ink2), align: .center).frame(maxWidth: .infinity).padding(.vertical, 24)
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
                T(tr("pl.e.t"), ui(21, 800, G.ink, lh: 1.2, ls: -0.01), align: .center)
                T(tr("pl.e.b"), ui(15, 400, G.ink2, lh: 1.5), align: .center).frame(maxWidth: 300).padding(.bottom, 10)
                GlassButton(tr("pl.e.new"), icon: "plus") { app.push(.newProject(editId: nil)) }.accessibilityIdentifier("projects.first")
            }
            .padding(.horizontal, 22).padding(.top, 34).padding(.bottom, 22)
            .frame(maxWidth: .infinity)
            .glassCard(RoundedRectangle(cornerRadius: 26, style: .continuous), fill: G.glass(0.55))
            T(tr("pl.e.foot"), ui(13.5, 400, G.ink3), align: .center).frame(maxWidth: .infinity).padding(.top, 8)
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
    @State private var locating = false
    @State private var tried = false
    @State private var touched: Set<String> = []
    @State private var loaded = false
    @State private var locator = OneFix()
    @FocusState private var focus: NF?

    private var edit: Project? { editId.flatMap { Store.shared.get($0) } }
    /// A furniture order (new for a furniture maker, or one being edited) says "order" instead of "project".
    private var furn: Bool { edit?.isFurniture ?? AppSettings.shared.furniture }

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
                .background(G.sheet(0.55).ignoresSafeArea(edges: .top))
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
                            LocationBlock(loc: loc, locating: locating, onLocate: locate, onRemove: { loc = nil })
                            T(tr("loc.note"), ui(13, 400, G.ink2))
                        }
                        HStack(alignment: .top, spacing: 10) {
                            MIcon("sliders", G.ink2, 18, 2)
                            let cur = edit?.currency ?? AppSettings.shared.currency
                            let rl = edit.map { Lang.of($0.reportLang) } ?? AppSettings.shared.reportLang
                            T(tr("np.fromSettings", ["c": cur, "l": rl.longName]), ui(13.5, 400, G.ink2, lh: 1.4)).frame(maxWidth: .infinity, alignment: .leading)
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
            guard !loaded else { return }
            loaded = true
            if let e = edit { name = dn(e.name); customer = dn(e.customer); phone = e.phone; address = dn(e.address); loc = e.location }
            // a new project opens with the cursor in its name, as in the prototype
            else { DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focus = .name } }
        }
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
        locating = true
        locator.get { l in
            locating = false
            if let l { loc = l } else { app.say("loc.fail", kind: .error) }
        }
    }
}

private struct LocationBlock: View {
    let loc: Location?
    let locating: Bool
    let onLocate: () -> Void
    let onRemove: () -> Void
    var body: some View {
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
                    if locating { T(tr("loc.locating"), ui(14, 500, G.ink2)) }
                    else if let loc {
                        T(String(format: "%.5f, %.5f", loc.lat, loc.lng), ui(14, 700))
                        T(tr("loc.acc", ["m": loc.acc]), ui(13, 400, G.ink2))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
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

/// One location fix (GPS works without internet). Calls back with nil when the phone can't get one within 15 s or
/// location is not allowed.
final class OneFix: NSObject, CLLocationManagerDelegate {
    private let m = CLLocationManager()
    private var done: ((Location?) -> Void)?
    private var timer: DispatchWorkItem?

    override init() { super.init(); m.delegate = self; m.desiredAccuracy = kCLLocationAccuracyBest }

    func get(_ cb: @escaping (Location?) -> Void) {
        done = cb
        let t = DispatchWorkItem { [weak self] in self?.finish(self?.m.location) }
        timer = t
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: t)
        switch m.authorizationStatus {
        case .notDetermined: m.requestWhenInUseAuthorization()
        case .denied, .restricted: finish(nil)
        default: m.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard done != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        case .denied, .restricted: finish(nil)
        default: break
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) { finish(locations.last) }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { finish(nil) }

    private func finish(_ l: CLLocation?) {
        guard let cb = done else { return }
        done = nil; timer?.cancel()
        let r = l.map { Location(lat: $0.coordinate.latitude, lng: $0.coordinate.longitude, acc: max(1, Int($0.horizontalAccuracy)), ts: nowMs()) }
        DispatchQueue.main.async { cb(r) }
    }
}
