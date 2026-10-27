import SwiftUI
import UIKit
import ModelIO

/*
 * "Mijozga 3D yuborish" (Joylan ideas, approved 26 Oct 2026; the mockup's share sheet; Android ui/furniture/
 * Client3DShare.kt): the sheet that picks the files and what goes in them (the price, the dimensions, the maker's
 * phone, kept as settings share3dPrice, share3dDims, share3dPhone), and the phone's share sheet with the files. No
 * server: the files are made on the phone (Core/Client3D.swift) and sent by Telegram, WhatsApp, AirDrop…
 *
 * The USDZ: the app writes its own USDA layer into the package (Core/Client3D.swift client3DUsdz), because that is the
 * one way that sets metres, Y up and a UsdPreviewSurface colour per look on every iOS 17 phone. ModelIO (MDLAsset
 * export to .usdz, Apple's own) is the fallback when that file cannot be written; RealityKit has no USD export on iOS 17.
 */

/// The client files' base name: the order's name, letters and digits only, and "_3D".
func c3FileBase(_ name: String) -> String {
    var s = ""
    for ch in name {
        if ch.isLetter || ch.isNumber { s.append(ch) } else if !s.hasSuffix("_") { s.append("_") }
    }
    while s.hasSuffix("_") { s.removeLast() }
    return (s.isEmpty ? "METRX" : String(s.prefix(40))) + "_3D"
}

/// What the order's HTML page says, in the order's report language, with what the maker allows in it.
func c3InfoFor(_ p: Project, _ s: AppSettings, rid: String?) -> C3Info {
    let l = Lang.of(p.reportLang), en = l == .en
    func t(_ k: String, _ v: [String: Any]? = nil) -> String { Strings.t(k, l, v) }
    let room = c3Room(p, rid)
    let fs = p.furniture.filter { !$0.modules.isEmpty && (room == nil ? $0.roomId == nil : $0.roomId == room?.id) }
    var info = C3Info()
    info.lang = l == .uzc ? "uz-Cyrl" : l.code
    info.title = dn(p.name, l)
    let names = fs.map { dn($0.name, l) }.joined(separator: ", ")
    info.line1 = names + (fs.isEmpty ? "" : " · " + t("sh3.units", ["n": akUnits(fs)]))
    if let r = room {
        let rn = p.floors.first { $0.id == r.floorId }.map { floorName($0, l) } ?? dn(r.name, l)
        let rs = Geo.roomSize(r, AppSettings.shared.angleSnap)
        let a = Geo.fmtLen(rs?.0, AppSettings.shared.unit, en), b = Geo.fmtLen(rs?.1, AppSettings.shared.unit, en)
        info.line2 = t("sh3.room", ["r": rn, "a": a, "b": b, "d": fmtDate(nowMs())])
    } else {
        info.line2 = fmtDate(nowMs())
    }
    if s.share3dPrice && s.advanced && !fs.isEmpty {
        let pr = priceOf(fs, p.fprice, s.workshop, s.mats, s.hws, remsOf(p))
        info.price = t("sh3.price", ["v": Money.str(pr.price, p.precision, en) + " " + Money.cur(p.currency, l)])
    }
    if !s.builderName.isEmpty { info.master = t("sh3.master", ["n": s.builderName]) }
    if s.share3dPhone && !s.builderPhone.isEmpty {
        info.phone = "+998" + Phone.digits(s.builderPhone)
        info.phoneShown = Phone.format(s.builderPhone)
        if info.master.isEmpty { info.master = t("sh3.master", ["n": ""]).trimmingCharacters(in: CharacterSet(charactersIn: " :,")) }
    }
    info.hint = t("sh3.hint")
    info.noGl = t("sh3.noGl")
    info.dims = s.share3dDims
    return info
}

/// The HTML of order p: the lit 3D's lighter boxes, the plainest when that is over C3_HTML_MAX. nil: nothing to show.
func client3DHtmlFor(_ p: Project, _ s: AppSettings, rid: String?) -> String? {
    let info = c3InfoFor(p, s, rid: rid)
    for d in [Quality3.low, .flat] {
        guard let sc = client3DScene(p, rid: rid, ws: s.workshop, mats: s.mats, snap: s.angleSnap, detail: d) else { return nil }
        let h = client3DHtml(sc, info)
        if h.utf8.count <= C3_HTML_MAX || d == .flat { return h }
    }
    return nil
}

/// ModelIO's USDZ of scene s at url (Apple's exporter): one mesh a colour, its material's base colour; false when this
/// phone's ModelIO cannot write USDZ or wrote nothing.
func c3ModelIO(_ s: C3Scene, _ url: URL) -> Bool {
    guard MDLAsset.canExportFileExtension("usdz") else { return false }
    let asset = MDLAsset()
    let alloc = MDLMeshBufferDataAllocator()
    for (i, m) in s.meshes.enumerated() {
        var verts: [Float] = [], idx: [UInt32] = []
        for (j, poly) in m.polys.enumerated() where poly.count >= 3 {
            let n = m.norms[j]
            let base = UInt32(verts.count / 6)
            for q0 in poly {
                let q = q0 - s.mid
                verts += [Float(q.x), Float(q.y), Float(q.z), Float(n.x), Float(n.y), Float(n.z)]
            }
            for k in 1..<(poly.count - 1) { idx += [base, base + UInt32(k), base + UInt32(k + 1)] }
        }
        if idx.isEmpty { continue }
        let vData = verts.withUnsafeBufferPointer { Data(buffer: $0) }
        let iData = idx.withUnsafeBufferPointer { Data(buffer: $0) }
        let vb = alloc.newBuffer(with: vData, type: .vertex)
        let ib = alloc.newBuffer(with: iData, type: .index)
        let desc = MDLVertexDescriptor()
        desc.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0)
        desc.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal, format: .float3, offset: 12, bufferIndex: 0)
        desc.layouts[0] = MDLVertexBufferLayout(stride: 24)
        let mat = MDLMaterial(name: "M\(i)", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
        let c = SIMD3<Float>(Float((m.rgb >> 16) & 255) / 255, Float((m.rgb >> 8) & 255) / 255, Float(m.rgb & 255) / 255)
        mat.setProperty(MDLMaterialProperty(name: "baseColor", semantic: .baseColor, float3: c))
        if m.op < 0.99 { mat.setProperty(MDLMaterialProperty(name: "opacity", semantic: .opacity, float: Float(m.op))) }
        let sub = MDLSubmesh(indexBuffer: ib, indexCount: idx.count, indexType: .uInt32, geometryType: .triangles, material: mat)
        let mesh = MDLMesh(vertexBuffers: [vb], vertexCount: verts.count / 6, descriptor: desc, submeshes: [sub])
        mesh.name = "G\(i)"
        asset.add(mesh)
    }
    do { try asset.export(to: url) } catch { return false }
    let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.intValue ?? 0
    return size > 0
}

/// Writes the USDZ of scene s at url: the app's own package, else ModelIO's. False when neither was written.
func c3WriteUsdz(_ s: C3Scene, _ url: URL) -> Bool {
    let d = client3DUsdz(s)
    if !d.isEmpty, (try? d.write(to: url, options: .atomic)) != nil { return true }
    try? FileManager.default.removeItem(at: url)
    return c3ModelIO(s, url)
}

/// The order's client files in a new folder of the app's temporary space: the USDZ and the HTML asked for. Empty when
/// the order has nothing to show.
func client3DFiles(_ p: Project, _ s: AppSettings, rid: String?, usdz: Bool, html: Bool) -> [URL] {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory.appendingPathComponent("client3d-" + uid(), isDirectory: true)
    guard (try? fm.createDirectory(at: dir, withIntermediateDirectories: true)) != nil else { return [] }
    let base = c3FileBase(dn(p.name, Lang.of(p.reportLang)))
    var out: [URL] = []
    if usdz, let sc = client3DScene(p, rid: rid, ws: s.workshop, mats: s.mats, snap: s.angleSnap, detail: .low) {
        let u = dir.appendingPathComponent(base + ".usdz")
        if c3WriteUsdz(sc, u) { out.append(u) }
    }
    if html, let h = client3DHtmlFor(p, s, rid: rid) {
        let u = dir.appendingPathComponent(base + ".html")
        if (try? Data(h.utf8).write(to: u, options: .atomic)) != nil { out.append(u) }
    }
    return out
}

/// Opens the phone's share sheet with several files (Telegram, WhatsApp, Files…).
@MainActor
func presentShareFiles(_ urls: [URL]) {
    guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
          var vc = scene.keyWindow?.rootViewController ?? scene.windows.first?.rootViewController else { return }
    while let p = vc.presentedViewController { vc = p }
    let av = UIActivityViewController(activityItems: urls, applicationActivities: nil)
    if let pop = av.popoverPresentationController {
        pop.sourceView = vc.view
        pop.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 0, height: 0)
        pop.permittedArrowDirections = []
    }
    vc.present(av, animated: true)
}

/* ---------------- the sheet ---------------- */

/// "Mijozga 3D yuborish": which files, what goes in them, send.
struct Share3DSheet: View {
    let app: AppModel
    let pid: String
    let rid: String?
    @State private var usdz = true
    @State private var html = true

    var body: some View {
        let s = AppSettings.shared
        GlassSheet(tr("sh3.title"), onClose: { app.sheet = nil }) {
            VStack(alignment: .leading, spacing: 10) {
                T(tr("sh3.sub"), ui(13.5, 400, G.ink2, lh: 1.4))
                Share3DFile(tag: "USDZ", name: tr("sh3.usdz"), sub: tr("sh3.usdzS"), on: usdz, tint: G.cobalt) { usdz.toggle() }
                    .accessibilityIdentifier("sh3.usdz")
                Share3DFile(tag: "HTML", name: tr("sh3.html"), sub: tr("sh3.htmlS"), on: html, tint: G.green) { html.toggle() }
                    .accessibilityIdentifier("sh3.html")
                if s.advanced {
                    FToggle(label: tr("sh3.oPrice"), on: s.share3dPrice, id: "sh3.oPrice", sub: tr("sh3.oPriceS")) { s.setShare3d("share3dPrice", !s.share3dPrice) }
                }
                FToggle(label: tr("sh3.oDims"), on: s.share3dDims, id: "sh3.oDims", sub: tr("sh3.oDimsS")) { s.setShare3d("share3dDims", !s.share3dDims) }
                FToggle(label: tr("sh3.oPhone"), on: s.share3dPhone, id: "sh3.oPhone", sub: tr("sh3.oPhoneS")) { s.setShare3d("share3dPhone", !s.share3dPhone) }
                T(tr("sh3.note"), ui(12.5, 500, G.cobalt2, lh: 1.4))
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(G.blueWash))
                GBtn(tr("sh3.send"), icon: "send", enabled: usdz || html) { send() }
                    .padding(.top, 4)
                    .accessibilityIdentifier("sh3.send")
            }
            .padding(.bottom, 6)
        }
    }

    private func send() {
        guard let p = Store.shared.get(pid), app.once() else { return }
        let s = AppSettings.shared, model = app
        let room = rid, u = usdz, h = html
        model.say("sh3.making", kind: .info)
        model.sheet = nil
        // the sheet goes and the note shows first; the files take a moment
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            let urls = client3DFiles(p, s, rid: room, usdz: u, html: h)
            if urls.isEmpty { model.say("sh3.none", kind: .error); return }
            presentShareFiles(urls)
        }
    }
}

/// One file of the sheet: its type's tag, name and note, picked or not.
private struct Share3DFile: View {
    let tag: String, name: String, sub: String
    let on: Bool
    let tint: Color
    let action: () -> Void
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: 12) {
            T(tag, ui(11, 800, .white), align: .center, lines: 1)
                .frame(width: 52, height: 40)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint))
            VStack(alignment: .leading, spacing: 1) {
                T(name, ui(14.5, 700), lines: 1)
                T(sub, ui(12, 400, G.ink2), lines: 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MIcon(on ? "check" : "plus", on ? G.cobalt : G.ink3, 20, 2.2)
        }
        .padding(10)
        .background(shape.fill(on ? G.cobalt.opacity(0.08) : G.glass(0.55)))
        .overlay(shape.strokeBorder(on ? G.cobalt : G.rim, lineWidth: on ? 1.5 : 1))
        .pressable(0.98, action)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}
