//
//  ServicesSettingsView.swift
//  Tree Cost Calculator
//

import SwiftUI

/// The saved price list for work other than measured trees (stump grinding, hauling, crew time…).
/// Each estimate picks from this list under "Other Work" and can still change the price per job.
struct ServicesSettingsView: View {
    @AppStorage(SettingsKey.services) private var services = ServiceList()

    /// Starter services that aren't in the list (compared by name, ignoring case).
    private var missingStarters: [ServiceItem] {
        let have = Set(services.items.map { $0.name.trimmed.lowercased() })
        return ServiceList.starter.filter { !have.contains($0.name.lowercased()) }
    }

    var body: some View {
        Form {
            Section {
                ForEach($services.items) { $item in
                    ServiceEditorRow(item: $item)
                }
                .onDelete { services.items.remove(atOffsets: $0) }
                .onMove { services.items.move(fromOffsets: $0, toOffset: $1) }

                Button {
                    services.items.append(ServiceItem())
                } label: {
                    Label("Add Service", systemImage: "plus.circle.fill")
                }
            } footer: {
                Text("Add these to any estimate under Other Work. Example: stump grinding at a price per inch of diameter with a minimum charge.")
            }

            if !missingStarters.isEmpty {
                Section {
                    Button {
                        let fresh = missingStarters.map { starter -> ServiceItem in
                            var copy = starter
                            copy.id = UUID()
                            return copy
                        }
                        services.items.append(contentsOf: fresh)
                    } label: {
                        Label("Restore Suggested Services", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
        .navigationTitle("Services & Prices")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                    .fontWeight(.semibold)
            }
        }
    }
}

private struct ServiceEditorRow: View {
    @Binding var item: ServiceItem

    private var title: String { item.name.trimmed.isEmpty ? "service" : item.name }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Service name", text: $item.name)
                .font(.body.weight(.medium))
                .textInputAutocapitalization(.sentences)
            LabeledContent("Unit") {
                TextField("e.g. in, hr, load", text: $item.unit)
                    .multilineTextAlignment(.trailing)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("Unit for \(title)")
            }
            LabeledContent("Price per unit") {
                NumberField(placeholder: "0", value: $item.unitPrice, prefix: Format.currencySymbol,
                            accessibilityLabel: "Price per unit for \(title)")
            }
            LabeledContent("Minimum charge") {
                NumberField(placeholder: "0", value: $item.minimum, prefix: Format.currencySymbol,
                            accessibilityLabel: "Minimum charge for \(title)")
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack { ServicesSettingsView() }
}
