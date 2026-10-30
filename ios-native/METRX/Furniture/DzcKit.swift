import SwiftUI
import UIKit
import Observation

/*
 * Designer C's shared parts (founder-approved 27 Oct 2026; design/designer-c/mockup.html): the editing state, the
 * drawing's zoom and pan, the touch layer (a tap selects, a second tap a front; about 0.4 s held lifts a unit to move it;
 * a quick drag pans, two fingers zoom, a double tap fits), the Canva-style tool slider and its options rows, the red
 * delete zone, the caption, the "?" hint and the number sheet. The kitchen's and the wardrobe's designers are
 * DzcKitchen.swift and DzcWard.swift; the rules Furniture/Core/DzcRules.swift.
 */

/* ---------------- the state ---------------- */

/// The drawing's zoom (1: fitted) and pan, screen points.
struct DzcCam: Equatable {
    var z: CGFloat = 1
    var dx: CGFloat = 0
    var dy: CGFloat = 0
    var fit: Bool { z == 1 && dx == 0 && dy == 0 }
}

/// A gesture on the drawing in progress: resizing a unit's right edge (or a section's), a wall unit's bottom edge, a
/// lifted unit being moved, a pan or a pinch.
struct DzcLive {
    var kind = ""
    var mid = ""
    var sec = -1
    /// The furniture as it would be (packed), drawn instead of the saved one.
    var preview: Furniture? = nil
    /// Resize: the new width, who takes the difference and its widths, the candidates, the edge pulled past the widest.
    var w = 0
    var taker: String? = nil
    var takerSec = -1
    /// The taker is on the left (nothing on the right could give).
    var tleft = false
    var tw0 = 0
    var tw1 = 0
    var cands: [Int] = []
    var maxHit = false
    var h = 0
    /// Move: where the lifted unit's left edge is (mm along the run), where it was grabbed, the place it would drop
    /// into, and whether it is over the delete zone.
    var gx = 0
    var grab = 0
    var slot = -1
    var slot0 = -1
    var overDel = false
    /// Pan and pinch: the camera when it began and the pinch's first centre.
    var cam0 = DzcCam()
    var c0: CGPoint = .zero
}

/// A catalogue tile being dragged up onto the wall: the finger on the screen.
struct DzcTileDrag {
    let tile: DzcTile
    var pt: CGPoint
}

/// Designer C's editing state, shared by the kitchen and the wardrobe designers (the selected unit itself is
/// KitOps.sel, as before: a kitchen's unit, a piece's box).
@Observable
final class DzcState {
    static let shared = DzcState()
    /// The selected front's key (HandleRules.swift: "f0", "s1:f0"), nil the whole unit or section.
    var front: String? = nil
    /// A wardrobe's selected section, -1 none.
    var sec = -1
    /// The open tool's options row, nil the slider.
    var tool: String? = nil
    /// "Faqat shu" / "Shu qatorga" / "Butun oshxonaga" ("one", "row", "all").
    var scope = "one"
    /// Belgilash: several units (ids; a wardrobe's sections as "s<i>").
    var multi = false
    var ticks: Set<String> = []
    /// The selected unit's doors open ("Ichki"); every door open ("Ichini ko‘rish").
    var peek = false
    var inside = false
    /// The catalogue's category.
    var cat = "door"
    var live: DzcLive? = nil
    var tile: DzcTileDrag? = nil
    var cams: [String: DzcCam] = [:]
    /// The checks' callouts made small.
    var callMin = false
    /// The gesture hint is showing, since t0.
    var teachOn = false
    var teachT0 = Date()
    /// The piece being designed (a new one starts clean).
    @ObservationIgnored var fid = ""
    @ObservationIgnored var lastTap: (t: Date, p: CGPoint)? = nil
    /// The drawing's and the delete zone's frames on the screen.
    @ObservationIgnored var canvasFrame: CGRect = .zero
    @ObservationIgnored var delFrame: CGRect = .zero
    /// The drawing's last mapping and its scene, for a tile dropped from the slider.
    @ObservationIgnored var map: DzcMap? = nil
    /// While a unit is lifted: where each unit of the row is drawn now (mm), easing towards its place (the others slide aside).
    @ObservationIgnored var disp: [String: CGFloat] = [:]
    @ObservationIgnored var mapScene = ""

    var taught: Bool {
        get { UserDefaults.standard.bool(forKey: "dzc.taught") }
        set { UserDefaults.standard.set(newValue, forKey: "dzc.taught") }
    }

    /// Another piece opened: nothing selected, the slider back, the drawing fitted.
    func enter(_ id: String) {
        if fid == id { return }
        fid = id
        clear()
        cams = [:]
        callMin = false
    }

    func clear() {
        front = nil; sec = -1; tool = nil; scope = "one"; multi = false; ticks = []; peek = false; inside = false; live = nil; tile = nil
    }

    func startTeach() { teachT0 = Date(); teachOn = true; taught = true }
}

/* ---------------- the drawing's mapping ---------------- */

/// Where the drawing (a KLay viewBox) is on the screen: fitted into the canvas between its top and bottom insets, then
/// zoomed and panned by cam.
struct DzcMap {
    let lay: KLay
    let k0: CGFloat
    let k: CGFloat
    let fx: CGFloat
    let fy: CGFloat
    let ox: CGFloat
    let oy: CGFloat
    let z: CGFloat
    /// A wall-hung box drawn at its real height: its bottom this far over the floor, mm (the box's own mm stay from its
    /// bottom; the layout's floor is lift under it).
    let lift: Int
    init(_ lay: KLay, _ size: CGSize, _ cam: DzcCam, top: CGFloat, bottom: CGFloat, lift: Int = 0) {
        self.lay = lay
        self.lift = max(0, lift)
        let aw = max(40, size.width - 16), ah = max(40, size.height - top - bottom)
        let kk = min(aw / lay.vw, ah / lay.vh)
        k0 = kk
        z = cam.z
        k = kk * cam.z
        fx = (size.width - lay.vw * kk) / 2
        fy = top + (ah - lay.vh * kk) / 2
        ox = fx + cam.dx
        oy = fy + cam.dy
    }
    /// mm along the drawing → screen x; mm up → screen y.
    func sx(_ mm: Int) -> CGFloat { ox + lay.x(mm) * k }
    func sy(_ mm: Int) -> CGFloat { oy + lay.y(mm + lift) * k }
    func sxD(_ mm: Double) -> CGFloat { ox + (lay.x0 + CGFloat(mm) * lay.s) * k }
    /// A screen point → mm along and up.
    func mmX(_ px: CGFloat) -> Int { Int((((px - ox) / k) - lay.x0) / lay.s) }
    func mmY(_ py: CGFloat) -> Int { Int((lay.yF - (py - oy) / k) / lay.s) - lift }
    /// Screen points a millimetre.
    var pxPerMm: CGFloat { lay.s * k }
    /// Zoomed in past DZC_FINE_ZOOM: 10 mm steps.
    var fine: Bool { z > DZC_FINE_ZOOM }
}

/// The camera zoomed by scale about screen point c (c0 where the pinch began) from cam0, the map fitted at fx, fy.
func dzcPinched(_ cam0: DzcCam, _ scale: CGFloat, _ c0: CGPoint, _ c: CGPoint, _ map: DzcMap) -> DzcCam {
    let z1 = min(6, max(0.7, cam0.z * scale))
    var cam = DzcCam()
    cam.z = z1
    cam.dx = c.x - map.fx - (c0.x - map.fx - cam0.dx) * (z1 / cam0.z)
    cam.dy = c.y - map.fy - (c0.y - map.fy - cam0.dy) * (z1 / cam0.z)
    return cam
}

/* ---------------- the touch layer ---------------- */

/// What the drawing's touches do (points in the drawing's own space; win the same point on the screen).
struct DzcTouchActions {
    var tap: (CGPoint) -> Void = { _ in }
    var panBegan: (CGPoint) -> Void = { _ in }
    var panMoved: (CGPoint, CGSize) -> Void = { _, _ in }
    var panEnded: (Bool) -> Void = { _ in }
    var longBegan: (CGPoint) -> Void = { _ in }
    var longMoved: (CGPoint, CGPoint) -> Void = { _, _ in }
    var longEnded: (CGPoint, Bool) -> Void = { _, _ in }
    var pinch: (UIGestureRecognizer.State, CGFloat, CGPoint) -> Void = { _, _, _ in }
}

/// The UIKit recognizers under the drawing: a tap, a long press of 0.4 s, a one-finger pan and a pinch, together.
final class DzcTouchView: UIView, UIGestureRecognizerDelegate {
    var act = DzcTouchActions()
    private var longOn = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(onTap(_:)))
        let long = UILongPressGestureRecognizer(target: self, action: #selector(onLong(_:)))
        long.minimumPressDuration = 0.4
        long.allowableMovement = 10
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        pan.maximumNumberOfTouches = 1
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
        for g in [tap, long, pan, pinch] as [UIGestureRecognizer] { g.delegate = self; addGestureRecognizer(g) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    @objc private func onTap(_ g: UITapGestureRecognizer) { act.tap(g.location(in: self)) }

    @objc private func onLong(_ g: UILongPressGestureRecognizer) {
        let p = g.location(in: self), w = g.location(in: nil)
        switch g.state {
        case .began: longOn = true; act.longBegan(p)
        case .changed: act.longMoved(p, w)
        case .ended: longOn = false; act.longEnded(w, false)
        case .cancelled, .failed: if longOn { longOn = false; act.longEnded(w, true) }
        default: break
        }
    }

    @objc private func onPan(_ g: UIPanGestureRecognizer) {
        if longOn { return }
        let p = g.location(in: self), t = g.translation(in: self)
        switch g.state {
        case .began: act.panBegan(CGPoint(x: p.x - t.x, y: p.y - t.y)); act.panMoved(p, CGSize(width: t.x, height: t.y))
        case .changed: act.panMoved(p, CGSize(width: t.x, height: t.y))
        case .ended: act.panEnded(false)
        case .cancelled, .failed: act.panEnded(true)
        default: break
        }
    }

    @objc private func onPinch(_ g: UIPinchGestureRecognizer) { act.pinch(g.state, g.scale, g.location(in: self)) }
}

struct DzcTouch: UIViewRepresentable {
    let act: DzcTouchActions
    func makeUIView(context: Context) -> DzcTouchView { let v = DzcTouchView(frame: .zero); v.act = act; return v }
    func updateUIView(_ v: DzcTouchView, context: Context) { v.act = act }
}

/* ---------------- icons ---------------- */

/// The tools' icons (24 × 24, stroked; the mockup's).
let DZC_ICON: [String: String] = [
    "add": "M12 5v14M5 12h14",
    "style": "M12 3l2.6 5.6 6 .7-4.5 4.1 1.2 6L12 16.4 6.7 19.4l1.2-6L3.4 9.3l6-.7z",
    "decor": "M12 3a9 9 0 1 0 0 18c1.2 0 2-.8 2-2 0-.6-.3-1-.6-1.4-.3-.4-.5-.8-.5-1.3 0-1.1.9-2 2-2H17a4 4 0 0 0 4-4c0-4.1-4-7.3-9-7.3zM6.5 11.5a1 1 0 1 0 2 0a1 1 0 1 0 -2 0M9.5 7.5a1 1 0 1 0 2 0a1 1 0 1 0 -2 0M14 7.5a1 1 0 1 0 2 0a1 1 0 1 0 -2 0",
    "handle": "M5 9h14M7 9v4M17 9v4",
    "multi": "M3 3h8v8h-8zM5 7l1.5 1.5L9.5 5.5M13 13h8v8h-8zM15 17l1.5 1.5 3-3M13 3h8v8h-8z",
    "see": "M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12zM9 12a3 3 0 1 0 6 0a3 3 0 1 0 -6 0",
    "checks": "M12 3l10 18H2zM12 10v5M12 18h.01",
    "type": "M4 4h16v16h-16zM4 10h16M4 15h16",
    "width": "M3 17L17 3l4 4L7 21zM7 13l2 2M10 10l2 2M13 7l2 2",
    "in": "M4 3h16v18h-16zM4 9h16M4 15h16",
    "copy": "M8 8h12v12h-12zM16 8V5a1 1 0 0 0 -1 -1H5a1 1 0 0 0 -1 1v10a1 1 0 0 0 1 1h3",
    "move": "M3 12h18M7 8l-4 4 4 4M17 8l4 4-4 4",
    "depth": "M4 9l8-5 8 5-8 5zM4 9v6l8 5 8-5V9M12 14v6",
    "plinth": "M4 3h16v13h-16zM4 19h16M7 16v3M17 16v3",
    "soft": "M4 12h6M14 12h6M10 8l4 4-4 4",
    "hinge": "M5 3h14v18h-14zM19 3L7 12l12 9",
    "del": "M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13",
    "height": "M12 3v18M8 7l4-4 4 4M8 17l4 4 4-4",
    "align": "M5 4h14v6H5zM8 14h8v6H8zM5 12h2M9 12h2M13 12h2M17 12h2",
    "closeGap": "M3 12h7M14 12h7M7 8l4 4-4 4M17 8l-4 4 4 4",
    "selUp": "M6 15l6-6 6 6",
    "done": "M5 12.5l4.5 4.5L19 7",
    "secs": "M3 4h18v16h-18zM9 4v16M15 4v16",
    "door": "M6 3h12v18h-12zM15 11v3",
    "more": "M4 7h10M18 7h2M16 5v4M4 17h4M12 17h8M10 15v4",
    "size": "M3 8h18M3 8v-3M21 8v-3M6 12h12v8h-12z",
    "boxes": "M3 7h8v13h-8zM13 11h8v9h-8z",
    "place": "M12 21s-7-6.2-7-11.5A7 7 0 0 1 19 9.5C19 14.8 12 21 12 21zM9.5 9.5a2.5 2.5 0 1 0 5 0a2.5 2.5 0 1 0 -5 0",
    "mats": "M12 3l9 5-9 5-9-5zM3 13l9 5 9-5",
    "setup": "M4 7h10M18 7h2M16 5v4M4 17h4M12 17h8M10 15v4",
    "kbd": "M3 6h18v12h-18zM7 10h.01M11 10h.01M15 10h.01M7 14h10",
    "fit": "M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5",
    "back": "M15 5l-7 7 7 7",
    "x": "M6 6l12 12M18 6L6 18",
    "left": "M15 5l-7 7 7 7",
    "right": "M9 5l7 7-7 7",
    "gorka": "M3 20V8h5v12M8 20V12h8v8M16 20V8h5v12M3 20h18",
]

/// The options' glyphs (30 × 30, stroked; the mockup's).
let DZC_GLYPH: [String: String] = [
    "door1": "M7 4h16v22h-16zM19 9v5",
    "door2": "M4 4h22v22h-22zM15 4v22M12.5 9v4M17.5 9v4",
    "drawer2": "M4 4h22v22h-22zM4 15h22M12 8h6M12 19h6",
    "drawer3": "M4 4h22v22h-22zM4 11h22M4 18.5h22M12 7.5h6M12 14.5h6M12 22h6",
    "drawer4": "M4 4h22v22h-22zM4 9.5h22M4 15h22M4 20.5h22",
    "openLow": "M4 4h22v22h-22zM4 11h22M4 18h22",
    "sink": "M4 11h22v15h-22zM15 11V5h5v3M8 11h14",
    "hob": "M4 8h22v18h-22zM4 5h22M8 13h14v8h-14z",
    "dishwasher": "M4 4h22v22h-22zM10 8h10M12 17a3 3 0 1 0 6 0a3 3 0 1 0 -6 0",
    "wdoor1": "M8 4h14v13h-14zM18 12v3",
    "wdoor2": "M4 4h22v13h-22zM15 4v13M13 12v3M17 12v3",
    "vitrina": "M4 4h22v14h-22zM15 4v14M7 15l4-7M18 15l4-7",
    "open": "M4 4h22v14h-22zM4 11h22",
    "micro": "M4 4h22v14h-22zM7 7h11v8h-11zM21 9v4",
    "hood": "M12 3h6v8h-6zM5 18l7-7h6l7 7z",
    "pantry": "M8 2h14v26h-14zM8 15h14M18 9v3M18 18v3",
    "corner": "M4 4h22v22h-22zM15 4v4M15 11v4M15 18v4M8 12v4",
    "fillerLow": "M12 4h6v22h-6z",
    "fillerUp": "M12 4h6v13h-6z",
    "fridge": "M8 2h14v26h-14zM8 11h14M11 5v3M11 14v4",
    "fridgeB": "M8 2h14v26h-14zM8 11h14M11 5v3M11 14v4",
    "oven": "M8 2h14v26h-14zM10 10h10v8h-10z",
    "base": "M4 4h22v22h-22zM15 4v22M12.5 9v4M17.5 9v4",
    "drawers": "M4 4h22v22h-22zM4 11h22M4 18.5h22M12 7.5h6M12 14.5h6M12 22h6",
    "wall": "M4 4h22v13h-22zM15 4v13M13 12v3M17 12v3",
    "plinth": "M4 4h22v17h-22zM4 21h22v5h-22z",
    "legs": "M4 4h22v17h-22zM8 21v5M22 21v5",
    "metal": "M4 4h22v17h-22zM8 21l-1 5M22 21l1 5",
    "wall-hang": "M4 4h22v15h-22zM2 2h26",
    "h-bar": "M6 3h18v24h-18zM19 10v10",
    "h-long": "M6 3h18v24h-18zM19 6v18",
    "h-knob": "M6 3h18v24h-18zM17.5 15a1.5 1.5 0 1 0 3 0a1.5 1.5 0 1 0 -3 0",
    "h-gola": "M6 3h18v24h-18zM6 6.5h18",
    "h-push": "M6 3h18v24h-18zM18 15a1 1 0 1 0 2 0a1 1 0 1 0 -2 0M15 12l3 3-3 3",
    "h-on": "M6 3h18v24h-18zM19 10v10",
    "h-off": "M6 3h18v24h-18zM18 15a1 1 0 1 0 2 0a1 1 0 1 0 -2 0M15 12l3 3-3 3",
    "hg-L": "M6 3h18v24h-18zM24 3L6 15l18 12",
    "hg-R": "M6 3h18v24h-18zM6 3l18 12L6 27",
    "rail": "M4 7h22M8 7v-2M22 7v-2M10 9l-4 6h8zM20 9l-4 6h8zM4 22h22",
    "d2": "M4 2h22v26h-22zM15 2v26M12.5 13v4M17.5 13v4",
    "d1": "M8 2h14v26h-14zM18 13v4",
    "mirror": "M8 2h14v26h-14zM11 12l5-6M11 20l8-9",
    "glass": "M8 2h14v26h-14zM11 5h8v20h-8z",
    "sopen": "M8 2h14v26h-14zM8 9h14M8 17h14",
    "hinged": "M4 2h22v26h-22zM15 2v26M12.5 13v4M17.5 13v4",
    "slide": "M3 2h24v26h-24zM12 2v26M18 2v26M3 25h24",
    "shelf": "M4 6h22v20h-22zM4 16h22",
    "drawer": "M4 6h22v20h-22zM4 16h22M12 11h6M12 21h6",
]

/// A tool's or an option's line icon.
struct DzcIcon: View {
    let d: String
    let color: Color
    var size: CGFloat = 24
    var box: CGFloat = 24
    var stroke: CGFloat = 1.9
    var body: some View { PathIcon(d, color, size, stroke, viewBox: box) }
}

/* ---------------- the slider ---------------- */

/// A tool of the slider: its key, label, icon; a count badge; tone "red" (O‘chirish) or "pri" (Tayyor); on: a switch on.
struct DzcTool: Identifiable {
    let id: String
    let label: String
    var icon = ""
    var badge: Int? = nil
    var tone = ""
    var on = false
}

/// The biggest size from mx down to mn (in steps of step) at which every word of label fits on a line (fits(word,
/// size)); mn when none does. Pure, so it is unit-tested.
func dzcLabelSize(_ label: String, _ mx: CGFloat, _ mn: CGFloat, _ step: CGFloat, _ fits: (String, CGFloat) -> Bool) -> CGFloat {
    let words = label.split(whereSeparator: { $0 == " " || $0 == "\n" }).map(String.init)
    var s = mx
    while s >= mn - 0.001 {
        if words.allSatisfy({ fits($0, s) }) { return s }
        s -= step
    }
    return mn
}

/// The size of a tool's label (11 pt at most, 8.5 at least) whose longest word fits the tool's 62 pt on one line.
func dzcToolLabelSize(_ label: String) -> CGFloat {
    dzcLabelSize(label, 11, 8.5, 0.5) { w, s in
        let f = ui(s, 700).uiFont
        return (w as NSString).size(withAttributes: [.font: f]).width <= 61
    }
}

/// One tool: the icon over its label (two lines at most), at least 56 pt tall.
private struct DzcToolButton: View {
    let t: DzcTool
    let action: () -> Void
    var body: some View {
        let fg: Color = t.tone == "red" ? G.err : t.tone == "pri" ? .white : (t.on ? G.cobalt2 : G.ink)
        let bg: Color = t.tone == "pri" ? G.cobalt : t.on ? G.cobalt.opacity(0.12) : Color.clear
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                DzcIcon(d: DZC_ICON[t.icon.isEmpty ? t.id : t.icon] ?? DZC_ICON["more"]!, color: fg, size: 24)
                    .frame(width: 34, height: 26)
                if let b = t.badge {
                    T(b > 0 ? "\(b)" : "✓", ui(10.5, 800, .white), align: .center)
                        .frame(minWidth: 17, minHeight: 17)
                        .background(Capsule().fill(b > 0 ? G.err : G.green))
                        .offset(x: 6, y: -5)
                }
            }
            // broken only between words, never inside one ("Qo‘shimch / a"): a little smaller when a word is too long
            let fs = dzcToolLabelSize(t.label)
            T(t.label, ui(fs, 700, fg, lh: 1.1), align: .center, lines: 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4).padding(.vertical, 5)
        .frame(width: 70, height: 62)
        .background(shape.fill(bg))
        .pressable(0.95, label: t.label + (t.badge.map { $0 > 0 ? ", \($0)" : "" } ?? ""), action)
        .accessibilityAddTraits(t.on ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("dzc.t." + t.id)
    }
}

/// The Canva-style slider: one row of tools that scrolls sideways, the last one cut by a faded edge.
struct DzcSlider: View {
    let tools: [DzcTool]
    let onTap: (String) -> Void
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(tools) { t in DzcToolButton(t: t) { onTap(t.id) } }
            }
            .padding(.leading, 8).padding(.trailing, 28)
        }
        .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.84), .init(color: .black.opacity(0.08), location: 1)],
                             startPoint: .leading, endPoint: .trailing))
        .frame(height: 66)
        .accessibilityIdentifier("dzc.slider")
    }
}

/* ---------------- an options row ---------------- */

/// A tool's options in place of the slider: its name and what it changes, the scope toggle, "←" back to the slider and
/// the options in a row that scrolls sideways.
struct DzcOptRow<Opts: View>: View {
    let title: String
    var sub = ""
    var scopes: [(String, String)] = []
    let onBack: () -> Void
    @ViewBuilder var opts: Opts
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                T(title, ui(14, 800), lines: 1)
                if !sub.isEmpty { T(sub, ui(12, 500, G.ink2), lines: 1).minimumScaleFactor(0.8) }
                Spacer(minLength: 4)
                if !scopes.isEmpty { DzcScope(items: scopes) }
            }
            .padding(.horizontal, 12)
            HStack(spacing: 6) {
                DzcIcon(d: DZC_ICON["back"]!, color: G.ink, size: 22)
                    .frame(width: 48, height: 52)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.ink.opacity(0.06)))
                    .pressable(0.95, label: tr("dzc.toTools"), onBack)
                    .accessibilityIdentifier("dzc.back")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) { opts }.padding(.trailing, 20)
                }
            }
            .padding(.leading, 10)
        }
        .padding(.top, 8).padding(.bottom, 6)
    }
}

/// The scope toggle of an options row ("Faqat shu" / "Shu qatorga" / "Butun oshxonaga").
struct DzcScope: View {
    let items: [(String, String)]
    var body: some View {
        let st = DzcState.shared
        HStack(spacing: 2) {
            ForEach(items, id: \.0) { k, label in
                let on = st.scope == k
                T(label, ui(11.5, on ? 800 : 600, on ? G.ink : G.ink2), lines: 1).minimumScaleFactor(0.75)
                    .padding(.horizontal, 9).frame(minHeight: 32)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(on ? G.glass(0.95) : .clear))
                    .pressable(0.97) { st.scope = k; Haptic.tick() }
                    .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                    .accessibilityIdentifier("dzc.scope." + k)
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(G.ink.opacity(0.07)))
    }
}

/// An option: a glyph (DZC_GLYPH key) or none, its label, on when it is the current one.
struct DzcOpt: View {
    let label: String
    var glyph = ""
    var on = false
    var tone = ""
    var id = ""
    /// A long text (a check's sentence): it wraps within this width instead of running on under the next option.
    var wrap: CGFloat? = nil
    let action: () -> Void
    var body: some View {
        let fg: Color = tone == "red" ? G.err : on ? G.cobalt2 : G.ink
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        HStack(spacing: 6) {
            if let d = DZC_GLYPH[glyph] { DzcIcon(d: d, color: fg, size: 26, box: 30, stroke: 1.8) }
            else if let d = DZC_ICON[glyph] { DzcIcon(d: d, color: fg, size: 20) }
            if let wrap { T(label, ui(13, on ? 800 : 600, fg), lines: 3).frame(width: wrap, alignment: .leading).fixedSize(horizontal: false, vertical: true) }
            else { T(label, ui(13.5, on ? 800 : 600, fg), lines: 2).fixedSize(horizontal: true, vertical: false) }
        }
        .padding(.horizontal, 12).frame(minHeight: 52)
        .background(shape.fill(on ? G.cobalt.opacity(0.1) : G.glass(0.6)))
        .overlay(shape.strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 2 : 1))
        .pressable(0.97, action)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(id)
    }
}

/// A colour swatch option with its name under it.
struct DzcSwatch: View {
    let rgb: String
    let label: String
    var wood = false
    let on: Bool
    var id = ""
    let action: () -> Void
    var body: some View {
        let c = Color(argb: 0xFF00_0000 | UInt32(rgbOf(rgb)))
        VStack(spacing: 3) {
            Circle().fill(c)
                .overlay { if wood { Circle().strokeBorder(Color.black.opacity(0.12), style: StrokeStyle(lineWidth: 5, dash: [1, 3])) } }
                .padding(on ? 3 : 1)
                .frame(width: 36, height: 36)
                .overlay(Circle().strokeBorder(on ? G.cobalt : G.ink.opacity(0.2), lineWidth: on ? 3 : 1))
            T(label, ui(10.5, on ? 800 : 600, on ? G.cobalt2 : G.ink2), align: .center, lines: 1)
                .frame(width: 62)
        }
        .frame(minHeight: 56)
        .pressable(0.96, label: label, action)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(id)
    }
}

/// "Javonlar − 2 +".
struct DzcStepper: View {
    let label: String
    let v: Int
    let lo: Int
    let hi: Int
    var id = ""
    let onValue: (Int) -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        HStack(spacing: 4) {
            T(label, ui(13, 700), lines: 1).padding(.leading, 10)
            step("−", v > lo, id + ".minus") { onValue(v - 1) }
            T("\(v)", num(16, 800), align: .center).frame(minWidth: 26).accessibilityIdentifier(id + ".v")
            step("+", v < hi, id + ".plus") { onValue(v + 1) }
        }
        .frame(minHeight: 52)
        .background(shape.fill(G.glass(0.6)))
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
    }
    private func step(_ t: String, _ on: Bool, _ sid: String, _ a: @escaping () -> Void) -> some View {
        T(t, ui(20, 700, on ? G.ink : G.ink3), align: .center).frame(width: 44, height: 44)
            .pressable(0.95, label: t) { if on { a() } }
            .accessibilityIdentifier(sid)
    }
}

/// A short line in an options row.
struct DzcNote: View {
    let text: String
    var body: some View { T(text, ui(12, 500, G.ink2, lh: 1.3), lines: 2).frame(maxWidth: 220, alignment: .leading).padding(.horizontal, 4) }
}

/* ---------------- the bottom ---------------- */

/// The red zone that takes the slider's place while a unit is lifted: dropped there, it is deleted.
struct DzcDelZone: View {
    let on: Bool
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        HStack(spacing: 10) {
            DzcIcon(d: DZC_ICON["del"]!, color: on ? .white : G.err, size: 24)
            T(tr("dzc.dropDel"), ui(14, 800, on ? .white : G.err), lines: 2)
        }
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(shape.fill(on ? G.err : G.errWash))
        .overlay(shape.strokeBorder(G.err.opacity(on ? 1 : 0.5), style: StrokeStyle(lineWidth: 2, dash: on ? [] : [6, 4])))
        .scaleEffect(on ? 1.03 : 1)
        .animation(.easeOut(duration: 0.15), value: on)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(GeometryReader { g in
            Color.clear
                .onAppear { DzcState.shared.delFrame = g.frame(in: .global) }
                .onChange(of: g.frame(in: .global)) { _, r in DzcState.shared.delFrame = r }
        })
        .accessibilityIdentifier("dzc.delZone")
    }
}

/// The bottom bar's middle: Redo and the 2D | 3D switch.
struct DzcMiddle: View {
    let canRedo: Bool
    let d3: Bool
    let onRedo: () -> Void
    let onDim: (Bool) -> Void
    var body: some View {
        HStack(spacing: 8) {
            MIcon("redo", canRedo ? G.ink : G.ink3.opacity(0.5), 20, 2.2)
                .frame(width: 46, height: 52)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.ink.opacity(0.06)))
                .pressable(0.95, label: tr("common.redo")) { if canRedo { onRedo() } }
                .accessibilityIdentifier("dzc.redo")
            HStack(spacing: 2) {
                ForEach([(false, "2D"), (true, "3D")], id: \.0) { k, l in
                    let on = k == d3
                    // one line always: on a small phone with a long main button "2D" wrapped to "2 / D"
                    T(l, ui(14, on ? 800 : 600, on ? G.ink : G.ink2), lines: 1)
                        .fixedSize()
                        .padding(.horizontal, 10).frame(minHeight: 46)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(on ? G.glass(0.95) : .clear))
                        .pressable(0.97) { if !on { onDim(k) } }
                        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                        .accessibilityIdentifier("dim." + l)
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(G.ink.opacity(0.06)))
        }
    }
}

/// The caption over the drawing: what is selected (with ✕), a front with "‹ the unit", the marked count with ✓.
struct DzcCaption: View {
    let title: String
    var sub = ""
    var up: String? = nil
    var dark = false
    let onUp: () -> Void
    let onClose: () -> Void
    var body: some View {
        let fg: Color = dark ? .white : G.ink
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: 8) {
            if let up {
                T("‹ " + up, ui(13, 700, dark ? .white : G.cobalt2), lines: 1)
                    .padding(.horizontal, 10).frame(minHeight: 36)
                    .background(Capsule().fill(G.cobalt.opacity(dark ? 0.3 : 0.1)))
                    .pressable(0.97, onUp)
                    .accessibilityIdentifier("dzc.selUp")
            }
            VStack(alignment: .leading, spacing: 0) {
                T(title, ui(14.5, 800, fg), lines: 1)
                if !sub.isEmpty { T(sub, ui(11.5, 500, dark ? .white.opacity(0.8) : G.ink2), lines: 1) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            DzcIcon(d: DZC_ICON[dark ? "done" : "x"]!, color: fg, size: 18)
                .frame(width: 40, height: 40)
                .background(Circle().fill(dark ? Color.white.opacity(0.2) : G.ink.opacity(0.06)))
                .pressable(0.95, label: tr(dark ? "dzc.done" : "dzc.desel"), onClose)
                .accessibilityIdentifier(dark ? "dzc.multiDone" : "dzc.desel")
        }
        .padding(.leading, 12).padding(.trailing, 6).padding(.vertical, 4)
        .background(shape.fill(dark ? G.cobalt : G.sheet(0.92)))
        .overlay(shape.strokeBorder(dark ? .clear : G.rim, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
        .padding(.horizontal, 10)
    }
}

/// Its view centred at (x, y) of the drawing but kept wholly inside it, pad from each edge (a unit at the screen's edge
/// still shows its mm bubble and the amber label whole); a view wider than the drawing is given its width.
struct DzcPin: Layout {
    let x: CGFloat
    let y: CGFloat
    var pad: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for s in subviews {
            let maxW = max(1, b.width - 2 * pad)
            var sz = s.sizeThatFits(.unspecified)
            if sz.width > maxW { sz = s.sizeThatFits(ProposedViewSize(width: maxW, height: nil)) }
            let w = min(sz.width, maxW), h = sz.height
            let c = dzcClampCentre(x, y, CGSize(width: w, height: h), b.size, pad)
            s.place(at: CGPoint(x: b.minX + c.x, y: b.minY + c.y), anchor: .center, proposal: ProposedViewSize(width: w, height: h))
        }
    }
}

/// The centre a box of size sz wants at (x, y), moved so the box stays inside area, pad from its edges (centred when
/// it does not fit). Pure, so it is unit-tested.
func dzcClampCentre(_ x: CGFloat, _ y: CGFloat, _ sz: CGSize, _ area: CGSize, _ pad: CGFloat) -> CGPoint {
    func clamp(_ v: CGFloat, _ half: CGFloat, _ len: CGFloat) -> CGFloat {
        let lo = half + pad, hi = len - half - pad
        return lo > hi ? len / 2 : min(max(v, lo), hi)
    }
    return CGPoint(x: clamp(x, sz.width / 2, area.width), y: clamp(y, sz.height / 2, area.height))
}

/// The amber label of whoever takes a dragged width's difference ("Tortmali 600 → 450"); from the left, a second line
/// saying the right side had no room.
struct DzcAmberLabel: View {
    let text: String
    var left = false
    var body: some View {
        VStack(spacing: 1) {
            T(text, num(12, 800, G.amberInk), lines: 1)
            if left { T(tr("dzc.fromLeft"), ui(11, 700, G.amberInk), align: .center, lines: 2) }
        }
        .padding(.horizontal, 10).padding(.vertical, 4).frame(minHeight: 26)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(G.amberWash))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(G.amberInk.opacity(0.5), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("dzc.taker")
    }
}

/// "120% · sig‘dirish": back to the fitted view.
struct DzcZoomPill: View {
    let pct: Int
    let onFit: () -> Void
    var body: some View {
        HStack(spacing: 6) {
            DzcIcon(d: DZC_ICON["fit"]!, color: G.ink, size: 16)
            T(tr("dzc.fit", ["v": pct]), ui(12, 700), lines: 1)
        }
        .padding(.horizontal, 12).frame(minHeight: 36)
        .background(Capsule().fill(G.sheet(0.92)))
        .overlay(Capsule().strokeBorder(G.rim, lineWidth: 1))
        .pressable(0.96, onFit)
        .accessibilityIdentifier("dzc.fitBtn")
    }
}

/* ---------------- the gesture hint ---------------- */

/// The animated hint shown once (and again by "?"): drag the edge for the width, hold to move, two fingers to zoom;
/// about 3 s each, skippable.
struct DzcTeach: View {
    /// A bed's, a table's (the short designer's): tap a tool below, one finger turns the 3D, two fingers zoom.
    var item = false
    let onSkip: () -> Void
    var body: some View {
        let t0 = DzcState.shared.teachT0
        let item = self.item
        let keys = item ? ["dzc.teachI1", "dzc.teachI2", "dzc.teach3"] : ["dzc.teach1", "dzc.teach2", "dzc.teach3"]
        ZStack {
            Rectangle().fill(G.scrim.opacity(0.35)).ignoresSafeArea()
                .onTapGesture { onSkip() }
            VStack(spacing: 10) {
                TimelineView(.animation) { tl in
                    let t = tl.date.timeIntervalSince(t0)
                    let phase = min(2, Int(t / 3))
                    let u = CGFloat(t.truncatingRemainder(dividingBy: 3) / 3)
                    VStack(spacing: 8) {
                        Canvas { ctx, size in
                            if item && phase < 2 { Self.drawItem(ctx, size, phase, u) } else { Self.draw(ctx, size, phase, u) }
                        }
                            .frame(width: 260, height: 118)
                        T(tr(keys[phase]), ui(15, 800), align: .center)
                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { i in
                                Capsule().fill(i <= phase ? G.cobalt : G.ink.opacity(0.15)).frame(width: i == phase ? 22 : 8, height: 8)
                            }
                        }
                    }
                    .onChange(of: t > 9.5) { _, done in if done { onSkip() } }
                }
                GBtn(tr("dzc.skip"), kind: .secondary, height: 44, corner: 14, fontSize: 14, fill: false) { onSkip() }
                    .accessibilityIdentifier("dzc.teachSkip")
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(G.sheet(0.97)))
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
            .padding(24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("dzc.teach")
    }

    /// The short designer's first two steps: a finger taps a tool of the row below; a finger drags the piece round.
    private static func drawItem(_ c: GraphicsContext, _ size: CGSize, _ phase: Int, _ u: CGFloat) {
        let ink = G.ink.opacity(0.75), blue = G.cobalt
        func finger(_ p: CGPoint, _ down: Bool) {
            let r: CGFloat = down ? 10 : 12
            c.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(G.cobalt.opacity(down ? 0.4 : 0.28)))
            c.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(blue), lineWidth: 2)
        }
        if phase == 0 {
            // the tool row; the second tool lights up as it is tapped
            let on = u > 0.45
            for i in 0..<4 {
                let r = Path(roundedRect: CGRect(x: 28 + CGFloat(i) * 52, y: 62, width: 44, height: 40), cornerRadius: 8)
                let hit = i == 1 && on
                c.fill(r, with: .color(hit ? G.cobalt.opacity(0.18) : G.ink.opacity(0.06)))
                c.stroke(r, with: .color(hit ? blue : ink), lineWidth: hit ? 2.4 : 1.2)
            }
            let y = u < 0.45 ? 30 + 50 * (u / 0.45) : 80
            finger(CGPoint(x: 102, y: y), u > 0.4 && u < 0.6)
            return
        }
        // a box turning about its middle while the finger drags sideways
        let a = (u - 0.5) * 1.2
        let w: CGFloat = 70 * max(0.25, abs(cos(a))), d: CGFloat = 40 * abs(sin(a))
        let x0 = size.width / 2 - (w + d) / 2
        let front = Path(CGRect(x: x0, y: 34, width: w, height: 60))
        c.fill(front, with: .color(G.cobalt.opacity(0.12)))
        c.stroke(front, with: .color(blue), lineWidth: 2.4)
        if d > 1 {
            var side = Path()
            side.move(to: CGPoint(x: x0 + w, y: 34)); side.addLine(to: CGPoint(x: x0 + w + d, y: 26))
            side.addLine(to: CGPoint(x: x0 + w + d, y: 86)); side.addLine(to: CGPoint(x: x0 + w, y: 94)); side.closeSubpath()
            c.fill(side, with: .color(G.ink.opacity(0.06)))
            c.stroke(side, with: .color(ink), lineWidth: 1.4)
        }
        c.line(ink, CGPoint(x: 16, y: 104), CGPoint(x: size.width - 16, y: 104), 1.4)
        finger(CGPoint(x: 70 + 120 * u, y: 64), true)
    }

    private static func draw(_ c: GraphicsContext, _ size: CGSize, _ phase: Int, _ u: CGFloat) {
        let ink = G.ink.opacity(0.75), blue = G.cobalt
        let ease = u < 0.5 ? 2 * u * u : 1 - pow(-2 * u + 2, 2) / 2
        func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ on: Bool) {
            let r = Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: 3)
            c.fill(r, with: .color(on ? G.cobalt.opacity(0.12) : G.ink.opacity(0.06)))
            c.stroke(r, with: .color(on ? blue : ink), lineWidth: on ? 2.4 : 1.4)
        }
        func finger(_ p: CGPoint) {
            c.fill(Path(ellipseIn: CGRect(x: p.x - 12, y: p.y - 12, width: 24, height: 24)), with: .color(G.cobalt.opacity(0.28)))
            c.stroke(Path(ellipseIn: CGRect(x: p.x - 12, y: p.y - 12, width: 24, height: 24)), with: .color(blue), lineWidth: 2)
        }
        c.line(ink, CGPoint(x: 16, y: 104), CGPoint(x: size.width - 16, y: 104), 1.4)
        switch phase {
        case 0:
            let w = 120 - 40 * ease
            box(40, 34, w, 70, true)
            c.fill(Path(roundedRect: CGRect(x: 40 + w - 6, y: 54, width: 12, height: 30), cornerRadius: 6), with: .color(blue))
            finger(CGPoint(x: 40 + w + 4, y: 78))
            c.text((ease < 0.5 ? "600" : "450") + U_MM, CGPoint(x: 40 + w / 2, y: 20), .num, 13, 700, blue)
        case 1:
            box(30, 34, 70, 70, false)
            let lift = min(1, u * 3)
            let dx = max(0, (u - 0.33) / 0.67) * -60
            box(104 + dx, 34 - 10 * lift, 70, 70, true)
            if u < 0.33 {
                var ring = Path(); ring.addArc(center: CGPoint(x: 139, y: 69), radius: 22, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * Double(u / 0.33)), clockwise: false)
                c.stroke(ring, with: .color(blue), lineWidth: 3)
            }
            finger(CGPoint(x: 139 + dx, y: 69 - 10 * lift))
        default:
            let s = 1 + 0.25 * ease
            box(130 - 58 * s, 104 - 70 * s, 56 * s, 70 * s, false)
            box(130 + 2 * s, 104 - 70 * s, 62 * s, 70 * s, true)
            finger(CGPoint(x: 114 - 24 * ease, y: 76 + 6 * ease))
            finger(CGPoint(x: 150 + 24 * ease, y: 58 - 6 * ease))
        }
    }
}

/* ---------------- the number sheet ---------------- */

/// A typed size from the mm bubble (the phone's own number keyboard): a unit's or a section's width, a wall unit's
/// height; the allowed range said under it.
struct DzcNumSheet: View {
    let app: AppModel
    let pid: String, fid: String, mid: String, key: String, sec: Int
    @State private var v = ""
    @FocusState private var focus: Int?
    var body: some View {
        if let p = Store.shared.get(pid), let f = p.furniture.first(where: { $0.id == fid }), let m = f.modules.first(where: { $0.id == mid }) {
            let r = dzcNumRange(p, f, m, key, sec)
            let vi = Int(v).flatMap { r.contains($0) ? $0 : nil }
            let fixedBad = key == "w" && sec < 0 && dzcFixedW(m) && vi != nil && !dzcWidths(m).contains(vi!)
            let ok = vi != nil && !fixedBad
            let title = tr(key == "h" ? "dzc.t.height" : "dzc.t.width")
            GlassSheet(title, onClose: { app.sheet = nil }) {
                GField(label: title, value: $v, placeholder: "\(dzcNumNow(m, key, sec))", error: fixedBad ? tr("dzc.onlyW", ["v": dzcWidths(m).map(String.init).joined(separator: ", ")]) : tr("km.bad", ["a": r.lowerBound, "b": r.upperBound]),
                       showError: !v.isEmpty && !ok, focus: $focus, me: 0, submit: .done, onSubmit: { if ok { save(p, f, m, vi!) } }, labelRight: tr("u.mm"), number: true, id: "dzc.num")
                T(tr("dzc.range", ["a": r.lowerBound, "b": r.upperBound]), ui(12.5, 500, G.ink2))
            } footer: {
                GBtn(tr("dzc.ready"), enabled: ok) { if let x = vi { save(p, f, m, x) } }.accessibilityIdentifier("dzc.numOk")
            }
            .onChange(of: v) { _, x in let t = String(x.filter(\.isNumber).prefix(4)); if t != x { v = t } }
            .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focus = 0 } }
        }
    }

    private func save(_ p: Project, _ f: Furniture, _ m: Module, _ x: Int) {
        app.sheet = nil
        if key == "h" { dzcCommitHeight(app, p, f, m.id, x); return }
        if sec >= 0 { dzcCommitSecW(app, p, f, m.id, sec, x); return }
        dzcCommitW(app, p, f, m.id, x, typed: true)
    }
}

func dzcNumNow(_ m: Module, _ key: String, _ sec: Int) -> Int {
    if key == "h" { return m.h }
    if sec >= 0 && sec < m.sections.count { return m.sections[sec].w }
    return m.w
}

/// The range a typed size may take.
func dzcNumRange(_ p: Project, _ f: Furniture, _ m: Module, _ key: String, _ sec: Int) -> ClosedRange<Int> {
    if key == "h" { return 200...1200 }
    if sec >= 0 { return DZC_SEC_MIN...max(DZC_SEC_MIN, dzcSecMax(m, sec)) }
    let run = kRuns(f, roomOf(p, f), AppSettings.shared.angleSnap).first { $0.wall == m.wall }
    let avail = run.flatMap { fillOf(f, $0, isUpper(m)).avail }
    let lo = dzcLowW(m)
    return lo...max(lo, dzcMaxW(f, m.id, avail: avail))
}

/* ---------------- committing a change ---------------- */

/// A change made: a confirm haptic and a toast with "Ortga qaytarish".
func dzcSaid(_ app: AppModel, _ pid: String, _ fid: String, _ key: String, _ vars: [String: Any] = [:]) {
    Haptic.confirm()
    app.say(key, vars, action: "common.undo") { KitOps.shared.undo(pid, fid); Haptic.tick() }
}

/// A change that did not go: a warning haptic and why.
func dzcWarn(_ app: AppModel, _ key: String, _ vars: [String: Any] = [:]) {
    Haptic.warn()
    app.say(key, vars, kind: .error)
}

/// An options row's "Faqat shu" line: "faqat <the front>" with a front selected (frontName), else whole (this unit or
/// this section).
func dzcOnlySub(_ m: Module?, _ front: String?, _ whole: String) -> String {
    guard let m, let fk = front, let fr = handleFronts(m).first(where: { $0.key == fk }) else { return whole }
    return tr("dzc.onlyF", ["f": frontName(m, fr)])
}

/// The name a taker of the difference goes by in a toast: a unit's name, or "the row's free end".
func dzcTakerName(_ f: Furniture, _ id: String?) -> String {
    guard let id else { return "" }
    if id.isEmpty { return tr("dzc.freeEnd") }
    return f.modules.first { $0.id == id }.map { tr("kn." + kindOf($0)) } ?? ""
}

/// Kitchen unit mid of f nw wide, the difference taken as the rules say; the toast tells who took it.
func dzcCommitW(_ app: AppModel, _ p: Project, _ f: Furniture, _ mid: String, _ nw: Int, typed: Bool = false) {
    guard let m = f.modules.first(where: { $0.id == mid }) else { return }
    if m.type == "wardrobe" { return }
    let s = AppSettings.shared, ws = wsOf(f, s.workshop)
    let run = kRuns(f, roomOf(p, f), s.angleSnap).first { $0.wall == m.wall }
    let avail = run.flatMap { fillOf(f, $0, isUpper(m)).avail }
    let r = dzcResize(f, mid, nw, avail: avail, ws: ws)
    if !r.ok { dzcWarn(app, r.why, r.vars); return }
    if nw == m.w { return }
    KitOps.shared.change(p.id, f.id) { x in dzcResize(x, mid, nw, avail: avail, ws: ws).f }
    let name = tr("kn." + kindOf(m))
    if let t = r.taker {
        // from the left only when the right had no room: the toast says so
        let who = dzcTakerName(f, t) + (r.left ? " (" + tr("dzc.fromLeft") + ")" : "")
        dzcSaid(app, p.id, f.id, "dzc.wTook", ["m": name, "a": m.w, "b": nw, "t": who, "c": r.w0, "d": max(0, r.w1)])
    } else {
        dzcSaid(app, p.id, f.id, "dzc.wDone", ["m": name, "a": m.w, "b": nw])
    }
}

/// Wall unit mid of f h high, its top kept.
func dzcCommitHeight(_ app: AppModel, _ p: Project, _ f: Furniture, _ mid: String, _ h: Int) {
    guard let m = f.modules.first(where: { $0.id == mid }), m.h != h else { return }
    KitOps.shared.change(p.id, f.id) { dzcHeight($0, mid, h) }
    dzcSaid(app, p.id, f.id, "dzc.hDone", ["m": tr("kn." + kindOf(m)), "a": m.h, "b": h])
}

/// Section sec of wardrobe box mid nw wide, its neighbour taking the difference.
func dzcCommitSecW(_ app: AppModel, _ p: Project, _ f: Furniture, _ mid: String, _ sec: Int, _ nw: Int) {
    guard let m = f.modules.first(where: { $0.id == mid }), sec >= 0, sec < m.sections.count else { return }
    let r = dzcSecResize(m, sec, nw)
    if !r.ok { dzcWarn(app, "dzc.maxW", ["v": dzcSecMax(m, sec)]); return }
    if nw == m.sections[sec].w { return }
    KitOps.shared.change(p.id, f.id) { x in
        var y = x
        y.modules = x.modules.map { $0.id == mid ? dzcSecResize($0, sec, nw).m : $0 }
        return y
    }
    dzcSaid(app, p.id, f.id, "dzc.secWDone", ["s": sec + 1, "a": m.sections[sec].w, "b": nw, "t": r.taker + 1, "c": m.sections[max(0, r.taker)].w, "d": r.w1])
}
