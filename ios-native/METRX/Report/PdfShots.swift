import UIKit

/*
 * The furniture PDF's own 3D pictures (founder 29 Oct 2026): every piece gets a picture of itself, made by the gallery
 * cards' hidden 3D (Three/CardShots.swift) from the cards' 3/4 angle a little from above, a piece in a measured room
 * with that room's floor and walls. A piece whose room has a view the maker saved ("Hisobotga qo‘shish") shows that
 * view instead, as before. Without the lit 3D (the flat tier, the Simulator, no picture within a few seconds) the
 * piece is drawn as on the gallery's cards. Small JPEGs (about 560 × 420 px), kept in memory by what they are made of;
 * the report page asks for them (ReportScreen.swift) and lays the pages out again once they are in.
 */

/// The picture's size: 280 × 210 pt at 2×, two to a row on the A4 page.
let PDF_SHOT_SPEC = CardSpec(pt: CGSize(width: 280, height: 210), scale: 2)

/// The pieces of sn's PDF that get a picture made: with the 3D views on, the ones whose room has no saved view (a
/// room-less piece, a room never pictured).
func pdfShotPieces(_ sn: Snap) -> [Furniture] {
    guard sn.pdf.views else { return [] }
    return sn.furniture.filter { f in
        guard let rid = f.roomId, let r = sn.rooms.first(where: { $0.room.id == rid })?.room else { return true }
        return r.views.isEmpty
    }
}

/// The measured room piece f stands in, from the snapshot (nil: room-less, or its room is not in it).
func pdfShotRoom(_ f: Furniture, _ sn: Snap) -> Room? {
    guard let rid = f.roomId else { return nil }
    return sn.rooms.first { $0.room.id == rid }?.room
}

/// The pictures. Use it on the main thread.
final class PdfShots {
    static let shared = PdfShots()
    private var pics: [String: UIImage] = [:]
    private var order: [String] = []
    /// Two lit pictures in a row did not come: the rest of this session's are drawn.
    private var broken = false

    /// What f's picture in sn is made of: the piece, its room, the boards, the workshop, the quality.
    func key(_ f: Furniture, _ sn: Snap, _ tier: Quality3) -> String {
        let room = pdfShotRoom(f, sn).map { cardSig($0) } ?? "-"
        return [cardSig(f), room, cardSig(sn.fmats), cardSig(sn.fws ?? Workshop()), tier.rawValue].joined(separator: "|")
    }

    /// f's picture for sn, when it was made.
    func image(_ f: Furniture, _ sn: Snap) -> UIImage? { pics[key(f, sn, Quality3.current())] }

    /// Makes the pictures sn's PDF still lacks, one at a time; true when any was made (lay the pages out again).
    @MainActor func prepare(_ sn: Snap) async -> Bool {
        let tier = Quality3.current()
        var made = false
        for f in pdfShotPieces(sn) {
            if Task.isCancelled { break }
            let k = key(f, sn, tier)
            if pics[k] != nil { continue }
            guard let img = await shoot(f, sn, tier) else { continue }
            keep(k, img)
            made = true
        }
        return made
    }

    private func keep(_ k: String, _ img: UIImage) {
        pics[k] = img
        order.removeAll { $0 == k }
        order.append(k)
        // a few orders' pictures, not every one ever made
        while order.count > 24 { pics[order.removeFirst()] = nil }
    }

    /// The lit 3D picture (in its room when it has one), else the drawn one; as a small JPEG.
    @MainActor private func shoot(_ f: Furniture, _ sn: Snap, _ tier: Quality3) async -> UIImage? {
        let ws = sn.fws ?? Workshop(), mats = sn.fmats, spec = PDF_SHOT_SPEC
        var img: UIImage? = nil
        if tier != .flat && !broken {
            img = await lit(f, pdfShotRoom(f, sn), ws, mats, spec, tier)
            if img == nil { fails += 1; if fails >= 2 { broken = true } } else { fails = 0 }
        }
        if img == nil { img = await Task.detached(priority: .userInitiated) { cardPainted(f, ws, mats, spec) }.value }
        guard let shot = img else { return nil }
        let fitted = cardFit(shot, spec)
        guard let data = fitted.jpegData(compressionQuality: 0.78) else { return fitted }
        return UIImage(data: data) ?? fitted
    }
    private var fails = 0

    /// The hidden 3D's picture of f, or nil when none came within 5 s.
    @MainActor private func lit(_ f: Furniture, _ room: Room?, _ ws: Workshop, _ mats: [Mat], _ spec: CardSpec, _ tier: Quality3) async -> UIImage? {
        let snap = AppSettings.shared.angleSnap
        return await withCheckedContinuation { (k: CheckedContinuation<UIImage?, Never>) in
            let once = PdfShotOnce()
            let finish: (UIImage?) -> Void = { img in
                DispatchQueue.main.async {
                    if once.over { return }
                    once.over = true
                    k.resume(returning: img)
                }
            }
            if let room, Geo.ready3D(room, snap) {
                CardRenderer.shared.renderRoom([f], room, ws, mats, spec, tier, snap: snap, finish)
            } else {
                CardRenderer.shared.render(f, ws, mats, spec, tier, finish)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { finish(nil) }
        }
    }
}

/// Whether a picture's wait is over (it came, or the time ran out): the first of the two wins.
private final class PdfShotOnce { var over = false }
