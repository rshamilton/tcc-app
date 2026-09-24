//
//  DebugLaunch.swift
//  Tree Cost Calculator
//

#if DEBUG
import UIKit

/// Development-only launch arguments used to open the app in a known state (for screenshots and
/// UI checks). None of this is compiled into release builds.
///
///   -resetOnboarding     show onboarding again
///   -resetData           delete all estimates
///   -demoData            replace all estimates with sample data
///   -openEstimate N      push the Nth estimate (0 = newest) on launch
///   -showSettings        present Settings on launch
///   -showPreview         open the PDF preview when the editor appears
///   -onboardingPage N    start onboarding on page N
///   -backupDir <path>    use this folder instead of iCloud Drive for the backup
///   -simulateFreshInstall  wipe the data folder and settings first, as if the app was just installed
///   -linkBackup          let this device update the backup's settings and logo straight away
nonisolated enum DebugLaunch {
    private static let args = ProcessInfo.processInfo.arguments

    static func value(after flag: String) -> String? {
        guard let i = args.firstIndex(of: flag), args.indices.contains(i + 1) else { return nil }
        return args[i + 1]
    }

    static func has(_ flag: String) -> Bool { args.contains(flag) }

    static var openEstimateIndex: Int? { value(after: "-openEstimate").flatMap(Int.init) }
    static var showSettings: Bool { has("-showSettings") }
    static var showPreview: Bool { has("-showPreview") }
    static var onboardingPage: Int { value(after: "-onboardingPage").flatMap(Int.init) ?? 0 }

    /// Runs before anything is loaded.
    static func simulateFreshInstallIfRequested() {
        guard has("-simulateFreshInstall") else { return }
        let fm = FileManager.default
        for url in (try? fm.contentsOfDirectory(at: DataFolder.root, includingPropertiesForKeys: nil)) ?? [] {
            try? fm.removeItem(at: url)
        }
        if let domain = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: domain) }
    }

    @MainActor
    static func seedIfRequested(_ store: EstimateStore) {
        if has("-linkBackup") {
            UserDefaults.standard.set(true, forKey: SettingsKey.backupLinked)
        }
        if has("-resetOnboarding") {
            UserDefaults.standard.set(false, forKey: SettingsKey.onboarded)
        }
        if has("-resetData") {
            for e in store.estimates { store.delete(id: e.id) }
            UserDefaults.standard.set(1, forKey: SettingsKey.nextNumber)
            store.flush()
        }
        guard has("-demoData") else { return }
        for e in store.estimates { store.delete(id: e.id) }
        UserDefaults.standard.set(1, forKey: SettingsKey.nextNumber)
        // Saved like a real user finishing onboarding (a launch argument alone isn't backed up).
        UserDefaults.standard.set(true, forKey: SettingsKey.onboarded)
        UserDefaults.standard.set("Oakridge Tree Service", forKey: SettingsKey.companyName)
        UserDefaults.standard.set("(555) 014-2290", forKey: SettingsKey.companyPhone)
        UserDefaults.standard.set("quotes@oakridgetree.example", forKey: SettingsKey.companyEmail)
        UserDefaults.standard.set("48 Mill Road, Springfield", forKey: SettingsKey.companyAddress)
        UserDefaults.standard.set(15.0, forKey: SettingsKey.ratePerUnit)
        UserDefaults.standard.set(150.0, forKey: SettingsKey.startingFee)
        UserDefaults.standard.set(8.5, forKey: SettingsKey.taxRate)
        UserDefaults.standard.set("ISA-TX-4471", forKey: SettingsKey.companyLicense)
        UserDefaults.standard.set(TaxRegionList(items: [
            TaxRegion(name: "Texas", rate: 6.25, license: "TX-TCLB-90211"),
            TaxRegion(name: "Oklahoma", rate: 4.5, license: "")
        ]).rawValue, forKey: SettingsKey.taxRegions)

        // Illustrative sample photos: a simple tree scene in a few moods.
        func photo(_ hue: CGFloat) -> UUID? {
            let size = CGSize(width: 1200, height: 900)
            let img = UIGraphicsImageRenderer(size: size).image { ctx in
                let cg = ctx.cgContext
                let space = CGColorSpaceCreateDeviceRGB()
                func gradient(_ colors: [UIColor], _ rect: CGRect) {
                    let g = CGGradient(colorsSpace: space, colors: colors.map(\.cgColor) as CFArray, locations: nil)!
                    cg.saveGState(); cg.clip(to: rect)
                    cg.drawLinearGradient(g, start: CGPoint(x: 0, y: rect.minY), end: CGPoint(x: 0, y: rect.maxY), options: [])
                    cg.restoreGState()
                }
                gradient([UIColor(red: 0.55, green: 0.76, blue: 0.93, alpha: 1), UIColor(red: 0.86, green: 0.93, blue: 0.97, alpha: 1)], CGRect(x: 0, y: 0, width: 1200, height: 640))
                gradient([UIColor(red: 0.36, green: 0.58, blue: 0.27, alpha: 1), UIColor(red: 0.22, green: 0.42, blue: 0.19, alpha: 1)], CGRect(x: 0, y: 620, width: 1200, height: 280))
                UIColor(red: 0.36, green: 0.25, blue: 0.16, alpha: 1).setFill()
                let trunk = UIBezierPath()
                trunk.move(to: CGPoint(x: 560, y: 340)); trunk.addLine(to: CGPoint(x: 640, y: 340))
                trunk.addLine(to: CGPoint(x: 668, y: 700)); trunk.addLine(to: CGPoint(x: 532, y: 700)); trunk.close()
                trunk.fill()
                let canopy = UIColor(hue: 0.30 - hue * 0.12, saturation: 0.55, brightness: 0.45, alpha: 1)
                let light = UIColor(hue: 0.30 - hue * 0.12, saturation: 0.50, brightness: 0.62, alpha: 1)
                for (x, y, r) in [(600.0, 240.0, 190.0), (470.0, 300.0, 150.0), (740.0, 300.0, 150.0), (560.0, 380.0, 130.0), (660.0, 380.0, 130.0)] {
                    canopy.setFill(); cg.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
                    light.setFill(); cg.fillEllipse(in: CGRect(x: x - r * 0.7, y: y - r * 0.85, width: r * 1.2, height: r * 1.1))
                }
            }
            return img.jpegData(compressionQuality: 0.85).flatMap { PhotoStore.save($0) }
        }

        // A made-up company logo.
        let logo = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300)).image { ctx in
            UIColor(red: 0.08, green: 0.32, blue: 0.22, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 300, height: 300), cornerRadius: 60).fill()
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 95, y: 50, width: 110, height: 110))
            UIBezierPath(rect: CGRect(x: 142, y: 150, width: 16, height: 40)).fill()
            let text = "OAKRIDGE" as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 34, weight: .heavy), .foregroundColor: UIColor.white, .kern: 3]
            let w = text.size(withAttributes: attrs).width
            text.draw(at: CGPoint(x: (300 - w) / 2, y: 218), withAttributes: attrs)
        }
        if let data = logo.pngData() { _ = PhotoStore.saveLogo(data) }

        let cal = Calendar.current
        func ago(days: Int = 0, hours: Int = 0) -> Date {
            cal.date(byAdding: .hour, value: -(days * 24 + hours), to: Date())!
        }
        /// Saves an estimate with fixed dates so the list reads naturally.
        func finish(_ e: Estimate, created: Date, updated: Date) {
            var e = e
            e.createdAt = created
            store.update(e)
            if var saved = store.estimate(id: e.id) { saved.updatedAt = updated; store.debugReplace(saved) }
        }

        // Oldest first, since new estimates are inserted at the top.
        var third = store.createEstimate()
        third.customerName = "Marcus Lee"
        third.address = "9 Birch Lane"
        third.trees = [TreeItem(label: "Leaning pine", circumference: 4.5, height: 45)]
        third.status = .declined
        finish(third, created: ago(days: 11), updated: ago(days: 9))

        var second = store.createEstimate()
        second.customerName = "Priya Raman"
        second.customerPhone = "(555) 010-7781"
        second.address = "210 Harbor View Dr, Springfield"
        second.trees = [
            TreeItem(label: "Silver maple, back yard", circumference: 7.2, height: 55, photoIDs: [photo(0.35), photo(0.1)].compactMap { $0 }),
            TreeItem(label: "Dead ash near fence", circumference: 4.0, height: 38)
        ]
        second.status = .approved
        second.discount = Adjustment(amount: 10, kind: .percent)
        second.surcharge = Adjustment(amount: 275, kind: .fixed)
        second.surchargeLabel = "Stump grinding"
        second.notes = "Gate code 4471. Keep clear of the pool fence.\nHaul away all debris and chip the small limbs."
        finish(second, created: ago(days: 5), updated: ago(days: 3))

        var fourth = store.createEstimate()
        fourth.customerName = "Sam Okafor"
        fourth.address = "77 Cedar Court"
        fourth.trees = [TreeItem(label: "Storm-damaged elm", circumference: 5.5, height: 42)]
        fourth.status = .approved
        finish(fourth, created: ago(days: 7), updated: ago(days: 6))

        var fifth = store.createEstimate()
        fifth.customerName = "Lena Ortiz"
        fifth.address = "14 Willow Way"
        fifth.trees = [TreeItem(label: "Front yard oak", circumference: 8.0, height: 60), TreeItem(label: "Two small cedars", circumference: 2.5, height: 22)]
        fifth.status = .sent
        finish(fifth, created: ago(days: 2), updated: ago(days: 1))

        var first = store.createEstimate()
        first.customerName = "Jordan Ellis"
        first.customerPhone = "(555) 012-4408"
        first.customerEmail = "jordan.ellis@example.com"
        first.address = "42 Oak Street, Springfield"
        first.trees = [
            TreeItem(label: "Red oak by driveway", circumference: 6.0, height: 50, photoIDs: [photo(0.55)].compactMap { $0 }),
            TreeItem(label: "", circumference: 3.5, height: 28),
            TreeItem(label: "Crabapple", circumference: 2.5, height: 18)
        ]
        first.sitePhotoIDs = [photo(0.75)].compactMap { $0 }
        first.status = .sent
        first.taxRate = 6.25
        first.regionName = "Texas"
        first.regionRate = 6.25
        first.licenseNumber = "TX-TCLB-90211"
        first.notes = "Customer wants the wood left on site."
        finish(first, created: ago(hours: 5), updated: ago(hours: 2))
        store.flush()
    }
}
#endif
