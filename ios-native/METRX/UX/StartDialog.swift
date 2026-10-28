import SwiftUI

/*
 * "Nimadan boshlaymiz?" (room-editor mockup v2, approved 28 Oct 2026, design/room-editor/mockup.html renderSheet
 * 'start'; Android sd.*): right after "Buyurtma yaratish" a sheet with two big cards for the order's trade, each saying
 * what comes next, and a small "Keyinroq". The first card measures the room (the trade's own "Xona qo‘shish" sheet,
 * then the shapes); the second goes on without a room (furniture: the 3D gallery with sizes; tiler: areas in m²;
 * electrician and plumber: a list; builder: the estimate; windows: products by size). Nothing is remembered between
 * orders; a tap outside is "Keyinroq". The order page keeps both paths (StartPaths) until it has a room.
 */

/// The trade part of the sd.* keys: furn, tile, elec, plumb, win or build.
func sdTrade(_ p: Project) -> String {
    switch p.industry {
    case "furniture": return "furn"
    case "tiler": return "tile"
    case "elec": return "elec"
    case "plumb": return "plumb"
    case "win": return "win"
    default: return "build"
    }
}

/// "Xonani o‘lchash": the trade's own room sheet (type and name), then the room shapes.
func sdStartRoom(_ app: AppModel, _ pid: String) {
    guard let p = Store.shared.get(pid) else { return }
    switch p.industry {
    case "furniture": app.sheet = .fNewRoom(pid: pid)
    case "tiler": app.sheet = .tNewRoom(pid: pid)
    case "elec": app.sheet = .eNewRoom(pid: pid)
    case "plumb": app.sheet = .pNewRoom(pid: pid)
    case "win": app.sheet = .wNewRoom(pid: pid)
    default:
        // a builder's room lives in a workspace: the first one, or a new "1-qavat"
        let wid: String
        if let w = p.floors.first { wid = w.id } else {
            let w = Workspace(id: uid(), name: "@floor1", type: "floor", created: nowMs())
            Store.shared.update(pid) { $0.floors.append(w) }
            wid = w.id
        }
        app.sheet = .newRoom(pid: pid, wid: wid)
    }
}

/// The other card: on without a room.
func sdStartOther(_ app: AppModel, _ pid: String) {
    guard let p = Store.shared.get(pid) else { return }
    app.sheet = nil
    switch p.industry {
    case "furniture": app.push(.fGallery(pid: pid, fromNew: true))
    case "tiler": app.push(.tGallery(pid: pid, fromNew: true))
    case "elec": app.push(.eGallery(pid: pid, fromNew: true))
    case "plumb": app.push(.pGallery(pid: pid, fromNew: true))
    case "win": app.push(.wGallery(pid: pid, fromNew: true))
    default: app.setProjectTab("estimate")
    }
}

/// One of the two cards: an icon, the title, what it does and what comes next in blue, a chevron.
private struct SdCard: View {
    let icon: String
    let title: String
    let desc: String
    let next: String
    let id: String
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        HStack(spacing: 12) {
            PathIcon(icon, G.cobalt, 28, 2)
                .frame(width: 54, height: 54)
                .background(RoundedRectangle(cornerRadius: 17, style: .continuous).fill(G.cobalt.opacity(0.11)))
            VStack(alignment: .leading, spacing: 4) {
                T(title, ui(16.5, 800, G.ink, lh: 1.2)).fixedSize(horizontal: false, vertical: true)
                T(desc, ui(13, 400, G.ink2, lh: 1.35)).fixedSize(horizontal: false, vertical: true)
                T(next, ui(12.5, 800, G.cobalt2, lh: 1.3)).padding(.top, 2).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MIcon("chev", G.ink3, 18, 2)
        }
        .padding(.leading, 14).padding(.trailing, 12).padding(.vertical, 16)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .background(shape.fill(G.glass(0.78)))
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .pressable(0.99, action)
        .accessibilityIdentifier(id)
    }
}

/// The cards' icons (the mockup's, 24 × 24).
let SD_ROOM_IC = "M4 4h16v16H4zM4 12h7v8"

/// The icon of a trade's second card.
private func sdIcon(_ t: String) -> String {
    switch t {
    case "furn": return "M5 11V7h14v4M3 11h4v3h10v-3h4v7H3zM6 18v2M18 18v2"
    case "tile": return "M3 3h8v8H3zM13 3h8v8h-8zM3 13h8v8H3zM13 13h8v8h-8z"
    case "build": return "M6 3h9l4 4v14H6zM15 3v4h4M9 12h6M9 16h6"
    case "win": return "M4 4h16v13H4zM12 4v13M4 10.5h16M3 20.5h18"
    default: return "M9 6h12M9 12h12M9 18h12M4 6h.01M4 12h.01M4 18h.01"
    }
}

struct StartSheet: View {
    let app: AppModel
    let sheet: Sheet
    static func handles(_ s: Sheet) -> Bool {
        if case .startOrder = s { return true }
        return false
    }
    var body: some View {
        if case .startOrder(let pid) = sheet, let p = Store.shared.get(pid) {
            let t = sdTrade(p)
            let who = dn(p.customer).isEmpty ? dn(p.name) : dn(p.customer)
            GlassSheet(tr("sd.title"), onClose: { later(pid) }) {
                T(tr("sd.sub", ["c": who, "t": tr("sd.n." + t)]), ui(13, 400, G.ink2), lines: 2)
                SdCard(icon: SD_ROOM_IC, title: tr("sd.a"), desc: tr("sd." + t + ".ad"), next: tr("sd." + t + ".an"), id: "sd.a") {
                    Haptic.tick(); sdStartRoom(app, pid)
                }
                SdCard(icon: sdIcon(t), title: tr("sd." + t + ".bt"), desc: tr("sd." + t + ".bd"), next: tr("sd." + t + ".bn"), id: "sd.b") {
                    Haptic.tick(); sdStartOther(app, pid)
                }
                VStack(spacing: 2) {
                    T(tr("sd.later"), ui(14, 700, G.ink2), align: .center).underline()
                        .padding(.horizontal, 16).frame(minHeight: 44)
                        .pressable(0.97) { later(pid) }
                        .accessibilityIdentifier("sd.later")
                    T(tr("sd.laterNote"), ui(12.5, 400, G.ink2, lh: 1.35), align: .center)
                }
                .frame(maxWidth: .infinity)
            } footer: { EmptyView() }
        }
    }
    private func later(_ pid: String) {
        app.sheet = nil
        app.say("sd.laterToast", kind: .info)
    }
}

/// The order page's two paths while it has no room (mockup scrOrder): "Hali xona yo‘q", the other path and
/// "Xonani o‘lchash".
struct StartPaths: View {
    let app: AppModel
    let p: Project
    var body: some View {
        let t = sdTrade(p)
        VStack(spacing: 10) {
            PathIcon(SD_ROOM_IC, G.cobalt, 26, 2)
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.cobalt.opacity(0.11)))
            T(tr("sd.noRoom"), ui(15.5, 800), align: .center)
            T(tr("sd.noRoomD", ["b": tr("sd." + t + ".bt")]), ui(13, 400, G.ink2, lh: 1.4), align: .center)
            HStack(spacing: 8) {
                GBtn(tr("sd." + t + ".bt"), kind: .secondary, height: 52, fontSize: 14, lines: 2) { sdStartOther(app, p.id) }
                    .accessibilityIdentifier("sd.pb")
                GBtn(tr("sd.a"), icon: "plus", height: 52, fontSize: 14, lines: 2) { sdStartRoom(app, p.id) }
                    .accessibilityIdentifier("sd.pa")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassCard(RoundedRectangle(cornerRadius: 22, style: .continuous), fill: G.glass(0.55))
    }
}
