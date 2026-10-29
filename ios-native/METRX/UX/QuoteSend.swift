import SwiftUI

/*
 * "Telegram’ga yuborish" (UX upgrades 26 Oct 2026, section 8): one tap issues the quote (freezes the price, the
 * pictures and the boards, as "Taklifni chiqarish" does, with no confirm sheet) and opens the share sheet with its PDF;
 * on iPhone there is no way to hand a file to Telegram itself, and the sheet puts the apps used most first. A toast
 * offers Undo, which takes the quote back to a draft. "Boshqa…" opens the same sheet.
 */
enum QuoteSend {
    /// Issues the order's quote (or reuses the last one when nothing changed since) and shares its PDF.
    static func send(_ app: AppModel, _ pid: String) { MainActor.assumeIsolated { sendNow(app, pid) } }

    @MainActor private static func sendNow(_ app: AppModel, _ pid: String) {
        guard let p = Store.shared.get(pid), p.isFurniture else { return }
        let sn = snapshotOf(p)
        guard !sn.furniture.isEmpty else { app.say("ux.needFurn", kind: .info); return }
        guard app.once() else { return }
        let before = p
        var no = p.quotes.count + 1
        var made = false
        if let last = p.quotes.last, sameAsQuote(sn, last.fp) {
            no = last.no
        } else {
            let q = freezeQuote(p, sn, no, nowMs())
            let early = p.stage == "measure" || p.stage == "estimate" || p.stage == "design"
            Store.shared.update(pid) { x in
                x.quotes.append(q)
                if early { x.stage = "quote" }
                if !x.flow.contains("price") { x.flow.append("price") }
            }
            made = true
        }
        guard let q = Store.shared.get(pid)?.quotes.first(where: { $0.no == no }) else { return }
        // the pieces' own 3D pictures first (usually made already while the price page was open)
        let n = no, wasMade = made, old = before
        Task { @MainActor in
            _ = await PdfShots.shared.prepare(q.sn)
            QuoteSend.share(app, pid, q, n, wasMade, old)
        }
    }

    @MainActor private static func share(_ app: AppModel, _ pid: String, _ q: Quote, _ no: Int, _ made: Bool, _ before: Project) {
        let pages = furniturePages(q.sn, draft: false, meta: QuoteMeta(no: q.no, ts: q.ts), image: viewLoader(), prices: true)
        let fname = pdfName(dn(q.sn.name), tr("q.no", ["n": no]))
        guard let url = pdfFile(pages, fname) else { app.say("cm.shareErr", kind: .error); return }
        presentShare(url)
        Haptic.confirm()
        if made {
            app.act("ux.sent", ["n": no]) {
                // back to a draft: the quote goes, the stage is what it was
                Store.shared.update(pid) { x in x.quotes.removeAll { $0.no == no }; x.stage = before.stage }
                if case .report(let id, let n) = app.top, id == pid, n == no { app.pop() }
            }
        } else {
            app.say("ux.resent", ["n": no])
        }
    }

    /// "Boshqa…": the same as the big button (the quote is issued, Undo returns it to a draft), as Android does; the
    /// share sheet then offers every app.
    static func other(_ app: AppModel, _ pid: String) { send(app, pid) }
}
