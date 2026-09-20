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
        // A brand-new install has nothing stored yet; we may need to restore it from the iCloud backup.
        let isFreshInstall = (UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:]).isEmpty
        AppDefaults.register()
        let store = EstimateStore()
        _store = StateObject(wrappedValue: store)
        _launch = StateObject(wrappedValue: LaunchCoordinator(store: store, isFreshInstall: isFreshInstall))

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
            .tint(Color("AccentColor"))
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            store.flush()
            // Give the iCloud copy a chance to catch up before iOS suspends the app.
            var task = UIBackgroundTaskIdentifier.invalid
            task = UIApplication.shared.beginBackgroundTask {
                UIApplication.shared.endBackgroundTask(task)
            }
            BackupScheduler.shared.syncNow {
                DispatchQueue.main.async { UIApplication.shared.endBackgroundTask(task) }
            }
        }
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
