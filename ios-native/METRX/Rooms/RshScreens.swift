import SwiftUI
import UIKit

/*
 * The room-shape flow's screens (room-shapes build spec §2; Android ui/rooms/RoomFlow.kt): the shape cards, the free
 * sketch (the builder's Editor/SketchScreen.swift), the walls one at a time, the height, the doors, windows and pipes,
 * and the summary. One page (Route.roomShape) shows the draft's current screen; Back steps back inside the flow.
 */

private let MIRROR_IC = "M12 3v18M9 7L3.5 17H9zM15 7l5.5 10H15z"
private let ROTATE_IC = "M20 12a8 8 0 11-2.3-5.6M20 4v5h-5"
private let HAND_IC = "M8 13V5.5a1.5 1.5 0 013 0V11m0-1.5V4a1.5 1.5 0 013 0v6m0-4.5a1.5 1.5 0 013 0V12m0-4a1.5 1.5 0 013 0v6.5A7.5 7.5 0 0112.5 22h-.7a6 6 0 01-5-2.7L4.2 15a1.6 1.6 0 012.5-2z"

struct RoomShapeScreen: View {
    let app: AppModel
    let pid: String
    let key: String
    @State private var kb = false
    @State private var backToken = 0

    var body: some View {
        Group {
            if let d = RshDrafts.get(key) {
                screen(d)
                    .onAppear {
                        BackOwner.seq += 1; backToken = BackOwner.seq; BackOwner.last = backToken
                        app.backOverride = { rshBack(app, d) }
                    }
                    .onDisappear { if BackOwner.last == backToken { app.backOverride = nil; BackOwner.last = 0 } }
                    // a real laser's measurement goes into the size being asked
                    .laserSink { mm in setFromLaser(d, mm) }
            } else {
                Color.clear.onAppear { app.pop() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in kb = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in kb = false }
    }

    @ViewBuilder private func screen(_ d: RshDraft) -> some View {
        switch d.screen {
        case "sketch":
            SketchScreen(app: app, pid: pid, wid: d.wid ?? "", name: d.name, onShape: { mm in sketchDone(app, d, mm) }, onClose: { go(d, "shape") })
        case "walls": WallsStep(app: app, d: d, kb: kb)
        case "height": HeightStep(app: app, d: d, kb: kb)
        case "ops":
            if let op = d.op {
                if op.stage == "wall" { OpWall(app: app, d: d, op: op) } else { OpNum(app: app, d: d, op: op, kb: kb) }
            } else { OpsList(app: app, d: d) }
        case "summary": SummaryStep(app: app, d: d)
        default: ShapeStep(app: app, d: d)
        }
    }
}

/* ---------------- moving around ---------------- */

/// Moves to another screen of the flow; the height step starts from the height kept, selected.
private func go(_ d: RshDraft, _ s: String) {
    d.heard = nil; d.err = nil
    if s == "height" { d.hIn = rshFieldText(d.height, rshUnit(d)); d.hFresh = true; d.hErr = nil }
    if s == "ops" { d.op = nil }
    d.screen = s
}

/// Opens asked value i (n: the free sketch's diagonal), with its value selected when it has one.
private func setStep(_ d: RshDraft, _ i: Int) {
    let n = rshAsks(d).count
    d.step = i
    let v = i < n ? d.vals[i] : d.diag
    d.input = v.map { rshFieldText($0, rshUnit(d)) } ?? ""
    d.fresh = !d.input.isEmpty; d.err = nil; d.heard = nil
}

private func rshBack(_ app: AppModel, _ d: RshDraft) {
    d.heard = nil
    switch d.screen {
    case "shape": RshDrafts.map[d.key] = nil; app.pop()
    case "sketch": go(d, "shape")
    case "walls":
        if d.ret { d.ret = false; go(d, "summary") }
        else if d.step > 0 { setStep(d, d.step - 1) }
        else { go(d, d.shape == "free" ? "sketch" : "shape") }
    case "height":
        if d.ret { d.ret = false; go(d, "summary") }
        else { let n = rshAsks(d).count; setStep(d, d.shape == "free" ? n : max(0, n - 1)); go(d, "walls") }
    case "ops": if let op = d.op { opBack(d, op) } else { go(d, "height") }
    case "summary": go(d, "ops")
    default: app.pop()
    }
}

/// A laser value into the field being asked (the laser button, or a real laser's measurement); false when no field shows.
@discardableResult private func setFromLaser(_ d: RshDraft, _ mm: Int) -> Bool {
    let unit = rshUnit(d)
    let t = rshFieldText(mm, unit)
    switch d.screen {
    case "walls": d.input = t; d.fresh = false; d.err = nil
    case "height": d.hIn = t; d.hFresh = false; d.hErr = nil
    case "ops":
        guard var op = d.op, op.stage == "num" else { return false }
        op.input = t; op.fresh = false; op.err = nil; d.op = op
    default: return false
    }
    d.heard = nil; d.flash += 1; Haptic.confirm()
    return true
}

/// A voice value into the field being asked, keeping what it replaced for "Bekor".
private func setFromVoice(_ d: RshDraft, _ mm: Int, _ words: String) {
    let t = rshFieldText(mm, rshUnit(d))
    switch d.screen {
    case "walls": d.heard = (d.input, words); d.input = t; d.fresh = false; d.err = nil
    case "height": d.heard = (d.hIn, words); d.hIn = t; d.hFresh = false; d.hErr = nil
    case "ops":
        guard var op = d.op else { return }
        d.heard = (op.input, words); op.input = t; op.fresh = false; op.err = nil; d.op = op
    default: return
    }
    d.flash += 1; Haptic.confirm()
}

/// A laser (words nil) or voice value into the field being asked.
private func takeValue(_ d: RshDraft, _ mm: Int, _ words: String?) {
    if let words { setFromVoice(d, mm, words) } else { _ = setFromLaser(d, mm) }
}

private func unVoice(_ d: RshDraft) {
    guard let h = d.heard else { return }
    switch d.screen {
    case "walls": d.input = h.before
    case "height": d.hIn = h.before
    case "ops": if var op = d.op { op.input = h.before; d.op = op }
    default: break
    }
    d.heard = nil; Haptic.tick()
}

/* ---------------- the page parts ---------------- */

/// The compact progress: Shakl, Devorlar, Balandlik, Eshik…, Xulosa.
private struct RProg: View {
    let cur: Int
    var body: some View {
        let labels = ["rsh.p.shape", "rsh.p.walls", "rsh.p.height", "rsh.p.ops", "rsh.p.sum"]
        HStack(spacing: 2) {
            ForEach(labels.indices, id: \.self) { i in
                let done = i < cur, on = i == cur
                VStack(spacing: 2) {
                    ZStack {
                        // the line from the step before (mockup .ps::before): blue once this step is reached
                        if i > 0 {
                            Capsule().fill(done || on ? G.cobalt : G.ink.opacity(0.12)).frame(width: 48, height: 2).offset(x: -36)
                        }
                        Circle().fill(done ? G.cobalt : G.solid)
                        Circle().strokeBorder(done || on ? G.cobalt : G.ink.opacity(0.12), lineWidth: 2)
                        if done { MIcon("check", .white, 12, 3) } else { T("\(i + 1)", ui(11, 800, on ? G.cobalt2 : G.ink3)) }
                    }
                    .frame(width: 22, height: 22)
                    T(tr(labels[i]), ui(10.5, 700, on ? G.cobalt2 : done ? G.ink2 : G.ink3), align: .center, lines: 1).minimumScaleFactor(0.8)
                }
                .padding(.vertical, 3).frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(on ? G.cobalt.opacity(0.1) : .clear))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A page of the flow: the header (Back, the title on two lines, the progress), the scrolling body and the bottom bar.
private struct RshPage<Content: View>: View {
    let title: String
    let sub: String?
    let prog: Int?
    let back: () -> Void
    let bar: RBar
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) {
            UXTop {
                UXTopBar(title: title, sub: sub, back: back)
                if let prog { RProg(cur: prog).padding(.horizontal, 12).padding(.bottom, 8) }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) { content }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            bar
        }
    }
}

/// The bottom bar: one big button within thumb reach.
private struct RBar: View {
    let label: String
    var icon: String? = nil
    var enabled = true
    var secondary = false
    var id = "rsh.next"
    let action: () -> Void
    var body: some View {
        GBtn(label, kind: secondary ? .secondary : .primary, icon: icon, enabled: enabled, height: 54, lines: 2) { action() }
            .accessibilityIdentifier(id)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background { ZStack { Rectangle().fill(.ultraThinMaterial); Rectangle().fill(barTint) }.ignoresSafeArea(edges: .bottom) }
            .overlay(alignment: .top) { Rectangle().fill(G.rim).frame(height: 1) }
            .bottomBar()
    }
}

/// Ko‘zgu or Burish.
private struct ToolBtn: View {
    let icon: String
    let label: String
    var id = ""
    /// False: the words never shrink (so ViewThatFits can tell when they do not fit side by side).
    var shrink = true
    let action: () -> Void
    var body: some View {
        HStack(spacing: 5) {
            PathIcon(icon, G.cobalt2, 16, 2.2)
            T(label, ui(12.5, 800, G.cobalt2), lines: 1).minimumScaleFactor(shrink ? 0.8 : 1).fixedSize(horizontal: !shrink, vertical: false)
        }
        .padding(.horizontal, 8).frame(maxWidth: .infinity, minHeight: 36)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(G.cobalt.opacity(0.11)))
        .pressable(0.97) { Haptic.tick(); action() }
        .accessibilityIdentifier(id)
    }
}

/// The plan picture's box, with Ko‘zgu / Burish on it for the shapes that turn (tools).
private struct PicBox<Content: View>: View {
    let height: CGFloat
    var tools: RshDraft? = nil
    @ViewBuilder let content: Content
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        ZStack(alignment: .topTrailing) {
            content
            if let d = tools, d.shape != "free" {
                VStack(spacing: 6) {
                    ToolBtn(icon: MIRROR_IC, label: tr("rsh.mirror"), id: "rsh.mirror") { d.mir.toggle() }
                    ToolBtn(icon: ROTATE_IC, label: tr("rsh.rotate"), id: "rsh.rotate") { d.rot = (d.rot + 1) % 4 }
                }
                .frame(width: 104).padding(8)
            }
        }
        .frame(maxWidth: .infinity).frame(height: height)
        .background(shape.fill(rshPaper))
        .clipShape(shape)
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
    }
}

/// Lengths on the plan in the flow's unit.
private func lenFmt(_ d: RshDraft) -> (Double) -> String { let u = rshUnit(d); return { lenWords(Int($0.rounded()), u) } }

/* ---------------- 1. the shape ---------------- */

private struct ShapeStep: View {
    let app: AppModel
    let d: RshDraft
    var body: some View {
        let free = d.shape == "free"
        RshPage(title: tr("rsh.shapeT"), sub: dn(d.name), prog: 0, back: { rshBack(app, d) },
              bar: RBar(label: tr(free ? "rsh.drawGo" : "fr.continue"), icon: free ? "pen" : nil, id: "rsh.shapeGo") {
                  Haptic.tick()
                  if free { go(d, "sketch") } else { d.ret = false; setStep(d, 0); go(d, "walls") }
              }) {
            T(tr("rsh.shapeHint"), ui(13.5, 400, G.ink2, lh: 1.4))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(RoomShape.allCases, id: \.self) { k in ShapeCard(d: d, k: k) }
            }
        }
    }
}

private struct ShapeCard: View {
    let d: RshDraft
    let k: RoomShape
    var body: some View {
        let sel = d.shape == k.id
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    ShapeThumb(shape: k, mir: sel ? d.mir : false, rot: sel ? d.rot : 0, sel: sel)
                        .frame(maxWidth: .infinity).frame(height: 96)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(rshPaper))
                    if sel {
                        MIcon("check", .white, 14, 3).frame(width: 24, height: 24).background(Circle().fill(G.cobalt)).padding(5)
                    }
                }
                T(tr("rsh.s." + k.id), ui(14, 800), lines: 2).padding(.horizontal, 4).padding(.top, 8)
            }
            .contentShape(Rectangle())
            .pressable(0.98) {
                if d.shape != k.id { d.shape = k.id; d.vals = [:]; d.mir = false; d.rot = 0; d.diag = nil; if k != .free { d.sk = nil }; d.ops = [] }
                Haptic.tick()
            }
            .accessibilityAddTraits(sel ? [.isSelected] : [])
            .accessibilityIdentifier("rsh.shape." + k.id)
            if sel && k != .free {
                // side by side as in the mockup; one under the other only when the words don't fit (Russian)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        ToolBtn(icon: MIRROR_IC, label: tr("rsh.mirror"), id: "rsh.mirror", shrink: false) { d.mir.toggle() }
                        ToolBtn(icon: ROTATE_IC, label: tr("rsh.rotate"), id: "rsh.rotate", shrink: false) { d.rot = (d.rot + 1) % 4 }
                    }
                    VStack(spacing: 4) {
                        ToolBtn(icon: MIRROR_IC, label: tr("rsh.mirror"), id: "rsh.mirror") { d.mir.toggle() }
                        ToolBtn(icon: ROTATE_IC, label: tr("rsh.rotate"), id: "rsh.rotate") { d.rot = (d.rot + 1) % 4 }
                    }
                }
                .padding(.top, 2)
            } else {
                let sub = k == .free ? tr(sel ? "rsh.byFinger" : "rsh.everyWall") : tr("rsh.nAsked", ["n": k.askCount])
                T(sub, ui(12, 500, G.ink2, lh: 1.25), lines: 2).padding(.horizontal, 4).frame(minHeight: 40, alignment: .topLeading)
            }
        }
        .padding(8)
        .background(shape.fill(sel ? G.glass(0.85) : G.glass(0.55)))
        .overlay(shape.strokeBorder(sel ? G.cobalt : G.rim, lineWidth: sel ? 2.5 : 1))
    }
}

/* ---------------- 2. the free sketch ---------------- */

/// The sketch's outline in mm (clockwise): each wall's direction and length go to the walls steps.
private func sketchDone(_ app: AppModel, _ d: RshDraft, _ mm: [Pt]) {
    let fsk = freeSketch(mm)
    if fsk.dirs.count < 3 { app.say("sk.cross", kind: .error); return }
    d.sk = fsk; d.vals = [:]; d.diag = nil; d.ops = []; d.ret = false
    Haptic.confirm()
    setStep(d, 0); go(d, "walls")
}

/* ---------------- 3. the walls ---------------- */

private struct WallsStep: View {
    let app: AppModel
    let d: RshDraft
    let kb: Bool
    var body: some View {
        let unit = rshUnit(d)
        let asks = rshAsks(d)
        let n = asks.count
        let free = d.shape == "free"
        let isD = free && d.step >= n
        let st = min(d.step, max(0, n))
        let typed = parseLen(d.input, unit)
        let live = typed.flatMap { $0 >= RSH_WALL_MIN && $0 <= RSH_WALL_MAX ? $0 : nil }
        var vals = d.vals
        if !isD, let live { vals[st] = live }
        let geo = rshGeo(d, vals)
        let hint = isD ? Int((rshDiagLen(d) / 10).rounded()) * 10 : (st < n ? asks[st].def : 3000)
        let label = isD ? tr("rsh.diag") : st < n ? askLabel(asks[st], geo) : ""
        let help = isD ? tr("rsh.diagD") : st < n ? askHelp(d, asks[st], geo) : ""
        let sub = isD ? tr("rsh.diagSub") : tr(d.shape == "bay" ? "rsh.sizeN" : "rsh.wallN", ["i": st + 1, "n": n])
        let liveTxt = typed.map { lenWords($0, unit) }
        var look = PlanLook(cur: isD ? nil : st, done: Set(vals.keys), liveTxt: isD ? nil : liveTxt)
        look.fmt = lenFmt(d); look.pad = 26; look.rp = free ? 0 : 108
        if isD { look.diagK = rshDiagK(d); look.diagCur = true; look.diagTxt = liveTxt ?? "?" }
        look.dimTxt = vals.mapValues { lenWords($0, unit) }
        let main = isD && d.input.isEmpty ? tr("rsh.skip") : d.ret ? tr("common.save") : tr("common.next")
        return RshPage(title: dn(d.name) + " · " + tr("rsh.s." + d.shape), sub: sub, prog: nil, back: { rshBack(app, d) },
                     bar: RBar(label: main, enabled: !d.input.isEmpty || isD) { wallsNext(d) }) {
            // no step dots: "Devor 2 / 4" in the header says it (mockup scrWalls)
            PicBox(height: kb ? 150 : 220, tools: d) { PlanPic(g: geo.g, look: look, letters: geo.letters) }
            RshSizeField(app: app, d: d, key: "w\(st)\(d.shape)", label: label, help: help, text: d.input, fresh: d.fresh, hint: hint, issue: d.err,
                         live: { (d.input, d.fresh) },
                         onText: { d.input = $0; d.fresh = false; d.err = nil; d.heard = nil },
                         onNext: { wallsNext(d) },
                         onValue: { mm, words in takeValue(d, mm, words) },
                         onUnVoice: { unVoice(d) })
        }
    }
}

/// An asked value's title: "Devor B", "Erker eni".
private func askLabel(_ a: ShapeAsk, _ geo: RGeo) -> String {
    switch a.kind {
    case .bayWidth: return tr("rsh.bayW")
    case .bayDepth: return tr("rsh.bayD")
    case .wall: return tr("rsh.wall", ["w": geo.letter(a.wall)])
    }
}

/// The line under it: where to measure.
private func askHelp(_ d: RshDraft, _ a: ShapeAsk, _ geo: RGeo) -> String {
    if d.shape == "bay" {
        switch a.kind {
        case .bayWidth: return tr("rsh.bayWD")
        case .bayDepth: return tr("rsh.bayDD")
        case .wall: return tr(a.wall == 6 ? "rsh.bayGD" : a.wall == 7 ? "rsh.bayHD" : "rsh.bayAD")
        }
    }
    if d.shape == "free" { return tr("rsh.wallD") + " " + tr("rsh.wallFree") }
    if d.shape == "cut" && a.wall == 3 { return tr("rsh.wallD") + " " + tr("rsh.wallCut", ["c": geo.letter(2)]) }
    return tr("rsh.wallD")
}

private func rangeText(_ a: Int, _ b: Int, _ unit: LenUnit) -> String {
    tr("rsh.range", ["a": lenWords(a, unit), "b": lenWords(b, unit), "u": unitWord(unit)])
}

private func wallsNext(_ d: RshDraft) {
    let unit = rshUnit(d)
    let n = rshAsks(d).count
    let free = d.shape == "free"
    let isD = free && d.step >= n
    d.heard = nil
    func bad(_ m: String) { d.err = m; Haptic.warn() }
    let range = rangeText(RSH_WALL_MIN, RSH_WALL_MAX, unit)
    if isD {
        if d.input.isEmpty { d.diag = nil; finishWalls(d); return }
        guard let v = parseLen(d.input, unit), v >= RSH_WALL_MIN, v <= RSH_WALL_MAX else { bad(tr("rsh.e.enter", ["r": range])); return }
        if let e = rshDiagErr(d, v) { bad(e); return }
        d.diag = v
        AppModel.shared.say("rsh.diagOk")
        finishWalls(d); return
    }
    guard let v = parseLen(d.input, unit), v >= RSH_WALL_MIN, v <= RSH_WALL_MAX else {
        bad(tr(d.shape == "bay" && d.step >= 3 ? "rsh.e.size" : "rsh.e.wall", ["r": range])); return
    }
    var vals = d.vals
    vals[d.step] = v
    if let e = rshStepErr(d, vals, d.step) { bad(e); return }
    d.vals = vals
    Haptic.tick()
    if d.ret { finishWalls(d) }
    else if d.step < n - 1 { setStep(d, d.step + 1) }
    else if free { setStep(d, n) }
    else { finishWalls(d) }
}

private func finishWalls(_ d: RshDraft) { if d.ret { d.ret = false; go(d, "summary") } else { go(d, "height") } }

/* ---------------- 4. the height ---------------- */

private struct HeightStep: View {
    let app: AppModel
    let d: RshDraft
    let kb: Bool
    var body: some View {
        let unit = rshUnit(d)
        let live = parseLen(d.hIn, unit).flatMap { $0 >= RSH_H_MIN && $0 <= RSH_H_MAX ? $0 : nil }
        RshPage(title: dn(d.name), sub: tr("rsh.hSub"), prog: nil, back: { rshBack(app, d) },
              bar: RBar(label: tr(d.ret ? "common.save" : "common.next"), enabled: !d.hIn.isEmpty) { heightNext(d) }) {
            PicBox(height: kb ? 150 : 220) { HeightPic(txt: live.map { lenWords($0, unit) } ?? "?").padding(4) }
            RshSizeField(app: app, d: d, key: "h", label: tr("rsh.hT"), help: tr("rsh.hD"), text: d.hIn, fresh: d.hFresh, hint: SHAPE_HEIGHT_DEFAULT, issue: d.hErr,
                         live: { (d.hIn, d.hFresh) },
                         onText: { d.hIn = $0; d.hFresh = false; d.hErr = nil; d.heard = nil },
                         onNext: { heightNext(d) },
                         onValue: { mm, words in takeValue(d, mm, words) },
                         onUnVoice: { unVoice(d) })
        }
    }
}

private func heightNext(_ d: RshDraft) {
    let unit = rshUnit(d)
    d.heard = nil
    guard let v = parseLen(d.hIn, unit), v >= RSH_H_MIN, v <= RSH_H_MAX else {
        d.hErr = tr("rsh.e.h", ["r": rangeText(RSH_H_MIN, RSH_H_MAX, unit)]); Haptic.warn(); return
    }
    d.height = v; Haptic.tick()
    if d.ret { d.ret = false; go(d, "summary") } else { go(d, "ops") }
}

/* ---------------- 5. doors, windows, water, sewer, gas ---------------- */

/// "900 × 2 100 · 600 mm dan" or "400 mm burchakdan".
private func opDesc(_ it: ShapeOpening, _ unit: LenUnit) -> String {
    let u = unitWord(unit)
    if it.kind.isOpening {
        let s = tr("rsh.opDescD", ["w": lenWords(it.w, unit), "h": lenWords(it.h, unit), "d": lenWords(it.dist, unit), "u": u])
        return s + (it.kind == .window ? " · " + tr("rsh.opSill", ["s": lenWords(it.sill, unit)]) : "")
    }
    return tr("rsh.opDescP", ["d": lenWords(it.dist, unit), "u": u])
}

private func opBack(_ d: RshDraft, _ op: OpEdit) {
    d.heard = nil
    let f = opAsks(op.kind)
    if op.stage == "num" && op.sub > 0 {
        var o = op
        o.sub -= 1
        let v = op.vals[f[o.sub].field]
        o.input = v.map { rshFieldText($0, rshUnit(d)) } ?? ""; o.fresh = v != nil; o.err = nil
        d.op = o
    } else if op.stage == "num" {
        var o = op
        o.stage = "wall"; o.err = nil
        d.op = o
    } else { d.op = nil }
}

private struct OpsList: View {
    let app: AppModel
    let d: RshDraft
    var body: some View {
        let unit = rshUnit(d)
        let geo = rshGeo(d)
        var look = PlanLook(final: true)
        look.ops = d.ops; look.fmt = lenFmt(d)
        return RshPage(title: tr("rsh.opsT"), sub: tr("rsh.opsSub", ["n": dn(d.name)]), prog: 3, back: { rshBack(app, d) },
                     bar: RBar(label: tr(d.ops.isEmpty ? "rsh.skip" : "rsh.ready"), id: "rsh.opsDone") { Haptic.tick(); go(d, "summary") }) {
            PicBox(height: 220) { PlanPic(g: geo.g, look: look, letters: geo.letters) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(OpKind.allCases, id: \.self) { k in
                    let cnt = d.ops.filter { $0.kind == k }.count
                    ZStack(alignment: .topTrailing) {
                        VStack(spacing: 6) {
                            OpIcon(kind: k, color: G.ink).frame(width: 36, height: 36)
                            T(tr("rsh.op." + k.id), ui(12.5, 700, G.ink, lh: 1.15), align: .center, lines: 2)
                        }
                        .padding(.horizontal, 4).padding(.vertical, 10).frame(maxWidth: .infinity, minHeight: 90)
                        if cnt > 0 {
                            T("\(cnt)", ui(11, 800, .white)).padding(.horizontal, 6).padding(.vertical, 1).background(Capsule().fill(G.cobalt)).padding(6)
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(G.glass(0.8)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
                    .pressable(0.97) { d.op = OpEdit(kind: k); Haptic.tick() }
                    .accessibilityIdentifier("rsh.op." + k.id)
                }
            }
            if d.ops.isEmpty {
                T(tr("rsh.opsHint"), ui(12.5, 400, G.ink2, lh: 1.4)).padding(.horizontal, 4)
            } else {
                Sect(tr("rsh.added2"))
                ForEach(Array(d.ops.enumerated()), id: \.offset) { i, it in
                    SumRow(label: tr("rsh.op." + it.kind.id) + " · " + tr("rsh.wall", ["w": geo.letter(it.wall)]), value: opDesc(it, unit), small: true, endMin: 40) {
                        MIcon("x", G.ink3, 17, 2).frame(width: 40, height: 40)
                            .pressable(0.95, label: tr("common.delete")) {
                                guard i < d.ops.count else { return }
                                let gone = d.ops.remove(at: i)
                                app.act("rsh.opDel", ["n": tr("rsh.op." + gone.kind.id)]) { d.ops.insert(gone, at: min(i, d.ops.count)) }
                            }
                            .accessibilityIdentifier("rsh.opX")
                    }
                }
            }
        }
    }
}

private struct OpWall: View {
    let app: AppModel
    let d: RshDraft
    let op: OpEdit
    var body: some View {
        let geo = rshGeo(d)
        let name = tr("rsh.op." + op.kind.id)
        var look = PlanLook(pick: true)
        look.ops = d.ops; look.fmt = lenFmt(d)
        return RshPage(title: tr("rsh.whichWall", ["n": name]), sub: tr("rsh.tapWall"), prog: 3, back: { rshBack(app, d) },
                     bar: RBar(label: tr("common.cancel"), secondary: true, id: "rsh.opCancel") { d.op = nil; Haptic.tick() }) {
            PicBox(height: 270) {
                PlanPic(g: geo.g, look: look, letters: geo.letters) { i in
                    var o = op
                    o.stage = "num"; o.wall = i; o.sub = 0; o.input = ""; o.fresh = false; o.err = nil
                    d.op = o; Haptic.tick()
                }
            }
            HStack(spacing: 10) {
                PathIcon(HAND_IC, G.cobalt2, 22, 2)
                T(tr("rsh.tapWallD", ["n": name]), ui(13.5, 600, G.ink, lh: 1.35)).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.blueWash))
        }
    }
}

private struct OpNum: View {
    let app: AppModel
    let d: RshDraft
    let op: OpEdit
    let kb: Bool
    var body: some View {
        let unit = rshUnit(d)
        let geo = rshGeo(d)
        let fs = opAsks(op.kind)
        let sub = min(op.sub, fs.count - 1)
        let f = fs[sub]
        let name = tr("rsh.op." + op.kind.id)
        let L = op.wall >= 0 && op.wall < geo.g.walls.count ? geo.g.walls[op.wall].len : 0
        let letter = geo.letter(op.wall)
        let live: Int? = f.field == .sill ? (op.input.isEmpty ? nil : (parseLen(op.input, unit) ?? 0)) : parseLen(op.input, unit)
        let pd: Int? = op.vals[.dist] ?? (f.field == .dist ? live : nil)
        let pw: Int = op.vals[.width] ?? (f.field == .width ? (live ?? 0) : 0)
        let prev: ShapeOpening? = pd.map { ShapeOpening(op.kind, op.wall, $0, pw) }
        let lw = lenWords(Int(L.rounded()), unit) + " " + unitWord(unit)
        let help: String
        switch f.field {
        case .dist: help = tr(op.kind.isOpening ? "rsh.distOpD" : "rsh.distPtD", ["n": name.lowercased(), "w": letter, "l": lw])
        case .width: help = tr("rsh.wD")
        case .height: help = tr("rsh.hOpD", ["n": name.lowercased()])
        case .sill: help = tr("rsh.sillD", ["v": lenWords(900, unit) + " " + unitWord(unit)])
        }
        var look = PlanLook(sel: op.wall, corner: op.wall)
        look.ops = d.ops; look.preview = prev; look.fmt = lenFmt(d); look.pad = 22
        let fieldLabel = tr(opFieldKey(op.kind, f.field))
        return RshPage(title: name + " · " + tr("rsh.wall", ["w": letter]), sub: "\(sub + 1) / \(fs.count) · " + fieldLabel, prog: nil, back: { rshBack(app, d) },
                     bar: RBar(label: tr(sub < fs.count - 1 ? "common.next" : "rsh.add"), enabled: !op.input.isEmpty) { opNext(app, d) }) {
            PicBox(height: kb ? 150 : 220) { PlanPic(g: geo.g, look: look, letters: geo.letters) }
            RshSizeField(app: app, d: d, key: "op\(op.kind.id)\(op.wall)\(sub)", label: fieldLabel, help: help, text: op.input, fresh: op.fresh,
                         hint: rshOpHint(d, op), issue: op.err,
                         live: { (d.op?.input ?? "", d.op?.fresh ?? false) },
                         onText: { t in if var o = d.op { o.input = t; o.fresh = false; o.err = nil; d.op = o }; d.heard = nil },
                         onNext: { opNext(app, d) },
                         onValue: { mm, words in takeValue(d, mm, words) },
                         onUnVoice: { unVoice(d) })
        }
    }
}

private func opNext(_ app: AppModel, _ d: RshDraft) {
    guard let op = d.op else { return }
    let unit = rshUnit(d)
    let fs = opAsks(op.kind)
    let f = fs[min(op.sub, fs.count - 1)]
    d.heard = nil
    // the distance and the sill may be 0 (in the corner, on the floor); the sizes may not
    let v = rshParse(op.input, unit, zeroOk: f.field == .dist || f.field == .sill)
    if let e = rshOpErr(d, op, v) { var o = op; o.err = e; d.op = o; Haptic.warn(); return }
    guard let v else { return }
    var vals = op.vals
    vals[f.field] = v
    if op.sub < fs.count - 1 {
        var o = op
        o.sub += 1; o.vals = vals; o.err = nil
        // the window's sill is put in for the maker (900), selected so one key replaces it
        if fs[o.sub].field == .sill { o.input = rshFieldText(rshOpHint(d, o), unit); o.fresh = true } else { o.input = ""; o.fresh = false }
        d.op = o
        Haptic.tick(); return
    }
    let it = ShapeOpening(op.kind, op.wall, vals[.dist] ?? 0, vals[.width] ?? 0, vals[.height] ?? 0, vals[.sill] ?? 0)
    let letter = rshGeo(d).letter(op.wall)
    d.op = nil
    d.ops.append(it)
    app.act("rsh.opAdded", ["n": tr("rsh.op." + it.kind.id), "w": letter]) {
        if let i = d.ops.lastIndex(of: it) { d.ops.remove(at: i) }
    }
}

/* ---------------- 6. the summary ---------------- */

private struct Sect: View {
    let t: String
    init(_ t: String) { self.t = t }
    var body: some View { T(t, ui(13, 800, G.ink2)).padding(.leading, 4).padding(.top, 8) }
}

private struct SumRow<End: View>: View {
    let label: String
    let value: String
    var small = false
    var auto = false
    var endMin: CGFloat = 96
    @ViewBuilder let end: End
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: 10) {
            T(label, ui(14, 500, G.ink2, lh: 1.3)).frame(maxWidth: .infinity, alignment: .leading)
            // fills its half and hugs the button, as the mockup's value next to "O‘zgartirish"
            T(value, small ? ui(12.5, 700, auto ? G.ink2 : G.ink, lh: 1.3) : num(15.5, 700, auto ? G.ink2 : G.ink), align: .trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
            end.frame(minWidth: endMin, alignment: .trailing)
        }
        .padding(.leading, 14).padding(.trailing, 6).padding(.vertical, 6).frame(minHeight: 52)
        .background(shape.fill(G.glass(0.6)))
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
    }
}

private struct ChangeBtn: View {
    let label: String
    var id = "rsh.change"
    let action: () -> Void
    var body: some View {
        T(label, ui(13, 700, G.cobalt2), lines: 1).padding(.horizontal, 8).frame(minHeight: 40)
            .pressable(0.97, action)
            .accessibilityIdentifier(id)
    }
}

private struct AutoTag: View {
    var body: some View {
        T(tr("rsh.auto"), ui(11.5, 800, G.ink3), lines: 1).padding(.horizontal, 9).padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(G.ink3.opacity(0.7), style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])))
            .padding(.trailing, 6)
    }
}

private struct Chip2: View {
    let t: String
    var body: some View {
        T(t, ui(12.5, 700), lines: 1).padding(.horizontal, 11).padding(.vertical, 6)
            .background(Capsule().fill(G.glass(0.8))).overlay(Capsule().strokeBorder(G.rim, lineWidth: 1))
    }
}

/// "8,8 m²".
private func m2(_ g: ShapeGeo) -> String {
    let s = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), g.areaMm2 / 1e6)
    return (rshEn ? s : s.replacingOccurrences(of: ".", with: ",")) + " m²"
}

private struct SummaryStep: View {
    let app: AppModel
    let d: RshDraft
    var body: some View {
        let unit = rshUnit(d)
        let u = unitWord(unit)
        let geo = rshGeo(d)
        let g = geo.g
        let asks = rshAsks(d)
        let ch = tr("fz.change")
        let err = g.error.map { rshErrText(d, $0) }
        var look = PlanLook(final: true)
        look.ops = d.ops; look.fmt = lenFmt(d)
        if let dg = d.diag { look.diagK = rshDiagK(d); look.diagTxt = lenWords(dg, unit) }
        let size = g.size
        // in the editor's letter order (a mirrored shape was asked the other way round)
        let order = g.walls.indices.sorted { geo.letter($0) < geo.letter($1) }
        func edit(_ i: Int) { d.ret = true; setStep(d, i); go(d, "walls") }
        return RshPage(title: dn(d.name), sub: tr("rsh.sumSub"), prog: 4, back: { rshBack(app, d) },
                     bar: RBar(label: tr("rsh.open"), enabled: err == nil, id: "rsh.open") { finishRoom(app, d) }) {
            PicBox(height: 230) { PlanPic(g: g, look: look, letters: geo.letters) }
            FlowLayout(spacing: 8) {
                Chip2(t: tr("rsh.s." + d.shape))
                Chip2(t: lenWords(Int(size.w.rounded()), unit) + " × " + lenWords(Int(size.h.rounded()), unit) + " " + u)
                Chip2(t: m2(g))
                if g.gapFixed > 0.5 { Chip2(t: tr("rsh.spread", ["v": lenWords(Int(g.gapFixed.rounded()), unit) + " " + u])) }
            }
            if let err {
                HStack(alignment: .top, spacing: 8) { MIcon("alert", G.err, 18, 2); T(err, ui(13.5, 600, G.err, lh: 1.35)).frame(maxWidth: .infinity, alignment: .leading) }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.errWash))
            }
            Sect(tr("rsh.wallsT"))
            ForEach(order, id: \.self) { i in
                let e = g.walls[i]
                let wl = tr("rsh.wall", ["w": geo.letter(i)])
                let lv = lenWords(Int(e.len.rounded()), unit) + " " + u
                if let a = e.ask {
                    SumRow(label: wl, value: lv) { ChangeBtn(label: ch, id: "rsh.change." + geo.letter(i)) { edit(a) } }
                } else {
                    SumRow(label: wl + (e.angle.map { " · " + tr("rsh.cutAng", ["a": $0]) } ?? ""), value: lv, auto: true) { AutoTag() }
                }
            }
            ForEach(Array(asks.enumerated()), id: \.offset) { j, a in
                if a.wall == nil {
                    SumRow(label: askLabel(a, geo), value: lenWords(d.vals[j] ?? a.def, unit) + " " + u) { ChangeBtn(label: ch) { edit(j) } }
                }
            }
            if d.shape == "free" {
                SumRow(label: tr("rsh.diagT"), value: d.diag.map { lenWords($0, unit) + " " + u } ?? tr("rsh.noDiag")) { ChangeBtn(label: ch) { edit(asks.count) } }
            }
            Sect(tr("rsh.hTitle"))
            SumRow(label: tr("rsh.hT"), value: lenWords(d.height, unit) + " " + u) { ChangeBtn(label: ch, id: "rsh.changeH") { d.ret = true; go(d, "height") } }
            Sect(tr("rsh.opsShort"))
            if d.ops.isEmpty {
                SumRow(label: tr("rsh.opsShort"), value: tr("rsh.none"), small: true, auto: true) { ChangeBtn(label: tr("rsh.add")) { d.ret = false; go(d, "ops") } }
            } else {
                ForEach(Array(d.ops.enumerated()), id: \.offset) { _, it in
                    SumRow(label: tr("rsh.op." + it.kind.id) + " · " + geo.letter(it.wall), value: opDesc(it, unit), small: true) {
                        ChangeBtn(label: ch) { d.ret = false; go(d, "ops") }
                    }
                }
            }
        }
    }
}
