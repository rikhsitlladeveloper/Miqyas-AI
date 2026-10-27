import SwiftUI

/*
 * One size of the room-shape flow, as the UX upgrades' size steps (§6, §9, §10; Android ui/rooms/RoomField.kt): a big
 * number field with the phone's own number keyboard, the laser button ("Lazerni ulash" opens the radar, "Lazer ·
 * o‘lchash" measures) and the hold-to-talk mic under it; a laser or voice value lights the field green with a confirm
 * haptic, a wrong number shows its error with a warning haptic.
 */

/// The field and its tools. text is what is typed (in unit); fresh: the value was put in for the maker (the last
/// height, a size opened again) and the first key replaces it; hint shows when empty; issue a red line under it.
struct RshSizeField: View {
    let app: AppModel
    let d: RshDraft
    /// Changes with each step, so the field takes the focus again.
    let key: String
    let label: String
    let help: String
    let text: String
    let fresh: Bool
    let hint: Int
    let issue: String?
    /// The field's text and freshness as the draft has them now (keys typed fast arrive before the view is drawn again).
    let live: () -> (text: String, fresh: Bool)
    let onText: (String) -> Void
    let onNext: () -> Void
    /// A laser or voice value, mm; words: what was heard (nil from the laser).
    let onValue: (Int, String?) -> Void
    let onUnVoice: () -> Void
    @FocusState private var focused: Bool
    @State private var glow = false
    @State private var seenFlash = 0

    var body: some View {
        let unit = rshUnit(d)
        let uw = unitWord(unit)
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        let bad = issue != nil
        VStack(alignment: .leading, spacing: 8) {
            T(label, ui(20, 800, G.ink, lh: 1.2)).padding(.top, 4).accessibilityIdentifier("rsh.label")
            if let h = d.heard {
                HStack(spacing: 8) {
                    PathIcon(MIC_ICON, G.green, 18, 2.2)
                    T(tr("ux.fromVoice", ["w": h.words, "v": text + " " + uw]), ui(13, 600, G.ink, lh: 1.3), lines: 2).frame(maxWidth: .infinity, alignment: .leading)
                    T(tr("ux.cancelV"), ui(14, 800, G.cobalt2)).padding(.horizontal, 12).frame(minHeight: 44)
                        .pressable(0.97, onUnVoice)
                        .accessibilityIdentifier("ux.voiceUndo")
                }
                .padding(.leading, 12).padding(.trailing, 4).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.greenWash))
            } else {
                T(help, ui(13, 400, G.ink2, lh: 1.35))
            }
            HStack(spacing: 10) {
                // a value put in for the maker (the last height, a size opened again) shows as the field's blue prompt over an
                // empty field, so the first key typed replaces it (as selected text would) and "Keyingi" keeps it; the
                // field's own text is never rewritten under the keyboard, which would leave it out of step with the draft
                let shownFresh = fresh && !text.isEmpty
                TextField("", text: Binding(get: { shownFresh ? "" : text }, set: { v in
                    let now = live()
                    let clean = String(v.filter { $0.isNumber || (unit != .mm && ($0 == "," || $0 == ".")) }.prefix(unit == .mm ? 5 : 8))
                    if now.fresh && !now.text.isEmpty { if !clean.isEmpty { onText(clean) }; return }
                    if clean != now.text { onText(clean) }
                }), prompt: Text(shownFresh ? text : unit == .mm ? fmtMm(Double(hint)) : Geo.fmtField(hint, unit, rshEn))
                    .foregroundColor(shownFresh ? G.cobalt2 : Color(argb: 0xFFA7B0C0)))
                .font(num(32, 700).font).foregroundColor(fresh ? G.cobalt2 : G.ink)
                .keyboardType(unit == .mm ? .numberPad : .decimalPad)
                .focused($focused)
                .submitLabel(.next)
                .onSubmit(onNext)
                .accessibilityLabel(label)
                .accessibilityIdentifier("rsh.value")
                T(uw, ui(17, 700, G.ink3))
            }
            .padding(.horizontal, 16).frame(minHeight: 68)
            .background(shape.fill(glow ? G.greenWash : G.glass(0.85)))
            .overlay(shape.strokeBorder(bad ? G.err : glow ? G.green : G.cobalt, lineWidth: 2))
            .shadow(color: glow ? G.green.opacity(0.45) : .clear, radius: glow ? 12 : 0)
            .animation(.easeOut(duration: 0.25), value: glow)
            .contentShape(shape)
            .onTapGesture { focused = true }
            if let issue {
                HStack(alignment: .top, spacing: 6) { MIcon("alert", G.err, 18, 2); T(issue, ui(13.5, 600, G.err, lh: 1.35)) }
                    .accessibilityIdentifier("rsh.err")
            }
            // always under the field: the laser (or the radar to connect one) and hold-to-talk (UX upgrades §6)
            HStack(spacing: 10) {
                LaserFieldButton(app: app, busy: d.busy) { rshRead(app, d, hint, label) { mm in onValue(mm, nil) } }
                MicButton(app: app) { mm, words in
                    guard let mm else { Haptic.warn(); if words.isEmpty { app.say("ux.vNothing", kind: .info) }; return }
                    onValue(mm, words)
                }
            }
        }
        .task(id: key) {
            // the keyboard waits until the page has slid in, or iOS drops the focus
            try? await Task.sleep(nanoseconds: 350_000_000)
            focused = true
        }
        .onChange(of: d.flash) { _, v in
            guard v != seenFlash else { return }
            seenFlash = v
            glow = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { glow = false }
        }
    }
}

/// A value put in for the maker (old) edited into new: what was typed replaces it, wherever the cursor was (the
/// characters new has that old has not); a key deleting empties it.
func rshReplaceFresh(_ old: String, _ new: String) -> String {
    if new.count <= old.count { return new == old ? new : "" }
    let a = Array(old), b = Array(new)
    var p = 0
    while p < a.count && a[p] == b[p] { p += 1 }
    var s = 0
    while s < a.count - p && a[a.count - 1 - s] == b[b.count - 1 - s] { s += 1 }
    return String(b[p..<(b.count - s)])
}

/// The laser button's reading: the real laser's next measurement; with the screen tests' simulator the newest reading
/// not used yet, else one near hint; with no laser, the radar to connect one.
func rshRead(_ app: AppModel, _ d: RshDraft, _ hint: Int, _ label: String, _ got: @escaping (Int) -> Void) {
    guard !d.busy else { return }
    if LaserRouter.shared.isReal {
        d.busy = true
        LaserRouter.shared.waitFor(onCancel: { d.busy = false }) { mm in d.busy = false; got(mm) }
        return
    }
    guard LaserRouter.shared.simOn else { app.openLaser(); return }
    if let r = AppSettings.shared.readings.last(where: { $0.used == nil && $0.src != "manual" }) {
        AppSettings.shared.markReadingUsed(r.id, label)
        got(r.mm)
        return
    }
    d.busy = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
        d.busy = false
        got((hint + Int.random(in: -120...120)) / 10 * 10)
    }
}
