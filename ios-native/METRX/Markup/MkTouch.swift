import SwiftUI
import UIKit

/*
 * The photo editor's touches (photo edge measuring, part 1; Android MarkupScreen's pointer input): one finger draws,
 * or picks up a line's end when it is held still on it; two fingers zoom and move the photo, dropping what one finger
 * had started. SwiftUI's own gestures on iOS 17 cannot give a two-finger pan, so this is a UIKit view.
 */

enum MkTouchEvent {
    case down(CGPoint), move(CGPoint), up(CGPoint), cancel
    /// A pinch step: zoom by, the fingers' centre now, how far the centre moved.
    case pinch(CGFloat, CGPoint, CGPoint)
}

struct MkTouch: UIViewRepresentable {
    let onEvent: (MkTouchEvent) -> Void

    func makeUIView(context: Context) -> TouchView { let v = TouchView(); v.onEvent = onEvent; return v }
    func updateUIView(_ v: TouchView, context: Context) { v.onEvent = onEvent }

    final class TouchView: UIView {
        var onEvent: ((MkTouchEvent) -> Void)?
        private var first: UITouch?
        private var pinching = false
        private var lastDist: CGFloat = 0, lastMid: CGPoint = .zero

        override init(frame: CGRect) { super.init(frame: frame); isMultipleTouchEnabled = true; backgroundColor = .clear }
        required init?(coder: NSCoder) { fatalError() }

        private func live(_ e: UIEvent?) -> [UITouch] {
            (e?.allTouches ?? []).filter { $0.view === self && $0.phase != .ended && $0.phase != .cancelled }
        }
        private func two(_ ts: [UITouch]) -> (CGFloat, CGPoint)? {
            guard ts.count >= 2 else { return nil }
            let a = ts[0].location(in: self), b = ts[1].location(in: self)
            return (max(1, hypot(a.x - b.x, a.y - b.y)), CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2))
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            let ts = live(event)
            if ts.count >= 2 {
                if !pinching { pinching = true; if first != nil { onEvent?(.cancel) } }
                if let r = two(ts) { lastDist = r.0; lastMid = r.1 }
                return
            }
            guard !pinching, first == nil, let t = touches.first else { return }
            first = t; onEvent?(.down(t.location(in: self)))
        }
        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            let ts = live(event)
            if pinching {
                if let r = two(ts) {
                    let (d, m) = r
                    onEvent?(.pinch(d / lastDist, m, CGPoint(x: m.x - lastMid.x, y: m.y - lastMid.y)))
                    lastDist = d; lastMid = m
                }
                return
            }
            if let f = first, touches.contains(f) { onEvent?(.move(f.location(in: self))) }
        }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { finish(touches, event, cancelled: false) }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { finish(touches, event, cancelled: true) }

        private func finish(_ touches: Set<UITouch>, _ event: UIEvent?, cancelled: Bool) {
            let left = live(event).filter { !touches.contains($0) }
            if pinching {
                if let r = two(left) { lastDist = r.0; lastMid = r.1 }
                if left.isEmpty { pinching = false; first = nil }
                return
            }
            if let f = first, touches.contains(f) {
                first = nil
                onEvent?(cancelled ? .cancel : .up(f.location(in: self)))
            }
        }
    }
}
