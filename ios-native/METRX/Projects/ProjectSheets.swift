import SwiftUI

/// The project, workspace and item sheets (prototype SHEETS.*). Returns nothing for sheets that are not theirs.
struct ProjectSheet: View {
    let app: AppModel
    let sheet: Sheet
    var body: some View {
        switch sheet {
        case .projectMenu(let pid): ProjectMenu(app: app, pid: pid)
        case .projectDelete(let pid): ProjectDelete(app: app, pid: pid)
        case .newSpace(let pid, let edit): NewSpace(app: app, pid: pid, editWid: edit)
        case .spaceMenu(let pid, let wid): SpaceMenu(app: app, pid: pid, wid: wid)
        case .spaceDelete(let pid, let wid): SpaceDelete(app: app, pid: pid, wid: wid)
        case .addItem(let pid, let wid, let step): AddItem(app: app, pid: pid, wid: wid, step: step)
        case .itemMenu(let pid, let wid, let iid): ItemMenu(app: app, pid: pid, wid: wid, iid: iid)
        case .itemRename(let pid, let wid, let iid): ItemRename(app: app, pid: pid, wid: wid, iid: iid)
        case .itemMove(let pid, let wid, let iid): ItemMove(app: app, pid: pid, wid: wid, iid: iid)
        case .currency: CurrencySheet(app: app)
        default: EmptyView()
        }
    }
    static func handles(_ s: Sheet) -> Bool {
        switch s {
        case .projectMenu, .projectDelete, .newSpace, .spaceMenu, .spaceDelete, .addItem, .itemMenu, .itemRename, .itemMove, .currency: return true
        default: return false
        }
    }
}

private struct ProjectMenu: View {
    let app: AppModel
    let pid: String
    var body: some View {
        GlassSheet(tr("pr.menuEdit"), onClose: { app.sheet = nil }) {
            ListBox {
                ActionRow(icon: "edit", label: tr("pr.menuEdit")) { app.sheet = nil; app.push(.newProject(editId: pid)) }
                Hairline()
                ActionRow(icon: "trash", label: tr("pr.menuDelete"), danger: true) { app.sheet = .projectDelete(pid: pid) }
            }
        }
    }
}

private struct ProjectDelete: View {
    let app: AppModel
    let pid: String
    var body: some View {
        if let p = Store.shared.get(pid) {
            GlassSheet(tr("pj.delQ", ["n": dn(p.name)]), onClose: { app.sheet = nil }) {
                T(p.quotes.isEmpty ? tr("pj.delB0") : tr("pj.delB", ["q": p.quotes.count]), ui(15, 400, G.ink2, lh: 1.45))
            } footer: {
                HStack(spacing: 8) {
                    GBtn(tr("common.cancel"), kind: .secondary) { app.sheet = nil }
                    GBtn(tr("common.delete"), kind: .danger, icon: "trash") {
                        let name = dn(p.name)
                        guard let gone = Store.shared.delete(p.id) else { return }
                        app.sheet = nil; app.dropMissing()
                        app.say("pr.deleted", ["n": name], action: "common.undo") { Store.shared.restore(gone.0, gone.1) }
                    }
                    .accessibilityIdentifier("pj.delete")
                }
            }
        }
    }
}

/// New workspace, or edit its name and type (prototype SHEETS.newSpace).
private enum WF: Hashable { case name }

private struct NewSpace: View {
    let app: AppModel
    let pid: String
    let editWid: String?
    @State private var type = "floor"
    @State private var name = ""
    @State private var tried = false
    @State private var loaded = false
    @FocusState private var focus: WF?

    var body: some View {
        if let p = Store.shared.get(pid) {
            let edit = editWid.flatMap { id in p.floors.first { $0.id == id } }
            let err = name.trimmingCharacters(in: .whitespaces).isEmpty ? tr("ws.nameReq") : nil
            GlassSheet(tr(edit != nil ? "ws.menuEdit" : "ws.new"), onClose: { app.sheet = nil }) {
                GField(label: tr("ws.name"), value: $name, placeholder: wsSuggest(p, type), error: err, showError: tried, focus: $focus, me: .name,
                       submit: .done, onSubmit: { save(p, edit) })
                VStack(alignment: .leading, spacing: 6) {
                    T(tr("ws.type"), ui(15, 700))
                    FlowLayout(spacing: 8) {
                        ForEach(WS_TYPES, id: \.0) { k, icon in
                            let on = type == k
                            HStack(spacing: 6) { MIcon(icon, on ? G.cobalt2 : G.ink, 18, 2); T(tr("ws.t." + k), ui(15, on ? 600 : 500, on ? G.cobalt2 : G.ink)) }
                                .padding(.leading, 12).padding(.trailing, 14).frame(minHeight: 44)
                                .background(Capsule().fill(G.glass(0.55)))
                                .overlay(Capsule().strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 1.5 : 1))
                                .pressable(0.97) { pick(p, edit, k) }
                                .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
            } footer: {
                GBtn(tr(edit != nil ? "common.save" : "ws.create"), enabled: err == nil) { save(p, edit) }.accessibilityIdentifier("ws.save")
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                type = edit?.type ?? "floor"
                name = edit.map { floorName($0) } ?? wsSuggest(p, "floor")
            }
        }
    }

    /// A suggested name follows the type; a typed name stays.
    private func pick(_ p: Project, _ edit: Workspace?, _ k: String) {
        let cur = name.trimmingCharacters(in: .whitespaces)
        if cur.isEmpty || cur == wsSuggest(p, type) || (edit != nil && cur == floorName(edit!)) {
            name = edit != nil && k == edit!.type ? floorName(edit!) : wsSuggest(p, k)
        }
        type = k
    }

    private func save(_ p: Project, _ edit: Workspace?) {
        tried = true
        let nm = name.trimmingCharacters(in: .whitespaces)
        guard !nm.isEmpty else { return }
        if let edit {
            Store.shared.update(p.id) { pr in
                let stored = wsStoreName(pr, nm, type)
                if let i = pr.floors.firstIndex(where: { $0.id == edit.id }) { pr.floors[i].name = stored; pr.floors[i].type = type }
            }
            app.sheet = nil; app.say("op.saved", ["o": nm])
        } else {
            let w = Workspace(id: uid(), name: wsStoreName(p, nm, type), type: type, created: nowMs())
            Store.shared.update(p.id) { $0.floors.append(w) }
            app.sheet = nil; app.push(.space(pid: p.id, wid: w.id)); app.say("ws.created", ["n": nm])
        }
    }
}

private struct SpaceMenu: View {
    let app: AppModel
    let pid: String
    let wid: String
    var body: some View {
        if let w = Store.shared.get(pid)?.floors.first(where: { $0.id == wid }) {
            GlassSheet(floorName(w), onClose: { app.sheet = nil }) {
                ListBox {
                    ActionRow(icon: "edit", label: tr("ws.menuEdit")) { app.sheet = .newSpace(pid: pid, editWid: wid) }
                    Hairline()
                    ActionRow(icon: "trash", label: tr("ws.menuDel"), danger: true) { app.sheet = .spaceDelete(pid: pid, wid: wid) }
                }
            }
        }
    }
}

private struct SpaceDelete: View {
    let app: AppModel
    let pid: String
    let wid: String
    var body: some View {
        if let p = Store.shared.get(pid), let w = p.floors.first(where: { $0.id == wid }) {
            let counts = wsCounts(p, w)
            GlassSheet(tr("ws.delQ", ["n": floorName(w)]), onClose: { app.sheet = nil }) {
                T(counts.isEmpty ? tr("ws.delBEmpty") : tr("ws.delB", ["c": counts]), ui(15, 400, G.ink2, lh: 1.45))
            } footer: {
                HStack(spacing: 8) {
                    GBtn(tr("common.cancel"), kind: .secondary) { app.sheet = nil }
                    GBtn(tr("it.del"), kind: .danger, icon: "trash") {
                        let name = floorName(w)
                        let idx = p.floors.firstIndex(where: { $0.id == w.id }) ?? 0
                        let rooms = p.rooms.filter { $0.floorId == w.id }
                        Store.shared.update(p.id) { pr in pr.floors.removeAll { $0.id == w.id }; pr.rooms.removeAll { $0.floorId == w.id } }
                        app.sheet = nil; app.dropMissing()
                        app.say("ws.deleted", ["n": name], action: "common.undo") {
                            Store.shared.update(p.id) { pr in pr.floors.insert(w, at: min(idx, pr.floors.count)); pr.rooms.append(contentsOf: rooms) }
                        }
                    }
                }
            }
        }
    }
}

/// "+": drawing, photo or note; a drawing then asks room plan or free drawing (prototype SHEETS.addItem).
private struct AddItem: View {
    let app: AppModel
    let pid: String
    let wid: String
    let step: String
    var body: some View {
        if let p = Store.shared.get(pid), let w = p.floors.first(where: { $0.id == wid }) {
            if step == "sketch" || step == "photo" {
                GlassSheet(tr("add." + step), onClose: { app.sheet = nil }, back: { app.sheet = .addItem(pid: pid, wid: wid, step: "root") }) {
                    VStack(spacing: 10) {
                        if step == "sketch" {
                            BigRow(icon: "room", title: "add.plan", desc: "add.planD") { app.sheet = .newRoom(pid: pid, wid: wid) }.accessibilityIdentifier("add.plan")
                            BigRow(icon: "pen", title: "add.free", desc: "add.freeD") { app.sheet = nil; app.say("nt.part", ["n": 7], kind: .info) }
                        } else {
                            BigRow(icon: "camera", title: "add.camera", desc: "add.cameraD") { app.sheet = nil; app.say("nt.part", ["n": 7], kind: .info) }
                            BigRow(icon: "folder", title: "add.gallery", desc: "add.galleryD") { app.sheet = nil; app.say("nt.part", ["n": 7], kind: .info) }
                        }
                    }
                    .padding(.bottom, 6)
                }
            } else {
                GlassSheet(tr("add.title", ["n": floorName(w)]), onClose: { app.sheet = nil }) {
                    HStack(spacing: 10) {
                        ForEach([("sketch", "pen"), ("photo", "camera"), ("note", "note")], id: \.0) { k, icon in
                            VStack(spacing: 6) {
                                MIcon(icon, G.cobalt, 30, 2).frame(width: 56, height: 56)
                                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.solid))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
                                T(tr("add." + k), ui(15, 600), align: .center).padding(.top, 4)
                                T(tr("add." + k + "D"), ui(12, 400, G.ink2, lh: 1.3), align: .center)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 6).padding(.top, 16).padding(.bottom, 14)
                            .frame(maxWidth: .infinity, minHeight: 150)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.ink.opacity(0.06)))
                            .pressable(0.97) { if k == "note" { newNote(p.id, w.id) } else { app.sheet = .addItem(pid: pid, wid: wid, step: k) } }
                            .accessibilityIdentifier("add." + k)
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
        }
    }

    private func newNote(_ pid: String, _ wid: String) {
        let now = nowMs()
        let item = Item(id: uid(), kind: "note", rep: false, created: now, edited: now)
        Store.shared.update(pid) { pr in if let i = pr.floors.firstIndex(where: { $0.id == wid }) { pr.floors[i].items.append(item) } }
        app.sheet = nil
        app.push(.note(pid: pid, wid: wid, iid: item.id))
    }
}

struct BigRow: View {
    let icon: String
    let title: String
    let desc: String
    let action: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            MIcon(icon, G.cobalt, 22, 2).frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.solid))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
            VStack(alignment: .leading, spacing: 1) { T(tr(title), ui(15.5, 600)); T(tr(desc), ui(13, 400, G.ink2, lh: 1.35)) }
                .frame(maxWidth: .infinity, alignment: .leading)
            MIcon("chev", G.ink, 18, 2)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.ink.opacity(0.06)))
        .pressable(0.98, action)
    }
}

/* ---------------- one item: rename, move, duplicate, report, delete (prototype SHEETS.itemMenu) ---------------- */

private func findItem(_ pid: String, _ wid: String, _ iid: String) -> (Workspace, Item)? {
    guard let w = Store.shared.get(pid)?.floors.first(where: { $0.id == wid }), let it = w.items.first(where: { $0.id == iid }) else { return nil }
    return (w, it)
}

private func changeItem(_ pid: String, _ wid: String, _ iid: String, _ f: (inout Item) -> Void) {
    Store.shared.update(pid) { pr in
        guard let wi = pr.floors.firstIndex(where: { $0.id == wid }), let ii = pr.floors[wi].items.firstIndex(where: { $0.id == iid }) else { return }
        f(&pr.floors[wi].items[ii])
    }
}

private struct ItemMenu: View {
    let app: AppModel
    let pid: String
    let wid: String
    let iid: String
    var body: some View {
        if let f = findItem(pid, wid, iid) {
            let w = f.0, it = f.1
            GlassSheet(itemName(it), onClose: { app.sheet = nil }) {
                ListBox {
                    ActionRow(icon: "edit", label: tr("it.rename")) { app.sheet = .itemRename(pid: pid, wid: wid, iid: iid) }
                    Hairline()
                    ActionRow(icon: "layers", label: tr("it.move")) { app.sheet = .itemMove(pid: pid, wid: wid, iid: iid) }
                    Hairline()
                    ActionRow(icon: "copy", label: tr("it.dup")) {
                        let now = nowMs()
                        var copy = it
                        copy.id = uid(); copy.name = tr("it.copy", ["n": itemName(it)]); copy.created = now; copy.edited = now
                        copy.checks = it.checks.map { var c = $0; c.id = uid(); return c }
                        copy.els = it.els.map { var e = $0; e.id = uid(); return e }
                        Store.shared.update(pid) { pr in if let i = pr.floors.firstIndex(where: { $0.id == w.id }) { pr.floors[i].items.append(copy) } }
                        app.sheet = nil; app.say("op.added", ["o": itemName(copy)])
                    }
                    Hairline()
                    ActionRow(icon: "doc", label: tr("it.report"), action: { changeItem(pid, wid, iid) { $0.rep = !$0.inReport } }) { GSwitch(on: it.inReport) }
                    Hairline()
                    ActionRow(icon: "trash", label: tr("it.del"), danger: true) {
                        let name = itemName(it)
                        let idx = w.items.firstIndex(where: { $0.id == it.id }) ?? 0
                        Store.shared.update(pid) { pr in if let i = pr.floors.firstIndex(where: { $0.id == w.id }) { pr.floors[i].items.removeAll { $0.id == it.id } } }
                        app.sheet = nil; app.dropMissing()
                        app.say("it.deleted", ["n": name], action: "common.undo") {
                            Store.shared.update(pid) { pr in if let i = pr.floors.firstIndex(where: { $0.id == w.id }) { pr.floors[i].items.insert(it, at: min(idx, pr.floors[i].items.count)) } }
                        }
                    }
                }
            }
        }
    }
}

private enum RF: Hashable { case name }

private struct ItemRename: View {
    let app: AppModel
    let pid: String
    let wid: String
    let iid: String
    @State private var v = ""
    @State private var loaded = false
    @FocusState private var focus: RF?
    var body: some View {
        if let f = findItem(pid, wid, iid) {
            let it = f.1
            let err = v.trimmingCharacters(in: .whitespaces).isEmpty && it.kind != "note" ? tr("ws.nameReq") : nil
            GlassSheet(tr("it.rename"), onClose: { app.sheet = nil }) {
                GField(label: tr("ws.name"), value: $v, error: err, showError: true, focus: $focus, me: .name, submit: .done, onSubmit: { save(err) })
            } footer: {
                GBtn(tr("common.save"), enabled: err == nil) { save(err) }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true; v = dn(it.name)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focus = .name }
            }
        }
    }
    private func save(_ err: String?) {
        guard err == nil else { return }
        let t = v.trimmingCharacters(in: .whitespaces)
        changeItem(pid, wid, iid) { x in x.name = dn(x.name) == t ? x.name : t; x.edited = nowMs() }
        app.sheet = nil
    }
}

private struct ItemMove: View {
    let app: AppModel
    let pid: String
    let wid: String
    let iid: String
    var body: some View {
        if let p = Store.shared.get(pid), let f = findItem(pid, wid, iid) {
            let w = f.0, it = f.1
            let others = p.floors.filter { $0.id != w.id }
            GlassSheet(tr("it.moveT"), onClose: { app.sheet = nil }) {
                if others.isEmpty {
                    T(tr("it.moveNone"), ui(14, 400, G.ink2, lh: 1.4)).padding(.bottom, 8)
                } else {
                    ListBox {
                        ForEach(Array(others.enumerated()), id: \.element.id) { i, to in
                            if i > 0 { Hairline() }
                            ActionRow(icon: wsIcon(to.type), label: floorName(to), action: {
                                Store.shared.update(p.id) { pr in
                                    for k in pr.floors.indices {
                                        if pr.floors[k].id == w.id { pr.floors[k].items.removeAll { $0.id == it.id } }
                                        else if pr.floors[k].id == to.id { pr.floors[k].items.append(it) }
                                    }
                                }
                                app.sheet = nil; app.dropMissing()
                                app.say("it.moved", ["n": itemName(it), "w": floorName(to)])
                            }) { MIcon("chev", G.ink3, 18, 2) }
                        }
                    }
                }
            }
        }
    }
}

/// The currency new projects start with (prototype SHEETS.currency).
private struct CurrencySheet: View {
    let app: AppModel
    var body: some View {
        GlassSheet(tr("np.currency"), onClose: { app.sheet = nil }) {
            ForEach(["UZS", "USD", "EUR", "RUB"], id: \.self) { c in
                Opt(title: c + (c == "UZS" ? " (\(tr("cur.UZS")))" : ""), on: AppSettings.shared.currency == c) { AppSettings.shared.setCurrencyDefault(c); app.sheet = nil }
            }
            T(tr("se.curNote"), ui(13, 400, G.ink2, lh: 1.4))
        }
    }
}

/// Lays out chips in rows that wrap (SwiftUI Layout, iOS 16+).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > w { x = 0; y += row + spacing; row = 0 }
            x += sz.width + spacing; row = max(row, sz.height); maxX = max(maxX, x - spacing)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + row)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, row: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > b.minX && x + sz.width > b.maxX { x = b.minX; y += row + spacing; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing; row = max(row, sz.height)
        }
    }
}
