//
//  BackupMirror.swift
//  Tree Cost Calculator
//

import Foundation
import Combine

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

// MARK: - Coordinated file helpers

nonisolated enum BackupFiles {
    /// Copies `source` over `destination` using file coordination (required for iCloud files).
    static func write(_ source: URL, to destination: URL) throws {
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(writingItemAt: destination, options: .forReplacing, error: &coordinationError) { url in
            do {
                let fm = FileManager.default
                try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fm.fileExists(atPath: url.path) { try fm.removeItem(at: url) }
                try fm.copyItem(at: source, to: url)
            } catch {
                copyError = error
            }
        }
        if let error = coordinationError ?? copyError { throw error }
    }

    static func remove(_ url: URL) {
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &coordinationError) { target in
            try? FileManager.default.removeItem(at: target)
        }
    }

    /// Copies a file out of the backup, first waiting for iCloud to download it.
    static func fetch(_ source: URL, to destination: URL) throws {
        try? FileManager.default.startDownloadingUbiquitousItem(at: source)
        let deadline = Date().addingTimeInterval(45)
        while Date() < deadline {
            let status = try? source.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus
            if status == nil || status == .current || status == .downloaded { break }
            Thread.sleep(forTimeInterval: 0.3)
        }
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { url in
            do {
                let fm = FileManager.default
                try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
                try fm.copyItem(at: url, to: destination)
            } catch {
                copyError = error
            }
        }
        if let error = coordinationError ?? copyError { throw error }
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
/// data folder can never wipe the backup.
nonisolated final class BackupScheduler: @unchecked Sendable {
    static let shared = BackupScheduler()

    private let queue = DispatchQueue(label: "me.ryham.tcc.backup", qos: .utility)
    private let lock = NSLock()
    private var pendingDeletes = Set<String>()
    private var work: DispatchWorkItem?
    private var ready = false

    /// Syncing starts only once launch (including any restore) has finished.
    func markReady() {
        lock.lock(); ready = true; lock.unlock()
        schedule(after: 2)
    }

    func noteDeletion(_ relativePath: String) {
        lock.lock(); pendingDeletes.insert(relativePath); lock.unlock()
        schedule()
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

        lock.lock(); pendingDeletes.subtract(deletes); lock.unlock()

        let fm = FileManager.default
        var failed = false
        for relative in DataFolder.dataFiles() {
            let source = DataFolder.root.appendingPathComponent(relative)
            let target = mirror.appendingPathComponent(relative)
            guard needsCopy(source: source, target: target, relative: relative) else { continue }
            do { try BackupFiles.write(source, to: target) } catch { failed = true }
        }
        for relative in deletes where BackupFiles.isDataFile(relative) {
            let target = mirror.appendingPathComponent(relative)
            if fm.fileExists(atPath: target.path) { BackupFiles.remove(target) }
        }
        if !failed { UserDefaults.standard.set(Date(), forKey: SettingsKey.lastBackup) }
    }

    private func needsCopy(source: URL, target: URL, relative: String) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: target.path) else { return true }
        // Photos never change once saved.
        if relative.hasPrefix("Photos/") { return false }
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        guard let a = try? source.resourceValues(forKeys: keys), let b = try? target.resourceValues(forKeys: keys) else { return true }
        if a.fileSize != b.fileSize { return true }
        return (a.contentModificationDate ?? .distantPast) > (b.contentModificationDate ?? .distantPast).addingTimeInterval(1)
    }
}

// MARK: - Restoring after a reinstall

@MainActor
enum BackupRestore {
    private final class Waiter: @unchecked Sendable {
        var done = false
        var observer: NSObjectProtocol?
    }

    /// Copies everything from the backup into the data folder. Returns true if anything was restored.
    static func restoreIfAvailable(progress: @escaping (Int, Int) -> Void) async -> Bool {
        let mirror = await Task.detached(priority: .userInitiated) { BackupLocation.url() }.value
        guard let mirror else { return false }

        let relatives = await backupContents(in: mirror)
        let files = relatives.filter { BackupFiles.isDataFile($0.relative) }
        guard !files.isEmpty else { return false }

        DataFolder.prepare()
        var restored = 0
        for (index, file) in files.enumerated() {
            progress(index, files.count)
            let destination = DataFolder.root.appendingPathComponent(file.relative)
            if !FileManager.default.fileExists(atPath: destination.path) {
                let source = file.url
                let ok = await Task.detached(priority: .userInitiated) { (try? BackupFiles.fetch(source, to: destination)) != nil }.value
                if ok { restored += 1 }
            }
        }
        progress(files.count, files.count)
        return restored > 0
    }

    private struct Item { let relative: String; let url: URL }

    private static func backupContents(in mirror: URL) async -> [Item] {
        let base = mirror.resolvingSymlinksInPath().path
        func relativePath(_ url: URL) -> String? {
            let path = url.resolvingSymlinksInPath().path
            guard path.hasPrefix(base + "/") else { return nil }
            return String(path.dropFirst(base.count + 1))
        }

        #if DEBUG
        if DebugLaunch.value(after: "-backupDir") != nil {
            let fm = FileManager.default
            let enumerator = fm.enumerator(at: mirror, includingPropertiesForKeys: nil)
            return (enumerator?.compactMap { $0 as? URL } ?? []).compactMap { url in
                relativePath(url).map { Item(relative: $0, url: url) }
            }
        }
        #endif

        // iCloud: ask the metadata service, which knows about files that haven't been downloaded yet.
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K LIKE '*'", NSMetadataItemFSNameKey)
        let waiter = Waiter()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiter.observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main) { _ in
                if !waiter.done { waiter.done = true; continuation.resume() }
            }
            query.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
                if !waiter.done { waiter.done = true; continuation.resume() }
            }
        }
        if let observer = waiter.observer { NotificationCenter.default.removeObserver(observer) }
        query.disableUpdates()
        let urls = (query.results as? [NSMetadataItem] ?? []).compactMap { $0.value(forAttribute: NSMetadataItemURLKey) as? URL }
        query.stop()
        return urls.compactMap { url in relativePath(url).map { Item(relative: $0, url: url) } }
    }
}

// MARK: - Launch

/// Decides at launch whether this is a fresh install that should be restored from the backup, and
/// makes sure the data is loaded before the app shows anything.
@MainActor
final class LaunchCoordinator: ObservableObject {
    enum Phase: Equatable {
        case ready
        case restoring(done: Int, total: Int)
    }

    @Published private(set) var phase: Phase = .ready
    private let store: EstimateStore

    init(store: EstimateStore, isFreshInstall: Bool) {
        self.store = store
        DataFolder.prepare()
        if isFreshInstall, DataFolder.isEmpty, BackupLocation.isEnabled, BackupLocation.isAvailable {
            phase = .restoring(done: 0, total: 0)
            Task { await restore() }
        } else {
            finish()
        }
    }

    private func restore() async {
        _ = await BackupRestore.restoreIfAvailable { [weak self] done, total in
            self?.phase = .restoring(done: done, total: total)
        }
        SettingsFile.applyIfPresent()
        finish()
    }

    private func finish() {
        store.reload()
        BackupScheduler.shared.markReady()
        phase = .ready
        #if DEBUG
        DebugLaunch.seedIfRequested(store)
        #endif
    }
}
