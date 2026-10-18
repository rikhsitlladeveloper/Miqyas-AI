import SwiftUI
import UIKit

/// A labelled glass field (prototype .fld / .box): white .6, a white rim, corner 16, 56 pt; focused it gets a 2 pt blue
/// border and a pale blue halo; with an error a red border and the message underneath. A phone field keeps 9 digits
/// and shows them as 90 123 45 67 after +998; a multi-line field grows to four lines and more.
struct GField<F: Hashable>: View {
    let label: String?
    @Binding var value: String
    var placeholder = ""
    var optional = false
    var phone = false
    var error: String? = nil
    var showError = false
    let focus: FocusState<F?>.Binding
    let me: F
    var submit: SubmitLabel = .next
    var onSubmit: () -> Void = {}
    var onBlur: () -> Void = {}
    var multiline = false
    var caps: TextInputAutocapitalization = .sentences
    var done = false
    var labelRight: String? = nil
    /// Digits only: the number keyboard.
    var number = false
    /// A number with a decimal mark: the decimal keyboard.
    var decimal = false
    /// The text field's accessibility id (screen tests).
    var id: String? = nil
    @State private var phoneFocused = false

    var body: some View {
        let focused = phone ? phoneFocused : focus.wrappedValue == me
        let bad = showError && error != nil
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 6) {
            if let label {
                HStack {
                    T(label, ui(15, 700)).frame(maxWidth: .infinity, alignment: .leading)
                    if optional { T(tr("common.optional").capitalizedFirst, ui(13, 500, G.ink3)) }
                    if let labelRight { T(labelRight, ui(13, 500, G.ink3)) }
                }
            }
            HStack(alignment: multiline ? .top : .center, spacing: 6) {
                if phone { T("+998", ui(16, 500, G.ink3)) }
                input
                    .padding(.vertical, multiline ? 12 : 10)
            }
            .padding(.horizontal, focused ? 17 : 18)
            .frame(minHeight: multiline ? 117 : 56, alignment: multiline ? .top : .center)
            .background(shape.fill(G.glass(0.6)))
            .overlay(shape.strokeBorder(bad ? G.err : focused ? G.cobalt : G.rim, lineWidth: focused || bad ? 2 : 1))
            .background(shape.inset(by: -2).stroke(focused ? (bad ? G.err : G.cobalt).opacity(0.12) : .clear, lineWidth: 4))
            .contentShape(shape)
            .onTapGesture { if !phone { focus.wrappedValue = me } }
            if bad, let error {
                HStack(alignment: .top, spacing: 6) { MIcon("alert", G.err, 18, 2); T(error, ui(13.5, 500, G.err)) }
            }
        }
        .onChange(of: focused) { was, now in if !phone && was && !now { onBlur() } }
    }

    @ViewBuilder private var input: some View {
        let st = ui(16, 400, done ? G.ink3 : G.ink, lh: multiline ? 1.45 : nil)
        if phone {
            PhoneTextField(value: $value, placeholder: placeholder, label: label ?? placeholder, focus: focus, me: me,
                           font: UIFont(name: fontName(.ui, 400), size: 16) ?? .systemFont(ofSize: 16), color: UIColor(G.ink), placeholderColor: UIColor(G.greyIcon), kern: 0,
                           onFocus: { on in phoneFocused = on; if !on { onBlur() } })
                .frame(height: 24)
        } else {
            TextField("", text: $value, prompt: Text(placeholder).foregroundColor(G.greyIcon), axis: multiline ? .vertical : .horizontal)
                .font(st.font).foregroundColor(st.color).lineSpacing(st.extraLeading)
                .strikethrough(done)
                .lineLimit(multiline ? 4...40 : 1...1)
                .textInputAutocapitalization(caps)
                .keyboardType(number ? .numberPad : decimal ? .decimalPad : .default)
                .focused(focus, equals: me)
                .submitLabel(submit)
                .onSubmit(onSubmit)
                .accessibilityLabel(label ?? placeholder)
                .accessibilityIdentifier(id ?? "")
        }
    }
}

extension String {
    /// "ixtiyoriy" → "Ixtiyoriy".
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// The search box of the Projects list (glass pill, 52 pt, a magnifier and a clear button).
struct SearchBox: View {
    @Binding var value: String
    let placeholder: String
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        HStack(spacing: 10) {
            MIcon("search", G.ink2, 20, 2.2)
            TextField("", text: $value, prompt: Text(placeholder).foregroundColor(Color(argb: 0xFF94A3B8)))
                .font(ui(16).font).foregroundColor(G.ink).submitLabel(.search).autocorrectionDisabled()
            if !value.isEmpty { MIcon("x", G.ink3, 18, 2).frame(width: 32, height: 32).pressable(0.95, label: tr("common.close")) { value = "" } }
        }
        .padding(.leading, 16).padding(.trailing, 12).frame(height: 52)
        .background(shape.fill(G.glass(0.45)))
        .topHighlight(shape)
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .background(shape.fill(Color.black.opacity(0.001)).boxShadow(G.shade.opacity(0.1), blur: 22, y: 8))
    }
}

/// A dashed glass button: the "add" row and tile of the glass design (prototype .gl-dash / .gl-tile).
struct DashedGlass: ViewModifier {
    let corner: CGFloat
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        content
            .background(shape.fill(G.glass(0.28)))
            .overlay(shape.strokeBorder(G.cobalt.opacity(0.45), style: StrokeStyle(lineWidth: 1.33, dash: [4, 3])))
    }
}
extension View { func dashedGlass(_ corner: CGFloat) -> some View { modifier(DashedGlass(corner: corner)) } }

/// A small count pill next to a section title.
struct CountPill: View {
    let n: Int
    var body: some View { Text("\(n)").st(num(12, 600, G.ink2)).padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(G.ink.opacity(0.06))) }
}

/// The back pill with the parent's name (prototype button.back in the glass header).
struct BackPill: View {
    let text: String
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        HStack(spacing: 4) { MIcon("back", G.ink, 22, 2.2); T(text, ui(15, 700), lines: 1) }
            .padding(.leading, 6).padding(.trailing, 16).frame(height: 44)
            .background(shape.fill(G.glass(0.45)))
            .topHighlight(shape, 1, width: 1)
            .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
            .background(shape.fill(Color.black.opacity(0.001)).boxShadow(G.shade.opacity(0.1), blur: 18, y: 6))
            .pressable(0.97, label: text, action)
            .accessibilityIdentifier("back")
    }
}

/// A plain back button: round glass icon, then the parent's name (prototype .page.space button.back).
struct BackLink: View {
    let text: String
    let action: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            GlassIconButton("back", tr("nt.back"), action)
            T(text, ui(15, 700, G.slate), lines: 1)
        }
        .padding(.horizontal, 6).frame(minHeight: 48)
        .contentShape(Rectangle()).onTapGesture(perform: action)
    }
}

/// Two-line page title: a small coloured step above the title.
struct BarTitle: View {
    let title: String
    var eyebrow: String? = nil
    var sub: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let eyebrow { T(eyebrow, ui(12.5, 600, G.cobalt), lines: 1) }
            T(title, ui(17, 700, lh: 1.2), lines: 1)
            if let sub { T(sub, ui(12.5, 400, G.ink2), lines: 1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 4)
    }
}

/// The floating frosted footer that holds a page's main button (prototype .footer in the glass look).
struct FloatingFooter<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        VStack(spacing: 8) { content }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 14)
            .glassBlur(shape, tint: G.sheet(0.55))
            .topHighlight(shape)
            .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
            .background(shape.fill(Color.black.opacity(0.001)).boxShadow(G.shade.opacity(0.1), blur: 30, y: -10))
            .padding(.horizontal, 12).padding(.bottom, 12)
    }
}
