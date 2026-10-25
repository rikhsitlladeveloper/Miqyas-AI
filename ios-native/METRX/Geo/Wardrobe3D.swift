import Foundation

/*
 * Wardrobes in the modern 3D ("modern furniture 3D" part 5, 25 Oct 2026; the approved mockup's buildKupe and kupeDoor):
 * a sliding door's aluminium profiles in the handle colour with a split rail on a tall door, its fillings (the front
 * board in its style, the upper fronts' above the split, a mirror in its tint, lacobel), the tracks; inside, chrome
 * rails and the LED under the hat shelf with its glow down the back; round metal legs; the cornice or a row of units up
 * to the ceiling over a tall box. Every cabinet built by the wardrobe engine (hinged wardrobes, kupe, stenka, vitrina,
 * office, kids', bathroom) goes through FBuilder.wardrobe in Furniture3D.swift; its hinged doors, glass doors and
 * handles are the kitchen's (Kitchen3D.swift: frontBody, glassDoor, handle). The 2D drawings (detail .flat) still get
 * boxes only, a weak phone no glow. Sizes in millimetres (the wall's frame) or metres (a front's own frame).
 */

/* ---------------- rules (plain, unit-tested: Wardrobe3DTests) ---------------- */

/// A sliding door's profiles, mm (mockup kupeDoor): the uprights' width and the profile's depth, the top and bottom
/// rails' heights, the split rail's.
let KUPE_PW = 42.0
let KUPE_PD = 35.0
let KUPE_RT = 30.0
let KUPE_RB = 50.0
let KUPE_SR = 14.0
/// (Where the split rail goes, the price's rule too: Core/Wardrobe.swift kupeSplit, KUPE_SPLIT_TOP, KUPE_SPLIT_MIN.)
/// The tracks along the opening: the top one's and the bottom one's height, mm.
let KUPE_TRACK_TOP = 20.0
let KUPE_TRACK_LOW = 12.0
/// A box takes a cornice or a row up to the ceiling only from this tall (its top above the floor), mm.
let WARD_CROWN_MIN = 1800

/// The looks a sliding door is filled with, its panel (Slide.panel; middleFill decides the middle door's: "mirror",
/// "glass" lacobel, "ldsp" the front board): below the split (or all of it), and above the split, always the upper
/// fronts' board (mockup kupeDoor; nil without a split).
func kupeFills(_ panel: String, split: Bool) -> (low: String, up: String?) {
    let low = panel == "mirror" ? "mirror" : panel == "glass" ? "lacobel" : "front"
    return (low, split ? "frontUp" : nil)
}

/// Where a section's LED strip goes, mm above the section's floor (the strip's top): under the shelf over its highest
/// rail (the hat shelf, as the mockup lights it), else under the top panel (ih, the inside's height).
func secLedY(_ s: Section, _ ih: Int) -> Int {
    guard let r = s.inserts.filter({ $0.kind == "rail" }).map(\.pos).max() else { return ih }
    return s.inserts.filter { ($0.kind == "shelf" || $0.kind == "glass") && $0.pos > r }.map(\.pos).min() ?? ih
}

/// How many mm crown ("cornice", "ceiling"; crownOf) adds over a box whose top is top mm up in a room ceil mm high: the
/// cornice's three layers (CORNICE_LAYERS, 76) when they fit under the ceiling, the row up to the ceiling (ceilRowH);
/// 0 for a low box (under WARD_CROWN_MIN) or no crown.
func wardCrown(_ crown: String, _ top: Int, _ ceil: Int) -> Int {
    guard top >= WARD_CROWN_MIN else { return 0 }
    switch crown {
    case "cornice":
        let h = Int(CORNICE_LAYERS.reduce(0.0) { $0 + $1.h }.rounded())
        return top + h <= ceil ? h : 0
    case "ceiling": return ceilRowH(top, ceil)
    default: return 0
    }
}

/* ---------------- shapes ---------------- */

extension FBuilder {
    /// A sliding door a mm along the wall, its bottom y up, its back n0 out, dw × dh (mm): the profiles in the frame's
    /// look (the handle colour, aluminium without one), the split rail sp mm up the door (Core/Wardrobe.swift kupeSplit;
    /// nil none), its fillings (kupeFills).
    func kupeDoor(_ w: WallBasis, _ a: Double, _ y: Double, _ n0: Double, _ dw: Double, _ dh: Double, _ panel: String, _ sp: Double?) {
        let f = FFrame(o: w.at(a / 1000, y / 1000, n0 / 1000), e: w.dir(1, 0), u: V3(0, 1, 0), n: w.dir(0, 1))
        let pm = p("frame"), W = dw / 1000, H = dh / 1000
        let pw = KUPE_PW / 1000, pd = KUPE_PD / 1000, rt = KUPE_RT / 1000, rb = KUPE_RB / 1000
        guard W > 2 * pw + 0.01, H > rt + rb + 0.01 else { fbox(pm, f, 0, 0, 0, W, H, pd, true); return }
        fbox(pm, f, 0, 0, 0, pw, H, pd, true); fbox(pm, f, W - pw, 0, 0, pw, H, pd, true)
        fbox(pm, f, pw, H - rt, 0.004, W - 2 * pw, rt, pd - 0.008, true); fbox(pm, f, pw, 0, 0.004, W - 2 * pw, rb, pd - 0.008, true)
        let fills = kupeFills(panel, split: sp != nil)
        let fw = W - 2 * pw, fz = 0.008
        if let sp {
            let s = sp / 1000, sr = KUPE_SR / 1000
            fbox(pm, f, pw, s - sr / 2, 0.006, fw, sr, pd - 0.012, true)
            kupeFill(f, fills.low, pw, rb, fw, s - sr / 2 - rb, fz)
            kupeFill(f, fills.up ?? fills.low, pw, s + sr / 2, fw, H - rt - s - sr / 2, fz, panel == "ldsp" ? "fp.slidePanel" : "fp.slideUp")
        } else {
            kupeFill(f, fills.low, pw, rb, fw, H - rt - rb, fz)
        }
    }

    /// One filling of a sliding door in its frame f, from (a, y) W × H metres, its back z out: a mirror or lacobel pane,
    /// else the board (front or frontUp) in the piece's front style.
    private func kupeFill(_ f: FFrame, _ key: String, _ a: Double, _ y: Double, _ W: Double, _ H: Double, _ z: Double, _ part: String = "fp.slidePanel") {
        guard W > 0.01, H > 0.01 else { return }
        let ff = FFrame(o: f.at(a, y, z), e: f.e, u: f.u, n: f.n)
        if key == "mirror" || key == "lacobel" { fbox(p(key), ff, 0, 0, 0, W, H, 0.006, true); return }
        frontBody(role("front", part, look: key), ff, W, H, Double(t) / 1000)
    }

    /// The tracks of sliding doors along an opening a0…a1, from y0 (its bottom) to y1 (its top), in front of the inside
    /// to dd (mm), in the profiles' look.
    func kupeTracks(_ w: WallBasis, _ a0: Double, _ a1: Double, _ y0: Double, _ y1: Double, _ dd: Double) {
        let fr = p("frame"), n0 = dd - Double(SLIDE_D) + 2, n1 = dd - 10
        box(w, fr, a0, a1, y1 - KUPE_TRACK_TOP, y1, n0, n1, true)
        box(w, fr, a0, a1, y0, y0 + KUPE_TRACK_LOW, n0, n1, true)
    }

    /// A hanging rail across a section il…il+iw at y, half way into the inside's depth di (mm): a chrome tube on two
    /// holders (mockup M.steel); a box in the 2D drawings.
    func hangRail(_ w: WallBasis, _ il: Double, _ iw: Double, _ y: Double, _ di: Double) {
        let c = p("chrome")
        guard fancy else { box(w, c, il + 5, il + iw - 5, y - 12, y + 12, di / 2 - 12, di / 2 + 12); return }
        let n = di / 2000
        tube(c, w.at((il + 2) / 1000, y / 1000, n), w.at((il + iw - 2) / 1000, y / 1000, n), 0.0095)
        for a in [il + 2, il + iw - 8] { box(w, c, a, a + 6, y - 14, y + 14, di / 2 - 14, di / 2 + 14) }
    }

    /// A box's legs: a pair under each side and divider at xs (each 36 wide from there), the box's bottom at z0, dd deep
    /// (mm): round, tapering down, in the legs' look (the handle colour); square in the 2D drawings.
    func wardLegs(_ w: WallBasis, _ xs: [Double], _ z0: Double, _ dd: Double) {
        let lg = p("legs")
        for q in xs {
            let a = q + 18
            for n in [58.0, dd - 58] {
                if fancy { tube(lg, w.at(a / 1000, 0, n / 1000), w.at(a / 1000, (z0 - 1) / 1000, n / 1000), 0.013, 0.016) }
                else { box(w, lg, q, q + 36, 0, z0, n - 18, n + 18) }
            }
        }
    }

    /// A section's LED a0…a1 whose strip's top is at y, near the front of the inside di (mm): the glowing strip and, on a
    /// strong phone, its light down the back panel to no lower than low.
    func secLed(_ w: WallBasis, _ a0: Double, _ a1: Double, _ y: Double, _ di: Double, _ low: Double) {
        guard a1 - a0 > 60 else { return }
        box(w, p("led"), a0 + 20, a1 - 20, y - 8, y, di - 60, di - 48)
        glowDown(w, a0 + 10, a1 - 10, y - 8, 3, min(420, y - 8 - low))
    }

    /// A LED's soft light on an upright face n0 out (mm) under it: three faint planes a0…a1 from y1 down H, the brightest
    /// at the top (mockup glow). None on a weak phone or in the 2D drawings.
    func glowDown(_ w: WallBasis, _ a0: Double, _ a1: Double, _ y1: Double, _ n0: Double, _ H: Double) {
        guard detail == .high, H > 40, a1 - a0 > 20 else { return }
        let g = p("glow"), A0 = a0 / 1000, A1 = a1 / 1000, Y1 = y1 / 1000
        for (k, f) in [1.0, 0.62, 0.3].enumerated() {
            let n = (n0 + 0.6 + Double(k)) / 1000, Y0 = (y1 - H * f) / 1000
            face(g, [w.at(A0, Y0, n), w.at(A1, Y0, n), w.at(A1, Y1, n), w.at(A0, Y1, n)], w.at((A0 + A1) / 2, (Y0 + Y1) / 2, n - 0.01), w.dir(1, 0))
        }
    }

    /// The crown over box m (x0…x1, its top at yt, dd deep; mm): the cornice's three layers in the upper fronts' board,
    /// standing out at the front and at a free end (mockup buildKupe); or a row of units up to the ceiling with lift-up
    /// fronts over the doors under them (one over each sliding door, the handles at the bottom; none on a sliding wardrobe).
    func crownOver(_ w: WallBasis, _ m: Module, _ x0: Double, _ x1: Double, _ yt: Double, _ dd: Double) {
        let pu = p("frontUp")
        if crown == "cornice" {
            var y = yt
            for l in CORNICE_LAYERS {
                box(w, pu, x0 - (freeL ? l.out : 0), x1 + (freeR ? l.out : 0), y, y + l.h, 0, dd + l.out, true)
                y += l.h
            }
            return
        }
        let hh = Double(wardCrown(crown, Int(yt.rounded()), ceilH))
        guard hh > 0 else { return }
        box(w, pu, x0, x1, yt, yt + hh, 0, dd, true)
        if bare { return }
        var spans: [(Double, Double)] = []
        if let sl = m.slide {
            let n = min(4, max(2, sl.n)), wd = (x1 - x0) / Double(n)
            for j in 0..<n { spans.append((x0 + wd * Double(j), x0 + wd * Double(j + 1))) }
        } else {
            var a = x0
            for s in m.sections {
                let k = s.fronts.kind == "door" ? max(1, s.fronts.n) : 1, wd = Double(s.w) / Double(k)
                for j in 0..<k { spans.append((a + wd * Double(j), a + wd * Double(j + 1))) }
                a += Double(s.w)
            }
        }
        let hd = m.handles && m.slide == nil
        for (i, sp) in spans.enumerated() {
            let s0 = sp.0 + (i == 0 ? edge : g / 2), s1 = sp.1 - (i == spans.count - 1 ? edge : g / 2)
            guard s1 - s0 > 40 else { continue }
            staticFront(w, pu, s0, yt + g / 2, s1 - s0, hh - g, dd, hd, "flap", .bottom)
        }
    }
}
