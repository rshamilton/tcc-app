//
//  BackupMirror.swift
//  Tree Cost Calculator
//

import Foundation
import Combine
import UIKit

/// Where the backup copy of the data folder lives: the app's iCloud Drive container, which survives
/// deleting the app. (Debug builds can point it at any folder with `-backupDir <path>` for testing.)
nonisolated enum BackupLocation {
    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: SettingsKey.iCloudBackup) }

    /// Cheap check that iCloud is signed in and available to this app.
    static var isAvailable: Bool {
        #if DEBUG
        if DebugLaunch.value(after: "-backupDir") != nil { return true }
        #endif
        return FileManager.default.ubiquityIdentityToken != nil
    }

    /// The folder to mirror into. May block while iCloud starts up, so call it off the main thread.
    static func url() -> URL? {
        #if DEBUG
        if let path = DebugLaunch.value(after: "-backupDir") {
            let url = URL(fileURLWithPath: path, isDirectory: true)
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }
        #endif
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        let documents = container.appendingPathComponent("Documents", isDirectory: true)
        try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        return documents
    }
}

/// Lets the launch coordinator tell restore work running off the main thread to stop.
nonisolated final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return flag }
    func cancel() { lock.lock(); flag = true; lock.unlock() }
}

// MARK: - Coordinated file helpers

nonisolated enum BackupFiles {
    /// Copies `source` over `destination` using file coordination (required for iCloud files).
    static func write(_ source: URL, to destination: URL) throws {
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(writingItemAt: destination, options: .forReplacing, error: &coordinationError) { url in
            do { try copyReplacing(source, to: url) } catch { copyError = error }
        }
        if let error = coordinationError ?? copyError { throw error }
    }

    /// Copies via a temporary file next to the destination, then swaps it in, so the destination is never
    /// left missing or half-written if the copy fails part way.
    private static func copyReplacing(_ source: URL, to destination: URL) throws {
        let fm = FileManager.default
        let directory = destination.deletingLastPathComponent()
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let temp = directory.appendingPathComponent(".\(UUID().uuidString).tmp")
        try fm.copyItem(at: source, to: temp)
        do {
            if fm.fileExists(atPath: destination.path) {
                _ = try fm.replaceItemAt(destination, withItemAt: temp)
            } else {
                try fm.moveItem(at: temp, to: destination)
            }
        } catch {
            try? fm.removeItem(at: temp)
            throw error
        }
    }

    /// iCloud's stand-in for a file that isn't downloaded: ".<name>.icloud" next to where it would be.
    private static func placeholder(for url: URL) -> URL {
        url.deletingLastPathComponent().appendingPathComponent("." + url.lastPathComponent + ".icloud")
    }

    /// True when the file is in the backup, downloaded or not.
    static func exists(_ url: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: url.path) || fm.fileExists(atPath: placeholder(for: url).path)
    }

    /// Removes a file (and its iCloud placeholder, if any). Returns true when it is gone afterwards,
    /// including when it was never there; false means the caller should try again later.
    @discardableResult
    static func remove(_ url: URL) -> Bool {
        let fm = FileManager.default
        var ok = true
        for target in [url, placeholder(for: url)] where fm.fileExists(atPath: target.path) {
            var coordinationError: NSError?
            var removed = false
            NSFileCoordinator().coordinate(writingItemAt: target, options: .forDeleting, error: &coordinationError) { item in
                removed = (try? fm.removeItem(at: item)) != nil
            }
            if coordinationError != nil || !removed { ok = false }
        }
        return ok
    }

    /// Copies a file out of the backup, first waiting (up to 45 seconds) for iCloud to download it.
    /// Throws, rather than blocking in a coordinated read, if it still hasn't arrived by then.
    static func fetch(_ source: URL, to destination: URL, cancel: CancelFlag? = nil) throws {
        let fm = FileManager.default
        try? fm.startDownloadingUbiquitousItem(at: source)
        let deadline = Date().addingTimeInterval(45)
        var ready = false
        while true {
            if let status = (try? source.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?.ubiquitousItemDownloadingStatus {
                ready = status == .current || status == .downloaded
            } else {
                // Not an iCloud item (or no status yet): fine as long as the file is really there.
                ready = fm.fileExists(atPath: source.path)
            }
            if ready || Date() >= deadline || cancel?.isCancelled == true { break }
            Thread.sleep(forTimeInterval: 0.3)
        }
        guard ready, cancel?.isCancelled != true else { throw CocoaError(.fileReadUnknown) }

        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { url in
            do { try copyReplacing(url, to: destination) } catch { copyError = error }
        }
        if let error = coordinationError ?? copyError { throw error }
    }

    /// Every file in the backup folder, including iCloud's placeholders for files not downloaded yet.
    static func listing(of mirror: URL) -> [URL] {
        let enumerator = FileManager.default.enumerator(at: mirror, includingPropertiesForKeys: nil)
        return enumerator?.compactMap { $0 as? URL } ?? []
    }

    /// The backup item a file (or iCloud placeholder) in the backup folder stands for, if it is a data file.
    static func item(for url: URL, in mirror: URL) -> BackupItem? {
        // Paths may or may not start with /private depending on who produced them.
        func normalized(_ url: URL) -> String {
            let path = url.standardizedFileURL.path
            return path.hasPrefix("/private/") ? String(path.dropFirst("/private".count)) : path
        }
        var url = url
        let name = url.lastPathComponent
        if name.hasPrefix("."), name.hasSuffix(".icloud") {
            // ".EST-0001-1A2B3C4D.json.icloud" stands for "EST-0001-1A2B3C4D.json".
            let real = String(name.dropFirst().dropLast(".icloud".count))
            url = url.deletingLastPathComponent().appendingPathComponent(real)
        }
        let base = normalized(mirror)
        let path = normalized(url)
        guard path.hasPrefix(base + "/") else { return nil }
        let relative = String(path.dropFirst(base.count + 1))
        return isDataFile(relative) ? BackupItem(relative: relative, url: url) : nil
    }

    /// True when `a` was modified after `b` (by more than the rounding some file systems apply).
    static func isNewer(_ a: URL, than b: URL) -> Bool {
        let key: Set<URLResourceKey> = [.contentModificationDateKey]
        guard let dateA = (try? a.resourceValues(forKeys: key))?.contentModificationDate else { return false }
        guard let dateB = (try? b.resourceValues(forKeys: key))?.contentModificationDate else { return true }
        return dateA.timeIntervalSince(dateB) > 1
    }

    static func isDataFile(_ relativePath: String) -> Bool {
        if relativePath == "Logo.png" || relativePath == "Settings.json" { return true }
        if relativePath.hasPrefix("Estimates/") { return relativePath.hasSuffix(".json") && relativePath.split(separator: "/").count == 2 }
        if relativePath.hasPrefix("Photos/") { return relativePath.hasSuffix(".jpg") && relativePath.split(separator: "/").count == 2 }
        return false
    }
}

// MARK: - Keeping the backup up to date

/// Copies new and changed files from the data folder to the backup a few seconds after every change.
/// Files are only ever removed from the backup when the app itself deleted them, so an empty or partial
/// data folder can never wipe the backup, and a file is never replaced by an older version of it.
nonisolated final class BackupScheduler: @unchecked Sendable {
    static let shared = BackupScheduler()

    private let queue = DispatchQueue(label: "me.ryham.tcc.backup", qos: .utility)
    private let lock = NSLock()
    /// Files the app deleted that still have to be removed from the backup. Kept in UserDefaults (not in
    /// Documents) so a deletion made just before the app closed isn't forgotten.
    private static let pendingKey = "backupPendingDeletes"
    private var pendingDeletes = Set<String>(UserDefaults.standard.stringArray(forKey: BackupScheduler.pendingKey) ?? [])
    private var work: DispatchWorkItem?
    private var ready = false

    /// Syncing starts only once launch (including any restore) has finished.
    func markReady() {
        lock.lock(); ready = true; lock.unlock()
        schedule(after: 2)
    }

    func noteDeletion(_ relativePath: String) {
        lock.lock()
        pendingDeletes.insert(relativePath)
        savePendingDeletes()
        lock.unlock()
        schedule()
    }

    /// Call with `lock` held.
    private func savePendingDeletes() {
        UserDefaults.standard.set(pendingDeletes.sorted(), forKey: Self.pendingKey)
    }

    func schedule(after delay: TimeInterval = 4) {
        lock.lock()
        work?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.run() }
        work = item
        lock.unlock()
        queue.asyncAfter(deadline: .now() + delay, execute: item)
    }

    /// Runs a sync right away (used when the app moves to the background).
    func syncNow(completion: (@Sendable () -> Void)? = nil) {
        lock.lock(); work?.cancel(); lock.unlock()
        queue.async { [weak self] in
            self?.run()
            completion?()
        }
    }

    private func run() {
        lock.lock()
        let isReady = ready
        let deletes = pendingDeletes
        lock.unlock()
        guard isReady, BackupLocation.isEnabled, BackupLocation.isAvailable, let mirror = BackupLocation.url() else { return }

        let fm = FileManager.default
        let linked = UserDefaults.standard.bool(forKey: SettingsKey.backupLinked)
        var failed = false
        for relative in DataFolder.dataFiles() {
            // A device that hasn't restored from the backup yet mustn't replace its settings and logo
            // (see `LaunchCoordinator`). Its estimates and photos have their own names, so they're safe.
            if !linked, relative == "Settings.json" || relative == "Logo.png" { continue }
            let source = DataFolder.root.appendingPathComponent(relative)
            let target = mirror.appendingPathComponent(relative)
            guard needsCopy(source: source, target: target, relative: relative) else { continue }
            do { try BackupFiles.write(source, to: target) } catch { failed = true }
        }
        // A deletion is forgotten only once it has actually happened in the backup (or was moot).
        var settled = Set<String>()
        for relative in deletes {
            guard BackupFiles.isDataFile(relative) else { settled.insert(relative); continue }
            if !linked, relative == "Settings.json" || relative == "Logo.png" { continue }
            // Recreated since (a new logo after Remove Logo, say): keep the new copy; the copy loop above handled it.
            if fm.fileExists(atPath: DataFolder.root.appendingPathComponent(relative).path) { settled.insert(relative); continue }
            if BackupFiles.remove(mirror.appendingPathComponent(relative)) { settled.insert(relative) }
            else { failed = true }
        }
        if !settled.isEmpty {
            lock.lock()
            pendingDeletes.subtract(settled)
            savePendingDeletes()
            lock.unlock()
        }
        if !failed { UserDefaults.standard.set(Date(), forKey: SettingsKey.lastBackup) }
    }

    private func needsCopy(source: URL, target: URL, relative: String) -> Bool {
        guard BackupFiles.exists(target) else { return true }
        // Photos never change once saved.
        if relative.hasPrefix("Photos/") { return false }
        // The other files are small, so compare what's in them.
        if let local = try? Data(contentsOf: source), let backup = try? Data(contentsOf: target), local == backup { return false }
        // Different: copy unless the backup's copy is the newer one (saved from another device).
        return !BackupFiles.isNewer(target, than: source)
    }
}

// MARK: - Reading the backup

/// A data file in the backup, by its path relative to the data folder.
nonisolated struct BackupItem: Sendable {
    let relative: String
    let url: URL
}

extension Notification.Name {
    /// Posted (with the photo's `UUID` as the object) when a photo arrives from the backup.
    static let photoRestored = Notification.Name("TCCPhotoRestored")
}

@MainActor
enum BackupRestore {
    /// Lists the data files in the backup, or nil if the backup can't be reached. On a new device iCloud
    /// may take a while to learn which files exist, so when nothing shows up it keeps looking for up to
    /// `patience` seconds, and when files do show up it waits for the list to stop growing.
    static func contents(patience: TimeInterval) async -> [BackupItem]? {
        await snapshot(patience: patience)?.items
    }

    /// The backup listing, plus whether iCloud's index finished gathering (when it didn't, an empty
    /// listing doesn't prove there is no backup).
    struct Snapshot {
        let items: [BackupItem]
        let gathered: Bool
    }

    static func snapshot(patience: TimeInterval) async -> Snapshot? {
        guard BackupLocation.isAvailable else { return nil }
        let mirror = await Task.detached(priority: .userInitiated) { BackupLocation.url() }.value
        guard let mirror else { return nil }

        var found: [String: URL] = [:]
        func add(_ urls: [URL]) {
            for url in urls {
                if let item = BackupFiles.item(for: url, in: mirror) { found[item.relative] = item.url }
            }
        }
        // What is on disk: downloaded files, and placeholders for ones that aren't.
        add(await Task.detached(priority: .userInitiated) { BackupFiles.listing(of: mirror) }.value)

        #if DEBUG
        if DebugLaunch.value(after: "-backupDir") != nil {
            return Snapshot(items: found.map { BackupItem(relative: $0.key, url: $0.value) }, gathered: true)
        }
        #endif

        // iCloud's own index also knows about files that haven't reached this device yet.
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE '*'", NSMetadataItemFSNameKey)
        query.start()
        defer { query.stop() }

        let start = Date()
        var gatheredAt: Date?
        var lastCount = -1
        var stableSince = Date()
        while Date().timeIntervalSince(start) < patience + 20 {
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return nil }
            guard !query.isGathering else { continue }
            let now = Date()
            if gatheredAt == nil { gatheredAt = now }

            query.disableUpdates()
            let urls = (query.results as? [NSMetadataItem] ?? []).compactMap { $0.value(forAttribute: NSMetadataItemURLKey) as? URL }
            query.enableUpdates()
            add(urls)

            if found.isEmpty {
                if now.timeIntervalSince(gatheredAt ?? now) >= patience { break }
            } else if found.count != lastCount {
                lastCount = found.count
                stableSince = now
            } else if now.timeIntervalSince(stableSince) >= 1.5 {
                break
            }
        }
        return Snapshot(items: found.map { BackupItem(relative: $0.key, url: $0.value) }, gathered: gatheredAt != nil)
    }

    struct Result {
        /// New plus updated estimates.
        var estimates: Int { newEstimates + updatedEstimates }
        var newEstimates = 0
        var updatedEstimates = 0
        var failed = 0
        var appliedSettings = false
    }

    /// Copies estimates, the logo and settings from the backup. Only files missing here are copied,
    /// except that `updateChanged` also brings over estimates that are newer in the backup (used when the
    /// user asks to restore). Photos are fetched separately by `restorePhotos`, once the estimates are loaded.
    static func restoreData(_ items: [BackupItem], updateChanged: Bool, cancel: CancelFlag? = nil, progress: @escaping (Int, Int) -> Void) async -> Result {
        DataFolder.prepare()
        let fm = FileManager.default
        var work: [(item: BackupItem, destination: URL)] = []
        var updates = Set<String>()
        for item in items where !item.relative.hasPrefix("Photos/") {
            let local = DataFolder.root.appendingPathComponent(item.relative)
            if item.relative == "Settings.json" {
                // Applied below rather than copied over this device's file.
                let temp = fm.temporaryDirectory.appendingPathComponent("Backup-Settings-\(UUID().uuidString).json")
                work.append((item, temp))
            } else if !fm.fileExists(atPath: local.path) {
                work.append((item, local))
            } else if updateChanged, item.relative.hasPrefix("Estimates/"), BackupFiles.isNewer(item.url, than: local) {
                work.append((item, local))
                updates.insert(item.relative)
            }
        }

        var result = Result()
        progress(0, work.count)
        var done = 0
        // A few at a time: each one may have to wait for iCloud to download it.
        await withTaskGroup(of: (BackupItem, URL, Bool).self) { group in
            var pending = work[...]
            func startNext() {
                guard cancel?.isCancelled != true, let next = pending.popFirst() else { return }
                group.addTask {
                    let ok = await Task.detached(priority: .userInitiated) {
                        (try? BackupFiles.fetch(next.item.url, to: next.destination, cancel: cancel)) != nil
                    }.value
                    return (next.item, next.destination, ok)
                }
            }
            for _ in 0..<4 { startNext() }
            for await (item, destination, ok) in group {
                done += 1
                progress(done, work.count)
                if !ok {
                    result.failed += 1
                } else if item.relative == "Settings.json" {
                    if let data = try? Data(contentsOf: destination) { result.appliedSettings = SettingsFile.apply(data) }
                    try? fm.removeItem(at: destination)
                } else if item.relative.hasPrefix("Estimates/") {
                    if updates.contains(item.relative) { result.updatedEstimates += 1 } else { result.newEstimates += 1 }
                }
                startNext()
            }
        }
        if result.appliedSettings { SettingsFile.writeNow() }
        return result
    }

    /// Fetches the photos that loaded estimates use but that aren't on this device, in the background.
    /// Each one shows up on screen as soon as it arrives.
    static func restorePhotos(_ items: [BackupItem], referenced: Set<UUID>) {
        let fm = FileManager.default
        let photos = items.filter { item in
            guard item.relative.hasPrefix("Photos/"),
                  let id = UUID(uuidString: (item.relative as NSString).lastPathComponent.replacingOccurrences(of: ".jpg", with: "")),
                  referenced.contains(id) else { return false }
            return !fm.fileExists(atPath: DataFolder.root.appendingPathComponent(item.relative).path)
        }
        guard !photos.isEmpty else { return }
        // Keeps the downloads going for a little while if the app is sent to the background.
        let background = BackgroundTaskBox()
        background.begin()
        Task.detached(priority: .utility) {
            defer { Task { @MainActor in background.end() } }
            await withTaskGroup(of: Void.self) { group in
                var pending = photos[...]
                func startNext() {
                    guard let item = pending.popFirst() else { return }
                    group.addTask {
                        let destination = DataFolder.root.appendingPathComponent(item.relative)
                        guard (try? BackupFiles.fetch(item.url, to: destination)) != nil,
                              let id = UUID(uuidString: destination.deletingPathExtension().lastPathComponent) else { return }
                        await MainActor.run { NotificationCenter.default.post(name: .photoRestored, object: id) }
                    }
                }
                for _ in 0..<4 { startNext() }
                for await _ in group { startNext() }
            }
        }
    }
}

@MainActor
private final class BackgroundTaskBox {
    private var id = UIBackgroundTaskIdentifier.invalid

    func begin() {
        id = UIApplication.shared.beginBackgroundTask(withName: "RestorePhotos") { [weak self] in
            MainActor.assumeIsolated { self?.end() }
        }
    }

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}

// MARK: - Launch

/// Decides at launch whether this is a fresh install that should be restored from the backup, makes
/// sure the data is loaded before the app shows anything, and handles restoring on request.
///
/// A device only starts replacing the settings and logo in the backup once it is "linked" to it: after
/// restoring from it, after the user chooses not to, or once it is clear there is no backup. Until then
/// a new device can't overwrite the settings of an existing backup with its empty defaults.
@MainActor
final class LaunchCoordinator: ObservableObject {
    enum Phase: Equatable {
        case ready
        case restoring(done: Int, total: Int)
    }

    /// A backup found after launch that this device hasn't restored from.
    struct BackupOffer: Identifiable {
        let id = UUID()
        /// Estimates in the backup that aren't on this device.
        let estimates: Int
    }

    @Published private(set) var phase: Phase = .ready
    @Published var backupOffer: BackupOffer?
    /// The outcome of a restore the user asked for.
    @Published var restoreMessage: String?

    private let store: EstimateStore
    private var watchTask: Task<Void, Never>?
    private var photoTask: Task<Void, Never>?
    private var launched = false

    /// Identifies the restore that is currently running. A restore that finishes after it was skipped (or
    /// replaced) no longer matches, so it can't call `finish()` a second time or touch state.
    private var restoreToken: UUID?
    private var restoreCancel: CancelFlag?
    private var restoreTask: Task<Void, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var restoreIsUserInitiated = false
    /// The longest the automatic restore at launch may keep the app waiting.
    private static let launchRestoreDeadline: Duration = .seconds(45)

    init(store: EstimateStore) {
        self.store = store
        let defaults = UserDefaults.standard
        let hasLocalData = !DataFolder.isEmpty || LegacyMigration.hasUnmigratedData
        DataFolder.prepare()
        if !hasLocalData {
            // Nothing here yet: a new device, or a reinstall. Any backup belongs to earlier data.
            defaults.set(false, forKey: SettingsKey.backupLinked)
            if BackupLocation.isEnabled, BackupLocation.isAvailable {
                phase = .restoring(done: 0, total: 0)
                startRestore(userInitiated: false)
                return
            }
        } else if defaults.object(forKey: SettingsKey.backupLinked) == nil {
            // Installs from before linking existed have been keeping the backup up to date all along.
            defaults.set(true, forKey: SettingsKey.backupLinked)
        }
        finish()
        watchForBackup()
    }

    private var isLinked: Bool { UserDefaults.standard.bool(forKey: SettingsKey.backupLinked) }

    /// Brings back everything in the backup that isn't on this device (Settings ▸ Restore, or the offer).
    func restoreFromBackup() {
        guard phase == .ready else { return }
        watchTask?.cancel()
        backupOffer = nil
        store.flush()
        phase = .restoring(done: 0, total: 0)
        startRestore(userInitiated: true)
    }

    /// Stops a restore that is taking too long and opens the app with the data already on this device.
    /// The device stays unlinked if it was, so the backup is still offered later.
    func skipRestore() {
        guard case .restoring = phase else { return }
        let wasUserInitiated = restoreIsUserInitiated
        endRestore()
        finish()
        if wasUserInitiated {
            restoreMessage = "The restore was stopped. Anything already downloaded was kept; you can try again from Settings."
        } else {
            watchForBackup()
        }
    }

    private func startRestore(userInitiated: Bool) {
        let token = UUID()
        let cancel = CancelFlag()
        restoreToken = token
        restoreCancel = cancel
        restoreIsUserInitiated = userInitiated
        restoreTask = Task { await restore(userInitiated: userInitiated, token: token, cancel: cancel) }
        if !userInitiated {
            deadlineTask = Task { [weak self] in
                try? await Task.sleep(for: Self.launchRestoreDeadline)
                guard !Task.isCancelled else { return }
                self?.skipRestore()
            }
        }
    }

    /// Cancels everything belonging to the current restore and invalidates its token.
    private func endRestore() {
        restoreToken = nil
        restoreCancel?.cancel()
        restoreCancel = nil
        restoreTask?.cancel()
        restoreTask = nil
        deadlineTask?.cancel()
        deadlineTask = nil
    }

    /// The user chose to keep this device's data instead of restoring the backup it found.
    func declineBackup() {
        backupOffer = nil
        link()
    }

    private func link() {
        watchTask?.cancel()
        UserDefaults.standard.set(true, forKey: SettingsKey.backupLinked)
        BackupScheduler.shared.schedule(after: 1)
    }

    private func restore(userInitiated: Bool, token: UUID, cancel: CancelFlag) async {
        let items = await BackupRestore.contents(patience: userInitiated ? 10 : 4)
        guard restoreToken == token else { return }
        var result = BackupRestore.Result()
        if let items, !items.isEmpty {
            result = await BackupRestore.restoreData(items, updateChanged: userInitiated, cancel: cancel) { [weak self] done, total in
                guard let self, self.restoreToken == token else { return }
                self.phase = .restoring(done: done, total: total)
            }
            guard restoreToken == token else { return }
            let backupHasSettings = items.contains { $0.relative == "Settings.json" }
            if result.appliedSettings || !backupHasSettings { link() }
        }
        endRestore()
        finish(scanPhotos: false)
        if let items {
            BackupRestore.restorePhotos(items, referenced: Set(store.estimates.flatMap(\.allPhotoIDs)))
        }

        if userInitiated {
            restoreMessage = Self.message(for: result, items: items)
        } else {
            watchForBackup()
        }
    }

    private static func message(for result: BackupRestore.Result, items: [BackupItem]?) -> String {
        guard let items else { return "Couldn't reach iCloud Drive. Check that you're signed in to iCloud and iCloud Drive is on, then try again." }
        guard !items.isEmpty else { return "There's no backup in iCloud Drive yet." }
        if result.failed > 0, result.estimates == 0, !result.appliedSettings {
            return "Nothing could be downloaded yet. Check your connection and try again."
        }
        var parts: [String] = []
        if result.newEstimates > 0 {
            parts.append(result.newEstimates == 1 ? "Restored 1 estimate." : "Restored \(result.newEstimates) estimates.")
        }
        if result.updatedEstimates > 0 {
            parts.append(result.updatedEstimates == 1 ? "Updated 1 estimate from the backup." : "Updated \(result.updatedEstimates) estimates from the backup.")
        }
        if result.appliedSettings { parts.append("Settings were restored.") }
        if parts.isEmpty { parts.append("Everything in the backup is already on this device.") }
        if result.failed > 0 {
            parts.append("\(result.failed) \(result.failed == 1 ? "file" : "files") couldn't be downloaded yet; try again in a few minutes.")
        } else if items.contains(where: { $0.relative.hasPrefix("Photos/") }) {
            parts.append("Photos will appear as they download.")
        }
        return parts.joined(separator: " ")
    }

    /// While this device isn't linked, keeps an eye out for a backup that iCloud hadn't downloaded the
    /// list of at launch, and offers to restore it. If none turns up, this device's data becomes the backup.
    private func watchForBackup() {
        guard !isLinked, BackupLocation.isEnabled, BackupLocation.isAvailable else { return }
        watchTask?.cancel()
        watchTask = Task { [weak self] in
            let started = Date()
            while !Task.isCancelled {
                guard let snapshot = await BackupRestore.snapshot(patience: 0), !Task.isCancelled, let self else { return }
                let items = snapshot.items
                let local = Set(DataFolder.dataFiles())
                let missing = items.filter { $0.relative.hasPrefix("Estimates/") && !local.contains($0.relative) }.count
                if missing > 0 || items.contains(where: { $0.relative == "Settings.json" }) {
                    if self.phase == .ready { self.backupOffer = BackupOffer(estimates: missing) }
                    return
                }
                // Only conclude "no backup" when iCloud's index positively finished and showed nothing.
                if snapshot.gathered, Date().timeIntervalSince(started) > 60 {
                    self.link()
                    return
                }
                try? await Task.sleep(for: .seconds(8))
            }
        }
    }

    private func finish(scanPhotos: Bool = true) {
        store.reload()
        BackupScheduler.shared.markReady()
        phase = .ready
        #if DEBUG
        if !launched { DebugLaunch.seedIfRequested(store) }
        #endif
        launched = true
        if scanPhotos { restoreMissingPhotos() }
    }

    /// Photos that were still downloading when the app last closed are fetched again: any photo an estimate
    /// uses that isn't on this device, if the backup has it.
    private func restoreMissingPhotos() {
        guard isLinked, BackupLocation.isEnabled, BackupLocation.isAvailable else { return }
        let fm = FileManager.default
        let missing = Set(store.estimates.flatMap(\.allPhotoIDs).filter { !fm.fileExists(atPath: PhotoStore.url(for: $0).path) })
        guard !missing.isEmpty else { return }
        photoTask?.cancel()
        photoTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let items = await BackupRestore.contents(patience: 0), !Task.isCancelled else { return }
            BackupRestore.restorePhotos(items, referenced: missing)
        }
    }
}
