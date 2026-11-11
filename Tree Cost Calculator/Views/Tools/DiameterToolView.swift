//
//  DiameterToolView.swift
//  Tree Cost Calculator
//

import SwiftUI

struct DiameterToolView: View {
    @AppStorage(SettingsKey.useMetric) private var useMetric = false
    @AppStorage("tool.dbh.units") private var unitsRaw = ""
    @AppStorage("tool.dbh.circumference") private var circumference = 0.0

    private var metric: Bool { ToolUnitPicker.isMetric(stored: unitsRaw, default: useMetric) }
    private var unit: String { metric ? "cm" : "in" }
    private var diameter: Double { TreeMath.diameter(fromCircumference: circumference) }

    var body: some View {
        ToolPage(title: "Trunk Diameter") {
            Section {
                ToolUnitPicker(stored: $unitsRaw, defaultMetric: useMetric, imperialLabel: "Inches", metricLabel: "Centimeters")
                ToolRow(title: "Distance around trunk", placeholder: "0", value: $circumference, suffix: unit)
            } footer: {
                Text("DBH means diameter at breast height: measure around the trunk 4.5 ft (1.37 m) above the ground on the uphill side.")
            }
            Section {
                if diameter > 0 {
                    let other = metric ? TreeMath.inches(fromCentimeters: diameter) : TreeMath.centimeters(fromInches: diameter)
                    ToolResult(label: "Diameter",
                               value: "\(Format.number(diameter)) \(unit)",
                               detail: "About \(Format.number(other)) \(metric ? "in" : "cm")",
                               formula: "Diameter = distance around ÷ π (3.14159)")
                } else {
                    Text("Enter the distance around the trunk.").foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: unitsRaw) { old, new in
            // Keep the same tree when the unit flips.
            let wasMetric = old.isEmpty ? useMetric : old == "metric"
            let nowMetric = new == "metric"
            guard wasMetric != nowMetric, circumference > 0 else { return }
            circumference = ((nowMetric ? TreeMath.centimeters(fromInches: circumference) : TreeMath.inches(fromCentimeters: circumference)) * 10).rounded() / 10
        }
    }
}
