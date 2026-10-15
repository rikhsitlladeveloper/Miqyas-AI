import SwiftUI
import UIKit
import Observation

extension Color {
    /// 0xAARRGGBB, like the Android app's Color(0xFF3550E0).
    init(argb: UInt32) {
        self.init(.sRGB, red: Double((argb >> 16) & 0xFF) / 255, green: Double((argb >> 8) & 0xFF) / 255,
                  blue: Double(argb & 0xFF) / 255, opacity: Double((argb >> 24) & 0xFF) / 255)
    }
}

/// Light or dark (Profile → "Tungi rejim"). Every colour in `G` reads `dark`, so the screens follow at once.
/// The sign-in screens always stay light. Paper drawings (report plans, card thumbnails) draw inside `onPaper`.
@Observable
final class Theme {
    static let shared = Theme()
    var inAuth = false
    @ObservationIgnored var paper = false
    var dark: Bool { AppSettings.shared.dark && !inAuth && !paper }
    func onPaper<T>(_ f: () -> T) -> T { let o = paper; paper = true; defer { paper = o }; return f() }
}

private func pick(_ light: UInt32, _ dark: UInt32) -> Color { Color(argb: Theme.shared.dark ? dark : light) }

/// Colours of the founder's liquid-glass design (prototype modules/glass.css). The dark values are the Android app's
/// (from the "Tun" glass option): a near-black ground, smoky glass with a faint white rim, light text, a lifted blue.
enum G {
    static var paper: Color { pick(0xFFEEF1F8, 0xFF0B0E16) }
    static var ink: Color { pick(0xFF0F172A, 0xFFE8ECF4) }
    static var ink2: Color { pick(0xFF475569, 0xFFAAB3C5) }
    static var ink3: Color { pick(0xFF64748B, 0xFF8A93A7) }
    static var slate: Color { pick(0xFF334155, 0xFFC2C9D6) }
    static var cobalt: Color { pick(0xFF3550E0, 0xFF5B74FF) }
    static var cobalt2: Color { pick(0xFF2B47D9, 0xFF9AA9FF) }
    static var green: Color { pick(0xFF16A34A, 0xFF3DD68C) }
    static var greyIcon: Color { pick(0xFF8A93A6, 0xFF7C8597) }
    static var fill: Color { glass(0.42) }
    static var rim: Color { Theme.shared.dark ? Color.white.opacity(0.12) : Color.white.opacity(0.8) }
    static var shade: Color { pick(0xFF1E286E, 0xFF000000) }
    static let auroraBlue = Color(argb: 0xFF5B7BFF)
    static let auroraViolet = Color(argb: 0xFFB07CFF)
    static let auroraCyan = Color(argb: 0xFF3FD8F2)
    static let auroraPeach = Color(argb: 0xFFFFB58A)
    static var err: Color { pick(0xFFB42318, 0xFFFF8A80) }
    static var errWash: Color { pick(0xFFFDEDEB, 0xFF3A1B1B) }
    static let blueprint = Color(argb: 0xFF0A1030)
    /// See-through white of the glass cards at a (prototype rgba(255,255,255,a)); smoky glass in the dark.
    static func glass(_ a: Double) -> Color { Color.white.opacity(Theme.shared.dark ? a * 0.16 : a) }
    /// The bright inner top edge of glass (prototype inset 0 1.5px 0 rgba(255,255,255,.95)).
    static func hi(_ a: Double) -> Color { Color.white.opacity(Theme.shared.dark ? a * 0.16 : a) }
    static var avatar: Color { pick(0xFF0F172A, 0xFF2A3247) }
    static var amberWash: Color { pick(0xFFFFF1DF, 0xFF33260F) }
    static var amberInk: Color { pick(0xFF9A4D00, 0xFFFFB45C) }
    static var noteWash: Color { pick(0xFFFFFAEB, 0xFF2A2616) }
    static var blueWash: Color { pick(0xFFE7EEFD, 0xFF1C2546) }
    static var greenWash: Color { pick(0xFFE8F6EE, 0xFF14291E) }
    static var scrim: Color { pick(0x6B0E1C36, 0x99000000) }
    /// The tint of sheets and other glass that content slides behind (prototype rgba(255,255,255,.84)).
    static func sheet(_ a: Double = 0.84) -> Color {
        Theme.shared.dark ? Color(argb: 0xFF161B27).opacity(min(1, a * 0.3 + 0.68)) : Color.white.opacity(a)
    }
    static var solid: Color { pick(0xFFFFFFFF, 0xFF1A2030) }
    static var stage: Color { pick(0xFFE9EDF3, 0xFF10141E) }
}

/// Colours of the sign-in screens (prototype modules/auth.css, from the founder's Figma file).
enum Au {
    static let cobalt = Color(argb: 0xFF3355B4)
    static let cobalt2 = Color(argb: 0xFF27448F)
    static let wash = Color(argb: 0xFFEBF2FC)
    static let ink = Color(argb: 0xFF0B1226)
    static let ink2 = Color(argb: 0xFF56627A)
    static let ink3 = Color(argb: 0xFF626E87)
    static let line = Color(argb: 0xFFC9D6E8)
    static let hair = Color(argb: 0xFFE7ECF3)
    static let tint = Color(argb: 0xFFF1F6FA)
    static let chip = Color(argb: 0xFFD3DFEF)
    static let plan = Color(argb: 0xFFF3F6FB)
    static let step = Color(argb: 0xFFE4E9ED)
}

/// The app's typefaces: Plus Jakarta Sans for Latin text, Manrope for Cyrillic (and the sign-in screens),
/// IBM Plex Sans Condensed for numbers, IBM Plex Mono on the sign-in screens.
enum Face { case ui, au, num, mono }

private let weightNames = [400: "Regular", 500: "Medium", 600: "SemiBold", 700: "Bold", 800: "ExtraBold"]

func fontName(_ face: Face, _ weight: Int) -> String {
    let w = max(400, min(800, (weight / 100) * 100))
    switch face {
    case .ui: return (AppSettings.shared.lang.cyrillic ? "Manrope-" : "PlusJakartaSans-") + weightNames[w]!
    case .au: return "Manrope-" + weightNames[w]!
    case .num: return "IBMPlexSansCond-" + weightNames[min(w, 700)]!
    case .mono: return "IBMPlexMono-" + weightNames[min(w, 700)]!
    }
}

/// A text style in the prototype's CSS terms: size in pt, weight 400–800, colour, line height as a multiple of the size
/// and letter spacing in em.
struct TStyle {
    var face: Face = .ui
    var size: CGFloat
    var weight: Int = 400
    var color: Color = G.ink
    var lineHeight: CGFloat? = nil
    var spacing: CGFloat = 0

    var name: String { fontName(face, weight) }
    var font: Font { .custom(name, size: size) }
    var uiFont: UIFont { UIFont(name: name, size: size) ?? .systemFont(ofSize: size) }
    /// Extra space between lines so a line box is size × lineHeight tall, like CSS line-height.
    var extraLeading: CGFloat { lineHeight.map { max(0, size * $0 - uiFont.lineHeight) } ?? 0 }
}

func ui(_ size: CGFloat, _ weight: Int = 400, _ color: Color = G.ink, lh: CGFloat? = nil, ls: CGFloat = 0) -> TStyle {
    TStyle(face: .ui, size: size, weight: weight, color: color, lineHeight: lh, spacing: ls)
}
func au(_ size: CGFloat, _ weight: Int = 400, _ color: Color = Au.ink, lh: CGFloat? = nil, ls: CGFloat = 0) -> TStyle {
    TStyle(face: .au, size: size, weight: weight, color: color, lineHeight: lh, spacing: ls)
}
func num(_ size: CGFloat, _ weight: Int = 700, _ color: Color = G.ink, ls: CGFloat = 0) -> TStyle {
    TStyle(face: .num, size: size, weight: weight, color: color, spacing: ls)
}
func mono(_ size: CGFloat, _ weight: Int = 500, _ color: Color = Au.ink, ls: CGFloat = 0) -> TStyle {
    TStyle(face: .mono, size: size, weight: weight, color: color, spacing: ls)
}

extension Text {
    /// The text in a TStyle: font, colour, letter spacing (line height comes from `T` or `.lineSpacing`).
    func st(_ s: TStyle) -> Text { font(s.font).foregroundColor(s.color).tracking(s.size * s.spacing) }
}

/// One line of text in a style; `T("…", ui(15, 700))` reads like the Android code's Text(…, style = ui(15f, 700)).
struct T: View {
    let text: String
    let s: TStyle
    var align: TextAlignment = .leading
    var lines: Int? = nil
    init(_ text: String, _ s: TStyle, align: TextAlignment = .leading, lines: Int? = nil) {
        self.text = text; self.s = s; self.align = align; self.lines = lines
    }
    var body: some View {
        Text(text).st(s).lineSpacing(s.extraLeading).multilineTextAlignment(align).lineLimit(lines)
    }
}
