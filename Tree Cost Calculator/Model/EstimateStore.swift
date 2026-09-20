//
//  EstimateStore.swift
//  Tree Cost Calculator
//

import Foundation
import SwiftUI
import Combine

/// Single source of truth for saved estimates. Each estimate is saved as its own small JSON file in
/// the visible data folder (see `DataFolder`) shortly after every change; photos are separate files.
@MainActor
final class EstimateStore: ObservableObject {
    @Published private(set) var estimates: [Estimate] = []

    private let defaults: UserDefaults
    private var dirty = Set<UUID>()
    private var saveTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Queries

    var sortedEstimates: [Estimate] {
        estimates.sorted { $0.updatedAt > $1.updatedAt }
    }

    func estimate(id: UUID) -> Estimate? {
        estimates.first { $0.id == id }
    }

    var openEstimates: [Estimate] { estimates.filter { $0.status.isOpen && $0.hasMeasuredTree } }
    var approvedEstimates: [Estimate] { estimates.filter { $0.status == .approved } }

    // MARK: Changes

    /// Creates an empty estimate pre-filled with the user's default pricing.
    @discardableResult
    func createEstimate() -> Estimate {
        var e = Estimate()
        e.number = takeNextNumber()
        e.unitSystem = defaults.bool(forKey: SettingsKey.useMetric) ? .metric : .imperial
        e.startingFee = defaults.double(forKey: SettingsKey.startingFee)
        e.ratePerUnit = defaults.double(forKey: SettingsKey.ratePerUnit)
        e.taxRate = defaults.double(forKey: SettingsKey.taxRate)
        e.licenseNumber = (defaults.string(forKey: SettingsKey.companyLicense) ?? "").trimmed
        e.trees = [TreeItem()]
        estimates.insert(e, at: 0)
        markDirty(e.id)
        return e
    }

    /// Saves edits to an existing estimate. Does nothing if it has been deleted.
    func update(_ estimate: Estimate) {
        guard let index = estimates.firstIndex(where: { $0.id == estimate.id }) else { return }
        guard estimates[index] != estimate else { return }
        var updated = estimate
        updated.updatedAt = Date()
        estimates[index] = updated
        markDirty(updated.id)
    }

    func delete(id: UUID) {
        guard let estimate = estimate(id: id) else { return }
        // Give the number back if this was the newest one and it never held anything.
        if estimate.isBlank, estimate.number == defaults.integer(forKey: SettingsKey.nextNumber) - 1 {
            defaults.set(estimate.number, forKey: SettingsKey.nextNumber)
        }
        estimates.removeAll { $0.id == id }
        dirty.remove(id)

        let name = DataFolder.fileName(for: estimate)
        try? FileManager.default.removeItem(at: DataFolder.estimates.appendingPathComponent(name))
        BackupScheduler.shared.noteDeletion("Estimates/\(name)")

        let photos = estimate.allPhotoIDs
        Task.detached(priority: .utility) { PhotoStore.delete(photos) }
    }

    /// Copies customer, measurements and pricing into a fresh draft (photos are not copied).
    @discardableResult
    func duplicate(id: UUID) -> Estimate? {
        guard var copy = estimate(id: id) else { return nil }
        copy.id = UUID()
        copy.number = takeNextNumber()
        copy.status = .draft
        copy.createdAt = Date()
        copy.updatedAt = Date()
        copy.sitePhotoIDs = []
        copy.trees = copy.trees.map { TreeItem(label: $0.label, circumference: $0.circumference, height: $0.height) }
        estimates.insert(copy, at: 0)
        markDirty(copy.id)
        return copy
    }

    #if DEBUG
    /// Replaces an estimate without touching its dates (used to seed demo data).
    func debugReplace(_ estimate: Estimate) {
        guard let index = estimates.firstIndex(where: { $0.id == estimate.id }) else { return }
        estimates[index] = estimate
        markDirty(estimate.id)
    }
    #endif

    private func takeNextNumber() -> Int {
        let stored = defaults.integer(forKey: SettingsKey.nextNumber)
        let next = max(stored, (estimates.map(\.number).max() ?? 0) + 1, 1)
        defaults.set(next + 1, forKey: SettingsKey.nextNumber)
        return next
    }

    // MARK: Persistence

    private func markDirty(_ id: UUID) {
        dirty.insert(id)
        scheduleSave()
    }

    func flush() {
        saveTask?.cancel()
        saveTask = nil
        write()
        SettingsFile.writeNow()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.write()
        }
    }

    private func write() {
        guard !dirty.isEmpty else { return }
        DataFolder.prepare()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let ids = dirty
        dirty.removeAll()
        for id in ids {
            guard let estimate = estimate(id: id) else { continue }
            let url = DataFolder.estimates.appendingPathComponent(DataFolder.fileName(for: estimate))
            do {
                try encoder.encode(estimate).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            } catch {
                dirty.insert(id)
                print("EstimateStore: could not save \(url.lastPathComponent) – \(error)")
            }
        }
        BackupScheduler.shared.schedule()
    }

    /// Reads every estimate file from the data folder. Called once at launch, after any restore.
    func reload() {
        DataFolder.prepare()
        importPreviousStorageIfNeeded()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let urls = (try? FileManager.default.contentsOfDirectory(at: DataFolder.estimates, includingPropertiesForKeys: nil)) ?? []
        var loaded: [Estimate] = []
        for url in urls where url.pathExtension == "json" {
            // A file we can't read is left alone rather than overwritten or deleted.
            if let data = try? Data(contentsOf: url), let estimate = try? decoder.decode(Estimate.self, from: data) {
                loaded.append(estimate)
            } else {
                print("EstimateStore: skipping unreadable file \(url.lastPathComponent)")
            }
        }
        estimates = loaded

        // A reinstall resets the counter, so never hand out a number that is already in use.
        let highest = loaded.map(\.number).max() ?? 0
        if highest >= defaults.integer(forKey: SettingsKey.nextNumber) {
            defaults.set(highest + 1, forKey: SettingsKey.nextNumber)
        }

        migrateLegacyDataIfNeeded()
        purgeOrphanedPhotos()
    }

    private func purgeOrphanedPhotos() {
        let referenced = Set(estimates.flatMap(\.allPhotoIDs))
        Task.detached(priority: .utility) { PhotoStore.purge(keeping: referenced) }
    }

    // MARK: Older versions

    /// Builds made during development kept everything in Application Support (one JSON array plus photos).
    private func importPreviousStorageIfNeeded() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TreeCostCalculator", isDirectory: true)
        let oldFile = base.appendingPathComponent("estimates.json")
        guard fm.fileExists(atPath: oldFile.path) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: oldFile), let old = try? decoder.decode([Estimate].self, from: data) else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        for estimate in old {
            let url = DataFolder.estimates.appendingPathComponent(DataFolder.fileName(for: estimate))
            if !fm.fileExists(atPath: url.path) { try? encoder.encode(estimate).write(to: url, options: .atomic) }
        }
        let oldPhotos = base.appendingPathComponent("Photos", isDirectory: true)
        for name in (try? fm.contentsOfDirectory(atPath: oldPhotos.path)) ?? [] {
            let destination = DataFolder.photos.appendingPathComponent(name)
            if !fm.fileExists(atPath: destination.path) { try? fm.moveItem(at: oldPhotos.appendingPathComponent(name), to: destination) }
        }
        let oldLogo = base.appendingPathComponent("logo.png")
        if fm.fileExists(atPath: oldLogo.path), !fm.fileExists(atPath: DataFolder.logo.path) { try? fm.moveItem(at: oldLogo, to: DataFolder.logo) }
        try? fm.removeItem(at: base)
    }

    /// Quotes saved by version 1 of the app (JSON in UserDefaults with photos embedded).
    private func migrateLegacyDataIfNeeded() {
        guard !defaults.bool(forKey: SettingsKey.migratedLegacy) else { return }

        let quotes = defaults.data(forKey: LegacyMigration.quotesKey)
        let history = defaults.data(forKey: LegacyMigration.historyKey)
        let logo = defaults.data(forKey: LegacyMigration.logoKey)
        let taxWasEnabled = defaults.bool(forKey: "showTaxCalculator")

        guard quotes != nil || logo != nil else {
            defaults.set(true, forKey: SettingsKey.migratedLegacy)
            return
        }

        Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                LegacyMigration.convert(quotesData: quotes, historyData: history, logoData: logo, taxWasEnabled: taxWasEnabled)
            }.value
            guard let self else { return }
            let existing = Set(self.estimates.map(\.id))
            var next = max(self.defaults.integer(forKey: SettingsKey.nextNumber), (self.estimates.map(\.number).max() ?? 0) + 1)
            for var estimate in result where !existing.contains(estimate.id) {
                estimate.number = next
                next += 1
                self.estimates.append(estimate)
                self.dirty.insert(estimate.id)
            }
            self.defaults.set(next, forKey: SettingsKey.nextNumber)
            self.flush()
            // Old blobs are left in place on purpose; they are only ever read once.
            self.defaults.removeObject(forKey: LegacyMigration.logoKey)
            self.defaults.set(true, forKey: SettingsKey.migratedLegacy)
        }
    }
}
