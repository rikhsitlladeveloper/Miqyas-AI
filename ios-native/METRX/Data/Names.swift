import Foundation

/* Names, counts and small numbers shown about projects and workspaces (prototype: dn, floorName, wsSuggest, wsCounts, pcStats). */

/// A stored name: typed text as it is, "@key" names in the language. "@key?w=300&a=12.5" fills the text's values (the
/// trades' calculator lines); a decimal point is shown as the language's mark.
func dn(_ s: String?, _ l: Lang = AppSettings.shared.lang) -> String {
    guard let s else { return "" }
    guard s.hasPrefix("@") else { return s }
    guard let q = s.firstIndex(of: "?") else { return Strings.t(String(s.dropFirst()), l) }
    var vars: [String: Any] = [:]
    for kv in s[s.index(after: q)...].split(separator: "&") where kv.contains("=") {
        let v = String(kv.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)[1])
        // a value "~key" is itself a strings key (a tile's look in the tiler's lines), shown in the language too
        let shown: String
        if v.hasPrefix("~") { shown = Strings.t(String(v.dropFirst()), l) } else { shown = l == .en ? v : v.replacingOccurrences(of: ".", with: ",") }
        vars[String(kv.prefix { $0 != "=" })] = shown
    }
    return Strings.t(String(s[s.index(after: s.startIndex)..<q]), l, vars)
}

/// The stored form of a text with values ("@key?w=300&a=12.5"), which dn shows in any language.
func keyName(_ key: String, _ vars: [String: String]) -> String {
    if vars.isEmpty { return "@" + key }
    return "@" + key + "?" + vars.sorted { $0.key < $1.key }.map { $0.key + "=" + $0.value.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: " ", with: "") }.joined(separator: "&")
}

/// A room's name as the app suggested it from strings key `key` ("Hammom", "Hammom 2") kept as that key, so it follows
/// the language later ("@fr.bath", "@nm.n?b=~fr.bath&n=2"); a name typed or changed stays as typed. `vars`: the key's values.
func suggestedName(_ typed: String, _ key: String, _ l: Lang = AppSettings.shared.lang, _ vars: [String: String] = [:]) -> String {
    let t = typed.trimmingCharacters(in: .whitespaces)
    let base = Strings.t(key, l, vars.isEmpty ? nil : (vars as [String: Any]))
    if t == base { return vars.isEmpty ? "@" + key : keyName(key, vars) }
    let pre = base + " "
    if vars.isEmpty && t.hasPrefix(pre), let n = Int(t.dropFirst(pre.count)), "\(base) \(n)" == t { return "@nm.n?b=~\(key)&n=\(n)" }
    return t
}

/// The suggested name for a new room from strings key `key`: "Hammom", or "Hammom 2" when there is one (counted in the language shown).
func nextName(_ p: Project, _ key: String, _ l: Lang = AppSettings.shared.lang) -> String {
    let base = Strings.t(key, l)
    let n = p.floors.filter { floorName($0, l).hasPrefix(base) }.count
    return n > 0 ? "\(base) \(n + 1)" : base
}

/// A workspace and one of its rooms (nil: none drawn yet) for a trade's rooms tab; several: the workspace has more than one.
struct WsRoom: Identifiable {
    let w: Workspace
    let room: Room?
    let several: Bool
    var id: String { w.id + "|" + (room?.id ?? "") }
}

/// Every room of each workspace (an older project may have several in one), a workspace without one once.
func wsRooms(_ p: Project) -> [WsRoom] {
    var out: [WsRoom] = []
    for w in p.floors {
        let rs = p.rooms.filter { $0.floorId == w.id }
        if rs.isEmpty { out.append(WsRoom(w: w, room: nil, several: false)) }
        for r in rs { out.append(WsRoom(w: w, room: r, several: rs.count > 1)) }
    }
    return out
}

/// A rooms tab card's title: the workspace, and the room's own name when the workspace holds several.
func wsRoomTitle(_ w: Workspace, _ room: Room?, _ several: Bool) -> String {
    guard several, let room else { return floorName(w) }
    return floorName(w) + " · " + dn(room.name)
}

func floorName(_ w: Workspace, _ l: Lang = AppSettings.shared.lang) -> String {
    if w.name == "@floor1" { return Strings.t("pr.floorName", l, ["n": 1]) }
    if w.name.hasPrefix("@floor:") { return Strings.t("pr.floorName", l, ["n": String(w.name.dropFirst(7))]) }
    return dn(w.name, l)
}

let WS_TYPES: [(String, String)] = [("floor", "layers"), ("room", "room"), ("bath", "bath"), ("kitchen", "kitchen"), ("balcony", "balcony"), ("outdoor", "tree"), ("other", "folder")]
func wsIcon(_ type: String) -> String { WS_TYPES.first { $0.0 == type }?.1 ?? "layers" }

/// The name offered for a new workspace of this type: "2-qavat", "Hammom", "Hammom 2"…
func wsSuggest(_ p: Project, _ type: String, _ l: Lang = AppSettings.shared.lang) -> String {
    // never a name already there (after a delete)
    let taken = Set(p.floors.map { floorName($0, l) })
    if type == "floor" {
        var k = p.floors.filter { $0.type == "floor" }.count + 1
        while taken.contains(Strings.t("pr.floorName", l, ["n": k])) { k += 1 }
        return Strings.t("pr.floorName", l, ["n": k])
    }
    let base = Strings.t("ws.t." + type, l)
    let n = p.floors.filter { let nm = floorName($0, l); return nm == base || nm.hasPrefix(base + " ") }.count
    if n == 0 && !taken.contains(base) { return base }
    var k = max(2, n + 1)
    while taken.contains("\(base) \(k)") { k += 1 }
    return "\(base) \(k)"
}

/// Stores a suggested name as a key, so it follows the language later; typed names stay as typed.
func wsStoreName(_ p: Project, _ nm: String, _ type: String, _ l: Lang = AppSettings.shared.lang) -> String {
    if type == "floor" { for k in 1...(2 * p.floors.count + 1) where nm == Strings.t("pr.floorName", l, ["n": k]) { return "@floor:\(k)" } }
    return nm == Strings.t("ws.t." + type, l) ? "@ws.t." + type : nm
}

/// "5 ta xona, 1 ta chizma, 2 ta surat"
func wsCounts(_ p: Project, _ w: Workspace, _ l: Lang = AppSettings.shared.lang) -> String {
    let rooms = p.rooms.filter { $0.floorId == w.id }.count
    func c(_ k: String) -> Int { w.items.filter { $0.kind == k }.count }
    return [(rooms, "ws.cRoom"), (c("drawing"), "ws.cDraw"), (c("photo"), "ws.cPhoto"), (c("note"), "ws.cNote")]
        .filter { $0.0 > 0 }.map { Strings.t($0.1, l, ["n": $0.0]) }.joined(separator: ", ")
}

func itemName(_ it: Item, _ l: Lang = AppSettings.shared.lang) -> String {
    let n = dn(it.name, l)
    return it.kind == "note" && n.trimmingCharacters(in: .whitespaces).isEmpty ? Strings.t("it.untitled", l) : n
}

func fmtDate(_ ts: Ms) -> String {
    let c = Calendar.current.dateComponents([.day, .month, .year], from: Date(timeIntervalSince1970: Double(ts) / 1000))
    return String(format: "%02d.%02d.%d", c.day ?? 1, c.month ?? 1, c.year ?? 2026)
}

/// Measurements needed and confirmed, net wall area and how many rooms it covers (prototype pcStats).
struct ProjectStats { var need = 0, conf = 0; var net: Int64 = 0; var nets = 0 }

func stats(_ p: Project, snap: Bool = AppSettings.shared.angleSnap) -> ProjectStats {
    var s = ProjectStats()
    for r in p.rooms {
        let ks = Geo.stepKeys(r, snap); s.need += ks.count; s.conf += ks.filter { r.dim($0).status == "conf" }.count
        if let n = Geo.areas(r, snap)?.net { s.net += n; s.nets += 1 }
    }
    return s
}

/// Net wall area of one workspace's rooms, and how many rooms have it.
func wsNet(_ p: Project, _ w: Workspace, snap: Bool = AppSettings.shared.angleSnap) -> (Int64, Int) {
    var net: Int64 = 0, n = 0
    for r in p.rooms where r.floorId == w.id { if let a = Geo.areas(r, snap)?.net { net += a; n += 1 } }
    return (net, n)
}

/// New project, as the prototype's saveProject(): no workspace yet, currency and report language from Profile.
func newProject(_ name: String, _ customer: String, _ phone: String, _ address: String, _ loc: Location?, _ currency: String, _ reportLang: String) -> Project {
    let now = nowMs()
    return Project(id: uid(), name: name, customer: customer, phone: phone, address: address, location: loc, currency: currency, reportLang: reportLang, created: now, edited: now)
}

/// Every room of p with its workspace, workspace by workspace: each workspace's rooms, not only its first (the trades' next step).
func roomsByWorkspace(_ p: Project) -> [(Workspace, Room)] {
    p.floors.flatMap { w in p.rooms.filter { $0.floorId == w.id }.map { (w, $0) } }
}

extension Array {
    /// x put back at index at (an Undo of one delete: only that item comes back, the other changes since stay).
    func putBack(_ x: Element, at: Int) -> [Element] {
        var out = self
        out.insert(x, at: Swift.min(Swift.max(0, at), out.count))
        return out
    }
}
