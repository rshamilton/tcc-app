//
//  FirewoodToolView.swift
//  Tree Cost Calculator
//

import SwiftUI

struct FirewoodToolView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case stack, face
        var id: String { rawValue }
    }

    @AppStorage(SettingsKey.useMetric) private var useMetric = false
    @AppStorage("tool.firewood.units") private var unitsRaw = ""
    @AppStorage("tool.firewood.mode") private var modeRaw = Mode.stack.rawValue
    @AppStorage("tool.firewood.pieceLength") private var pieceLength = 16.0
    @State private var length = 0.0
    @State private var width = 0.0
    @State private var height = 0.0

    private var metric: Bool { ToolUnitPicker.isMetric(stored: unitsRaw, default: useMetric) }
    private var mode: Mode { Mode(rawValue: modeRaw) ?? .stack }
    private var lenUnit: String { metric ? "m" : "ft" }

    /// Length, width, height converted to feet for the maths.
    private func ft(_ v: Double) -> Double { metric ? TreeMath.feet(fromMeters: v) : v }

    private var cords: Double {
        switch mode {
        case .stack: return TreeMath.cords(length: ft(length), width: ft(width), height: ft(height))
        case .face: return TreeMath.faceCords(length: ft(length), height: ft(height), pieceLength: pieceLength)
        }
    }

    var body: some View {
        ToolPage(title: "Firewood Cords") {
            Section {
                Picker("Stack type", selection: $modeRaw) {
                    Text("Stack (L × W × H)").tag(Mode.stack.rawValue)
                    Text("Face cord").tag(Mode.face.rawValue)
                }
                .pickerStyle(.segmented)
                ToolUnitPicker(stored: $unitsRaw, defaultMetric: useMetric, imperialLabel: "Feet", metricLabel: "Meters")
            }
            Section {
                ToolRow(title: "Stack length", placeholder: "0", value: $length, suffix: lenUnit)
                if mode == .stack {
                    ToolRow(title: "Stack width (log length)", placeholder: "0", value: $width, suffix: lenUnit)
                }
                ToolRow(title: "Stack height", placeholder: "0", value: $height, suffix: lenUnit)
                if mode == .face {
                    ToolRow(title: "Log length", placeholder: "16", value: $pieceLength, suffix: "in")
                }
            } footer: {
                Text(mode == .stack
                     ? "Measure the neatly stacked wood: how long, how deep (the length of the logs) and how high."
                     : "A face cord is one row of logs, usually 8 ft long by 4 ft high. Its size depends on the log length.")
            }
            Section {
                if cords > 0 {
                    ToolResult(label: "Full cords",
                               value: Format.number(cords),
                               detail: detail,
                               formula: mode == .stack
                                   ? "Cords = length × width × height (ft) ÷ 128 cu ft"
                                   : "Cords = length × height × log length (ft) ÷ 128 cu ft")
                } else {
                    Text("Enter the size of the stack.").foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: unitsRaw) { old, new in
            let wasMetric = old.isEmpty ? useMetric : old == "metric"
            let nowMetric = new.isEmpty ? useMetric : new == "metric"
            guard wasMetric != nowMetric else { return }
            func conv(_ v: Double) -> Double {
                guard v > 0 else { return v }
                return ((nowMetric ? TreeMath.meters(fromFeet: v) : TreeMath.feet(fromMeters: v)) * 100).rounded() / 100
            }
            length = conv(length); width = conv(width); height = conv(height)
        }
    }

    private var detail: String {
        let cuFt = cords * TreeMath.cubicFeetPerCord
        if metric { return "About \(Format.number(cuFt / 35.3147)) m³ stacked" }
        return "About \(Format.number(cuFt)) cu ft stacked"
    }
}
