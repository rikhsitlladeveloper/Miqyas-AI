import Foundation
import Observation

/// The projects on this phone. Each project is one JSON file (the same shape as the prototype's state and the Android
/// app's), in the app's Application Support folder, so the model can grow without migrations.
///
/// Screens read `projects` and change a project through `update`; every change is written to its file shortly after
/// (coalesced per project, 250 ms) and at once when the app goes to the background (`flush`).
@Observable
final class Store {
    static let shared = Store()

    /// Newest edit first, like the prototype's list.
    private(set) var projects: [Project] = []

    @ObservationIgnored private let dir: URL
    @ObservationIgnored private var pending: [String: DispatchWorkItem] = [:]
    @ObservationIgnored private let io = DispatchQueue(label: "metrx.store")
    @ObservationIgnored private let enc: JSONEncoder = { let e = JSONEncoder(); e.outputFormatting = [.sortedKeys]; return e }()

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("projects", isDirectory: true)
        if ProcessInfo.processInfo.arguments.contains("-uiReset") { try? FileManager.default.removeItem(at: dir) }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dec = JSONDecoder()
        var loaded: [Project] = []
        for f in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] where f.pathExtension == "json" {
            if let data = try? Data(contentsOf: f), let p = try? dec.decode(Project.self, from: data) {
                // trade data left on rooms deleted before deleting took it along goes now (shown nowhere, still counted)
                loaded.append(withoutOrphans(p))
            } else { NSLog("METRX: a saved project could not be read and was skipped: %@", f.lastPathComponent) }
        }
        projects = loaded.sorted { $0.edited > $1.edited }
    }

    func get(_ id: String?) -> Project? { projects.first { $0.id == id } }

    func add(_ p: Project) { projects.insert(p, at: 0); save(p) }

    /// Change one project; touch moves it to the top of the list (edited now).
    @discardableResult func update(_ id: String, touch: Bool = true, _ change: (inout Project) -> Void) -> Project? {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return nil }
        var p = projects[i]
        change(&p)
        if touch { p.edited = nowMs() }
        if touch && i != 0 { projects.remove(at: i); projects.insert(p, at: 0) } else { projects[i] = p }
        save(p)
        return p
    }

    func delete(_ id: String) -> (Project, Int)? {
        guard let i = projects.firstIndex(where: { $0.id == id }) else { return nil }
        let p = projects.remove(at: i)
        pending.removeValue(forKey: id)?.cancel()
        let f = file(id)
        io.async { try? FileManager.default.removeItem(at: f) }
        return (p, i)
    }

    /// Puts a deleted project back where it was (Undo).
    func restore(_ p: Project, _ index: Int) { projects.insert(p, at: min(max(0, index), projects.count)); save(p, now: true) }

    private func file(_ id: String) -> URL { dir.appendingPathComponent(id + ".json") }

    private func save(_ p: Project, now: Bool = false) {
        pending.removeValue(forKey: p.id)?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.write(p) }
        pending[p.id] = w
        io.asyncAfter(deadline: .now() + (now ? 0 : 0.25), execute: w)
    }

    private func write(_ p: Project) {
        do { try enc.encode(p).write(to: file(p.id), options: .atomic) }
        catch { NSLog("METRX: saving a project failed: %@", error.localizedDescription) }
    }

    /// Writes every change still waiting, right now (the app is going to the background).
    func flush() {
        let waiting = pending; pending.removeAll()
        for (id, w) in waiting { w.cancel(); if let p = get(id) { io.sync { write(p) } } }
    }
}
