import UIKit

/// The three haptics of the UX upgrades (26 Oct 2026, section 10), no sound: a tick for a step, an undo or a switch; a
/// confirm for a laser or voice value and a quote sent; a warning for an error. Off with Profile → "Tebranish (haptik)".
enum Haptic {
    static func tick() {
        guard AppSettings.shared.haptics else { return }
        let g = UIImpactFeedbackGenerator(style: .light)
        g.impactOccurred()
    }
    static func confirm() {
        guard AppSettings.shared.haptics else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warn() {
        guard AppSettings.shared.haptics else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
