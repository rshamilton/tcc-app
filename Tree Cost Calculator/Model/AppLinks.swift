//
//  AppLinks.swift
//  Tree Cost Calculator
//

import Foundation

/// Every web address and contact the app shows. The website and the source code are public.
enum AppLinks {
    static let website = URL(string: "https://rshamilton.github.io/treecostcalculator/")!
    static let support = URL(string: "https://rshamilton.github.io/treecostcalculator/support")!
    static let privacy = URL(string: "https://rshamilton.github.io/treecostcalculator/privacy")!
    static let terms = URL(string: "https://rshamilton.github.io/treecostcalculator/terms")!
    static let supportEmail = "treecostcalculator@googlegroups.com"

    /// The app's open-source code (GPL-3.0).
    static let sourceCode = URL(string: "https://github.com/rshamilton/tcc-app")!
    /// Bug reports and feature requests.
    static let issues = URL(string: "https://github.com/rshamilton/tcc-app/issues")!
    static let license = URL(string: "https://github.com/rshamilton/tcc-app/blob/main/LICENSE")!

    static let appStoreID = "6760602763"
    /// Opens the App Store straight to "Write a Review" (only ever from a button the user taps).
    static let writeReview = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
    /// The App Store page, for sharing the app with someone else.
    static let appStore = URL(string: "https://apps.apple.com/app/id\(appStoreID)")!

    static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
