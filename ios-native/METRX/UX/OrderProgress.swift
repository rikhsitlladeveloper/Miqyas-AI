import SwiftUI

/*
 * A furniture order's progress, Xona → Mebel → Dizayn → Narx → PDF (UX upgrades 26 Oct 2026, section 2; mockup
 * design/ux-upgrades/mockup.html steps()/nextAct()): done steps ✓, the current one blue, Xona "–" with no room; each
 * step opens its place. The simple app calls the last step "Yuborish". The order cards show it as a 5-segment line.
 */

enum FStepState { case done, cur, todo, skip }

struct FStep: Equatable {
    let key: String
    var state: FStepState
    var label: String {
        switch key {
        case "room": return tr("ux.st.room")
        case "furn": return tr("ux.st.furn")
        case "design": return tr("ux.st.design")
        case "price": return tr("ux.st.price")
        default: return tr(AppSettings.shared.advanced ? "ux.st.pdf" : "ux.st.send")
        }
    }
}

/// The five steps of order p, the first one not done the current one.
func orderSteps(_ p: Project) -> [FStep] {
    let snap = AppSettings.shared.angleSnap
    let sent = !p.quotes.isEmpty
    let measured = p.rooms.contains { measuredRoom($0, snap) }
    let room: FStepState = measured ? .done : (p.rooms.isEmpty && p.floors.isEmpty ? .skip : .todo)
    let furn = p.furniture.contains { !$0.modules.isEmpty }
    let designed = furn && (sent || p.flow.contains("design") || p.flow.contains("price"))
    let priced = furn && (sent || p.flow.contains("price"))
    var st = [FStep(key: "room", state: room), FStep(key: "furn", state: furn ? .done : .todo),
              FStep(key: "design", state: designed ? .done : .todo), FStep(key: "price", state: priced ? .done : .todo),
              FStep(key: "send", state: sent ? .done : .todo)]
    // a room still to measure does not hold the furniture up: it is current only while there is no furniture
    if room == .todo && furn { st[0].state = .skip }
    if let i = st.firstIndex(where: { $0.state == .todo }) { st[i].state = .cur }
    return st
}

/// The current step's key, nil when all are done.
func curStep(_ p: Project) -> String? { orderSteps(p).first { $0.state == .cur }?.key }

/// The order's progress marks: "design" once the designer's main button was used, "price" once the price was seen.
func markFlow(_ pid: String, _ k: String) {
    guard let p = Store.shared.get(pid), !p.flow.contains(k) else { return }
    Store.shared.update(pid, touch: false) { $0.flow.append(k) }
}

/* ---------------- the price ---------------- */

/// The customer price of the order's furniture (nil before there is any), as the Narx tab works it out.
func orderPrice(_ p: Project) -> Decimal? {
    let s = AppSettings.shared
    let fs = p.furniture.filter { !$0.modules.isEmpty }
    if fs.isEmpty { return nil }
    let v = priceOf(fs, p.fprice, s.workshop, s.mats, s.hws).price
    return v > 0 ? v : nil
}

/// "≈ 12 345 000 so‘m (taxminiy)" in the simple app (rounded to the thousand), the exact price in Advanced.
/// short: just "≈ 12 345 000 so‘m" (the designer's narrow head, where "(taxminiy)" was cut off).
func priceLine(_ p: Project, short: Bool = false) -> String? {
    guard let v = orderPrice(p) else { return nil }
    let en = AppSettings.shared.lang == .en
    if AppSettings.shared.advanced { return tr("ux.exact", ["v": Money.str(v, p.precision, en) + " " + Money.cur(p.currency)]) }
    var r = v / 1000
    var out = Decimal()
    NSDecimalRound(&out, &r, 0, .plain)
    let v1k = Money.str(out * 1000, 0, en) + " " + Money.cur(p.currency)
    return short ? "≈ " + v1k : tr("ux.approx", ["v": v1k])
}

/// The price as a line: grey and approximate in the simple app, nothing before there is furniture.
struct OrderPriceLine: View {
    let p: Project
    var size: CGFloat = 13.5
    var body: some View {
        if let t = priceLine(p) {
            T(t, AppSettings.shared.advanced ? num(size, 700) : ui(size, 600, G.ink3), lines: 1)
                .minimumScaleFactor(0.8)
                .accessibilityIdentifier("ux.price")
        }
    }
}

/* ---------------- where a step goes ---------------- */

/// Opens step k of order p: the room (or a new one to measure), the gallery, the designer, the price, the sending.
func goStep(_ app: AppModel, _ p: Project, _ k: String) {
    let pid = p.id
    Haptic.tick()
    switch k {
    case "room":
        let snap = AppSettings.shared.angleSnap
        if let r = p.rooms.first(where: { !measuredRoom($0, snap) }) ?? p.rooms.first { openRoom(app, pid, r.id) }
        else { app.sheet = .fNewRoom(pid: pid) }
    case "furn":
        app.push(galleryRoute(p))
    case "design":
        if let f = p.furniture.first(where: { !$0.modules.isEmpty }) ?? p.furniture.first { KitOps.shared.sel = nil; app.push(designer(pid, f, step: 2)) }
        else { app.say("ux.needFurn", kind: .info) }
    case "price":
        openPrice(app, p)
    default:
        if p.furniture.contains(where: { !$0.modules.isEmpty }) { app.push(.report(pid: pid, no: nil)) } else { app.say("ux.needFurn", kind: .info) }
    }
}

/// The gallery for order p, opened on its measured room when it has one (as Android).
func galleryRoute(_ p: Project) -> Route {
    let snap = AppSettings.shared.angleSnap
    return .fGallery(pid: p.id, rid: p.rooms.first { measuredRoom($0, snap) }?.id)
}

/// The order's price: the Narx tab in Advanced, the price-and-send page (the report) in the simple app.
func openPrice(_ app: AppModel, _ p: Project) {
    guard p.furniture.contains(where: { !$0.modules.isEmpty }) else { app.say("ux.needFurn", kind: .info); return }
    markFlow(p.id, "price")
    if AppSettings.shared.advanced {
        if case .project(let id, _, _, _) = app.top, id == p.id { app.setProjectTab("price"); return }
        app.popTo { if case .project(let id, _, _, _) = $0 { return id == p.id }; return false }
        if case .project(let id, _, _, _) = app.top, id == p.id { app.setProjectTab("price") } else { app.push(.project(id: p.id, tab: "price")) }
    } else {
        app.push(.report(pid: p.id, no: nil))
    }
}

/// The order page's one big button: what to do next, by the progress (the stages after the quote in Advanced).
struct MainAction { let label: String; let icon: String?; let go: () -> Void }

func mainAction(_ app: AppModel, _ p: Project) -> MainAction {
    let s = AppSettings.shared
    let pid = p.id
    let gallery = MainAction(label: tr("ux.addMore"), icon: "plus") { app.push(galleryRoute(p)) }
    if s.advanced && fStage(p) >= 2 {
        if let st = NextStep.of(app, p) { return MainAction(label: st.button, icon: nil, go: st.go) }
        return gallery
    }
    switch curStep(p) {
    case "room":
        if let st = NextStep.of(app, p) { return MainAction(label: st.button, icon: "ruler", go: st.go) }
        return MainAction(label: tr("ns.measureB"), icon: "ruler") { goStep(app, p, "room") }
    case "furn":
        // a room-less piece waiting for its measured room goes in first
        if let st = NextStep.of(app, p), st.place { return MainAction(label: st.button, icon: nil, go: st.go) }
        return MainAction(label: tr("ux.addFurn"), icon: "plus") { app.push(galleryRoute(p)) }
    case "design": return MainAction(label: tr("ux.goDesign"), icon: "cube") { goStep(app, p, "design") }
    case "price": return MainAction(label: tr("ux.seePrice"), icon: "coin") { openPrice(app, p) }
    case "send": return MainAction(label: tr("ux.tg"), icon: "send") { QuoteSend.send(app, pid) }
    default: return gallery
    }
}

/* ---------------- the views ---------------- */

/// The five steps; compact: the designer's smaller version.
struct OrderProgress: View {
    let app: AppModel
    let p: Project
    var compact = false
    var body: some View {
        let st = orderSteps(p)
        if compact { row(st, all: false) }
        // all five names when they fit; else only the current one, as the designer's head (an iPhone SE cut them to "Ro…", "Furn…")
        else { ViewThatFits(in: .horizontal) { row(st, all: true); row(st, all: false) } }
    }

    private func row(_ st: [FStep], all: Bool) -> some View {
        HStack(spacing: compact ? 2 : 4) {
            ForEach(Array(st.enumerated()), id: \.offset) { i, s in
                if i > 0 { Spacer(minLength: 0) }
                let col: Color = s.state == .cur ? G.cobalt : s.state == .done ? G.green : G.ink3
                HStack(spacing: 4) {
                    ZStack {
                        Circle().fill(s.state == .cur ? G.cobalt : s.state == .done ? G.green.opacity(0.16) : G.ink.opacity(0.07))
                        if s.state == .done { MIcon("check", G.green, compact ? 10 : 12, 2.6) }
                        else { T(s.state == .skip ? "–" : "\(i + 1)", ui(compact ? 10 : 11.5, 800, s.state == .cur ? .white : G.ink3)) }
                    }
                    .frame(width: compact ? 18 : 22, height: compact ? 18 : 22)
                    // the designer's narrow head: the current step's name only (the others were cut to "Di…")
                    if all || s.state == .cur {
                        T(s.label, ui(compact ? 11 : 12.5, s.state == .cur ? 800 : 600, s.state == .todo || s.state == .skip ? G.ink3 : col), lines: 1)
                            .minimumScaleFactor(compact ? 0.6 : 0.9)
                    }
                }
                // each step as wide as its name (equal widths cut "Yuborish" to "Yubo…" while "Xona" had room)
                .padding(.horizontal, compact ? 4 : 6).frame(minHeight: compact ? 32 : 40)
                .layoutPriority(s.state == .cur ? 1 : 0)
                .background(Capsule().fill(s.state == .cur ? G.cobalt.opacity(0.1) : .clear))
                .contentShape(Rectangle())
                .onTapGesture { goStep(app, p, s.key) }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(s.label)
                .accessibilityAddTraits(s.state == .cur ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("ux.step." + s.key)
            }
        }
    }
}

/// The order cards' small 5-segment line.
struct MiniProgress: View {
    let p: Project
    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(orderSteps(p).enumerated()), id: \.offset) { _, s in
                Capsule().fill(s.state == .cur ? G.cobalt : s.state == .done || s.state == .skip ? G.cobalt.opacity(0.45) : G.ink.opacity(0.12))
                    .frame(height: 5)
            }
        }
        .frame(maxWidth: 150)
        .accessibilityHidden(true)
    }
}

/// "Keyingi: Dizayn", or "Yuborildi ✓" once everything is done.
func nextLine(_ p: Project) -> String {
    guard let k = curStep(p) else { return tr("ux.allDone") }
    return tr("ux.next", ["s": FStep(key: k, state: .cur).label])
}
