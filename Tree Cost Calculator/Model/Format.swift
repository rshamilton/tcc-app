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

    /// Text in number fields: the user's decimal mark, but always Latin digits (what `sanitize` keeps),
    /// and enough decimals that showing a value and reading it back never changes it (8.375% stays 8.375%).
    private static let editableFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        var components = Locale.Components(locale: .current)
        components.numberingSystem = "latn"
        f.locale = Locale(components: components)
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 6
        return f
    }()

    private static let percentFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = .current
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 3
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

    /// "8.5%" or "8.375%" – percentages, up to three decimals.
    static func percent(_ value: Double) -> String {
        "\(percentFormatter.string(from: value as NSNumber) ?? String(format: "%.3f", value))%"
    }

    /// "1.5" or "12" – a line item quantity, up to two decimals.
    static func number(_ value: Double) -> String {
        measureFormatter.string(from: value as NSNumber) ?? String(format: "%.2f", value)
    }

    /// A price per unit, showing more than two decimals only when the value has them ($0.125).
    static func unitPrice(_ value: Double) -> String {
        let cents = (value * 100).rounded() / 100
        guard abs(value - cents) > 0.000001 else { return money(value) }
        let f = currencyFormatter.copy() as! NumberFormatter
        f.maximumFractionDigits = 4
        return f.string(from: value as NSNumber) ?? money(value)
    }

    // MARK: Text field editing

    /// Text shown in an input field. Zero is shown as empty so the placeholder appears.
    static func editable(_ value: Double) -> String {
        guard value != 0 else { return "" }
        return editableFormatter.string(from: value as NSNumber) ?? ""
    }

    /// Parses what the user typed (after `sanitize`). Accepts either "," or "." as the decimal mark.
    static func parse(_ text: String) -> Double? {
        let trimmed = sanitize(text)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    private static let decimalMarks: Set<Character> = [".", ",", "\u{066B}"]

    /// Strips everything except digits and a single decimal mark. Digits from any script (Arabic-Indic,
    /// Persian, Devanagari…) become 0-9, and the Arabic decimal separator counts as a decimal mark.
    /// A pasted number with grouping ("1,234.50") keeps only its last mark as the decimal mark.
    static func sanitize(_ text: String) -> String {
        let marks = text.filter { decimalMarks.contains($0) }
        let mixedMarks = Set(marks.map { $0 == "\u{066B}" ? "," : $0 }).count > 1
        let lastMarkIndex = mixedMarks ? text.lastIndex(where: { decimalMarks.contains($0) }) : nil
        var seenMark = false
        var result = ""
        for index in text.indices {
            let ch = text[index]
            if ch.isNumber, let digit = ch.wholeNumberValue, (0...9).contains(digit) {
                result.append(Character(String(digit)))
            } else if decimalMarks.contains(ch), !seenMark, lastMarkIndex == nil || index == lastMarkIndex {
                seenMark = true
                result.append(ch == "\u{066B}" ? "," : ch)
            }
        }
        return result
    }
}
