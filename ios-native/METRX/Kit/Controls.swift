import SwiftUI

/* Pieces of the glass screens (values from the prototype's computed styles, as in the Android app's GlassKit). */

/// Round glass icon button, 44 pt (prototype .bar .ib).
struct GlassIconButton: View {
    let icon: String
    let label: String
    var size: CGFloat = 44
    var iconSize: CGFloat = 22
    var tint: Color? = nil
    let action: () -> Void
    init(_ icon: String, _ label: String, size: CGFloat = 44, iconSize: CGFloat = 22, tint: Color? = nil, _ action: @escaping () -> Void) {
        self.icon = icon; self.label = label; self.size = size; self.iconSize = iconSize; self.tint = tint; self.action = action
    }
    var body: some View {
        MIcon(icon, tint ?? G.ink, iconSize, 2)
            .frame(width: size, height: size)
            .background(Circle().fill(G.glass(0.42)))
            .topHighlight(Circle(), 0.95, width: 1)
            .overlay(Circle().strokeBorder(G.rim, lineWidth: 1))
            .background(Circle().fill(Color.black.opacity(0.001)).boxShadow(G.shade.opacity(0.1), blur: 18, y: 6))
            .pressable(0.95, label: label, action)
    }
}

enum Btn { case primary, secondary, danger }

/// Buttons of the glass screens: 54 pt, corner 18, primary blue with a soft blue shadow, secondary a grey wash.
struct GBtn: View {
    let label: String
    var kind: Btn = .primary
    var icon: String? = nil
    var enabled = true
    var height: CGFloat = 54
    var corner: CGFloat = 18
    var fontSize: CGFloat = 16
    var fill = true
    let action: () -> Void
    init(_ label: String, kind: Btn = .primary, icon: String? = nil, enabled: Bool = true, height: CGFloat = 54, corner: CGFloat = 18,
         fontSize: CGFloat = 16, fill: Bool = true, _ action: @escaping () -> Void) {
        self.label = label; self.kind = kind; self.icon = icon; self.enabled = enabled; self.height = height; self.corner = corner
        self.fontSize = fontSize; self.fill = fill; self.action = action
    }
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        let bg: Color = kind == .primary ? G.cobalt : kind == .secondary ? G.ink.opacity(0.06) : Color(argb: 0xFFB42318)
        let fg: Color = kind == .secondary ? G.ink : .white
        HStack(spacing: 8) {
            if let icon { MIcon(icon, fg, 18, 2.2) }
            T(label, ui(fontSize, 700, fg), align: .center, lines: 1)
        }
        .padding(.horizontal, height < 50 ? 12 : 16)
        .frame(maxWidth: fill ? .infinity : nil, minHeight: height)
        .background(shape.fill(bg))
        .background(shape.fill(Color.black.opacity(0.001)).boxShadow(kind == .primary && enabled ? Color(argb: 0x38374FDD) : .clear, blur: 18, y: 8))
        .opacity(enabled ? 1 : 0.42)
        .pressable(0.98) { if enabled { action() } }
        .accessibilityAddTraits(enabled ? [] : .isStaticText)
    }
}

/// Primary and secondary buttons of the glass sheets.
struct GlassButton: View {
    let label: String
    var primary = true
    var icon: String? = nil
    let action: () -> Void
    init(_ label: String, primary: Bool = true, icon: String? = nil, _ action: @escaping () -> Void) {
        self.label = label; self.primary = primary; self.icon = icon; self.action = action
    }
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: 8) {
            if let icon { MIcon(icon, primary ? .white : G.ink, 18, 2.2) }
            T(label, ui(16, 700, primary ? .white : G.ink), lines: 1)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(shape.fill(primary ? G.cobalt : G.glass(0.6)))
        .overlay(primary ? nil : shape.strokeBorder(G.rim, lineWidth: 1))
        .background(shape.fill(Color.black.opacity(0.001)).boxShadow(primary ? G.cobalt.opacity(0.3) : .clear, blur: 22, y: 10))
        .pressable(0.98, action)
    }
}

/// The METRX mark drawn in a 64 × 64 box: a white M with the three corner dots and the ruler ticks cut in the tile colour.
func drawLogoMark(_ ctx: GraphicsContext, tile: Color, box: CGFloat, origin: CGPoint = .zero) {
    var c = ctx
    c.translateBy(x: origin.x, y: origin.y)
    c.scaleBy(x: box / 64, y: box / 64)
    c.stroke(SVGPath.path("M15 47V19l17 19 17-19v28"), with: .color(.white), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
    for p in [CGPoint(x: 15, y: 19), CGPoint(x: 32, y: 38), CGPoint(x: 49, y: 19)] {
        c.fill(Path(ellipseIn: CGRect(x: p.x - 1.9, y: p.y - 1.9, width: 3.8, height: 3.8)), with: .color(tile))
    }
    c.stroke(SVGPath.path("M11.5 28h3M11.5 34h3M11.5 40h3M49.5 28h3M49.5 34h3M49.5 40h3"), with: .color(tile), lineWidth: 1.4)
}

/// The logo tile: 38 pt, corner 11, #3550E0 on glass screens (prototype .wordmark::before).
struct LogoTile: View {
    var size: CGFloat = 38
    var corner: CGFloat = 11
    var color: Color = G.cobalt
    var body: some View {
        Canvas { ctx, sz in
            ctx.fill(Path(roundedRect: CGRect(origin: .zero, size: sz), cornerRadius: corner, style: .continuous), with: .color(color))
            drawLogoMark(ctx, tile: color, box: sz.width)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Logo and the spaced METRX name (prototype .wordmark in the glass header).
struct Wordmark: View {
    var body: some View {
        HStack(spacing: 10) {
            LogoTile()
            Text("METRX").font(.custom("PlusJakartaSans-Bold", size: 19)).foregroundColor(G.ink).tracking(19 * 0.32)
        }
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
    }
}

private let BT_RUNE = "M6.5 6.5L17.5 17.5L12 23L12 1L17.5 6.5L6.5 17.5"

/// The round laser button at the top right (prototype .gl-bt): grey with a grey dot when not connected, green when
/// connected. The colour is never the only signal: the label says the state.
struct LaserButton: View {
    let action: () -> Void
    var body: some View {
        let on = AppSettings.shared.laser == .connected
        let c = on ? G.green : G.greyIcon
        PathIcon(BT_RUNE, c, 22, 2.2)
            .frame(width: 48, height: 48)
            .glassBlur(Circle(), tint: G.sheet(0.42))
            .topHighlight(Circle(), 0.95, width: 1)
            .overlay(Circle().strokeBorder(G.rim, lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                Circle().fill(c).frame(width: 5, height: 5).padding(2).background(Circle().fill(G.solid)).offset(x: -9, y: 9)
            }
            .background(Circle().fill(Color.black.opacity(0.001)).boxShadow(G.shade.opacity(0.14), blur: 24, y: 8))
            .pressable(0.95, label: tr(on ? "gl.btOn" : "gl.btOff"), action)
            .accessibilityIdentifier("laser")
    }
}

/// The glass header: logo and name on the left, the laser button on the right.
struct GlassHeader: View {
    let onLaser: () -> Void
    var body: some View {
        HStack { Wordmark(); Spacer(); LaserButton(action: onLaser) }
            .padding(.leading, 8).padding(.trailing, 12).padding(.vertical, 8)
    }
}

/// The on/off switch: 46 × 28, a 22 pt white knob; blue when on.
struct GSwitch: View {
    let on: Bool
    var body: some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule().fill(on ? G.cobalt : G.ink.opacity(0.14))
            Circle().fill(Color.white).frame(width: 22, height: 22).boxShadow(Color(argb: 0x40101828), blur: 3, y: 1).padding(3)
        }
        .frame(width: 46, height: 28)
        .animation(.easeOut(duration: 0.15), value: on)
    }
}

/// A white list group with hairlines between rows (prototype .lgroup in the glass look).
struct ListBox<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(spacing: 0) { content }
            .padding(.horizontal, 12)
            .background(shape.fill(G.glass(0.6)))
            .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
    }
}

struct Hairline: View {
    var body: some View { Rectangle().fill(G.ink.opacity(0.08)).frame(height: 1) }
}

/// A row in a sheet's action list: an icon in a pale tile, a label; red for destructive actions.
struct ActionRow<Trailing: View>: View {
    let icon: String
    let label: String
    var danger = false
    let action: () -> Void
    @ViewBuilder var trailing: Trailing
    var body: some View {
        let c = danger ? G.err : G.ink
        HStack(spacing: 12) {
            MIcon(icon, danger ? c : G.cobalt, 20, 2)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill((danger ? c : G.cobalt).opacity(0.12)))
            T(label, ui(15.5, 500, c)).frame(maxWidth: .infinity, alignment: .leading)
            trailing
        }
        .padding(.horizontal, 4)
        .frame(minHeight: 56)
        .pressable(0.99, action)
    }
}

extension ActionRow where Trailing == EmptyView {
    init(icon: String, label: String, danger: Bool = false, action: @escaping () -> Void) {
        self.init(icon: icon, label: label, danger: danger, action: action) { EmptyView() }
    }
}

/// Space the floating tab bar takes at the bottom of every tab page (68 + margins 4 and 14).
let NAV_SPACE: CGFloat = 86
