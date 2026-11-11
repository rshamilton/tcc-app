//
//  HeightMeasureView.swift
//  Tree Cost Calculator
//

import SwiftUI
import Combine
import CoreMotion

/// Reads how far the phone's top edge points above (+) or below (-) level, in degrees.
///
/// Method: hold the phone like a sighting tool and aim along its TOP EDGE at the target.
/// Core Motion's `gravity` is the direction of gravity in device axes (x right, y toward the top edge,
/// z out of the screen). "Up" is therefore -gravity, and the top edge (+y) points above the horizon by
/// `asin(-g.y)`. Flat on a table g = (0, 0, -1) gives 0 deg; tilting the top edge up makes g.y negative
/// and the angle positive; pointing it down gives a negative angle. Using atan2 with the other two axes
/// keeps this accurate at steep angles and ignores how the phone is rolled left or right.
/// No permission prompt is needed for device motion.
@MainActor
final class Clinometer: ObservableObject {
    @Published private(set) var angle = 0.0
    let isAvailable: Bool
    private let manager = CMMotionManager()
    private var smoothed: Double?

    init() { isAvailable = manager.isDeviceMotionAvailable }

    func start() {
        guard isAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 20.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let g = motion?.gravity else { return }
            let raw = atan2(-g.y, (g.x * g.x + g.z * g.z).squareRoot()) * 180 / .pi
            // Light smoothing so the number does not jitter in the hand.
            let value = self.smoothed.map { $0 * 0.6 + raw * 0.4 } ?? raw
            self.smoothed = value
            self.angle = value
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        smoothed = nil
    }
}

/// The measuring UI shared by the sheet and the "Measure Tree Height" tool. Emits Form sections.
struct HeightMeasureContent: View {
    @ObservedObject var clino: Clinometer
    let units: UnitSystem
    /// Called whenever the computed height changes (nil when not enough information yet).
    var onResult: (Double?) -> Void = { _ in }

    @AppStorage("tool.height.eyeFt") private var eyeHeightFt = 5.5
    @State private var distance = 0.0
    @State private var useEye = false
    @State private var typeAngles = false
    @State private var markedTop: Double?
    @State private var markedBase: Double?
    @State private var manualTop = 0.0
    @State private var manualBaseDown = 0.0

    private var metric: Bool { units == .metric }
    private var unit: String { units.lengthUnit }

    private var eyeBinding: Binding<Double> {
        Binding(get: { metric ? TreeMath.meters(fromFeet: eyeHeightFt) : eyeHeightFt },
                set: { eyeHeightFt = metric ? TreeMath.feet(fromMeters: $0) : $0 })
    }

    private var manual: Bool { typeAngles || !clino.isAvailable }

    private var topAngle: Double? { manual ? (manualTop > 0 ? manualTop : nil) : markedTop }
    private var baseAngle: Double? {
        if manual { return manualBaseDown > 0 ? -manualBaseDown : nil }
        return markedBase
    }

    private var height: Double? {
        guard distance > 0, let top = topAngle else { return nil }
        if useEye {
            return TreeMath.height(distance: distance, topAngleDegrees: top, baseAngleDegrees: nil, eyeHeight: eyeBinding.wrappedValue)
        }
        guard let base = baseAngle else { return nil }
        return TreeMath.height(distance: distance, topAngleDegrees: top, baseAngleDegrees: base, eyeHeight: 0)
    }

    var body: some View {
        Group {
            Section {
                Text("Stand back from the tree on level ground. Hold your phone upright and look along its top edge at the top of the tree, tap Mark Top; then aim at the base and tap Mark Base.")
                    .font(.subheadline)
                ToolRow(title: "Distance to tree", placeholder: "0", value: $distance, suffix: unit)
            } header: {
                Text("1. Distance")
            } footer: {
                Text("Pace it or use a tape. Standing about as far away as the tree is tall gives the best accuracy.")
            }

            Section {
                if clino.isAvailable {
                    Toggle("Type angles instead", isOn: $typeAngles)
                } else {
                    Text("This device has no motion sensor (the Simulator, for example), so type the angles you measured.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if manual {
                    ToolRow(title: "Angle up to treetop", placeholder: "0", value: $manualTop, suffix: "°")
                } else {
                    liveAngle
                    markRow(title: "Mark Top", marked: $markedTop, label: "Top angle")
                }
                Toggle("Use eye height instead of base", isOn: $useEye)
                if useEye {
                    ToolRow(title: "Eye height", placeholder: "0", value: eyeBinding, suffix: unit)
                } else if manual {
                    ToolRow(title: "Angle down to base", placeholder: "0", value: $manualBaseDown, suffix: "°")
                } else {
                    markRow(title: "Mark Base", marked: $markedBase, label: "Base angle")
                }
            } header: {
                Text("2. Angles")
            } footer: {
                Text(useEye ? "Eye height is how high your eyes are above the ground where the tree base is level with your feet."
                            : "Aim at where the trunk meets the ground. A base below eye level reads as a downward angle.")
            }

            Section {
                if let height {
                    ToolResult(label: "Estimated height",
                               value: Format.length(height, in: units),
                               detail: "Accurate to roughly 10%. Slopes and leaning trees add error.",
                               formula: useEye ? "Height = distance × tan(top angle) + eye height"
                                               : "Height = distance × (tan top angle + tan base angle below level)")
                } else {
                    Text(distance > 0 ? "Mark the top and base to see the height." : "Enter your distance from the tree first.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: height) { _, new in onResult(new) }
    }

    private var liveAngle: some View {
        HStack {
            Text("Phone is pointing")
            Spacer()
            Text(String(format: "%+.1f°", clino.angle))
                .font(.system(.title, design: .rounded, weight: .bold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Phone angle")
        .accessibilityValue(String(format: "%.0f degrees %@", abs(clino.angle), clino.angle >= 0 ? "above level" : "below level"))
    }

    private func markRow(title: String, marked: Binding<Double?>, label: String) -> some View {
        HStack {
            Button(marked.wrappedValue == nil ? title : "Re-mark") {
                marked.wrappedValue = clino.angle
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(marked.wrappedValue == nil ? title : "Re-mark \(label.lowercased())")
            Spacer()
            if let value = marked.wrappedValue {
                Text("\(label) \(String(format: "%+.1f°", value))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// "Measure Tree Height" tool.
struct HeightToolView: View {
    @AppStorage(SettingsKey.useMetric) private var useMetric = false
    @AppStorage("tool.height.units") private var unitsRaw = ""

    @StateObject private var clino = Clinometer()

    private var metric: Bool { ToolUnitPicker.isMetric(stored: unitsRaw, default: useMetric) }

    var body: some View {
        ToolPage(title: "Tree Height") {
            Section {
                ToolUnitPicker(stored: $unitsRaw, defaultMetric: useMetric, imperialLabel: "Feet", metricLabel: "Meters")
            }
            // New identity per unit so the distance field starts fresh instead of silently changing meaning.
            HeightMeasureContent(clino: clino, units: metric ? .metric : .imperial)
                .id(metric)
        }
        .onAppear { clino.start() }
        .onDisappear { clino.stop() }
    }
}

/// Presented from the estimate editor; hands back the measured height in `units`.
struct HeightMeasureSheet: View {
    let units: UnitSystem
    let onUse: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var result: Double?
    @StateObject private var clino = Clinometer()

    init(units: UnitSystem, onUse: @escaping (Double) -> Void) {
        self.units = units
        self.onUse = onUse
    }

    var body: some View {
        NavigationStack {
            ToolPage(title: "Measure Height") {
                HeightMeasureContent(clino: clino, units: units) { result = $0 }
                if let result {
                    Section {
                        Button {
                            onUse((result * 10).rounded() / 10)
                            dismiss()
                        } label: {
                            Text("Use This Height").frame(maxWidth: .infinity).fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityHint("Puts \(Format.length(result, in: units)) into the estimate")
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { clino.start() }
        .onDisappear { clino.stop() }
    }
}
