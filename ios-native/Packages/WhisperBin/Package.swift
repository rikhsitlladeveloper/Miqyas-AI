// swift-tools-version:5.9
// The offline speech engine of the voice input (UX upgrades section 9): whisper.cpp's official prebuilt XCFramework
// from its GitHub release b5130 (v1.9.4, 11 Sep 2026), pinned by its SHA-256. The model is downloaded by the app on
// first use (METRX/UX/VoicePack.swift).
import PackageDescription

let package = Package(
    name: "WhisperBin",
    platforms: [.iOS(.v17)],
    products: [.library(name: "WhisperBin", targets: ["whisper"])],
    targets: [
        .binaryTarget(
            name: "whisper",
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/b5130/whisper-b5130-xcframework.zip",
            checksum: "033a43b0174e8cf9b366f72e4a428cdcf126f93ad1c87d3fa119a96bed6f231a"
        ),
    ]
)
