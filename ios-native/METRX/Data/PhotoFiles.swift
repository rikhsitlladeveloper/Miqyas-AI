import UIKit

/// Photos of workspaces and the Measure page's pictures (Android data/PhotoFiles.kt). The prototype keeps each as JPEG
/// data in the item, at most 1280 px on the long side, 72 % quality (78 % from the live camera); here each is a file in
/// Application Support ("photos/<id>.jpg").
enum PhotoFiles {
    /// Saves the picture (made smaller first when needed) and returns its name and pixel size.
    static func save(_ id: String, _ img: UIImage, quality: CGFloat = 0.72) -> (String, Int, Int)? {
        let up = shrink(upright(img), 1280)
        guard let data = up.jpegData(compressionQuality: quality) else { return nil }
        let name = "photos/" + id + ".jpg"
        let url = ViewFiles.file(name)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        do { try data.write(to: url, options: .atomic) } catch { return nil }
        return (name, Int(up.size.width * up.scale), Int(up.size.height * up.scale))
    }

    static func load(_ src: String, maxW: CGFloat = 0) -> UIImage? { ViewFiles.load(src, maxW: maxW) }

    /// The picture as the camera held it (the camera stores its turn as a flag).
    private static func upright(_ img: UIImage) -> UIImage {
        guard img.imageOrientation != .up else { return img }
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: img.size.width * img.scale, height: img.size.height * img.scale), format: f).image { _ in
            img.draw(in: CGRect(x: 0, y: 0, width: img.size.width * img.scale, height: img.size.height * img.scale))
        }
    }

    private static func shrink(_ img: UIImage, _ max: CGFloat) -> UIImage {
        let w = img.size.width * img.scale, h = img.size.height * img.scale
        let k = min(1, max / Swift.max(w, h))
        if k >= 1 && img.scale == 1 { return img }
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: (w * k).rounded(), height: (h * k).rounded()), format: f).image { _ in
            img.draw(in: CGRect(x: 0, y: 0, width: (w * k).rounded(), height: (h * k).rounded()))
        }
    }
}
