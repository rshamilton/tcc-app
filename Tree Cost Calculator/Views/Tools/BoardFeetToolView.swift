//
//  BoardFeetToolView.swift
//  Tree Cost Calculator
//

import SwiftUI

struct BoardFeetToolView: View {
    @AppStorage(SettingsKey.useMetric) private var useMetric = false
    @AppStorage("tool.boardfeet.units") private var unitsRaw = ""
    @State private var diameter = 0.0
    @State private var length = 0.0

    private var metric: Bool { ToolUnitPicker.isMetric(stored: unitsRaw, default: useMetric) }
    private var inches: Double { metric ? TreeMath.inches(fromCentimeters: diameter) : diameter }
    private var feet: Double { metric ? TreeMath.feet(fromMeters: length) : length }
    private var doyle: Double { TreeMath.doyleBoardFeet(smallEndDiameterInches: inches, lengthFeet: feet) }
    private var intl: Double { TreeMath.international14BoardFeet(diameterInches: inches, lengthFeet: feet) }

    var body: some View {
        ToolPage(title: "Log Board Feet") {
            Section {
                ToolUnitPicker(stored: $unitsRaw, defaultMetric: useMetric, imperialLabel: "Inches / feet", metricLabel: "cm / meters")
                ToolRow(title: "Small-end diameter", placeholder: "0", value: $diameter, suffix: metric ? "cm" : "in")
                ToolRow(title: "Log length", placeholder: "0", value: $length, suffix: metric ? "m" : "ft")
            } footer: {
                Text("Measure across the thinner end of the log, inside the bark.")
            }
            Section {
                if intl > 0 || doyle > 0 {
                    ToolResult(label: "International ¼-inch rule",
                               value: "\(Format.number(intl.rounded())) board ft",
                               detail: "Closest to what a mill actually cuts",
                               formula: "Adds up each 4 ft section: 0.9048 × (0.22d² − 0.71d), with 0.5 in taper per section")
                    ToolResult(label: "Doyle rule",
                               value: "\(Format.number(doyle.rounded())) board ft",
                               detail: "Common in the eastern US; reads low on small logs",
                               formula: "Board feet = ((diameter − 4)² ÷ 16) × length in feet")
                } else {
                    Text("Enter the log's small-end diameter and length.").foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: unitsRaw) { old, new in
            let wasMetric = old.isEmpty ? useMetric : old == "metric"
            let nowMetric = new.isEmpty ? useMetric : new == "metric"
            guard wasMetric != nowMetric else { return }
            if diameter > 0 {
                diameter = ((nowMetric ? TreeMath.centimeters(fromInches: diameter) : TreeMath.inches(fromCentimeters: diameter)) * 10).rounded() / 10
            }
            if length > 0 {
                length = ((nowMetric ? TreeMath.meters(fromFeet: length) : TreeMath.feet(fromMeters: length)) * 100).rounded() / 100
            }
        }
    }
}
