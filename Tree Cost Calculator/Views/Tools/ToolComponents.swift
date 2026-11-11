//
//  ToolComponents.swift
//  Tree Cost Calculator
//

import SwiftUI

/// Shared look for every Tree Tools screen: a form, centred and capped in width on iPad.
struct ToolPage<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        Form { content }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
    }
}

/// A big, bold result with a one-line explanation of how it was worked out.
struct ToolResult: View {
    let label: String
    let value: String
    var detail: String? = nil
    let formula: String

    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: size, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(2)
            if let detail {
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Text(formula)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// A labelled number row that stacks the label above the field at accessibility text sizes.
struct ToolRow: View {
    let title: String
    let placeholder: String
    @Binding var value: Double
    var suffix: String? = nil
    var prefix: String? = nil

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                NumberField(placeholder: placeholder, value: $value, prefix: prefix, suffix: suffix,
                            alignment: .leading, accessibilityLabel: title)
            }
        } else {
            HStack {
                Text(title).accessibilityHidden(true)
                Spacer(minLength: 12)
                NumberField(placeholder: placeholder, value: $value, prefix: prefix, suffix: suffix,
                            accessibilityLabel: title)
            }
        }
    }
}

/// Two-way unit choice stored per tool. Empty storage means "follow the app's Measurements setting".
struct ToolUnitPicker: View {
    @Binding var stored: String
    let defaultMetric: Bool
    let imperialLabel: String
    let metricLabel: String

    private var isMetric: Bool { stored.isEmpty ? defaultMetric : stored == "metric" }

    var body: some View {
        Picker("Units", selection: Binding(get: { isMetric }, set: { stored = $0 ? "metric" : "imperial" })) {
            Text(imperialLabel).tag(false)
            Text(metricLabel).tag(true)
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Units")
    }

    static func isMetric(stored: String, default d: Bool) -> Bool {
        stored.isEmpty ? d : stored == "metric"
    }
}

extension View {
    /// Reads a result aloud when it appears or changes.
    func announceResult(_ text: String) -> some View {
        accessibilityValue(text)
    }
}
