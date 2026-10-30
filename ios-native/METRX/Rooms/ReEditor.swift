import SwiftUI
import UIKit

/*
 * One room editor for every trade (room-editor mockup v2, approved 28 Oct 2026; scrEditor, edTools, edOpt, edTop,
 * drawEdChrome, drawEdCanvas): the plan, the selected wall from inside, or the simple 3D, all with taps that select;
 * under it a Canva-style tool slider that follows the selection, a tool's options replacing it with "←" back; undo,
 * redo, 2D / 3D and the trade's main button. Hold an item 0,4 s to slide it, drag to pan, two fingers to zoom, a
 * double tap fits. Adding goes through the same style window and size steps as the openings step. The old editor's
 * own tools stay under "Qo‘shimcha" (the old editor itself, columns and niches, the readings, the room's info, the
 * wall view and the real 3D).
 */

/// The editor's room in the saved project.
func reEditorHost(_ pid: String, _ rid: String) -> ReHost {
    let industry = Store.shared.get(pid)?.industry ?? "build"
    return ReHost(pid: pid, industry: industry, room: { Store.shared.get(pid)?.rooms.first { $0.id == rid } },
                  put: { r in Store.shared.update(pid) { p in if let i = p.rooms.firstIndex(where: { $0.id == rid }) { p.rooms[i] = r } } })
}

/// The trade's main button (mockup TRADES.main) and where it goes.
func reMainKey(_ industry: String) -> String {
    switch industry {
    case "furniture": return "re.main.furn"
    case "tiler": return "re.main.tile"
    case "elec": return "re.main.elec"
    case "plumb": return "re.main.plumb"
    case "win": return "re.main.win"
    default: return "re.main.build"
    }
}

func reMain(_ app: AppModel, _ pid: String, _ rid: String, _ industry: String) {
    Haptic.tick()
    switch industry {
    case "furniture": app.push(.fGallery(pid: pid, rid: rid))
    case "tiler": app.push(.tGallery(pid: pid, rid: rid))
    case "elec": app.push(.eView(pid: pid, rid: rid))
    case "plumb": app.push(.pView(pid: pid, rid: rid))
    case "win": app.push(.wView(pid: pid, rid: rid))
    default:
        app.popTo { if case .project(let id, _, _, _) = $0 { return id == pid }; return false }
        app.setProjectTab("estimate")
    }
}

/// The tools' icons (24 × 24, the mockup's).
let RE_IC: [String: String] = [
    "add": "M12 5v14M5 12h14",
    "shape": "M4 4h10v6h6v10H4z",
    "rh": "M12 3v18M8 7l4-4 4 4M8 17l4 4 4-4",
    "rot": "M20 12a8 8 0 1 1 -2.3-5.6M20 4v5h-5",
    "rotL": "M4 12a8 8 0 1 0 2.3-5.6M4 4v5h5",
    "mirror": "M12 3v18M9 7L3.5 17H9zM15 7l5.5 10H15z",
    "dims": "M3 17L17 3l4 4L7 21zM7 13l2 2M10 10l2 2M13 7l2 2",
    "checks": "M12 3.5l9 16H3zM12 10v4M12 17h.01",
    "v3d": "M12 3l8 4.5v9L12 21l-8-4.5v-9zM12 12l8-4.5M12 12v9M12 12L4 7.5",
    "more": "M4 7h10M18 7h2M16 5v4M4 17h4M12 17h8M10 15v4",
    "len": "M3 17L17 3l4 4L7 21zM7 13l2 2M10 10l2 2M13 7l2 2",
    "laser": "M2.5 8h11v8h-11zM13.5 12h4M20 9v6M18.5 12h3",
    "pt": "M12 7a3 3 0 1 0 0 6a3 3 0 1 0 0 -6M12 21s-7-6-7-11a7 7 0 0 1 14 0c0 5-7 11-7 11z",
    "thick": "M4 6h16M4 18h16M12 8.5v7M9.5 11L12 8.5 14.5 11M9.5 13l2.5 2.5 2.5-2.5",
    "corner": "M5 19V5h14M5 12a7 7 0 0 1 7-7",
    "w": "M4 5v14M20 5v14M7 12h10M10 9l-3 3 3 3M14 9l3 3-3 3",
    "h": "M12 3v18M8 7l4-4 4 4M8 17l4 4 4-4",
    "sill": "M5 3h14v10H5zM3 15.5h18M12 15.5v5M10 18.5l2 2 2-2",
    "move": "M3 12h18M7 8l-4 4 4 4M17 8l4 4-4 4",
    "type": "M4 4h16v16H4zM4 10h16M4 15h16",
    "swing": "M5 3h14v18H5zM19 3L7 12l12 9",
    "copy": "M8 8h12v12H8zM16 8V5H4v11h4",
    "del": "M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13",
    "kbd": "M3 6h18v12H3zM7 10h.01M11 10h.01M15 10h.01M7 14h10",
    "fit": "M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5",
    "inner": IW_IC,
    "iwOf": IW_IC,
    "iwFace": "M4 4h16v16H4zM12 4v16",
]

/// A tool's icon: its own, or the one it shares (the inner wall's tools borrow the room's).
func reToolIcon(_ t: String) -> String {
    let alias = ["ptype": "type", "ph": "h", "iwLen": "len", "iwTh": "thick", "iwH": "h", "iwOp": "w", "iwShape": "shape", "iwRot": "rot",
                 "iwCopy": "copy", "iwDel": "del"]
    return RE_IC[t] ?? RE_IC[alias[t] ?? "more"] ?? ""
}

/// A tool's label: the room editor's (re.t.*) or the inner wall's (iw.t.*).
func reToolLabel(_ t: String, _ col: Bool) -> String {
    if t == "iwLen" && col { return reTr("iw.t.iwSize") }
    return t == "inner" || t.hasPrefix("iw") ? reTr("iw.t." + t) : reTr("re.t." + t)
}

/// A tool of the slider: icon over its label; red for O‘chirish; on for a switch that is on; a count badge.
private struct ReToolBtn: View {
    let id: String
    let label: String
    let icon: String
    var badge: Int? = nil
    var red = false
    var on = false
    let action: () -> Void
    var body: some View {
        let fg: Color = red ? G.err : on ? G.cobalt2 : G.ink
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                if id == "addDoor" || id == "addWin" { PathIcon(reKind(id == "addDoor" ? "door" : "window").icon, RD.kind(id == "addDoor" ? "door" : "window"), 24, 2) }
                else { PathIcon(icon, red ? G.err : on ? G.cobalt2 : G.ink2, 24, 2) }
                if let b = badge {
                    T(b > 0 ? "\(b)" : "✓", ui(10.5, 800, .white), align: .center)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Capsule().fill(b > 0 ? RD.issue : G.green))
                        .offset(x: 10, y: -6)
                }
            }
            .frame(width: 34, height: 26)
            T(label, ui(dzcToolLabelSize(label), 700, fg, lh: 1.1), align: .center, lines: 2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
        .frame(width: 70, height: 62)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(on ? G.cobalt.opacity(0.11) : .clear))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(on ? G.cobalt : .clear, lineWidth: 2))
        .pressable(0.95, label: label, action)
        .accessibilityIdentifier("re.t." + id)
    }
}

/// An option in a tool's row: an icon or none, its label; on the current one; red, or an issue.
struct ReOpt: View {
    let label: String
    var icon: String? = nil
    var on = false
    var tone = ""
    var id = ""
    let action: () -> Void
    var body: some View {
        let fg: Color = tone == "iss" || tone == "red" ? RD.issue : tone == "ok" ? G.green : on ? G.cobalt2 : G.ink
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        HStack(spacing: 7) {
            if let icon { PathIcon(icon, fg, 19, 2) }
            T(label, num(13, on ? 800 : 700, fg), lines: 2).fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12).frame(minHeight: 52)
        .background(shape.fill(on ? G.cobalt.opacity(0.1) : G.glass(0.7)))
        .overlay(shape.strokeBorder(on ? G.cobalt : tone == "iss" ? RD.issue : G.rim, lineWidth: on ? 2 : tone == "iss" ? 1.5 : 1))
        .pressable(0.97, action)
        .accessibilityIdentifier(id)
    }
}

struct ReEditorScreen: View {
    let app: AppModel
    let pid: String
    let rid: String
    @State private var backToken = 0

    var body: some View {
        let st = ReState.of("ed:" + rid)
        let h = reEditorHost(pid, rid)
        if let p = Store.shared.get(pid), let r0 = h.room() {
            let r = st.shown(h) ?? r0
            let g = reGeo(r)
            let items = reItems(r)
            let issues = reRoomIssues(r, g)
            ZStack {
                VStack(spacing: 0) {
                    top(st, h, p, r, g)
                    ZStack(alignment: .topLeading) {
                        ReCanvas(app: app, st: st, h: h, ops: false)
                        overlays(st, h, r, g, items)
                    }
                    .frame(maxHeight: .infinity)
                    .background(RD.paper.opacity(0.6))
                    toolBar(st, h, r, g, items, issues)
                    bottom(st, h, p)
                }
                if let k = st.tileKind {
                    let line = st.ghost.map { gh in reTr("re.dragTo", ["w": reWL(gh.wall)]) + " · " + reLen(reDists(gh, g.len(gh.wall)).l) + " | " + reLen(reDists(gh, g.len(gh.wall)).r) } ?? reTr("re.dragNear")
                    ReDragChip(kind: k, line: line, ok: st.ghost != nil).position(x: st.tilePt.x, y: st.tilePt.y - 56)
                }
                RePickWindow(app: app, st: st, h: h)
                ReIwWindow(app: app, st: st, h: h)
                ReKpOverlay(app: app, st: st)
            }
            .coordinateSpace(name: "re")
            .laserSink { mm in
                // a real laser's reading: into the size being asked, the number being typed, or the selected wall
                if st.kp != nil { st.kpText = rshFieldText(mm, AppSettings.shared.unit); st.flash += 1; Haptic.confirm(); return true }
                if st.pkField() != nil { st.pkSet(mm); st.flash += 1; Haptic.confirm(); return true }
                if let w = st.selWall { st.setWallLen(w, mm, app, h, laser: true); return true }
                return false
            }
            .onAppear {
                if g.wall(st.fw) == nil { st.fw = g.walls.first?.id ?? "A" }
                BackOwner.seq += 1; backToken = BackOwner.seq; BackOwner.last = backToken
                app.backOverride = { edBack(st, h) }
            }
            .onDisappear { if BackOwner.last == backToken { app.backOverride = nil; BackOwner.last = 0 } }
            .animation(.easeOut(duration: 0.18), value: st.pk != nil)
        } else {
            Color.clear.onAppear { app.pop() }
        }
    }

    /// Back closes what is open first (the window, a number, an options row, the selection), then the page.
    private func edBack(_ st: ReState, _ h: ReHost) {
        if st.kp != nil { st.kp = nil; return }
        if st.iwWin { st.iwWin = false; return }
        if let p = st.pk { if p.phase == "style" { st.pkCancel() } else { st.pkBack(h) }; return }
        if st.strip != nil { st.strip = nil; return }
        if st.sel != nil || st.arm != nil { st.deselect(); return }
        st.reset()
        app.pop()
    }

    /* ---------------- the top: back, the room, Reja / Devor X ---------------- */

    private func top(_ st: ReState, _ h: ReHost, _ p: Project, _ r: Room, _ g: ReRoomGeo) -> some View {
        UXTop {
            HStack(spacing: 8) {
                GlassIconButton("back", tr("nt.back")) { edBack(st, h) }.accessibilityIdentifier("back")
                VStack(alignment: .leading, spacing: 1) {
                    T((dn(p.customer).isEmpty ? dn(p.name) : dn(p.customer)) + " · " + tr("sd.n." + sdTrade(p)), ui(12, 600, G.cobalt2), lines: 1)
                    T(dn(r.name), ui(18, 800, lh: 1.18), lines: 1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if st.view == "3d" {
                    T("3D", ui(13, 700, G.ink3)).padding(.horizontal, 12).frame(height: 40)
                } else {
                    HStack(spacing: 0) {
                        seg(reTr("re.plan"), st.view == "plan", "re.vPlan") { st.view = "plan"; st.last2d = "plan" }
                        seg(reTr("re.wallX", ["w": reWL(st.fw)]), st.view == "front", "re.vFront") { st.view = "front"; st.last2d = "front" }
                    }
                    .padding(3)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.glass(0.6)))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8).frame(minHeight: 64)
        }
    }

    private func seg(_ t: String, _ on: Bool, _ id: String, _ a: @escaping () -> Void) -> some View {
        T(t, ui(13, 700, on ? G.ink : G.ink2), lines: 1).padding(.horizontal, 11).frame(height: 36)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(on ? G.solid : .clear))
            .pressable(0.97) { Haptic.tick(); a() }
            .accessibilityIdentifier(id)
    }

    /* ---------------- over the drawing: the caption, zoom, armed bar, front wall chips, 3D hint ---------------- */

    @ViewBuilder private func overlays(_ st: ReState, _ h: ReHost, _ r: Room, _ g: ReRoomGeo, _ items: [ReItem]) -> some View {
        let cam = st.cam(st.view)
        VStack(alignment: .leading, spacing: 0) {
            caption(st, h, r, g, items).padding(.horizontal, 10).padding(.top, 6)
            Spacer(minLength: 0)
            if st.view == "3d" {
                HStack(spacing: 6) { MIcon("info", G.cobalt, 16, 2); T(reTr("re.isoHint"), ui(12, 700, G.ink2), lines: 2) }
                    .padding(.horizontal, 12).frame(minHeight: 30)
                    .background(Capsule().fill(G.sheet(0.94)))
                    .frame(maxWidth: .infinity).padding(.bottom, 10)
                    .allowsHitTesting(false)
            }
            if st.view == "front" {
                // a row that scrolls: with an inner wall's letters it widened the whole page past the screen
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(g.walls, id: \.id) { w in
                            let on = w.id == st.fw
                            T(reWL(w.id), ui(13, 800, on ? .white : G.ink)).frame(minWidth: 44, minHeight: 40)
                                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(on ? G.cobalt : G.sheet(0.94)))
                                .pressable(0.96) { st.fw = w.id; st.cams["front"] = ReCam(); if st.selWall != nil { st.sel = .wall(w.id) }; Haptic.tick() }
                                .accessibilityIdentifier("re.fw." + w.id)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxWidth: .infinity).padding(.bottom, 8)
            }
        }
        HStack(spacing: 6) {
            Spacer()
            if !cam.fit {
                HStack(spacing: 6) {
                    PathIcon(RE_IC["fit"]!, G.ink2, 16, 2)
                    T(String(format: "%.1f", cam.z).replacingOccurrences(of: ".", with: AppSettings.shared.lang == .en ? "." : ",") + "× · " + reTr("re.fit"), ui(12, 700, G.ink2), lines: 1)
                }
                .padding(.horizontal, 12).frame(height: 34)
                .background(Capsule().fill(G.sheet(0.94)))
                .pressable(0.96) { st.cams[st.view] = ReCam(); Haptic.tick() }
                .accessibilityIdentifier("re.fitView")
            }
        }
        .padding(.trailing, 10)
        .frame(maxHeight: .infinity, alignment: .bottom)
        // above the wall chips (front) and the 3D hint (two lines in Russian), not under them
        .padding(.bottom, st.view == "front" ? 56 : st.view == "3d" ? 64 : 10)
        if let k = st.arm {
            HStack(spacing: 8) {
                PathIcon(reKind(k).icon, .white, 16, 2)
                T(reTr("re.armBar", ["n": reKindName(k)]), ui(12.5, 700, .white), lines: 1).frame(maxWidth: .infinity, alignment: .leading)
                MIcon("x", .white, 16, 2).frame(width: 34, height: 34).background(Circle().fill(Color.white.opacity(0.2)))
                    .pressable(0.95) { st.arm = nil }
            }
            .padding(.leading, 12).padding(.trailing, 4).frame(minHeight: 40)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.cobalt))
            .padding(.horizontal, 10)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, st.view == "front" ? 56 : 8)
        }
    }

    @ViewBuilder private func caption(_ st: ReState, _ h: ReHost, _ r: Room, _ g: ReRoomGeo, _ items: [ReItem]) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        if st.arm == nil {
            if let w = st.selWall {
                let n = items.filter { $0.wall == w }.count
                capRow(reTr("re.wallCap", ["w": reWL(w), "l": reLen(g.len(w)), "v": reLen(g.len(w))]), reTr("re.wallCapS", ["t": reLenU(r.thickOf(w)), "n": n]), x: { st.deselect() }, shape)
            } else if let id = st.selPiece, let p = r.inner.first(where: { $0.id == id }) {
                capRow(iwName(p.k) + (st.newPiece == id ? " · " + reTr("iw.c.new") : ""), iwSizeLine(p, g.H) + " " + unitWord(AppSettings.shared.unit), x: { st.deselect() }, shape)
            } else if let id = st.selItem, let it = items.first(where: { $0.id == id }) {
                let d = reDists(it, g.len(it.wall))
                capRow(reItemName(it), reSizeLine(it) + " · " + reWL(it.wall) + " · " + reLen(d.l) + " | " + reLen(d.r), x: { st.deselect() }, shape)
            } else {
                HStack(spacing: 6) {
                    T(dn(r.name), ui(13, 800), lines: 1)
                    T(reTr("rsh.s." + reShapeOf(r)) + " · " + reAreaShort(g) + " · h " + reLen(g.H), ui(12, 500, G.ink2), lines: 1)
                }
                .padding(.horizontal, 12).frame(minHeight: 34)
                .background(shape.fill(G.sheet(0.94)))
                .allowsHitTesting(false)
            }
        }
    }

    private func capRow(_ t: String, _ s: String, x: @escaping () -> Void, _ shape: RoundedRectangle) -> some View {
        HStack(spacing: 6) {
            T(t, ui(13, 800), lines: 1)
            T(s, num(12, 500, G.ink2), lines: 1)
            MIcon("x", G.ink2, 15, 2).frame(width: 30, height: 30).background(Circle().fill(G.glass(0.8)))
                .pressable(0.95, label: reTr("re.desel"), x)
                .accessibilityIdentifier("re.capX")
        }
        .padding(.leading, 12).padding(.trailing, 4).frame(minHeight: 34)
        .background(shape.fill(G.sheet(0.94)))
    }

    /* ---------------- the tools and their options ---------------- */

    @ViewBuilder private func toolBar(_ st: ReState, _ h: ReHost, _ r: Room, _ g: ReRoomGeo, _ items: [ReItem], _ issues: [ReIssue]) -> some View {
        VStack(spacing: 0) {
            if let k = st.strip, reToolIds(st, h).contains(k) {
                options(k, st, h, r, g, items, issues)
            } else {
                HStack(spacing: 8) {
                    T(toolsTitle(st, h, items), ui(12.5, 800), lines: 1)
                    T(toolsSub(st), ui(11.5, 600, G.ink2), lines: 1)
                }
                .padding(.horizontal, 14).padding(.top, 6).frame(maxWidth: .infinity, alignment: .leading)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(reToolIds(st, h), id: \.self) { t in tool(t, st, h, r, issues) }
                    }
                    .padding(.leading, 8).padding(.trailing, 28).padding(.vertical, 4)
                }
                .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.86), .init(color: .black.opacity(0.3), location: 1)],
                                     startPoint: .leading, endPoint: .trailing))
                .accessibilityIdentifier("re.slider")
            }
        }
        .background(Rectangle().fill(G.sheet(0.97)))
        .overlay(alignment: .top) { Rectangle().fill(G.rim).frame(height: 1) }
        // toasts rise above the tools too, so they never cover one
        .bottomBar()
    }

    private func toolsTitle(_ st: ReState, _ h: ReHost, _ items: [ReItem]) -> String {
        switch st.sel {
        case .wall(let w)?: return iwPieceOf(w) != nil ? reTr("iw.faceT", ["w": reWL(w)]) : reTr("re.wallX", ["w": reWL(w)])
        case .piece(let id)?: return h.room()?.inner.first { $0.id == id }.map { iwName($0.k) } ?? ""
        case .item(let id)?: return items.first { $0.id == id }.map { reKindName($0.kind) } ?? ""
        default: return reTr("re.toolsT")
        }
    }
    private func toolsSub(_ st: ReState) -> String {
        switch st.sel {
        case .wall(let w)?: return iwPieceOf(w) != nil ? reTr("iw.faceSub") : reTr("re.toolsWall")
        case .piece?: return reTr("iw.toolsSub")
        case .item?: return reTr("re.toolsItem")
        default: return reTr("re.toolsNone")
        }
    }

    @ViewBuilder private func tool(_ t: String, _ st: ReState, _ h: ReHost, _ r: Room, _ issues: [ReIssue]) -> some View {
        let label = reToolLabel(t, st.curPiece(h)?.k == "col")
        let icon = reToolIcon(t)
        ReToolBtn(id: t, label: label, icon: icon, badge: t == "checks" ? issues.count : nil, red: t == "del" || t == "iwDel", on: t == "v3d" && st.view == "3d") {
            Haptic.tick()
            switch t {
            case "v3d": st.view = st.view == "3d" ? st.last2d : "3d"
            case "laser": wallLaser(st, h)
            case "addDoor", "addWin":
                if let w = st.selWall { st.placeAt(t == "addDoor" ? "door" : "window", wall: w, centre: reGeo(r).len(w) / 2, how: "chip", app, h) }
            case "copy": st.dupSel(app, h)
            case "del": st.delSel(app, h)
            case "type", "ptype": st.pickFor("retype", h)
            case "inner": st.iwWin = true; st.strip = nil; st.arm = nil
            case "iwRot": st.iwRotate(app, h)
            case "iwCopy": st.iwCopy(app, h)
            case "iwDel": st.iwDel(app, h)
            case "iwOf": if let p = st.curPiece(h) { st.selectPiece(p.id, h) }
            default: st.strip = t; st.arm = nil
            }
        }
    }

    /// Lazer on a wall: the laser's next reading becomes its length (with no laser, the radar to connect one).
    private func wallLaser(_ st: ReState, _ h: ReHost) {
        guard let w = st.selWall, let r = h.room() else { return }
        let L = reGeo(r).len(w)
        rshRead(app, st, L, reTr("re.wallX", ["w": reWL(w)])) { mm in st.setWallLen(w, mm, app, h, laser: true) }
    }

    @ViewBuilder private func options(_ k: String, _ st: ReState, _ h: ReHost, _ r: Room, _ g: ReRoomGeo, _ items: [ReItem], _ issues: [ReIssue]) -> some View {
        let it = st.selItem.flatMap { id in items.first { $0.id == id } }
        let wi = st.selWall
        let back = { st.strip = nil; Haptic.tick() }
        switch k {
        case "add", "pt":
            VStack(alignment: .leading, spacing: 0) {
                DzcOptRow(title: tr(k == "add" ? "re.t.add" : "re.t.pt"), sub: tr(k == "add" ? "re.tilesS" : "re.ptSub", ["w": reWL(wi ?? "")]), onBack: back) {
                    if k == "add" { ReOpt(label: reTr("iw.tile"), icon: IW_IC, id: "re.o.iw") { st.iwWin = true } }
                }
                ReTileRow(st: st, groups: k == "add" ? reGroups(h.industry) : reGroups(h.industry).filter { !$0.contains("door") },
                          tap: { kind in st.tileTap(kind, app, h) },
                          drag: { kind, p in
                              if st.view == "3d" { return }
                              st.dragTile(kind, p, h, ops: false)
                          },
                          drop: { kind, p in st.dropTile(kind, p, app, h, front: st.view == "front") })
                    .padding(.bottom, 6)
            }
        case "shape":
            DzcOptRow(title: reTr("re.t.shape"), sub: reTr("re.shapeSub", ["s": reTr("rsh.s." + reShapeOf(r))]), onBack: back) {
                ForEach(RoomShape.allCases.filter { $0 != .free }, id: \.self) { s in
                    ReOpt(label: reTr("rsh.s." + s.id), icon: RE_IC["shape"], on: reShapeOf(r) == s.id, id: "re.o.shape." + s.id) { st.setShape(s.id, app, h) }
                }
                ReOpt(label: reTr("rsh.s.free"), on: false, id: "re.o.shape.free") { app.toast = ToastMsg(text: reTr("re.m.free"), kind: .info) }
            }
        case "rh":
            DzcOptRow(title: reTr("re.t.rh"), sub: reTr("re.rhSub", ["v": reLenU(g.H)]), onBack: back) {
                ForEach([2500, 2600, 2700, 2800, 3000, 3200], id: \.self) { v in
                    ReOpt(label: reLen(v), on: g.H == v, id: "re.o.rh.\(v)") { st.setRoomH(v, app, h) }
                }
                ReOpt(label: reTr("re.type2"), icon: RE_IC["kbd"], id: "re.o.rhKp") {
                    st.openKp(reTr("re.t.rh"), cur: g.H, lo: SHAPE_HEIGHT_MIN, hi: SHAPE_HEIGHT_MAX) { st.setRoomH($0, app, h) }
                }
            }
        case "rot":
            DzcOptRow(title: reTr("re.t.rot"), sub: reTr("re.rotSub"), onBack: back) {
                ReOpt(label: reTr("re.rotL"), icon: RE_IC["rotL"], id: "re.o.rotL") { st.turn(-1, app, h) }
                ReOpt(label: reTr("re.rotR"), icon: RE_IC["rot"], id: "re.o.rotR") { st.turn(1, app, h) }
                ReOpt(label: reTr("rsh.mirror"), icon: RE_IC["mirror"], id: "re.o.mirror") { st.mirror(app, h) }
            }
        case "dims":
            DzcOptRow(title: reTr("re.t.dims"), sub: reTr("re.dimsSub"), onBack: back) {
                ReOpt(label: reTr("re.dLen"), icon: RE_IC["len"], on: st.dimLen, id: "re.o.dLen") { st.dimLen.toggle() }
                ReOpt(label: reTr("re.dChain"), icon: RE_IC["w"], on: st.dimChain, id: "re.o.dChain") { st.dimChain.toggle() }
                ReOpt(label: reTr("re.dArea"), icon: RE_IC["shape"], on: st.dimArea, id: "re.o.dArea") { st.dimArea.toggle() }
            }
        case "checks":
            DzcOptRow(title: reTr("re.t.checks"), sub: issues.isEmpty ? reTr("re.chkOk") : reTr("re.chkN", ["n": issues.count]), onBack: back) {
                if issues.isEmpty {
                    ReOpt(label: reTr("re.chkNone"), icon: "M5 12.5l4.5 4.5L19 7", tone: "ok", id: "re.o.chkNone") {}
                } else {
                    ForEach(Array(issues.enumerated()), id: \.offset) { _, q in
                        ReOpt(label: reIssueText(q), icon: RE_IC["checks"], tone: "iss", id: "re.o.iss") {
                            if st.view == "3d" { st.view = "plan" }
                            st.strip = nil
                            st.select(q.id, h)
                        }
                    }
                }
            }
        case "more":
            DzcOptRow(title: reTr("re.t.more"), sub: reTr("re.moreSub"), onBack: back) {
                if h.industry == "furniture" {
                    ReOpt(label: tr("fp.placeT"), icon: RE_IC["move"], id: "re.o.fp") { app.push(.fArrange(pid: pid, rid: rid)) }
                }
                ReOpt(label: reTr("re.oldEd"), icon: RE_IC["more"], id: "re.old") { st.reset(); app.replaceTop(.editor(pid: pid, rid: rid, mode: "plan")) }
                ReOpt(label: reTr("re.feat"), icon: RE_IC["shape"], id: "re.o.feat") { app.sheet = .featureForm(pid: pid, rid: rid, fid: nil, type: "column") }
                ReOpt(label: reTr("re.tray"), icon: RE_IC["laser"], id: "re.o.tray") { app.sheet = .tray(pid: pid, rid: rid) }
                ReOpt(label: reTr("re.info"), icon: RE_IC["type"], id: "re.o.info") { app.sheet = .roomInfo(pid: pid, rid: rid) }
                ReOpt(label: reTr("re.wallView", ["w": reWL(st.fw)]), icon: RE_IC["sill"], id: "re.o.wallView") { app.push(.wallView(pid: pid, rid: rid, wall: st.fw)) }
                ReOpt(label: reTr("re.real3d"), icon: RE_IC["v3d"], id: "re.o.real3d") { app.push(.editor(pid: pid, rid: rid, mode: "3d")) }
            }
        case "len":
            let w = wi ?? "A"
            let L = g.len(w)
            let auto = r.isPoly && (g.wall(w)?.auto ?? false) && r.dim(w).v == nil
            DzcOptRow(title: reTr("re.t.len"), sub: auto ? reTr("re.lenAuto", ["w": reWL(w), "v": reLenU(L)]) : reTr("re.lenSub", ["w": reWL(w), "v": reLenU(L)]), onBack: back) {
                if auto {
                    T(reTr("re.m.auto"), ui(11.5, 600, G.ink2, lh: 1.25)).frame(maxWidth: 220, alignment: .leading)
                } else {
                    ForEach([-100, -10], id: \.self) { s in ReOpt(label: "−" + reLen(-s), id: "re.o.len\(s)") { st.setWallLen(w, L + s, app, h) } }
                    ReOpt(label: reLenU(L), on: true, id: "re.o.lenNow") {}
                    ForEach([10, 100], id: \.self) { s in ReOpt(label: "+" + reLen(s), id: "re.o.len+\(s)") { st.setWallLen(w, L + s, app, h) } }
                    ReOpt(label: reTr("re.type2"), icon: RE_IC["kbd"], id: "re.o.lenKp") {
                        st.openKp(reTr("re.wallLen", ["w": reWL(w), "v": reLenU(L)]), cur: L, lo: SHAPE_WALL_MIN, hi: SHAPE_WALL_MAX, big: true) { st.setWallLen(w, $0, app, h) }
                    }
                }
            }
        case "thick":
            let w = wi ?? "A"
            DzcOptRow(title: reTr("re.t.thick"), sub: reTr("re.thickSub", ["w": reWL(w), "v": reLen(r.thickOf(w))]), onBack: back) {
                ForEach([100, 120, 200, 250, 380, 510], id: \.self) { v in
                    ReOpt(label: reLenU(v), on: r.thickOf(w) == v, id: "re.o.th\(v)") { st.setThick(v, app, h) }
                }
                ReOpt(label: reTr("re.type2"), icon: RE_IC["kbd"], id: "re.o.thKp") {
                    st.openKp(reTr("re.t.thick"), cur: r.thickOf(w), lo: 50, hi: 1000) { st.setThick($0, app, h) }
                }
            }
        case "corner":
            let w = wi ?? "A"
            let a0 = reCornerAngle(g, w), a1 = reCornerAngle(g, g.next(w))
            DzcOptRow(title: reTr("re.t.corner"), sub: reTr("re.cornerSub", ["w": reWL(w)]), onBack: back) {
                ReOpt(label: reTr("re.angWith", ["w": g.prev(w), "a": a0]), id: "re.o.ang0") {}
                ReOpt(label: reTr("re.angWith", ["w": g.next(w), "a": a1]), id: "re.o.ang1") {}
                ReOpt(label: reTr("re.diag"), icon: RE_IC["len"], id: "re.o.diag") { diagCheck(st, g, w) }
                T(reTr("re.cornerNote"), ui(11.5, 600, G.ink2, lh: 1.25)).frame(maxWidth: 190, alignment: .leading)
            }
        case "w":
            if let it {
                let cw = it.kind == "door" ? [700, 800, 900] : [1200, 1500, 1800]
                DzcOptRow(title: reTr("re.t.w"), sub: reTr("re.wSub", ["n": reKindName(it.kind), "v": reLenU(it.w)]), onBack: back) {
                    ForEach(cw, id: \.self) { v in ReOpt(label: reLen(v), on: it.w == v, id: "re.o.w\(v)") { st.setSize("w", v, app, h) } }
                    ReOpt(label: reTr("re.type2"), icon: RE_IC["kbd"], id: "re.o.wKp") {
                        st.openKp(reTr("re.kpW", ["n": reKindName(it.kind)]), cur: it.w, lo: 300, hi: g.len(it.wall)) { st.setSize("w", $0, app, h) }
                    }
                }
            }
        case "h":
            if let it {
                let ch = it.kind == "door" || it.isBalcony ? [2000, 2100, 2200] : [1200, 1400, 1500]
                DzcOptRow(title: reTr("re.t.h"), sub: reTr("re.hSub", ["n": reKindName(it.kind), "v": reLenU(it.h)]), onBack: back) {
                    ForEach(ch, id: \.self) { v in ReOpt(label: reLen(v), on: it.h == v, id: "re.o.h\(v)") { st.setSize("h", v, app, h) } }
                    ReOpt(label: reTr("re.type2"), icon: RE_IC["kbd"], id: "re.o.hKp") {
                        st.openKp(reTr("re.kpH", ["n": reKindName(it.kind)]), cur: it.h, lo: 300, hi: g.H - it.z0) { st.setSize("h", $0, app, h) }
                    }
                }
            }
        case "sill":
            if let it {
                if it.kind == "window" {
                    DzcOptRow(title: reTr("re.t.sill"), sub: reTr("re.sillSub", ["v": reLenU(it.sill)]), onBack: back) {
                        ForEach([800, 900], id: \.self) { v in ReOpt(label: reLen(v), on: it.sill == v, id: "re.o.s\(v)") { st.setSize("sill", v, app, h) } }
                        ReOpt(label: reTr("re.type2"), icon: RE_IC["kbd"], id: "re.o.sKp") {
                            st.openKp(reTr("re.kpSill"), cur: it.sill, lo: 0, hi: g.H - it.h) { st.setSize("sill", $0, app, h) }
                        }
                    }
                } else {
                    DzcOptRow(title: reTr("re.thrT"), sub: reTr("re.thrSub", ["v": reLen(it.thr)]), onBack: back) {
                        ForEach([0, 20, 40], id: \.self) { v in ReOpt(label: reLenU(v), on: it.thr == v, id: "re.o.thr\(v)") { st.setSize("thr", v, app, h) } }
                    }
                }
            }
        case "move":
            if let it {
                let d = reDists(it, g.len(it.wall))
                DzcOptRow(title: reTr("re.t.move"), sub: reTr("re.moveSub", ["l": reLen(d.l), "r": reLen(d.r), "a": reLen(d.l), "b": reLen(d.r)]), onBack: back) {
                    ReOpt(label: reLen(100), icon: DZC_ICON["left"], id: "re.o.mv-100") { st.moveSel("-100", app, h) }
                    ReOpt(label: reLen(10), icon: DZC_ICON["left"], id: "re.o.mv-10") { st.moveSel("-10", app, h) }
                    ReOpt(label: reLen(10), icon: DZC_ICON["right"], id: "re.o.mv10") { st.moveSel("10", app, h) }
                    ReOpt(label: reLen(100), icon: DZC_ICON["right"], id: "re.o.mv100") { st.moveSel("100", app, h) }
                    Rectangle().fill(G.ink.opacity(0.1)).frame(width: 1, height: 34)
                    ReOpt(label: reTr("re.mvS"), id: "re.o.mvS") { st.moveSel("s", app, h) }
                    ReOpt(label: reTr("re.mvC"), id: "re.o.mvC") { st.moveSel("c", app, h) }
                    ReOpt(label: reTr("re.mvE"), id: "re.o.mvE") { st.moveSel("e", app, h) }
                }
            }
        case "swing":
            if let it {
                let sws = it.kind == "door" ? ["inL", "inR", "outL", "outR"] : ["L", "R", "T"]
                DzcOptRow(title: reTr("re.t.swing"), sub: reTr("re.swingSub"), onBack: back) {
                    ForEach(sws, id: \.self) { s in
                        ReOpt(label: reTr("re.sw." + s), icon: RE_IC["swing"], on: (it.sw.isEmpty ? sws[0] : it.sw) == s, id: "re.o.sw." + s) { st.setSize("sw", 0, s: s, app, h) }
                    }
                }
            }
        case "ph":
            if let it {
                DzcOptRow(title: reTr("re.t.ph"), sub: reTr("re.phSub", ["n": reKindName(it.kind), "v": reLenU(it.ph)]), onBack: back) {
                    ForEach(reKind(it.kind).hs.sorted(), id: \.self) { v in ReOpt(label: reLen(v), on: it.ph == v, id: "re.o.ph\(v)") { st.setSize("ph", v, app, h) } }
                    ReOpt(label: reTr("re.type2"), icon: RE_IC["kbd"], id: "re.o.phKp") {
                        st.openKp(reTr("re.kpPh", ["n": reKindName(it.kind)]), cur: it.ph, lo: 0, hi: g.H) { st.setSize("ph", $0, app, h) }
                    }
                }
            }
        case "iwLen", "iwTh", "iwH", "iwOp", "iwShape", "iwFace":
            if let p = st.curPiece(h) { iwOptions(k, p, st, h, g, back) }
        default: EmptyView()
        }
    }

    /// The inner wall's options (mockup edOpt iwTh, iwH, iwOp, iwShape, iwFace; iwLen as the wall's Uzunlik).
    @ViewBuilder private func iwOptions(_ k: String, _ p: InnerWall, _ st: ReState, _ h: ReHost, _ g: ReRoomGeo, _ back: @escaping () -> Void) -> some View {
        let nm = iwName(p.k)
        switch k {
        case "iwLen":
            let col = p.k == "col"
            DzcOptRow(title: reToolLabel("iwLen", col), sub: reTr("iw.o.lenSub", ["n": nm, "v": reLen(p.len)]), onBack: back) {
                ForEach([-100, -10], id: \.self) { s in ReOpt(label: "−" + reLen(-s), id: "iw.o.len\(s)") { st.iwSetLen(p.len + s, app, h) } }
                ReOpt(label: reLenU(p.len), on: true, id: "iw.o.lenNow") {}
                ForEach([10, 100], id: \.self) { s in ReOpt(label: "+" + reLen(s), id: "iw.o.len+\(s)") { st.iwSetLen(p.len + s, app, h) } }
                ReOpt(label: reTr("re.type2"), icon: RE_IC["kbd"], id: "iw.o.lenKp") {
                    st.openKp(tr(col ? "iw.kp.size" : "iw.kp.len"), cur: p.len, lo: col ? 100 : 300, hi: SHAPE_WALL_MAX, big: !col) { st.iwSetLen($0, app, h) }
                }
                ReOpt(label: reTr("re.t.laser"), icon: RE_IC["laser"], id: "iw.o.laser") {
                    rshRead(app, st, p.len, nm) { mm in st.iwSetLen(mm, app, h) }
                }
            }
        case "iwTh":
            DzcOptRow(title: reTr("iw.t.iwTh"), sub: reTr("iw.o.thSub", ["n": nm, "v": reLen(p.th)]), onBack: back) {
                ForEach(IW_TH, id: \.self) { v in ReOpt(label: reLenU(v), on: p.th == v, id: "iw.o.th\(v)") { st.iwSetTh(v, app, h) } }
                ReOpt(label: reTr("re.type2"), icon: RE_IC["kbd"], id: "iw.o.thKp") { st.openKp(reTr("iw.t.iwTh"), cur: p.th, lo: 50, hi: 1000) { st.iwSetTh($0, app, h) } }
            }
        case "iwH":
            let hv = p.h > 0 ? p.h : 1100
            DzcOptRow(title: reTr("iw.t.iwH"), sub: reTr("iw.o.hSub", ["v": reLen(hv)]), onBack: back) {
                ForEach(IW_HH, id: \.self) { v in ReOpt(label: reLen(v), on: hv == v, id: "iw.o.h\(v)") { st.iwSetH(v, app, h) } }
                ReOpt(label: reTr("re.type2"), icon: RE_IC["kbd"], id: "iw.o.hKp") { st.openKp(reTr("iw.t.iwH"), cur: hv, lo: 300, hi: g.H - 1) { st.iwSetH($0, app, h) } }
            }
        case "iwOp":
            if let op = p.op {
                DzcOptRow(title: reTr("iw.o.opT"), sub: reTr("iw.o.opSub", ["w": reLen(op.w), "h": reLen(op.h)]), onBack: back) {
                    ForEach(IW_OPW, id: \.self) { v in ReOpt(label: reLen(v), on: op.w == v, id: "iw.o.op\(v)") { st.iwSetOp(w: v, app, h) } }
                    ReOpt(label: reTr("iw.o.opW"), icon: RE_IC["kbd"], id: "iw.o.opW") { st.openKp(reTr("iw.o.opW"), cur: op.w, lo: 400, hi: p.len - 200) { st.iwSetOp(w: $0, app, h) } }
                    ReOpt(label: reTr("iw.o.opH", ["v": reLen(op.h)]), icon: RE_IC["h"], id: "iw.o.opH") {
                        st.openKp(reTr("iw.o.opH", ["v": reLen(op.h)]), cur: op.h, lo: 1000, hi: g.H - 50) { st.iwSetOp(hh: $0, app, h) }
                    }
                }
            }
        case "iwShape":
            DzcOptRow(title: reTr("iw.o.shapeT"), sub: iwSizeLine(p, g.H), onBack: back) {
                ReOpt(label: reTr("iw.o.square"), on: !p.round, id: "iw.o.sq") { st.iwRound(false, app, h) }
                ReOpt(label: reTr("iw.o.round"), on: p.round, id: "iw.o.rd") { st.iwRound(true, app, h) }
                Rectangle().fill(G.ink.opacity(0.1)).frame(width: 1, height: 34)
                ForEach(IW_COL, id: \.self) { v in ReOpt(label: reLen(v), on: p.len == v, id: "iw.o.col\(v)") { st.iwSetLen(v, app, h) } }
            }
        default:
            DzcOptRow(title: reTr("iw.t.iwFace"), sub: reTr("iw.o.faceSub"), onBack: back) {
                ForEach(g.walls.filter { $0.inner && iwPieceOf($0.id) == p.id }, id: \.id) { w in
                    ReOpt(label: reTr("iw.o.face", ["w": w.label]), icon: RE_IC["iwFace"], id: "iw.o.face." + w.label) { st.strip = nil; st.selectWall(w.id, h) }
                }
            }
        }
    }

    /// "Diagonal bilan tekshirish": a typed diagonal from the wall's start to the next wall's end says whether the corner is square.
    private func diagCheck(_ st: ReState, _ g: ReRoomGeo, _ w: String) {
        guard let a = g.wall(w), let b = g.wall(g.next(w)) else { return }
        let dd = Int(hypot(b.b.x - a.a.x, b.b.y - a.a.y).rounded())
        let la = Double(a.len), lb = Double(b.len)
        st.openKp(reTr("re.diagT", ["a": w, "b": b.id]), cur: dd, lo: 300, hi: SHAPE_WALL_MAX) { v in
            if abs(v - dd) <= max(20, Int(Double(dd) * 0.005)) {
                Haptic.confirm()
                app.toast = ToastMsg(text: reTr("re.diagOk", ["a": reCornerAngle(g, b.id), "v": reLen(v)]), kind: .ok)
            } else {
                let cs = max(-1, min(1, (la * la + lb * lb - Double(v) * Double(v)) / (2 * la * lb)))
                let ang = String(format: "%.1f", acos(cs) * 180 / Double.pi)
                st.warn(app, reTr("re.diagBad", ["a": AppSettings.shared.lang == .en ? ang : ang.replacingOccurrences(of: ".", with: ",")]))
            }
        }
    }

    /* ---------------- the bottom: undo, redo, 2D / 3D, the trade's main button ---------------- */

    private func bottom(_ st: ReState, _ h: ReHost, _ p: Project) -> some View {
        HStack(spacing: 8) {
            hist("undo", on: !st.past.isEmpty, id: "re.undo") { st.undo(app, h) }
            hist("redo", on: !st.future.isEmpty, id: "re.redo") { st.redo(app, h) }
            HStack(spacing: 0) {
                seg2("2D", st.view != "3d", "re.v2d") { st.view = st.last2d }
                seg2("3D", st.view == "3d", "re.v3d") { st.view = "3d" }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.glass(0.6)))
            GBtn(tr(reMainKey(p.industry)), height: 54, fontSize: 15, lines: 2) { reMain(app, pid, rid, p.industry) }
                .accessibilityIdentifier("re.main")
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background { ZStack { Rectangle().fill(.ultraThinMaterial); Rectangle().fill(barTint) }.ignoresSafeArea(edges: .bottom) }
        .bottomBar()
    }

    private func hist(_ icon: String, on: Bool, id: String, _ a: @escaping () -> Void) -> some View {
        MIcon(icon, on ? G.ink : G.ink3.opacity(0.5), 20, 2.2)
            .frame(width: 46, height: 54)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.ink.opacity(0.06)))
            .pressable(0.95, label: tr(icon == "undo" ? "ux.undo" : "re.redo")) { if on { a() } }
            .accessibilityIdentifier(id)
    }

    private func seg2(_ t: String, _ on: Bool, _ id: String, _ a: @escaping () -> Void) -> some View {
        T(t, ui(14, 800, on ? G.ink : G.ink2), align: .center).frame(width: 42, height: 48)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(on ? G.solid : .clear))
            .pressable(0.96) { Haptic.tick(); a() }
            .accessibilityIdentifier(id)
    }
}

/// "8,8 m²".
func reAreaShort(_ g: ReRoomGeo) -> String {
    let s = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), g.area / 1e6)
    return (AppSettings.shared.lang == .en ? s : s.replacingOccurrences(of: ".", with: ",")) + U_M2
}
