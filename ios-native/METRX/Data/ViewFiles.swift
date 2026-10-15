import UIKit

/// Pictures of 3D views added to the report. The prototype keeps them in the project as JPEG data; here each is a JPEG
/// file in Application Support and the room keeps its name (View3D.img = "views/<id>.jpg"), as in the Android app.
enum ViewFiles {
    private static var base: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0] }
    private static var dir: URL {
        let d = base.appendingPathComponent("views", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func file(_ img: String) -> URL { base.appendingPathComponent(img) }

    /// Saves the picture as JPEG at 80 % like the prototype's toDataURL('image/jpeg', 0.8).
    static func save(_ id: String, _ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        do { try data.write(to: dir.appendingPathComponent(id + ".jpg"), options: .atomic); return "views/" + id + ".jpg" }
        catch { return nil }
    }

    /// The picture, scaled down to about maxW points wide (0 = full size).
    static func load(_ img: String, maxW: CGFloat = 0) -> UIImage? {
        guard let im = UIImage(contentsOfFile: file(img).path) else { return nil }
        guard maxW > 0, im.size.width > maxW else { return im }
        return im.preparingThumbnail(of: CGSize(width: maxW, height: im.size.height * maxW / im.size.width)) ?? im
    }

    static func delete(_ img: String) { try? FileManager.default.removeItem(at: file(img)) }
}
