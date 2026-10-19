import SwiftUI
import UIKit

/*
 * Photo edge measuring, parts 2 and 3 on the phone (Android ui/markup/PhotoEdgesUi.kt): the photo's edges found once when
 * it opens (in the background, on a small grey copy), drawn faintly over it; the edge or corner a line's end is stuck
 * to turns blue; a found rectangle is outlined while its offer is open.
 */

/// The grey copy of an image the edge finder works on: about EdgeFinder.work px on its long side.
func greyPixels(_ img: UIImage) -> ([Float], Int, Int)? {
    guard let cg = img.cgImage else { return nil }
    let k = CGFloat(EdgeFinder.work) / CGFloat(max(cg.width, cg.height))
    let w = max(1, Int((CGFloat(cg.width) * min(1, k)).rounded())), h = max(1, Int((CGFloat(cg.height) * min(1, k)).rounded()))
    var px = [UInt8](repeating: 0, count: w * h * 4)
    let ok: Bool = px.withUnsafeMutableBytes { buf in
        guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        return true
    }
    guard ok else { return nil }
    var g = [Float](repeating: 0, count: w * h)
    for i in 0..<(w * h) { g[i] = EdgeFinder.grey(px[i * 4], px[i * 4 + 1], px[i * 4 + 2]) }
    return (g, w, h)
}

/// The edges of a photo item's picture in its units (none if the file cannot be read).
func findEdges(_ src: String, _ outW: Float, _ outH: Float) -> PhotoEdges {
    guard let img = PhotoFiles.load(src, maxW: CGFloat(EdgeFinder.work * 2)), let gp = greyPixels(img) else { return .none }
    return EdgeFinder.find(gp.0, gp.1, gp.2, outW, outH)
}

private let EDGE_SHADE = Color(argb: 0x4D0F172A)
private let EDGE_LINE = Color(argb: 0xB8FFFFFF)
let EDGE_ON = Color(argb: 0xFF3550E0)

/// The edges over the photo, in item units: faint white lines with a thin dark shadow so they read on light and dark
/// photos, small rings at the corners; stuck edges and corners blue. ppu is screen points per item unit.
func drawPhotoEdges(_ ctx: GraphicsContext, _ e: PhotoEdges, _ ppu: CGFloat, _ stuck: [ESnap]) {
    let px = 1 / ppu
    let on = Set(stuck.flatMap(\.segs))
    for (i, s) in e.segs.enumerated() {
        let p = linePath(CGPoint(x: CGFloat(s.x1), y: CGFloat(s.y1)), CGPoint(x: CGFloat(s.x2), y: CGFloat(s.y2)))
        if on.contains(i) {
            ctx.stroke(p, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 6 * px, lineCap: .round))
            ctx.stroke(p, with: .color(EDGE_ON), style: StrokeStyle(lineWidth: 3 * px, lineCap: .round))
        } else {
            ctx.stroke(p, with: .color(EDGE_SHADE), style: StrokeStyle(lineWidth: 3 * px, lineCap: .round))
            ctx.stroke(p, with: .color(EDGE_LINE), style: StrokeStyle(lineWidth: 1.5 * px, lineCap: .round))
        }
    }
    func ring(_ x: Float, _ y: Float, _ r: CGFloat) -> Path { Path(ellipseIn: CGRect(x: CGFloat(x) - r, y: CGFloat(y) - r, width: 2 * r, height: 2 * r)) }
    for c in e.corners {
        ctx.fill(ring(c.x, c.y, 4.5 * px), with: .color(.white.opacity(0.9)))
        ctx.stroke(ring(c.x, c.y, 4.5 * px), with: .color(Color(argb: 0x730F172A)), lineWidth: 1.5 * px)
    }
    for s in stuck where s.corner {
        if let c = e.corners.first(where: { $0.a == s.a && $0.b == s.b }) { ctx.stroke(ring(c.x, c.y, 11 * px), with: .color(EDGE_ON), lineWidth: 3 * px) }
    }
}

/// The found rectangle while its offer is open (part 3): a light blue fill and a dashed blue outline.
func drawRectOffer(_ ctx: GraphicsContext, _ r: ERect, _ ppu: CGFloat) {
    let px = 1 / ppu
    var p = Path()
    for (i, q) in r.pts.enumerated() { let c = CGPoint(x: CGFloat(q.0), y: CGFloat(q.1)); if i == 0 { p.move(to: c) } else { p.addLine(to: c) } }
    p.closeSubpath()
    ctx.fill(p, with: .color(EDGE_ON.opacity(0.1)))
    ctx.stroke(p, with: .color(EDGE_ON), style: StrokeStyle(lineWidth: 2.5 * px, dash: [8 * px, 6 * px]))
}
