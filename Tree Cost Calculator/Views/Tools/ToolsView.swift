//
//  ToolsView.swift
//  Tree Cost Calculator
//

import SwiftUI

/// Field calculators that work offline. Presented as a sheet.
struct ToolsView: View {
    @Environment(\.dismiss) private var dismiss

    init() {}

    var body: some View {
        NavigationStack {
            List {
                Section {
                    link("Measure Tree Height", "Stand back, aim your phone, get the height.", "arrow.up.and.down", HeightToolView())
                    link("Trunk Diameter (DBH)", "Turn a tape-around-the-trunk reading into a diameter.", "circle.dashed", DiameterToolView())
                    link("Stump Grinding Price", "Price a stump by its diameter, with a minimum.", "scope", StumpPriceToolView())
                    link("Firewood Cords", "How much wood is in that stack.", "square.stack.3d.up", FirewoodToolView())
                    link("Log Board Feet", "Lumber a log could yield (Doyle and International).", "ruler", BoardFeetToolView())
                    link("Log Weight", "Estimate how heavy a log is, by species.", "scalemass", LogWeightToolView())
                } footer: {
                    Text("All results are estimates. Check measurements on site.")
                }
            }
            .navigationTitle("Tree Tools")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground))
        }
    }

    private func link<D: View>(_ title: String, _ subtitle: String, _ symbol: String, _ destination: D) -> some View {
        NavigationLink {
            destination
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: symbol).foregroundStyle(Color.accentColor)
            }
        }
        .accessibilityHint(subtitle)
    }
}
