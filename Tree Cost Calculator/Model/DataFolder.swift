//
//  DataFolder.swift
//  Tree Cost Calculator
//

import Foundation

/// Everything the app saves lives as ordinary files in the app's Documents folder, which iOS shows in the
/// Files app as "TCC" (the app's display name). That makes it easy to see what uses space and to copy the data.
///
///     Estimates/EST-0001-1A2B3C4D.json   one small file per estimate
///     Photos/<id>.jpg                    photos attached to estimates
///     Logo.png                           company logo
///     Settings.json                      business details and default prices
///     README.txt                         explains the folder
nonisolated enum DataFolder {
    static let root: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    static var estimates: URL { root.appendingPathComponent("Estimates", isDirectory: true) }
    static var photos: URL { root.appendingPathComponent("Photos", isDirectory: true) }
    static var logo: URL { root.appendingPathComponent("Logo.png") }
    static var settings: URL { root.appendingPathComponent("Settings.json") }

    /// Creates the folders (and the explanatory README) if they don't exist yet.
    static func prepare() {
        let fm = FileManager.default
        try? fm.createDirectory(at: estimates, withIntermediateDirectories: true)
        try? fm.createDirectory(at: photos, withIntermediateDirectories: true)
        let readme = root.appendingPathComponent("README.txt")
        if !fm.fileExists(atPath: readme.path) {
            let text = """
            Tree Cost Calculator: your data

            This folder holds everything the app saves, as ordinary files:

              Estimates/   one small file per estimate
              Photos/      photos you attached to estimates
              Logo.png     your company logo
              Settings.json  your business details and default prices

            Use the Files app (Get Info on this folder) to see how much space each part uses.
            The app keeps a copy of this folder in your iCloud Drive (if iCloud Drive is on) so your
            data comes back if you delete and reinstall the app.

            Please don't rename or edit these files by hand: the app may not be able to read them.
            """
            try? text.write(to: readme, atomically: true, encoding: .utf8)
        }
    }

    /// File name for an estimate. The number never changes after creation, so neither does the name.
    static func fileName(for estimate: Estimate) -> String {
        "\(estimate.numberLabel)-\(estimate.id.uuidString.prefix(8)).json"
    }

    /// True when there is nothing saved here yet (a first launch, or a fresh install).
    static var isEmpty: Bool {
        let fm = FileManager.default
        let estimateFiles = (try? fm.contentsOfDirectory(atPath: estimates.path))?.filter { $0.hasSuffix(".json") } ?? []
        return estimateFiles.isEmpty && !fm.fileExists(atPath: settings.path)
    }

    /// Every data file, as a path relative to `root` (used to mirror the folder to iCloud Drive).
    static func dataFiles() -> [String] {
        let fm = FileManager.default
        var result: [String] = []
        for (folder, ext) in [("Estimates", "json"), ("Photos", "jpg")] {
            let names = (try? fm.contentsOfDirectory(atPath: root.appendingPathComponent(folder).path)) ?? []
            result += names.filter { $0.hasSuffix(".\(ext)") }.map { "\(folder)/\($0)" }
        }
        for name in ["Logo.png", "Settings.json"] where fm.fileExists(atPath: root.appendingPathComponent(name).path) {
            result.append(name)
        }
        return result
    }

    struct Usage {
        var estimateCount = 0
        var estimateBytes: Int64 = 0
        var photoCount = 0
        var photoBytes: Int64 = 0
        var totalBytes: Int64 { estimateBytes + photoBytes }
    }

    static func usage() -> Usage {
        var usage = Usage()
        let fm = FileManager.default
        func size(_ url: URL) -> Int64 {
            Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        for name in (try? fm.contentsOfDirectory(atPath: estimates.path)) ?? [] where name.hasSuffix(".json") {
            usage.estimateCount += 1
            usage.estimateBytes += size(estimates.appendingPathComponent(name))
        }
        for name in (try? fm.contentsOfDirectory(atPath: photos.path)) ?? [] where name.hasSuffix(".jpg") {
            usage.photoCount += 1
            usage.photoBytes += size(photos.appendingPathComponent(name))
        }
        usage.estimateBytes += size(settings) + size(logo)
        return usage
    }
}
