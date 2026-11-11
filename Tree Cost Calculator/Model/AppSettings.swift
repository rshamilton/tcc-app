//
//  AppSettings.swift
//  Tree Cost Calculator
//

import Foundation

/// UserDefaults keys. The first group keeps the names used by earlier versions so
/// existing users' settings carry over untouched.
nonisolated enum SettingsKey {
    static let startingFee = "startingFee"
    static let ratePerUnit = "pricePerCubicFoot"
    static let taxRate = "taxRate"
    static let useMetric = "useMetric"
    static let companyName = "companyName"
    static let onboarded = "hasCompletedOnboarding"
    static let includePhotos = "includePhotoInPDF"
    static let itemizeTrees = "showIndividualTrees"

    static let companyPhone = "companyPhone"
    static let companyEmail = "companyEmail"
    static let companyAddress = "companyAddress"
    static let companyLicense = "companyLicense"
    static let taxRegions = "taxRegions"
    static let validDays = "estimateValidDays"
    static let terms = "estimateTerms"
    static let nextNumber = "nextEstimateNumber"
    static let migratedLegacy = "didMigrateLegacyData"
    static let iCloudBackup = "iCloudBackupEnabled"
    static let lastBackup = "lastBackupDate"
    /// Whether this device keeps the backup's settings and logo up to date (see `LaunchCoordinator`).
    static let backupLinked = "backupLinkedToThisDevice"

    /// Saved services price list (`ServiceList` JSON).
    static let services = "serviceList"
    /// Days after the invoice date that payment is due (0 = due on receipt).
    static let invoiceDueDays = "invoiceDueDays"
    /// Payment instructions printed on invoices (bank details, accepted payment methods…).
    static let paymentInstructions = "paymentInstructions"

    // Review prompt bookkeeping (device-only; not copied to Settings.json).
    static let sharedCount = "sharedDocumentCount"
    static let firstUse = "firstUseDate"
    static let reviewRequestedVersion = "reviewRequestedForVersion"
}

enum AppDefaults {
    static let defaultTerms = "Price is based on the tree measurements above. Final price may change if site conditions differ from what was described or measured. Payment is due upon completion of the work."

    static func register() {
        UserDefaults.standard.register(defaults: registered)
    }

    /// The default value of every setting (also used to tell which ones the user has changed).
    nonisolated static let registered: [String: Any] = [
            SettingsKey.startingFee: 0.0,
            SettingsKey.ratePerUnit: 10.0,
            SettingsKey.taxRate: 0.0,
            SettingsKey.useMetric: false,
            SettingsKey.onboarded: false,
            SettingsKey.includePhotos: true,
            SettingsKey.itemizeTrees: true,
            SettingsKey.taxRegions: "[]",
            SettingsKey.iCloudBackup: true,
            SettingsKey.validDays: 30,
            SettingsKey.terms: defaultTerms,
            SettingsKey.nextNumber: 1,
            SettingsKey.services: ServiceList(items: ServiceList.starter).rawValue,
            SettingsKey.invoiceDueDays: 14,
            SettingsKey.paymentInstructions: ""
    ]
}

/// Snapshot of the business details printed on every estimate.
nonisolated struct BusinessProfile: Sendable {
    var name: String
    var phone: String
    var email: String
    var address: String
    var terms: String
    var validDays: Int
    var includePhotos: Bool
    var itemizeTrees: Bool
    var invoiceDueDays: Int
    var paymentInstructions: String

    static func current() -> BusinessProfile {
        let d = UserDefaults.standard
        return BusinessProfile(
            name: (d.string(forKey: SettingsKey.companyName) ?? "").trimmed,
            phone: (d.string(forKey: SettingsKey.companyPhone) ?? "").trimmed,
            email: (d.string(forKey: SettingsKey.companyEmail) ?? "").trimmed,
            address: (d.string(forKey: SettingsKey.companyAddress) ?? "").trimmed,
            terms: (d.string(forKey: SettingsKey.terms) ?? "").trimmed,
            validDays: d.integer(forKey: SettingsKey.validDays),
            includePhotos: d.bool(forKey: SettingsKey.includePhotos),
            itemizeTrees: d.bool(forKey: SettingsKey.itemizeTrees),
            invoiceDueDays: d.integer(forKey: SettingsKey.invoiceDueDays),
            paymentInstructions: (d.string(forKey: SettingsKey.paymentInstructions) ?? "").trimmed
        )
    }
}
