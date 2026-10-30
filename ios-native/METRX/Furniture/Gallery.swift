import SwiftUI

/*
 * Adding furniture (decided 21 Oct 2026, mockup design/furniture/gallery-steps-mockup.html v5; Android
 * ui/furniture/Gallery.kt): one gallery of 3D cards grouped by room; a model's main sizes one at a time, the size being
 * asked shown on the piece; which room it goes into (or none). In a measured room the sizes come from the room and the
 * walls step follows (FPlaceScreen). The rules are in Furniture/Core/Steps.swift; the cards' pictures (the real 3D) in
 * GalleryCards.swift, the steps' live picture in PieceView.swift.
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

/// A new piece in the order's design style st ("" none), as addPiece makes it: the size steps' picture shows its colours.
func styledNew(_ f: Furniture, _ st: String, ws: Workshop = Workshop()) -> Furniture {
    st.isEmpty || designPreset(st) == nil || f.look != nil ? f : withPreset(f, st, fresh: true, ws: ws)
}

/// A typed length in mm (nil when empty, unreadable or zero).
func parseLen(_ s: String, _ unit: LenUnit) -> Int? {
    if case .ok(let v) = Geo.parseDec(s, Geo.unitDecimals(unit)), v > 0 { return Int(v) }
    return nil
}

func unitWord(_ unit: LenUnit) -> String { tr(unitKey(unit)) }

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
    if named("fr.kids") { return "kids" }
    if named("fr.bath") { return "bath" }
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
            // the cards' pictures from the real 3D, kept once made (GalleryCards.swift)
            let pics = CardPics.shared.pics
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    GlassIconButton("back", tr("nt.back")) { app.pop() }.padding(.leading, 6).accessibilityIdentifier("back")
                    BarTitle(title: tr("fg.title"), eyebrow: dn(p.name))
                }
                .padding(.trailing, 12).frame(minHeight: 64)
                .background(barTint.ignoresSafeArea(edges: .top))
                .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
                // the order's design style on top: new pieces start with it, the cards repaint at once (Core/PieceLook.swift)
                StyleRow(app: app, p: p).padding(.top, 10)
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
                                let f = { (mm: Int?) in Geo.fmtLen(mm, AppSettings.shared.unit, en) }
                                let name = p.floors.first { $0.id == room.floorId }.map { floorName($0) } ?? dn(room.name)
                                T(tr("fg.forRoomU", ["u": unitWord(AppSettings.shared.unit), "r": name, "a": f(Geo.roomSize(room, AppSettings.shared.angleSnap)?.0), "b": f(Geo.roomSize(room, AppSettings.shared.angleSnap)?.1), "h": f(room.dim("H").v)]), ui(13.5, 400, G.ink2, lh: 1.4))
                                // the room's one editor (room-editor mockup v2): its walls, doors, windows and points
                                HStack(spacing: 8) {
                                    PathIcon(SD_ROOM_IC, G.cobalt2, 20, 2)
                                    T(tr("re.editRoom"), ui(14.5, 700, G.cobalt2)).frame(maxWidth: .infinity, alignment: .leading)
                                    MIcon("chev", G.ink3, 16, 2)
                                }
                                .padding(.horizontal, 12).frame(minHeight: 48)
                                .dashedGlass(16)
                                .pressable(0.98) { app.push(.roomEd(pid: p.id, rid: room.id)) }
                                .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
                                .accessibilityIdentifier("re.editRoom")
                                // "Mebel joylash": the room's pieces against a wall or free (room-editor mockup v3)
                                HStack(spacing: 8) {
                                    PathIcon("M4 11h16v6H4zM6 17v2M18 17v2M6 11V8h12v3", G.cobalt2, 20, 2)
                                    T(tr("fp.placeT"), ui(14.5, 700, G.cobalt2)).frame(maxWidth: .infinity, alignment: .leading)
                                    MIcon("chev", G.ink3, 16, 2)
                                }
                                .padding(.horizontal, 12).frame(minHeight: 48)
                                .dashedGlass(16)
                                .pressable(0.98) { app.push(.fArrange(pid: p.id, rid: room.id)) }
                                .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
                                .accessibilityIdentifier("fp.open")
                                // a measured kitchen: built for it, six styles to pick from (Joylan ideas, 26 Oct 2026)
                                if first == "kitchen" && measuredRoom(room, s.angleSnap) { AutoKitchenEntry(app: app, pid: p.id, rid: room.id) }
                            } else if !p.rooms.contains(where: { measuredRoom($0, s.angleSnap) }) {
                                // not when the order has a measured room ("Measure the room first" was shown over its gallery)
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
                            // the maker's own templates first: their style and layout stay, the sizes refit (UX upgrades section 7)
                            if !s.templates.isEmpty { TemplatesRow(app: app, p: p, rid: room?.id, pics: pics) }
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
                                                .coachMark(g == groups[0].0 && i == 0 && m.id == ms[0].id ? "gallery" : "")
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
            .onAppear { CardPics.shared.use(s.workshop, s.mats, p.fstyle); CardPics.shared.prefer(cardOrder(groups, on)) }
            // the group at the top of the list (or jumped to) is made first
            .onChange(of: cur) { _, g in CardPics.shared.prefer(cardOrder(groups, g ?? groups[0].0)) }
            // another style, other boards or another workshop: other pictures
            .onChange(of: p.fstyle) { _, st in CardPics.shared.use(s.workshop, s.mats, st) }
            .onChange(of: s.mats) { _, ms in CardPics.shared.use(s.workshop, ms, p.fstyle) }
            .onChange(of: s.workshop) { _, w in CardPics.shared.use(w, s.mats, p.fstyle) }
        }
    }

    private func pick(_ p: Project, _ room: Room?, _ m: FModelDef) {
        KitOps.shared.sel = nil
        if let room { app.push(.fPlace(pid: p.id, fid: nil, rid: room.id, model: m.id)) } else { app.push(.fSteps(pid: p.id, model: m.id)) }
    }
}

/// "Mening shablonlarim": the saved pieces, a tap puts one in the order (its sizes refit), the cross deletes it (Undo).
private struct TemplatesRow: View {
    let app: AppModel
    let p: Project
    let rid: String?
    let pics: [String: UIImage]
    var body: some View {
        let s = AppSettings.shared
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .lastTextBaseline, spacing: 8) { T(tr("ux.tpl.group"), ui(17, 800)); T("\(s.templates.count)", ui(12.5, 500, G.ink3)) }
                .padding(.top, 8).padding(.leading, 2)
            T(tr("ux.tpl.note"), ui(12.5, 400, G.ink2, lh: 1.4)).padding(.leading, 2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(s.templates) { t in
                        VStack(alignment: .leading, spacing: 6) {
                            ZStack {
                                Color(argb: 0xFFF6F8FC)
                                if let pic = pics[modelOf(t).id] { Image(uiImage: pic).resizable().scaledToFill() } else { MIcon(t.kind == "kitchen" ? "kitchen" : "board", G.cobalt, 30, 2) }
                            }
                            .frame(width: 154, height: 116)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            HStack(spacing: 4) {
                                T(dn(t.name), ui(14, 800), lines: 2).frame(maxWidth: .infinity, alignment: .leading)
                                MIcon("x", G.ink3, 16, 2).frame(width: 40, height: 40)
                                    .pressable(0.95, label: tr("common.delete")) {
                                        let before = s.templates
                                        s.setTemplateList(before.filter { $0.id != t.id })
                                        app.act("ux.tpl.del") { AppSettings.shared.setTemplateList(before) }
                                    }
                            }
                            .padding(.leading, 4)
                        }
                        .padding(8)
                        .frame(width: 170)
                        .glassCard(RoundedRectangle(cornerRadius: 20, style: .continuous), fill: G.glass(0.62))
                        .pressable(0.98) { useTemplate(t) }
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("tpl." + t.id)
                    }
                }
            }
        }
    }

    /// A template into the order: in a measured room a room-less copy goes onto its walls; without one its sizes are
    /// asked again.
    private func useTemplate(_ t: Furniture) {
        guard app.once(), let p = Store.shared.get(p.id) else { return }
        KitOps.shared.sel = nil
        let m = modelOf(t)
        if let rid {
            var f = t
            f.id = uid(); f.name = pieceName(p, m); f.created = nowMs(); f.roomId = nil; f.ws = ""
            addPiece(p.id, f)
            app.push(.fPlace(pid: p.id, fid: f.id, rid: rid))
        } else {
            app.push(.fSteps(pid: p.id, model: m.id, tpl: t.id))
        }
    }
}

/// The gallery's models in the order their cards should be made: group g's first, then the ones below it, then the rest.
private func cardOrder(_ groups: [(String, [String])], _ g: String) -> [String] {
    let i = groups.firstIndex { $0.0 == g } ?? 0
    return (groups[i...] + groups[..<i]).flatMap { $0.1 }
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
            if let pic { Image(uiImage: pic).resizable().scaledToFill().transition(.opacity) } else { CardShimmer() }
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

/// Which sizes page set app.backOverride last: a page going away clears it only while it is still its own (the next
/// page may have set its own before the old one's onDisappear).
enum BackOwner { static var last = 0; static var seq = 0 }

struct FStepsScreen: View {
    let app: AppModel
    let pid: String
    let model: String
    let fid: String?
    /// What was typed, by step key; a choice step keeps the index of what was chosen ("" the usual one).
    @State private var texts: [String: String]
    /// The sizes the page started from (a corner piece's shape when it is changed later).
    private let had: [String: Int]
    /// 0 … n-1 a size, n the summary; back: the step was opened from the summary, was: its text then.
    @State private var at: Int
    @State private var back = false
    @State private var was = ""
    @State private var laser: String? = nil   // "busy", or the reading's words
    /// The field glows green a moment after a laser or voice value (UX upgrades section 6).
    @State private var flash = false
    /// A voice value just put in: the words heard and the text before, for the "Bekor" chip.
    @State private var voice: VoiceGot? = nil
    /// A spoken size that was not understood ("Raqam noto‘g‘ri. Masalan: 3400").
    @State private var heardBad = false
    /// This page's turn at app.backOverride (BackOwner).
    @State private var backToken = 0
    @FocusState private var typing: Bool

    /// A template being put in (its style and layout stay, its sizes asked again).
    private let tplF: Furniture?

    init(app: AppModel, pid: String, model: String, fid: String?, vals: String? = nil, tpl: String? = nil) {
        self.app = app; self.pid = pid; self.model = model; self.fid = fid
        let s = AppSettings.shared
        let edit = fid.flatMap { id in Store.shared.get(pid)?.furniture.first { $0.id == id } }
        let tf = fid == nil ? tpl.flatMap { id in s.templates.first { $0.id == id } } : nil
        tplF = tf
        let have = vals.map { decodeVals($0) } ?? edit.map { valsOf($0, s.workshop) } ?? tf.map { valsOf($0, s.workshop) } ?? [:]
        had = have
        let all = fModel(model).map { stepsOf($0, have) } ?? []
        var t: [String: String] = [:]
        for (k, v) in have {
            let choice = all.contains { $0.key == k && $0.choice }
            t[k] = choice ? "\(v)" : Geo.fmtField(v, s.unit, s.lang == .en)
        }
        _texts = State(initialValue: t)
        // a corner piece's shape is chosen once, when it is made
        let n = all.filter { edit == nil || $0.key != "sh" }.count
        _at = State(initialValue: vals != nil ? n : 0)
    }

    /// The steps now: a corner piece's side steps follow which sides were measured; its shape only for a new piece.
    private func stepsNow(_ m: FModelDef) -> [SizeStep] {
        let ms = texts["ms"].flatMap { Int($0) }
        let all = stepsOf(m, ms.map { ["ms": $0] } ?? [:])
        if fid == nil { return all }
        return all.filter { $0.key != "sh" }
    }

    /// Step i's text.
    private func txt(_ steps: [SizeStep], _ i: Int) -> String { i < steps.count ? texts[steps[i].key] ?? "" : "" }
    private func setTxt(_ steps: [SizeStep], _ i: Int, _ v: String) { if i < steps.count { texts[steps[i].key] = v } }

    var body: some View {
        if let p = Store.shared.get(pid), let m = fModel(model) {
            let s = AppSettings.shared, ws = s.workshop, unit = s.unit
            let steps = stepsNow(m), n = steps.count
            let edit = fid.flatMap { id in p.furniture.first { $0.id == id } }
            // only sizes within their range reach the piece: a typed 99999 would otherwise build a 100 m kitchen on every key
            let vals = typedVals(steps, unit)
            // a new piece is shown in the order's design style, as it will be made (addPiece)
            let piece = edit.map { resized($0, vals, ws) } ?? tplF.map { resized($0, vals, ws) } ?? styledNew(pieceOf(m, vals, ws, ""), p.fstyle, ws: ws)
            let scene = pieceScene(piece, ws, s.mats)
            let uw = unitWord(unit)
            let hi: String? = at < n && !steps[at].choice ? steps[at].key : nil
            let label: String? = hi != nil ? (parseLen(txt(steps, at), unit).map { Geo.fmtLen($0, unit, en) + " " + uw } ?? "?") : nil
            // the sides worked out from the ones typed (a corner piece), and whether one comes out of what the piece can be
            let derived = derivedSides(m, vals)
            let allOk = steps.indices.allSatisfy { ok(steps, $0, unit) } && !derived.contains { $0.bad }
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        GlassIconButton("back", tr("nt.back")) { prev(n) }.padding(.leading, 6).accessibilityIdentifier("back")
                        BarTitle(title: tr("fz.m." + m.id), eyebrow: at < n ? tr("fx.step", ["i": at + 1, "n": n]) : tr(edit != nil ? "fz.editSizes" : "fx.sumT"))
                    }
                    .padding(.trailing, 12).frame(minHeight: 64)
                    .background(barTint.ignoresSafeArea(edges: .top))
                    .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
                    ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            // where we are: a dot a size, the last one the summary
                            HStack(spacing: 6) {
                                ForEach(0...n, id: \.self) { i in
                                    Capsule().fill(i == at ? G.cobalt : i < at ? G.cobalt.opacity(0.45) : G.ink.opacity(0.15)).frame(width: i == at ? 22 : 8, height: 8)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .id("fx.top")
                            // with the keyboard up the picture gets lower, so the field and the laser stay in sight
                            ZStack(alignment: .bottomTrailing) {
                                PieceView(scene: scene, hi: hi, label: label)
                                T(tr("fx.drag"), ui(11, 600, G.ink3)).padding(10).allowsHitTesting(false)
                            }
                            .aspectRatio(typing && at < n ? 2.5 : 1 / 0.92, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
                            if at < n && steps[at].pics { picsAsk(m, steps) }
                            else if at < n && steps[at].choice { choiceAsk(steps) }
                            else if at < n { ask(steps, unit, uw) }
                            else { summary(steps, unit, uw, derived, noteKey(m, edit)) }
                        }
                        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 120)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    // with the keyboard up the laser and mic row went under "Keyingi": it is scrolled up above the bar
                    .onChange(of: typing) { _, on in if on { toolsUp(proxy) } }
                    .onChange(of: at) { _, v in
                        // the summary opens from its top (it was left with the picture under the title)
                        if v >= n { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { proxy.scrollTo("fx.top", anchor: .top) } }
                        else if typing { toolsUp(proxy) }
                    }
                    }
                }
                FloatingFooter {
                    if at < n {
                        GBtn(tr("common.next"), enabled: ok(steps, at, unit)) { next(steps, unit) }.accessibilityIdentifier("fx.next")
                    } else if let edit {
                        GBtn(tr("common.save"), enabled: allOk) {
                            guard app.once() else { return }
                            let g = resized(edit, vals, ws)
                            Store.shared.update(pid) { pr in pr.furniture = pr.furniture.map { $0.id == g.id ? g : $0 } }
                            KitOps.shared.forget(g.id); KitOps.shared.tick += 1; app.pop(); app.say("fz.saved")
                        }
                        .accessibilityIdentifier("fx.save")
                    } else {
                        // no measured room in the order: "Qaysi xonaga?" is skipped, the piece goes in without a room and
                        // the designer opens (UX upgrades section 7)
                        let roomless = !p.rooms.contains { measuredRoom($0, s.angleSnap) }
                        GBtn(tr(roomless ? "ux.toDesign" : "fr.continue"), enabled: allOk) {
                            if roomless || tplF != nil { placeRoomless(p, m, vals, ask: !roomless); return }
                            // the sizes stay with this page, so coming back from "Which room?" finds them
                            app.setTop(.fSteps(pid: pid, model: m.id, fid: nil, vals: encodeVals(vals)))
                            app.push(.fWhere(pid: pid, model: m.id, vals: encodeVals(vals)))
                        }
                        .accessibilityIdentifier("fx.go")
                    }
                }
            }
            .onChange(of: at) { _, v in typing = v < n && !steps[v].choice }
            .onAppear {
                BackOwner.seq += 1; backToken = BackOwner.seq; BackOwner.last = backToken
                app.backOverride = { prev(n) }
                // the keyboard waits until the page has slid in, or iOS drops the focus
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { if at < n && !steps[at].choice { typing = true } }
            }
            .onDisappear { if BackOwner.last == backToken { app.backOverride = nil; BackOwner.last = 0 } }
            // a real laser's measurement goes into the size being asked, then on to the next step when it fits
            .laserSink { mm in gotReal(mm) }
        }
    }

    /// The piece without a room, straight into its designer; Undo takes it out again.
    private func placeRoomless(_ p: Project, _ m: FModelDef, _ vals: [String: Int], ask: Bool = false) {
        guard app.once() else { return }
        let ws = AppSettings.shared.workshop
        var f = pieceOf(m, vals, ws, pieceName(p, m), now: nowMs())
        // a template's copy: its style and layout, the new sizes
        if let t = tplF {
            var c = t
            c.id = uid(); c.name = pieceName(p, m); c.created = nowMs(); c.roomId = nil; c.ws = ""; c.pose = nil
            f = resized(c, vals, ws)
        }
        let before = p
        addPiece(pid, f)
        KitOps.shared.sel = nil
        app.popTo { if case .project(let id, _, _, _) = $0 { return id == pid }; return false }
        // the order has a measured room: which one (or none) is asked
        if ask { app.sheet = .fPickRoom(pid: pid, fid: f.id); return }
        app.push(designer(pid, f, step: 2))
        app.act("ux.addedFree", ["n": dn(f.name)]) {
            Store.shared.update(before.id) { $0 = before }
            if case .wardrobe(let id, let fid, _, _, _, _) = AppModel.shared.top, id == before.id, fid == f.id { AppModel.shared.pop() }
            if case .kitchen(let id, let fid, _, _) = AppModel.shared.top, id == before.id, fid == f.id { AppModel.shared.pop() }
        }
    }

    /// A step's value as typed: a choice's index, or a size in mm.
    private func typed(_ s: SizeStep, _ text: String, _ unit: LenUnit) -> Int? { s.choice ? Int(text) : parseLen(text, unit) }

    /// The values typed so far that are within their ranges.
    private func typedVals(_ steps: [SizeStep], _ unit: LenUnit) -> [String: Int] {
        var out: [String: Int] = [:]
        for i in steps.indices {
            if let v = typed(steps[i], txt(steps, i), unit), stepIssue(steps[i], v) == nil { out[steps[i].key] = v }
        }
        return out
    }

    /// The summary's note: a piece of several boxes is built again from its sizes, so what was changed box by box goes
    /// (said before saving).
    private func noteKey(_ m: FModelDef, _ edit: Furniture?) -> String {
        if let edit, PIECE_TYPES.contains(edit.type) || edit.type == "loft" { return "fx.noteRebuild" }
        if m.kind == "kitchen" { return "fx.noteK" }
        return ITEM_TYPES.contains(m.type) ? "fx.noteI" : "fx.noteW"
    }

    private func issue(_ s: SizeStep, _ text: String, _ unit: LenUnit) -> String? {
        if s.choice { return nil }
        guard let mm = parseLen(text, unit) else {
            // 0 or a wrong number says so (Next stays off without a word otherwise)
            let t = text.trimmingCharacters(in: .whitespaces)
            if t.isEmpty { return nil }
            let digits = t.drop { $0 == "0" || $0 == "," || $0 == "." }
            return digits.isEmpty ? tr("err.zero") : tr("ux.badNum", ["v": Geo.fmtField(s.usual, unit, en)])
        }
        guard let r = stepIssue(s, mm) else { return nil }
        return tr(r.0, ["v": Geo.fmtLen(r.1, unit, en) + " " + unitWord(unit)])
    }
    private func ok(_ steps: [SizeStep], _ i: Int, _ unit: LenUnit) -> Bool {
        guard i < steps.count else { return false }
        if steps[i].choice { return true }
        let t = txt(steps, i)
        return parseLen(t, unit) != nil && issue(steps[i], t, unit) == nil
    }
    private func next(_ steps: [SizeStep], _ unit: LenUnit) {
        guard at < steps.count, ok(steps, at, unit) else { Haptic.warn(); return }
        Haptic.tick()
        laser = nil; voice = nil; heardBad = false
        if back { back = false; at = steps.count } else { at += 1 }
    }
    private func prev(_ n: Int) {
        laser = nil
        // back to the summary: a size left empty or wrong gets its old value again
        if at < n && back {
            if let m = fModel(model) {
                let st = stepsNow(m)
                if !ok(st, at, AppSettings.shared.unit) { setTxt(st, at, was) }
            }
            back = false; at = n
        } else if at > 0 { at -= 1 } else { app.pop() }
    }

    /// The size step's laser, mic and laser line scrolled above the "Keyingi" bar once the keyboard is up.
    /// The step being asked has usual sizes under its field.
    private var hasPicks: Bool {
        guard let m = fModel(model) else { return false }
        let st = stepsNow(m)
        return at < st.count && !st[at].picks.isEmpty
    }

    private func toolsUp(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // on an iPhone SE a step with usual sizes under the field (a mattress's) is taller than the space above the
            // keyboard: its heading stays in sight (it went under the title), the chips scroll
            let tall = UIScreen.main.bounds.height < 700 && self.hasPicks
            withAnimation(.easeOut(duration: 0.25)) { if tall { proxy.scrollTo("fx.ask", anchor: .top) } else { proxy.scrollTo("fx.end", anchor: .bottom) } }
        }
    }

    @ViewBuilder private func ask(_ steps: [SizeStep], _ unit: LenUnit, _ uw: String) -> some View {
        let i = at
        let s = steps[i]
        let bad = issue(s, txt(steps, i), unit)
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let on = AppSettings.shared.laser == .connected
        VStack(alignment: .leading, spacing: 6) {
            T(tr(s.label), ui(21, 800, G.ink, lh: 1.2)).padding(.top, 4).id("fx.ask")
            T(tr(s.help), ui(13, 400, G.ink2, lh: 1.4))
            HStack(spacing: 10) {
                TextField("", text: Binding(get: { txt(steps, i) }, set: { v in
                    setTxt(steps, i, String(v.filter { $0.isNumber || $0 == "," || $0 == "." }.prefix(8))); laser = nil; voice = nil; heardBad = false
                }), prompt: Text(Geo.fmtField(s.usual, unit, en)).foregroundColor(Color(argb: 0xFFA7B0C0)))
                .font(num(34, 800).font).foregroundColor(G.ink)
                .keyboardType(unit == .mm ? .numberPad : .decimalPad).focused($typing)
                .accessibilityLabel(tr(s.label)).accessibilityIdentifier("fx.value")
                T(uw, ui(17, 700, G.ink3))
            }
            .padding(.horizontal, 16).frame(minHeight: 72)
            .background(shape.fill(flash ? G.greenWash : G.glass(0.85)))
            .overlay(shape.strokeBorder(bad != nil || heardBad ? G.err : flash ? G.green : G.cobalt, lineWidth: 2))
            .shadow(color: flash ? G.green.opacity(0.45) : .clear, radius: flash ? 12 : 0)
            .animation(.easeOut(duration: 0.25), value: flash)
            if let bad { HStack(alignment: .top, spacing: 6) { MIcon("alert", G.err, 18, 2); T(bad, ui(13.5, 500, G.err)) } }
            else if heardBad { HStack(alignment: .top, spacing: 6) { MIcon("alert", G.err, 18, 2); T(tr("ux.badNum", ["v": Geo.fmtField(s.usual, unit, en)]), ui(13.5, 500, G.err)) } }
            // a voice value: what was heard, and "Bekor" to put the old value back
            if let v = voice, v.step == i {
                HStack(spacing: 8) {
                    PathIcon(MIC_ICON, G.cobalt2, 16, 2)
                    T(tr("ux.fromVoice", ["w": v.said, "v": txt(steps, i) + " " + uw]), ui(13, 600, G.cobalt2), lines: 2).frame(maxWidth: .infinity, alignment: .leading)
                    T(tr("ux.cancelV"), ui(13.5, 800, G.cobalt2)).padding(.horizontal, 12).frame(minHeight: 40)
                        .background(Capsule().fill(G.cobalt.opacity(0.12)))
                        .pressable(0.97) { setTxt(steps, i, v.before); voice = nil; Haptic.tick() }
                        .accessibilityIdentifier("ux.voiceUndo")
                }
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.cobalt.opacity(0.08)))
            }
            // always under the field: the laser (or the radar to connect one) and hold-to-talk (UX upgrades section 6)
            HStack(spacing: 10) {
                LaserFieldButton(app: app, busy: laser == "busy") { reading(steps, unit) }
                MicButton(app: app) { mm, words in gotVoice(steps, i, mm, words, unit) }
            }
            // the usual sizes (a mattress's) a tap away
            if !s.picks.isEmpty { picksRow(steps, i, unit) }
            // the laser's state or its reading, in one line
            HStack(spacing: 8) {
                Circle().fill(on ? Color(argb: 0xFF16A34A) : G.ink3).frame(width: 9, height: 9)
                T(laser == "busy" ? tr("fx.busy") : laser ?? tr(on ? "fx.laserOn" : "fx.laserOff"), ui(12.5, 600, G.ink2, lh: 1.35)).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 4).frame(minHeight: 32)
            .id("fx.tools")
            // the floating "Keyingi" bar's room: scrolled to with the keyboard up, the field and the laser stay above the bar
            Color.clear.frame(height: 96).id("fx.end")
        }
    }

    private func picksRow(_ steps: [SizeStep], _ i: Int, _ unit: LenUnit) -> some View {
        let s = steps[i]
        let cur = parseLen(txt(steps, i), unit)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(s.picks, id: \.self) { v in
                    FChip(label: Geo.fmtLen(v, unit, en), on: cur == v) { setTxt(steps, i, Geo.fmtField(v, unit, en)); laser = nil }
                        .accessibilityIdentifier("fx.pick.\(v)")
                }
            }
        }
    }

    /// A corner piece's shape, or which of its sides were measured, as small top-down pictures.
    private func picsAsk(_ m: FModelDef, _ steps: [SizeStep]) -> some View {
        let i = at
        let s = steps[i]
        let cur = Int(txt(steps, i)) ?? s.usual
        let sh = texts["sh"].flatMap { Int($0) } ?? had["sh"] ?? 0
        return PicsAsk(m: m, s: s, cur: cur, sh: sh) { v in setTxt(steps, i, "\(v)") }
    }

    /// A choice on its own step (a bed's kind, a table's legs): one card an option, the chosen one marked.
    @ViewBuilder private func choiceAsk(_ steps: [SizeStep]) -> some View {
        let i = at
        let s = steps[i]
        let cur = Int(txt(steps, i)) ?? s.usual
        VStack(alignment: .leading, spacing: 8) {
            T(tr(s.label), ui(21, 800, G.ink, lh: 1.2)).padding(.top, 4)
            T(tr(s.help), ui(13, 400, G.ink2, lh: 1.4))
            ForEach(Array(s.opts.enumerated()), id: \.offset) { k, key in choiceCard(key, k == cur) { setTxt(steps, i, "\(k)") } }
        }
    }

    private func choiceCard(_ key: String, _ on: Bool, _ pick: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return HStack(spacing: 10) {
            ZStack {
                Circle().strokeBorder(on ? G.cobalt : G.ink3, lineWidth: 2).frame(width: 20, height: 20)
                if on { Circle().fill(G.cobalt).frame(width: 10, height: 10) }
            }
            VStack(alignment: .leading, spacing: 1) {
                T(tr(key), ui(15, 700, on ? G.cobalt2 : G.ink))
                T(tr(key + ".s"), ui(12.5, 400, G.ink2, lh: 1.35))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, 10).frame(minHeight: 56)
        .background(shape.fill(on ? G.cobalt.opacity(0.1) : G.glass(0.75)))
        .overlay(shape.strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 2 : 1))
        .pressable(0.98, pick)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
        .accessibilityIdentifier("fx.opt." + key)
    }

    /// A real laser's measurement goes into the size being asked, then on to the next step when it fits.
    private func gotReal(_ mm: Int) -> Bool {
        guard let m = fModel(model) else { return false }
        let steps = stepsNow(m)
        let i = at
        guard i < steps.count, !steps[i].choice, !steps[i].pics else { return false }
        let unit = AppSettings.shared.unit
        let tv = Geo.fmtField(mm, unit, en)
        setTxt(steps, i, tv)
        laser = tr("fx.got", ["v": Geo.fmtLen(mm, unit, en) + " " + unitWord(unit)])
        glow()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { nextAfter(i, tv, unit) }
        return true
    }

    /// A laser or voice value went in: the field glows green a moment, and a confirm haptic.
    private func glow() {
        Haptic.confirm()
        flash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { flash = false }
    }

    /// A size said: written into the field straight away (with "Bekor"), or the error when no number was understood.
    private func gotVoice(_ steps: [SizeStep], _ i: Int, _ mm: Int?, _ words: String, _ unit: LenUnit) {
        guard at == i, i < steps.count else { return }
        guard let mm else {
            heardBad = !words.isEmpty
            Haptic.warn()
            if words.isEmpty { app.say("ux.vNothing", kind: .info) }
            return
        }
        let before = txt(steps, i)
        setTxt(steps, i, Geo.fmtField(mm, unit, en))
        heardBad = false
        laser = nil
        voice = VoiceGot(said: words, before: before, step: i)
        glow()
    }

    /// With the real laser, its next measurement; with no laser, the radar to connect one. With the screen tests'
    /// simulator the laser's newest reading not used yet (its readings' inbox) fills the field first, and the next step
    /// opens; with none, a made-up one near the usual size (as the editor's laser button).
    private func reading(_ steps: [SizeStep], _ unit: LenUnit) {
        let i = at
        guard laser != "busy", i < steps.count, !steps[i].choice else { return }
        if LaserRouter.shared.isReal {
            LaserRouter.shared.waitFor(onCancel: { if laser == "busy" { laser = nil } }) { mm in
                laser = nil
                if !gotReal(mm) { AppSettings.shared.addReading(mm, "laser") }
            }
            laser = "busy"
            return
        }
        guard LaserRouter.shared.simOn else { app.openLaser(); return }
        let s = steps[i]
        if let r = AppSettings.shared.readings.last(where: { $0.used == nil && $0.src != "manual" }) {
            AppSettings.shared.markReadingUsed(r.id, tr(s.label))
            let tv = Geo.fmtField(r.mm, unit, en)
            setTxt(steps, i, tv)
            glow()
            laser = tr("fx.got", ["v": Geo.fmtLen(r.mm, unit, en) + " " + unitWord(unit)])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { nextAfter(i, tv, unit) }
            return
        }
        laser = "busy"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            let v = (s.usual + Int.random(in: -120...120)) / 5 * 5
            let tv = Geo.fmtField(v, unit, en)
            setTxt(steps, i, tv)
            glow()
            laser = tr("fx.got", ["v": Geo.fmtLen(v, unit, en) + " " + unitWord(unit)])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { nextAfter(i, tv, unit) }
        }
    }

    /// After a laser reading v went into step i: on to the next step when it fits (read from v, the value put in).
    private func nextAfter(_ i: Int, _ v: String, _ unit: LenUnit) {
        guard at == i, let m = fModel(model) else { return }
        let st = stepsNow(m)
        guard i < st.count, let mm = parseLen(v, unit), stepIssue(st[i], mm) == nil else { return }
        laser = nil
        if back { back = false; at = st.count } else { at = i + 1 }
    }

    /// What a step's value reads as in the summary: a choice's name, or a size with its unit.
    private func shown(_ steps: [SizeStep], _ i: Int, _ unit: LenUnit, _ uw: String) -> String {
        let s = steps[i]
        let text = txt(steps, i)
        if s.choice {
            let k = Int(text) ?? s.usual
            return tr(k >= 0 && k < s.opts.count ? s.opts[k] : s.opts[0])
        }
        return (parseLen(text, unit).map { Geo.fmtLen($0, unit, en) } ?? text) + " " + uw
    }

    @ViewBuilder private func summary(_ steps: [SizeStep], _ unit: LenUnit, _ uw: String, _ derived: [DerivedSide], _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                HStack(spacing: 10) {
                    T(tr(s.label), ui(14.5, 600)).frame(maxWidth: .infinity, alignment: .leading)
                    T(shown(steps, i, unit, uw), num(17, 700), lines: 1)
                    T(tr("fz.change"), ui(12.5, 700, G.cobalt2))
                }
                .padding(.horizontal, 12).padding(.vertical, 8).frame(minHeight: 54)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.glass(0.7)))
                .pressable(0.98) { was = txt(steps, i); back = true; at = i }
                .accessibilityElement(children: .combine).accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("fx.row.\(i)")
            }
            // a corner piece: the sides worked out from the ones typed, marked as such
            if !derived.isEmpty {
                DerivedCard(rows: derived.map { d in (tr(d.key), Geo.fmtLen(d.mm, unit, en) + " " + uw, d.bad) })
            }
            T(tr(note), ui(12.5, 400, G.ink2, lh: 1.45)).padding(.top, 4).padding(.leading, 4)
            // whether "Qaysi xonaga?" comes next or is skipped (UX upgrades section 7)
            if fid == nil, let p = Store.shared.get(pid) {
                let room = p.rooms.contains { measuredRoom($0, AppSettings.shared.angleSnap) }
                HStack(alignment: .top, spacing: 10) {
                    MIcon(room ? "room" : "info", G.cobalt2, 18, 2)
                    T(tr(room ? "ux.sum.room" : "ux.sum.skip"), ui(13, 500, G.ink, lh: 1.4)).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.blueWash))
            }
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
            let dv = derive(m, v)
            let sizes = stepsOf(m).filter { !$0.choice && ($0.key != "h" || m.kind != "kitchen") }.map { st in dv[st.key].map { Geo.fmtLen($0, unit, en) } ?? "?" }
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
        let f = { (mm: Int?) in Geo.fmtLen(mm, AppSettings.shared.unit, en) }
        HStack(spacing: 12) {
            MIcon(w?.type == "kitchen" ? "kitchen" : "room", ready ? G.cobalt : G.ink3, 24, 2)
            VStack(alignment: .leading, spacing: 3) {
                T(name, ui(15, 700, ready ? G.ink : G.ink3), lines: 1)
                if ready {
                    let fit = bestFirst(probe, Geo.walls(r, snap).map(\.id), { wallLen(r, snap, $0) }, r.dim("H").v, s.workshop)
                    let good = fit.1.isEmpty
                    T({ let z = Geo.roomSize(r, AppSettings.shared.angleSnap); return f(z?.0) + " × " + f(z?.1) }() + U_L + " · h " + f(r.dim("H").v), num(12.5, 500, G.ink2))
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

/// A size heard by the voice input: the words, the field's text before, and the step it went into.
struct VoiceGot: Equatable { let said: String; let before: String; let step: Int }
