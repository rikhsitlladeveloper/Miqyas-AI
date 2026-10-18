import Foundation

/*
 * A furniture order's stages and money (furniture plan section 4; Android data/Orders.kt): measured → designed →
 * quote sent → approved with a prepayment → in production → installed → paid in full. Money is whole numbers of the
 * smallest unit, as in Money.swift.
 */

/// The agreed price (nil until the order is approved), what was paid, and what is left (nil without a price).
struct OrderMoney { let agreed: Decimal?; let paid: Decimal; let left: Decimal? }

private func dec(_ s: String) -> Decimal? { Decimal(string: s.replacingOccurrences(of: " ", with: "")) }

func orderMoney(_ p: Project) -> OrderMoney {
    let agreed = p.agreed.isEmpty ? nil : dec(p.agreed)
    let paid = p.payments.reduce(Decimal(0)) { $0 + (dec($1.amount) ?? 0) }
    return OrderMoney(agreed: agreed, paid: paid, left: agreed.map { max(0, $0 - paid) })
}

/// Where the order is among F_STAGES, 0 for anything unknown.
func fStage(_ p: Project) -> Int { F_STAGES.firstIndex(of: p.stage) ?? 0 }

private let APPROVED = 3
private let INSTALLED = 5

/// What customers still owe on approved orders that are not paid yet, and on how many orders.
func owed(_ ps: [Project]) -> (Decimal, Int) {
    var sum = Decimal(0); var n = 0
    for p in ps where p.isFurniture && (APPROVED...INSTALLED).contains(fStage(p)) {
        if let left = orderMoney(p).left, left > 0 { sum += left; n += 1 }
    }
    return (sum, n)
}

/// An installed order with nothing left to pay becomes "paid".
func settle(_ p: Project) -> Project {
    var q = p
    if fStage(p) == INSTALLED && orderMoney(p).left == 0 { q.stage = "paid" }
    return q
}

/// Approving: the agreed price, the prepayment as the first payment (when there is one), stage "approved".
func approve(_ p: Project, _ agreed: Decimal, _ pre: Decimal, _ now: Ms) -> Project {
    var q = p
    q.agreed = Money.digits(agreed); q.stage = "approved"
    if pre > 0 { q.payments.append(Payment(id: uid(), amount: Money.digits(pre), ts: now, pre: true)) }
    return q
}

/// The next stage; approving goes through approve instead, and "paid" only comes from the payments.
func nextStage(_ p: Project) -> Project {
    let i = fStage(p)
    if i == APPROVED - 1 || i >= INSTALLED { return p }
    var q = p; q.stage = F_STAGES[i + 1]
    return settle(q)
}

/// One stage back, for a mistake; the price and the payments stay.
func prevStage(_ p: Project) -> Project { var q = p; q.stage = F_STAGES[max(0, fStage(p) - 1)]; return q }

func addPayment(_ p: Project, _ amount: Decimal, _ note: String, _ now: Ms) -> Project {
    var q = p
    q.payments.append(Payment(id: uid(), amount: Money.digits(amount), ts: now, note: note.trimmingCharacters(in: .whitespaces)))
    return settle(q)
}

/// Removing a payment of a paid order puts it back to "installed" when something is left again.
func removePayment(_ p: Project, _ id: String) -> Project {
    var q = p
    q.payments.removeAll { $0.id == id }
    if q.stage == "paid", let left = orderMoney(q).left, left > 0 { q.stage = "installed" }
    return q
}

/// Half the price, rounded half up: the usual prepayment.
func halfOf(_ v: Decimal) -> Decimal {
    var x = (v + 1) / 2, r = Decimal()
    NSDecimalRound(&r, &x, 0, .down)
    return r
}
