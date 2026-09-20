//
//  Estimate.swift
//  Tree Cost Calculator
//

import Foundation
import SwiftUI

// MARK: - Units

nonisolated enum UnitSystem: String, Codable, CaseIterable, Identifiable {
    case imperial
    case metric

    var id: String { rawValue }

    var lengthUnit: String { self == .imperial ? "ft" : "m" }
    var volumeUnit: String { self == .imperial ? "cu ft" : "m³" }
    var lengthName: String { self == .imperial ? "Feet" : "Meters" }
}

// MARK: - Status

nonisolated enum EstimateStatus: String, Codable, CaseIterable, Identifiable {
    case draft
    case sent
    case approved
    case declined

    var id: String { rawValue }

    var title: String {
        switch self {
        case .draft: "Draft"
        case .sent: "Sent"
        case .approved: "Approved"
        case .declined: "Declined"
        }
    }

    var symbol: String {
        switch self {
        case .draft: "pencil.circle.fill"
        case .sent: "paperplane.circle.fill"
        case .approved: "checkmark.circle.fill"
        case .declined: "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .draft: .gray
        case .sent: .blue
        case .approved: .green
        case .declined: .red
        }
    }

    /// Estimates that are still waiting on a decision.
    var isOpen: Bool { self == .draft || self == .sent }
}

// MARK: - Adjustments (discount / additional charge)

nonisolated enum AdjustmentKind: String, Codable, CaseIterable, Identifiable {
    case fixed
    case percent

    var id: String { rawValue }
}

nonisolated struct Adjustment: Codable, Equatable {
    var amount: Double = 0
    var kind: AdjustmentKind = .fixed

    /// The currency value of this adjustment when applied to `base`.
    func value(on base: Double) -> Double {
        guard amount > 0 else { return 0 }
        switch kind {
        case .fixed: return amount.roundedToCents
        case .percent: return (base * amount / 100).roundedToCents
        }
    }
}

extension Double {
    nonisolated var roundedToCents: Double { (self * 100).rounded() / 100 }
}

// MARK: - Tax regions

/// A state or area the business works in, with its tax rate and (optionally) the license number to
/// print on estimates for work done there.
nonisolated struct TaxRegion: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
    var rate = 0.0
    var license = ""
}

/// Storable list of regions (kept in UserDefaults so `@AppStorage` can use it directly).
nonisolated struct TaxRegionList: RawRepresentable, Equatable {
    var items: [TaxRegion]

    init(items: [TaxRegion] = []) { self.items = items }

    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([TaxRegion].self, from: data) else { return nil }
        items = decoded
    }

    var rawValue: String {
        guard let data = try? JSONEncoder().encode(items), let text = String(data: data, encoding: .utf8) else { return "[]" }
        return text
    }
}

// MARK: - Tree

nonisolated struct TreeItem: Identifiable, Codable, Equatable {
    /// Volume divisor used since v1: circumference² × height ÷ 12.56 (≈ 4π).
    static let volumeDivisor = 12.56

    var id = UUID()
    /// Optional description, e.g. "Oak by the driveway".
    var label: String = ""
    var circumference: Double = 0
    var height: Double = 0
    var photoIDs: [UUID] = []

    var isMeasured: Bool { circumference > 0 && height > 0 }

    var volume: Double {
        guard isMeasured else { return 0 }
        return circumference * circumference * height / Self.volumeDivisor
    }

    init(id: UUID = UUID(), label: String = "", circumference: Double = 0, height: Double = 0, photoIDs: [UUID] = []) {
        self.id = id
        self.label = label
        self.circumference = circumference
        self.height = height
        self.photoIDs = photoIDs
    }

    private enum CodingKeys: String, CodingKey {
        case id, label, circumference, height, photoIDs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? ""
        circumference = try c.decodeIfPresent(Double.self, forKey: .circumference) ?? 0
        height = try c.decodeIfPresent(Double.self, forKey: .height) ?? 0
        photoIDs = try c.decodeIfPresent([UUID].self, forKey: .photoIDs) ?? []
    }
}

// MARK: - Totals

nonisolated struct EstimateTotals: Equatable {
    var volume: Double = 0
    var volumeCost: Double = 0
    var startingFee: Double = 0
    var surcharge: Double = 0
    var subtotal: Double = 0
    var discount: Double = 0
    var tax: Double = 0
    var total: Double = 0
}

// MARK: - Estimate

nonisolated struct Estimate: Identifiable, Codable, Equatable {
    var id = UUID()
    /// Sequential number shown to the customer, e.g. EST-0007.
    var number: Int = 1
    var status: EstimateStatus = .draft
    var createdAt = Date()
    var updatedAt = Date()

    // Customer & job site
    var customerName = ""
    var customerPhone = ""
    var customerEmail = ""
    var address = ""

    // Work
    var trees: [TreeItem] = []
    var sitePhotoIDs: [UUID] = []
    var notes = ""

    // Pricing (snapshotted from Settings when the estimate is created)
    var unitSystem: UnitSystem = .imperial
    var startingFee: Double = 0
    var ratePerUnit: Double = 0
    var taxRate: Double = 0
    /// The tax region this rate came from (name and rate are snapshots), if one was chosen.
    var regionName = ""
    var regionRate: Double = 0
    /// Contractor license / registration number printed on the estimate.
    var licenseNumber = ""
    var surcharge = Adjustment(amount: 0, kind: .fixed)
    var surchargeLabel = ""
    var discount = Adjustment(amount: 0, kind: .percent)

    init() {}

    // MARK: Derived

    var numberLabel: String { String(format: "EST-%04d", number) }

    /// True while the tax rate still matches the region it was taken from.
    var taxRegionApplies: Bool { !regionName.isEmpty && abs(regionRate - taxRate) < 0.0001 }

    var measuredTreeCount: Int { trees.filter(\.isMeasured).count }

    var hasMeasuredTree: Bool { trees.contains(where: \.isMeasured) }

    /// Name used in lists and file names.
    var displayName: String {
        let name = customerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Untitled Estimate" : name
    }

    /// True when the user hasn't entered anything worth keeping.
    var isBlank: Bool {
        customerName.trimmed.isEmpty
            && customerPhone.trimmed.isEmpty
            && customerEmail.trimmed.isEmpty
            && address.trimmed.isEmpty
            && notes.trimmed.isEmpty
            && sitePhotoIDs.isEmpty
            && trees.allSatisfy { $0.circumference == 0 && $0.height == 0 && $0.label.trimmed.isEmpty && $0.photoIDs.isEmpty }
    }

    var allPhotoIDs: [UUID] { sitePhotoIDs + trees.flatMap(\.photoIDs) }

    /// All money is rounded to whole cents at each step so the lines on screen and on
    /// the PDF always add up to exactly the total.
    var totals: EstimateTotals {
        var t = EstimateTotals()
        t.volume = trees.reduce(0) { $0 + $1.volume }
        t.volumeCost = (t.volume * ratePerUnit).roundedToCents
        t.startingFee = startingFee.roundedToCents
        let base = (t.startingFee + t.volumeCost).roundedToCents
        t.surcharge = surcharge.value(on: base)
        t.subtotal = (base + t.surcharge).roundedToCents
        t.discount = min(discount.value(on: t.subtotal), t.subtotal)
        let afterDiscount = (t.subtotal - t.discount).roundedToCents
        t.tax = taxRate > 0 ? (afterDiscount * taxRate / 100).roundedToCents : 0
        t.total = (afterDiscount + t.tax).roundedToCents
        return t
    }

    // MARK: Codable (lenient, so future versions can add fields safely)

    private enum CodingKeys: String, CodingKey {
        case id, number, status, createdAt, updatedAt
        case customerName, customerPhone, customerEmail, address
        case trees, sitePhotoIDs, notes
        case unitSystem, startingFee, ratePerUnit, taxRate
        case regionName, regionRate, licenseNumber
        case surcharge, surchargeLabel, discount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        number = try c.decodeIfPresent(Int.self, forKey: .number) ?? 1
        status = try c.decodeIfPresent(EstimateStatus.self, forKey: .status) ?? .draft
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        customerName = try c.decodeIfPresent(String.self, forKey: .customerName) ?? ""
        customerPhone = try c.decodeIfPresent(String.self, forKey: .customerPhone) ?? ""
        customerEmail = try c.decodeIfPresent(String.self, forKey: .customerEmail) ?? ""
        address = try c.decodeIfPresent(String.self, forKey: .address) ?? ""
        trees = try c.decodeIfPresent([TreeItem].self, forKey: .trees) ?? []
        sitePhotoIDs = try c.decodeIfPresent([UUID].self, forKey: .sitePhotoIDs) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        unitSystem = try c.decodeIfPresent(UnitSystem.self, forKey: .unitSystem) ?? .imperial
        startingFee = try c.decodeIfPresent(Double.self, forKey: .startingFee) ?? 0
        ratePerUnit = try c.decodeIfPresent(Double.self, forKey: .ratePerUnit) ?? 0
        taxRate = try c.decodeIfPresent(Double.self, forKey: .taxRate) ?? 0
        regionName = try c.decodeIfPresent(String.self, forKey: .regionName) ?? ""
        regionRate = try c.decodeIfPresent(Double.self, forKey: .regionRate) ?? 0
        licenseNumber = try c.decodeIfPresent(String.self, forKey: .licenseNumber) ?? ""
        surcharge = try c.decodeIfPresent(Adjustment.self, forKey: .surcharge) ?? Adjustment(amount: 0, kind: .fixed)
        surchargeLabel = try c.decodeIfPresent(String.self, forKey: .surchargeLabel) ?? ""
        discount = try c.decodeIfPresent(Adjustment.self, forKey: .discount) ?? Adjustment(amount: 0, kind: .percent)
    }
}

extension String {
    nonisolated var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
