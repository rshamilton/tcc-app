//
//  Tree_Cost_CalculatorApp.swift
//  Tree Cost Calculator
//
//  Created by Ryan Hamilton on 1/9/26.
//

import SwiftUI

@main
struct Tree_Cost_CalculatorApp: App {
    @AppStorage(SettingsKey.onboarded) private var hasCompletedOnboarding = false
    @StateObject private var store: EstimateStore
    @StateObject private var launch: LaunchCoordinator
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        DebugLaunch.simulateFreshInstallIfRequested()
        #endif
        AppDefaults.register()
        let store = EstimateStore()
        _store = StateObject(wrappedValue: store)
        // Loads the data (restoring it from the iCloud backup first if this device has none yet). Created
        // here rather than inside StateObject's lazy closure, which runs during a view update.
        let launch = LaunchCoordinator(store: store)
        _launch = StateObject(wrappedValue: launch)

        // Keep a copy of the settings in the data folder so they survive a reinstall too.
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: nil) { _ in
            SettingsFile.scheduleWrite()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch launch.phase {
                case .restoring(let done, let total):
                    RestoringView(done: done, total: total)
                case .ready:
                    if hasCompletedOnboarding {
                        EstimatesListView()
                            .transition(.opacity)
                    } else {
                        OnboardingView {
                            withAnimation(.easeInOut(duration: 0.3)) { hasCompletedOnboarding = true }
                        }
                        .transition(.opacity)
                    }
                }
            }
            .environmentObject(store)
            .environmentObject(launch)
            .tint(Color("AccentColor"))
            .alert("Restore from iCloud?", isPresented: offerShown, presenting: launch.backupOffer) { _ in
                Button("Restore") { launch.restoreFromBackup() }
                Button("Don't Restore", role: .cancel) { launch.declineBackup() }
            } message: { offer in
                Text(offer.estimates > 0
                     ? "Your iCloud Drive backup has \(offer.estimates) \(offer.estimates == 1 ? "estimate" : "estimates") that aren't on this device. Restore them, with their photos and your settings?"
                     : "Your iCloud Drive backup has settings from another device. Restore them?")
                + Text(" If you don't, this device's settings replace the ones in the backup.")
            }
            .alert("Restore from iCloud", isPresented: messageShown) {
                Button("OK") {}
            } message: {
                Text(launch.restoreMessage ?? "")
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .inactive:
                store.flush()
            case .background:
                store.flush()
                syncBackupBeforeSuspending()
            default:
                break
            }
        }
    }

    private var offerShown: Binding<Bool> {
        Binding(get: { launch.backupOffer != nil }, set: { if !$0 { launch.backupOffer = nil } })
    }

    private var messageShown: Binding<Bool> {
        Binding(get: { launch.restoreMessage != nil }, set: { if !$0 { launch.restoreMessage = nil } })
    }

    /// Gives the iCloud copy a chance to catch up before iOS suspends the app.
    private func syncBackupBeforeSuspending() {
        let task = BackgroundTask()
        task.id = UIApplication.shared.beginBackgroundTask { task.end() }
        BackupScheduler.shared.syncNow {
            DispatchQueue.main.async { task.end() }
        }
    }
}

/// Ends a background task exactly once, whichever of "finished" and "out of time" comes first.
private final class BackgroundTask: @unchecked Sendable {
    var id = UIBackgroundTaskIdentifier.invalid

    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}

/// Shown briefly on a fresh install while data is copied back from the iCloud backup.
struct RestoringView: View {
    let done: Int
    let total: Int

    var body: some View {
        VStack(spacing: 22) {
            BrandTile()
                .frame(width: 110, height: 110)
                .shadow(color: Color.accentColor.opacity(0.35), radius: 16, y: 8)
            VStack(spacing: 6) {
                Text("Restoring your data")
                    .font(.title3.weight(.bold))
                Text(total > 0 ? "Getting your estimates and photos back from iCloud (\(min(done + 1, total)) of \(total))…"
                               : "Checking iCloud for your estimates…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
            if total > 0 {
                ProgressView(value: Double(done), total: Double(total))
                    .frame(maxWidth: 240)
            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}
