import Foundation

/*
 * The "Namuna — oshxona" sample order (UX upgrades 26 Oct 2026, section 11): an L kitchen in the "Tabiiy yog‘och" style in
 * a measured 3400 × 2600 kitchen, so a new furniture maker sees a finished order. It has a NAMUNA badge, goes in one tap
 * with Undo and is never counted in reports, totals or counts. Made once; Profile → "Maslahatlarni qayta ko‘rsatish"
 * makes it again.
 */
enum SampleOrder {
    /// Makes the sample order once for a furniture maker (not in the screen tests unless they ask with -uiTour).
    static func ensure() {
        let s = AppSettings.shared
        guard s.furniture, !s.sampleMade, !AppSettings.uxQuiet else { return }
        s.setSampleMade(true)
        if Store.shared.projects.contains(where: { $0.sample }) { return }
        Store.shared.add(make())
    }

    static func make() -> Project {
        let s = AppSettings.shared
        let now = nowMs()
        var p = newProject("@ux.sampleName", "@ux.sampleWho", "", "", nil, s.currency, s.reportLang.code)
        p.industry = "furniture"; p.sample = true; p.fstyle = "wood"; p.created = now - 1
        let w = Workspace(id: uid(), name: "@fr.kitchen", type: "kitchen", created: now)
        var r = Room(id: uid(), floorId: w.id, name: "@fr.kitchen", created: now)
        r.dims = ["A": Dim(v: 3400), "B": Dim(v: 2600), "H": Dim(v: 2700)]
        r.points = [SitePoint(id: uid(), t: "cold", wall: "A", off: 1500, h: 500), SitePoint(id: uid(), t: "gas", wall: "B", off: 400, h: 600)]
        p.floors = [w]; p.rooms = [r]
        let R = akRoomOf(r, s.angleSnap)
        let walls = akWallsFor(R, "L", ["A"]) ?? ["D", "A"]
        if let plan = akGenerate(R, walls: walls, layout: "L", app: AKApp(), preset: "wood") {
            p.furniture = akFurniture(plan, r, "wood", s.workshop, snap: s.angleSnap, now: now) { i in tr("kt.nameN", ["n": i + 1]) }
        }
        p.flow = ["design"]
        return p
    }

    /// Deletes the sample order at once; Undo puts it back.
    static func delete(_ app: AppModel, _ pid: String) {
        guard let gone = Store.shared.delete(pid) else { return }
        let (p, i) = gone
        app.dropMissing()
        app.act("ux.sampleDel") { Store.shared.restore(p, i) }
    }
}
