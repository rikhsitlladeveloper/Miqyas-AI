import Foundation

/*
 * The "Namuna — oshxona" sample order of the UX upgrades is gone (the founder, 27 Oct 2026): it is never made, and one
 * an older version made is deleted on the first start after the update. Project.sample stays readable only so that
 * order can be found.
 */
enum SampleOrder {
    /// Deletes any sample order an older version made.
    static func purge() {
        let old = Store.shared.projects.filter { $0.sample }.map(\.id)
        for id in old { _ = Store.shared.delete(id) }
        if !old.isEmpty { AppModel.shared.dropMissing() }
    }
}
