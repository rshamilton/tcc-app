//
//  ReviewPrompter.swift
//  Tree Cost Calculator
//

import Foundation

/// Decides when to show Apple's standard "rate this app" prompt (`requestReview`). Following Apple's
/// guidance, it is only considered right after something went well (the user shared an estimate or
/// invoice), never at launch or in the middle of a task, at most once per app version, and only after
/// the app has been used for a while. iOS itself also limits the prompt to three times a year and may
/// choose not to show it. Nothing here is required to use the app, and nothing is offered in return.
@MainActor
enum ReviewPrompter {
    /// Shares needed before the first prompt.
    static let sharesBeforeAsking = 3
    /// Days since first use before the first prompt.
    static let daysBeforeAsking = 3

    private static var defaults: UserDefaults { .standard }

    private static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Call once at launch.
    static func noteLaunch(now: Date = Date()) {
        if defaults.object(forKey: SettingsKey.firstUse) == nil {
            defaults.set(now, forKey: SettingsKey.firstUse)
        }
    }

    /// Call when the user has successfully shared, printed or saved a PDF. Returns true if this is a good
    /// moment to call `requestReview()`; the caller should then do so and call `didRequest()`.
    static func noteSuccessfulShare(now: Date = Date()) -> Bool {
        let count = defaults.integer(forKey: SettingsKey.sharedCount) + 1
        defaults.set(count, forKey: SettingsKey.sharedCount)
        return shouldAsk(shareCount: count, now: now)
    }

    static func didRequest() {
        defaults.set(currentVersion, forKey: SettingsKey.reviewRequestedVersion)
    }

    static func shouldAsk(shareCount: Int, now: Date) -> Bool {
        guard shareCount >= sharesBeforeAsking else { return false }
        guard defaults.string(forKey: SettingsKey.reviewRequestedVersion) != currentVersion else { return false }
        let first = defaults.object(forKey: SettingsKey.firstUse) as? Date ?? now
        return now.timeIntervalSince(first) >= Double(daysBeforeAsking) * 86_400
    }
}
