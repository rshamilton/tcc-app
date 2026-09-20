//
//  LegacyMigration.swift
//  Tree Cost Calculator
//

import Foundation

/// Brings quotes saved by earlier versions (JSON blobs in UserDefaults with photos embedded)
/// into the current file-based store. The original data is never deleted.
nonisolated enum LegacyMigration {
    static let quotesKey = "SavedQuotes"
    static let historyKey = "SavedCalculations"
    static let logoKey = "companyLogoData"

    // MARK: Legacy shapes (decode-only)

    private struct LegacyTree: Decodable {
        var circumference: Double
        var height: Double
        var photoDataList: [Data]?
    }

    private struct LegacyQuote: Decodable {
        var id: UUID
        var name: String
        var date: Date
        var lastModified: Date?
        var trees: [LegacyTree]
        var currentTreeCircumference: Double?
        var currentTreeHeight: Double?
        var customerName: String?
        var location: String?
        var jobNotes: String?
        var startingFee: Double?
        var pricePerCubicFoot: Double?
        var taxRate: Double?
        var discountAmount: Double?
        var discountType: String?
        var additionalChargeAmount: Double?
        var additionalChargeType: String?
        var additionalChargeDescription: String?
    }

    /// Entries from the old "History" list, which is where customer name, address and notes lived.
    private struct LegacyHistoryEntry: Decodable {
        var date: Date
        var cubicFeet: Double
        var jobNotes: String?
        var customerName: String?
        var location: String?
    }

    // MARK: Conversion

    static func convert(quotesData: Data?, historyData: Data?, logoData: Data?, taxWasEnabled: Bool) -> [Estimate] {
        if let logoData, PhotoStore.loadLogo() == nil {
            _ = PhotoStore.saveLogo(logoData)
        }

        guard let quotesData else { return [] }
        let decoder = JSONDecoder()
        // Swift's default Date strategy (seconds since 2001) is what the old version wrote.
        guard let quotes = try? decoder.decode([LegacyQuote].self, from: quotesData) else { return [] }
        var history = (historyData.flatMap { try? decoder.decode([LegacyHistoryEntry].self, from: $0) }) ?? []

        let useMetric = UserDefaults.standard.bool(forKey: SettingsKey.useMetric)
        // Oldest first so numbering follows creation order.
        let ordered = quotes.sorted { $0.date < $1.date }

        return ordered.enumerated().map { offset, quote in
            var e = Estimate()
            e.id = quote.id
            e.number = offset + 1
            e.createdAt = quote.date
            e.updatedAt = quote.lastModified ?? quote.date
            e.unitSystem = useMetric ? .metric : .imperial
            e.startingFee = quote.startingFee ?? 0
            e.ratePerUnit = quote.pricePerCubicFoot ?? 0
            e.taxRate = taxWasEnabled ? (quote.taxRate ?? 0) : 0

            e.discount = Adjustment(amount: quote.discountAmount ?? 0, kind: quote.discountType == "fixed" ? .fixed : .percent)
            e.surcharge = Adjustment(amount: quote.additionalChargeAmount ?? 0, kind: quote.additionalChargeType == "percentage" ? .percent : .fixed)
            e.surchargeLabel = quote.additionalChargeDescription ?? ""

            var trees = quote.trees.map { legacy -> TreeItem in
                var tree = TreeItem(circumference: legacy.circumference, height: legacy.height)
                tree.photoIDs = (legacy.photoDataList ?? []).compactMap { PhotoStore.save($0) }
                return tree
            }
            if let c = quote.currentTreeCircumference, let h = quote.currentTreeHeight, c > 0, h > 0 {
                trees.append(TreeItem(circumference: c, height: h))
            }
            e.trees = trees.isEmpty ? [TreeItem()] : trees

            e.customerName = quote.customerName ?? ""
            e.address = quote.location ?? ""
            e.notes = quote.jobNotes ?? ""

            // Customer details were entered on the estimate screen and only saved to History.
            if e.customerName.isEmpty, e.address.isEmpty, e.notes.isEmpty {
                let volume = e.totals.volume
                let matchIndex = history.indices
                    .filter { abs(history[$0].cubicFeet - volume) < 0.01 && history[$0].date >= quote.date.addingTimeInterval(-1) }
                    .min { abs(history[$0].date.timeIntervalSince(e.updatedAt)) < abs(history[$1].date.timeIntervalSince(e.updatedAt)) }
                if let i = matchIndex {
                    let match = history.remove(at: i)
                    e.customerName = match.customerName ?? ""
                    e.address = match.location ?? ""
                    e.notes = match.jobNotes ?? ""
                }
            }

            // A quote's own name is useful context, so keep it if it says something new.
            let name = quote.name.trimmed
            if !name.isEmpty, name != "Untitled Quote", name != e.customerName {
                if e.customerName.isEmpty {
                    e.customerName = name
                } else {
                    e.notes = e.notes.isEmpty ? "Job: \(name)" : "Job: \(name)\n\(e.notes)"
                }
            }
            return e
        }
    }
}
