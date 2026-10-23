import Foundation

/*
 * The report's content as it stands (prototype snapshotOf + the workspace module's extras; Android report/Snapshot.kt):
 * the rooms kept in the report with their kept 3D views, each with its workspace's name in the report language; the
 * drawings, photos and notes chosen for the report; the builder, the estimate and the PDF parts.
 */
func snapshotOf(_ p: Project, _ s: AppSettings = .shared, pdf: PdfParts? = nil) -> Snap {
    let sn = baseSnapshot(p, s, pdf: pdf)
    if p.isFurniture { return furnSnap(sn, p, s.workshop, s.mats, s.hws) }
    if p.isElec { return withCalcRooms(elecSnap(sn, p, s.angleSnap), p) }
    if p.isPlumb { return withCalcRooms(plumbSnap(sn, p, s.angleSnap), p) }
    if p.isWin { return withCalcRooms(winSnap(sn, p, s.advanced ? s.trade.win : nil), p) }
    if p.isTiler { return tileSnap(sn, p) }
    return sn
}

/// A tiler's order's part of the snapshot: its layouts and rooms' extras, for the layout drawings.
func tileSnap(_ sn: Snap, _ p: Project) -> Snap {
    if p.tiles.isEmpty { return sn }
    var out = sn
    out.tiles = p.tiles
    out.troom = p.troom
    return out
}

/// The rooms left out of the report, so a trade's circuits, pipes and windows are worked out with every room (only the ticked ones are drawn).
func withCalcRooms(_ sn: Snap, _ p: Project) -> Snap {
    let l = Lang.of(p.reportLang)
    let out: [SnapRoom] = p.rooms.filter { p.reportRooms[$0.id] == false }.map { r in
        var rr = r
        rr.views = []
        return SnapRoom(room: rr, floorLabel: p.floors.first { $0.id == r.floorId }.map { floorName($0, l) } ?? "")
    }
    if out.isEmpty { return sn }
    var s2 = sn
    s2.calcRooms = out
    return s2
}

/// A windows-and-doors order's part of the snapshot: its products, and with prices (the advanced app) each one's price.
func winSnap(_ sn: Snap, _ p: Project, _ prices: WinPrices?) -> Snap {
    if p.win.empty { return sn }
    var cost: [String: Int64] = [:]
    if let prices {
        for (it, r) in wWithReveals(p) {
            let v = eMathRoundP(wItemCost(it, r, prices))
            cost[it.id] = v.isFinite ? Int64(min(max(v, -9e15), 9e15)) : 0
        }
    }
    var out = sn
    out.win = p.win
    out.winPrice = cost
    return out
}

/// A plumber's order's part of the snapshot: its fixtures, outlets, riser and rooms, each room's kind written down.
func plumbSnap(_ sn: Snap, _ p: Project, _ snap: Bool) -> Snap {
    if p.plumb.empty { return sn }
    var kinds: [(String, String)] = []
    for r in p.rooms { if let c = pCtxOf(p, r.id, snap) { kinds.append((r.id, c.kind)) } }
    let ids = Set(kinds.map(\.0))
    var rooms: [PlRoom] = kinds.map { k in
        var pr = p.plumb.room(k.0)
        pr.kind = k.1
        return pr
    }
    rooms += p.plumb.rooms.filter { !ids.contains($0.roomId) }
    var e = p.plumb
    e.rooms = rooms
    var out = sn
    out.plumb = e
    return out
}

/// An electrician's order's part of the snapshot: its devices, panel and rooms, each room's kind written down.
func elecSnap(_ sn: Snap, _ p: Project, _ snap: Bool) -> Snap {
    if p.elec.empty { return sn }
    var kinds: [(String, String)] = []
    for r in p.rooms { if let c = ctxOf(p, r.id, snap) { kinds.append((r.id, c.kind)) } }
    let ids = Set(kinds.map(\.0))
    var rooms: [ElecRoom] = kinds.map { k in
        var er = p.elec.room(k.0)
        er.kind = k.1
        return er
    }
    rooms += p.elec.rooms.filter { !ids.contains($0.roomId) }
    var e = p.elec
    e.rooms = rooms
    var out = sn
    out.elec = e
    return out
}

/// The handles the order's pieces have: the usual one, or those picked for a whole piece ("Change for all").
private func handleNames(_ fs: [Furniture], _ hws: [Hw]) -> String {
    let usual = usualHw(hws, "handle")
    var names: [String] = []
    for f in fs where f.modules.contains(where: { $0.handles }) {
        let own = hws.first { $0.id == f.handle && $0.kind == "handle" }
        if let n = (own ?? usual)?.name, !names.contains(n) { names.append(n) }
    }
    if names.isEmpty, let u = usual { names = [u.name] }
    return names.joined(separator: ", ")
}

/// A furniture order's part of the snapshot: the furniture, its materials, the price lines and the terms.
func furnSnap(_ sn: Snap, _ p: Project, _ ws: Workshop, _ mats: [Mat], _ hws: [Hw]) -> Snap {
    let fs = p.furniture.filter { !$0.modules.isEmpty }
    let pr = priceOf(fs, p.fprice, ws, mats, hws)
    var used = Set(fs.flatMap { [$0.mats.carcass, $0.mats.front, $0.mats.back] })
    if fs.contains(where: { $0.kind == "kitchen" }) { used.insert("wt38") }
    var out = sn
    out.furniture = fs; out.fmats = mats.filter { used.contains($0.id) }
    out.flines = pr.lines.map { SnapLine(key: $0.key, amount: Money.digits($0.amount)) }
    out.ftotal = Money.digits(pr.price); out.fprepay = ws.prepay; out.fdays = p.fprice.days; out.finst = p.fprice.inst
    out.fhandles = handleNames(fs, hws); out.fws = ws
    return out
}

private func baseSnapshot(_ p: Project, _ s: AppSettings, pdf: PdfParts?) -> Snap {
    let l = Lang.of(p.reportLang)
    let rooms: [SnapRoom] = p.rooms.filter { p.reportRooms[$0.id] != false }.map { r in
        var rr = r
        rr.views = r.views.filter { p.reportViews[$0.id] != false }
        return SnapRoom(room: rr, floorLabel: p.floors.first { $0.id == r.floorId }.map { floorName($0, l) } ?? "")
    }
    // an empty drawing has nothing to show (prototype: drawings without marks are left out)
    let extras: [SnapExtra] = p.floors.flatMap { w in
        w.items.filter { $0.inReport && !($0.kind == "drawing" && $0.els.isEmpty) }.sorted { $0.created < $1.created }.map { it in
            SnapExtra(id: it.id, kind: it.kind, name: it.name, ws: floorName(w, l), text: it.text, checks: it.checks, edited: it.edited,
                      els: it.els, src: it.src, W: it.W, H: it.H, caption: it.caption)
        }
    }
    return Snap(name: p.name, customer: p.customer, phone: p.phone, address: p.address, location: p.location,
                currency: p.currency, precision: p.precision, unit: s.unit == .cm ? "cm" : "m", lang: l.code, notes: p.reportNotes,
                builderName: s.builderName, builderPhone: s.builderPhone, pdf: pdf ?? s.pdf, rooms: rooms, estimate: p.estimate, extras: extras,
                snap: s.angleSnap, industry: p.industry)
}

/// What decides whether the draft still matches an issued quote (prototype fingerprint): the parties, currency,
/// language, unit, notes, every room's name, measurements, openings, columns and niches, site points, shape and chosen
/// views, the estimate and the extras. The parts added later (columns and niches, site points, the customer's phone, the
/// angle snap, a furniture order's prepayment and printed handles) are only there when set or not the first default, so
/// a quote issued before them still matches its unchanged draft.
func fingerprint(_ sn: Snap) -> String {
    struct FRoom: Encodable {
        let name: String; let dims: [[String?]]; let openings: [Opening]; let poly: Poly?; let rot: Int; let views: [String]
        var features: [Feature]? = nil, points: [SitePoint]? = nil
    }
    struct FExtra: Encodable { let id: String; let edited: Ms; let name: String }
    struct F: Encodable {
        let name, customer, address, currency: String; let precision: Int; let lang, unit, notes: String
        let builder: [String]; let rooms: [FRoom]; let estimate: Estimate; let extras: [FExtra]
        /// furniture orders only (a builder's fingerprint stays as it was)
        var furniture: [Furniture]? = nil, ftotal: String? = nil, fdays: Int? = nil, finst: Int? = nil, fmats: [Mat]? = nil
        var phone: String? = nil, snap: Bool? = nil
        var pp: Int? = nil, hd: String? = nil
        /// electricians' orders only
        var el: ElecOrder? = nil
        /// plumbers' orders only
        var pl: PlumbOrder? = nil
        /// windows-and-doors orders only: the products and each one's price
        var dw: WinOrder? = nil, dwp: [String: Int64]? = nil
        /// trades' orders with rooms left out of the report: those rooms (the tile layouts are not in it: tilers' quotes
        /// issued before the layout drawings still match, their estimate follows the layouts)
        var cr: [Room]? = nil
    }
    let f = F(name: sn.name, customer: sn.customer, address: sn.address, currency: sn.currency, precision: sn.precision, lang: sn.lang,
              unit: sn.unit, notes: sn.notes, builder: [sn.builderName, sn.builderPhone],
              rooms: sn.rooms.map { sr in
                  let r = sr.room
                  return FRoom(name: r.name, dims: r.dims.keys.sorted().map { [$0, r.dims[$0]?.v.map(String.init)] }, openings: r.openings,
                               poly: r.poly, rot: r.rot, views: r.views.map(\.id),
                               features: r.features.isEmpty ? nil : r.features, points: r.points.isEmpty ? nil : r.points)
              },
              estimate: sn.estimate, extras: sn.extras.map { FExtra(id: $0.id, edited: $0.edited, name: $0.name) })
    var g = f
    if !sn.furniture.isEmpty { g.furniture = sn.furniture; g.ftotal = sn.ftotal; g.fdays = sn.fdays; g.finst = sn.finst; g.fmats = sn.fmats }
    if !sn.phone.isEmpty { g.phone = sn.phone }
    if !sn.snap { g.snap = false }
    if !sn.furniture.isEmpty && sn.fprepay != 50 { g.pp = sn.fprepay }
    // the handle the workshop's list starts with fingerprints as before handles were printed
    let handlesPrinted = !sn.fhandles.trimmingCharacters(in: .whitespaces).isEmpty && sn.furniture.contains(where: { $0.modules.contains(where: \.handles) })
    if handlesPrinted && sn.fhandles != "Tutqich skoba 128" { g.hd = sn.fhandles }
    if let e = sn.elec { g.el = e }
    if let e = sn.plumb { g.pl = e }
    if let e = sn.win { g.dw = e; g.dwp = sn.winPrice }
    if !sn.calcRooms.isEmpty { g.cr = sn.calcRooms.map(\.room) }
    let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
    return (try? enc.encode(g)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
}

/// Grand total of a snapshot (for the quote's record and the dark strip).
func snapTotal(_ sn: Snap) -> Decimal {
    var g: Decimal = 0
    for r in sn.estimate.materials { g += Money.line(r.qty, r.price, sn.precision) }
    for r in sn.estimate.labor { if let v = Money.parse(r.amount, sn.precision).value { g += v } }
    return g
}

/// Measurements still waiting for confirmation in the report's rooms (prototype unconfCount over sn.rooms).
func unconfirmed(_ sn: Snap) -> Int { sn.rooms.reduce(0) { $0 + Geo.unconfCount($1.room) } }

/// The PDF's file name (prototype A.share): project name and "Qoralama" or "Taklif №n", no awkward characters.
func pdfName(_ name: String, _ suffix: String) -> String {
    (name + "_" + suffix).replacingOccurrences(of: "[\\s,№./\\\\:*?\"<>|]+", with: "_", options: .regularExpression) + ".pdf"
}

/// Freezes the report as quote № no: the 3D pictures and photos are copied next to the quote, so removing a view later
/// from the room (or the room itself, or a photo) leaves the issued quote as it was.
func freezeQuote(_ p: Project, _ sn: Snap, _ no: Int, _ now: Ms) -> Quote {
    let dir = "quotes/\(p.id)-\(no)"
    let fm = FileManager.default
    try? fm.createDirectory(at: ViewFiles.file(dir), withIntermediateDirectories: true)
    func copy(_ src: String, _ dst: String) {
        try? fm.removeItem(at: ViewFiles.file(dst))
        try? fm.copyItem(at: ViewFiles.file(src), to: ViewFiles.file(dst))
    }
    var frozen = sn
    frozen.rooms = sn.rooms.map { sr in
        var s2 = sr
        s2.room.views = sr.room.views.map { v in var v2 = v; v2.img = "\(dir)/\(v.id).jpg"; copy(v.img, v2.img); return v2 }
        return s2
    }
    // the photos too, so a photo deleted or changed later leaves the quote as it was issued
    frozen.extras = sn.extras.map { x in
        guard let src = x.src else { return x }
        var x2 = x; x2.src = "\(dir)/ph-\(x.id).jpg"; copy(src, x2.src!)
        return x2
    }
    return Quote(no: no, ts: now, sn: frozen, fp: fingerprint(sn), total: sn.furniture.isEmpty ? Money.digits(snapTotal(sn)) : sn.ftotal)
}

func fmtTime(_ ts: Ms) -> String {
    let c = Calendar.current.dateComponents([.hour, .minute], from: Date(timeIntervalSince1970: Double(ts) / 1000))
    return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
}

extension SnapExtra {
    /// The extra as the item it was, for drawing it.
    func asItem() -> Item {
        var it = Item(id: id, kind: kind, name: name, edited: edited)
        it.text = text; it.checks = checks; it.els = els; it.src = src; it.W = W; it.H = H; it.caption = caption
        return it
    }
}
