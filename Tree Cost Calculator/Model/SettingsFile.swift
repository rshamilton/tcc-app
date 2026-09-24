//
//  SettingsFile.swift
//  Tree Cost Calculator
//

import Foundation

/// Keeps a copy of the user's settings (business details, default prices, tax regions…) in
/// `Settings.json` inside the data folder, so they survive deleting and reinstalling the app along
/// with the estimates.
nonisolated enum SettingsFile {
    private static let bools = [SettingsKey.useMetric, SettingsKey.onboarded, SettingsKey.includePhotos,
                                SettingsKey.itemizeTrees, SettingsKey.iCloudBackup]
    private static let doubles = [SettingsKey.startingFee, SettingsKey.ratePerUnit, SettingsKey.taxRate]
    private static let ints = [SettingsKey.validDays, SettingsKey.nextNumber]
    private static let strings = [SettingsKey.companyName, SettingsKey.companyPhone, SettingsKey.companyEmail,
                                  SettingsKey.companyAddress, SettingsKey.companyLicense, SettingsKey.taxRegions,
                                  SettingsKey.terms]

    private static let lock = NSLock()
    nonisolated(unsafe) private static var pending: DispatchWorkItem?
    nonisolated(unsafe) private static var lastWritten: Data?

    /// Only settings that differ from their default are stored.
    private static func snapshot(from defaults: UserDefaults) -> [String: Any] {
        var result: [String: Any] = [:]
        for key in bools + doubles + ints + strings {
            guard defaults.object(forKey: key) != nil else { continue }
            // Read with the setting's own type, so e.g. a "YES" string still saves as a Bool.
            let value: NSObject
            if bools.contains(key) { value = defaults.bool(forKey: key) as NSNumber }
            else if doubles.contains(key) { value = defaults.double(forKey: key) as NSNumber }
            else if ints.contains(key) { value = defaults.integer(forKey: key) as NSNumber }
            else if let text = defaults.string(forKey: key) { value = text as NSString }
            else { continue }
            if let standard = AppDefaults.registered[key] as? NSObject, standard.isEqual(value) { continue }
            result[key] = value
        }
        return result
    }

    /// Writes `Settings.json` a moment after the last change.
    static func scheduleWrite() {
        lock.lock()
        pending?.cancel()
        let work = DispatchWorkItem { writeNow() }
        pending = work
        lock.unlock()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    static func writeNow() {
        let dict = snapshot(from: .standard)
        guard !dict.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]) else { return }
        lock.lock(); defer { lock.unlock() }
        guard data != lastWritten else { return }
        DataFolder.prepare()
        if (try? data.write(to: DataFolder.settings, options: .atomic)) != nil {
            lastWritten = data
            BackupScheduler.shared.schedule()
        }
    }

    /// Loads settings saved in a `Settings.json` (from the backup) into UserDefaults. Settings it doesn't
    /// mention keep their current value, and the next estimate number never goes down (so a number
    /// already used on this device isn't handed out again). Returns false if the file can't be read.
    @discardableResult
    static func apply(_ data: Data) -> Bool {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        let defaults = UserDefaults.standard
        for (key, value) in dict {
            if bools.contains(key), let v = value as? Bool { defaults.set(v, forKey: key) }
            else if doubles.contains(key), let v = value as? Double { defaults.set(v, forKey: key) }
            else if key == SettingsKey.nextNumber, let v = value as? Int { defaults.set(max(v, defaults.integer(forKey: key)), forKey: key) }
            else if ints.contains(key), let v = value as? Int { defaults.set(v, forKey: key) }
            else if strings.contains(key), let v = value as? String { defaults.set(v, forKey: key) }
        }
        return true
    }
}
