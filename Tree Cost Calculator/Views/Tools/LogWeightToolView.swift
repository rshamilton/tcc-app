//
//  LogWeightToolView.swift
//  Tree Cost Calculator
//

import SwiftUI

struct LogWeightToolView: View {
    @AppStorage(SettingsKey.useMetric) private var useMetric = false
    @AppStorage("tool.logweight.units") private var unitsRaw = ""
    @AppStorage("tool.logweight.species") private var speciesName = "Red oak"
    @State private var diameter = 0.0
    @State private var length = 0.0

    private var metric: Bool { ToolUnitPicker.isMetric(stored: unitsRaw, default: useMetric) }
    private var species: TreeMath.WoodSpecies { TreeMath.species(named: speciesName) }
    private var pounds: Double {
        TreeMath.logWeightPounds(diameterInches: metric ? TreeMath.inches(fromCentimeters: diameter) : diameter,
                                 lengthFeet: metric ? TreeMath.feet(fromMeters: length) : length,
                                 species: species)
    }

    var body: some View {
        ToolPage(title: "Log Weight") {
            Section {
                ToolUnitPicker(stored: $unitsRaw, defaultMetric: useMetric, imperialLabel: "Inches / feet", metricLabel: "cm / meters")
                Picker("Species", selection: $speciesName) {
                    ForEach(TreeMath.species) { s in
                        Text(s.name).tag(s.name)
                    }
                }
                ToolRow(title: "Average diameter", placeholder: "0", value: $diameter, suffix: metric ? "cm" : "in")
                ToolRow(title: "Log length", placeholder: "0", value: $length, suffix: metric ? "m" : "ft")
            } footer: {
                Text("Uses approximate green (fresh-cut) weights. Dry, rotten or very wet wood will differ.")
            }
            Section {
                if pounds > 0 {
                    let primary = metric ? TreeMath.kilograms(fromPounds: pounds) : pounds
                    let secondary = metric ? pounds : TreeMath.kilograms(fromPounds: pounds)
                    ToolResult(label: "Approximate weight",
                               value: "\(Format.number(primary.rounded())) \(metric ? "kg" : "lb")",
                               detail: "About \(Format.number(secondary.rounded())) \(metric ? "lb" : "kg")",
                               formula: "Weight = π × radius² × length × \(Format.number(species.greenLbPerCuFt)) lb per cu ft (\(species.name), green)")
                } else {
                    Text("Enter the log's diameter and length.").foregroundStyle(.secondary)
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
