import SwiftUI

/*
 * Adding furniture (decided 21 Oct 2026, mockup design/furniture/gallery-steps-mockup.html v5; Android
 * ui/furniture/Gallery.kt): one gallery of 3D cards grouped by room; a model's main sizes one at a time, the size being
 * asked shown on the piece; which room it goes into (or none). In a measured room the sizes come from the room and the
 * walls step follows (FPlaceScreen). The rules are in Furniture/Core/Steps.swift, the pictures in PieceView.swift.
 */

private var en: Bool { AppSettings.shared.lang == .en }

/* ---------------- small helpers ---------------- */

/// Step values as a route string, "s0=3000,h=2700", and back.
func encodeVals(_ v: [String: Int]) -> String { v.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: ",") }
func decodeVals(_ s: String?) -> [String: Int] {
    var out: [String: Int] = [:]
    for e in (s ?? "").split(separator: ",") {
        let kv = e.split(separator: "=")
        if kv.count == 2, let v = Int(kv[1]) { out[String(kv[0])] = v }
    }
    return out
}

/// A typed length in mm (nil when empty, unreadable or zero).
func parseLen(_ s: String, _ unit: LenUnit) -> Int? {
    if case .ok(let v) = Geo.parseDec(s, Geo.unitDecimals(unit)), v > 0 { return Int(v) }
    return nil
}

func unitWord(_ unit: LenUnit) -> String { tr(unit == .cm ? "u.cm" : "u.m") }

/// The gallery group a room's furniture belongs to: a kitchen's kitchens, a living room's, a hallway's; the others the bedroom's.
private func groupOf(_ p: Project, _ rid: String?) -> String? {
    guard let rid, let r = p.rooms.first(where: { $0.id == rid }) else { return nil }
    let w = p.floors.first { $0.id == r.floorId }
    if w?.type == "kitchen" { return "kitchen" }
    let n = w?.name ?? r.name
    // the room may have been named while the app spoke another language
    let named = { (key: String) in Lang.allCases.contains { n.hasPrefix(Strings.t(key, $0)) } }
    if named("fr.living") { return "living" }
    if named("fr.hall") { return "hall" }
    return "bedroom"
}

/// The group's name: the room names, a hallway and a study.
private func groupName(_ g: String) -> String { tr(g == "hall" ? "fg.hall" : g == "office" ? "fg.office" : "fr." + g) }

private struct GroupTops: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) { value.merge(nextValue()) { $1 } }
}

/* ---------------- the gallery ---------------- */

struct FGalleryScreen: View {
    let app: AppModel
    let pid: String
    let rid: String?
    let fromNew: Bool
    @State private var cur: String? = nil
    @State private var jumping = false
    @State private var viewH: CGFloat = 0   // the list's visible height: its end in sight picks the last group

    var body: some View {
        if let p = Store.shared.get(pid) {
            let s = AppSettings.shared
            let room = rid.flatMap { id in p.rooms.first { $0.id == id } }
            let first = groupOf(p, rid)
            let groups = first == nil ? GALLERY : GALLERY.filter { $0.0 == first } + GALLERY.filter { $0.0 != first }
            let on = cur ?? groups[0].0
            let pics = PiecePics.shared.pics
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    GlassIconButton("back", tr("nt.back")) { app.pop() }.padding(.leading, 6).accessibilityIdentifier("back")
                    BarTitle(title: tr("fg.title"), eyebrow: dn(p.name))
                }
                .padding(.trailing, 12).frame(minHeight: 64)
                .background(G.sheet(0.55).ignoresSafeArea(edges: .top))
                .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(groups, id: \.0) { g, _ in
                                let sel = g == on
                                T(groupName(g), ui(14, 700, sel ? G.solid : G.ink), lines: 1)
                                    .padding(.horizontal, 16).frame(minHeight: 40)
                                    .background(Capsule().fill(sel ? G.ink : G.glass(0.55)))
                                    .pressable(0.97) {
                                        cur = g; jumping = true
                                        withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("g-" + g, anchor: .top) }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { jumping = false }
                                    }
                                    .accessibilityAddTraits(sel ? [.isSelected, .isButton] : .isButton)
                                    .accessibilityIdentifier("fg.chip." + g)
                            }
                        }
                        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            if let room {
                                let f = { (mm: Int?) in Geo.fmtLen(mm, .m, en) }
                                let name = p.floors.first { $0.id == room.floorId }.map { floorName($0) } ?? dn(room.name)
                                T(tr("fg.forRoom", ["r": name, "a": f(room.dim("A").v), "b": f(room.dim("B").v), "h": f(room.dim("H").v)]), ui(13.5, 400, G.ink2, lh: 1.4))
                            } else {
                                HStack(spacing: 12) {
                                    MIcon("room", G.cobalt, 24, 2)
                                    VStack(alignment: .leading, spacing: 1) { T(tr("fg.measure"), ui(14.5, 700, G.cobalt2)); T(tr("fg.measureS"), ui(12.5, 400, G.ink2)) }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                .dashedGlass(18)
                                .pressable(0.98) { app.sheet = .fNewRoom(pid: p.id) }
                                .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
                                .accessibilityIdentifier("fg.measure")
                            }
                            ForEach(groups, id: \.0) { g, ids in
                                HStack(alignment: .lastTextBaseline, spacing: 8) { T(groupName(g), ui(17, 800)); T("\(ids.count)", ui(12.5, 500, G.ink3)) }
                                    .padding(.top, 8).padding(.leading, 2)
                                    .background(GeometryReader { geo in Color.clear.preference(key: GroupTops.self, value: [g: geo.frame(in: .named("gal")).minY]) })
                                    .id("g-" + g)
                                let ms = ids.compactMap { fModel($0) }
                                ForEach(Array(stride(from: 0, to: ms.count, by: 2)), id: \.self) { i in
                                    HStack(alignment: .top, spacing: 10) {
                                        ForEach(ms[i..<min(i + 2, ms.count)], id: \.id) { m in
                                            ModelCard(m: m, pic: pics[m.id], wide: i + 1 >= ms.count) { pick(p, room, m) }
                                        }
                                    }
                                    .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            if fromNew {
                                T(tr("fz.needL"), ui(14.5, 700, G.cobalt2)).padding(.horizontal, 16).padding(.vertical, 12).frame(maxWidth: .infinity)
                                    .pressable(0.97) { app.pop() }
                                    .accessibilityAddTraits(.isButton).accessibilityIdentifier("fg.later")
                            }
                            Color.clear.frame(height: 1)
                                .background(GeometryReader { geo in Color.clear.preference(key: GroupTops.self, value: ["_end": geo.frame(in: .named("gal")).maxY]) })
                        }
                        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 28)
                    }
                    .coordinateSpace(name: "gal")
                    .background(GeometryReader { geo in Color.clear.onAppear { viewH = geo.size.height }.onChange(of: geo.size.height) { _, h in viewH = h } })
                    // the chip of the group at the top of the list
                    .onPreferenceChange(GroupTops.self) { tops in
                        guard !jumping else { return }
                        let atEnd = viewH > 0 && (tops["_end"] ?? .infinity) <= viewH + 4
                        let top = atEnd ? groups[groups.count - 1].0 : groups.last { (tops[$0.0] ?? .infinity) <= 60 }?.0 ?? groups[0].0
                        if top != cur { cur = top }
                    }
                }
            }
            .onAppear { PiecePics.shared.make(s.workshop, s.mats) }
        }
    }

    private func pick(_ p: Project, _ room: Room?, _ m: FModelDef) {
        KitOps.shared.sel = nil
        if let room { app.push(.fPlace(pid: p.id, fid: nil, rid: room.id, model: m.id)) } else { app.push(.fSteps(pid: p.id, model: m.id)) }
    }
}

private struct ModelCard: View {
    let m: FModelDef
    let pic: UIImage?
    let wide: Bool
    let action: () -> Void
    var body: some View {
        let name = tr("fz.m." + m.id)
        let img = ZStack {
            Color(argb: 0xFFF6F8FC)
            if let pic { Image(uiImage: pic).resizable().scaledToFill() } else { T("3D…", ui(11, 600, G.ink3)) }
        }
        .aspectRatio(200 / 170, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        let words = VStack(alignment: .leading, spacing: 2) {
            T(name, ui(14.5, 800), lines: 2)
            T(tr("fz.s." + m.id), ui(12, 500, G.ink2, lh: 1.3), lines: 2)
        }
        .padding(.horizontal, 4)
        Group {
            // the last card of an odd row takes the whole width, its picture beside the words
            if wide { HStack(spacing: 10) { img.frame(maxWidth: .infinity); words.frame(maxWidth: .infinity, alignment: .leading) } }
            else { VStack(alignment: .leading, spacing: 6) { img; words; Spacer(minLength: 0) } }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.62))
        .pressable(0.98, action)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("model." + m.id)
    }
}

/* ---------------- the sizes, one at a time ---------------- */

struct FStepsScreen: View {
    let app: AppModel
    let pid: String
    let model: String
    let fid: String?
    @State private var texts: [String]
    /// 0 … n-1 a size, n the summary; back: the step was opened from the summary, was: its text then.
    @State private var at: Int
    @State private var back = false
    @State private var was = ""
    @State private var laser: String? = nil   // "busy", or the reading's words
    @FocusState private var typing: Bool

    init(app: AppModel, pid: String, model: String, fid: String?, vals: String? = nil) {
        self.app = app; self.pid = pid; self.model = model; self.fid = fid
        let s = AppSettings.shared
        let st = fModel(model).map { stepsOf($0) } ?? []
        let edit = fid.flatMap { id in Store.shared.get(pid)?.furniture.first { $0.id == id } }
        let have = vals.map { decodeVals($0) } ?? edit.map { valsOf($0, s.workshop) } ?? [:]
        _texts = State(initialValue: st.map { have[$0.key].map { Geo.fmtField($0, s.unit, s.lang == .en) } ?? "" })
        _at = State(initialValue: vals != nil ? st.count : 0)
    }

    var body: some View {
        if let p = Store.shared.get(pid), let m = fModel(model) {
            let s = AppSettings.shared, ws = s.workshop, unit = s.unit
            let steps = stepsOf(m), n = steps.count
            let edit = fid.flatMap { id in p.furniture.first { $0.id == id } }
            // only sizes within their range reach the piece: a typed 99999 would otherwise build a 100 m kitchen on every key
            let vals = Dictionary(uniqueKeysWithValues: steps.indices.compactMap { i in parseLen(texts[i], unit).flatMap { stepIssue(steps[i], $0) == nil ? (steps[i].key, $0) : nil } })
            let piece = edit.map { resized($0, vals, ws) } ?? pieceOf(m, vals, ws, "")
            let scene = pieceScene(piece, ws, s.mats)
            let uw = unitWord(unit)
            let hi = at < n ? steps[at].key : nil
            let label: String? = at < n ? (parseLen(texts[at], unit).map { Geo.fmtLen($0, unit, en) + " " + uw } ?? "?") : nil
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        GlassIconButton("back", tr("nt.back")) { prev(n) }.padding(.leading, 6).accessibilityIdentifier("back")
                        BarTitle(title: tr("fz.m." + m.id), eyebrow: at < n ? tr("fx.step", ["i": at + 1, "n": n]) : tr(edit != nil ? "fz.editSizes" : "fx.sumT"))
                    }
                    .padding(.trailing, 12).frame(minHeight: 64)
                    .background(G.sheet(0.55).ignoresSafeArea(edges: .top))
                    .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            // where we are: a dot a size, the last one the summary
                            HStack(spacing: 6) {
                                ForEach(0...n, id: \.self) { i in
                                    Capsule().fill(i == at ? G.cobalt : i < at ? G.cobalt.opacity(0.45) : G.ink.opacity(0.15)).frame(width: i == at ? 22 : 8, height: 8)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            // with the keyboard up the picture gets lower, so the field and the laser stay in sight
                            ZStack(alignment: .bottomTrailing) {
                                PieceView(scene: scene, hi: hi, label: label)
                                T(tr("fx.drag"), ui(11, 600, G.ink3)).padding(10).allowsHitTesting(false)
                            }
                            .aspectRatio(typing && at < n ? 2.1 : 1 / 0.92, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
                            if at < n { ask(steps[at], unit, uw) } else { summary(steps, unit, uw, m.kind == "kitchen") }
                        }
                        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 120)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                FloatingFooter {
                    if at < n {
                        GBtn(tr("common.next"), enabled: ok(steps, at, unit)) { next(steps, unit) }.accessibilityIdentifier("fx.next")
                    } else if let edit {
                        GBtn(tr("common.save"), enabled: steps.indices.allSatisfy { ok(steps, $0, unit) }) {
                            guard app.once() else { return }
                            let g = resized(edit, vals, ws)
                            Store.shared.update(pid) { pr in pr.furniture = pr.furniture.map { $0.id == g.id ? g : $0 } }
                            KitOps.shared.forget(g.id); KitOps.shared.tick += 1; app.pop(); app.say("fz.saved")
                        }
                        .accessibilityIdentifier("fx.save")
                    } else {
                        GBtn(tr("fr.continue"), enabled: steps.indices.allSatisfy { ok(steps, $0, unit) }) {
                            // the sizes stay with this page, so coming back from "Which room?" finds them
                            app.setTop(.fSteps(pid: pid, model: m.id, fid: nil, vals: encodeVals(vals)))
                            app.push(.fWhere(pid: pid, model: m.id, vals: encodeVals(vals)))
                        }
                        .accessibilityIdentifier("fx.go")
                    }
                }
            }
            .onChange(of: at) { _, v in typing = v < n }
            .onAppear {
                app.backOverride = { prev(n) }
                // the keyboard waits until the page has slid in, or iOS drops the focus
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { if at < n { typing = true } }
            }
            .onDisappear { app.backOverride = nil }
        }
    }

    private func issue(_ s: SizeStep, _ text: String, _ unit: LenUnit) -> String? {
        guard let mm = parseLen(text, unit), let r = stepIssue(s, mm) else { return nil }
        return tr(r.0, ["v": Geo.fmtLen(r.1, unit, en) + " " + unitWord(unit)])
    }
    private func ok(_ steps: [SizeStep], _ i: Int, _ unit: LenUnit) -> Bool { parseLen(texts[i], unit) != nil && issue(steps[i], texts[i], unit) == nil }
    private func next(_ steps: [SizeStep], _ unit: LenUnit) {
        guard at < steps.count, ok(steps, at, unit) else { return }
        laser = nil
        if back { back = false; at = steps.count } else { at += 1 }
    }
    private func prev(_ n: Int) {
        laser = nil
        // back to the summary: a size left empty or wrong gets its old value again
        if at < n && back {
            if let m = fModel(model), !ok(stepsOf(m), at, AppSettings.shared.unit) { texts[at] = was }
            back = false; at = n
        } else if at > 0 { at -= 1 } else { app.pop() }
    }

    @ViewBuilder private func ask(_ s: SizeStep, _ unit: LenUnit, _ uw: String) -> some View {
        let i = at
        let bad = issue(s, texts[i], unit)
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let on = AppSettings.shared.laser == .connected
        VStack(alignment: .leading, spacing: 6) {
            T(tr(s.label), ui(21, 800, G.ink, lh: 1.2)).padding(.top, 4)
            T(tr(s.help), ui(13, 400, G.ink2, lh: 1.4))
            HStack(spacing: 10) {
                TextField("", text: Binding(get: { i < texts.count ? texts[i] : "" }, set: { v in
                    if i < texts.count { texts[i] = String(v.filter { $0.isNumber || $0 == "," || $0 == "." }.prefix(8)); laser = nil }
                }), prompt: Text(Geo.fmtField(s.usual, unit, en)).foregroundColor(Color(argb: 0xFFA7B0C0)))
                .font(num(24, 700).font).foregroundColor(G.ink)
                .keyboardType(.decimalPad).focused($typing)
                .accessibilityLabel(tr(s.label)).accessibilityIdentifier("fx.value")
                T(uw, ui(15, 700, G.ink3))
                // the laser's button sits in the field, so it stays in sight above the keyboard
                if on { GBtn(tr("fx.laser"), icon: "laser", enabled: laser != "busy", height: 44, corner: 14, fontSize: 13.5, fill: false) { reading(s, unit) }.accessibilityIdentifier("fx.laser") }
            }
            .padding(.horizontal, 16).frame(minHeight: 60)
            .background(shape.fill(G.glass(0.85)))
            .overlay(shape.strokeBorder(bad != nil ? G.err : G.cobalt, lineWidth: 2))
            if let bad { HStack(alignment: .top, spacing: 6) { MIcon("alert", G.err, 18, 2); T(bad, ui(13.5, 500, G.err)) } }
            // one line under the field: the laser's state or its reading; without a laser, the way to connect one
            HStack(spacing: 8) {
                Circle().fill(on ? Color(argb: 0xFF16A34A) : G.ink3).frame(width: 9, height: 9)
                T(laser == "busy" ? tr("fx.busy") : laser ?? tr(on ? "fx.laserOn" : "fx.laserOff"), ui(12.5, 600, G.ink2, lh: 1.35)).frame(maxWidth: .infinity, alignment: .leading)
                if !on { T(tr("fx.connect"), ui(13.5, 700, G.cobalt2)) }
            }
            .padding(.horizontal, 4).frame(minHeight: 40)
            .contentShape(Rectangle())
            .onTapGesture { if !on { app.sheet = .device } }
        }
    }

    /// The simulated laser: a reading near the usual size fills the field, and the next step opens.
    private func reading(_ s: SizeStep, _ unit: LenUnit) {
        guard laser != "busy" else { return }
        let i = at
        laser = "busy"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            let v = (s.usual + Int.random(in: -120...120)) / 5 * 5
            if i < texts.count { texts[i] = Geo.fmtField(v, unit, en) }
            laser = tr("fx.got", ["v": Geo.fmtLen(v, unit, en) + " " + unitWord(unit)])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                guard at == i, let m = fModel(model) else { return }
                next(stepsOf(m), unit)
            }
        }
    }

    @ViewBuilder private func summary(_ steps: [SizeStep], _ unit: LenUnit, _ uw: String, _ kitchen: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                HStack(spacing: 10) {
                    T(tr(s.label), ui(14.5, 600)).frame(maxWidth: .infinity, alignment: .leading)
                    T((parseLen(texts[i], unit).map { Geo.fmtLen($0, unit, en) } ?? texts[i]) + " " + uw, num(17, 700))
                    T(tr("fz.change"), ui(12.5, 700, G.cobalt2))
                }
                .padding(.horizontal, 12).padding(.vertical, 8).frame(minHeight: 54)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.glass(0.7)))
                .pressable(0.98) { was = texts[i]; back = true; at = i }
                .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("fx.row.\(i)")
            }
            T(tr(kitchen ? "fx.noteK" : "fx.noteW"), ui(12.5, 400, G.ink2, lh: 1.45)).padding(.top, 4).padding(.leading, 4)
        }
    }
}

/* ---------------- which room ---------------- */

struct FWhereScreen: View {
    let app: AppModel
    let pid: String
    let model: String
    let vals: String

    var body: some View {
        if let p = Store.shared.get(pid), let m = fModel(model) {
            let s = AppSettings.shared, ws = s.workshop, snap = s.angleSnap, unit = s.unit
            let v = decodeVals(vals)
            let probe = pieceOf(m, v, ws, "")
            let sizes = stepsOf(m).filter { $0.key != "h" || m.kind != "kitchen" }.map { st in v[st.key].map { Geo.fmtLen($0, unit, en) } ?? "?" }
                .joined(separator: m.kind == "kitchen" ? " + " : " × ") + " " + unitWord(unit)
            FPage(eyebrow: tr("fz.m." + m.id), title: tr("fq.title"), back: { app.pop() }) {
                T(tr("fz.m." + m.id) + ": " + sizes, ui(13.5, 500, G.ink2))
                if !p.rooms.contains(where: { measuredRoom($0, snap) }) { T(tr("fz.noMeasured"), ui(13.5, 400, G.ink2, lh: 1.4)) }
                ForEach(p.rooms) { r in roomRow(p, r, m, probe) }
                // a room still to measure: the piece is kept and goes in once the room is measured
                HStack(spacing: 12) {
                    MIcon("plus", G.cobalt2, 22, 2.2)
                    VStack(alignment: .leading, spacing: 1) { T(tr("fz.newRoom"), ui(15, 700, G.cobalt2)); T(tr("fq.newRoomS"), ui(12.5, 400, G.ink2)) }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12).padding(.vertical, 10).frame(minHeight: 66)
                .dashedGlass(16)
                .pressable(0.98) {
                    guard app.once() else { return }
                    let f = pieceOf(m, v, ws, pieceName(p, m), now: nowMs()); addPiece(pid, f)
                    app.popTo { if case .project(let id, _, _, _) = $0 { return id == pid }; return false }
                    app.sheet = .fNewRoom(pid: pid, kind: f.kind, fid: f.id)
                }
                .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton).accessibilityIdentifier("fq.new")
                HStack(spacing: 12) {
                    MIcon("ruler", G.cobalt, 22, 2)
                    VStack(alignment: .leading, spacing: 1) { T(tr("fq.none"), ui(15, 700)); T(tr("fq.noneS"), ui(12.5, 400, G.ink2)) }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    MIcon("chev", G.ink3, 16, 2)
                }
                .padding(.horizontal, 12).padding(.vertical, 10).frame(minHeight: 66)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.glass(0.75)))
                .pressable(0.98) {
                    guard app.once() else { return }
                    let f = pieceOf(m, v, ws, pieceName(p, m), now: nowMs()), moved = p.stage == "measure"
                    addPiece(pid, f)
                    KitOps.shared.sel = nil
                    app.popTo { if case .project(let id, _, _, _) = $0 { return id == pid }; return false }
                    app.push(designer(pid, f, step: 2))
                    app.say(moved ? "fz.createdS" : "fz.created", ["n": dn(f.name), "s": tr("fs.design")])
                }
                .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton).accessibilityIdentifier("fq.none")
            }
        }
    }

    @ViewBuilder private func roomRow(_ p: Project, _ r: Room, _ m: FModelDef, _ probe: Furniture) -> some View {
        let s = AppSettings.shared, snap = s.angleSnap
        let w = p.floors.first { $0.id == r.floorId }
        let name = w.map { floorName($0) } ?? dn(r.name)
        let ready = measuredRoom(r, snap)
        let f = { (mm: Int?) in Geo.fmtLen(mm, .m, en) }
        HStack(spacing: 12) {
            MIcon(w?.type == "kitchen" ? "kitchen" : "room", ready ? G.cobalt : G.ink3, 24, 2)
            VStack(alignment: .leading, spacing: 3) {
                T(name, ui(15, 700, ready ? G.ink : G.ink3), lines: 1)
                if ready {
                    let fit = bestFirst(probe, Geo.walls(r, snap).map(\.id), { wallLen(r, snap, $0) }, r.dim("H").v, s.workshop)
                    let good = fit.1.isEmpty
                    T(f(r.dim("A").v) + " × " + f(r.dim("B").v) + " m · h " + f(r.dim("H").v), num(12.5, 500, G.ink2))
                    T(good ? "✓ " + tr("fq.fits") : issueText(fit.1[0]), ui(12, 700, good ? Color(argb: 0xFF15803D) : G.err, lh: 1.3))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(good ? G.greenWash : G.errWash))
                } else {
                    T(tr("fo.notMeasured"), ui(12.5, 400, G.ink3))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if ready { MIcon("chev", G.ink3, 16, 2) }
        }
        .padding(.horizontal, 12).padding(.vertical, 10).frame(minHeight: 66)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.glass(ready ? 0.75 : 0.4)))
        .pressable(0.98) { if ready { app.push(.fPlace(pid: pid, fid: nil, rid: r.id, model: m.id, vals: vals)) } }
        .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(ready ? "fq.room" : "fq.unmeasured")
    }
}
