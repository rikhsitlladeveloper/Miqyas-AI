import SwiftUI
import UIKit

/*
 * The report (prototype report.js "option A: read it first"; Android ui/report/ReportScreen.kt): the A4 pages fill the
 * width, swipe between them, tap to zoom; a dark strip keeps the total, page count and language in view; "Set up" holds
 * language, rooms, notes, 3D views and the report's note. A draft can be shared with its DRAFT mark or issued as a
 * frozen quote; an issued quote opens in the same viewer with a lock banner.
 */

private let DARK = Color(argb: 0xFF0E1C36)
private let STRIP_INK = Color(argb: 0xFFB7C3D9)

/// Opens the phone's share sheet for a file (Telegram, WhatsApp, Files, print…).
@MainActor
func presentShare(_ url: URL) {
    guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
          var vc = scene.keyWindow?.rootViewController ?? scene.windows.first?.rootViewController else { return }
    while let p = vc.presentedViewController { vc = p }
    let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    av.popoverPresentationController?.sourceView = vc.view
    vc.present(av, animated: true)
}

struct ReportScreen: View {
    let app: AppModel
    let pid: String
    let no: Int?
    @State private var pages: [RPage] = []
    @State private var images: [UIImage] = []
    @State private var builtKey = ""
    @State private var page = 0
    @State private var viewer: Int? = nil

    var body: some View {
        if let p = Store.shared.get(pid) {
            let quote = no.flatMap { n in p.quotes.first { $0.no == n } }
            // a furniture maker or a tiler in the simple app shares the design: no price, nothing to issue (a tiler's has no estimate)
            let design = isDesign(p, quote)
            let sn = quote?.sn ?? designSnap(p, design)
            let key = quote.map { "q\($0.no)" } ?? (design ? "d" : "") + fingerprint(sn) + "\(sn.pdf)" + sn.lang + sn.roomLabel + sn.extras.map { $0.text + "\($0.checks)" }.joined()
            let total = quote.flatMap { Decimal(string: $0.total) } ?? (p.isFurniture ? Decimal(string: sn.ftotal) ?? 0 : snapTotal(sn))
            let lang = AppSettings.shared.lang
            GeometryReader { geo in
                let w = geo.size.width - 32
                ZStack {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            GlassIconButton("back", tr("nt.back")) { app.pop() }.accessibilityIdentifier("back")
                            VStack(alignment: .leading, spacing: 0) {
                                T(quote.map { tr("q.no", ["n": $0.no]) } ?? tr(design ? "rpt.design" : "rpt.title"), ui(17, 700, G.ink, lh: 1.2), lines: 1)
                                T(dn(p.name), ui(12.5, 400, G.ink2, lh: 1.2), lines: 1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            if quote == nil {
                                HStack(spacing: 6) { MIcon("sliders", G.ink, 18, 2); T(tr("rp2.setup"), ui(14, 600), lines: 1) }
                                    .padding(.horizontal, 12).frame(minHeight: 40)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.glass(0.55)))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
                                    .pressable(0.97) { app.sheet = .reportSetup(pid: p.id) }
                                    .accessibilityIdentifier("rp.setup")
                            }
                        }
                        .padding(.leading, 14).padding(.trailing, 12).frame(height: 64)
                        ScrollView {
                            VStack(spacing: 10) {
                                if quote == nil {
                                    if AppSettings.shared.builderName.trimmingCharacters(in: .whitespaces).isEmpty {
                                        Banner(icon: "alert", text: tr("rpt.noBuilder"), amber: true, action: tr("rpt.addBuilder")) { app.sheet = .issue(pid: p.id, builderOnly: true) }
                                    }
                                    let uc = unconfirmed(sn)
                                    if uc > 0 { Banner(icon: "clock", text: tr("rpt.unconf", ["n": uc]), amber: true) }
                                } else if let quote {
                                    Banner(icon: "lock", text: tr(p.isFurniture ? "fd.frozen" : "q.frozen"), amber: false, tail: tr("q.issued") + ": " + fmtDate(quote.ts) + " " + fmtTime(quote.ts))
                                }
                                // the dark strip: total, pages, language
                                HStack {
                                    VStack(alignment: .leading, spacing: 0) {
                                        if design { T(dn(p.name), ui(15, 700, .white), lines: 1) } else {
                                            T(tr("rp2.total"), ui(12.5, 400, STRIP_INK))
                                            Text(Money.str(total, sn.precision, lang == .en) + " " + Money.cur(sn.currency)).st(num(22, 700, .white)).lineLimit(1)
                                                .accessibilityIdentifier("rp.total")
                                        }
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 0) {
                                        T(pages.isEmpty ? "…" : tr("rp2.pages", ["n": pages.count]), ui(12.5, 400, STRIP_INK))
                                        T(Lang.of(sn.lang).longName, ui(12.5, 400, STRIP_INK))
                                    }
                                }
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DARK))
                                TabView(selection: $page) {
                                    ForEach(0..<max(1, images.count), id: \.self) { i in
                                        Group {
                                            if i < images.count { Image(uiImage: images[i]).resizable() } else { Color.white }
                                        }
                                        .frame(width: w, height: w * PAGE_H / PAGE_W)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .boxShadow(Color(argb: 0x24101828), blur: 14, y: 2)
                                        .onTapGesture { if !images.isEmpty { viewer = i } }
                                        .accessibilityLabel(Text(tr("rp2.of", ["i": i + 1, "n": pages.count])))
                                        .accessibilityAddTraits(.isImage)
                                        .accessibilityIdentifier("rp.page")
                                        .tag(i)
                                    }
                                }
                                .tabViewStyle(.page(indexDisplayMode: .never))
                                .frame(height: w * PAGE_H / PAGE_W + 20)
                                HStack(spacing: 14) {
                                    NavIb(forward: false, on: page > 0, label: tr("rp2.prev")) { withAnimation { page -= 1 } }
                                    Text(tr("rp2.of", ["i": page + 1, "n": max(1, pages.count)])).st(num(14, 600, G.ink2))
                                    NavIb(forward: true, on: page < pages.count - 1, label: tr("rp2.next")) { withAnimation { page += 1 } }.accessibilityIdentifier("rp.next")
                                }
                                T(tr("rp2.tapZoom"), ui(12.5, 400, G.ink2), align: .center)
                            }
                            .padding(.horizontal, 16).padding(.top, 4).padding(.bottom, 120)
                        }
                    }
                    VStack {
                        Spacer()
                        FloatingFooter {
                            if design {
                                GBtn(tr("rpt.share"), icon: "share") { share(p, quote, sn, key) }.accessibilityIdentifier("rp.share")
                            } else if quote == nil {
                                HStack(spacing: 10) {
                                    GBtn(tr("rp2.shareDraft"), kind: .secondary, icon: "share") { share(p, quote, sn, key) }.accessibilityIdentifier("rp.shareDraft")
                                    GBtn(tr("rpt.issue"), icon: "lock") {
                                        let n = p.isFurniture ? 0 : rowsMissing(p)
                                        if n > 0 { app.say("et.block", ["n": n], kind: .error) } else { app.sheet = .issue(pid: p.id) }
                                    }
                                    .accessibilityIdentifier("rp.issue")
                                }
                            } else {
                                GBtn(tr("rpt.share"), icon: "share") { share(p, quote, sn, key) }.accessibilityIdentifier("rp.share")
                            }
                        }
                    }
                    if let start = viewer { PageViewer(pages: pages, start: start) { viewer = nil }.zIndex(3) }
                }
                .task(id: key + "\(Int(w))") {
                    guard w > 0 else { return }
                    let built = layout(p, quote, sn)
                    pages = built
                    images = built.compactMap { pageImage($0, width: w) }
                    if page >= built.count { page = max(0, built.count - 1) }
                    builtKey = key
                }
            }
        }
    }

    /// The simple furniture, tiler or electrician app's draft: the design, shared without a price.
    private func isDesign(_ p: Project, _ quote: Quote?) -> Bool { quote == nil && (p.isFurniture || p.isTiler || p.isElec || p.isPlumb || p.isWin) && !AppSettings.shared.advanced }

    /// The draft's snapshot; a tiler's or an electrician's design has no estimate in it.
    private func designSnap(_ p: Project, _ design: Bool) -> Snap {
        var s = snapshotOf(p)
        if design && (p.isTiler || p.isElec || p.isPlumb || p.isWin) { s.pdf.estimate = false }
        return s
    }

    /// A furniture order's quote has its own pages (furniture plan section 10).
    private func layout(_ p: Project, _ quote: Quote?, _ sn: Snap) -> [RPage] {
        let meta = quote.map { QuoteMeta(no: $0.no, ts: $0.ts) }
        return p.isFurniture ? furniturePages(sn, draft: quote == nil, meta: meta, image: viewLoader(), prices: !(quote == nil && !AppSettings.shared.advanced))
                             : reportPages(sn, draft: quote == nil, meta: meta, image: viewLoader(), design: isDesign(p, quote))
    }

    private func share(_ p: Project, _ quote: Quote?, _ sn: Snap, _ key: String) {
        guard !pages.isEmpty else { return }
        app.say("sh.making", kind: .info)
        let design = isDesign(p, quote)
        let fname = pdfName(dn(quote?.sn.name ?? p.name), quote.map { tr("q.no", ["n": $0.no]) } ?? tr(design ? "rpt.design" : "es.draft"))
        // just after a set-up change the pages on screen may be the old ones: the PDF is laid out from the report as it is
        let pg = builtKey == key ? pages : layout(p, quote, sn)
        if let url = pdfFile(pg, fname) { presentShare(url) } else { app.say("cm.shareErr", kind: .error) }
    }
}

/// A row in the estimate that still lacks a number (materials: quantity or price, labour: amount).
func rowsMissing(_ p: Project) -> Int {
    p.estimate.materials.filter { $0.qty.trimmingCharacters(in: .whitespaces).isEmpty || $0.price.trimmingCharacters(in: .whitespaces).isEmpty }.count
        + p.estimate.labor.filter { $0.amount.trimmingCharacters(in: .whitespaces).isEmpty }.count
}

private struct NavIb: View {
    let forward: Bool
    let on: Bool
    let label: String
    let action: () -> Void
    var body: some View {
        MIcon(forward ? "chev" : "back", G.ink, 18, 2.2).frame(width: 44, height: 44)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.glass(0.55)))
            .boxShadow(G.shade.opacity(0.08), blur: 20, y: 8)
            .opacity(on ? 1 : 0.35)
            .pressable(0.95, label: label) { if on { action() } }
    }
}

/// A notice above the pages (prototype .banner warn / lock).
private struct Banner: View {
    let icon: String
    let text: String
    let amber: Bool
    var action: String? = nil
    var tail: String? = nil
    var onAction: () -> Void = {}
    var body: some View {
        HStack(spacing: 10) {
            MIcon(icon, amber ? G.amberInk : G.ink, 18, 2)
            VStack(alignment: .leading, spacing: 0) {
                T(text, ui(13.5, tail == nil ? 500 : 400, G.ink, lh: 1.4))
                if let tail { T(tail, ui(13.5, 700, G.ink, lh: 1.4)) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let action {
                T(action, ui(13.5, 700, G.cobalt2)).padding(.horizontal, 10).padding(.vertical, 8).pressable(0.96, onAction)
                    .accessibilityIdentifier("rp.addBuilder")
            }
        }
        .padding(.leading, 12).padding(.trailing, 8).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(amber ? G.amberWash : G.glass(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(amber ? Color(argb: 0x33EA8C00) : G.rim, lineWidth: 1))
    }
}

/// All pages one under the other on a dark ground; + shows them at full size (prototype .viewer).
struct PageViewer: View {
    let pages: [RPage]
    let start: Int
    let onClose: () -> Void
    @State private var zoom = false
    @State private var images: [UIImage] = []
    var body: some View {
        GeometryReader { geo in
            let w = zoom ? 595 * 1.6 : geo.size.width - 24
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    T(tr("sh.pages", ["n": pages.count]), ui(15, 700, .white)).frame(maxWidth: .infinity, alignment: .leading)
                    T(zoom ? "−" : "+", ui(20, 600, .white)).frame(width: 44, height: 36)
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white, lineWidth: 1))
                        .pressable(0.95, label: zoom ? "−" : "+") { zoom.toggle() }
                        .accessibilityIdentifier("pv.zoom")
                    MIcon("x", .white, 22, 2).frame(width: 44, height: 44).pressable(0.95, label: tr("common.close"), onClose)
                        .accessibilityIdentifier("pv.close")
                }
                .padding(.horizontal, 12).frame(height: 56)
                ScrollViewReader { sr in
                    ScrollView(zoom ? [.vertical, .horizontal] : .vertical) {
                        VStack(spacing: 12) {
                            ForEach(pages.indices, id: \.self) { i in
                                Group { if i < images.count { Image(uiImage: images[i]).resizable() } else { Color.white } }
                                    .frame(width: w, height: w * PAGE_H / PAGE_W)
                                    .id(i)
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: images.count) { _, n in if n > 0 && !zoom { sr.scrollTo(start, anchor: .top) } }
                }
            }
            .background(Color(argb: 0xF00E1C36).ignoresSafeArea())
            .task(id: Int(w)) { images = pages.compactMap { pageImage($0, width: w) } }
        }
        .transition(.opacity)
    }
}

/* ---------------- sheets ---------------- */

struct ReportSheet: View {
    let app: AppModel
    let sheet: Sheet
    var body: some View {
        switch sheet {
        case .reportSetup(let pid): ReportSetupSheet(app: app, pid: pid)
        case .issue(let pid, let builderOnly): IssueSheet(app: app, pid: pid, builderOnly: builderOnly)
        default: EmptyView()
        }
    }
    static func handles(_ s: Sheet) -> Bool { switch s { case .reportSetup, .issue: return true; default: return false } }
}

private struct Chip<Content: View>: View {
    let on: Bool
    let action: () -> Void
    @ViewBuilder let content: Content
    var body: some View {
        HStack(spacing: 6) { content }
            .padding(.horizontal, 12).frame(minHeight: 40)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(on ? G.cobalt : G.glass(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(on ? G.cobalt : G.rim, lineWidth: 1))
            .pressable(0.97, action)
            .accessibilityAddTraits(on ? .isSelected : [])
    }
}

private enum SF: Hashable { case notes, name, phone }

/// Report language, rooms, notes, 3D views and the report's note (prototype SHEETS.repSetup).
private struct ReportSetupSheet: View {
    let app: AppModel
    let pid: String
    @State private var notes = ""
    @State private var loaded = false
    @FocusState private var focus: SF?
    var body: some View {
        if let p = Store.shared.get(pid) {
            GlassSheet(tr("rp2.setupTitle"), onClose: { done(p) }) {
                VStack(alignment: .leading, spacing: 8) {
                    T(tr("rpt.lang"), ui(15, 700))
                    FlowLayout(spacing: 8) {
                        ForEach(Lang.allCases) { l in
                            let on = p.reportLang == l.code
                            Chip(on: on, action: { Store.shared.update(p.id, touch: false) { $0.reportLang = l.code } }) { T(l.longName, ui(14, 600, on ? .white : G.ink)) }
                                .accessibilityIdentifier("rl." + l.code)
                        }
                    }
                }
                if !p.rooms.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        T(tr("rpt.rooms"), ui(15, 700))
                        FlowLayout(spacing: 8) {
                            ForEach(p.rooms) { r in
                                let on = p.reportRooms[r.id] != false
                                Chip(on: on, action: { Store.shared.update(p.id, touch: false) { $0.reportRooms[r.id] = !on } }) {
                                    MIcon(on ? "check" : "plus", on ? .white : G.ink, 14, 2.4); T(dn(r.name), ui(14, 600, on ? .white : G.ink))
                                }
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    T(tr("rpt.extras"), ui(15, 700))
                    let its = p.floors.flatMap { w in w.items.map { (w, $0) } }
                    if its.isEmpty { T(tr("rpt.noExtras"), ui(13.5, 400, G.ink2)) }
                    else {
                        FlowLayout(spacing: 8) {
                            ForEach(Array(its.enumerated()), id: \.offset) { _, pair in
                                let w = pair.0, it = pair.1
                                let on = it.inReport
                                Chip(on: on, action: {
                                    Store.shared.update(p.id, touch: false) { pp in
                                        if let fi = pp.floors.firstIndex(where: { $0.id == w.id }), let ii = pp.floors[fi].items.firstIndex(where: { $0.id == it.id }) { pp.floors[fi].items[ii].rep = !on }
                                    }
                                }) {
                                    MIcon(on ? "check" : "plus", on ? .white : G.ink, 14, 2.4)
                                    MIcon(it.kind == "note" ? "note" : it.kind == "photo" ? "camera" : "pen", on ? .white : G.ink2, 14, 2)
                                    T(itemName(it), ui(14, 600, on ? .white : G.ink), lines: 1)
                                }
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    T(tr("rpt.views"), ui(15, 700))
                    let views = p.rooms.flatMap(\.views)
                    // the PDF prints the first four ticked views of the rooms in the report: only those show ticked, and a fifth is refused
                    let shown = shownViews(p)
                    if views.isEmpty { T(tr("rpt.noViews"), ui(13.5, 400, G.ink2)) }
                    else {
                        T(tr("3d.inRep", ["n": shown.count]), ui(13, 400, G.ink2))
                        FlowLayout(spacing: 8) {
                            ForEach(views) { v in
                                let on = shown.contains(v.id)
                                Group {
                                    if let img = ViewFiles.load(v.img, maxW: 144) { Image(uiImage: img).resizable().scaledToFill() } else { Color.white }
                                }
                                .frame(width: 72, height: 54).clipped().opacity(on ? 1 : 0.4)
                                .padding(4)
                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 2 : 1))
                                .pressable(0.97) {
                                    if !on && shown.count >= 4 { app.say("3d.max", kind: .error) }
                                    else { Store.shared.update(p.id, touch: false) { $0.reportViews[v.id] = !on } }
                                }
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }
                }
                GField(label: tr("rpt.notes"), value: $notes, placeholder: tr("rpt.notesPh"), optional: true, focus: $focus, me: .notes, multiline: true)
                // the simple furniture app's design has no DRAFT mark
                if !((p.isFurniture || p.isTiler || p.isElec || p.isPlumb || p.isWin) && !AppSettings.shared.advanced) {
                    HStack(alignment: .top, spacing: 8) { MIcon("info", G.ink2, 18, 2); T(tr("rpt.draftShare"), ui(13, 400, G.ink2, lh: 1.45)) }
                }
            } footer: {
                GBtn(tr("rp2.done")) { done(p) }.accessibilityIdentifier("rp.done")
            }
            .onAppear { if !loaded { loaded = true; notes = p.reportNotes } }
            // closed another way (a tab, another sheet): the note is kept then too
            .onDisappear { if loaded { keep() } }
        }
    }
    private func keep() {
        guard let now = Store.shared.get(pid), notes != now.reportNotes else { return }
        let n = notes; Store.shared.update(now.id, touch: false) { $0.reportNotes = n }
    }
    private func done(_ p: Project) {
        keep()
        app.sheet = nil
    }
}

/// Issuing quote №n (prototype SHEETS.issue): first the builder's name and phone when missing, then what gets frozen,
/// the total, language and builder. builderOnly asks only for the builder (the report's banner).
private struct IssueSheet: View {
    let app: AppModel
    let pid: String
    let builderOnly: Bool
    @State private var name = ""
    @State private var phone = ""
    @State private var tried = false
    @State private var loaded = false
    @FocusState private var focus: SF?
    private var st: AppSettings { AppSettings.shared }

    var body: some View {
        if let p = Store.shared.get(pid) {
            let no = p.quotes.count + 1
            if st.builderName.trimmingCharacters(in: .whitespaces).isEmpty || builderOnly {
                let nameErr = name.trimmingCharacters(in: .whitespaces).isEmpty ? tr("bd.req") : nil
                let phoneErr = Phone.errorKey(phone, required: true).map { tr($0) }
                GlassSheet(builderOnly ? tr("rpt.builder") : tr("iss.title", ["n": no]), onClose: { app.sheet = nil }) {
                    if !builderOnly { T(tr("iss.needBuilder"), ui(15, 400, G.ink2, lh: 1.45)) }
                    GField(label: tr("bd.name"), value: $name, placeholder: tr("fr.namePh"), error: nameErr, showError: tried, focus: $focus, me: .name,
                           submit: .next, onSubmit: { focus = .phone })
                    GField(label: tr("bd.phone"), value: $phone, placeholder: "90 123 45 67", phone: true, error: phoneErr, showError: tried, focus: $focus, me: .phone)
                } footer: {
                    GBtn(tr(builderOnly ? "common.save" : "iss.saveGo")) {
                        if nameErr != nil || phoneErr != nil { tried = true; return }
                        st.saveBuilder(name, phone)
                        if builderOnly { app.sheet = nil; app.say("bd.saved") } else { app.sheet = .issue(pid: p.id) }
                    }
                    .opacity(nameErr != nil || phoneErr != nil ? 0.5 : 1)
                    .accessibilityIdentifier("bd.save")
                }
                .onAppear { if !loaded { loaded = true; name = st.builderName; phone = Phone.groups(st.builderPhone) } }
            } else {
                let tt = Money.totals(p)
                let fsn = p.isFurniture ? snapshotOf(p) : nil
                let empty = fsn.map { $0.furniture.isEmpty } ?? (p.estimate.materials.isEmpty && p.estimate.labor.isEmpty)
                let grand = fsn.flatMap { Decimal(string: $0.ftotal) } ?? tt.g
                GlassSheet(tr("iss.title", ["n": no]), onClose: { app.sheet = nil }) {
                    T(tr(p.isFurniture ? "fd.issBody" : "iss.body"), ui(15, 400, G.ink2, lh: 1.45))
                    VStack(spacing: 0) {
                        kv(tr("es.grand"), Money.of(grand, p, withCur: true), number: true)
                        Hairline(); kv(tr("rpt.lang"), Lang.of(p.reportLang).longName)
                        Hairline(); kv(tr(p.isFurniture ? "fd.maker" : "rpt.builder"), st.builderName)
                    }
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.glass(0.6)))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
                    if empty {
                        HStack(alignment: .top, spacing: 8) { MIcon("alert", G.err, 18, 2); T(tr(p.isFurniture ? "fd.empty" : "iss.empty"), ui(13.5, 500, G.err)) }
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.errWash))
                    }
                } footer: {
                    HStack(spacing: 10) {
                        GBtn(tr("common.cancel"), kind: .secondary) { app.sheet = nil }
                        GBtn(tr("rpt.issue"), icon: "lock", enabled: !empty) { issue(p, no) }.accessibilityIdentifier("iss.go")
                    }
                }
            }
        }
    }

    private func kv(_ k: String, _ v: String, number: Bool = false) -> some View {
        HStack(spacing: 10) {
            T(k, ui(14, 400, G.ink2)).frame(maxWidth: .infinity, alignment: .leading)
            T(v, number ? num(15, 700) : ui(15, 500), align: .trailing)
        }
        .padding(.vertical, 12)
    }

    private func issue(_ p: Project, _ no: Int) {
        let sn = snapshotOf(p)
        guard p.isFurniture ? !sn.furniture.isEmpty : !(p.estimate.materials.isEmpty && p.estimate.labor.isEmpty) else { return }
        let q = freezeQuote(p, sn, no, nowMs())
        Store.shared.update(p.id) { $0.quotes.append(q) }
        app.sheet = nil
        let early = p.stage == "measure" || p.stage == "estimate" || p.stage == "design"
        if p.isFurniture {
            // a furniture order: issued from the PDF or the order itself, it moves to "quote sent" and the quote opens, ready to share
            if case .report = app.top { app.pop() }
            if case .project = app.top { app.setProjectTab("quotes") }
            if early { Store.shared.update(p.id) { $0.stage = "quote" } }
            app.push(.report(pid: p.id, no: no))
            app.say(early ? "fo.issuedMoved" : "iss.done", ["n": no])
            return
        }
        app.pop()
        app.setProjectTab("quotes")
        let pid = p.id
        app.toast = early
            ? ToastMsg(text: tr("iss.done", ["n": no]) + ". " + tr("bd.stage") + ": " + tr(p.isFurniture ? "fs.quote" : "stage.quote") + "?", kind: .ok, action: tr("bd.move"),
                       onAction: { Store.shared.update(pid) { $0.stage = "quote" } })
            : ToastMsg(text: tr("iss.done", ["n": no]))
    }
}

/// The 3D views the PDF prints: the first four ticked ones of the rooms kept in the report.
func shownViews(_ p: Project) -> Set<String> {
    let inRep = p.rooms.filter { p.reportRooms[$0.id] != false }.flatMap(\.views).filter { p.reportViews[$0.id] != false }
    return Set(inRep.prefix(4).map(\.id))
}
