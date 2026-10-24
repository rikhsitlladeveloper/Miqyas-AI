import Foundation
import CoreBluetooth
import Observation

/// The laser's log, shared by the real laser (RealLaser) and the "Lazer sinovi" page: kept while the app runs, every
/// line also in the device console (Console.app / Xcode, filter "METRX-LASER"). Android laser/LaserLog.kt.
@Observable
final class LaserLog {
    static let shared = LaserLog()
    private(set) var lines: [String] = []
    @ObservationIgnored private let fmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func add(_ msg: String) { shared.put(msg) }

    private func put(_ msg: String) {
        NSLog("METRX-LASER %@", msg)
        if Thread.isMainThread { append(msg) } else { DispatchQueue.main.async { self.append(msg) } }
    }

    private func append(_ msg: String) {
        lines.append(fmt.string(from: Date()) + "  " + msg)
        if lines.count > 6000 { lines.removeFirst(lines.count - 5000) }
    }

    func text() -> String { lines.joined(separator: "\n") }
    func clear() { lines.removeAll(); NSLog("METRX-LASER %@", "----- log cleared -----") }
}

/// Bluetooth on this phone, in the app's words (CBManagerState).
enum LzBt { case unknown, on, off, unauthorized, unsupported }

/// The Bluetooth state of a central manager; nil manager: what the app may know before making one.
func lzBtState(_ cm: CBCentralManager?) -> LzBt {
    #if targetEnvironment(simulator)
    return .unsupported
    #else
    guard let cm else {
        let a = CBCentralManager.authorization
        return a == .denied || a == .restricted ? .unauthorized : .unknown
    }
    switch cm.state {
    case .poweredOn: return .on
    case .poweredOff: return .off
    case .unauthorized: return .unauthorized
    case .unsupported: return .unsupported
    default: return .unknown
    }
    #endif
}

/// " (what went wrong)" for the log, or nothing.
func lzErr(_ e: Error?) -> String { e.map { " (" + $0.localizedDescription + ")" } ?? "" }

/// Milliseconds since the phone started (for the parser's stale half frames).
func lzUptimeMs() -> Int64 { Int64(ProcessInfo.processInfo.systemUptime * 1000) }

/// The ZB-08's Dialog SPS service: measurements come as notifications on TX (…cb8); flow control (…cb9) notifies too.
/// RX (…cba) is where commands would go: the app never writes to it.
enum LzSps {
    static let service = CBUUID(string: "0783B03E-8535-B5A0-7140-A304D2495CB7")
    static let tx = CBUUID(string: "0783B03E-8535-B5A0-7140-A304D2495CB8")
    static let flow = CBUUID(string: "0783B03E-8535-B5A0-7140-A304D2495CB9")
    static let rx = CBUUID(string: "0783B03E-8535-B5A0-7140-A304D2495CBA")
}

/// What a CoreBluetooth user gets told (the real laser and the test page each have one).
protocol LzBleOwner: AnyObject {
    func bleState(_ c: CBCentralManager)
    func bleFound(_ p: CBPeripheral, _ adv: [String: Any], _ rssi: Int)
    func bleConnected(_ p: CBPeripheral)
    func bleFailed(_ p: CBPeripheral, _ e: Error?)
    func bleGone(_ p: CBPeripheral, _ e: Error?)
    func bleServices(_ p: CBPeripheral, _ e: Error?)
    func bleChars(_ p: CBPeripheral, _ s: CBService, _ e: Error?)
    func bleDescs(_ p: CBPeripheral, _ c: CBCharacteristic, _ e: Error?)
    func bleValue(_ p: CBPeripheral, _ c: CBCharacteristic, _ e: Error?)
    func bleDescValue(_ p: CBPeripheral, _ d: CBDescriptor, _ e: Error?)
    func bleNotify(_ p: CBPeripheral, _ c: CBCharacteristic, _ e: Error?)
}

/// The CoreBluetooth delegate (an NSObject) that hands every callback to its owner. The managers here are made with
/// the main queue, so every callback comes on the main thread.
final class LzBleProxy: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    weak var owner: LzBleOwner?
    init(_ owner: LzBleOwner) { self.owner = owner; super.init() }

    func centralManagerDidUpdateState(_ central: CBCentralManager) { owner?.bleState(central) }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        owner?.bleFound(peripheral, advertisementData, RSSI.intValue)
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) { owner?.bleConnected(peripheral) }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) { owner?.bleFailed(peripheral, error) }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) { owner?.bleGone(peripheral, error) }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) { owner?.bleServices(peripheral, error) }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) { owner?.bleChars(peripheral, service, error) }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) { owner?.bleDescs(peripheral, characteristic, error) }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) { owner?.bleValue(peripheral, characteristic, error) }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) { owner?.bleDescValue(peripheral, descriptor, error) }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) { owner?.bleNotify(peripheral, characteristic, error) }
}
