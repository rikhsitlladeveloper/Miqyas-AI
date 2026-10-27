import SwiftUI
import UIKit

/*
 * An order's location, for every trade (room-shapes build spec §1, approved 26 Oct 2026; Android ui/loc/OrderLocation.kt
 * and core/MapLinks.kt): GPS only, read when the maker taps "Joylashuvni aniqlash" (no link pasting); the new-order
 * form's block, the cards' chip with "Yo‘l" or "+ Qo‘shish", the Ma’lumot tab's card and the sheets. The location is
 * never printed in a furniture or trade PDF (Report/Snapshot.swift keeps it for a builder's report only).
 */

/* ---------------- the map links ---------------- */

/// The links of the "Yo‘l" sheet: the pin in Yandex Maps, a route in Yandex Navigator, Google Maps, and the coordinates
/// to copy. An app that is not installed falls back to its https map link. Pure, so the links are unit-tested.
enum MapLinks {
    /// The map apps of the sheet, in its order, with their URL schemes (LSApplicationQueriesSchemes in Info.plist).
    enum App: CaseIterable { case yandexMaps, yandexNavi, googleMaps
        var scheme: String {
            switch self {
            case .yandexMaps: return "yandexmaps"
            case .yandexNavi: return "yandexnavi"
            case .googleMaps: return "comgooglemaps"
            }
        }
    }

    /// One coordinate with 5 decimals (about 1 m), always with a dot.
    static func c(_ v: Double) -> String { String(format: "%.5f", locale: Locale(identifier: "en_US_POSIX"), v) }

    /// "41.31110, 69.27970": what the cards show and "Nusxa olish" copies.
    static func coords(_ lat: Double, _ lng: Double) -> String { c(lat) + ", " + c(lng) }

    static func yandexMaps(_ lat: Double, _ lng: Double) -> String { "yandexmaps://maps.yandex.ru/?pt=\(c(lng)),\(c(lat))&z=17" }
    static func yandexNavi(_ lat: Double, _ lng: Double) -> String { "yandexnavi://build_route_on_map?lat_to=\(c(lat))&lon_to=\(c(lng))" }
    static func googleApp(_ lat: Double, _ lng: Double) -> String { "comgooglemaps://?q=\(c(lat)),\(c(lng))&center=\(c(lat)),\(c(lng))&zoom=17" }
    static func yandexWeb(_ lat: Double, _ lng: Double) -> String { "https://yandex.uz/maps/?pt=\(c(lng)),\(c(lat))&z=17" }
    static func googleWeb(_ lat: Double, _ lng: Double) -> String { "https://maps.google.com/?q=\(c(lat)),\(c(lng))" }

    /// The app's own link: Yandex note longitude first, Google latitude first.
    static func appLink(_ a: App, _ lat: Double, _ lng: Double) -> String {
        switch a {
        case .yandexMaps: return yandexMaps(lat, lng)
        case .yandexNavi: return yandexNavi(lat, lng)
        case .googleMaps: return googleApp(lat, lng)
        }
    }

    /// The https map link used when the app is missing (both Yandex apps open Yandex's map in the browser).
    static func webLink(_ a: App, _ lat: Double, _ lng: Double) -> String {
        a == .googleMaps ? googleWeb(lat, lng) : yandexWeb(lat, lng)
    }

    /// What to open for a: its own link when installed, else the https fallback.
    static func open(_ a: App, _ lat: Double, _ lng: Double, installed: (String) -> Bool) -> String {
        installed(a.scheme) ? appLink(a, lat, lng) : webLink(a, lat, lng)
    }
}

/// Whether a map app is on the phone (its scheme is listed in Info.plist, so iOS answers).
private func mapInstalled(_ scheme: String) -> Bool {
    guard let u = URL(string: scheme + "://") else { return false }
    return UIApplication.shared.canOpenURL(u)
}

/// Opens l in map app a, or its https map when the app is missing (or refuses the link); done(false) when nothing opened.
func openInMap(_ a: MapLinks.App, _ l: Location, done: @escaping (Bool) -> Void) {
    let link = MapLinks.open(a, l.lat, l.lng, installed: mapInstalled)
    guard let u = URL(string: link) else { done(false); return }
    UIApplication.shared.open(u, options: [:]) { ok in
        if ok { done(true); return }
        guard let w = URL(string: MapLinks.webLink(a, l.lat, l.lng)), w != u else { done(false); return }
        UIApplication.shared.open(w, options: [:]) { done($0) }
    }
}

/* ---------------- GPS ---------------- */

/// Reading the GPS from a screen: the permission is asked on the first tap (Projects/ProjectsList.swift OneFix); locating
/// while it runs. A refusal or no fix in 15 s answers nil.
@Observable
final class Gps {
    private(set) var locating = false
    @ObservationIgnored private var fix: OneFix? = nil

    func locate(_ done: @escaping (Location?) -> Void) {
        if locating { return }
        locating = true
        let f = OneFix()
        fix = f
        f.get { [weak self] l in
            guard let self, self.fix === f else { return }
            self.fix = nil; self.locating = false
            done(l)
        }
    }

    /// Stops a fix that is running; nothing is called back.
    func cancel() { fix?.cancel(); fix = nil; locating = false }
}

/* ---------------- small parts ---------------- */

private let NAV_IC = "M3.5 10.5L20 4l-6.5 16.5-2.2-7.3z"
private let GPS_IC = "M5 12a7 7 0 1 0 14 0a7 7 0 1 0 -14 0z M9.5 12a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0z M12 2v3M12 19v3M2 12h3M19 12h3"
private let WARN_IC = "M12 3.5l9 16H3z M12 10v4M12 17h.01"

private var greenInk: Color { Theme.shared.dark ? G.green : Color(argb: 0xFF15803D) }

/// The pin with its coordinates, "±N m" and where it came from (mockup pinRow).
struct PinRow: View {
    let l: Location
    var body: some View {
        HStack(spacing: 10) {
            MIcon("pin", greenInk, 20, 2).frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.glass(0.85)))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    T(MapLinks.coords(l.lat, l.lng), num(14.5, 700), lines: 1).minimumScaleFactor(0.8)
                    T(tr("loc.acc", ["m": l.acc]), ui(11.5, 800, greenInk), lines: 1)
                        .padding(.horizontal, 7).padding(.vertical, 2)
                        .background(Capsule().fill(G.glass(0.85)))
                        .accessibilityIdentifier("loc.acc")
                }
                T(tr("loc.src"), ui(12, 400, G.ink2))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.greenWash))
        .accessibilityElement(children: .combine)
    }
}

/// "Joylashuv aniqlanmoqda…" with a spinner and "Bekor".
struct WaitRow: View {
    let onCancel: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            ProgressView().tint(G.cobalt).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                T(tr("loc.wait"), ui(14.5, 700))
                T(tr("loc.waitS"), ui(12, 400, G.ink2))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            T(tr("loc.cancel"), ui(14, 700, G.cobalt2)).padding(.horizontal, 12).frame(minHeight: 44)
                .pressable(0.97, onCancel)
                .accessibilityIdentifier("loc.cancel")
        }
        .padding(.leading, 12).padding(.trailing, 6).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.blueWash))
    }
}

/// "Joylashuvni aniqlab bo‘lmadi" with the hint about the permission and GPS.
struct FailRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            PathIcon(WARN_IC, G.err, 22, 2)
            VStack(alignment: .leading, spacing: 2) {
                T(tr("loc.failT"), ui(14.5, 700))
                T(tr("loc.failB"), ui(12.5, 400, G.ink2, lh: 1.4))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.errWash))
        .accessibilityElement(children: .combine)
    }
}

/// The big "Joylashuvni aniqlash" button.
struct GpsButton: View {
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        HStack(spacing: 10) {
            PathIcon(GPS_IC, G.cobalt2, 22, 2)
            T(tr("loc.get"), ui(15.5, 700, G.cobalt2), align: .center)
        }
        .padding(.horizontal, 16).padding(.vertical, 12).frame(maxWidth: .infinity, minHeight: 56)
        .background(shape.fill(G.cobalt.opacity(0.1)))
        .overlay(shape.strokeBorder(G.cobalt.opacity(0.22), lineWidth: 1))
        .pressable(0.98, action)
        .accessibilityIdentifier("loc.get")
    }
}

/// A grey half-width button ("Qayta aniqlash", "Olib tashlash"…); danger red.
private struct Btn2: View {
    let label: String
    var icon: String? = nil
    var gps = false
    var danger = false
    var id: String? = nil
    let action: () -> Void
    var body: some View {
        let fg = danger ? G.err : G.ink
        HStack(spacing: 6) {
            if gps { PathIcon(GPS_IC, fg, 18, 2) } else if let icon { MIcon(icon, fg, 18, 2) }
            T(label, ui(14, 700, fg), align: .center, lines: 2)
        }
        .padding(.horizontal, 10).padding(.vertical, 10).frame(maxWidth: .infinity, minHeight: 46)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(danger ? G.errWash : G.ink.opacity(0.06)))
        .pressable(0.97, action)
        .accessibilityIdentifier(id ?? "")
    }
}

/// The chip: green "Joylashuv bor" or muted "Joylashuv yo‘q".
struct LocChip: View {
    let has: Bool
    var body: some View {
        let fg = has ? greenInk : G.ink2
        HStack(spacing: 5) {
            MIcon("pin", fg, 15, 2.2)
            T(tr(has ? "loc.has" : "loc.no"), ui(12.5, 700, fg), lines: 1)
        }
        .padding(.horizontal, 11).frame(minHeight: 32)
        .background(Capsule().fill(has ? G.greenWash : G.ink.opacity(0.07)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(has ? "loc.has" : "loc.no")
    }
}

/// "+ Qo‘shish": opens the sheet with the GPS button.
struct AddLocLink: View {
    let action: () -> Void
    var body: some View {
        T(tr("loc.add"), ui(12.5, 800, G.cobalt2), lines: 1)
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(Capsule().fill(G.blueWash))
            .frame(minHeight: 44)
            .pressable(0.97, label: tr("loc.addA"), action)
            .accessibilityIdentifier("loc.add")
    }
}

/// The blue "Yo‘l" button.
struct YolButton: View {
    var fill = false
    let action: () -> Void
    var body: some View {
        HStack(spacing: 6) {
            PathIcon(NAV_IC, .white, 18, 2.2)
            T(tr("loc.yol"), ui(14.5, 800, .white), lines: 1)
        }
        .padding(.horizontal, 16).frame(maxWidth: fill ? .infinity : nil, minHeight: 44)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.cobalt))
        .pressable(0.97, label: tr("loc.yolA"), action)
        .accessibilityIdentifier("loc.yol")
    }
}

/* ---------------- the new-order form ---------------- */

/// The form's location state: none, locating, ok, fail or skip (mockup locBlock).
enum LocState { case none, locating, ok, fail, skip }

/// The "Joylashuv" block under the address of the new-order form, shared by every trade. state and loc live in the
/// form; gps reads the fix (the form sets ok or fail when it answers).
struct LocFormBlock: View {
    let app: AppModel
    @Binding var state: LocState
    @Binding var loc: Location?
    let gps: Gps

    private func locate() {
        Haptic.tick()
        state = .locating
        gps.locate { l in
            guard state == .locating else { return }
            if let l { loc = l; state = .ok; Haptic.confirm() } else { state = .fail; Haptic.warn() }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                MIcon("pin", G.cobalt, 18, 2.2)
                T(tr("np.location"), ui(15, 800))
                T(tr("loc.optPdf"), ui(12, 500, G.ink3), align: .trailing, lines: 2).frame(maxWidth: .infinity, alignment: .trailing)
            }
            switch state {
            case .locating:
                WaitRow { gps.cancel(); state = .none }
            case .ok:
                if let l = loc {
                    PinRow(l: l)
                    HStack(spacing: 8) {
                        Btn2(label: tr("loc.again"), gps: true, id: "loc.again", action: locate)
                        Btn2(label: tr("loc.remove"), icon: "trash", danger: true, id: "loc.remove") {
                            let prev = l
                            loc = nil; state = .none
                            app.say("loc.removed", kind: .info, action: "common.undo") { loc = prev; state = .ok }
                        }
                    }
                }
            case .fail:
                FailRow()
                HStack(spacing: 8) { Btn2(label: tr("loc.retry"), gps: true, id: "loc.retry", action: locate) }
                Later { Haptic.tick(); state = .skip }
            case .skip:
                HStack(spacing: 8) {
                    LocChip(has: false)
                    T(tr("loc.skipped"), ui(12.5, 400, G.ink2)).frame(maxWidth: .infinity, alignment: .leading)
                    AddLocLink { state = .none }
                }
            case .none:
                GpsButton(action: locate)
                T(tr("loc.hint"), ui(12.5, 400, G.ink2, lh: 1.4))
                Later { Haptic.tick(); state = .skip; loc = nil }
            }
        }
        .padding(14)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
    }
}

/// "Keyinroq", underlined.
private struct Later: View {
    let action: () -> Void
    var body: some View {
        Text(tr("loc.later")).st(ui(14, 700, G.ink2)).underline()
            .padding(.horizontal, 14).frame(minHeight: 44)
            .frame(maxWidth: .infinity)
            .pressable(0.97, action)
            .accessibilityIdentifier("loc.later")
    }
}

/* ---------------- order cards and the Ma’lumot tab ---------------- */

/// The order card's line: "Joylashuv bor" with "Yo‘l", or "Joylashuv yo‘q" with "+ Qo‘shish".
struct OrderLocRow: View {
    let app: AppModel
    let p: Project
    var body: some View {
        HStack(spacing: 8) {
            LocChip(has: p.location != nil)
            if p.location == nil { AddLocLink { app.sheet = .locAdd(pid: p.id) } }
            Spacer(minLength: 0)
            if p.location != nil { YolButton { app.sheet = .yol(pid: p.id) } }
        }
    }
}

/// The Ma’lumot tab's location card: the pin, "±N m", Yo‘l and O‘zgartirish; or "Joylashuv yo‘q · + Qo‘shish". No live map.
struct LocInfoCard: View {
    let app: AppModel
    let p: Project
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                T(tr("pr.location"), ui(15, 800)).frame(maxWidth: .infinity, alignment: .leading)
                T(tr("loc.noPdf"), ui(12, 500, G.ink3))
            }
            if let l = p.location {
                PinRow(l: l)
                HStack(spacing: 8) {
                    YolButton(fill: true) { app.sheet = .yol(pid: p.id) }
                    Btn2(label: tr("loc.change"), icon: "edit", id: "loc.change") { app.sheet = .locAdd(pid: p.id) }
                }
            } else {
                HStack(spacing: 8) {
                    LocChip(has: false)
                    Spacer(minLength: 0)
                    AddLocLink { app.sheet = .locAdd(pid: p.id) }
                }
            }
        }
        .padding(14)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
    }
}

/* ---------------- sheets ---------------- */

/// Sets the order's location (nil: removes it) with a toast and Undo.
func setOrderLocation(_ app: AppModel, _ pid: String, _ l: Location?) {
    guard let p = Store.shared.get(pid) else { return }
    let prev = p.location
    if l == nil && prev == nil { return }
    Store.shared.update(pid) { $0.location = l }
    let key = l == nil ? "loc.removed" : prev != nil ? "loc.updated" : "loc.added"
    app.act(key, ["m": l?.acc ?? 0]) { Store.shared.update(pid) { $0.location = prev } }
}

struct LocSheet: View {
    let app: AppModel
    let sheet: Sheet
    static func handles(_ s: Sheet) -> Bool {
        switch s { case .locAdd, .yol: return true; default: return false }
    }
    var body: some View {
        switch sheet {
        case .locAdd(let pid): LocAddSheet(app: app, pid: pid)
        case .yol(let pid): YolSheet(app: app, pid: pid)
        default: EmptyView()
        }
    }
}

private func whoOf(_ p: Project) -> String { dn(p.customer).isEmpty ? dn(p.name) : dn(p.customer) }

private struct LocAddSheet: View {
    let app: AppModel
    let pid: String
    @State private var gps = Gps()
    @State private var failed = false

    private func locate() {
        Haptic.tick(); failed = false
        gps.locate { l in
            if let l { app.sheet = nil; Haptic.confirm(); setOrderLocation(app, pid, l) }
            else { failed = true; Haptic.warn() }
        }
    }

    var body: some View {
        if let p = Store.shared.get(pid) {
            let sub = [whoOf(p), dn(p.address)].filter { !$0.isEmpty }.joined(separator: " · ")
            GlassSheet(tr(p.location != nil ? "loc.changeT" : "loc.addT"), onClose: { gps.cancel(); app.sheet = nil }) {
                if !sub.isEmpty { T(sub, ui(13, 400, G.ink2), lines: 2) }
                if gps.locating {
                    WaitRow { gps.cancel() }
                } else if failed {
                    FailRow()
                    HStack(spacing: 8) { Btn2(label: tr("loc.retry"), gps: true, id: "loc.retry", action: locate) }
                } else {
                    if let l = p.location { PinRow(l: l) }
                    GpsButton(action: locate)
                    T(tr("loc.sheetHint"), ui(12.5, 400, G.ink2, lh: 1.4))
                    if p.location != nil {
                        T(tr("loc.del"), ui(14, 700, G.err)).padding(.horizontal, 14).frame(minHeight: 44).frame(maxWidth: .infinity)
                            .pressable(0.97) { app.sheet = nil; setOrderLocation(app, pid, nil) }
                            .accessibilityIdentifier("loc.del")
                    }
                }
            }
            .onDisappear { gps.cancel() }
        }
    }
}

private struct YolSheet: View {
    let app: AppModel
    let pid: String
    private struct Opt: Identifiable { let key: String; let color: Color; let letter: String?; let icon: String?; let map: MapLinks.App?; var id: String { key } }
    private let opts: [Opt] = [
        Opt(key: "ym", color: Color(argb: 0xFFFC3F1D), letter: "Y", icon: nil, map: .yandexMaps),
        Opt(key: "yn", color: Color(argb: 0xFF6E4BF2), letter: nil, icon: NAV_IC, map: .yandexNavi),
        Opt(key: "gm", color: Color(argb: 0xFF34A853), letter: "G", icon: nil, map: .googleMaps),
        Opt(key: "copy", color: Color(argb: 0xFF64748B), letter: nil, icon: nil, map: nil)
    ]
    var body: some View {
        if let p = Store.shared.get(pid), let l = p.location {
            GlassSheet(tr("loc.yol"), onClose: { app.sheet = nil }) {
                T([whoOf(p), MapLinks.coords(l.lat, l.lng)].filter { !$0.isEmpty }.joined(separator: " · "), ui(13, 400, G.ink2), lines: 2)
                ForEach(opts) { o in row(o, l) }
                T(tr("loc.only"), ui(12.5, 400, G.ink2, lh: 1.4))
            }
        }
    }
    private func row(_ o: Opt, _ l: Location) -> some View {
        let there = o.map.map { mapInstalled($0.scheme) } ?? true
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(o.color)
                if let t = o.letter { T(t, ui(18, 800, .white)) } else if let ic = o.icon { PathIcon(ic, .white, 20, 2.2) } else { MIcon("copy", .white, 20, 2) }
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                T(tr("loc." + o.key), ui(15, 700))
                T(there ? tr("loc." + o.key + "S") : tr("loc.web"), ui(12.5, 400, G.ink2), lines: 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MIcon("chev", G.ink3, 16, 2)
        }
        .padding(.horizontal, 12).padding(.vertical, 10).frame(minHeight: 60)
        .background(shape.fill(G.glass(0.6)))
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .pressable(0.98) {
            Haptic.tick()
            app.sheet = nil
            if let m = o.map {
                openInMap(m, l) { ok in if !ok { DispatchQueue.main.async { app.say("loc.noApp", kind: .error) } } }
            } else {
                let c = MapLinks.coords(l.lat, l.lng)
                UIPasteboard.general.string = c
                app.say("loc.copied", ["c": c])
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("loc.opt." + o.key)
    }
}

/* ---------------- an order card with its location line ---------------- */

extension View {
    /// An order's card in a list: this content opens the order; under it the location line ("Joylashuv bor" + Yo‘l, or
    /// "Joylashuv yo‘q" + Qo‘shish), kept out of the card's own button so its buttons work on their own.
    func orderCard(_ p: Project, corner: CGFloat = 22, h: CGFloat = 14, v: CGFloat = 12, combine: Bool = true, _ action: @escaping () -> Void) -> some View {
        OrderCardShell(p: p, corner: corner, h: h, v: v, combine: combine, action: action, content: self)
    }
}

private struct OrderCardShell<C: View>: View {
    let p: Project
    let corner: CGFloat
    let h: CGFloat
    let v: CGFloat
    let combine: Bool
    let action: () -> Void
    let content: C
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content
                .contentShape(Rectangle())
                .pressable(0.985, action)
                .accessibilityElement(children: combine ? .combine : .contain)
                .accessibilityAddTraits(.isButton)
            OrderLocRow(app: AppModel.shared, p: p)
        }
        .padding(.horizontal, h).padding(.vertical, v)
        .glassCard(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}
