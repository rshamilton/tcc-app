//
//  PhotoStore.swift
//  Tree Cost Calculator
//

import Foundation
import UIKit
import ImageIO
import UniformTypeIdentifiers

/// Stores photos and the company logo as files in Application Support instead of
/// inside UserDefaults, and keeps them at a sensible size.
nonisolated enum PhotoStore {
    /// Longest edge of a stored photo, in pixels.
    private static let maxStoredDimension = 2000
    private static let maxLogoDimension = 600

    private static var logoURL: URL { DataFolder.logo }

    nonisolated(unsafe) private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 120
        return c
    }()

    static func url(for id: UUID) -> URL {
        DataFolder.photos.appendingPathComponent("\(id.uuidString).jpg")
    }

    private static func relativePath(for id: UUID) -> String { "Photos/\(id.uuidString).jpg" }

    // MARK: Photos

    /// Downsizes and stores image data (any format the system can read). Returns the new photo's id.
    @discardableResult
    static func save(_ data: Data) -> UUID? {
        guard let jpeg = encode(data, maxDimension: maxStoredDimension, asPNG: false) else { return nil }
        let id = UUID()
        DataFolder.prepare()
        do {
            try jpeg.write(to: url(for: id), options: .atomic)
            BackupScheduler.shared.schedule()
            return id
        } catch {
            return nil
        }
    }

    /// A downscaled image for display. `maxPixel` is the longest edge in pixels.
    static func image(for id: UUID, maxPixel: Int) -> UIImage? {
        let key = "\(id.uuidString)-\(maxPixel)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let source = CGImageSourceCreateWithURL(url(for: id) as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions(maxPixel: maxPixel)) else { return nil }
        let image = UIImage(cgImage: cg)
        cache.setObject(image, forKey: key)
        return image
    }

    static func delete(_ ids: [UUID]) {
        for id in ids {
            try? FileManager.default.removeItem(at: url(for: id))
            BackupScheduler.shared.noteDeletion(relativePath(for: id))
        }
    }

    /// Removes any photo file that no estimate refers to (left behind by crashes or interrupted edits).
    static func purge(keeping referenced: Set<UUID>) {
        let files = (try? FileManager.default.contentsOfDirectory(at: DataFolder.photos, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "jpg" {
            // Never touch a photo saved in the last few minutes: its estimate may not be saved yet.
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            guard Date().timeIntervalSince(modified) > 300 else { continue }
            if let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent), !referenced.contains(id) {
                try? FileManager.default.removeItem(at: file)
                BackupScheduler.shared.noteDeletion(relativePath(for: id))
            }
        }
    }

    // MARK: Logo

    static func saveLogo(_ data: Data) -> Bool {
        guard let png = encode(data, maxDimension: maxLogoDimension, asPNG: true) else { return false }
        DataFolder.prepare()
        guard (try? png.write(to: logoURL, options: .atomic)) != nil else { return false }
        BackupScheduler.shared.schedule()
        return true
    }

    static func loadLogo() -> UIImage? {
        guard let data = try? Data(contentsOf: logoURL) else { return nil }
        return UIImage(data: data)
    }

    static func removeLogo() {
        try? FileManager.default.removeItem(at: logoURL)
        BackupScheduler.shared.noteDeletion("Logo.png")
    }

    // MARK: Helpers

    private static func thumbnailOptions(maxPixel: Int) -> CFDictionary {
        [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ] as CFDictionary
    }

    private static func encode(_ data: Data, maxDimension: Int, asPNG: Bool) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions(maxPixel: maxDimension)) else { return nil }
        let output = NSMutableData()
        let type = asPNG ? UTType.png : UTType.jpeg
        guard let dest = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil) else { return nil }
        let properties: [CFString: Any] = asPNG ? [:] : [kCGImageDestinationLossyCompressionQuality: 0.82]
        CGImageDestinationAddImage(dest, cg, properties as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return output as Data
    }
}
