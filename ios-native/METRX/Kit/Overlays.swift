import SwiftUI

/// Measures a view's height (used to let a sheet hug its content until the screen is full).
private struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// A glass bottom sheet (prototype .sheet in the glass look): white .84 over a blur, a grab handle, a title row with
/// a close button, the body (scrolling when long) and an optional footer above a hairline. It slides up while the
/// scrim fades in; it stays below the status bar and above the keyboard.
struct GlassSheet<Content: View, Footer: View>: View {
    let title: String
    let onClose: () -> Void
    var back: (() -> Void)? = nil
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer
    @State private var shown = false
    @State private var bodyH: CGFloat = 0

    var body: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
        GeometryReader { full in
        // the body scrolls once the sheet would reach the top (handle and title 60, footer about 80, margin 24)
        let maxBody = max(120, full.size.height - 24 - 60 - (Footer.self == EmptyView.self ? 0 : 80))
        ZStack(alignment: .bottom) {
            G.scrim.opacity(shown ? 1 : 0).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 0) {
                Capsule().fill(G.rim).frame(width: 36, height: 4).padding(.top, 7)
                HStack(spacing: 0) {
                    if let back {
                        MIcon("back", G.ink, 22, 2).frame(width: 44, height: 44).pressable(0.95, label: tr("nt.back"), back)
                    }
                    T(title, ui(17, 600, lh: 1.25)).frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
                    MIcon("x", G.ink2, 22, 2).frame(width: 44, height: 44).pressable(0.95, label: tr("common.close"), onClose)
                        .accessibilityIdentifier("sheet.close")
                }
                .padding(.leading, back != nil ? 6 : 16).padding(.trailing, 6).padding(.vertical, 4).frame(minHeight: 48)
                GeometryReader { geo in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) { content }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16).padding(.bottom, 12)
                            .background(GeometryReader { Color.clear.preference(key: HeightKey.self, value: $0.size.height) })
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(height: geo.size.height)
                }
                .frame(height: min(bodyH, maxBody))
                .onPreferenceChange(HeightKey.self) { bodyH = $0 }
                if Footer.self != EmptyView.self {
                    Hairline()
                    VStack(spacing: 8) { footer }.padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
                }
            }
            .frame(maxWidth: .infinity)
            // the glass runs down to the screen's edge, under the home indicator
            .background { ZStack { shape.fill(.ultraThinMaterial); shape.fill(G.sheet(0.84)) }.ignoresSafeArea(edges: .bottom) }
            .overlay(shape.stroke(G.rim, lineWidth: 1).ignoresSafeArea(edges: .bottom))
            .background(shape.fill(Color.black.opacity(0.001)).boxShadow(G.shade.opacity(0.16), blur: 40, y: -12))
            .contentShape(shape)
            .onTapGesture {}
            .offset(y: shown ? 0 : 900)
            .padding(.top, 24)
        }
        }
        .onAppear { withAnimation(.timingCurve(0.3, 0.7, 0.2, 1, duration: 0.28)) { shown = true } }
    }
}

extension GlassSheet where Footer == EmptyView {
    init(_ title: String, onClose: @escaping () -> Void, back: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: title, onClose: onClose, back: back, content: content, footer: { EmptyView() })
    }
}

extension GlassSheet {
    init(_ title: String, onClose: @escaping () -> Void, back: (() -> Void)? = nil, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.init(title: title, onClose: onClose, back: back, content: content, footer: footer)
    }
}

enum ToastKind { case ok, info, error }

struct ToastMsg: Identifiable, Equatable {
    let id = UUID()
    let text: String
    var kind: ToastKind = .ok
    var action: String? = nil
    var onAction: (() -> Void)? = nil
    static func == (a: ToastMsg, b: ToastMsg) -> Bool { a.id == b.id }
}

/// The toast of the prototype's last UX pass: one dark card at the top, its colour and icon say what happened;
/// it closes by itself (longer with an action or an error) or with the cross.
struct ToastHost: View {
    let msg: ToastMsg?
    /// The bottom bar's height: the toast sits just above it (UX upgrades section 3), so it never covers Back.
    var lift: CGFloat = 0
    /// At the top instead (over a sheet, whose buttons are at the bottom).
    var top = false
    let onGone: () -> Void
    @State private var visible = false
    @State private var shown: ToastMsg? = nil
    /// The toast whose action already ran: a second tap during the exit animation must not run Undo again.
    @State private var acted: UUID? = nil

    var body: some View {
        VStack {
            if !top { Spacer() }
            if visible, let m = shown {
                let (tc, icon): (Color, String) = m.kind == .ok ? (Color(argb: 0xFF5BE49B), "check") : m.kind == .info ? (Color(argb: 0xFF9DB1FF), "info") : (Color(argb: 0xFFFF7A7A), "alert")
                HStack(spacing: 12) {
                    MIcon(icon, tc, 18, 2.4).frame(width: 32, height: 32).background(Circle().fill(tc.opacity(0.2)))
                    T(m.text, ui(14.5, 600, .white, lh: 1.35)).frame(maxWidth: .infinity, alignment: .leading)
                    if let a = m.action {
                        // 48 pt: easy to hit (UX upgrades section 3)
                        HStack(spacing: 6) { MIcon("undo", .white, 16, 2.2); T(a, ui(14, 700, .white), lines: 2).fixedSize(horizontal: false, vertical: true) }
                            .padding(.horizontal, 12).frame(minHeight: 48)
                            .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color.white.opacity(0.14)))
                            .pressable(0.97) { if acted != m.id { acted = m.id; m.onAction?() }; hide() }
                            .accessibilityIdentifier("toast.undo")
                    }
                    MIcon("x", Color.white.opacity(0.62), 18, 2).frame(width: 40, height: 40).pressable(0.95, label: tr("common.close")) { hide() }
                }
                .padding(.leading, 12).padding(.trailing, 8).padding(.top, 9).padding(.bottom, 11)
                .frame(minHeight: 58)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(argb: 0xFF0F1626)))
                .boxShadow(Color(argb: 0x52000000), blur: 32, y: 12)
                .padding(.horizontal, 10).padding(.top, top ? 8 : 0).padding(.bottom, top ? 0 : lift + 8)
                .transition(.move(edge: top ? .top : .bottom).combined(with: .opacity))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("toast")
            }
            if top { Spacer() }
        }
        .animation(.easeOut(duration: 0.2), value: lift)
        .onChange(of: msg?.id) { _, _ in
            // cleared by the app (e.g. the room-shape flow moving to its next screen): it slides away now
            guard let m = msg else { if visible { withAnimation(.easeIn(duration: 0.22)) { visible = false } }; return }
            shown = m
            withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) { visible = true }
            let id = m.id
            // a toast with Undo stays long enough to reach it (about 6 s)
            let wait: Double = m.action != nil ? 6.5 : (m.kind == .error ? 5.2 : 3.4)
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { if shown?.id == id { hide() } }
        }
    }

    private func hide() {
        withAnimation(.easeIn(duration: 0.22)) { visible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { onGone() }
    }
}
