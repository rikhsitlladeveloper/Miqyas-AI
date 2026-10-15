import SwiftUI
import UIKit

/* Pieces of the sign-in screens (prototype modules/auth.css; the look of the founder's Figma file). */

enum BtnKind { case primary, outline }

struct AuButton<Leading: View, Trailing: View>: View {
    let label: String
    var kind: BtnKind = .primary
    var enabled = true
    var fontSize: CGFloat = 16
    let action: () -> Void
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        HStack(spacing: 8) {
            leading
            T(label, au(fontSize, 600, kind == .primary ? .white : Au.ink), align: .center)
            trailing
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(shape.fill(kind == .primary ? Au.cobalt : Color.white))
        .overlay(kind == .outline ? shape.strokeBorder(Au.line, lineWidth: 1.5) : nil)
        .background(shape.fill(Color.black.opacity(0.001)).boxShadow(kind == .primary && enabled ? Au.cobalt.opacity(0.22) : .clear, blur: 14, y: 6))
        .opacity(enabled ? 1 : 0.42)
        .pressable(0.98) { if enabled { action() } }
    }
}

extension AuButton where Leading == EmptyView, Trailing == EmptyView {
    init(_ label: String, kind: BtnKind = .primary, enabled: Bool = true, fontSize: CGFloat = 16, _ action: @escaping () -> Void) {
        self.init(label: label, kind: kind, enabled: enabled, fontSize: fontSize, action: action, leading: { EmptyView() }, trailing: { EmptyView() })
    }
}

/// The Google "G", drawn from the prototype's 18 × 18 SVG.
struct GoogleLogo: View {
    var size: CGFloat = 20
    var body: some View {
        Canvas { ctx, sz in
            var c = ctx; c.scaleBy(x: sz.width / 18, y: sz.width / 18)
            let parts: [(String, UInt32)] = [
                ("M9 3.48c1.69 0 2.83.73 3.48 1.34l2.54-2.48C13.46.89 11.43 0 9 0 5.48 0 2.44 2.02.96 4.96l2.91 2.26C4.6 5.05 6.62 3.48 9 3.48z", 0xFFEA4335),
                ("M17.64 9.2c0-.74-.06-1.28-.19-1.84H9v3.34h4.96c-.1.83-.64 2.08-1.84 2.92l2.84 2.2c1.7-1.57 2.68-3.88 2.68-6.62z", 0xFF4285F4),
                ("M3.88 10.78A5.54 5.54 0 0 1 3.58 9c0-.62.11-1.22.29-1.78L.96 4.96A9 9 0 0 0 0 9c0 1.45.35 2.82.96 4.04l2.92-2.26z", 0xFFFBBC05),
                ("M9 18c2.43 0 4.47-.8 5.96-2.18l-2.84-2.2c-.76.53-1.78.9-3.12.9-2.38 0-4.4-1.57-5.12-3.74L.97 13.04C2.45 15.98 5.48 18 9 18z", 0xFF34A853),
            ]
            for (d, col) in parts { c.fill(SVGPath.path(d), with: .color(Color(argb: col))) }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct UzFlag: View {
    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height, r = 2.5 * w / 22
            let clip = Path(roundedRect: CGRect(origin: .zero, size: sz), cornerRadius: r)
            var c = ctx; c.clip(to: clip)
            c.fill(Path(CGRect(origin: .zero, size: sz)), with: .color(.white))
            c.fill(Path(CGRect(x: 0, y: 0, width: w, height: h * 5 / 16)), with: .color(Color(argb: 0xFF1E9FC7)))
            c.fill(Path(CGRect(x: 0, y: h * 11 / 16, width: w, height: h * 5 / 16)), with: .color(Color(argb: 0xFF2DA84F)))
            c.fill(Path(CGRect(x: 0, y: h * 5 / 16, width: w, height: h * 0.8 / 16)), with: .color(Color(argb: 0xFFD8343C)))
            c.fill(Path(CGRect(x: 0, y: h * 10.2 / 16, width: w, height: h * 0.8 / 16)), with: .color(Color(argb: 0xFFD8343C)))
            ctx.stroke(clip, with: .color(Color(argb: 0x240B1226)), lineWidth: 1)
        }
        .frame(width: 22, height: 16)
        .accessibilityHidden(true)
    }
}

enum FieldKind { case text, phone, password }

/// A labelled field with the phone's own keyboard (prototype .auf / .aubox): a blue ring when focused, red when wrong.
/// A phone field keeps the 9 local digits and shows them as 90 123 45 67.
struct AuField<Focus: Hashable>: View {
    let label: String
    @Binding var value: String
    var kind: FieldKind = .text
    var placeholder = ""
    var error: String? = nil
    var showError = false
    let focus: FocusState<Focus?>.Binding
    let me: Focus
    var submit: SubmitLabel = .next
    var onSubmit: () -> Void = {}
    var onBlur: () -> Void = {}
    @State private var showPw = false
    @State private var phoneFocused = false

    var body: some View {
        let focused = kind == .phone ? phoneFocused : focus.wrappedValue == me
        let bad = showError && error != nil
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                T(label, au(13.5, 600, Au.ink2)).frame(maxWidth: .infinity, alignment: .leading)
                if kind == .password {
                    T(tr(showPw ? "pw.hide" : "pw.show"), au(13.5, 600, Au.cobalt)).padding(.horizontal, 10).padding(.vertical, 6)
                        .pressable(0.97) { showPw.toggle() }
                }
            }
            HStack(spacing: 10) {
                switch kind {
                case .phone:
                    HStack(spacing: 8) { UzFlag(); Text("+998").st(mono(15, 600)) }
                        .padding(.horizontal, 10).frame(height: 42)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(argb: 0xFFF1F4FB)))
                case .password: MIcon("lock", focused ? Au.cobalt : Au.ink3, 22, 1.8)
                case .text: MIcon("user", focused ? Au.cobalt : Au.ink3, 22, 1.8)
                }
                if kind == .phone { field.padding(.vertical, 8) } else { textField }
                if kind == .text && !value.isEmpty {
                    PathIcon("M12 3.5a8.5 8.5 0 1 1 0 17a8.5 8.5 0 1 1 0-17zM9 9l6 6M15 9l-6 6", Au.ink3, 22, 1.8)
                        .frame(width: 44, height: 44)
                        .pressable(0.95, label: tr("common.delete")) { value = ""; focus.wrappedValue = me }
                }
            }
            .padding(.leading, kind == .phone ? 6 : 14).padding(.trailing, 4)
            .frame(minHeight: 56)
            .background(shape.fill(Color.white))
            .overlay(shape.strokeBorder(bad ? G.err : focused ? Au.cobalt : Au.line, lineWidth: focused ? 2.5 : 1.5))
            .background(shape.inset(by: -2).stroke(focused ? (bad ? G.errWash : Au.wash) : .clear, lineWidth: 4))
            if bad, let error {
                HStack(alignment: .top, spacing: 6) { MIcon("alert", G.err, 18, 2); T(error, au(13.5, 500, G.err)) }
            }
        }
        .onChange(of: focused) { was, now in if kind != .phone && was && !now { onBlur() } }
    }

    private var textField: some View {
        field.focused(focus, equals: me).submitLabel(submit).onSubmit(onSubmit).accessibilityLabel(label).padding(.vertical, 8)
    }

    @ViewBuilder private var field: some View {
        switch kind {
        case .phone:
            PhoneTextField(value: $value, placeholder: placeholder, label: label, focus: focus, me: me) { on in
                phoneFocused = on
                if on { if focus.wrappedValue != nil { focus.wrappedValue = nil } } else { onBlur() }
            }
            .frame(height: 30)
        case .password:
            Group {
                if showPw { TextField("", text: $value, prompt: Text(placeholder).foregroundColor(Au.ink3)) }
                else { SecureField("", text: $value, prompt: Text(placeholder).foregroundColor(Au.ink3)) }
            }
            .font(au(16, 500).font).foregroundColor(Au.ink)
            .textContentType(.password).textInputAutocapitalization(.never).autocorrectionDisabled()
        case .text:
            TextField("", text: $value, prompt: Text(placeholder).foregroundColor(Au.ink3))
                .font(au(16, 500).font).foregroundColor(Au.ink)
                .textInputAutocapitalization(.words).autocorrectionDisabled()
        }
    }
}

/// "Davom etib, [Foydalanish shartlari] va ..." with the bracketed parts underlined.
struct Terms: View {
    var body: some View {
        var out = Text("")
        var rest = tr("au.terms")
        while let a = rest.firstIndex(of: "["), let b = rest[a...].firstIndex(of: "]") {
            out = out + Text(String(rest[..<a]))
            out = out + Text(String(rest[rest.index(after: a)..<b])).foregroundColor(Au.ink2).font(au(12, 500).font).underline()
            rest = String(rest[rest.index(after: b)...])
        }
        out = out + Text(rest)
        return out.font(au(12, 400).font).foregroundColor(Au.ink3).lineSpacing(au(12, lh: 1.45).extraLeading)
            .multilineTextAlignment(.center).frame(maxWidth: .infinity)
    }
}

/// "Hisobingiz bormi?  Kirish"
struct AuRow: View {
    let lead: String
    let link: String
    let onLink: () -> Void
    var body: some View {
        HStack(spacing: 6) {
            T(lead, au(14.5, 400, Au.ink2))
            T(link, au(14.5, 600, Au.cobalt)).padding(.horizontal, 4).padding(.vertical, 12).pressable(0.97, onLink)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AuHeading: View {
    let title: String
    let lead: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            T(title, au(26, 700, Au.ink, lh: 1.2, ls: -0.012)).accessibilityAddTraits(.isHeader)
            if let lead { T(lead, au(15, 400, Au.ink2, lh: 1.45)) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The phone number field: a UIKit text field, so each key press is turned into the 9 local digits and shown as
/// 90 123 45 67 at once (a SwiftUI field that is rewritten while typing loses fast key presses).
struct PhoneTextField<Focus: Hashable>: UIViewRepresentable {
    @Binding var value: String
    let placeholder: String
    let label: String
    let focus: FocusState<Focus?>.Binding
    let me: Focus
    /// The field got or lost the keyboard (SwiftUI's focus state doesn't see UIKit fields, so it is reported here).
    let onFocus: (Bool) -> Void

    func makeUIView(context: Context) -> UITextField {
        let f = UITextField()
        f.delegate = context.coordinator
        f.keyboardType = .phonePad
        f.textContentType = .telephoneNumber
        f.font = UIFont(name: "IBMPlexMono-SemiBold", size: 22)
        f.textColor = UIColor(Au.ink)
        f.defaultTextAttributes[.kern] = 22 * 0.01
        f.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.foregroundColor: UIColor(Au.ink3), .font: UIFont(name: "IBMPlexMono-SemiBold", size: 22) as Any])
        f.accessibilityLabel = label
        f.setContentHuggingPriority(.defaultLow, for: .horizontal)
        f.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        f.text = Phone.groups(value)
        return f
    }

    func updateUIView(_ f: UITextField, context: Context) {
        context.coordinator.parent = self
        let shown = Phone.groups(value)
        if f.text != shown { f.text = shown }
        // the previous field's "next" asks for this one: take the keyboard once per request
        let want = focus.wrappedValue == me
        if want && !context.coordinator.requested && !f.isFirstResponder {
            context.coordinator.requested = true
            DispatchQueue.main.async { f.becomeFirstResponder() }
        }
        if !want { context.coordinator.requested = false }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: PhoneTextField
        var requested = false
        init(_ p: PhoneTextField) { parent = p }
        func textField(_ f: UITextField, shouldChangeCharactersIn range: NSRange, replacementString s: String) -> Bool {
            let old = (f.text ?? "") as NSString
            var next = old.replacingCharacters(in: range, with: s)
            // deleting a space removes the digit before it
            if s.isEmpty && range.length == 1 && old.substring(with: range) == " " && range.location > 0 {
                next = old.replacingCharacters(in: NSRange(location: range.location - 1, length: 2), with: "")
            }
            let d = Phone.normalise(next)
            f.text = Phone.groups(d)
            parent.value = d
            return false
        }
        func textFieldDidBeginEditing(_ f: UITextField) { parent.onFocus(true) }
        func textFieldDidEndEditing(_ f: UITextField) { parent.onFocus(false) }
    }
}
