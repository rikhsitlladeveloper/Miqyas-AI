import SwiftUI
import UIKit

/*
 * Choosing a product (22 Oct 2026; Android ui/win/WGallery.kt): the gallery of types grouped as windows, balcony and
 * doors, each card drawn by the app from the product's own boxes in a piece of wall; then where it goes: the openings
 * of the measured rooms it fits (several at once), or without a room at a typed size.
 */

private var wgEn: Bool { AppSettings.shared.lang == .en }

private struct WGGroupTops: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) { value.merge(nextValue()) { $1 } }
}

/* ---------------- the gallery ---------------- */

struct WGalleryScreen: View {
    let app: AppModel
    let pid: String
    var rid: String? = nil
    var oid: String? = nil
    var fromNew = false
    @State private var cur: String? = nil
    @State private var jumping = false
    @State private var viewH: CGFloat = 0

    /// The groups, an opening's own first (a door opening: the doors).
    private func groupsFor(_ op: Opening?) -> [String] {
        guard op?.type == "door" else { return W_GROUPS }
        return ["door", "balc", "win"]
    }

    var body: some View {
        if let p = Store.shared.get(pid) {
            let room = rid.flatMap { id in p.rooms.first { $0.id == id } }
            let op = oid.flatMap { id in room?.openings.first { $0.id == id } }
            let groups = groupsFor(op)
            let on = cur ?? groups.first ?? "win"
            let pics = WinPics.shared.pics
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    GlassIconButton("back", tr("nt.back")) { app.pop() }.padding(.leading, 6).accessibilityIdentifier("back")
                    BarTitle(title: tr("dw.galT"), eyebrow: dn(p.name))
                }
                .padding(.trailing, 12).frame(minHeight: 64)
                .background(G.sheet(0.55).ignoresSafeArea(edges: .top))
                .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
                ScrollViewReader { proxy in
                    chips(groups, on, proxy)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            T(intro(p, room, op), ui(13.5, 400, G.ink2, lh: 1.4))
                            ForEach(groups, id: \.self) { g in group(p, g, pics) }
                            if fromNew {
                                T(tr("fz.needL"), ui(14.5, 700, G.cobalt2)).padding(.horizontal, 16).padding(.vertical, 12).frame(maxWidth: .infinity)
                                    .pressable(0.97) { app.pop() }
                                    .accessibilityAddTraits(.isButton).accessibilityIdentifier("wg.later")
                            }
                            Color.clear.frame(height: 1)
                                .background(GeometryReader { geo in Color.clear.preference(key: WGGroupTops.self, value: ["_end": geo.frame(in: .named("wgal")).maxY]) })
                        }
                        .padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 28)
                    }
                    .coordinateSpace(name: "wgal")
                    .background(GeometryReader { geo in Color.clear.onAppear { viewH = geo.size.height }.onChange(of: geo.size.height) { _, h in viewH = h } })
                    // the chip of the group at the top of the list
                    .onPreferenceChange(WGGroupTops.self) { tops in
                        guard !jumping, !groups.isEmpty else { return }
                        let atEnd = viewH > 0 && (tops["_end"] ?? .infinity) <= viewH + 4
                        let top = atEnd ? groups[groups.count - 1] : groups.last { (tops[$0] ?? .infinity) <= 60 } ?? groups[0]
                        if top != cur { cur = top }
                    }
                }
            }
            .onAppear { WinPics.shared.make() }
        }
    }

    private func intro(_ p: Project, _ room: Room?, _ op: Opening?) -> String {
        guard let room else { return tr("dw.galB") }
        let f = { (mm: Int?) in Geo.fmtLen(mm, .m, wgEn) }
        let base = tr("tl.forRoom", ["r": wRoomName(p, room.id), "a": f(room.dim("A").v), "b": f(room.dim("B").v), "h": f(room.dim("H").v)])
        guard let op else { return base }
        return base + " · " + wOpeningName(room, op) + " " + wSizeText(op.w, op.h)
    }

    private func chips(_ groups: [String], _ on: String, _ proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(groups, id: \.self) { g in
                    let sel = g == on
                    T(tr("dw.grp." + g), ui(14, 700, sel ? G.solid : G.ink), lines: 1)
                        .padding(.horizontal, 16).frame(minHeight: 40)
                        .background(Capsule().fill(sel ? G.ink : G.glass(0.55)))
                        .pressable(0.97) {
                            cur = g; jumping = true
                            withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("wg-" + g, anchor: .top) }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { jumping = false }
                        }
                        .accessibilityAddTraits(sel ? [.isSelected, .isButton] : .isButton)
                        .accessibilityIdentifier("wg.chip." + g)
                }
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)
        }
    }

    @ViewBuilder private func group(_ p: Project, _ g: String, _ pics: [String: UIImage]) -> some View {
        let ks = W_KINDS.filter { $0.group == g }
        HStack(alignment: .lastTextBaseline, spacing: 8) { T(tr("dw.grp." + g), ui(17, 800)); T("\(ks.count)", ui(12.5, 500, G.ink3)) }
            .padding(.top, 8).padding(.leading, 2)
            .background(GeometryReader { geo in Color.clear.preference(key: WGGroupTops.self, value: [g: geo.frame(in: .named("wgal")).minY]) })
            .id("wg-" + g)
        ForEach(Array(stride(from: 0, to: ks.count, by: 2)), id: \.self) { i in
            HStack(alignment: .top, spacing: 10) {
                ForEach(ks[i..<min(i + 2, ks.count)], id: \.id) { k in
                    WGKindCard(k: k, pic: pics[k.id], wide: i + 1 >= ks.count) { app.push(.wPlace(pid: p.id, kind: k.id, rid: rid, oid: oid)) }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct WGKindCard: View {
    let k: WinKind
    let pic: UIImage?
    let wide: Bool
    let action: () -> Void
    var body: some View {
        let name = tr("dw.k." + k.id)
        let sub = tr("dw.kS." + k.id)
        let img = ZStack {
            Color(argb: 0xFFF6F8FC)
            if let pic { Image(uiImage: pic).resizable().scaledToFill() } else { T("3D…", ui(11, 600, G.ink3)) }
        }
        .aspectRatio(200 / 170, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        let words = VStack(alignment: .leading, spacing: 2) {
            T(name, ui(14.5, 800), lines: 2)
            T(sub, ui(12, 500, G.ink2, lh: 1.3), lines: 3)
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
        .accessibilityIdentifier("wkind." + k.id)
    }
}

/* ---------------- where it goes ---------------- */

private enum WGF: Hashable { case w, h }

struct WPlaceScreen: View {
    let app: AppModel
    let pid: String
    let kind: String
    let rid: String?
    let oid: String?
    /// the chosen openings ("room|opening")
    @State private var picks: [String]
    /// a typed size instead, without a room
    @State private var free: Bool
    @State private var tw: String
    @State private var th: String
    @State private var qty = 1
    @FocusState private var focus: WGF?

    init(app: AppModel, pid: String, kind: String, rid: String? = nil, oid: String? = nil) {
        self.app = app; self.pid = pid; self.kind = kind; self.rid = rid; self.oid = oid
        let k = wkind(kind)
        var start: [String] = []
        if let rid, let oid { start.append(rid + "|" + oid) }
        _picks = State(initialValue: start)
        _free = State(initialValue: Store.shared.get(pid)?.rooms.isEmpty ?? true)
        _tw = State(initialValue: "\(k.w)")
        _th = State(initialValue: "\(k.h)")
    }

    private var freeSize: (Int, Int)? {
        guard let W = Int(tw), let H = Int(th), (300...8000).contains(W), (300...4000).contains(H) else { return nil }
        return (W, H)
    }
    private var ok: Bool { free ? freeSize != nil : !picks.isEmpty }

    var body: some View {
        if let p = Store.shared.get(pid) {
            let k = wkind(kind)
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    HStack(spacing: 6) {
                        GlassIconButton("back", tr("nt.back")) { app.pop() }.padding(.leading, 6).accessibilityIdentifier("back")
                        BarTitle(title: tr("dw.k." + k.id), eyebrow: tr("dw.whereE"))
                    }
                    .padding(.trailing, 12).frame(minHeight: 64)
                    .background(G.sheet(0.55).ignoresSafeArea(edges: .top))
                    .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            picture(k)
                            T(tr("dw.kS." + k.id), ui(13, 500, G.ink2, lh: 1.35))
                            EAsk(title: tr("dw.whereT"), help: tr(k.isDoor ? "dw.whereD" : "dw.whereW")) {
                                ForEach(roomsOrdered(p)) { r in roomBlock(p, r, k) }
                                EOption(title: tr("dw.freeOpt"), sub: tr("dw.freeOptS"), on: free) {
                                    free.toggle()
                                    if free { picks = [] }
                                }
                                if free { freeFields }
                            }
                        }
                        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 120)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
                FloatingFooter {
                    GBtn(free ? tr("dw.putFree") : tr("dw.putN", ["n": picks.count]), enabled: ok) { save(p, k) }.accessibilityIdentifier("dw.put")
                }
            }
        }
    }

    private func picture(_ k: WinKind) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        return ZStack(alignment: .bottomTrailing) {
            WPicView(spec: wSamplePic(k.id))
            T(tr("fx.drag"), ui(11, 600, G.ink3)).padding(10).allowsHitTesting(false)
        }
        .aspectRatio(1.5, contentMode: .fit)
        .clipShape(shape)
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
    }

    private func roomsOrdered(_ p: Project) -> [Room] {
        p.rooms.filter { $0.id == rid } + p.rooms.filter { $0.id != rid }
    }

    @ViewBuilder private func roomBlock(_ p: Project, _ r: Room, _ k: WinKind) -> some View {
        let snap = AppSettings.shared.angleSnap
        let c = wCtxOf(p, r.id, snap)
        T(wRoomName(p, r.id), ui(15, 800)).padding(.top, 6)
        if let c {
            let ops = wOpeningsFor(c, k.id)
            if ops.isEmpty { T(tr(r.openings.isEmpty ? "dw.noOps" : "dw.noFit"), ui(13, 400, G.ink2, lh: 1.35)) }
            ForEach(ops) { o in openingCheck(p, r, o) }
        } else {
            HStack(spacing: 8) {
                MIcon("ruler", G.amberInk, 18, 2)
                T(tr("dw.measureFirst"), ui(13.5, 600, G.amberInk)).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.glass(0.6)))
            .pressable(0.98) { openRoom(app, p.id, r.id) }
            .accessibilityAddTraits(.isButton)
        }
    }

    private func openingCheck(_ p: Project, _ r: Room, _ o: Opening) -> some View {
        let key = r.id + "|" + o.id
        let on = picks.contains(key)
        let now = p.win.items.first { $0.roomId == r.id && $0.opening == o.id }
        let title = wOpeningName(r, o) + " · " + tr("tl.wallN", ["w": o.wall]) + " · " + wSizeText(o.w, o.h)
        let sub = now.map { tr("dw.replaces", ["n": tr("dw.k." + $0.kind)]) } ?? tr("dw.emptyOp")
        return WCheck(title: title, sub: sub, on: on) {
            free = false
            if on { picks.removeAll { $0 == key } } else { picks.append(key) }
        }
    }

    private var freeFields: some View {
        let uw = tr("dw.mm")
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                GField(label: tr("tl.pbW"), value: wDigits($tw, 4), placeholder: "1300", focus: $focus, me: .w, labelRight: uw, number: true).frame(maxWidth: .infinity)
                GField(label: tr("tl.pbH"), value: wDigits($th, 4), placeholder: "1400", focus: $focus, me: .h, labelRight: uw, number: true).frame(maxWidth: .infinity)
            }
            HStack {
                T(tr("dw.qty"), ui(15, 600)).frame(maxWidth: .infinity, alignment: .leading)
                EStepper(v: qty) { v in qty = min(max(v, 1), 99) }
            }
            .frame(minHeight: 52)
            if freeSize == nil { T(tr("dw.freeErr"), ui(13, 500, G.err)) }
        }
    }

    private func save(_ p: Project, _ k: WinKind) {
        guard ok, app.once() else { return }
        let p0 = p.id
        if free {
            guard let sz = freeSize else { return }
            var it = wNewItem(uid(), k, sz.0, sz.1, gap: p.win.gap)
            it.qty = qty
            let fresh = it
            updateWin(p0) { e in e.items.append(fresh) }
            app.popTo { if case .project(let id, _, _, _) = $0 { return id == p0 }; return false }
            app.push(.wDesign(pid: p0, iid: fresh.id))
            app.say("dw.added", ["n": tr("dw.k." + k.id)])
            return
        }
        let snap = AppSettings.shared.angleSnap
        var made: [WinItem] = []
        for pk in picks {
            let parts = pk.split(separator: "|", maxSplits: 1).map(String.init)
            guard parts.count == 2, let c = wCtxOf(p, parts[0], snap), let o = c.opening(parts[1]) else { continue }
            made.append(wFillOpening(uid(), k, c, o, p.win.gap))
        }
        if made.isEmpty { return }
        // a product put in an opening takes the place of the one there
        let fresh = made
        updateWin(p0) { e in
            e.items = e.items.filter { old in !fresh.contains { $0.roomId == old.roomId && $0.opening == old.opening } } + fresh
        }
        app.popTo { if case .project(let id, _, _, _) = $0 { return id == p0 }; return false }
        if fresh.count == 1 { app.push(.wDesign(pid: p0, iid: fresh[0].id)) }
        else if let r = fresh[0].roomId { app.push(.wView(pid: p0, rid: r)) }
        app.say("dw.placed", ["n": fresh.count])
    }
}

/// A choice that can be ticked, with a line under it.
struct WCheck: View {
    let title: String
    let sub: String
    let on: Bool
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let box = RoundedRectangle(cornerRadius: 6, style: .continuous)
        HStack(spacing: 10) {
            ZStack {
                box.fill(on ? G.cobalt : Color.clear)
                box.strokeBorder(on ? G.cobalt : G.ink3, lineWidth: 2)
                if on { MIcon("check", .white, 14, 2.6) }
            }
            .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                T(title, ui(15, 700, on ? G.cobalt2 : G.ink))
                T(sub, ui(12.5, 400, G.ink2, lh: 1.35))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, 10).frame(minHeight: 56)
        .background(shape.fill(on ? G.cobalt.opacity(0.1) : G.glass(0.75)))
        .overlay(shape.strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 2 : 1))
        .pressable(0.98, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isSelected, .isButton] : .isButton)
    }
}
