//
//  Format.swift
//  Tree Cost Calculator
//

import Foundation

/// Number and currency formatting. Currency follows the device region rather than
/// assuming US dollars.
enum Format {
    private static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        return f
    }()

    private static let quantityFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = .current
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 1
        return f
    }()

    private static let measureFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = .current
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    private static let editableFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = .current
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    static var currencySymbol: String { currencyFormatter.currencySymbol ?? "$" }

    static func money(_ value: Double) -> String {
        currencyFormatter.string(from: value as NSNumber) ?? String(format: "$%.2f", value)
    }

    /// "412.3" – volumes and other quantities, one decimal place.
    static func quantity(_ value: Double) -> String {
        quantityFormatter.string(from: value as NSNumber) ?? String(format: "%.1f", value)
    }

    static func volume(_ value: Double, in units: UnitSystem) -> String {
        "\(quantity(value)) \(units.volumeUnit)"
    }

    /// "5.5 ft" – tree measurements, up to two decimals.
    static func length(_ value: Double, in units: UnitSystem) -> String {
        let number = measureFormatter.string(from: value as NSNumber) ?? String(format: "%.2f", value)
        return "\(number) \(units.lengthUnit)"
    }

    /// "Tax (8.5%)" or "Tax – Texas (6.25%)".
    static func taxTitle(for estimate: Estimate) -> String {
        let rate = percent(estimate.taxRate)
        return estimate.taxRegionApplies ? "Tax – \(estimate.regionName) (\(rate))" : "Tax (\(rate))"
    }

    /// "8.5" – percentages.
    static func percent(_ value: Double) -> String {
        "\(measureFormatter.string(from: value as NSNumber) ?? String(format: "%.2f", value))%"
    }

    // MARK: Text field editing

    /// Text shown in an input field. Zero is shown as empty so the placeholder appears.
    static func editable(_ value: Double) -> String {
        guard value != 0 else { return "" }
        return editableFormatter.string(from: value as NSNumber) ?? ""
    }

    /// Parses what the user typed. Accepts either "," or "." as the decimal mark.
    static func parse(_ text: String) -> Double? {
        let trimmed = text.trimmed
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    /// Strips everything except digits and a single decimal mark.
    static func sanitize(_ text: String) -> String {
        var seenMark = false
        var result = ""
        for ch in text {
            if ch.isASCII, ch.isNumber {
                result.append(ch)
            } else if (ch == "." || ch == ","), !seenMark {
                seenMark = true
                result.append(ch)
            }
        }
        return result
    }
}
