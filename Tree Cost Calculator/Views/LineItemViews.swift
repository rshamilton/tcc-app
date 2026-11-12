//
//  LineItemViews.swift
//  Tree Cost Calculator
//

import SwiftUI

/// One "Other Work" line: stump grinding by the inch, crew by the hour, a flat haul-away fee...
struct LineItemRow: View {
    @Binding var item: LineItem
    var focus: FocusState<EditorField?>.Binding

    @Environment(\.dynamicTypeSize) private var typeSize
    /// Opened for items that already have a minimum; otherwise it stays out of the way.
    @State private var showMinimum: Bool

    init(item: Binding<LineItem>, focus: FocusState<EditorField?>.Binding) {
        _item = item
        self.focus = focus
        _showMinimum = State(initialValue: item.wrappedValue.minimum > 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("What the work is, e.g. Stump grinding", text: $item.name)
                .font(.headline)
                .textInputAutocapitalization(.sentences)
                .focused(focus, equals: .itemName(item.id))
                .accessibilityIdentifier("lineItemNameField")

            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) { quantityField; priceField }
            } else {
                HStack(spacing: 10) { quantityField; priceField }
            }

            if let hint = measureHint {
                Label(hint, systemImage: "ruler")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if showMinimum {
                LabeledContent("Minimum charge") {
                    NumberField(placeholder: "0", value: $item.minimum, prefix: Format.currencySymbol,
                                accessibilityLabel: "Minimum charge for \(item.displayName)")
                }
                .font(.subheadline)
            }

            HStack(alignment: .firstTextBaseline) {
                if !showMinimum {
                    Button {
                        withAnimation { showMinimum = true }
                    } label: {
                        Text("Add minimum charge")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(Format.money(item.amount))
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                    if item.usesMinimum {
                        Text("minimum")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Amount")
                .accessibilityValue(Format.money(item.amount) + (item.usesMinimum ? ", minimum charge" : ""))
            }
        }
        .padding(.vertical, 4)
    }

    private var quantityField: some View {
        HStack(spacing: 6) {
            NumberField(placeholder: "1", value: $item.quantity, alignment: .leading,
                        accessibilityLabel: "Quantity for \(item.displayName)",
                        identifier: "lineItemQuantityField")
                .focused(focus, equals: .itemQuantity(item.id))
                .frame(minWidth: 44)
            TextField("unit", text: $item.unit)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundStyle(.secondary)
                .frame(maxWidth: 64)
                .accessibilityLabel("Unit for \(item.displayName)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var priceField: some View {
        HStack(spacing: 4) {
            NumberField(placeholder: "0", value: $item.unitPrice, prefix: Format.currencySymbol, alignment: .leading,
                        accessibilityLabel: "Price per \(item.unit.trimmed.isEmpty ? "unit" : item.unit.trimmed) for \(item.displayName)")
                .focused(focus, equals: .itemPrice(item.id))
                .frame(minWidth: 60)
            if !item.unit.trimmed.isEmpty {
                Text("/ \(item.unit.trimmed)")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// Stump grinding is priced by diameter, which is easy to get wrong in the yard.
    private var measureHint: String? {
        switch item.unit.trimmed.lowercased() {
        case "in": return "Measure the stump's widest diameter in inches. Stumps are usually a little wider than the trunk, so check this number."
        case "cm": return "Measure the stump's widest diameter in centimeters. Stumps are usually a little wider than the trunk, so check this number."
        default: return nil
        }
    }
}
