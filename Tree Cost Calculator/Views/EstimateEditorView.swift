//
//  EstimateEditorView.swift
//  Tree Cost Calculator
//

import SwiftUI

/// Every input that can hold keyboard focus, so "Next" / "Previous" can walk the whole form.
enum EditorField: Hashable {
    case label(UUID), circumference(UUID), height(UUID)
    case name, phone, email, address
    case fee, rate, surchargeLabel, surchargeAmount, discount, tax
    case notes
}

struct EstimateEditorView: View {
    @EnvironmentObject private var store: EstimateStore
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.taxRegions) private var regionList = TaxRegionList()

    @State private var estimate: Estimate
    /// Changes whenever the tax rate is set from a region, so its text field reloads the new value.
    @State private var taxFieldToken = UUID()
    @State private var showPreview = false
    @State private var confirmDelete = false
    @FocusState private var focus: EditorField?

    init(estimate: Estimate) {
        _estimate = State(initialValue: estimate)
    }

    private var units: UnitSystem { estimate.unitSystem }
    private var totals: EstimateTotals { estimate.totals }

    var body: some View {
        List {
            treesSection
            customerSection
            sitePhotosSection
            pricingSection
            summarySection
            notesSection
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(estimate.numberLabel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                statusMenu
            }
            ToolbarItemGroup(placement: .keyboard) {
                keyboardBar
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if focus == nil { bottomBar }
        }
        .sheet(isPresented: $showPreview) {
            EstimatePreviewSheet(estimate: estimate)
                .pageSizedSheet()
        }
        .confirmationDialog("Delete this estimate?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete Estimate", role: .destructive) {
                store.delete(id: estimate.id)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The estimate and its photos will be removed. This can't be undone.")
        }
        .onChange(of: estimate) { _, updated in
            store.update(updated)
        }
        .onDisappear {
            store.update(estimate)
            if estimate.isBlank { store.delete(id: estimate.id) }
        }
        .task {
            #if DEBUG
            if DebugLaunch.showPreview { showPreview = true }
            #endif
            // A brand-new estimate opens straight into the first measurement. Focus is ignored while
            // the screen is still animating in, so retry until it sticks (or the user goes elsewhere).
            if estimate.isBlank, let first = estimate.trees.first {
                let target = EditorField.circumference(first.id)
                for attempt in 0..<8 {
                    try? await Task.sleep(for: .milliseconds(attempt == 0 ? 450 : 300))
                    if Task.isCancelled { return }
                    if let current = focus, current != target { return }
                    focus = target
                    try? await Task.sleep(for: .milliseconds(100))
                    if focus == target { return }
                }
            }
        }
    }

    // MARK: - Trees

    private var treesSection: some View {
        Section {
            ForEach(estimate.trees) { tree in
                TreeRow(
                    tree: treeBinding(tree.id),
                    number: (estimate.trees.firstIndex(where: { $0.id == tree.id }) ?? 0) + 1,
                    units: units,
                    focus: $focus,
                    onDuplicate: { duplicateTree(tree.id) },
                    onDelete: { deleteTree(tree.id) }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) { deleteTree(tree.id) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading) {
                    Button { duplicateTree(tree.id) } label: {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    .tint(.blue)
                }
            }

            Button {
                addTree()
            } label: {
                Label(estimate.trees.isEmpty ? "Add Tree" : "Add Another Tree", systemImage: "plus.circle.fill")
                    .font(.body.weight(.semibold))
            }
        } header: {
            Text("Trees")
        } footer: {
            if totals.volume > 0 {
                Text("Total volume: \(Format.volume(totals.volume, in: units)) across \(estimate.measuredTreeCount) \(estimate.measuredTreeCount == 1 ? "tree" : "trees")")
            } else {
                Text("Measure around the trunk at about 4½ ft (1.4 m) off the ground, then measure the tree's total height.")
            }
        }
    }

    // MARK: - Customer

    private var customerSection: some View {
        Section("Customer") {
            IconField(symbol: "person.fill", placeholder: "Customer name", text: $estimate.customerName)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .focused($focus, equals: .name)
            IconField(symbol: "phone.fill", placeholder: "Phone", text: $estimate.customerPhone)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
                .focused($focus, equals: .phone)
            IconField(symbol: "envelope.fill", placeholder: "Email", text: $estimate.customerEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focus, equals: .email)
            IconField(symbol: "mappin.and.ellipse", placeholder: "Job site address", text: $estimate.address)
                .textContentType(.fullStreetAddress)
                .textInputAutocapitalization(.words)
                .focused($focus, equals: .address)
        }
    }

    private var sitePhotosSection: some View {
        Section {
            PhotoAttachments(ids: $estimate.sitePhotoIDs)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        } header: {
            Text("Site Photos")
        } footer: {
            Text("Photos of each tree can be added above. Everything is included in the PDF.")
        }
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        Section {
            LabeledContent("Starting fee") {
                NumberField(placeholder: "0", value: $estimate.startingFee, prefix: Format.currencySymbol)
                    .focused($focus, equals: .fee)
            }
            LabeledContent("Price per \(units.volumeUnit)") {
                NumberField(placeholder: "0", value: $estimate.ratePerUnit, prefix: Format.currencySymbol)
                    .focused($focus, equals: .rate)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Additional charge")
                    Spacer(minLength: 8)
                    AdjustmentKindPicker(kind: $estimate.surcharge.kind)
                }
                HStack(spacing: 12) {
                    NumberField(placeholder: "0", value: $estimate.surcharge.amount,
                                prefix: estimate.surcharge.kind == .fixed ? Format.currencySymbol : nil,
                                suffix: estimate.surcharge.kind == .percent ? "%" : nil,
                                alignment: .leading)
                        .focused($focus, equals: .surchargeAmount)
                        .frame(width: 96)
                    Divider().frame(height: 22)
                    TextField("Description, e.g. Stump grinding", text: $estimate.surchargeLabel)
                        .font(.subheadline)
                        .focused($focus, equals: .surchargeLabel)
                }
            }
            .padding(.vertical, 2)

            HStack {
                Text("Discount")
                Spacer(minLength: 8)
                NumberField(placeholder: "0", value: $estimate.discount.amount,
                            prefix: estimate.discount.kind == .fixed ? Format.currencySymbol : nil,
                            suffix: estimate.discount.kind == .percent ? "%" : nil)
                    .focused($focus, equals: .discount)
                AdjustmentKindPicker(kind: $estimate.discount.kind)
            }

            if !regionList.items.isEmpty {
                LabeledContent("Tax region") {
                    Menu {
                        Button {
                            useDefaultTax()
                        } label: {
                            Label("Default (\(Format.percent(UserDefaults.standard.double(forKey: SettingsKey.taxRate))))",
                                  systemImage: estimate.regionName.isEmpty ? "checkmark" : "circle.dashed")
                        }
                        ForEach(regionList.items) { region in
                            Button {
                                apply(region)
                            } label: {
                                Label("\(region.name) (\(Format.percent(region.rate)))",
                                      systemImage: estimate.taxRegionApplies && estimate.regionName == region.name ? "checkmark" : "mappin.circle")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(taxRegionTitle)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                    }
                }
            }
            LabeledContent("Tax rate") {
                NumberField(placeholder: "0", value: $estimate.taxRate, suffix: "%")
                    .focused($focus, equals: .tax)
                    .id(taxFieldToken)
            }
        } header: {
            Text("Pricing")
        } footer: {
            Text("Starts from your defaults in Settings. Changes here only affect this estimate. Tax rates are whatever you enter; the app doesn't look them up.")
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        Section("Summary") {
            summaryRow("Tree removal", detail: totals.volume > 0 ? "\(Format.volume(totals.volume, in: units)) × \(Format.money(estimate.ratePerUnit))" : nil, value: totals.volumeCost)
            if totals.startingFee > 0 {
                summaryRow("Starting fee", value: totals.startingFee)
            }
            if totals.surcharge > 0 {
                summaryRow(estimate.surchargeLabel.trimmed.isEmpty ? "Additional charge" : estimate.surchargeLabel.trimmed, value: totals.surcharge)
            }
            if totals.discount > 0 || totals.tax > 0 {
                summaryRow("Subtotal", value: totals.subtotal, bold: true)
            }
            if totals.discount > 0 {
                summaryRow(estimate.discount.kind == .percent ? "Discount (\(Format.percent(estimate.discount.amount)))" : "Discount",
                           value: -totals.discount, color: .orange)
            }
            if totals.tax > 0 {
                summaryRow(Format.taxTitle(for: estimate), value: totals.tax)
            }
            HStack {
                Text("Total").font(.headline)
                Spacer()
                Text(Format.money(totals.total))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func summaryRow(_ title: String, detail: String? = nil, value: Double, bold: Bool = false, color: Color = .primary) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(bold ? .semibold : .regular)
                if let detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(Format.money(value))
                .fontWeight(bold ? .semibold : .regular)
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Notes

    private var notesSection: some View {
        Section {
            TextField("Access, hazards, cleanup, anything the customer should know", text: $estimate.notes, axis: .vertical)
                .lineLimit(3...10)
                .focused($focus, equals: .notes)
        } header: {
            Text("Notes")
        } footer: {
            Text("Printed on the estimate.")
        }
    }

    // MARK: - Bars & menus

    private var bottomBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Total")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(Format.money(totals.total))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 8)

            Button {
                showPreview = true
            } label: {
                Label("Preview & Share", systemImage: "square.and.arrow.up")
                    .font(.body.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .disabled(!estimate.hasMeasuredTree)
            .accessibilityHint(estimate.hasMeasuredTree ? "Creates a PDF you can send to the customer" : "Enter a tree's measurements first")
        }
        .frame(maxWidth: 720 - 40)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder
    private var keyboardBar: some View {
        Button { moveFocus(-1) } label: { Image(systemName: "chevron.up") }
            .disabled(neighbour(of: focus, offset: -1) == nil)
            .accessibilityLabel("Previous field")
        Button { moveFocus(1) } label: { Image(systemName: "chevron.down") }
            .disabled(neighbour(of: focus, offset: 1) == nil)
            .accessibilityLabel("Next field")
        Spacer()
        Text(Format.money(totals.total))
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)
        Spacer()
        Button("Done") { focus = nil }
            .fontWeight(.semibold)
    }

    private var statusMenu: some View {
        Menu {
            Picker("Status", selection: $estimate.status) {
                ForEach(EstimateStatus.allCases) { status in
                    Label(status.title, systemImage: status.symbol).tag(status)
                }
            }
            Divider()
            Button(role: .destructive) { confirmDelete = true } label: {
                Label("Delete Estimate", systemImage: "trash")
            }
        } label: {
            Text(estimate.status.title)
                .fontWeight(.semibold)
        }
        .accessibilityLabel("Status: \(estimate.status.title)")
        .accessibilityHint("Change the status or delete the estimate")
    }

    // MARK: - Focus order

    private var focusOrder: [EditorField] {
        var order: [EditorField] = []
        for tree in estimate.trees {
            order += [.label(tree.id), .circumference(tree.id), .height(tree.id)]
        }
        order += [.name, .phone, .email, .address, .fee, .rate, .surchargeAmount, .surchargeLabel, .discount, .tax]
        return order
    }

    private func neighbour(of field: EditorField?, offset: Int) -> EditorField? {
        guard let field, let index = focusOrder.firstIndex(of: field) else { return nil }
        let target = index + offset
        return focusOrder.indices.contains(target) ? focusOrder[target] : nil
    }

    private func moveFocus(_ offset: Int) {
        if let next = neighbour(of: focus, offset: offset) { focus = next }
    }

    // MARK: - Tax regions

    private var taxRegionTitle: String {
        if estimate.taxRegionApplies { return estimate.regionName }
        return estimate.regionName.isEmpty ? "Default" : "Custom"
    }

    private func apply(_ region: TaxRegion) {
        estimate.taxRate = region.rate
        estimate.regionName = region.name
        estimate.regionRate = region.rate
        let regionLicense = region.license.trimmed
        estimate.licenseNumber = regionLicense.isEmpty ? defaultLicense : regionLicense
        taxFieldToken = UUID()
    }

    private func useDefaultTax() {
        estimate.taxRate = UserDefaults.standard.double(forKey: SettingsKey.taxRate)
        estimate.regionName = ""
        estimate.regionRate = 0
        estimate.licenseNumber = defaultLicense
        taxFieldToken = UUID()
    }

    private var defaultLicense: String {
        (UserDefaults.standard.string(forKey: SettingsKey.companyLicense) ?? "").trimmed
    }

    // MARK: - Tree actions

    private func treeBinding(_ id: UUID) -> Binding<TreeItem> {
        Binding(
            get: { estimate.trees.first(where: { $0.id == id }) ?? TreeItem(id: id) },
            set: { newValue in
                if let index = estimate.trees.firstIndex(where: { $0.id == id }) {
                    estimate.trees[index] = newValue
                }
            }
        )
    }

    private func addTree() {
        let tree = TreeItem()
        withAnimation { estimate.trees.append(tree) }
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            focus = .circumference(tree.id)
        }
    }

    private func duplicateTree(_ id: UUID) {
        guard let index = estimate.trees.firstIndex(where: { $0.id == id }) else { return }
        let source = estimate.trees[index]
        let copy = TreeItem(label: source.label, circumference: source.circumference, height: source.height)
        withAnimation { estimate.trees.insert(copy, at: index + 1) }
    }

    private func deleteTree(_ id: UUID) {
        guard let index = estimate.trees.firstIndex(where: { $0.id == id }) else { return }
        let photos = estimate.trees[index].photoIDs
        withAnimation { _ = estimate.trees.remove(at: index) }
        if !photos.isEmpty {
            Task.detached(priority: .utility) { PhotoStore.delete(photos) }
        }
    }
}

// MARK: - Tree row

struct TreeRow: View {
    @Binding var tree: TreeItem
    let number: Int
    let units: UnitSystem
    var focus: FocusState<EditorField?>.Binding
    let onDuplicate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Tree \(number)")
                    .font(.headline)
                if tree.isMeasured {
                    Text(Format.volume(tree.volume, in: units))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
                Spacer()
                Menu {
                    Button(action: onDuplicate) { Label("Duplicate", systemImage: "plus.square.on.square") }
                    Button(role: .destructive, action: onDelete) { Label("Delete Tree", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 30)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Tree \(number) options")
            }

            TextField("Name or note, e.g. Oak by driveway", text: $tree.label)
                .font(.subheadline)
                .focused(focus, equals: .label(tree.id))

            HStack(spacing: 12) {
                MeasurementField(title: "Circumference", unit: units.lengthUnit, value: $tree.circumference,
                                 isFocused: focus.wrappedValue == .circumference(tree.id))
                    .focused(focus, equals: .circumference(tree.id))
                MeasurementField(title: "Height", unit: units.lengthUnit, value: $tree.height,
                                 isFocused: focus.wrappedValue == .height(tree.id))
                    .focused(focus, equals: .height(tree.id))
            }

            PhotoAttachments(ids: $tree.photoIDs)
        }
        .padding(.vertical, 6)
        .buttonStyle(.borderless)
    }
}
