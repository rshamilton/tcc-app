//
//  Components.swift
//  Tree Cost Calculator
//

import SwiftUI

// MARK: - Number input

/// A numeric text field that edits a `Double` live, accepts "," or "." as the decimal mark (and digits
/// from any script) and shows a placeholder instead of "0".
///
/// The text follows `value` when it changes from elsewhere (a tax region picked, a restore, a unit switch),
/// but only when it would read differently, so typing is never interrupted. Showing a value never writes
/// it back: the text holds up to six decimals, so the round trip is exact (8.375% stays 8.375%).
struct NumberField: View {
    let placeholder: String
    @Binding var value: Double
    var prefix: String? = nil
    var suffix: String? = nil
    var alignment: TextAlignment = .trailing
    /// What VoiceOver calls the field, e.g. "Tax rate". Without it the field would be read as its placeholder.
    var accessibilityLabel: String? = nil

    @State private var text = ""

    var body: some View {
        HStack(spacing: 4) {
            if let prefix {
                Text(prefix).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(alignment)
                .autocorrectionDisabled()
                .accessibilityLabel(accessibilityLabel ?? placeholder)
                .accessibilityValue(accessibilityText)
            if let suffix {
                Text(suffix).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .onAppear { syncText() }
        .onChange(of: value) { _, _ in syncText() }
        .onChange(of: text) { _, newText in
            let clean = Format.sanitize(newText)
            if clean != newText {
                text = clean
                return
            }
            let parsed = Format.parse(clean) ?? 0
            if abs(parsed - value) > 1e-9 { value = parsed }
        }
    }

    private var accessibilityText: String {
        let number = text.isEmpty ? "0" : text
        return [prefix, number, suffix].compactMap { $0 }.joined(separator: " ")
    }

    /// Shows `value` unless the text already means the same number (e.g. "8." while typing "8.5").
    private func syncText() {
        let shown = Format.parse(text) ?? 0
        if abs(shown - value) > 1e-9 { text = Format.editable(value) }
    }
}

/// Large labelled measurement input used for circumference and height.
struct MeasurementField: View {
    let title: String
    let unit: String
    @Binding var value: Double
    let isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            HStack(spacing: 6) {
                NumberField(placeholder: "0", value: $value, suffix: nil, alignment: .leading,
                            accessibilityLabel: "\(title), \(unit == "ft" ? "feet" : unit == "m" ? "meters" : unit)")
                    .font(.title3.weight(.semibold))
                Text(unit)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: isFocused ? 2 : 0)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

/// Text field with a small leading icon.
struct IconField: View {
    let symbol: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 22)
                .accessibilityHidden(true)
            TextField(placeholder, text: $text)
        }
    }
}

// MARK: - Status

struct StatusPill: View {
    let status: EstimateStatus

    var body: some View {
        Label(status.title, systemImage: status.symbol)
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            // Solid base so the pill stays readable on a selected (accent-coloured) sidebar row.
            .background(Capsule().fill(status.color.opacity(0.14)))
            .background(Capsule().fill(Color(.systemBackground)))
    }
}

/// `$` / `%` switch used by discounts and additional charges.
struct AdjustmentKindPicker: View {
    @Binding var kind: AdjustmentKind

    var body: some View {
        Picker("Type", selection: $kind) {
            Text(Format.currencySymbol).tag(AdjustmentKind.fixed)
            Text("%").tag(AdjustmentKind.percent)
        }
        .pickerStyle(.segmented)
        .frame(width: 92)
    }
}

// MARK: - Brand mark

/// The app icon's tree-and-tape-measure, drawn in SwiftUI so it stays sharp at any size.
struct TreeMark: View {
    var canopy = Color(red: 0.984, green: 0.973, blue: 0.925)
    var shade = Color(red: 0.863, green: 0.910, blue: 0.812)
    var trunkLight = Color(red: 0.894, green: 0.690, blue: 0.471)
    var trunkDark = Color(red: 0.776, green: 0.549, blue: 0.322)
    var tape = Color(red: 0.969, green: 0.788, blue: 0.282)
    var tapeEdge = Color(red: 0.788, green: 0.576, blue: 0.102)
    var tick = Color(red: 0.357, green: 0.227, blue: 0.020)
    var ground = Color.black.opacity(0.22)

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 1024
            ctx.translateBy(x: (size.width - 1024 * s) / 2, y: (size.height - 1024 * s) / 2)
            ctx.scaleBy(x: s, y: s)

            ctx.fill(Path(ellipseIn: CGRect(x: 206, y: 838, width: 612, height: 92)), with: .color(ground))

            var trunk = Path()
            trunk.move(to: CGPoint(x: 462, y: 500))
            trunk.addLine(to: CGPoint(x: 562, y: 500))
            trunk.addCurve(to: CGPoint(x: 632, y: 878), control1: CGPoint(x: 566, y: 640), control2: CGPoint(x: 578, y: 760))
            trunk.addLine(to: CGPoint(x: 392, y: 878))
            trunk.addCurve(to: CGPoint(x: 462, y: 500), control1: CGPoint(x: 446, y: 760), control2: CGPoint(x: 458, y: 640))
            trunk.closeSubpath()
            ctx.fill(trunk, with: .linearGradient(Gradient(colors: [trunkLight, trunkDark]),
                                                  startPoint: CGPoint(x: 392, y: 0), endPoint: CGPoint(x: 632, y: 0)))

            let lobes: [(CGFloat, CGFloat, CGFloat)] = [
                (512, 286, 178), (348, 396, 140), (676, 396, 140),
                (402, 478, 112), (622, 478, 112), (512, 420, 176)
            ]
            for (x, y, r) in lobes {
                ctx.fill(Path(ellipseIn: CGRect(x: x - r + 4, y: y - r + 22, width: (r - 4) * 2, height: (r - 4) * 2)), with: .color(shade))
            }
            for (x, y, r) in lobes {
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(canopy))
            }

            // Tape tail
            var tail = Path()
            tail.move(to: CGPoint(x: 590, y: 716)); tail.addLine(to: CGPoint(x: 646, y: 724))
            tail.addLine(to: CGPoint(x: 656, y: 842)); tail.addLine(to: CGPoint(x: 598, y: 848)); tail.closeSubpath()
            ctx.fill(tail, with: .color(tape))
            var tailEnd = Path()
            tailEnd.move(to: CGPoint(x: 598, y: 848)); tailEnd.addLine(to: CGPoint(x: 656, y: 842))
            tailEnd.addLine(to: CGPoint(x: 658, y: 868)); tailEnd.addLine(to: CGPoint(x: 600, y: 874)); tailEnd.closeSubpath()
            ctx.fill(tailEnd, with: .color(tapeEdge))

            // Tape band
            var band = Path()
            band.move(to: CGPoint(x: 404, y: 668))
            band.addQuadCurve(to: CGPoint(x: 620, y: 668), control: CGPoint(x: 512, y: 716))
            band.addLine(to: CGPoint(x: 620, y: 748))
            band.addQuadCurve(to: CGPoint(x: 404, y: 748), control: CGPoint(x: 512, y: 796))
            band.closeSubpath()
            ctx.fill(band, with: .color(tape))
            var edges = Path()
            edges.move(to: CGPoint(x: 404, y: 668)); edges.addQuadCurve(to: CGPoint(x: 620, y: 668), control: CGPoint(x: 512, y: 716))
            edges.move(to: CGPoint(x: 404, y: 748)); edges.addQuadCurve(to: CGPoint(x: 620, y: 748), control: CGPoint(x: 512, y: 796))
            ctx.stroke(edges, with: .color(tapeEdge), lineWidth: 6)

            var ticks = Path()
            for (x, y1, y2) in [(436, 690, 714), (468, 699, 726), (500, 705, 730), (532, 705, 730), (564, 699, 726), (596, 690, 714)] as [(CGFloat, CGFloat, CGFloat)] {
                ticks.move(to: CGPoint(x: x, y: y1)); ticks.addLine(to: CGPoint(x: x, y: y2))
            }
            ctx.stroke(ticks, with: .color(tick), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The app-icon look: brand-green gradient tile with the tree mark.
struct BrandTile: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(red: 0.25, green: 0.77, blue: 0.49), Color(red: 0.04, green: 0.35, blue: 0.22)],
                               startPoint: UnitPoint(x: 0.15, y: 0), endPoint: UnitPoint(x: 0.85, y: 1))
                TreeMark()
                    .padding(geo.size.width * 0.02)
            }
            .clipShape(RoundedRectangle(cornerRadius: geo.size.width * 0.2237, style: .continuous))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
