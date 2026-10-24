import SwiftUI
import UIKit

/// Opens this app's page in the iPhone's Settings (Bluetooth permission). iOS has no link to the Bluetooth switch itself.
@MainActor
func lzOpenSettings() {
    guard let u = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(u)
}

/// The measuring device (prototype SHEETS.device; Android ui/main/DeviceSheet.kt): the real ZB-08 over Bluetooth, and
/// the simulator for when there is none. "Qidirish" scans 15 s; lasers come first, other named devices under them; a
/// tap connects. The laser connected last is remembered and connected again by itself (opening this sheet tries it at
/// once); "Uzish" disconnects and stops that until the next start, "Unutish" forgets it. Typing values always works.
struct DeviceSheet: View {
    let app: AppModel

    private var rl: LaserRouter { LaserRouter.shared }
    private var real: RealLaser { RealLaser.shared }

    var body: some View {
        GlassSheet(tr("dv.title"), onClose: { app.sheet = nil }) {
            statusRow
            // what stands in the way of the real laser
            if !real.connected && !real.paused { notice }
            if let p = real.problem, !real.connected {
                HStack(alignment: .top, spacing: 8) {
                    MIcon("alert", G.err, 18, 2)
                    T(tr(p), ui(13.5, 500, G.err, lh: 1.4)).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            realCard
            if !real.connected { foundList }
            // the simulator, for trying the app without a laser (only while no real laser is connected)
            if !real.connected { simRow }
            HStack(alignment: .top, spacing: 8) { MIcon("kbd", G.ink2, 18, 2); T(tr("dv.always"), ui(13, 400, G.ink2, lh: 1.4)) }
            testRow
        } footer: {
            if real.connected {
                GlassButton(tr("dv.disconnect"), primary: false) { real.disconnect() }
            } else if real.scanning {
                GlassButton(tr("lt.stop") + " · " + tr("lt.scanning", ["s": real.scanLeft]), primary: false, icon: "search") { real.stopScan() }
            } else {
                GlassButton(tr("dv.search"), icon: "search") { search() }
            }
        }
        .onAppear { real.opened() }
    }

    private func search() {
        switch real.bt {
        case .unsupported: app.say("lt.noBt", kind: .info)
        case .unauthorized: lzOpenSettings()
        case .off: app.say("dv.offBody", kind: .info)
        default: real.startScan()
        }
    }

    private var statusRow: some View {
        let st: String = real.connected || rl.simOn ? "dev.conn" : real.scanning ? "dev.scan" : real.link == .connecting ? "lz.connecting" : "dev.disc"
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return HStack {
            T(tr("dv.status"), ui(14, 500, G.ink2)).frame(maxWidth: .infinity, alignment: .leading)
            T(tr(st), ui(14, 700, st == "dev.conn" ? G.green : G.ink))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(shape.fill(G.glass(0.6)))
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
    }

    @ViewBuilder private var notice: some View {
        switch real.bt {
        case .unsupported: LaserNotice(text: tr("lt.noBt"))
        case .off:
            LaserNotice(text: tr("dv.offBody")) {
                GlassButton(tr("dv.openSettings"), primary: false, icon: "bt") { lzOpenSettings() }
            }
        case .unauthorized:
            LaserNotice(text: tr("dv.deniedBody")) {
                GlassButton(tr("dv.openSettings"), primary: false) { lzOpenSettings() }
            }
        default: EmptyView()
        }
    }

    /// The real laser: connected, or the remembered one.
    @ViewBuilder private var realCard: some View {
        if real.connected {
            LzRealCard(name: real.linkName ?? "ZB-08", idText: lzShortId(real.linkId), line: tr("lz.press"), on: true) {
                forgetLink
            }
        } else if let sid = real.savedId, !real.paused {
            let connecting = real.link == .connecting && real.linkId == sid
            let line = connecting ? tr("lz.connecting") : real.stopped ? tr("lz.off") : tr("lz.retry")
            LzRealCard(name: real.savedName ?? "ZB-08", idText: lzShortId(sid), line: tr("lz.saved") + " · " + line, on: false) {
                if !connecting && (real.bt == .on || real.bt == .unknown) {
                    GBtn(tr("dv.connect"), height: 40, corner: 12, fontSize: 14, fill: false) { real.connect(sid, real.savedName) }
                }
                forgetLink
            }
        }
    }

    private var forgetLink: some View {
        T(tr("lz.forget"), ui(14, 600, G.err)).padding(.horizontal, 6).padding(.vertical, 10)
            .pressable(0.97, label: tr("lz.forget")) { real.forget(); app.say("lz.forgot") }
    }

    /// What the scan found: lasers first, then other named devices.
    @ViewBuilder private var foundList: some View {
        let all = Array(real.found.values)
        let lasers = all.filter { $0.laser }.sorted { $0.rssi > $1.rssi }
        let others = all.filter { !$0.laser }.sorted { $0.rssi > $1.rssi }
        let busy = real.link == .connecting
        let canTap = !busy && real.bt == .on
        if real.scanning || !all.isEmpty { T(tr("dv.found"), ui(13, 700, G.ink3)) }
        ForEach(lasers) { d in
            LzDevRow(d: d, connecting: busy && real.linkId == d.id, enabled: canTap) { real.connect(d.id, d.name) }
        }
        if real.scanned && !real.scanning && lasers.isEmpty { T(tr("lz.none"), ui(13.5, 500, G.ink2, lh: 1.4)) }
        if !others.isEmpty {
            T(tr("lz.others"), ui(13, 700, G.ink3)).padding(.top, 4)
            ForEach(Array(others.prefix(12))) { d in
                LzDevRow(d: d, connecting: busy && real.linkId == d.id, enabled: canTap) { real.connect(d.id, d.name) }
            }
        }
    }

    private var simRow: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(alignment: .leading, spacing: 8) {
            T(tr("lz.simHead"), ui(13, 700, G.ink3)).padding(.top, 4)
            HStack(spacing: 12) {
                MIcon("laser", G.cobalt, 24, 2)
                VStack(alignment: .leading, spacing: 1) {
                    T(tr("dv.simDev"), ui(15.5, 700))
                    T(tr("nt.simLaser"), ui(13, 500, G.amberInk, lh: 1.35))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if rl.simOn {
                    GBtn(tr("dv.disconnect"), kind: .secondary, height: 40, corner: 12, fontSize: 14, fill: false) { rl.setSim(false) }
                } else {
                    GBtn(tr("dv.connect"), height: 40, corner: 12, fontSize: 14, fill: false) {
                        rl.setSim(true); app.sheet = nil; app.say("dv.connected")
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(shape.fill(G.glass(0.6)))
            .overlay(shape.strokeBorder(rl.simOn ? G.green : G.rim, lineWidth: 1))
        }
    }

    /// A real laser's own signal, read only (Main/LaserTest.swift).
    private var testRow: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return HStack(spacing: 12) {
            MIcon("bt", G.cobalt, 22, 2)
            VStack(alignment: .leading, spacing: 1) {
                T(tr("lt.row"), ui(15, 700))
                T(tr("lt.rowSub"), ui(13, 400, G.ink2, lh: 1.35))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MIcon("chev", G.ink2, 18, 2)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(shape.fill(G.glass(0.6)))
        .overlay(shape.strokeBorder(G.rim, lineWidth: 1))
        .pressable(0.98, label: tr("lt.row")) { app.sheet = nil; app.push(.laserTest) }
        .accessibilityIdentifier("lt.row")
    }
}

/// The start of iOS's identifier for a device (iPhone apps see no Bluetooth addresses).
func lzShortId(_ id: UUID?) -> String { id.map { String($0.uuidString.prefix(8)) } ?? "" }

private struct LzRealCard<Actions: View>: View {
    let name: String
    let idText: String
    let line: String
    let on: Bool
    @ViewBuilder let actions: Actions
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                MIcon("laser", G.cobalt, 24, 2)
                VStack(alignment: .leading, spacing: 1) {
                    T(on ? tr("lz.connTo", ["n": name]) : name, ui(15.5, 700))
                    T(idText, mono(11.5, 500, G.ink2))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            T(line, ui(13, 500, on ? G.green : G.ink2, lh: 1.35))
            HStack(spacing: 12) { actions }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(G.blueWash))
        .overlay(shape.strokeBorder(G.cobalt, lineWidth: 2))
    }
}

private struct LzDevRow: View {
    let d: LzFound
    let connecting: Bool
    let enabled: Bool
    let onTap: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: 12) {
            MIcon(d.laser ? "laser" : "bt", d.laser ? G.cobalt : G.ink2, 22, 2)
            VStack(alignment: .leading, spacing: 1) {
                T(d.name ?? "—", ui(15, 700, d.laser ? G.cobalt : G.ink), lines: 1)
                T(lzShortId(d.id) + " · \(d.rssi) dBm", mono(11.5, 500, G.ink2), lines: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            T(tr(connecting ? "lz.connecting" : "dv.connect"), ui(14, 700, enabled || connecting ? G.cobalt : G.ink3))
        }
        .padding(.horizontal, 14).padding(.vertical, 10).frame(minHeight: 56)
        .background(shape.fill(d.laser ? G.blueWash : G.glass(0.55)))
        .overlay(shape.strokeBorder(d.laser ? G.cobalt : G.rim, lineWidth: d.laser ? 2 : 1))
        .pressable(0.98, label: d.name ?? lzShortId(d.id)) { if enabled { onTap() } }
    }
}

/// An amber notice with optional buttons (Bluetooth off, permission), as on the test page.
struct LaserNotice<Buttons: View>: View {
    let text: String
    @ViewBuilder let buttons: Buttons
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                MIcon("alert", G.amberInk, 20, 2)
                T(text, ui(14, 600, G.amberInk, lh: 1.4)).frame(maxWidth: .infinity, alignment: .leading)
            }
            buttons
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(G.amberWash))
    }
}

extension LaserNotice where Buttons == EmptyView {
    init(text: String) { self.init(text: text, buttons: { EmptyView() }) }
}
