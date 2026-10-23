import Foundation

/*
 * Part labels (bazis ideas, 23 Oct 2026; Advanced only; Android furniture/Labels.kt): one sticker for every part of an
 * order, 3 × 8 to an A4 sheet of 70 × 37 mm stickers: the part's name and size, which edges are banded, the material,
 * the order and an optional QR code with the part's id. Unit-tested (BazisTests); the pages are drawn in
 * Report/LabelPages.swift.
 */

/// Stickers across and down an A4 sheet.
let LABEL_COLS = 3
let LABEL_ROWS = 8
let LABELS_PER_PAGE = LABEL_COLS * LABEL_ROWS

/// One sticker: n its number in the order (from 1), the part's name key, mod the module it belongs to (its label,
/// "Sh1/2"), piece the piece's name, finished L × W, its bands, material id mat, grain kept upright.
struct PartLabel: Equatable {
    let n: Int, key: String, mod: String, piece: String, L: Int, W: Int, bands: Bands, mat: String, grain: Bool
}

/// A sticker per part of fs (each of a line's pieces its own), piece by piece and module by module.
func labelsOf(_ fs: [Furniture], _ ws: Workshop) -> [PartLabel] {
    var out: [PartLabel] = []
    for f in fs {
        let fws = wsOf(f, ws)
        var parts: [FPart] = []
        for m in f.modules { parts += partsOf(m, fws) }
        parts += extrasParts(f, ws)
        for p in parts {
            for _ in 0..<max(0, p.qty) {
                out.append(PartLabel(n: out.count + 1, key: p.key, mod: p.mod, piece: f.name, L: p.L, W: p.W, bands: p.bands,
                                     mat: matFor(p.role, f.mats), grain: p.grain))
            }
        }
    }
    return out
}

/// How many A4 sheets n stickers take.
func labelPages(_ n: Int) -> Int { (n + LABELS_PER_PAGE - 1) / LABELS_PER_PAGE }

/// Where sticker i (from 0) goes: its page, column and row.
func labelSlot(_ i: Int) -> (page: Int, col: Int, row: Int) {
    (i / LABELS_PER_PAGE, i % LABELS_PER_PAGE % LABEL_COLS, i % LABELS_PER_PAGE / LABEL_COLS)
}

/// The id a sticker's QR code carries: the order's short id and the sticker's number ("MX-4f2a9c-017").
func labelId(_ order: String, _ n: Int) -> String {
    let short = String(order.filter { $0.isLetter || $0.isNumber }.prefix(6))
    var num = String(n)
    while num.count < 3 { num = "0" + num }
    return "MX-" + short + "-" + num
}
