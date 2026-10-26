import SwiftUI

/*
 * The bars of the UX upgrades (26 Oct 2026, sections 1, 3 and 12): a top bar with Back and the order's name on up to two
 * lines, a bottom action bar within thumb reach (one big next-step button, a small Undo, the designers' 2D/3D), both
 * almost solid (94 % of the glass colour) with the blur only showing at their edges. Toasts sit just above the bottom bar.
 */

/// The almost solid glass of the UX bars.
var barTint: Color { G.sheet(0.94) }

extension View {
    /// This view is a bottom bar: toasts rise above it while it shows (AppModel.bars); extra: what is under it besides.
    func bottomBar(extra: CGFloat = 0) -> some View { modifier(BottomBarHeight(extra: extra)) }
}

private struct BottomBarHeight: ViewModifier {
    let extra: CGFloat
    @State private var id = UUID()
    func body(content: Content) -> some View {
        content
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { AppModel.shared.bars[id] = g.size.height + extra }
                    .onChange(of: g.size.height) { _, h in AppModel.shared.bars[id] = h + extra }
            })
            .onDisappear { AppModel.shared.bars[id] = nil }
    }
}

/// Back, a small line above, the title on up to two lines (never cut), and what goes on the right.
struct UXTopBar<Right: View>: View {
    let title: String
    var sub: String? = nil
    var badge = false
    let back: () -> Void
    @ViewBuilder var right: Right
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            GlassIconButton("back", tr("nt.back"), back).accessibilityIdentifier("back")
            VStack(alignment: .leading, spacing: 1) {
                if sub != nil || badge {
                    HStack(spacing: 6) {
                        if badge { SampleBadge() }
                        if let sub { T(sub, ui(12, 600, G.ink3), lines: 1) }
                    }
                }
                T(title, ui(18, 800, G.ink, lh: 1.18), lines: 2).fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            right
        }
        .padding(.leading, 12).padding(.trailing, 12).padding(.vertical, 8)
        .frame(minHeight: 64)
    }
}

extension UXTopBar where Right == EmptyView {
    init(title: String, sub: String? = nil, badge: Bool = false, back: @escaping () -> Void) {
        self.init(title: title, sub: sub, badge: badge, back: back, right: { EmptyView() })
    }
}

/// The top area of a UX page: almost solid, a hairline under it, running up under the status bar.
struct UXTop<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .background { ZStack { Rectangle().fill(.ultraThinMaterial); Rectangle().fill(barTint) }.ignoresSafeArea(edges: .top) }
            .overlay(alignment: .bottom) { Rectangle().fill(G.rim).frame(height: 1) }
    }
}

/// The small Undo of the bottom bar (48 pt).
struct UndoButton: View {
    let enabled: Bool
    let action: () -> Void
    var body: some View {
        MIcon("undo", enabled ? G.ink : G.ink3.opacity(0.5), 20, 2.2)
            .frame(width: 52, height: 52)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.ink.opacity(0.06)))
            .pressable(0.95, label: tr("ux.undo")) { if enabled { action() } }
            .accessibilityAddTraits(enabled ? [] : .isStaticText)
            .accessibilityIdentifier("kt.undo")
    }
}

/// The bottom action bar: Undo, the designers' 2D/3D, one big next-step button; extra below it (a "Boshqa…" link).
struct ActionBar<Middle: View, Extra: View>: View {
    let label: String
    var icon: String? = nil
    var enabled = true
    var undoOn: Bool
    let undo: () -> Void
    let main: () -> Void
    var id = "ux.main"
    /// The coach mark on the main button ("order", "price"…; "" none).
    var coach = ""
    /// The coach mark on Undo ("designer"; "" none).
    var undoCoach = ""
    @ViewBuilder var middle: Middle
    @ViewBuilder var extra: Extra
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                UndoButton(enabled: undoOn, action: undo).coachMark(undoCoach)
                middle
                GBtn(label, icon: icon, enabled: enabled, height: 52, corner: 16, fontSize: 15.5, lines: 2) { Haptic.tick(); main() }
                    .accessibilityIdentifier(id)
                    .coachMark(coach)
            }
            extra
        }
        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background { ZStack { Rectangle().fill(.ultraThinMaterial); Rectangle().fill(barTint) }.ignoresSafeArea(edges: .bottom) }
        .overlay(alignment: .top) { Rectangle().fill(G.rim).frame(height: 1) }
        .bottomBar()
    }
}

extension ActionBar where Middle == EmptyView, Extra == EmptyView {
    init(label: String, icon: String? = nil, enabled: Bool = true, undoOn: Bool, undo: @escaping () -> Void, main: @escaping () -> Void, id: String = "ux.main", coach: String = "") {
        self.init(label: label, icon: icon, enabled: enabled, undoOn: undoOn, undo: undo, main: main, id: id, coach: coach, middle: { EmptyView() }, extra: { EmptyView() })
    }
}

extension ActionBar where Extra == EmptyView {
    init(label: String, icon: String? = nil, enabled: Bool = true, undoOn: Bool, undo: @escaping () -> Void, main: @escaping () -> Void, id: String = "ux.main",
         coach: String = "", @ViewBuilder middle: () -> Middle) {
        self.init(label: label, icon: icon, enabled: enabled, undoOn: undoOn, undo: undo, main: main, id: id, coach: coach, middle: middle, extra: { EmptyView() })
    }
}

/* ---------------- the designers ---------------- */

/// A designer's top: Back, the piece's name (two lines) and its line, Redo and the menu; under it the order's compact
/// progress and the price chip (approximate in the simple app).
struct DesignerHead: View {
    let app: AppModel
    let p: Project
    let f: Furniture
    let sub: String
    var body: some View {
        let kit = KitOps.shared
        UXTop {
            UXTopBar(title: dn(f.name), sub: sub, back: { app.pop() }) {
                GlassIconButton("redo", tr("common.redo"), tint: kit.canRedo(f.id) ? G.ink : G.ink3.opacity(0.5)) { kit.redo(p.id, f.id); Haptic.tick() }
                GlassIconButton("more", tr("common.menu")) { app.sheet = .fMenu(pid: p.id, fid: f.id) }.accessibilityIdentifier("kt.menu")
            }
            HStack(spacing: 8) {
                OrderProgress(app: app, p: p, compact: true)
                if let t = priceLine(p) {
                    T(t, AppSettings.shared.advanced ? num(12.5, 800) : ui(12, 700, G.ink3), lines: 1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 10).frame(minHeight: 30)
                        .background(Capsule().fill(G.ink.opacity(0.06)))
                        .frame(maxWidth: 130)
                        .accessibilityIdentifier("ux.priceChip")
                }
            }
            .padding(.horizontal, 10).padding(.bottom, 8)
        }
    }
}

/// A designer's bottom bar: Undo, the 2D/3D switch (middle), "Narxni ko‘rish".
struct DesignerBar<Middle: View>: View {
    let app: AppModel
    let p: Project
    let f: Furniture
    @ViewBuilder var middle: Middle
    var body: some View {
        let kit = KitOps.shared
        let pid = p.id
        // the piece's own changes first, then the order's last action (a piece added…)
        ActionBar(label: tr("ux.seePrice"), icon: nil, undoOn: kit.canUndo(f.id) || app.undoCount > 0,
                  undo: { if kit.canUndo(f.id) { kit.undo(pid, f.id); Haptic.tick() } else { app.undoLast() } },
                  main: { markFlow(pid, "design"); if let q = Store.shared.get(pid) { openPrice(app, q) } }, id: "ux.desMain",
                  coach: "", undoCoach: "designer", middle: { middle }, extra: { EmptyView() })
    }
}
