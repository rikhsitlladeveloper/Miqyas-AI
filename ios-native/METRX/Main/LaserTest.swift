import SwiftUI
import UIKit
import CoreBluetooth
import Observation

/*
 * Device sheet → "Lazer sinovi" (Android ui/main/LaserTest.kt): a tool to learn how a Bluetooth laser rangefinder talks
 * (the ZB-08 was decoded with the Android one; the app's own support is Laser/RealLaser.swift, which steps aside while
 * this page is open).
 *
 * iPhone apps get Bluetooth LE only (CoreBluetooth): classic Bluetooth (SPP) is not open to them, so that half of the
 * Android page is not here, and the page says so. It scans with no filter, lists what a device advertises, connects,
 * lists the services, characteristics and descriptors, and ONLY READS: it reads readable values, and the one thing it
 * ever asks of the device is setNotifyValue(true) (notifications on). Every log line also goes to the device console.
 */

private let LT_SCAN_S = 20

/// Reading the bytes a laser sends: hex, ASCII, and candidate distances (pure, unit-tested).
enum LaserDecode {
    static func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02X", $0) }.joined(separator: " ") }

    static func ascii(_ b: [UInt8]) -> String {
        String(b.map { (c: UInt8) -> Character in c >= 0x20 && c <= 0x7E ? Character(UnicodeScalar(c)) : "." })
    }

    /// The FNIRSI IR40 rule: big-endian uint16 at offset 14, in mm. Not proven for the ZB-08.
    static func fnirsi(_ b: [UInt8]) -> Double? {
        guard b.count >= 16 else { return nil }
        let v = (Int(b[14]) << 8) | Int(b[15])
        return Double(v) / 1000
    }

    private static let num = try! NSRegularExpression(pattern: #"(-?\d+(?:[.,]\d+)?)\s*(mm|cm|m|ft|in|")?"#, options: [.caseInsensitive])

    /// Numbers in text like "1.234m", "1234mm", "D=1.234": "1.234m = 1.234 m". Empty for data that is mostly not text.
    static func textNumbers(_ b: [UInt8]) -> [String] {
        if b.isEmpty { return [] }
        let printable = b.filter { (c: UInt8) -> Bool in (c >= 0x20 && c <= 0x7E) || c == 0x0D || c == 0x0A }.count
        if printable * 10 < b.count * 6 { return [] }
        let s = String(b.map { (c: UInt8) -> Character in c >= 0x20 && c <= 0x7E ? Character(UnicodeScalar(c)) : " " })
        let ns = s as NSString
        var out: [String] = []
        for m in num.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            let numText = ns.substring(with: m.range(at: 1))
            let ur = m.range(at: 2)
            let unit = ur.location == NSNotFound ? "" : ns.substring(with: ur).lowercased()
            guard let v = Double(numText.replacingOccurrences(of: ",", with: ".")) else { continue }
            // a bare whole number with no unit is too vague to call a distance
            if unit.isEmpty && !numText.contains(".") && !numText.contains(",") { continue }
            let metres: Double
            switch unit {
            case "mm": metres = v / 1000
            case "cm": metres = v / 100
            case "ft": metres = v * 0.3048
            case "in", "\"": metres = v * 0.0254
            default: metres = v
            }
            let whole = ns.substring(with: m.range).trimmingCharacters(in: .whitespaces)
            out.append(whole + " = " + String(format: "%.3f m", metres))
        }
        return out
    }

    /// 0x2A00 for a Bluetooth base UUID, the full UUID otherwise, with a known name.
    static func uuid(_ text: String) -> String {
        let s = text.lowercased()
        let base = "-0000-1000-8000-00805f9b34fb"
        let short: String
        if s.count == 4 { short = "0x" + s.uppercased() }
        else if s.count == 36 && s.hasPrefix("0000") && s.hasSuffix(base) {
            let a = s.index(s.startIndex, offsetBy: 4), b = s.index(s.startIndex, offsetBy: 8)
            short = "0x" + s[a..<b].uppercased()
        } else { short = s }
        return known[short].map { short + " (" + $0 + ")" } ?? short
    }

    static func uuid(_ u: CBUUID) -> String { uuid(u.uuidString) }

    private static let known: [String: String] = [
        "0x1800": "Generic Access", "0x1801": "Generic Attribute", "0x180A": "Device Information", "0x180F": "Battery",
        "0x1812": "HID", "0x1101": "Serial Port (SPP)", "0x2A00": "Device Name", "0x2A01": "Appearance",
        "0x2A04": "Conn. Parameters", "0x2A05": "Service Changed", "0x2A19": "Battery Level", "0x2A23": "System ID",
        "0x2A24": "Model Number", "0x2A25": "Serial Number", "0x2A26": "Firmware Rev", "0x2A27": "Hardware Rev",
        "0x2A28": "Software Rev", "0x2A29": "Manufacturer", "0x2A50": "PnP ID", "0x2902": "CCCD", "0x2901": "User Description",
        "0xFFE0": "HM-10 style UART service", "0xFFE1": "HM-10 style UART data", "0xFFF0": "vendor UART service",
        "0xEE01": "FNIRSI-like service", "0xEE02": "FNIRSI-like notify", "0xEE03": "FNIRSI-like write",
        "6e400001-b5a3-f393-e0a9-e50e24dcca9e": "Nordic UART service", "6e400002-b5a3-f393-e0a9-e50e24dcca9e": "Nordic UART RX",
        "6e400003-b5a3-f393-e0a9-e50e24dcca9e": "Nordic UART TX",
        "0783b03e-8535-b5a0-7140-a304d2495cb7": "Dialog SPS service", "0783b03e-8535-b5a0-7140-a304d2495cb8": "SPS TX (notify)",
        "0783b03e-8535-b5a0-7140-a304d2495cb9": "SPS flow control", "0783b03e-8535-b5a0-7140-a304d2495cba": "SPS RX (write)"
    ]

    static func props(_ p: CBCharacteristicProperties) -> String {
        let all: [(CBCharacteristicProperties, String)] = [
            (.broadcast, "BROADCAST"), (.read, "READ"), (.writeWithoutResponse, "WRITE_NO_RESP"), (.write, "WRITE"),
            (.notify, "NOTIFY"), (.indicate, "INDICATE"), (.authenticatedSignedWrites, "SIGNED_WRITE"), (.extendedProperties, "EXT_PROPS")
        ]
        let names = all.filter { p.contains($0.0) }.map { $0.1 }
        return (names.isEmpty ? "none" : names.joined(separator: ",")) + String(format: " (0x%02X)", UInt32(truncatingIfNeeded: p.rawValue))
    }
}

/// A device seen by the scan.
struct LtDev: Identifiable {
    let id: UUID
    var name: String?
    var rssi: Int?
    var uuids: [String] = []
    var mfr: String? = nil
    var svcData: String? = nil
    var connectable: Bool? = nil
    var tx: Int? = nil
    var zb: Bool { name?.uppercased().contains("ZB") == true }
}

enum LtConn { case idle, connecting, connected }

/// Scanning, connecting and logging; its own central manager on the main queue.
@Observable
final class LaserProbe: LzBleOwner {
    private(set) var devices: [UUID: LtDev] = [:]
    private(set) var scanning = false
    private(set) var scanLeft = 0
    private(set) var conn: LtConn = .idle
    private(set) var connId: UUID? = nil
    private(set) var services: [String] = []
    private(set) var last: String? = nil
    private(set) var bt: LzBt = .unknown

    @ObservationIgnored private var cm: CBCentralManager? = nil
    @ObservationIgnored private var proxy: LzBleProxy? = nil
    @ObservationIgnored private var periph: CBPeripheral? = nil
    @ObservationIgnored private var known: [UUID: CBPeripheral] = [:]
    @ObservationIgnored private var lastAdv: [UUID: String] = [:]
    @ObservationIgnored private var pendingScan = false
    @ObservationIgnored private var tickWork: DispatchWorkItem? = nil
    @ObservationIgnored private var opWork: DispatchWorkItem? = nil
    @ObservationIgnored private var listWork: DispatchWorkItem? = nil
    /// No "connected" within 10 s: the try is given up (iOS itself would wait for ever).
    @ObservationIgnored private var connWork: DispatchWorkItem? = nil
    @ObservationIgnored private let jrt = JrtParser()
    @ObservationIgnored private let timeFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HH:mm:ss"; return f
    }()

    private enum Op {
        case read(CBCharacteristic)
        case readDesc(CBDescriptor)
        case notify(CBCharacteristic)
    }
    @ObservationIgnored private var ops: [Op] = []
    @ObservationIgnored private var cur: Op? = nil
    @ObservationIgnored private var nNotify = 0
    @ObservationIgnored private var pendingChars = 0
    @ObservationIgnored private var pendingDescs = 0
    @ObservationIgnored private var listed = false

    private func log(_ s: String) { LaserLog.add(s) }

    private func after(_ s: Double, _ f: @escaping () -> Void) -> DispatchWorkItem {
        let w = DispatchWorkItem(block: f)
        DispatchQueue.main.asyncAfter(deadline: .now() + s, execute: w)
        return w
    }

    // ---------- start / stop ----------

    func start() {
        log("===== METRX laser test: iPhone, " + ProcessInfo.processInfo.operatingSystemVersionString + " =====")
        log("classic Bluetooth (SPP) is not open to iPhone apps: Bluetooth LE only")
        bt = lzBtState(nil)
        // asked only once Bluetooth was allowed before; otherwise "Qidirish" asks
        if CBCentralManager.authorization == .allowedAlways { ensureManager() }
    }

    func dispose() {
        stopScan(quiet: true)
        disconnect()
        tickWork?.cancel(); opWork?.cancel(); listWork?.cancel(); connWork?.cancel()
        log("===== laser test page closed =====")
    }

    @discardableResult private func ensureManager() -> Bool {
        #if targetEnvironment(simulator)
        bt = .unsupported
        return false
        #else
        if cm != nil { return true }
        let p = LzBleProxy(self)
        proxy = p
        cm = CBCentralManager(delegate: p, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: false])
        return true
        #endif
    }

    func bleState(_ c: CBCentralManager) {
        guard c === cm else { return }
        bt = lzBtState(c)
        log("Bluetooth: \(bt) (authorization \(CBCentralManager.authorization.rawValue))")
        if bt == .on {
            if pendingScan { pendingScan = false; startScan() }
        } else {
            // off, resetting, not allowed: iOS has dropped every link and the peripherals it gave are no longer valid
            if bt != .unknown { pendingScan = false }
            stopScan(quiet: false)
            disconnect()
            known = [:]
        }
    }

    // ---------- scanning ----------

    func startScan() {
        if scanning { return }
        guard ensureManager(), let cm else { log("scan: no Bluetooth here"); return }
        if bt != .on {
            if bt == .unknown { pendingScan = true } else { log("scan: Bluetooth is \(bt)") }
            return
        }
        scanning = true
        scanLeft = LT_SCAN_S
        log("=== scan start: BLE, no filters, duplicates on, \(LT_SCAN_S) s ===")
        // devices this phone is connected to already (another app) do not advertise: they are listed too
        let linked = cm.retrieveConnectedPeripherals(withServices: [CBUUID(string: "1800"), CBUUID(string: "180A"), LzSps.service])
        for p in linked {
            known[p.identifier] = p
            var d = devices[p.identifier] ?? LtDev(id: p.identifier, name: p.name, rssi: nil)
            d.name = d.name ?? p.name
            devices[p.identifier] = d
            log("already connected to iOS: \(p.name ?? "—") \(p.identifier.uuidString)")
        }
        cm.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        tick()
    }

    private func tick() {
        tickWork = after(1) { [weak self] in
            guard let self, self.scanning else { return }
            self.scanLeft -= 1
            if self.scanLeft <= 0 { self.stopScan(quiet: false) } else { self.tick() }
        }
    }

    func stopScan(quiet: Bool = false) {
        tickWork?.cancel(); tickWork = nil
        if let cm, cm.state == .poweredOn, cm.isScanning { cm.stopScan() }
        guard scanning else { return }
        scanning = false; scanLeft = 0
        if !quiet {
            let zb = devices.values.filter { $0.zb }
            let list = zb.isEmpty ? "none" : zb.map { ($0.name ?? "—") + " " + $0.id.uuidString }.joined(separator: ", ")
            log("=== scan stop: \(devices.count) device(s); with \"ZB\" in the name: \(list) ===")
        }
    }

    func bleFound(_ p: CBPeripheral, _ adv: [String: Any], _ rssi: Int) {
        let id = p.identifier
        known[id] = p
        let name = (adv[CBAdvertisementDataLocalNameKey] as? String) ?? p.name
        let su = ((adv[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []).map { LaserDecode.uuid($0) }
        let ou = ((adv[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID]) ?? []).map { LaserDecode.uuid($0) + " (overflow)" }
        let mfr = (adv[CBAdvertisementDataManufacturerDataKey] as? Data).map { LaserDecode.hex([UInt8]($0)) }
        var sd: String? = nil
        if let m = adv[CBAdvertisementDataServiceDataKey] as? [CBUUID: Data], !m.isEmpty {
            sd = m.map { LaserDecode.uuid($0.key) + ": " + LaserDecode.hex([UInt8]($0.value)) }.joined(separator: "; ")
        }
        let cn = (adv[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue
        let tx = (adv[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue
        let old = devices[id]
        var d = old ?? LtDev(id: id, name: name, rssi: rssi)
        d.name = name ?? old?.name
        d.rssi = rssi
        d.uuids = Array(Set((old?.uuids ?? []) + su + ou)).sorted()
        d.mfr = mfr ?? old?.mfr
        d.svcData = sd ?? old?.svcData
        d.connectable = cn ?? old?.connectable
        d.tx = tx ?? old?.tx
        // what the advertising says, as one line (iOS gives the parts, not the raw bytes)
        let cnText = cn.map { $0 ? "yes" : "no" } ?? "?"
        let txText = tx.map { String($0) } ?? "?"
        let uuText = (su + ou).joined(separator: ", ")
        let mfrText: String = mfr ?? "—"
        let sdText: String = sd ?? "—"
        let parts: [String] = ["uuids=[\(uuText)]", "mfr=\(mfrText)", "svcData=\(sdText)", "connectable=\(cnText)", "tx=\(txText)"]
        let advText = parts.joined(separator: " ")
        let desc = "\(d.name ?? "—") \(id.uuidString) rssi=\(rssi) " + advText
        if old == nil {
            log("BLE found: " + desc)
        } else if name != nil && old?.name == nil {
            log("BLE name: " + desc)
        } else if (d.zb || id == connId) && lastAdv[id] != advText {
            // a ZB device's advertising may itself carry the reading: each change is logged
            log("BLE adv changed: \(d.name ?? "—") \(id.uuidString) rssi=\(rssi)\n    " + advText)
        }
        lastAdv[id] = advText
        // the list changes only when something worth showing does (the same device comes many times a second)
        if let old, old.name == d.name, old.uuids == d.uuids, old.mfr == d.mfr, abs((old.rssi ?? 0) - rssi) < 4 { return }
        devices[id] = d
    }

    // ---------- connecting ----------

    func connect(_ id: UUID) {
        guard let cm, cm.state == .poweredOn else { log("BLE: Bluetooth is not on (\(bt))"); return }
        guard let p = known[id] ?? cm.retrievePeripherals(withIdentifiers: [id]).first else { log("BLE: \(id.uuidString) is not known to iOS"); return }
        disconnect(); stopScan(quiet: false)
        conn = .connecting; connId = id; services = []; nNotify = 0; listed = false
        ops = []; cur = nil; jrt.reset()
        periph = p
        p.delegate = proxy
        log("=== BLE connect \(devices[id]?.name ?? p.name ?? "—") \(id.uuidString) ===")
        cm.connect(p, options: nil)
        connWork = after(10) { [weak self] in
            guard let self, self.conn == .connecting, self.periph === p else { return }
            self.log("GATT: no answer in 10 s; given up")
            self.disconnect()
        }
    }

    func bleConnected(_ p: CBPeripheral) {
        guard p === periph else { return }
        connWork?.cancel(); connWork = nil
        conn = .connected
        log("GATT: connected (iOS chooses the MTU: \(p.maximumWriteValueLength(for: .withoutResponse) + 3))")
        log("discovering services…")
        p.discoverServices(nil)
    }

    func bleFailed(_ p: CBPeripheral, _ e: Error?) {
        guard p === periph else { return }
        log("GATT: could not connect: \(e?.localizedDescription ?? "no reason")")
        endLink()
    }

    func bleGone(_ p: CBPeripheral, _ e: Error?) {
        guard p === periph else { return }
        log("GATT: disconnected (\(e?.localizedDescription ?? "no reason"))")
        endLink()
    }

    private func endLink() {
        opWork?.cancel(); listWork?.cancel(); connWork?.cancel(); ops = []; cur = nil
        periph = nil
        conn = .idle
    }

    func bleServices(_ p: CBPeripheral, _ e: Error?) {
        guard p === periph else { return }
        let ss = p.services ?? []
        log("services discovered: \(ss.count)\(lzErr(e))")
        pendingChars = ss.count; pendingDescs = 0
        for s in ss { p.discoverCharacteristics(nil, for: s) }
        // a device that never answers a discovery still gets its list
        listWork = after(8) { [weak self] in self?.listAll() }
        if ss.isEmpty { listAll() }
    }

    func bleChars(_ p: CBPeripheral, _ s: CBService, _ e: Error?) {
        guard p === periph else { return }
        if let e { log("  characteristics of \(LaserDecode.uuid(s.uuid)): \(e.localizedDescription)") }
        let cs = s.characteristics ?? []
        pendingDescs += cs.count
        for c in cs { p.discoverDescriptors(for: c) }
        pendingChars -= 1
        checkListed()
    }

    func bleDescs(_ p: CBPeripheral, _ c: CBCharacteristic, _ e: Error?) {
        guard p === periph else { return }
        pendingDescs -= 1
        checkListed()
    }

    private func checkListed() { if pendingChars <= 0 && pendingDescs <= 0 { listAll() } }

    /// The whole tree once found: logged and shown, then reads first, then notifications on.
    private func listAll() {
        guard !listed, let p = periph else { return }
        listed = true
        listWork?.cancel()
        var lines: [String] = []
        var reads: [Op] = []
        var notes: [Op] = []
        for s in p.services ?? [] {
            lines.append("SERVICE \(LaserDecode.uuid(s.uuid)) \(s.isPrimary ? "primary" : "secondary")")
            for c in s.characteristics ?? [] {
                lines.append("  CHAR \(LaserDecode.uuid(c.uuid)) [\(LaserDecode.props(c.properties))]")
                for d in c.descriptors ?? [] {
                    lines.append("    DESC \(LaserDecode.uuid(d.uuid))")
                    if d.uuid == CBUUID(string: "2901") { reads.append(.readDesc(d)) }
                }
                if c.properties.contains(.read) { reads.append(.read(c)) }
                if c.properties.contains(.notify) || c.properties.contains(.indicate) { notes.append(.notify(c)) }
            }
        }
        services = lines
        for l in lines { log(l) }
        ops = reads + notes
        log("reading \(reads.count) value(s), then turning on \(notes.count) notification(s)…")
        nextOp()
    }

    private func nextOp() {
        opWork?.cancel(); opWork = nil
        guard let p = periph else { cur = nil; return }
        guard !ops.isEmpty else {
            cur = nil
            log("=== ready: notifications on for \(nNotify) characteristic(s). Take a reading on the laser now. ===")
            return
        }
        let op = ops.removeFirst()
        cur = op
        switch op {
        case .read(let c): p.readValue(for: c)
        case .readDesc(let d): p.readValue(for: d)
        // the only thing this tool ever asks of a device: notifications (or indications) on
        case .notify(let c): log("  notifications on → \(LaserDecode.uuid(c.uuid))"); p.setNotifyValue(true, for: c)
        }
        opWork = after(4) { [weak self] in
            guard let self else { return }
            self.log("  (no answer in 4 s, next)")
            self.nextOp()
        }
    }

    func bleValue(_ p: CBPeripheral, _ c: CBCharacteristic, _ e: Error?) {
        guard p === periph else { return }
        let v = [UInt8](c.value ?? Data())
        if case .read(let rc)? = cur, rc === c {
            log("  READ \(LaserDecode.uuid(c.uuid))\(lzErr(e)) len=\(v.count) hex=[\(LaserDecode.hex(v))] ascii=\"\(LaserDecode.ascii(v))\"")
            nextOp()
            return
        }
        data("BLE " + LaserDecode.uuid(c.uuid), v)
    }

    func bleDescValue(_ p: CBPeripheral, _ d: CBDescriptor, _ e: Error?) {
        guard p === periph else { return }
        var text = d.value.map { "\($0)" } ?? "—"
        if let s = d.value as? String { text = "\"" + s + "\"" }
        else if let b = d.value as? Data { text = "hex=[" + LaserDecode.hex([UInt8](b)) + "]" }
        let of = d.characteristic.map { LaserDecode.uuid($0.uuid) } ?? "?"
        log("  READ desc \(LaserDecode.uuid(d.uuid)) of \(of)\(lzErr(e)): " + text)
        if case .readDesc(let rd)? = cur, rd === d { nextOp() }
    }

    func bleNotify(_ p: CBPeripheral, _ c: CBCharacteristic, _ e: Error?) {
        guard p === periph else { return }
        let ok = e == nil && c.isNotifying
        if ok { nNotify += 1 }
        log("  notify \(LaserDecode.uuid(c.uuid)): " + (ok ? "on" : "FAILED") + lzErr(e))
        if case .notify(let nc)? = cur, nc === c { nextOp() }
    }

    /// A notification: logged with every decoding that might be a distance.
    private func data(_ src: String, _ b: [UInt8]) {
        var s = "DATA \(src) len=\(b.count)\n    hex:   \(LaserDecode.hex(b))\n    ascii: \"\(LaserDecode.ascii(b))\""
        var guesses: [String] = []
        // the ZB-08's JRT frames (Laser/LaserJrt.swift), as the app itself reads them
        for ev in jrt.feed(b, now: lzUptimeMs()) {
            if case .reading(let mm, let q, _) = ev { guesses.append("JRT result = \(mm) mm (q \(q))") }
        }
        if let f = LaserDecode.fnirsi(b) { guesses.append("FNIRSI rule (BE u16 @14 /1000) = " + String(format: "%.3f m", f)) }
        for t in LaserDecode.textNumbers(b) { guesses.append("text: " + t) }
        for g in guesses { s += "\n    → " + g }
        log(s)
        if !guesses.isEmpty { last = timeFmt.string(from: Date()) + "  " + guesses.joined(separator: "  |  ") }
    }

    // ---------- disconnect ----------

    func disconnect() {
        opWork?.cancel(); listWork?.cancel(); connWork?.cancel(); ops = []; cur = nil
        // with Bluetooth not on iOS has dropped the link already (cancelling then is an API misuse)
        if let p = periph, let cm, cm.state == .poweredOn {
            log("BLE: disconnect")
            cm.cancelPeripheralConnection(p)
        }
        periph = nil
        conn = .idle
    }
}

/// Writes the whole log to Documents/laser/ (kept in the app's files) and returns the file.
func lzSaveLog() -> URL? {
    let text = LaserLog.shared.text()
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyyMMdd-HHmmss"
    let name = "laser-" + f.string(from: Date()) + ".txt"
    guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
    let dir = docs.appendingPathComponent("laser", isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name)
        try (text + "\n").write(to: url, atomically: true, encoding: .utf8)
        LaserLog.add("log saved: " + url.path)
        return url
    } catch {
        LaserLog.add("log not saved: \(error.localizedDescription)")
        return nil
    }
}

struct LaserTestScreen: View {
    let app: AppModel
    @State private var probe = LaserProbe()
    @State private var sel: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                GlassIconButton("back", tr("nt.back")) { app.pop() }.accessibilityIdentifier("back")
                T(tr("lt.row"), ui(17, 700), lines: 1).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14).frame(height: 64)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    T(tr("lt.intro"), ui(14, 400, G.ink2, lh: 1.45))
                    HStack(alignment: .top, spacing: 8) {
                        MIcon("info", G.ink2, 18, 2)
                        T(tr("nt.ltIos"), ui(13, 400, G.ink2, lh: 1.4)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    notice
                    scanButton
                    deviceList
                    connCard
                    if !probe.services.isEmpty {
                        T(tr("lt.services"), ui(13, 600, G.ink2)).padding(.top, 4)
                        Text(probe.services.joined(separator: "\n")).st(mono(10.5, 500, G.ink)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(10)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.solid))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
                    }
                    logBox
                }
                .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 24)
            }
        }
        // the app's own laser connection steps aside while this page has Bluetooth, and comes back after
        .onAppear { RealLaser.shared.pause(); probe.start() }
        .onDisappear { probe.dispose(); RealLaser.shared.resume() }
    }

    @ViewBuilder private var notice: some View {
        switch probe.bt {
        case .unsupported: LaserNotice(text: tr("lt.noBt"))
        case .off:
            LaserNotice(text: tr("lt.btOff")) { GlassButton(tr("dv.openSettings"), primary: false, icon: "bt") { lzOpenSettings() } }
        case .unauthorized:
            LaserNotice(text: tr("dv.deniedBody")) { GlassButton(tr("dv.openSettings"), primary: false) { lzOpenSettings() } }
        default: EmptyView()
        }
    }

    @ViewBuilder private var scanButton: some View {
        if probe.scanning {
            GlassButton(tr("lt.stop") + " · " + tr("lt.scanning", ["s": probe.scanLeft]), primary: false, icon: "search") { probe.stopScan() }
        } else {
            let can = probe.bt == .on || probe.bt == .unknown
            GlassButton(tr("lt.scan"), icon: "search") { if can { probe.startScan() } }
                .opacity(can ? 1 : 0.45)
                .accessibilityIdentifier("lt.scan")
        }
    }

    /// The devices, strongest first; a name with "ZB" stands out.
    @ViewBuilder private var deviceList: some View {
        let list = probe.devices.values.sorted { a, b in
            let ra = a.rssi ?? Int.min, rb = b.rssi ?? Int.min
            return ra != rb ? ra > rb : a.id.uuidString < b.id.uuidString
        }
        T(tr("lt.devices", ["n": list.count]), ui(13, 600, G.ink2)).padding(.top, 4)
        if list.isEmpty { T(tr("lt.none"), ui(13, 400, G.ink3)) }
        ForEach(Array(list.prefix(80))) { d in
            LtDeviceCard(d: d, open: sel == d.id, canConnect: probe.conn == .idle,
                         onTap: { sel = sel == d.id ? nil : d.id }, onConnect: { probe.connect(d.id) })
        }
    }

    @ViewBuilder private var connCard: some View {
        if probe.conn != .idle || probe.connId != nil {
            let st = probe.conn == .idle ? "lt.st.idle" : probe.conn == .connecting ? "lt.st.connecting" : "lt.st.connected"
            VStack(alignment: .leading, spacing: 8) {
                T(tr(st) + " · BLE", ui(15, 700, probe.conn == .connected ? G.green : G.ink))
                if let id = probe.connId {
                    T((probe.devices[id]?.name ?? "—") + "  " + id.uuidString, mono(12, 500, G.ink2))
                }
                if let l = probe.last {
                    T(tr("lt.last"), ui(12, 600, G.ink3))
                    Text(l).st(mono(13, 600, G.cobalt)).textSelection(.enabled)
                }
                if probe.conn != .idle { GlassButton(tr("lt.disconnect"), primary: false) { probe.disconnect() } }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(RoundedRectangle(cornerRadius: 18, style: .continuous), fill: G.glass(0.55))
        }
    }

    /// The log: newest at the bottom, selectable; copy, clear, save to a file (and share it).
    @ViewBuilder private var logBox: some View {
        let lg = LaserLog.shared
        T(tr("lt.log") + " (\(lg.lines.count))", ui(13, 600, G.ink2)).padding(.top, 4)
        HStack(spacing: 8) {
            LtSmallBtn(label: tr("lt.copy"), icon: "copy") {
                UIPasteboard.general.string = lg.text()
                app.say("lt.copied")
            }
            LtSmallBtn(label: tr("lt.clear"), icon: "trash") { lg.clear() }
            LtSmallBtn(label: tr("lt.save"), icon: "save") {
                if let url = lzSaveLog() {
                    app.say("lt.saved", ["f": "laser/" + url.lastPathComponent])
                    presentShare(url)
                } else {
                    app.say("lt.saveFail", kind: .error)
                }
            }
            .layoutPriority(1)
        }
        let shown = lg.lines.suffix(400).joined(separator: "\n")
        ScrollViewReader { sr in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(shown.isEmpty ? "—" : shown).st(mono(10.5, 500, G.ink)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Color.clear.frame(height: 1).id("lt.end")
                }
                .padding(10)
            }
            .frame(height: 380)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.solid))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(G.rim, lineWidth: 1))
            .onChange(of: lg.lines.count) { _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { sr.scrollTo("lt.end", anchor: .bottom) }
            }
        }
    }
}

private struct LtSmallBtn: View {
    let label: String
    let icon: String
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        HStack(spacing: 6) {
            MIcon(icon, G.ink, 16, 2)
            T(label, ui(12.5, 600), lines: 1)
        }
        .padding(.horizontal, 8).frame(maxWidth: .infinity, minHeight: 40)
        .background(shape.fill(G.glass(0.6)))
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .pressable(0.97, label: label, action)
    }
}

private struct LtDeviceCard: View {
    let d: LtDev
    let open: Bool
    let canConnect: Bool
    let onTap: () -> Void
    let onConnect: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                MIcon(d.zb ? "laser" : "bt", d.zb ? G.cobalt : G.ink2, 20, 2)
                T(d.name ?? "—", ui(15, 700, d.zb ? G.cobalt : G.ink), lines: 1).frame(maxWidth: .infinity, alignment: .leading)
                T(d.rssi.map { "\($0) dBm" } ?? "", mono(12, 600, G.ink2))
            }
            T(d.id.uuidString, mono(11, 500, G.ink2), lines: 1)
            if !d.uuids.isEmpty { T("uuids: " + d.uuids.joined(separator: ", "), mono(10.5, 500, G.ink3)) }
            if let m = d.mfr { T("mfr: " + m, mono(10.5, 500, G.ink3)) }
            if let s = d.svcData { T("svc: " + s, mono(10.5, 500, G.ink3)) }
            if open {
                if let c = d.connectable { T("connectable: \(c)" + (d.tx.map { " · tx \($0) dBm" } ?? ""), mono(10.5, 500, G.ink3)) }
                GlassButton(tr("lt.connLe")) { if canConnect { onConnect() } }
                    .opacity(canConnect ? 1 : 0.45)
                    .padding(.top, 6)
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(d.zb ? G.blueWash : G.glass(0.55)))
        .overlay(shape.strokeBorder(d.zb ? G.cobalt : G.rim, lineWidth: d.zb ? 2 : 1))
        .pressable(0.99, label: d.name ?? d.id.uuidString, onTap)
    }
}
