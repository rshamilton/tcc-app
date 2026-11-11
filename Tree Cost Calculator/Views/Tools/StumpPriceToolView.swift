//
//  StumpPriceToolView.swift
//  Tree Cost Calculator
//

import SwiftUI

struct StumpPriceToolView: View {
    @AppStorage(SettingsKey.useMetric) private var useMetric = false
    @AppStorage("tool.stump.units") private var unitsRaw = ""
    @AppStorage("tool.stump.pricePerUnit") private var pricePerUnit = 0.0
    @AppStorage("tool.stump.minimum") private var minimum = 0.0
    @State private var diameter = 0.0
    @State private var count = 1.0

    private var metric: Bool { ToolUnitPicker.isMetric(stored: unitsRaw, default: useMetric) }
    private var unit: String { metric ? "cm" : "in" }
    private var each: Double { TreeMath.stumpGrindingPrice(diameter: diameter, pricePerUnit: pricePerUnit, minimum: minimum) }

    var body: some View {
        ToolPage(title: "Stump Grinding") {
            Section {
                ToolUnitPicker(stored: $unitsRaw, defaultMetric: useMetric, imperialLabel: "Inches", metricLabel: "Centimeters")
                ToolRow(title: "Stump diameter", placeholder: "0", value: $diameter, suffix: unit)
                ToolRow(title: "Number of stumps", placeholder: "1", value: $count)
            } footer: {
                Text("Measure across the widest point of the stump, at ground level.")
            }
            Section("Your prices") {
                ToolRow(title: "Price per \(unit)", placeholder: "0", value: $pricePerUnit, prefix: Format.currencySymbol)
                ToolRow(title: "Minimum charge", placeholder: "0", value: $minimum, prefix: Format.currencySymbol)
            }
            Section {
                if each > 0 {
                    let n = max(1, count.rounded())
                    let usesMin = diameter * pricePerUnit < minimum
                    ToolResult(label: n > 1 ? "Total for \(Format.number(n)) stumps" : "Price",
                               value: Format.money(each * n),
                               detail: usesMin ? "Minimum charge applied" : (n > 1 ? "\(Format.money(each)) each" : nil),
                               formula: "Price = larger of (diameter × price per \(unit)) and the minimum")
                } else {
                    Text("Enter a diameter and your price per \(unit).").foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: unitsRaw) { old, new in
            let wasMetric = old.isEmpty ? useMetric : old == "metric"
            let nowMetric = new == "metric"
            guard wasMetric != nowMetric else { return }
            if diameter > 0 {
                diameter = ((nowMetric ? TreeMath.centimeters(fromInches: diameter) : TreeMath.inches(fromCentimeters: diameter)) * 10).rounded() / 10
            }
            // The price per inch becomes a price per centimetre and back.
            if pricePerUnit > 0 {
                let converted = nowMetric ? pricePerUnit / 2.54 : pricePerUnit * 2.54
                pricePerUnit = (converted * 10000).rounded() / 10000
            }
        }
    }
}
