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
    /// Projects whose file could not be read (an older or newer shape): their ids and the 3D pictures and photos their
    /// files name, which the cold-start sweep keeps (the file is still there and may load in a later version).
    @ObservationIgnored private(set) var unreadableIds: Set<String> = []
    @ObservationIgnored private(set) var unreadableFiles: Set<String> = []
    /// A save failed and was said (once, until a save works again); only touched on the writer's queue.
    @ObservationIgnored private var failed = false

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("projects", isDirectory: true)
        if ProcessInfo.processInfo.arguments.contains("-uiReset") { try? FileManager.default.removeItem(at: dir) }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dec = JSONDecoder()
        var loaded: [Project] = []
        var badIds = Set<String>(), badFiles = Set<String>()
        for f in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] where f.pathExtension == "json" {
            let data = try? Data(contentsOf: f)
            if let data, let p = try? dec.decode(Project.self, from: data) {
                // trade data left on rooms deleted before deleting took it along goes now (shown nowhere, still counted)
                loaded.append(withoutOrphans(p))
            } else {
                NSLog("METRX: a saved project could not be read and was skipped: %@", f.lastPathComponent)
                badIds.insert(f.deletingPathExtension().lastPathComponent)
                if let data, let text = String(data: data, encoding: .utf8) { badFiles.formUnion(Store.filesNamed(text)) }
            }
        }
        unreadableIds = badIds; unreadableFiles = badFiles
        // drawn rooms saved before each kept its own 90°/45° snap get the setting they were shown with, written back once
        let snap = UserDefaults.standard.object(forKey: "angleSnap") as? Bool ?? true
        let fixed = loaded.map { Store.withSnap($0, snap) }
        projects = fixed.sorted { $0.edited > $1.edited }
        for (i, p) in fixed.enumerated() where p != loaded[i] { save(p) }
    }

    /// p with each drawn room that has no snap of its own given snap; the same project when there is none.
    static func withSnap(_ p: Project, _ snap: Bool) -> Project {
        if !p.rooms.contains(where: { $0.poly != nil && $0.poly?.snap == nil }) { return p }
        var q = p
        for i in q.rooms.indices where q.rooms[i].poly != nil && q.rooms[i].poly?.snap == nil { q.rooms[i].poly?.snap = snap }
        return q
    }

    /// The 3D pictures and photos ("views/…", "photos/…") a saved project's text names (its slashes may be escaped).
    static func filesNamed(_ text: String) -> Set<String> {
        guard let re = try? NSRegularExpression(pattern: #"(?:views|photos)\\?/[^"\\]+"#) else { return [] }
        let ns = text as NSString
        var out = Set<String>()
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            out.insert(ns.substring(with: m.range).replacingOccurrences(of: "\\", with: ""))
        }
        return out
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

    /// Writes one project (on the writer's queue). A failure is logged and said once, until a write works again; the
    /// project stays as it is in memory and is written again with its next change or when the app goes to the background.
    private func write(_ p: Project) {
        do {
            try enc.encode(p).write(to: file(p.id), options: .atomic)
            failed = false
        } catch {
            NSLog("METRX: saving a project failed: %@", error.localizedDescription)
            if !failed {
                failed = true
                DispatchQueue.main.async { AppModel.shared.say("st.saveFail", kind: .error) }
            }
        }
    }

    /// Writes every change still waiting, right now (the app is going to the background).
    func flush() {
        let waiting = pending; pending.removeAll()
        for (id, w) in waiting { w.cancel(); if let p = get(id) { io.sync { write(p) } } }
    }
}
