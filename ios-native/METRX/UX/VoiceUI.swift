import SwiftUI

/*
 * The voice input's buttons (UX upgrades 26 Oct 2026, sections 6 and 9): "Bosib turib gapiring" under a size field
 * (hold, say "uch ming to‘rt yuz", let go: 3400 goes into the field), the first-use sheet that offers the pack over
 * Wi-Fi, and the laser button beside it.
 */

/// Hold to talk: heard(mm, words) with the size heard (nil when no number was understood).
struct MicButton: View {
    let app: AppModel
    let heard: (Int?, String) -> Void
    @State private var phase = 0          // 0 idle, 1 recording, 2 recognising
    @State private var pressed = false
    var body: some View {
        let pack = VoicePack.shared
        let label = phase == 1 ? tr("ux.vListen") : phase == 2 ? tr("ux.vThink") : pack.state == .loading ? tr("ux.vLoading") : tr("ux.vHold")
        HStack(spacing: 8) {
            PathIcon(MIC_ICON, phase == 1 ? .white : G.ink, 20, 2.2)
            T(label, ui(14, 700, phase == 1 ? .white : G.ink), lines: 2).minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 52)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(phase == 1 ? G.err : G.ink.opacity(0.07)))
        .scaleEffect(pressed ? 0.97 : 1)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in if !pressed { pressed = true; down() } }
            .onEnded { _ in pressed = false; up() })
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tr("ux.vHold"))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("ux.mic")
        .coachMark("size")
    }

    private func down() {
        let pack = VoicePack.shared
        if pack.state == .loading { app.say("ux.vLoadingT", kind: .info); return }
        if pack.state != .ready { app.sheet = .voicePack; return }
        VoiceEngine.shared.permission { ok in
            guard ok else { app.say("ux.micDenied", kind: .error); return }
            // let go before the question was answered: nothing to record
            guard pressed, phase == 0 else { return }
            if VoiceEngine.shared.start() { phase = 1; Haptic.tick() } else { app.say("ux.micDenied", kind: .error) }
        }
    }

    private func up() {
        guard phase == 1 else { return }
        phase = 2
        VoiceEngine.shared.stop { text in
            phase = 0
            let words = text ?? ""
            heard(words.isEmpty ? nil : VoiceParse.mm(words), words)
        }
    }
}

/// The laser button under a size field: "Lazerni ulash" (the radar) with no laser, "Lazer · o‘lchash" with one.
struct LaserFieldButton: View {
    let app: AppModel
    let busy: Bool
    let measure: () -> Void
    var body: some View {
        let on = AppSettings.shared.laser == .connected || LaserRouter.shared.simOn
        HStack(spacing: 8) {
            MIcon("laser", on ? .white : G.cobalt2, 20, 2.2)
            T(busy ? tr("fx.busy") : tr(on ? "ux.lzMeasure" : "ux.lzConnect"), ui(14, 700, on ? .white : G.cobalt2), lines: 2).minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 12).frame(maxWidth: .infinity, minHeight: 52)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(on ? G.cobalt : G.cobalt.opacity(0.1)))
        .opacity(busy ? 0.6 : 1)
        .pressable(0.97) { if busy { return }; Haptic.tick(); if on { measure() } else { app.openLaser() } }
        .accessibilityIdentifier("fx.laser")
    }
}

/// "Ovoz paketi (57 MB) — Wi-Fi da yuklab olish", with "Keyinroq".
struct VoicePackSheet: View {
    let app: AppModel
    var body: some View {
        let pack = VoicePack.shared
        GlassSheet(tr("ux.vSheetT"), onClose: { app.sheet = nil }) {
            T(tr("ux.vSheetB"), ui(14, 400, G.ink2, lh: 1.45))
            HStack(alignment: .top, spacing: 12) {
                MIcon("globe", G.cobalt, 22, 2)
                VStack(alignment: .leading, spacing: 4) {
                    T(tr("ux.vPackT", ["n": VoicePack.modelMB]), ui(15, 700))
                    T(tr("ux.vPackS"), ui(12.5, 400, G.ink2, lh: 1.4))
                    if pack.state == .loading { ProgressView(value: pack.progress).tint(G.cobalt) }
                    if !pack.wifi && pack.state != .loading { T(tr("ux.vNoWifi"), ui(12.5, 600, G.amberInk, lh: 1.4)) }
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.glass(0.6)))
        } footer: {
            GBtn(tr(pack.state == .loading ? "ux.vLoading" : "ux.vGet"), icon: "save", enabled: pack.state != .loading && pack.wifi) {
                if VoicePack.shared.download() { Haptic.tick() } else { app.say("ux.vNoWifi", kind: .info) }
            }
            .accessibilityIdentifier("ux.vGet")
            T(tr("ux.later"), ui(14.5, 700, G.cobalt2)).padding(.vertical, 10).frame(maxWidth: .infinity)
                .pressable(0.97) { app.sheet = nil }
                .accessibilityAddTraits(.isButton).accessibilityIdentifier("ux.vLater")
        }
    }
}

/// Profile's line about the pack: not loaded, loading with its bar, or ready.
struct VoicePackRow: View {
    let app: AppModel
    var body: some View {
        let pack = VoicePack.shared
        HStack(spacing: 12) {
            PathIcon(MIC_ICON, G.cobalt, 20, 2).frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(G.cobalt.opacity(0.12)))
            VStack(alignment: .leading, spacing: 3) {
                T(tr("ux.vRow"), ui(15.5, 500))
                switch pack.state {
                case .ready: T(tr("ux.vReadyS"), ui(12.5, 400, G.green, lh: 1.35))
                case .loading:
                    T(tr("ux.vLoadingS"), ui(12.5, 400, G.ink2))
                    ProgressView(value: pack.progress).tint(G.cobalt)
                case .failed: T(tr("ux.vFailS"), ui(12.5, 400, G.err, lh: 1.35))
                case .none: T(tr("ux.vNoneS", ["n": VoicePack.modelMB]), ui(12.5, 400, G.ink2, lh: 1.35))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if pack.state == .none || pack.state == .failed {
                GBtn(tr("ux.vLoad"), kind: .secondary, height: 40, corner: 14, fontSize: 14, fill: false) {
                    if !VoicePack.shared.download() { app.say("ux.vNoWifi", kind: .info) }
                }
                .accessibilityIdentifier("pf.voice")
            } else if pack.state == .ready {
                MIcon("trash", G.ink3, 18, 2).frame(width: 40, height: 40)
                    .pressable(0.95, label: tr("common.delete")) { VoicePack.shared.remove(); app.say("ux.vRemoved", kind: .info) }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10).frame(minHeight: 60)
    }
}
