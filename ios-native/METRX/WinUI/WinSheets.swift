import SwiftUI

/*
 * The windows-and-doors sheets (Android ui/win/WinScreens.kt, sheets part): a new room, the order's fitting gap, and
 * the prices (a list per profile system, then the glass, extras, doors and labour).
 */

struct WinSheet: View {
    let app: AppModel
    let sheet: Sheet
    static func handles(_ s: Sheet) -> Bool {
        switch s { case .wNewRoom, .wGap, .wPrices: return true; default: return false }
    }
    var body: some View {
        switch sheet {
        case .wNewRoom(let pid): WNNewRoomSheet(app: app, pid: pid)
        case .wGap(let pid): WNGapSheet(app: app, pid: pid)
        case .wPrices(let pid): WNPricesSheet(app: app, pid: pid)
        default: EmptyView()
        }
    }
}

/// Digits only, at most n of them.
func wDigits(_ b: Binding<String>, _ n: Int) -> Binding<String> {
    Binding(get: { b.wrappedValue }, set: { v in b.wrappedValue = String(v.filter { $0.isASCII && $0.isNumber }.prefix(n)) })
}

/// A row with a title, a line under it and a switch.
struct WNSwitchRow: View {
    let title: String
    var sub: String? = nil
    let on: Bool
    let action: () -> Void
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                T(title, ui(14.5, 700))
                if let sub { T(sub, ui(12, 400, G.ink2, lh: 1.3)) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            GSwitch(on: on)
        }
        .padding(.horizontal, 12).padding(.vertical, 6).frame(minHeight: 54)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.glass(0.7)))
        .pressable(0.98, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
    }
}

/* ---------------- a new room ---------------- */

private enum WNNF: Hashable { case name }

private struct WNNewRoomSheet: View {
    let app: AppModel
    let pid: String
    @State private var name: String
    @FocusState private var focus: WNNF?
    init(app: AppModel, pid: String) {
        self.app = app; self.pid = pid
        _name = State(initialValue: Store.shared.get(pid).map { nextName($0, "dw.roomName") } ?? tr("dw.roomName"))
    }
    var body: some View {
        GlassSheet(tr("fo.addRoom"), onClose: { app.sheet = nil }) {
            GField(label: tr("fr.name"), value: $name, placeholder: tr("dw.roomName"), error: name.trimmingCharacters(in: .whitespaces).isEmpty ? tr("nr.nameReq") : nil,
                   showError: true, focus: $focus, me: .name, submit: .done, onSubmit: create)
                .onChange(of: name) { _, n in if n.count > NAME_MAX { name = String(n.prefix(NAME_MAX)) } }
            T(tr("dw.roomB"), ui(12.5, 400, G.ink2, lh: 1.4))
        } footer: {
            GBtn(tr("fr.continue"), enabled: !name.trimmingCharacters(in: .whitespaces).isEmpty, create).accessibilityIdentifier("dw.roomCreate")
        }
    }
    private func create() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty, app.once() else { return }
        // a suggested name is kept as its key, so it follows the language
        app.sheet = nil
        // the shape, sizes, height and openings come next, in the room-shape flow (Rooms/RshScreens.swift)
        startRoomShape(app, pid, trade: "win", kind: "room", name: suggestedName(n, "dw.roomName"))
    }
}

/* ---------------- the fitting gap ---------------- */

private enum WNGF: Hashable { case gap }

/// The fitting gap new products get, and optionally every product that follows its opening.
private struct WNGapSheet: View {
    let app: AppModel
    let pid: String
    @State private var t: String
    @State private var all = true
    @FocusState private var focus: WNGF?
    init(app: AppModel, pid: String) {
        self.app = app; self.pid = pid
        _t = State(initialValue: "\(Store.shared.get(pid)?.win.gap ?? W_GAP)")
    }
    private var value: Int? {
        guard let v = Int(t), v >= W_GAP_MIN, v <= W_GAP_MAX else { return nil }
        return v
    }
    var body: some View {
        GlassSheet(tr("dw.gap"), onClose: { app.sheet = nil }) {
            GField(label: tr("dw.gapEach"), value: wDigits($t, 2), placeholder: "20", focus: $focus, me: .gap, labelRight: tr("dw.mm"), number: true)
            T(tr("dw.gapB"), ui(12.5, 400, G.ink2, lh: 1.4))
            WNSwitchRow(title: tr("dw.gapAll"), on: all) { all.toggle() }
            if value == nil { T(tr("dw.gapErr", ["a": W_GAP_MIN, "b": W_GAP_MAX]), ui(13, 500, G.err)) }
        } footer: {
            GBtn(tr("common.save"), enabled: value != nil) { save() }.accessibilityIdentifier("dw.gapSave")
        }
    }
    private func save() {
        guard let v = value else { return }
        let every = all
        updateWin(pid) { e in
            e.gap = v
            if every {
                e.items = e.items.map { it in
                    var x = it
                    if it.inRoom && it.fit { x.gap = v }
                    return x
                }
            }
        }
        refitWin(pid)
        app.sheet = nil
        app.say("common.save")
    }
}

/* ---------------- the prices ---------------- */

/// One price: its key, unit, and where it is in the prices.
private struct WNPField {
    let key: String
    let unit: String
    let path: WritableKeyPath<WinPrices, String>
}

private func wnSysFields(_ s: String) -> [WNPField] {
    let base: WritableKeyPath<WinPrices, WSys> = s == "alu" ? \WinPrices.alu : \WinPrices.pvc
    return [
        WNPField(key: "frameM", unit: "/m", path: base.appending(path: \WSys.frameM)),
        WNPField(key: "sashM", unit: "/m", path: base.appending(path: \WSys.sashM)),
        WNPField(key: "mullM", unit: "/m", path: base.appending(path: \WSys.mullM)),
        WNPField(key: "hwTurn", unit: "", path: base.appending(path: \WSys.hwTurn)),
        WNPField(key: "hwTilt", unit: "", path: base.appending(path: \WSys.hwTilt)),
        WNPField(key: "hwTT", unit: "", path: base.appending(path: \WSys.hwTT)),
        WNPField(key: "hwSlide", unit: "", path: base.appending(path: \WSys.hwSlide)),
        WNPField(key: "lM2", unit: "/m²", path: base.appending(path: \WSys.lM2))
    ]
}

private let WN_COMMON: [WNPField] = [
    WNPField(key: "glass1", unit: "/m²", path: \WinPrices.glass1), WNPField(key: "glass2", unit: "/m²", path: \WinPrices.glass2),
    WNPField(key: "panel", unit: "/m²", path: \WinPrices.panel), WNPField(key: "lam", unit: "/m", path: \WinPrices.lam),
    WNPField(key: "sill", unit: "/m", path: \WinPrices.sill), WNPField(key: "drip", unit: "/m", path: \WinPrices.drip),
    WNPField(key: "reveal", unit: "/m²", path: \WinPrices.reveal), WNPField(key: "net", unit: "", path: \WinPrices.net),
    WNPField(key: "handle", unit: "", path: \WinPrices.handle), WNPField(key: "hwDoor", unit: "", path: \WinPrices.hwDoor),
    WNPField(key: "dInt", unit: "/m²", path: \WinPrices.dInt), WNPField(key: "dEnt", unit: "/m²", path: \WinPrices.dEnt),
    WNPField(key: "dSl", unit: "/m²", path: \WinPrices.dSl), WNPField(key: "dGl", unit: "/m²", path: \WinPrices.dGl),
    WNPField(key: "lDoor", unit: "", path: \WinPrices.lDoor), WNPField(key: "lSill", unit: "/m", path: \WinPrices.lSill),
    WNPField(key: "lReveal", unit: "/m²", path: \WinPrices.lReveal), WNPField(key: "lDrip", unit: "/m", path: \WinPrices.lDrip)
]

/// The groups of prices in order: each profile system's, then the common ones.
private let WN_GROUPS: [(String, [WNPField])] = [("pvc", wnSysFields("pvc")), ("alu", wnSysFields("alu")), ("common", WN_COMMON)]
private let WN_ALL: [WNPField] = WN_GROUPS.flatMap { $0.1 }

/// The prices, one set for all orders: a list per profile system, then the glass, extras, doors and labour.
private struct WNPricesSheet: View {
    let app: AppModel
    let pid: String?
    @State private var texts: [String]
    @State private var tab = "pvc"
    @FocusState private var focus: String?
    init(app: AppModel, pid: String?) {
        self.app = app; self.pid = pid
        let t0 = AppSettings.shared.trade.win
        _texts = State(initialValue: WN_ALL.map { t0[keyPath: $0.path] })
    }
    var body: some View {
        let fs = WN_GROUPS.first { $0.0 == tab }?.1 ?? []
        GlassSheet(tr("tl.prices"), onClose: { app.sheet = nil }) {
            FlowLayout(spacing: 8) {
                ForEach(WN_GROUPS.map(\.0), id: \.self) { k in
                    FChip(label: tr(k == "common" ? "dw.p.common" : "dw.p." + k), on: k == tab) { tab = k }
                }
            }
            T(tr(tab == "common" ? "dw.p.commonS" : "dw.p.sysS"), ui(12.5, 400, G.ink2, lh: 1.4))
            ForEach(Array(stride(from: 0, to: fs.count, by: 2)), id: \.self) { i in
                HStack(alignment: .top, spacing: 10) {
                    field(fs[i])
                    if i + 1 < fs.count { field(fs[i + 1]) } else { Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                }
            }
            T(tr("dw.pricesNote"), ui(12.5, 400, G.ink2, lh: 1.4))
        } footer: {
            GBtn(tr("common.save")) { save() }.accessibilityIdentifier("dw.pricesSave")
        }
    }
    private func field(_ f: WNPField) -> some View {
        let i = WN_ALL.firstIndex { $0.path == f.path } ?? 0
        let text = Binding(get: { i < texts.count ? texts[i] : "" }, set: { v in
            if i < texts.count { texts[i] = String(v.filter { $0.isASCII && $0.isNumber }.prefix(12)) }
        })
        let id = tab + "." + f.key
        return GField(label: tr("dw.pr." + f.key), value: text, placeholder: "0", focus: $focus, me: id, labelRight: f.unit.isEmpty ? nil : unitText(f.unit), number: true, id: "dwf." + id)
            .frame(maxWidth: .infinity)
    }
    private func save() {
        var st = AppSettings.shared.trade
        var w = st.win
        for (i, f) in WN_ALL.enumerated() where i < texts.count {
            let v = texts[i].trimmingCharacters(in: .whitespaces)
            if !v.isEmpty { w[keyPath: f.path] = v }
        }
        st.win = w
        AppSettings.shared.setTradeSet(st)
        app.sheet = nil
        if let id = pid, let pr = Store.shared.get(id), madeBy(pr, "dw.e.") { applyWinRows(app, pr) }
        else { app.say("common.save") }
    }
}
