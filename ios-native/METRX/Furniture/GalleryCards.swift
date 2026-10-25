import SwiftUI
import UIKit
import Observation

/*
 * The gallery's card pictures ("modern furniture 3D" part 4, 25 Oct 2026; the approved mockup's makeCards): snapshots
 * of the real 3D (Three/CardShots.swift), made once and kept (Furniture/CardCache.swift), one at a time, the cards in
 * sight first. A card the 3D cannot make in time is drawn the old way (Furniture/PieceView.swift), so a card always
 * shows; until then a soft shimmer.
 */

/// What the cards are made for: the workshop, the boards, the order's design style and the quality tier.
struct CardCtx: Equatable {
    let ws: Workshop
    let mats: [Mat]
    let style: String
    let tier: Quality3
}

/// Takes piece f's card for ctx at spec: done gets the picture or nil (and may never be called).
typealias CardRender = (_ f: Furniture, _ ctx: CardCtx, _ spec: CardSpec, _ done: @escaping (UIImage?) -> Void) -> Void

/// The gallery's pictures by model id, for the context last asked for (use). Call it on the main thread.
@Observable final class CardPics {
    static let shared = CardPics(render: { f, c, spec, done in CardRenderer.shared.render(f, c.ws, c.mats, spec, c.tier, done) }, store: CardStore.shared)

    private(set) var pics: [String: UIImage] = [:]
    /// Two 3D pictures in a row did not come: the rest of this session's cards are drawn.
    @ObservationIgnored private(set) var broken = false
    private let render: CardRender
    private let store: CardStore
    private let timeout: Double
    private let ids: [String]
    @ObservationIgnored private var ctx: CardCtx? = nil
    @ObservationIgnored private var matsSig = ""
    @ObservationIgnored private var wsSig = ""
    @ObservationIgnored private var pieces: [String: Furniture] = [:]
    @ObservationIgnored private var queue: [String] = []
    @ObservationIgnored private var preferred: [String] = []
    @ObservationIgnored private var job: Task<Void, Never>? = nil
    @ObservationIgnored private var jobNo = 0
    @ObservationIgnored private var fails = 0

    /// render takes the 3D pictures, store keeps them; a picture not there after timeout seconds is drawn instead;
    /// ids the models (the gallery's, by default).
    init(render: @escaping CardRender, store: CardStore, timeout: Double = 4, ids: [String]? = nil) {
        self.render = render; self.store = store; self.timeout = timeout
        self.ids = ids ?? GALLERY.flatMap { $0.1 }
    }

    /// The cards for this workshop, these boards and this design style ("" none): the ones kept show at once, the rest
    /// are made. Another context starts over (its pictures are kept, so going back is quick).
    @MainActor func use(_ ws: Workshop, _ mats: [Mat], _ style: String, tier: Quality3? = nil) {
        let c = CardCtx(ws: ws, mats: mats, style: style, tier: tier ?? Quality3.current())
        if c == ctx { run(); return }
        job?.cancel(); job = nil
        ctx = c; pieces = [:]
        matsSig = cardSig(mats); wsSig = cardSig(ws)
        var now: [String: UIImage] = [:]
        for id in ids { if let k = key(id), let img = store.memory(k) { now[id] = img } }
        pics = now
        queue = ids.filter { now[$0] == nil }
        run()
    }

    /// The models whose cards are made first, in this order (the ones in sight on the gallery).
    @MainActor func prefer(_ ids: [String]) { preferred = ids }

    /// The key of model id's card in the current context.
    @MainActor func key(_ id: String) -> CardKey? {
        guard let c = ctx, let f = piece(id, c) else { return nil }
        return cardKey(id, cardSpec(c.tier), style: c.style, matsSig: matsSig, handle: f.handle, tier: c.tier, wsSig: wsSig)
    }

    @MainActor private func piece(_ id: String, _ c: CardCtx) -> Furniture? {
        if let f = pieces[id] { return f }
        let f = cardPiece(id, c.ws, c.style)
        pieces[id] = f
        return f
    }

    /// The next card: the first one preferred that is still waiting, else the first one waiting.
    @MainActor private func nextId() -> String? { preferred.first { queue.contains($0) } ?? queue.first }

    @MainActor private func run() {
        if job != nil || queue.isEmpty { return }
        jobNo += 1
        let no = jobNo
        job = Task { @MainActor [weak self] in
            while true {
                guard let me = self, !Task.isCancelled, let id = me.nextId() else { break }
                await me.make(id)
            }
            if let me = self, me.jobNo == no { me.job = nil }
        }
    }

    /// One card: from memory, from disk, from the 3D, else drawn.
    @MainActor private func make(_ id: String) async {
        queue.removeAll { $0 == id }
        guard let c = ctx, let f = piece(id, c), let k = key(id) else { return }
        let spec = cardSpec(c.tier)
        if let img = store.memory(k) { pics[id] = img; return }
        let store = self.store
        let hit = await Task.detached(priority: .userInitiated) { store.disk(k) }.value
        guard ctx == c, !Task.isCancelled else { return }
        if let hit { pics[id] = hit; return }
        if c.tier != .flat && !broken {
            let shot = await shoot(f, c, spec)
            guard ctx == c, !Task.isCancelled else { return }
            if let shot {
                fails = 0
                let card = cardFit(shot, spec)
                store.remember(k, card)
                pics[id] = card
                Task.detached(priority: .utility) { store.save(k, card) }
                return
            }
            fails += 1
            if fails >= 2 { broken = true }
        }
        let ws = c.ws, mats = c.mats
        let drawn = await Task.detached(priority: .userInitiated) { cardPainted(f, ws, mats, spec) }.value
        guard ctx == c else { return }
        // only in memory: the next launch tries the 3D again
        store.remember(k, drawn)
        pics[id] = drawn
    }

    /// The 3D picture, or nil when none came within timeout.
    @MainActor private func shoot(_ f: Furniture, _ c: CardCtx, _ spec: CardSpec) async -> UIImage? {
        let render = self.render, wait = timeout
        return await withCheckedContinuation { (k: CheckedContinuation<UIImage?, Never>) in
            let once = CardOnce()
            let finish: (UIImage?) -> Void = { img in
                DispatchQueue.main.async {
                    if once.over { return }
                    once.over = true
                    k.resume(returning: img)
                }
            }
            render(f, c, spec, finish)
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { finish(nil) }
        }
    }
}

/// Whether a card's wait is over (its picture came, or the time ran out): the first of the two wins.
private final class CardOnce { var over = false }

/// Screen tests run with -uiReset: the placeholder stays still there (an endless animation keeps the app from idling).
private let CARD_STILL = ProcessInfo.processInfo.arguments.contains("-uiReset")

/// The card's placeholder until its picture is ready: the card's background with a soft light sweeping across.
struct CardShimmer: View {
    @Environment(\.accessibilityReduceMotion) private var still
    @State private var on = false
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            LinearGradient(colors: [Color.white.opacity(0), Color.white.opacity(0.6), Color.white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                .frame(width: w * 0.55, height: geo.size.height)
                .offset(x: on ? w : -w * 0.55)
        }
        .background(Color(uiColor: uiColor(CARD_BG)))
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            if still || CARD_STILL { return }
            withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) { on = true }
        }
    }
}
