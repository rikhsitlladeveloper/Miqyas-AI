import Foundation

/*
 * The report's content as it stands (prototype snapshotOf + the workspace module's extras; Android report/Snapshot.kt):
 * the rooms kept in the report with their kept 3D views, each with its workspace's name in the report language; the
 * drawings, photos and notes chosen for the report; the builder, the estimate and the PDF parts.
 */
func snapshotOf(_ p: Project, _ s: AppSettings = .shared, pdf: PdfParts? = nil) -> Snap {
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
                builderName: s.builderName, builderPhone: s.builderPhone, pdf: pdf ?? s.pdf, rooms: rooms, estimate: p.estimate, extras: extras)
}

/// What decides whether the draft still matches an issued quote (prototype fingerprint): the parties, currency,
/// language, unit, notes, every room's name, measurements, openings, shape and chosen views, the estimate and the extras.
func fingerprint(_ sn: Snap) -> String {
    struct FRoom: Encodable { let name: String; let dims: [[String?]]; let openings: [Opening]; let poly: Poly?; let rot: Int; let views: [String] }
    struct FExtra: Encodable { let id: String; let edited: Ms; let name: String }
    struct F: Encodable {
        let name, customer, address, currency: String; let precision: Int; let lang, unit, notes: String
        let builder: [String]; let rooms: [FRoom]; let estimate: Estimate; let extras: [FExtra]
    }
    let f = F(name: sn.name, customer: sn.customer, address: sn.address, currency: sn.currency, precision: sn.precision, lang: sn.lang,
              unit: sn.unit, notes: sn.notes, builder: [sn.builderName, sn.builderPhone],
              rooms: sn.rooms.map { sr in
                  let r = sr.room
                  return FRoom(name: r.name, dims: r.dims.keys.sorted().map { [$0, r.dims[$0]?.v.map(String.init)] }, openings: r.openings,
                               poly: r.poly, rot: r.rot, views: r.views.map(\.id))
              },
              estimate: sn.estimate, extras: sn.extras.map { FExtra(id: $0.id, edited: $0.edited, name: $0.name) })
    let enc = JSONEncoder(); enc.outputFormatting = [.sortedKeys]
    return (try? enc.encode(f)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
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
    return Quote(no: no, ts: now, sn: frozen, fp: fingerprint(sn), total: Money.digits(snapTotal(sn)))
}

func fmtTime(_ ts: Ms) -> String {
    let c = Calendar.current.dateComponents([.hour, .minute], from: Date(timeIntervalSince1970: Double(ts) / 1000))
    return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
}
