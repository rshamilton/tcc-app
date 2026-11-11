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
    /// The job is done and an invoice has been sent.
    case invoiced
    /// The invoice has been paid in full.
    case paid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .draft: "Draft"
        case .sent: "Sent"
        case .approved: "Approved"
        case .declined: "Declined"
        case .invoiced: "Invoiced"
        case .paid: "Paid"
        }
    }

    var symbol: String {
        switch self {
        case .draft: "pencil.circle.fill"
        case .sent: "paperplane.circle.fill"
        case .approved: "checkmark.circle.fill"
        case .declined: "xmark.circle.fill"
        case .invoiced: "doc.text.fill"
        case .paid: "dollarsign.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .draft: .gray
        case .sent: .blue
        case .approved: .green
        case .declined: .red
        case .invoiced: .purple
        case .paid: .teal
        }
    }

    /// Estimates that are still waiting on a decision.
    var isOpen: Bool { self == .draft || self == .sent }

    /// Work the customer has agreed to (approved, invoiced or paid).
    var isWon: Bool { self == .approved || self == .invoiced || self == .paid }

    /// True when the document sent to the customer is an invoice rather than an estimate.
    var isInvoice: Bool { self == .invoiced || self == .paid }
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

    init(amount: Double = 0, kind: AdjustmentKind = .fixed) {
        self.amount = amount
        self.kind = kind
    }

    private enum CodingKeys: String, CodingKey { case amount, kind }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        amount = (try? c.decodeIfPresent(Double.self, forKey: .amount)) ?? 0
        kind = c.lenient(AdjustmentKind.self, .kind) ?? .fixed
    }

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

// MARK: - Line items

/// Any work priced apart from tree volume: stump grinding, trimming, hauling, crew hours, crane time…
/// Priced as quantity × unit price, never less than `minimum` (e.g. a stump grinding minimum charge).
nonisolated struct LineItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
    var quantity: Double = 1
    /// Short unit shown after the quantity, e.g. "in", "hr", "load". Empty for a plain count.
    var unit = ""
    var unitPrice: Double = 0
    var minimum: Double = 0

    init(id: UUID = UUID(), name: String = "", quantity: Double = 1, unit: String = "", unitPrice: Double = 0, minimum: Double = 0) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
        self.minimum = minimum
    }

    init(service: ServiceItem) {
        self.init(name: service.name, quantity: 1, unit: service.unit, unitPrice: service.unitPrice, minimum: service.minimum)
    }

    /// The price of this line, in currency.
    var amount: Double {
        let raw = (quantity * unitPrice).roundedToCents
        guard raw > 0 || minimum > 0 else { return 0 }
        return max(raw, minimum.roundedToCents)
    }

    /// True when the minimum charge, not quantity × price, sets the amount.
    var usesMinimum: Bool { minimum > 0 && (quantity * unitPrice).roundedToCents < minimum.roundedToCents }

    var displayName: String { name.trimmed.isEmpty ? "Other work" : name.trimmed }

    private enum CodingKeys: String, CodingKey { case id, name, quantity, unit, unitPrice, minimum }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        quantity = (try? c.decodeIfPresent(Double.self, forKey: .quantity)) ?? 1
        unit = (try? c.decodeIfPresent(String.self, forKey: .unit)) ?? ""
        unitPrice = (try? c.decodeIfPresent(Double.self, forKey: .unitPrice)) ?? 0
        minimum = (try? c.decodeIfPresent(Double.self, forKey: .minimum)) ?? 0
    }
}

/// A saved service in the user's price list (Settings ▸ Services), added to estimates as a `LineItem`.
nonisolated struct ServiceItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
    var unit = ""
    var unitPrice: Double = 0
    var minimum: Double = 0
}

/// Storable price list (kept in UserDefaults so `@AppStorage` can use it directly).
nonisolated struct ServiceList: RawRepresentable, Equatable {
    var items: [ServiceItem]

    init(items: [ServiceItem] = []) { self.items = items }

    init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([ServiceItem].self, from: data) else { return nil }
        items = decoded
    }

    var rawValue: String {
        guard let data = try? JSONEncoder().encode(items), let text = String(data: data, encoding: .utf8) else { return "[]" }
        return text
    }

    /// Common tree-service extras, offered until the user edits the list. Prices start at zero: every
    /// business sets its own.
    static let starter: [ServiceItem] = [
        ServiceItem(name: "Stump grinding", unit: "in", unitPrice: 0, minimum: 0),
        ServiceItem(name: "Trimming / pruning", unit: "tree", unitPrice: 0),
        ServiceItem(name: "Haul away debris", unit: "load", unitPrice: 0),
        ServiceItem(name: "Crew labor", unit: "hr", unitPrice: 0),
        ServiceItem(name: "Crane / bucket truck", unit: "hr", unitPrice: 0),
        ServiceItem(name: "Emergency / storm call-out", unit: "", unitPrice: 0)
    ]
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
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        label = (try? c.decodeIfPresent(String.self, forKey: .label)) ?? ""
        circumference = (try? c.decodeIfPresent(Double.self, forKey: .circumference)) ?? 0
        height = (try? c.decodeIfPresent(Double.self, forKey: .height)) ?? 0
        photoIDs = (try? c.decodeIfPresent([UUID].self, forKey: .photoIDs)) ?? []
    }
}

// MARK: - Totals

nonisolated struct EstimateTotals: Equatable {
    var volume: Double = 0
    var volumeCost: Double = 0
    var startingFee: Double = 0
    /// Sum of all line items (stump grinding, trimming, hauling…).
    var lineItems: Double = 0
    var surcharge: Double = 0
    var subtotal: Double = 0
    var discount: Double = 0
    var tax: Double = 0
    var total: Double = 0
    /// Deposit requested on acceptance (0 if none).
    var deposit: Double = 0
    /// Amount already received.
    var paid: Double = 0
    /// What the customer still owes: total minus amount paid.
    var balanceDue: Double = 0
}

// MARK: - Estimate

nonisolated struct Estimate: Identifiable, Codable, Equatable {
    var id = UUID()
    /// Sequential number shown to the customer, e.g. EST-0007.
    var number: Int = 1
    var status: EstimateStatus = .draft {
        // However the status is changed (editor, list menu, picker), an invoice gets a fixed date the
        // first time, so its date and due date don't drift with later edits, and "Paid" means paid in full.
        didSet {
            guard status != oldValue else { return }
            if status.isInvoice, invoiceDate == nil { invoiceDate = Date() }
            if status == .paid {
                let total = totals.total
                if amountPaid < total { amountPaid = total }
            }
        }
    }
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

    /// Other work priced apart from tree volume (stump grinding, trimming, hauling…).
    var lineItems: [LineItem] = []
    /// Deposit asked for when the customer accepts (fixed amount or % of the total).
    var deposit = Adjustment(amount: 0, kind: .percent)
    /// Money already received from the customer (deposit or payments).
    var amountPaid: Double = 0
    /// When the estimate was turned into an invoice; the invoice's date.
    var invoiceDate: Date?
    /// Customer signature captured on the device (stored like a photo), with the printed name and time.
    var signatureID: UUID?
    var signedName = ""
    var signedAt: Date?

    init() {}

    // MARK: Derived

    var numberLabel: String { String(format: "EST-%04d", number) }
    var invoiceLabel: String { String(format: "INV-%04d", number) }

    /// The label for the document the customer currently receives.
    var documentLabel: String { status.isInvoice ? invoiceLabel : numberLabel }

    var isSigned: Bool { signatureID != nil }

    /// True while the tax rate still matches the region it was taken from.
    var taxRegionApplies: Bool { !regionName.isEmpty && abs(regionRate - taxRate) < 0.0001 }

    var measuredTreeCount: Int { trees.filter(\.isMeasured).count }

    var hasMeasuredTree: Bool { trees.contains(where: \.isMeasured) }

    /// True when there is something to charge for: a measured tree or a priced line item.
    /// (Stump-only or trimming-only jobs have no measured tree.)
    var hasBillableWork: Bool { hasMeasuredTree || lineItems.contains { $0.amount > 0 } }

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
            && lineItems.isEmpty
            && signatureID == nil
            && trees.allSatisfy { $0.circumference == 0 && $0.height == 0 && $0.label.trimmed.isEmpty && $0.photoIDs.isEmpty }
    }

    /// Every image file this estimate owns (photos and the signature).
    var allPhotoIDs: [UUID] { sitePhotoIDs + trees.flatMap(\.photoIDs) + (signatureID.map { [$0] } ?? []) }

    /// Equal apart from `updatedAt`, which the store sets itself.
    func hasSameContent(as other: Estimate) -> Bool {
        var copy = other
        copy.updatedAt = updatedAt
        return self == copy
    }

    /// All money is rounded to whole cents at each step so the lines on screen and on
    /// the PDF always add up to exactly the total.
    var totals: EstimateTotals {
        var t = EstimateTotals()
        t.volume = trees.reduce(0) { $0 + $1.volume }
        t.volumeCost = (t.volume * ratePerUnit).roundedToCents
        t.startingFee = startingFee.roundedToCents
        t.lineItems = lineItems.reduce(0) { $0 + $1.amount }.roundedToCents
        let base = (t.startingFee + t.volumeCost + t.lineItems).roundedToCents
        t.surcharge = surcharge.value(on: base)
        t.subtotal = (base + t.surcharge).roundedToCents
        t.discount = min(discount.value(on: t.subtotal), t.subtotal)
        let afterDiscount = (t.subtotal - t.discount).roundedToCents
        t.tax = taxRate > 0 ? (afterDiscount * taxRate / 100).roundedToCents : 0
        t.total = (afterDiscount + t.tax).roundedToCents
        t.deposit = min(deposit.value(on: t.total), t.total)
        t.paid = max(amountPaid, 0).roundedToCents
        t.balanceDue = max(t.total - t.paid, 0).roundedToCents
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
        case lineItems, deposit, amountPaid, invoiceDate, signatureID, signedName, signedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        number = (try? c.decodeIfPresent(Int.self, forKey: .number)) ?? 1
        status = c.lenient(EstimateStatus.self, .status) ?? .draft
        createdAt = (try? c.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? c.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? createdAt
        customerName = (try? c.decodeIfPresent(String.self, forKey: .customerName)) ?? ""
        customerPhone = (try? c.decodeIfPresent(String.self, forKey: .customerPhone)) ?? ""
        customerEmail = (try? c.decodeIfPresent(String.self, forKey: .customerEmail)) ?? ""
        address = (try? c.decodeIfPresent(String.self, forKey: .address)) ?? ""
        trees = (try? c.decodeIfPresent([TreeItem].self, forKey: .trees)) ?? []
        sitePhotoIDs = (try? c.decodeIfPresent([UUID].self, forKey: .sitePhotoIDs)) ?? []
        notes = (try? c.decodeIfPresent(String.self, forKey: .notes)) ?? ""
        unitSystem = c.lenient(UnitSystem.self, .unitSystem) ?? .imperial
        startingFee = (try? c.decodeIfPresent(Double.self, forKey: .startingFee)) ?? 0
        ratePerUnit = (try? c.decodeIfPresent(Double.self, forKey: .ratePerUnit)) ?? 0
        taxRate = (try? c.decodeIfPresent(Double.self, forKey: .taxRate)) ?? 0
        regionName = (try? c.decodeIfPresent(String.self, forKey: .regionName)) ?? ""
        regionRate = (try? c.decodeIfPresent(Double.self, forKey: .regionRate)) ?? 0
        licenseNumber = (try? c.decodeIfPresent(String.self, forKey: .licenseNumber)) ?? ""
        surcharge = (try? c.decodeIfPresent(Adjustment.self, forKey: .surcharge)) ?? Adjustment(amount: 0, kind: .fixed)
        surchargeLabel = (try? c.decodeIfPresent(String.self, forKey: .surchargeLabel)) ?? ""
        discount = (try? c.decodeIfPresent(Adjustment.self, forKey: .discount)) ?? Adjustment(amount: 0, kind: .percent)
        lineItems = (try? c.decodeIfPresent([LineItem].self, forKey: .lineItems)) ?? []
        deposit = (try? c.decodeIfPresent(Adjustment.self, forKey: .deposit)) ?? Adjustment(amount: 0, kind: .percent)
        amountPaid = (try? c.decodeIfPresent(Double.self, forKey: .amountPaid)) ?? 0
        invoiceDate = try? c.decodeIfPresent(Date.self, forKey: .invoiceDate)
        signatureID = try? c.decodeIfPresent(UUID.self, forKey: .signatureID)
        signedName = (try? c.decodeIfPresent(String.self, forKey: .signedName)) ?? ""
        signedAt = try? c.decodeIfPresent(Date.self, forKey: .signedAt)
    }
}

extension KeyedDecodingContainer {
    /// Decodes a string-backed enum, returning nil (instead of failing the whole file) for a value this
    /// version doesn't know, e.g. a status added by a newer version of the app.
    nonisolated func lenient<T: RawRepresentable>(_ type: T.Type, _ key: Key) -> T? where T.RawValue == String {
        guard let raw = try? decodeIfPresent(String.self, forKey: key) else { return nil }
        return T(rawValue: raw)
    }
}

extension String {
    nonisolated var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
