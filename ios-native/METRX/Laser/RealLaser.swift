import Foundation
import CoreBluetooth
import Observation

/*
 * The real ZB-08 laser over Bluetooth LE, app-wide (one for the whole app, so it outlives screens and sheets);
 * Android laser/RealLaser.kt with CoreBluetooth.
 *
 * GATT: the Dialog SPS service; the laser's measurements come as notifications on its TX characteristic (…cb8) as JRT
 * frames (LaserJrt.swift). The ONLY thing ever asked of the laser is setNotifyValue(true) (on TX, and on flow control
 * …cb9, as the working Android test did): iOS writes the notification switch itself. No commands: the builder measures
 * with the laser's own button. iPhone apps see no Bluetooth addresses, so the last laser is remembered by the identifier
 * iOS gives it (Settings laserId); it is connected again by itself when the app starts, after the link drops and when
 * Bluetooth comes back on, with a growing pause between tries.
 *
 * The central manager works on the main queue: every callback and every state change here is on the main thread. It is
 * made only when needed (a remembered laser, "Qidirish" or "Ulash"), so iOS asks for Bluetooth only then.
 */

enum LzLink { case idle, connecting, connected }

/// A device the scan saw: laser when its name starts with "ZB" or it shows the SPS service.
struct LzFound: Identifiable, Equatable {
    let id: UUID
    var name: String?
    var rssi: Int
    var laser: Bool
}

/// One measurement from the real laser.
struct LaserReading {
    let mm: Int
    let quality: Int
    let ts: Int64
}

@Observable
final class RealLaser: LzBleOwner {
    static let shared = RealLaser()
    static let scanS = 15
    private static let connectS = 20.0
    private static let backoffS: [Double] = [2, 4, 8, 15, 30, 45, 60]

    private(set) var link: LzLink = .idle
    private(set) var linkId: UUID? = nil
    private(set) var linkName: String? = nil
    /// The connecting now going on was asked for in the Device sheet (not a reconnect in the background).
    private(set) var userConnect = false
    private(set) var scanning = false
    private(set) var scanLeft = 0
    /// True once a scan ran to its end (the sheet then says when no laser was found).
    private(set) var scanned = false
    private(set) var found: [UUID: LzFound] = [:]
    /// When the next reconnect try is planned, nil when none is.
    private(set) var retryAt: Date? = nil
    /// "Uzish" was pressed: no reconnect by itself until the app starts again or "Ulash" is pressed.
    private(set) var stopped = false
    /// The last thing that went wrong, as a string key (lz.failed, lz.notLaser, lz.scanFail), cleared by the next try.
    private(set) var problem: String? = nil
    /// The "Lazer sinovi" page has Bluetooth to itself.
    private(set) var paused = false
    /// Bluetooth on this phone: on, off, not allowed for the app, none (the simulator).
    private(set) var bt: LzBt = .unknown

    /// Each measurement; set by the app (LaserRouter).
    @ObservationIgnored var onReading: ((LaserReading) -> Void)? = nil
    /// "connected" (with the name) or "lost": said to the builder by the app.
    @ObservationIgnored var onEvent: ((String, String?, Bool) -> Void)? = nil

    @ObservationIgnored private var cm: CBCentralManager? = nil
    @ObservationIgnored private var proxy: LzBleProxy? = nil
    @ObservationIgnored private var periph: CBPeripheral? = nil
    /// Peripherals the scan saw: iOS connects only to one the app keeps.
    @ObservationIgnored private var known: [UUID: CBPeripheral] = [:]
    @ObservationIgnored private let parser = JrtParser()
    @ObservationIgnored private var attempt = 0
    @ObservationIgnored private var started = false
    /// Asked for before Bluetooth said it is on (the manager was just made): done once it is.
    @ObservationIgnored private var pendingScan = false
    @ObservationIgnored private var pendingConnect: (UUID, String?)? = nil
    @ObservationIgnored private var retryWork: DispatchWorkItem? = nil
    @ObservationIgnored private var tickWork: DispatchWorkItem? = nil
    @ObservationIgnored private var connectWork: DispatchWorkItem? = nil

    var connected: Bool { link == .connected }
    var savedId: UUID? { AppSettings.shared.laserId.flatMap { UUID(uuidString: $0) } }
    var savedName: String? { AppSettings.shared.laserName }

    private func log(_ s: String) { LaserLog.add(s) }

    private func after(_ s: Double, _ f: @escaping () -> Void) -> DispatchWorkItem {
        let w = DispatchWorkItem(block: f)
        DispatchQueue.main.asyncAfter(deadline: .now() + s, execute: w)
        return w
    }

    // ---------- start ----------

    /// Called once when the app starts: a remembered laser is tried (Bluetooth was allowed when it was connected).
    func attach() {
        if started { return }
        started = true
        bt = lzBtState(nil)
        if let id = savedId {
            log("start: remembered laser \(savedName ?? "—") \(id.uuidString)")
            attempt = 0
            ensureManager()
        }
    }

    /// Makes the central manager (iOS asks for Bluetooth the first time). False where there is no Bluetooth.
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
        let was = bt
        bt = lzBtState(c)
        log("Bluetooth: \(bt)")
        if bt == .on {
            if was != .on { attempt = 0 }
            if pendingScan { pendingScan = false; startScan() }
            else if let pc = pendingConnect { pendingConnect = nil; connect(pc.0, pc.1) }
            else { plan(was == .unknown ? 0.3 : 0.8) }
        } else if bt != .unknown {
            pendingScan = false; pendingConnect = nil
            log("Bluetooth not on: link and scan stop")
            stopScan()
            drop(lost: link == .connected)
            cancelPlan()
        }
    }

    // ---------- reconnecting ----------

    private func cancelPlan() { retryWork?.cancel(); retryWork = nil; retryAt = nil }

    /// Plans the next try at the remembered laser: first seconds for the first one, then a growing pause.
    private func plan(_ first: Double? = nil) {
        cancelPlan()
        guard savedId != nil, !stopped, !paused, link == .idle, bt == .on else { return }
        let d = first ?? RealLaser.backoffS[min(attempt, RealLaser.backoffS.count - 1)]
        attempt += 1
        retryAt = Date().addingTimeInterval(d)
        retryWork = after(d) { [weak self] in
            guard let self else { return }
            self.retryWork = nil; self.retryAt = nil
            self.reconnectNow()
        }
    }

    private func reconnectNow() {
        guard let id = savedId, link == .idle, !stopped, !paused else { return }
        if scanning { plan(); return }
        connect(id, savedName, user: false)
    }

    /// The Device sheet was opened: an old scan's list and problem go; the remembered laser is tried at once.
    func opened() {
        if cm == nil {
            bt = lzBtState(nil)
            // Bluetooth already allowed: the real state (on or off) shows at once, without asking anything
            if CBCentralManager.authorization == .allowedAlways { ensureManager() }
        }
        if !scanning { found = [:]; scanned = false }
        if link == .idle { problem = nil }
        kick()
    }

    /// The remembered laser is tried at once (unless "Uzish" was pressed).
    func kick() {
        guard savedId != nil, !stopped, !paused, link == .idle else { return }
        attempt = 0
        plan(0)
    }

    // ---------- scanning ----------

    /// A 15 s scan with no service filter (the laser may not advertise SPS); lasers ("ZB…" or the SPS service) and
    /// other named devices are listed.
    func startScan() {
        if scanning || paused { return }
        guard ensureManager(), let cm else { return }
        if bt != .on {
            if bt == .unknown { pendingScan = true } else { log("scan: Bluetooth is \(bt)") }
            return
        }
        found = [:]; scanned = false; problem = nil
        cancelPlan()
        cm.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        scanning = true
        scanLeft = RealLaser.scanS
        log("=== laser scan: \(RealLaser.scanS) s ===")
        tick()
    }

    private func tick() {
        tickWork = after(1) { [weak self] in
            guard let self, self.scanning else { return }
            self.scanLeft -= 1
            if self.scanLeft <= 0 { self.stopScan(); self.scanned = true } else { self.tick() }
        }
    }

    func stopScan() {
        tickWork?.cancel(); tickWork = nil
        if let cm, cm.isScanning { cm.stopScan() }
        guard scanning else { return }
        scanning = false; scanLeft = 0
        let n = found.values.filter { $0.laser }.count
        log("=== laser scan stop: \(n) laser(s), \(found.count) device(s) ===")
        // a remembered laser is tried again after the scan
        if link == .idle { attempt = 0; plan(0.5) }
    }

    func bleFound(_ p: CBPeripheral, _ adv: [String: Any], _ rssi: Int) {
        guard scanning else { return }
        let name = (adv[CBAdvertisementDataLocalNameKey] as? String) ?? p.name
        let uuids = (adv[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        let sps = uuids.contains(LzSps.service)
        let zb = name?.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("ZB") == true
        let laser = sps || zb
        let blank = name?.trimmingCharacters(in: .whitespaces).isEmpty ?? true
        if blank && !laser { return }
        let id = p.identifier
        known[id] = p
        let old = found[id]
        let dev = LzFound(id: id, name: name ?? old?.name, rssi: rssi, laser: laser || old?.laser == true)
        // the same device is seen many times a second: the list changes only when something worth showing does
        if let old, old.name == dev.name, old.laser == dev.laser, abs(old.rssi - dev.rssi) < 4 { return }
        found[id] = dev
        if old == nil { log("found: \(name ?? "—") \(id.uuidString) rssi=\(rssi)\(laser ? " (laser)" : "")") }
    }

    // ---------- connecting ----------

    /// Connects to the laser id; user when picked in the sheet (only then is a failure said).
    func connect(_ id: UUID, _ name: String?, user: Bool = true) {
        if paused { return }
        if user { stopped = false; attempt = 0 }
        guard ensureManager(), let cm else { return }
        if bt != .on {
            if bt == .unknown && user { pendingConnect = (id, name) }
            return
        }
        stopScan(); cancelPlan(); close()
        let p = known[id] ?? cm.retrievePeripherals(withIdentifiers: [id]).first
        problem = nil; userConnect = user
        link = .connecting; linkId = id; linkName = name ?? found[id]?.name ?? p?.name
        parser.reset()
        log("=== connect \(linkName ?? "—") \(id.uuidString) (\(user ? "picked" : "reconnect")) ===")
        guard let p else { log("connect: iOS does not know this laser any more; search for it again"); fail("lz.failed"); return }
        known[id] = p
        periph = p
        p.delegate = proxy
        cm.connect(p, options: nil)
        connectWork = after(RealLaser.connectS) { [weak self] in
            guard let self, self.link == .connecting else { return }
            self.log("connect: no answer in \(Int(RealLaser.connectS)) s")
            self.fail("lz.failed")
        }
    }

    func bleConnected(_ p: CBPeripheral) {
        guard p === periph else { return }
        log("GATT: connected; discovering the SPS service")
        p.discoverServices([LzSps.service])
    }

    func bleFailed(_ p: CBPeripheral, _ e: Error?) {
        guard p === periph else { return }
        log("GATT: could not connect (\(e?.localizedDescription ?? "no reason"))")
        fail("lz.failed")
    }

    func bleGone(_ p: CBPeripheral, _ e: Error?) {
        guard p === periph else { return }
        log("GATT: disconnected (\(e?.localizedDescription ?? "no reason"))")
        if link == .connected { drop(lost: true) } else { fail("lz.failed") }
    }

    func bleServices(_ p: CBPeripheral, _ e: Error?) {
        guard p === periph else { return }
        let svc = p.services?.first { $0.uuid == LzSps.service }
        log("services: \(p.services?.count ?? 0); SPS \(svc != nil ? "found" : "MISSING")\(lzErr(e))")
        guard let svc else { fail("lz.notLaser"); return }
        p.discoverCharacteristics([LzSps.tx, LzSps.flow], for: svc)
    }

    func bleChars(_ p: CBPeripheral, _ s: CBService, _ e: Error?) {
        guard p === periph, s.uuid == LzSps.service else { return }
        let chars = s.characteristics ?? []
        let can: (CBCharacteristic) -> Bool = { $0.properties.contains(.notify) || $0.properties.contains(.indicate) }
        guard let tx = chars.first(where: { $0.uuid == LzSps.tx }), can(tx) else {
            log("SPS TX cannot notify")
            fail("lz.notLaser")
            return
        }
        // the only thing ever asked of the laser: notifications on (iOS writes the switch itself)
        p.setNotifyValue(true, for: tx)
        if let fl = chars.first(where: { $0.uuid == LzSps.flow }), can(fl) { p.setNotifyValue(true, for: fl) }
    }

    func bleNotify(_ p: CBPeripheral, _ c: CBCharacteristic, _ e: Error?) {
        guard p === periph else { return }
        let ok = e == nil && c.isNotifying
        log("  notifications on \(c.uuid == LzSps.tx ? "TX" : "flow"): \(ok ? "on" : "FAILED")\(lzErr(e))")
        guard c.uuid == LzSps.tx else { return }
        if ok { ready() } else { fail("lz.failed") }
    }

    func bleDescs(_ p: CBPeripheral, _ c: CBCharacteristic, _ e: Error?) {}
    func bleDescValue(_ p: CBPeripheral, _ d: CBDescriptor, _ e: Error?) {}

    private func ready() {
        connectWork?.cancel(); connectWork = nil
        guard let id = linkId, link == .connecting else { return }
        let name = linkName ?? savedName ?? "ZB-08"
        let user = userConnect
        link = .connected; linkName = name; attempt = 0; stopped = false; problem = nil; userConnect = false
        AppSettings.shared.setLaserDevice(id.uuidString, name)
        log("=== ready: \(name) \(id.uuidString); measure with the laser's own button ===")
        onEvent?("connected", name, user)
    }

    func bleValue(_ p: CBPeripheral, _ c: CBCharacteristic, _ e: Error?) {
        guard p === periph else { return }
        let b = [UInt8](c.value ?? Data())
        if c.uuid != LzSps.tx {
            log("data on \(c.uuid == LzSps.flow ? "flow" : c.uuid.uuidString): \(JrtParser.hex(b))")
            return
        }
        for ev in parser.feed(b, now: lzUptimeMs()) {
            switch ev {
            case .reading(let mm, let q, let hex):
                if mm <= 0 { log("JRT \(hex) → 0 mm (q \(q)): ignored"); continue }
                log("JRT \(hex) → \(mm) mm (q \(q))")
                onReading?(LaserReading(mm: mm, quality: q, ts: nowMs()))
            case .other(let reg, let hex): log("JRT \(hex) → register 0x" + String(format: "%04X", UInt32(truncatingIfNeeded: reg)) + ", not a reading: ignored")
            case .badChecksum(let hex): log("JRT \(hex) → bad checksum: ignored")
            case .skipped(let hex): log("JRT skipped bytes: \(hex)")
            }
        }
    }

    // ---------- ending ----------

    private func close() {
        connectWork?.cancel(); connectWork = nil
        if let p = periph, let cm, p.state != .disconnected { cm.cancelPeripheralConnection(p) }
        periph = nil
    }

    /// A try did not reach "ready": said only when the builder picked the laser; the remembered one is tried again later.
    private func fail(_ key: String) {
        let user = userConnect
        log("connect failed (\(key))")
        close()
        link = .idle; userConnect = false
        if user || key == "lz.notLaser" { problem = key }
        if key != "lz.notLaser" && linkId == savedId { plan() }
    }

    /// The link went away: lost when it was up (said to the builder), then the remembered laser is tried again.
    private func drop(lost: Bool) {
        close()
        let was = link
        link = .idle; userConnect = false
        if lost && was == .connected {
            log("=== link lost ===")
            onEvent?("lost", linkName, false)
            attempt = 0
            plan(1)
        }
    }

    /// "Uzish": disconnects and stops reconnecting by itself for now.
    func disconnect() {
        log("=== disconnect (Uzish) ===")
        stopped = true; cancelPlan(); close()
        link = .idle; userConnect = false
    }

    /// "Unutish": disconnects and forgets the laser.
    func forget() {
        log("=== forget \(savedName ?? "—") \(savedId?.uuidString ?? "") ===")
        cancelPlan(); close()
        link = .idle; userConnect = false; linkId = nil; linkName = nil; stopped = false; problem = nil
        AppSettings.shared.setLaserDevice(nil, nil)
    }

    /// The test page takes Bluetooth over (its own scan and connection); resume gives it back.
    func pause() {
        if paused { return }
        log("=== real laser paused for the test page ===")
        stopScan(); cancelPlan(); close()
        link = .idle; userConnect = false; paused = true
    }

    func resume() {
        if !paused { return }
        paused = false
        log("=== real laser resumed ===")
        attempt = 0
        plan(0.6)
    }
}
