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

/// A device the scan saw: laser when its name starts with "ZB" or it shows the SPS service. avg is the smoothed signal
/// (the radar's distance), seen when it was last heard (uptime ms).
struct LzFound: Identifiable, Equatable {
    let id: UUID
    var name: String?
    var rssi: Int
    var laser: Bool
    var avg: Double = -70
    var seen: Int64 = 0
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

    // ---- for the radar page (Main/LaserRadar.swift) ----
    /// The radar page is open: the link-lost countdown is its own (4 s) and background tries wait at most that long.
    @ObservationIgnored var radar = false
    /// Why the last try the builder asked for failed (cleared by the next try, "Qidiruvga" and the like).
    private(set) var failure: LaserFail? = nil
    private(set) var failId: UUID? = nil
    private(set) var failName: String? = nil
    /// +1 for every new failure (the page shakes, buzzes and draws the snapped line once per failure).
    private(set) var failSeq = 0
    /// Failed tries in a row at failId (3 → the help list); a ready link or another laser starts it again.
    private(set) var failStreak = 0
    /// +1 every time a ready link goes away.
    private(set) var lostSeq = 0
    /// How long the planned reconnect waits in all (s), for the countdown's progress bar.
    private(set) var retryTotal: Double = 0
    /// Devices that connected but had no SPS service this session: never drawn as lasers again.
    private(set) var incompatible: Set<UUID> = []

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
    /// No "connected" at all in LaserLinkRules.answerMs: the laser is off or too far.
    @ObservationIgnored private var answerWork: DispatchWorkItem? = nil
    @ObservationIgnored private var quickWork: DispatchWorkItem? = nil
    /// When this try's link said "connected" (uptime ms), 0 before.
    @ObservationIgnored private var gattUpAt: Int64 = 0
    /// Quick drops in this try (two → "busy").
    @ObservationIgnored private var quickDrops = 0
    /// The scan asked for before Bluetooth was on keeps the list.
    @ObservationIgnored private var pendingKeep = false
    /// Every advertisement's signal, smoothed (found is updated only when something worth showing changes).
    @ObservationIgnored private var avgs: [UUID: Double] = [:]

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
            if pendingScan { pendingScan = false; startScan(keep: pendingKeep) }
            else if let pc = pendingConnect { pendingConnect = nil; connect(pc.0, pc.1) }
            else if failure == .btOff, let fid = failId {
                // the try Bluetooth broke off goes on by itself ("Yoqilishi bilan ilova … ga o‘zi ulanadi")
                let n = failName
                _ = after(0.8) { [weak self] in
                    guard let self, self.link == .idle, self.failure == .btOff else { return }
                    self.connect(fid, n)
                }
            }
            else { plan(was == .unknown ? 0.3 : 0.8) }
        } else if bt != .unknown {
            pendingScan = false; pendingConnect = nil
            log("Bluetooth not on: link and scan stop")
            stopScan()
            // a try going on fails with its own reason (the radar page says "Bluetooth o‘chirildi")
            if link == .connecting {
                if bt == .unauthorized { fail("dv.deniedBody", .permission) } else { fail("lt.btOff", .btOff) }
            }
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
        // the radar page shows a failure card: nothing starts behind it until the builder picks what to do
        if radar && failure != nil { return }
        let d = first ?? Double(LaserLinkRules.backoffMs(attempt, radarOpen: radar)) / 1000
        attempt += 1
        retryAt = Date().addingTimeInterval(d)
        retryTotal = d
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
        if !scanning { found = [:]; avgs = [:]; scanned = false }
        if link == .idle { problem = nil }
        kick()
    }

    /// The radar page: the central manager is made now (iOS asks for Bluetooth the first time), so the page shows the
    /// real state at once.
    func prepare() {
        if cm == nil { bt = lzBtState(nil) }
        ensureManager()
    }

    /// The remembered laser is tried at once (unless "Uzish" was pressed).
    func kick() {
        guard savedId != nil, !stopped, !paused, link == .idle else { return }
        attempt = 0
        plan(0)
    }

    // ---------- scanning ----------

    /// A 15 s scan with no service filter (the laser may not advertise SPS); lasers ("ZB…" or the SPS service) and
    /// other named devices are listed. keep: the list is kept (the radar page starts scan after scan; a device not heard
    /// for a while leaves the radar by itself).
    func startScan(keep: Bool = false) {
        if scanning || paused { return }
        guard ensureManager(), let cm else { return }
        if bt != .on {
            if bt == .unknown { pendingScan = true; pendingKeep = keep } else { log("scan: Bluetooth is \(bt)") }
            return
        }
        if !keep { found = [:]; avgs = [:] }
        scanned = false; problem = nil
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
        let id = p.identifier
        let bad = incompatible.contains(id)
        let laser = (sps || zb) && !bad
        let blank = name?.trimmingCharacters(in: .whitespaces).isEmpty ?? true
        if blank && !laser { return }
        known[id] = p
        let old = found[id]
        // iOS gives 127 when it has no signal reading for this advertisement
        let heard = rssi < 0 && rssi > -127
        let r = heard ? rssi : (old?.rssi ?? -80)
        let avg = heard ? LaserRadarMath.smooth(avgs[id], rssi) : (avgs[id] ?? Double(r))
        avgs[id] = avg
        let now = lzUptimeMs()
        let wasLaser = old?.laser == true && !bad
        let dev = LzFound(id: id, name: name ?? old?.name, rssi: r, laser: laser || wasLaser, avg: avg, seen: now)
        // the same device is seen many times a second: the list changes only when something worth showing does (or once
        // a second, so the radar knows it is still there)
        if let old, old.name == dev.name, old.laser == dev.laser, abs(old.avg - dev.avg) < 1.5, now - old.seen < 1000 { return }
        found[id] = dev
        if old == nil { log("found: \(name ?? "—") \(id.uuidString) rssi=\(rssi)\(laser ? " (laser)" : "")") }
    }

    // ---------- connecting ----------

    /// Connects to the laser id; user when the builder picked it (only then is a failure said). again: the same try going
    /// on after a quick drop (the radar keeps its "Ulanmoqda" animation, the counts are kept).
    func connect(_ id: UUID, _ name: String?, user: Bool = true, again: Bool = false) {
        if paused { return }
        if user { stopped = false; attempt = 0 }
        if user && !again {
            if id != failId { failStreak = 0 }
            failure = nil
        }
        if !again { quickDrops = 0 }
        guard ensureManager(), let cm else { return }
        if bt == .unauthorized {
            // the radar page shows its permission card (the Settings button)
            userConnect = user; linkId = id; linkName = name ?? found[id]?.name ?? linkName
            log("connect: Bluetooth is not allowed for the app")
            fail("dv.deniedBody", .permission)
            return
        }
        if bt != .on {
            if bt == .unknown && user { pendingConnect = (id, name) }
            return
        }
        stopScan(); cancelPlan(); close()
        let p = known[id] ?? cm.retrievePeripherals(withIdentifiers: [id]).first
        problem = nil; userConnect = user
        link = .connecting; linkId = id; linkName = name ?? found[id]?.name ?? p?.name ?? linkName
        parser.reset(); gattUpAt = 0
        let how = again ? "again after a quick drop" : user ? "picked" : "reconnect"
        log("=== connect \(linkName ?? "—") \(id.uuidString) (\(how)) ===")
        guard let p else { log("connect: iOS does not know this laser any more; search for it again"); fail("lz.failed", .timeout); return }
        known[id] = p
        periph = p
        p.delegate = proxy
        cm.connect(p, options: nil)
        answerWork = after(Double(LaserLinkRules.answerMs) / 1000) { [weak self] in
            guard let self, self.link == .connecting, self.gattUpAt == 0 else { return }
            self.log("connect: no answer in \(LaserLinkRules.answerMs / 1000) s")
            self.fail("lz.failed", .timeout)
        }
        connectWork = after(RealLaser.connectS) { [weak self] in
            guard let self, self.link == .connecting else { return }
            self.log("connect: not ready in \(Int(RealLaser.connectS)) s")
            self.fail("lz.failed", .timeout)
        }
    }

    /// "Bekor qilish" while connecting: the try stops quietly; the remembered laser is not tried again by itself for now.
    func cancelConnect() {
        if link != .connecting { return }
        log("=== connect cancelled ===")
        if linkId == savedId { stopped = true }
        close(); cancelPlan()
        link = .idle; userConnect = false
    }

    /// The failure card was answered ("Qidiruvga", "Boshqa lazerni qidirish", "Keyinroq"): it goes; the count stays.
    func clearFailure() { failure = nil; problem = nil }

    /// A quick drop: tried once more by itself; the second in one try means another phone most likely holds the laser.
    private func quick(_ why: String) {
        quickDrops += 1
        log("quick drop #\(quickDrops) (\(why))")
        if LaserLinkRules.isBusy(quickDrops) { fail("lz.failed", .busy); return }
        if !userConnect { fail("lz.failed", .timeout); return }
        close()
        quickWork = after(Double(LaserLinkRules.quickRetryMs) / 1000) { [weak self] in
            guard let self, let id = self.linkId, self.link == .connecting else { return }
            self.connect(id, self.linkName, user: self.userConnect, again: true)
        }
    }

    func bleConnected(_ p: CBPeripheral) {
        guard p === periph else { return }
        answerWork?.cancel(); answerWork = nil
        gattUpAt = lzUptimeMs()
        log("GATT: connected; discovering the SPS service")
        p.discoverServices([LzSps.service])
    }

    /// iOS could not connect at all: the laser refused at once (counted like Android's 133 refusal).
    func bleFailed(_ p: CBPeripheral, _ e: Error?) {
        guard p === periph, link == .connecting else { return }
        log("GATT: could not connect (\(e?.localizedDescription ?? "no reason"))")
        quick("refused: " + (e?.localizedDescription ?? "no reason"))
    }

    func bleGone(_ p: CBPeripheral, _ e: Error?) {
        guard p === periph else { return }
        log("GATT: disconnected (\(e?.localizedDescription ?? "no reason"))")
        let up = gattUpAt > 0
        // iOS says "disconnected" only after "connected": one before is an old, cancelled try's
        if !up && link == .connecting { log("  (before this try connected: an old try's, ignored)"); return }
        let since: Int64 = up ? lzUptimeMs() - gattUpAt : -1
        switch LaserLinkRules.drop(status: 0, ready: link == .connected, gattUp: up, msSinceUp: since) {
        case .lost: drop(lost: true)
        case .quick: quick("dropped \(since) ms after connecting")
        case .noAnswer: fail("lz.failed", .timeout)
        }
    }

    func bleServices(_ p: CBPeripheral, _ e: Error?) {
        guard p === periph else { return }
        let svc = p.services?.first { $0.uuid == LzSps.service }
        log("services: \(p.services?.count ?? 0); SPS \(svc != nil ? "found" : "MISSING")\(lzErr(e))")
        guard let svc else { fail("lz.notLaser", .notLaser); return }
        p.discoverCharacteristics([LzSps.tx, LzSps.flow], for: svc)
    }

    func bleChars(_ p: CBPeripheral, _ s: CBService, _ e: Error?) {
        guard p === periph, s.uuid == LzSps.service else { return }
        let chars = s.characteristics ?? []
        let can: (CBCharacteristic) -> Bool = { $0.properties.contains(.notify) || $0.properties.contains(.indicate) }
        guard let tx = chars.first(where: { $0.uuid == LzSps.tx }), can(tx) else {
            log("SPS TX cannot notify")
            fail("lz.notLaser", .notLaser)
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
        if ok { ready() } else { fail("lz.failed", .timeout) }
    }

    func bleDescs(_ p: CBPeripheral, _ c: CBCharacteristic, _ e: Error?) {}
    func bleDescValue(_ p: CBPeripheral, _ d: CBDescriptor, _ e: Error?) {}

    private func ready() {
        connectWork?.cancel(); connectWork = nil
        guard let id = linkId, link == .connecting else { return }
        let name = linkName ?? savedName ?? "ZB-08"
        let user = userConnect
        link = .connected; linkName = name; attempt = 0; stopped = false; problem = nil; userConnect = false
        failure = nil; failStreak = 0; quickDrops = 0; incompatible.remove(id)
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
        answerWork?.cancel(); answerWork = nil
        quickWork?.cancel(); quickWork = nil
        // with Bluetooth off iOS has already dropped every link (cancelling then is an API misuse)
        if let p = periph, let cm, cm.state == .poweredOn, p.state != .disconnected { cm.cancelPeripheralConnection(p) }
        periph = nil
    }

    /// A try did not reach "ready": said only when the builder picked the laser (failure for the radar page, problem
    /// for the Device sheet); the remembered one is tried again later.
    private func fail(_ key: String, _ why: LaserFail) {
        let user = userConnect
        log("connect failed (\(key), \(why))")
        close()
        link = .idle; userConnect = false
        if why == .notLaser, let id = linkId {
            incompatible.insert(id)
            found[id]?.laser = false
        }
        if user || why == .notLaser {
            problem = key
            failId = linkId; failName = linkName; failStreak += 1; failure = why; failSeq += 1
        }
        if why != .notLaser && linkId == savedId { plan() }
    }

    /// The link went away: lost when it was up (said to the builder), then the remembered laser is tried again.
    private func drop(lost: Bool) {
        close()
        let was = link
        link = .idle; userConnect = false
        if lost && was == .connected {
            log("=== link lost ===")
            lostSeq += 1
            onEvent?("lost", linkName, false)
            attempt = 0
            // the radar page counts down 4 s before connecting again; elsewhere it goes after 1 s, with a toast
            plan(radar ? Double(LaserLinkRules.lostWaitMs) / 1000 : 1)
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
        failure = nil; failStreak = 0
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
