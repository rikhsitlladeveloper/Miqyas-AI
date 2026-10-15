import SwiftUI

/// The aurora light behind every glass screen: four soft glows on the paper colour, sized like the prototype's CSS
/// (radial-gradient(330px at 6% 4%, rgba(91,123,255,.62) → transparent at 70%), and so on); dimmed at night.
struct Aurora: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(G.paper))
            let k = Theme.shared.dark ? 0.45 : 1.0
            func glow(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ c: Color, _ a: Double) {
                let center = CGPoint(x: size.width * x, y: size.height * y)
                let g = Gradient(stops: [.init(color: c.opacity(a), location: 0), .init(color: c.opacity(0), location: 0.7)])
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(g, center: center, startRadius: 0, endRadius: r))
            }
            glow(0.06, 0.04, 330, G.auroraBlue, 0.62 * k)
            glow(1, 0.28, 300, G.auroraViolet, 0.48 * k)
            glow(0.04, 0.70, 340, G.auroraCyan, 0.40 * k)
            glow(1, 1, 300, G.auroraPeach, 0.50 * k * (Theme.shared.dark ? 0.6 : 1))
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// inset 0 1.5px 0 rgba(255,255,255,.95): a bright line along the inside of the top edge, clipped to the shape.
    func topHighlight<S: Shape>(_ shape: S, _ alpha: Double = 0.95, width: CGFloat = 1.5) -> some View {
        overlay(alignment: .top) { Rectangle().fill(G.hi(alpha)).frame(height: width) }.clipShape(shape)
    }

    /// A CSS box-shadow: blur b, offset y, colour (the Android dropShadow values; SwiftUI's radius is about half the blur).
    func boxShadow(_ color: Color, blur: CGFloat, y: CGFloat = 0) -> some View {
        shadow(color: color, radius: blur / 2, x: 0, y: y)
    }

    /// A frosted card on the soft background (no real blur): see-through white, a white rim, a bright inner top edge
    /// and a soft blue-grey shadow (prototype .gl-big / .gl-sm / .gl-pc).
    func glassCard<S: InsettableShape>(_ shape: S, fill: Color? = nil, shadowBlur: CGFloat = 28, shadowY: CGFloat = 12, shadowAlpha: Double = 0.12) -> some View {
        background(shape.fill(fill ?? G.fill))
            .topHighlight(shape)
            .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
            .background(shape.fill(Color.black.opacity(0.001)).boxShadow(G.shade.opacity(shadowAlpha), blur: shadowBlur, y: shadowY))
    }

    /// Real glass for layers content moves behind: the system blur with the design's white tint over it.
    func glassBlur<S: Shape>(_ shape: S, tint: Color) -> some View {
        background { ZStack { shape.fill(.ultraThinMaterial); shape.fill(tint) } }
    }
}

/// A press effect like the prototype's :active { transform: scale(.985) }.
struct Press: ButtonStyle {
    var scale: CGFloat = 0.985
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    /// The view as a button with the press effect; [label] is what VoiceOver says when the view has no text of its own.
    @ViewBuilder
    func pressable(_ scale: CGFloat = 0.985, label: String? = nil, _ action: @escaping () -> Void) -> some View {
        let b = Button(action: action) { self }.buttonStyle(Press(scale: scale))
        if let label { b.accessibilityLabel(Text(label)) } else { b }
    }
}
