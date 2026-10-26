import SwiftUI
import UIKit
import Observation

/*
 * Free drawings and photos with dimensions (prototype workspace.js PAGES.draw / PAGES.photo and camera.js for the
 * Measure page's pictures; Android ui/markup/MarkupScreen.kt): pen, line or dimension, arrow, text and eraser, three
 * colours, undo and redo.
 */

/// Where a new photo goes: a project's workspace, or (no project) the Measure page's pictures.
struct PhotoTarget { let pid: String?; let wid: String? }

/// The markup editor's choices and undo history, kept while the app runs (prototype U.mkTool, U.mkCol, U.mkW, U.mkH).
@MainActor
@Observable
final class MarkOps {
    static let shared = MarkOps()
    private var tool: [String: String] = [:]
    private var col: [String: String] = [:]
    var width = 1
    private(set) var tick = 0
    @ObservationIgnored private var undoH: [String: [[MkEl]]] = [:]
    @ObservationIgnored private var redoH: [String: [[MkEl]]] = [:]
    /// A laser reading waiting in the dimension sheet, and the text it put in the field (to tell laser from typed).
    var recv: Int? = nil
    @ObservationIgnored var laserText: String? = nil
    /// Photo edges shown and snapped to ("Qirralar" switch), for the time the app runs.
    var edgesOn = true
    /// Photos whose rectangle offer was closed, for the time the app runs.
    var rectGone: [String: Bool] = [:]

    /// Adds the found rectangle's two sides as dimensions A and B (part 3); each is then measured like any line.
    func useRect(_ pid: String?, _ iid: String, _ r: ERect) {
        guard let it = item(pid, iid) else { return }
        let c = colorOf(it)
        func q(_ v: Float) -> Double { (Double(v) * 10).rounded() / 10 }
        let add = rectSides(r).map { s in MkEl(id: uid(), t: "dim", pts: [[q(s.0.0), q(s.0.1)], [q(s.1.0), q(s.1.1)]], c: c) }
        guard !add.isEmpty else { return }
        change(pid, iid) { $0 + add }   // the new dimensions hide the offer; undo brings it back
        app.say("mk.rectAdded")
    }

    private var app: AppModel { AppModel.shared }

    func toolOf(_ it: Item) -> String { let ts = MK_TOOLS[it.kind] ?? MK_TOOLS["drawing"]!; if let c = tool[it.kind], ts.contains(c) { return c }; return ts[0] }
    func setTool(_ it: Item, _ t: String) { tool[it.kind] = t }
    func colorOf(_ it: Item) -> String { col[it.kind] ?? (it.kind == "photo" ? "red" : "ink") }
    func setColor(_ it: Item, _ c: String) { col[it.kind] = c }

    func item(_ pid: String?, _ iid: String) -> Item? {
        guard let pid else { return AppSettings.shared.shots.first { $0.id == iid } }
        return Store.shared.get(pid)?.floors.flatMap(\.items).first { $0.id == iid }
    }
    func wid(_ pid: String?, _ iid: String) -> String? { pid.flatMap { Store.shared.get($0)?.floors.first { w in w.items.contains { $0.id == iid } }?.id } }

    /// The item's workspace name, or "Pictures" for the Measure page's.
    func place(_ pid: String?, _ iid: String) -> String {
        guard let pid else { return tr("cm.shots") }
        return Store.shared.get(pid)?.floors.first { w in w.items.contains { $0.id == iid } }.map { floorName($0) } ?? ""
    }

    func update(_ pid: String?, _ iid: String, _ f: (inout Item) -> Void) {
        let now = nowMs()
        if let pid {
            Store.shared.update(pid) { p in
                for wi in p.floors.indices { if let ii = p.floors[wi].items.firstIndex(where: { $0.id == iid }) { f(&p.floors[wi].items[ii]); p.floors[wi].items[ii].edited = now } }
            }
        } else {
            var shots = AppSettings.shared.shots
            if let i = shots.firstIndex(where: { $0.id == iid }) { f(&shots[i]); shots[i].edited = now; AppSettings.shared.saveShots(shots) }
        }
    }

    /// Remembers the marks before a change (prototype mkSnap: at most 60 steps).
    func change(_ pid: String?, _ iid: String, _ f: @escaping ([MkEl]) -> [MkEl]) {
        guard let it = item(pid, iid) else { return }
        var u = undoH[it.id] ?? []; u.append(it.els); if u.count > 60 { u.removeFirst() }
        undoH[it.id] = u; redoH[it.id] = []; tick += 1
        update(pid, iid) { $0.els = f($0.els) }
    }
    func canUndo(_ id: String) -> Bool { _ = tick; return !(undoH[id] ?? []).isEmpty }
    func canRedo(_ id: String) -> Bool { _ = tick; return !(redoH[id] ?? []).isEmpty }
    func undo(_ pid: String?, _ iid: String) {
        guard let it = item(pid, iid), let prev = undoH[iid]?.popLast() else { return }
        redoH[iid, default: []].append(it.els); update(pid, iid) { $0.els = prev }; tick += 1
    }
    func redo(_ pid: String?, _ iid: String) {
        guard let it = item(pid, iid), let next = redoH[iid]?.popLast() else { return }
        undoH[iid, default: []].append(it.els); update(pid, iid) { $0.els = next }; tick += 1
    }

    /// A new free drawing in a workspace (prototype addFree), opened right away.
    func newDrawing(_ pid: String, _ wid: String) {
        let now = nowMs()
        let n = (Store.shared.get(pid)?.floors.first { $0.id == wid }?.items.filter { $0.kind == "drawing" }.count ?? 0) + 1
        var it = Item(id: uid(), kind: "drawing", name: tr("it.drawing", ["n": n]), created: now, edited: now)
        it.W = 1000; it.H = 1300
        let new = it
        Store.shared.update(pid) { p in if let i = p.floors.firstIndex(where: { $0.id == wid }) { p.floors[i].items.append(new) } }
        app.sheet = nil; app.push(.markup(pid: pid, iid: it.id))
    }

    /// A photo saved as src (w × h px) becomes an item there and opens; els are the live camera's line.
    @discardableResult
    func addPhoto(_ t: PhotoTarget, _ id: String, _ src: String, _ w: Int, _ h: Int, els: [MkEl] = []) -> Item {
        let now = nowMs()
        let hh = kround(1000 * Double(h) / Double(max(1, w)))
        var it = Item(id: id, kind: "photo", name: "", created: now, edited: now)
        it.els = els; it.src = src; it.W = 1000; it.H = hh
        if let pid = t.pid, let wid = t.wid {
            let n = (Store.shared.get(pid)?.floors.first { $0.id == wid }?.items.filter { $0.kind == "photo" }.count ?? 0) + 1
            it.name = tr("it.photo", ["n": n])
            let new = it
            Store.shared.update(pid) { p in if let i = p.floors.firstIndex(where: { $0.id == wid }) { p.floors[i].items.append(new) } }
        } else {
            it.name = tr("cm.shotN", ["n": AppSettings.shared.shots.count + 1]); it.rep = false
            AppSettings.shared.saveShots([it] + AppSettings.shared.shots)
        }
        return it
    }

    /// A photo from the camera app or the gallery, into t, opened in the editor.
    func pickPhoto(_ t: PhotoTarget, camera: Bool) {
        app.sheet = nil
        PhotoPicker.present(camera: camera) { [weak self] img in
            guard let self, let img else { return }
            let id = uid()
            guard let saved = PhotoFiles.save(id, img) else { self.app.say("cm.shareErr", kind: .error); return }
            let it = self.addPhoto(t, id, saved.0, saved.1, saved.2)
            // from the live camera's own screen, the picture takes its place (back goes to the Measure page)
            if self.app.top == .liveCam { self.app.replaceTop(.markup(pid: t.pid, iid: it.id)) } else { self.app.push(.markup(pid: t.pid, iid: it.id)) }
        }
    }
}

/// The phone's camera app or photo library (UIKit's picker). With the screen tests' -uiSamplePhoto a drawn sample picture
/// stands in for it, since the simulator has no camera.
enum PhotoPicker {
    private final class Delegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (UIImage?) -> Void
        init(_ done: @escaping (UIImage?) -> Void) { self.done = done }
        func imagePickerController(_ p: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let img = info[.originalImage] as? UIImage
            p.dismiss(animated: true) { self.done(img); PhotoPicker.current = nil }
        }
        func imagePickerControllerDidCancel(_ p: UIImagePickerController) { p.dismiss(animated: true) { PhotoPicker.current = nil } }
    }
    private static var current: Delegate? = nil

    static var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    @MainActor
    static func present(camera: Bool, _ done: @escaping (UIImage?) -> Void) {
        if ProcessInfo.processInfo.arguments.contains("-uiSamplePhoto") { done(sample()); return }
        if camera && !cameraAvailable { AppModel.shared.say("cm.errNone", kind: .info); return }
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              var vc = scene.keyWindow?.rootViewController ?? scene.windows.first?.rootViewController else { return }
        while let p = vc.presentedViewController { vc = p }
        let d = Delegate(done); current = d
        let pk = UIImagePickerController()
        pk.sourceType = camera ? .camera : .photoLibrary
        pk.delegate = d
        vc.present(pk, animated: true)
    }

    /// A wall with a doorway, drawn, for the screen tests.
    private static func sample() -> UIImage {
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 900), format: f).image { c in
            UIColor(red: 0.85, green: 0.82, blue: 0.76, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 0, width: 1200, height: 900))
            UIColor(red: 0.62, green: 0.48, blue: 0.34, alpha: 1).setFill(); c.fill(CGRect(x: 0, y: 720, width: 1200, height: 180))
            UIColor(red: 0.35, green: 0.30, blue: 0.27, alpha: 1).setFill(); c.fill(CGRect(x: 440, y: 260, width: 300, height: 460))
            UIColor.white.setFill(); c.fill(CGRect(x: 850, y: 250, width: 240, height: 200))
        }
    }
}

private let LOUPE_MAG: CGFloat = 2.5

/// What the hint says while a line's end is stuck: along an edge (both ends on it), to a corner, or to an edge.
private func snapHint(_ a: ESnapped, _ b: ESnapped) -> String? {
    if sharedEdge(a.snap, b.snap) != nil { return "mk.snapL" }
    if b.snap?.corner == true { return "mk.snapC" }
    return b.snap != nil ? "mk.snapE" : nil
}

private extension ESnapped {
    init(_ p: CGPoint) { self.init(x: Float(p.x), y: Float(p.y), snap: nil) }
    var cg: CGPoint { CGPoint(x: CGFloat(x), y: CGFloat(y)) }
}

struct MarkupScreen: View {
    let app: AppModel
    let pid: String?
    let iid: String
    @State private var photo: UIImage? = nil
    @State private var livePen: [CGPoint]? = nil
    @State private var liveLine: (CGPoint, CGPoint)? = nil
    @State private var faded: Set<String> = []
    /// A line whose end is being moved: drawn here while the stored one is hidden.
    @State private var liveEdit: MkEl? = nil
    /// Where the finger's point is on the screen while a line is drawn or an end moved: the loupe shows it.
    @State private var loupe: CGPoint? = nil
    /// The photo edges and corners the line's ends are stuck to (drawn blue), and the hint saying so.
    @State private var stuck: [ESnap] = []
    @State private var hint: String? = nil
    /// Zoom (1–4) and pan of the photo, and the canvas box.
    @State private var z: CGFloat = 1
    @State private var pan: CGPoint = .zero
    @State private var box: CGRect = .zero
    /// The photo's edges (part 2): nil while they are being found.
    @State private var edges: PhotoEdges? = nil
    @State private var g: Gest? = nil
    @State private var hold: DispatchWorkItem? = nil
    private struct Gest {
        let p0: CGPoint, down: CGPoint, lab: MkEl?, t: String, c: String
        var a0: ESnapped, start: CGPoint
        var pts: [CGPoint], b: CGPoint, hit: Set<String>, last: CGPoint, moved: CGFloat = 0
        var endHere: (MkEl, Int)? = nil, grab: (MkEl, Int)? = nil, waiting = false, edit: MkEl? = nil
    }
    private var ops: MarkOps { MarkOps.shared }

    var body: some View {
        if let it = ops.item(pid, iid) {
            let _ = ops.tick
            let ph = it.kind == "photo"
            let tool = ops.toolOf(it), col = ops.colorOf(it)
            let fmt = MkFmt.current()
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    GlassIconButton("back", tr("nt.back")) { app.pop() }.accessibilityIdentifier("back")
                    VStack(alignment: .leading, spacing: 0) {
                        T(dn(it.name), ui(18, 800, G.ink, lh: 1.2), lines: 1)
                        T(ops.place(pid, iid), ui(12, 400, G.ink2), lines: 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    GlassIconButton("undo", tr("common.undo"), iconSize: 20) { ops.undo(pid, iid) }.opacity(ops.canUndo(iid) ? 1 : 0.4)
                    GlassIconButton("redo", tr("common.redo"), iconSize: 20) { ops.redo(pid, iid) }.opacity(ops.canRedo(iid) ? 1 : 0.4)
                    if pid == nil { GlassIconButton("share", tr("cm.share"), iconSize: 20) { shareShot(it) } }
                    GlassIconButton("more", tr("common.menu"), iconSize: 20) {
                        app.sheet = pid == nil ? .shotMenu : .itemMenu(pid: pid!, wid: ops.wid(pid, iid) ?? "", iid: iid)
                    }
                    .accessibilityIdentifier("mk.menu")
                }
                .padding(.horizontal, 12).frame(height: 64)
                GeometryReader { geo in
                    let bx = CGRect(origin: .zero, size: geo.size)
                    let view = mkZoomBox(bx, z, pan)
                    let ed = ph && ops.edgesOn ? edges : nil
                    let offer = rectOffer(it)
                    ZStack {
                        Canvas { ctx, size in
                            let ppu = mkFit(mkViewBox(it, .edit), view).0
                            let hide: Set<String> = liveEdit.map { [$0.id] } ?? []
                            let letters = mkLetters(it)
                            let liveMarks: (GraphicsContext, CGFloat) -> Void = { c, zz in
                                let cc = MK_COL[col] ?? MK_COL["ink"]!
                                if let ps = livePen { c.stroke(mkPolyPath(ps), with: .color(cc), style: StrokeStyle(lineWidth: ops.width == 2 ? 18 : 8, lineCap: .round, lineJoin: .round)) }
                                if let l = liveLine { c.stroke(linePath(l.0, l.1), with: .color(cc), style: StrokeStyle(lineWidth: 7 / zz, lineCap: .butt, dash: [14 / zz, 10 / zz])) }
                                if let e = liveEdit { drawMark(c, e, fmt, zoom: zz, letter: letters[e.id]) }
                            }
                            let under: (GraphicsContext, CGFloat) -> Void = { c, k in
                                if let r = offer { drawRectOffer(c, r, k) }
                                if let ed { drawPhotoEdges(c, ed, k, stuck) }
                            }
                            drawMarkup(ctx, it, photo, view, fmt, .edit, faded: faded, hidden: hide, zoom: z, under: { under($0, ppu) }) { liveMarks($0, z) }
                            // the loupe: the photo around the finger, 2.5 times larger, above it (below it near the top)
                            if let s = loupe {
                                let rad: CGFloat = 60, l = mkLoupeAt(s, size, rad, 34)
                                let disc = CGRect(x: l.x - rad, y: l.y - rad, width: 2 * rad, height: 2 * rad)
                                ctx.fill(Path(ellipseIn: disc.insetBy(dx: -4, dy: -4).offsetBy(dx: 0, dy: 6)), with: .color(.black.opacity(0.28)))
                                var lc = ctx
                                lc.clip(to: Path(ellipseIn: disc))
                                lc.fill(Path(disc), with: .color(Color(argb: 0xFF161D30)))
                                drawMarkup(lc, it, photo, mkLoupeBox(view, s, l, LOUPE_MAG), fmt, .edit, faded: faded, hidden: hide, zoom: z * LOUPE_MAG,
                                           under: { under($0, ppu * LOUPE_MAG) }) { liveMarks($0, z * LOUPE_MAG) }
                                ctx.stroke(Path(ellipseIn: disc), with: .color(.white), lineWidth: 3)
                                for d in [CGPoint(x: 1, y: 0), CGPoint(x: -1, y: 0), CGPoint(x: 0, y: 1), CGPoint(x: 0, y: -1)] {
                                    let p = linePath(CGPoint(x: l.x + d.x * 7, y: l.y + d.y * 7), CGPoint(x: l.x + d.x * 16, y: l.y + d.y * 16))
                                    ctx.stroke(p, with: .color(.white), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    ctx.stroke(p, with: .color(MK_COL["red"]!), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                                }
                            }
                        }
                        MkTouch { ev in onTouch(it, ev, tool, col, fmt) }
                    }
                    .clipped()
                    .overlay(alignment: .topLeading) {
                        // the "Qirralar" switch: shows the photo's edges and snaps line ends to them
                        if ph {
                            HStack(spacing: 8) {
                                ZStack(alignment: ops.edgesOn ? .trailing : .leading) {
                                    Capsule().fill(ops.edgesOn ? G.cobalt : Color(argb: 0xFF5B6478)).frame(width: 30, height: 18)
                                    Circle().fill(.white).frame(width: 14, height: 14).padding(2)
                                }
                                .frame(width: 30, height: 18)
                                T(tr(ops.edgesOn && edges == nil ? "mk.edgesBusy" : "mk.edges"), ui(13.5, 700, .white), lines: 1)
                            }
                            .padding(.leading, 8).padding(.trailing, 12).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color(argb: 0xCC0F1626)))
                            .pressable(0.97) { ops.edgesOn.toggle() }
                            .accessibilityValue(Text(ops.edgesOn ? "on" : "off"))
                            .accessibilityIdentifier("mk.edges")
                            .padding(8)
                        }
                    }
                    .overlay(alignment: .top) {
                        // a clear rectangle (table top, door, cabinet front) on a photo with no dimensions yet: offer its sides as A and B
                        if let r = offer {
                            HStack(spacing: 8) {
                                T(tr("mk.rectT"), ui(13.5, 600, MK_COL["ink"]!, lh: 1.25), lines: 2).frame(maxWidth: .infinity, alignment: .leading)
                                T(tr("mk.rectUse"), ui(13.5, 700, .white), lines: 1).fixedSize().padding(.horizontal, 12).frame(minHeight: 40)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(G.cobalt))
                                    .pressable(0.97) { ops.useRect(pid, iid, r) }
                                    .accessibilityIdentifier("mk.rectUse")
                                MIcon("x", Color(argb: 0xFF475569), 18, 2.2).frame(width: 40, height: 40)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(argb: 0x0F0F172A)))
                                    .pressable(0.97, label: tr("common.close")) { ops.rectGone[iid] = true }
                                    .accessibilityIdentifier("mk.rectX")
                            }
                            .padding(.leading, 14).padding(.trailing, 6).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white.opacity(0.94)))
                            .padding(.horizontal, 8).padding(.top, 52)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        // zoomed in: the zoom and a tap back to the whole photo
                        if z > 1.02 {
                            HStack(spacing: 6) {
                                T(String(format: "%.1f", Double(z)).replacingOccurrences(of: ".", with: AppSettings.shared.lang == .en ? "." : ",") + "×", num(14, 700, .white), lines: 1)
                                MIcon("x", .white.opacity(0.7), 14, 2.2)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color(argb: 0xCC0F1626)))
                            .pressable(0.97, label: tr("mk.zoomReset")) { z = 1; pan = .zero }
                            .accessibilityIdentifier("mk.zoomReset")
                            .padding(8)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("mk.canvas")
                    .onAppear { box = bx }
                    .onChange(of: geo.size) { _, s in box = CGRect(origin: .zero, size: s); pan = mkClampPan(it, box, z, pan) }
                }
                .padding(10)
                .background(ph ? Color(argb: 0xFF0E1C36) : G.stage)
                if ph {
                    HStack(spacing: 8) {
                        MIcon("edit", G.ink2, 18, 2)
                        T(it.caption.trimmingCharacters(in: .whitespaces).isEmpty ? tr("mk.addCaption") : dn(it.caption), ui(14, 400, it.caption.isEmpty ? G.ink3 : G.ink), lines: 1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8).frame(minHeight: 44)
                    .background(G.sheet(0.8))
                    .overlay(alignment: .top) { Rectangle().fill(G.ink.opacity(0.08)).frame(height: 1) }
                    .pressable(0.99) { app.sheet = .mkCaption }
                    .accessibilityIdentifier("mk.caption")
                }
                // colours, pen width and what the tool does (prototype .mk-opts)
                HStack(spacing: 10) {
                    if tool != "eraser" {
                        ForEach(["ink", "cobalt", "red"], id: \.self) { k in
                            let on = col == k, cc = MK_COL[k]!
                            ZStack {
                                Circle().fill(on ? cc : G.ink.opacity(0.15)).frame(width: on ? 42 : 40, height: on ? 42 : 40)
                                Circle().fill(G.solid).frame(width: 38, height: 38)
                                Circle().fill(cc).frame(width: 34, height: 34)
                                if on { MIcon("check", .white, 16, 2.6) }
                            }
                            .frame(width: 44, height: 44)
                            .pressable(0.95, label: k) { ops.setColor(it, k) }
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                        if tool == "pen" {
                            HStack(spacing: 0) {
                                ForEach([(1, "mk.thin"), (2, "mk.thick")], id: \.0) { k, l in
                                    let on = ops.width == k
                                    T(tr(l), ui(13, on ? 600 : 500, on ? G.ink : G.ink2), lines: 1).fixedSize().padding(.horizontal, 10).frame(minHeight: 38)
                                        .background(RoundedRectangle(cornerRadius: 9).fill(on ? G.solid : .clear))
                                        .pressable(0.97) { ops.width = k }
                                }
                            }
                            .padding(3).background(RoundedRectangle(cornerRadius: 12).fill(G.ink.opacity(0.06)))
                        }
                    }
                    // while a line's end is stuck the hint says to what (blue), otherwise what the tool does
                    T(tr(hint ?? ("mk.h." + tool)), ui(12, hint != nil ? 600 : 400, hint != nil ? G.cobalt2 : G.ink3, lh: 1.3), lines: 3).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12).padding(.vertical, 6).frame(minHeight: 60)
                .background(G.sheet(0.8))
                .overlay(alignment: .top) { Rectangle().fill(G.ink.opacity(0.08)).frame(height: 1) }
                MkTools(it: it, tool: tool)
            }
            .background(G.paper.ignoresSafeArea())
            .task(id: it.src) {
                guard let src = it.src else { photo = nil; edges = .none; return }
                photo = await Task.detached { PhotoFiles.load(src, maxW: 1400) }.value
                // the photo's edges, found once in the background
                if ph {
                    let w = Float(it.W), h = Float(it.hh)
                    let found = await Task.detached { findEdges(src, w, h) }.value
                    edges = found
                    if ops.edgesOn && found.segs.isEmpty { app.say("mk.noEdges", kind: .info) }
                } else { edges = .none }
            }
        }
    }

    /// The rectangle offer is open while the photo has a found rectangle, no dimension yet, and was not closed.
    private func rectOffer(_ it: Item) -> ERect? {
        guard it.kind == "photo", ops.edgesOn, let r = edges?.rect, ops.rectGone[it.id] != true,
              !it.els.contains(where: { $0.t == "dim" }), liveLine == nil, liveEdit == nil else { return nil }
        return r
    }

    private func q(_ it: Item, _ view: CGRect, _ p: CGPoint) -> CGPoint {
        let o = mkToItem(it, view, p)
        return CGPoint(x: min(max(o.x, 4), CGFloat(it.W) - 4), y: min(max(o.y, 4), CGFloat(it.hh) - 4))
    }
    private func onScreen(_ it: Item, _ view: CGRect, _ p: CGPoint) -> CGPoint {
        let (k, ox, oy) = mkFit(mkViewBox(it, .edit), view); return CGPoint(x: ox + p.x * k, y: oy + p.y * k)
    }
    private func r1(_ v: CGFloat) -> Double { (Double(v) * 10).rounded() / 10 }

    private func erase(_ it: Item, _ st: inout Gest, _ x: CGPoint) {
        for e in it.els where !st.hit.contains(e.id) && mkNear(e, x) { st.hit.insert(e.id) }
        faded = st.hit
    }

    /* ---------- snapping onto the photo's edges (part 2) ---------- */

    private func edgesNow(_ it: Item) -> PhotoEdges? { it.kind == "photo" && ops.edgesOn ? edges : nil }
    /// A corner within about 6 mm of the finger first, else an edge within about 4 mm (ppu: screen points per item unit).
    private func snapAt(_ it: Item, _ p: CGPoint, _ ppu: CGFloat) -> ESnapped {
        guard let ed = edgesNow(it) else { return ESnapped(p) }
        return edgeSnap(ed, Float(p.x), Float(p.y), Float(38 / ppu), Float(25 / ppu))
    }
    private func stuckAt(_ it: Item, _ p: [Double]) -> ESnap? {
        guard let ed = edgesNow(it), p.count > 1 else { return nil }
        return edgeSnap(ed, Float(p[0]), Float(p[1]), 1.5, 1.5).snap
    }
    /// A line from a to the finger at to: the end snaps onto the edges (else to 45°); two ends on one edge lie along it.
    private func place(_ it: Item, _ a: ESnapped, _ to: CGPoint, _ ppu: CGFloat) -> (ESnapped, ESnapped) {
        let s = snapAt(it, to, ppu)
        let e2 = s.snap != nil ? s : ESnapped(snap45(a.cg, to, AppSettings.shared.angleSnap))
        if let ed = edgesNow(it) { return lockAlong(ed, a, e2) }
        return (a, e2)
    }
    private func moveEnd(_ it: Item, _ st: inout Gest, _ to: CGPoint, _ ppu: CGFloat) -> MkEl? {
        guard let gr = st.grab, gr.0.pts.count > 1 else { return nil }
        let (e, i) = gr
        let o = e.pts[1 - i]
        let (lo, ln) = place(it, ESnapped(x: Float(o[0]), y: Float(o[1]), snap: stuckAt(it, o)), to, ppu)
        st.b = ln.cg
        stuck = [lo.snap, ln.snap].compactMap { $0 }; hint = snapHint(lo, ln)
        var m = e
        let np = [r1(ln.cg.x), r1(ln.cg.y)], op = [r1(lo.cg.x), r1(lo.cg.y)]
        m.pts = i == 0 ? [np, op] : [op, np]
        return m
    }

    private func clearLive() { livePen = nil; liveLine = nil; faded = []; liveEdit = nil; loupe = nil; stuck = []; hint = nil }
    private func abandon() { hold?.cancel(); hold = nil; g = nil; clearLive() }

    /* ---------- touches: one finger draws or moves a line's end, two fingers zoom (part 1) ---------- */

    private func onTouch(_ it: Item, _ ev: MkTouchEvent, _ t: String, _ c: String, _ fmt: MkFmt) {
        let view = mkZoomBox(box, z, pan)
        let ppu = mkFit(mkViewBox(it, .edit), view).0
        switch ev {
        case .pinch(let k, let m, let mv):
            if g != nil { abandon() }
            let (nz, np) = mkPinch(it, box, z, pan, k, m, mv); z = nz; pan = np
        case .cancel: abandon()
        case .down(let p): down(it, p, t, c, fmt, view, ppu)
        case .move(let p): move(it, p, t, view, ppu)
        case .up: up(it, t, c)
        }
    }

    private func down(_ it: Item, _ p: CGPoint, _ t: String, _ c: String, _ fmt: MkFmt, _ view: CGRect, _ ppu: CGFloat) {
        if app.sheet != nil { return }
        let p0 = q(it, view, p)
        let lab = t != "eraser" && t != "pen" ? mkLabelAt(it, p0, fmt, zoom: z) : nil
        let lines = t == "line" || t == "dim" || t == "arrow"
        // a new line starts on the corner or edge under the finger
        let a0 = lines ? snapAt(it, p0, ppu) : ESnapped(p0)
        var st = Gest(p0: p0, down: p, lab: lab, t: t, c: c, a0: a0, start: a0.cg, pts: [p0], b: p0, hit: [], last: p0)
        // holding still on a line's end picks it up to move it; dragging straight away draws a new line from there
        if lab == nil && lines, let eh = mkEndAt(it, p0, 24 / ppu) {
            st.endHere = eh; st.waiting = true
            let w = DispatchWorkItem {
                guard var s = g, s.waiting, let e = s.endHere else { return }
                s.waiting = false; s.grab = e
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                let v = mkZoomBox(box, z, pan), k = mkFit(mkViewBox(it, .edit), v).0
                let p0 = s.p0; let m = moveEnd(it, &s, p0, k); s.edit = m; liveEdit = m; loupe = onScreen(it, v, s.b)
                g = s
            }
            hold = w
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32, execute: w)
        }
        if t == "pen" { livePen = [p0] } else if t == "eraser" { erase(it, &st, p0) }
        g = st
    }

    private func move(_ it: Item, _ p: CGPoint, _ t: String, _ view: CGRect, _ ppu: CGFloat) {
        guard var st = g else { return }
        st.moved = max(st.moved, (p - st.down).len)
        if st.waiting {
            // moved on before the hold: a new line from the end
            if st.moved > 10 { st.waiting = false; hold?.cancel(); hold = nil } else { g = st; return }
        }
        let qq = q(it, view, p)
        if st.grab != nil { let m = moveEnd(it, &st, qq, ppu); st.edit = m; liveEdit = m; loupe = onScreen(it, view, st.b); g = st; return }
        if st.lab != nil || t == "text" { g = st; return }
        switch t {
        case "pen": if let l = st.pts.last, hypot(qq.x - l.x, qq.y - l.y) > 4 { st.pts.append(qq); livePen = st.pts }
        case "line", "dim", "arrow":
            let (la, lb) = place(it, st.a0, qq, ppu); st.start = la.cg; st.b = lb.cg
            liveLine = (st.start, st.b)
            stuck = [la.snap, lb.snap].compactMap { $0 }; hint = snapHint(la, lb)
            if st.moved > 12 { loupe = onScreen(it, view, st.b) }
        case "eraser":
            let n = max(1, Int(hypot(qq.x - st.last.x, qq.y - st.last.y) / 12))
            for i in 1...n { erase(it, &st, st.last + (qq - st.last) * (CGFloat(i) / CGFloat(n))) }
            st.last = qq
        default: break
        }
        g = st
    }

    private func up(_ it: Item, _ t: String, _ c: String) {
        hold?.cancel(); hold = nil
        defer { g = nil; clearLive() }
        guard let st = g else { return }
        let tap = st.moved < 12
        if let gr = st.grab {
            let e = gr.0
            if let m = st.edit, m.pts != e.pts, m.pts.count > 1, hypot(m.pts[0][0] - m.pts[1][0], m.pts[0][1] - m.pts[1][1]) >= 30 {
                ops.change(pid, iid) { els in els.map { $0.id == e.id ? m : $0 } }
            }
            return
        }
        if let lab = st.lab { if tap { if lab.t == "text" { app.sheet = .mkText(eid: lab.id, x: 0, y: 0) } else { openDim(lab) } }; return }
        switch t {
        case "text": if tap { app.sheet = .mkText(eid: nil, x: Double(st.p0.x), y: Double(st.p0.y)) }
        case "pen":
            let pts = st.pts.map { [r1($0.x), r1($0.y)] }, w = ops.width
            ops.change(pid, iid) { $0 + [MkEl(id: uid(), t: "pen", pts: pts, c: c, w: w)] }
        case "eraser": if !st.hit.isEmpty { let hit = st.hit; ops.change(pid, iid) { $0.filter { !hit.contains($0.id) } } }
        default:
            guard hypot(st.b.x - st.start.x, st.b.y - st.start.y) >= 30 else { return }
            let el = MkEl(id: uid(), t: t, pts: [[r1(st.start.x), r1(st.start.y)], [r1(st.b.x), r1(st.b.y)]], c: c)
            ops.change(pid, iid) { $0 + [el] }
            if t != "arrow" { openDim(el) }
        }
    }

    private func openDim(_ e: MkEl) {
        ops.recv = nil
        ops.laserText = e.src == "laser" ? e.v.map { Geo.fmtLen($0, AppSettings.shared.unit, AppSettings.shared.lang == .en, full: true) } : nil
        app.sheet = .mkDim(eid: e.id)
    }
}

/// Straight lines snap to every 45° when angle snapping is on (prototype snap).
private func snap45(_ a: CGPoint, _ b: CGPoint, _ on: Bool) -> CGPoint {
    guard on else { return b }
    let dx = b.x - a.x, dy = b.y - a.y, l = hypot(dx, dy), ang = atan2(dy, dx), st = CGFloat.pi / 4
    let k = (ang / st).rounded() * st
    return abs(ang - k) < 0.14 ? CGPoint(x: a.x + cos(k) * l, y: a.y + sin(k) * l) : b
}

private struct MkTools: View {
    let it: Item
    let tool: String
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 33, style: .continuous)
        HStack(spacing: 2) {
            ForEach(MK_TOOLS[it.kind] ?? [], id: \.self) { k in
                let on = tool == k
                VStack(spacing: 3) {
                    MIcon(k, on ? G.cobalt2 : G.slate, 22, 2)
                    T(tr("mk." + k), ui(11, on ? 700 : 600, on ? G.cobalt2 : G.slate), lines: 1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 27, style: .continuous).fill(on ? G.glass(0.9) : .clear))
                .pressable(0.96) { MarkOps.shared.setTool(it, k) }
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("mk." + k)
            }
        }
        .padding(6).frame(height: 66)
        .glassBlur(shape, tint: G.sheet(0.5))
        .topHighlight(shape, 0.95)
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 12)
        .bottomBar()
    }
}

/// The item drawn at up to 1600 px on its long side (twice its units at most), on white.
@MainActor
func markImage(_ it: Item) -> UIImage? {
    let k = min(2, 1600 / CGFloat(max(it.W, it.hh)))
    let w = CGFloat(it.W) * k, h = CGFloat(it.hh) * k
    let photo = it.src.flatMap { PhotoFiles.load($0) }
    let f = MkFmt.current()
    let r = ImageRenderer(content: Canvas { ctx, size in
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
        Theme.shared.onPaper { drawMarkup(ctx, it, photo, CGRect(origin: .zero, size: size), f, .report) }
    }.frame(width: w, height: h))
    r.scale = 1
    return r.uiImage
}

/// The picture with its lines and numbers as one JPEG, through the phone's share sheet (prototype shotShare).
@MainActor
func shareShot(_ it: Item) {
    guard let img = markImage(it), let data = img.jpegData(compressionQuality: 0.9) else { AppModel.shared.say("cm.shareErr", kind: .info); return }
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("share", isDirectory: true)
    try? FileManager.default.removeItem(at: dir)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent(pdfName("METRX", dn(it.name)).replacingOccurrences(of: ".pdf", with: ".jpg"))
    do { try data.write(to: url); presentShare(url) } catch { AppModel.shared.say("cm.shareErr", kind: .info) }
}

/* ---------------- sheets ---------------- */

struct MarkupSheet: View {
    let app: AppModel
    let sheet: Sheet
    var body: some View {
        switch sheet {
        case .mkDim(let eid): DimSheet(app: app, eid: eid)
        case .mkText(let eid, let x, let y): TextSheet(app: app, eid: eid, x: x, y: y)
        case .mkCaption: CaptionSheet(app: app)
        case .shotMenu: ShotMenuSheet(app: app)
        case .shotDel: ShotDelSheet(app: app)
        case .shotTo: ShotToSheet(app: app)
        case .cameraPick: CameraPickSheet(app: app)
        default: EmptyView()
        }
    }
    static func handles(_ s: Sheet) -> Bool {
        switch s { case .mkDim, .mkText, .mkCaption, .shotMenu, .shotDel, .shotTo, .cameraPick: return true; default: return false }
    }
}

/// The open markup page's item (pid nil: a Measure page picture).
private func mkRoute() -> (String?, String)? { if case .markup(let pid, let iid) = AppModel.shared.top { return (pid, iid) }; return nil }

private enum MF2: Hashable { case v }

/// A line's length (prototype SHEETS.mkDim): from the laser when it is connected, or typed.
private struct DimSheet: View {
    let app: AppModel
    let eid: String
    @State private var v = ""
    @State private var tried = false
    @State private var loaded = false
    @FocusState private var focus: MF2?
    private var ops: MarkOps { MarkOps.shared }
    var body: some View {
        let s = AppSettings.shared, en = s.lang == .en, on = s.laser == .connected
        if let r = mkRoute(), let it = ops.item(r.0, r.1), let e = it.els.first(where: { $0.id == eid }) {
            let parsed = Geo.lenErr(v, Geo.dimMax("A"), s.unit, en)
            // the sheet says which line it is (the photo is behind it, often covered by the keyboard)
            GlassSheet(tr("mk.dimT") + (mkLetters(it)[e.id].map { " " + $0 } ?? ""), onClose: { app.sheet = nil }) {
                if !on {
                    // no laser: typing works; "Ulash" opens the radar to connect one
                    HStack(alignment: .top, spacing: 8) {
                        MIcon("btoff", G.ink2, 18, 2); T(tr("mk.noLaser"), ui(13.5, 400, G.ink2, lh: 1.4)).frame(maxWidth: .infinity, alignment: .leading)
                        T(tr("ms.connect"), ui(14, 700, G.cobalt)).padding(.horizontal, 6).frame(minHeight: 44).pressable(0.96) { app.openLaser() }
                    }
                } else if let recv = ops.recv {
                    HStack(spacing: 10) {
                        MIcon("laser", G.amberInk, 18, 2)
                        T(tr("mk.recv", ["v": ""]) + Geo.fmtLen(recv, s.unit, en, full: true) + " " + unitName(), ui(14, 600)).frame(maxWidth: .infinity, alignment: .leading)
                        GBtn(tr("mk.use"), height: 44, fontSize: 14, fill: false) { let t = Geo.fmtLen(recv, s.unit, en, full: true); v = t; ops.laserText = t; ops.recv = nil }
                    }
                    .padding(.leading, 12).padding(.trailing, 6).padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 12).fill(G.amberWash))
                    .overlay(alignment: .leading) { Rectangle().fill(G.amberInk).frame(width: 3) }
                } else {
                    GBtn(tr("mk.laser"), kind: .secondary, icon: "laser") {
                        if LaserRouter.shared.isReal { LaserRouter.shared.waitFor { mm in MarkOps.shared.recv = mm }; return }
                        // made-up values only with the screen tests' simulator
                        guard LaserRouter.shared.simOn else { app.openLaser(); return }
                        let base = e.v ?? (800 + Int.random(in: 0...3400))
                        ops.recv = max(50, base + kround((Double.random(in: 0..<1) - 0.5) * Double(e.v != nil ? 6 : 40)))
                    }
                    .accessibilityIdentifier("mk.laserBtn")
                }
                NumField(label: tr("mk.value"), value: $v, suffix: unitName(), error: v.isEmpty ? nil : errText(parsed), showError: tried || !v.isEmpty, focus: $focus, me: .v, id: "mk.value")
                if it.kind == "photo" { HStack(alignment: .top, spacing: 8) { MIcon("info", G.ink2, 18, 2); T(tr("mk.photoNote"), ui(13, 400, G.ink2, lh: 1.4)) } }
                HStack(spacing: 6) { MIcon("trash", G.err, 18, 2); T(tr("mk.delLine"), ui(15, 600, G.err)) }
                    .padding(.horizontal, 4).frame(minHeight: 44)
                    .pressable(0.97) { ops.change(r.0, r.1) { $0.filter { $0.id != eid } }; app.sheet = nil }
            } footer: {
                HStack(spacing: 8) {
                    GBtn(tr("mk.later"), kind: .secondary) { app.sheet = nil }
                    GBtn(tr("common.save"), enabled: !v.isEmpty && parsed.value != nil) {
                        guard let mm = parsed.value else { tried = true; return }
                        let src = ops.laserText != nil && ops.laserText == v.trimmingCharacters(in: .whitespaces) ? "laser" : "manual"
                        ops.change(r.0, r.1) { $0.map { x in var y = x; if x.id == eid { y.v = Int(mm); y.src = src }; return y } }
                        app.sheet = nil
                    }
                    .accessibilityIdentifier("mk.save")
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                v = e.v.map { Geo.fmtLen($0, s.unit, en, full: true) } ?? ""
                if !on { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focus = .v } }
            }
            // a real laser's measurement while this sheet is open is this line's: it waits here to be used, as a simulated one
            .laserSink { mm in MarkOps.shared.recv = mm; return true }
        }
    }
}

private enum TF: Hashable { case t }

/// A text mark: new at the tapped point, or changed (prototype SHEETS.mkText). Empty text removes it.
private struct TextSheet: View {
    let app: AppModel
    let eid: String?
    let x: Double
    let y: Double
    @State private var v = ""
    @State private var loaded = false
    @FocusState private var focus: TF?
    private var ops: MarkOps { MarkOps.shared }
    var body: some View {
        if let r = mkRoute(), let it = ops.item(r.0, r.1) {
            let e = eid.flatMap { id in it.els.first { $0.id == id } }
            GlassSheet(tr("mk.textT"), onClose: { app.sheet = nil }) {
                GField(label: tr("mk.textT"), value: $v, placeholder: tr("mk.textPh"), focus: $focus, me: .t, submit: .done, onSubmit: { save(r, it, e) })
                if e != nil {
                    HStack(spacing: 6) { MIcon("trash", G.err, 18, 2); T(tr("mk.delText"), ui(15, 600, G.err)) }
                        .padding(.horizontal, 4).frame(minHeight: 44)
                        .pressable(0.97) { ops.change(r.0, r.1) { els in els.filter { $0.id != eid } }; app.sheet = nil }
                }
            } footer: {
                GBtn(tr("common.save")) { save(r, it, e) }.accessibilityIdentifier("mk.textSave")
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true; v = e?.txt.map { dn($0) } ?? ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focus = .t }
            }
        }
    }
    private func save(_ r: (String?, String), _ it: Item, _ e: MkEl?) {
        let t = v.trimmingCharacters(in: .whitespaces)
        if let e {
            ops.change(r.0, r.1) { els in
                t.isEmpty ? els.filter { $0.id != e.id } : els.map { x in var y = x; if x.id == e.id && dn(x.txt ?? "") != t { y.txt = t }; return y }
            }
        } else if !t.isEmpty {
            let c = ops.colorOf(it), px = x, py = y
            ops.change(r.0, r.1) { $0 + [MkEl(id: uid(), t: "text", pts: [[px, py]], c: c, txt: t)] }
        }
        app.sheet = nil
    }
}

private struct CaptionSheet: View {
    let app: AppModel
    @State private var v = ""
    @State private var loaded = false
    @FocusState private var focus: TF?
    var body: some View {
        if let r = mkRoute(), let it = MarkOps.shared.item(r.0, r.1) {
            GlassSheet(tr("mk.caption"), onClose: { app.sheet = nil }) {
                GField(label: tr("mk.caption"), value: $v, placeholder: tr("mk.captionPh"), focus: $focus, me: .t, submit: .done, onSubmit: { save(r) })
            } footer: {
                GBtn(tr("common.save")) { save(r) }.accessibilityIdentifier("mk.captionSave")
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true; v = dn(it.caption)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { focus = .t }
            }
        }
    }
    private func save(_ r: (String?, String)) {
        let t = v.trimmingCharacters(in: .whitespaces)
        MarkOps.shared.update(r.0, r.1) { if dn($0.caption) != t { $0.caption = t } }
        app.sheet = nil
    }
}

/* ---------------- the Measure page's pictures ---------------- */

/// "Kamera" on the Measure page: the live camera, or a photo to draw on (prototype SHEETS.camPick).
private struct CameraPickSheet: View {
    let app: AppModel
    var body: some View {
        GlassSheet(tr("cm.pickT"), onClose: { app.sheet = nil }) {
            VStack(spacing: 10) {
                BigRow(icon: "laser", title: "cm.live", desc: "cm.liveD") { app.sheet = nil; app.push(.liveCam) }.accessibilityIdentifier("cm.live")
                BigRow(icon: "camera", title: "cm.photo", desc: "cm.photoD") { MarkOps.shared.pickPhoto(PhotoTarget(pid: nil, wid: nil), camera: true) }
                    .accessibilityIdentifier("cm.photo")
            }
            .padding(.bottom, 6)
        }
    }
}

private struct ShotMenuSheet: View {
    let app: AppModel
    var body: some View {
        if let r = mkRoute(), let it = MarkOps.shared.item(r.0, r.1) {
            GlassSheet(dn(it.name), onClose: { app.sheet = nil }) {
                ListBox {
                    ActionRow(icon: "share", label: tr("cm.share")) { app.sheet = nil; shareShot(it) }
                    Hairline()
                    ActionRow(icon: "layers", label: tr("cm.toProj")) { app.sheet = .shotTo }.accessibilityIdentifier("cm.toProj")
                    Hairline()
                    ActionRow(icon: "trash", label: tr("cm.del"), danger: true) { app.sheet = .shotDel }
                }
            }
        }
    }
}

private struct ShotDelSheet: View {
    let app: AppModel
    var body: some View {
        if let r = mkRoute() {
            GlassSheet(tr("cm.delQ"), onClose: { app.sheet = nil }) {
                T(tr("cm.delB"), ui(15, 400, G.ink2, lh: 1.45))
            } footer: {
                HStack(spacing: 8) {
                    GBtn(tr("common.cancel"), kind: .secondary) { app.sheet = nil }
                    GBtn(tr("cm.del"), kind: .danger, icon: "trash") {
                        AppSettings.shared.saveShots(AppSettings.shared.shots.filter { $0.id != r.1 })
                        app.sheet = nil; app.pop(); app.say("cm.deleted")
                    }
                }
            }
        }
    }
}

/// Into a project: the picture becomes an ordinary photo of that workspace, so it can also go into the PDF.
private struct ShotToSheet: View {
    let app: AppModel
    var body: some View {
        if let r = mkRoute() {
            let rows = Store.shared.projects.flatMap { p in p.floors.map { (p, $0) } }
            GlassSheet(tr("cm.toT"), onClose: { app.sheet = nil }) {
                if rows.isEmpty { HStack(alignment: .top, spacing: 8) { MIcon("info", G.ink2, 18, 2); T(tr("cm.toNone"), ui(14, 400, G.ink2, lh: 1.4)) } }
                else {
                    ListBox {
                        ForEach(Array(rows.enumerated()), id: \.offset) { i, pw in
                            let p = pw.0, w = pw.1
                            if i > 0 { Hairline() }
                            HStack(spacing: 12) {
                                MIcon("layers", G.cobalt, 20, 2).frame(width: 36, height: 36).background(RoundedRectangle(cornerRadius: 12).fill(G.cobalt.opacity(0.12)))
                                VStack(alignment: .leading, spacing: 0) { T(floorName(w), ui(15.5, 600)); T(dn(p.name), ui(13, 400, G.ink2)) }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                MIcon("chev", G.ink3, 18, 2)
                            }
                            .padding(.horizontal, 4).frame(minHeight: 60)
                            .pressable(0.99) { move(r.1, p, w) }
                            .accessibilityIdentifier("cm.toWs")
                        }
                    }
                }
            }
        }
    }
    private func move(_ iid: String, _ p: Project, _ w: Workspace) {
        guard var it = AppSettings.shared.shots.first(where: { $0.id == iid }) else { return }
        AppSettings.shared.saveShots(AppSettings.shared.shots.filter { $0.id != iid })
        it.edited = nowMs(); it.rep = nil
        let moved = it
        Store.shared.update(p.id) { pp in if let i = pp.floors.firstIndex(where: { $0.id == w.id }) { pp.floors[i].items.append(moved) } }
        app.sheet = nil; app.pop(); app.say("cm.moved", ["w": floorName(w)])
    }
}
