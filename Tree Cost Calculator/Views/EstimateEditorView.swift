//
//  EstimateEditorView.swift
//  Tree Cost Calculator
//

import SwiftUI
import UIKit

/// Every input that can hold keyboard focus, so "Next" / "Previous" can walk the whole form.
enum EditorField: Hashable {
    case label(UUID), circumference(UUID), height(UUID)
    case name, phone, email, address
    case itemName(UUID), itemQuantity(UUID), itemPrice(UUID)
    case fee, rate, surchargeLabel, surchargeAmount, discount, tax
    case deposit, amountPaid
    case notes
}

struct EstimateEditorView: View {
    @EnvironmentObject private var store: EstimateStore
    @Environment(\.dismiss) private var dismiss

    @Environment(\.dynamicTypeSize) private var typeSize

    @AppStorage(SettingsKey.taxRegions) private var regionList = TaxRegionList()
    @AppStorage(SettingsKey.services) private var services = ServiceList()

    @State private var estimate: Estimate
    @State private var showPreview = false
    @State private var showContacts = false
    @State private var showSignature = false
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
            otherWorkSection
            customerSection
            sitePhotosSection
            pricingSection
            paymentSection
            summarySection
            signatureSection
            notesSection
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(estimate.documentLabel)
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
            EstimatePreviewSheet(estimate: estimate, onShared: {
                if estimate.status == .draft { estimate.status = .sent }
            })
            .pageSizedSheet()
        }
        .sheet(isPresented: $showContacts) {
            ContactPicker { contact in
                importContact(contact)
                showContacts = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showSignature) {
            SignatureCaptureSheet(customerName: estimate.customerName) { png, name in
                saveSignature(png, name: name)
            }
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
        .onChange(of: store.estimate(id: estimate.id)) { _, stored in
            // Changed somewhere else (status set from the list on iPad, or restored from the backup):
            // show that version instead of later saving over it with this stale copy.
            if let stored, !stored.hasSameContent(as: estimate) { estimate = stored }
        }
        .onDisappear {
            // Blank estimates are discarded by the list when you leave them, not here: this also runs
            // while the camera covers the screen.
            store.update(estimate)
        }
        .task {
            #if DEBUG
            if DebugLaunch.showPreview { showPreview = true }
            #endif
            // A brand-new estimate opens straight into the first measurement.
            if estimate.isBlank, let first = estimate.trees.first {
                await focusWhenReady(.circumference(first.id), firstDelay: 450)
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

    // MARK: - Other work

    private var otherWorkSection: some View {
        Section {
            ForEach(estimate.lineItems) { item in
                LineItemRow(item: lineItemBinding(item.id), focus: $focus)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { deleteLineItem(item.id) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            Menu {
                ForEach(services.items) { service in
                    Button(serviceTitle(service)) { addLineItem(LineItem(service: service)) }
                }
                if !services.items.isEmpty { Divider() }
                Button {
                    addLineItem(LineItem(), focusName: true)
                } label: {
                    Label("Custom item", systemImage: "square.and.pencil")
                }
            } label: {
                Label("Add Other Work", systemImage: "plus.circle.fill")
                    .font(.body.weight(.semibold))
            }
            .accessibilityHint("Choose from your price list or add a custom item")
        } header: {
            Text("Other Work")
        } footer: {
            Text("Priced as quantity × price, for example stump grinding by the inch or a crew by the hour. Edit your price list in Settings.")
        }
    }

    private func serviceTitle(_ service: ServiceItem) -> String {
        guard service.unitPrice > 0 else { return service.name }
        let unit = service.unit.trimmed
        return "\(service.name) — \(Format.unitPrice(service.unitPrice))" + (unit.isEmpty ? "" : "/\(unit)")
    }

    private func lineItemBinding(_ id: UUID) -> Binding<LineItem> {
        Binding(
            get: { estimate.lineItems.first(where: { $0.id == id }) ?? LineItem(id: id) },
            set: { newValue in
                if let index = estimate.lineItems.firstIndex(where: { $0.id == id }) {
                    estimate.lineItems[index] = newValue
                }
            }
        )
    }

    private func addLineItem(_ item: LineItem, focusName: Bool = false) {
        withAnimation { estimate.lineItems.append(item) }
        let target: EditorField = focusName ? .itemName(item.id) : .itemQuantity(item.id)
        Task { await focusWhenReady(target, firstDelay: 250) }
    }

    private func deleteLineItem(_ id: UUID) {
        withAnimation { estimate.lineItems.removeAll { $0.id == id } }
    }

    // MARK: - Customer

    private var customerSection: some View {
        Section("Customer") {
            Button {
                showContacts = true
            } label: {
                Label("Import from Contacts", systemImage: "person.crop.circle.badge.plus")
            }
            .accessibilityHint("Fills in the name, phone, email and address from a contact you pick")
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
            quickActions
        }
    }

    @ViewBuilder
    private var quickActions: some View {
        let callURL = phoneURL
        let mailURL = mailtoURL
        let mapURL = directionsURL
        if callURL != nil || mailURL != nil || mapURL != nil {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 20) { quickLinks(callURL, mailURL, mapURL) }
                VStack(alignment: .leading, spacing: 10) { quickLinks(callURL, mailURL, mapURL) }
            }
            .font(.subheadline)
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private func quickLinks(_ call: URL?, _ mail: URL?, _ map: URL?) -> some View {
        if let call { Link(destination: call) { Label("Call", systemImage: "phone.fill") } }
        if let mail { Link(destination: mail) { Label("Email", systemImage: "envelope.fill") } }
        if let map { Link(destination: map) { Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill") } }
    }

    private var phoneURL: URL? {
        let raw = estimate.customerPhone.trimmed
        var digits = raw.filter { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty else { return nil }
        if raw.hasPrefix("+") { digits = "+" + digits }
        return URL(string: "tel:\(digits)")
    }

    private var mailtoURL: URL? {
        let email = estimate.customerEmail.trimmed
        guard email.contains("@") else { return nil }
        return URL(string: "mailto:\(email.addingPercentEncoding(withAllowedCharacters: Self.queryAllowed) ?? email)")
    }

    private var directionsURL: URL? {
        let address = estimate.address.trimmed
        guard !address.isEmpty, let encoded = address.addingPercentEncoding(withAllowedCharacters: Self.queryAllowed) else { return nil }
        return URL(string: "http://maps.apple.com/?daddr=\(encoded)")
    }

    /// Like URL-query-allowed, but also escapes the characters that would end or split a query value.
    private static let queryAllowed: CharacterSet = {
        var set = CharacterSet.urlQueryAllowed
        set.remove(charactersIn: "&+=?#")
        return set
    }()

    /// The user picked the contact on purpose, so its details replace what's there (only where it has something).
    private func importContact(_ contact: ImportedContact) {
        if !contact.name.isEmpty { estimate.customerName = contact.name }
        if !contact.phone.isEmpty { estimate.customerPhone = contact.phone }
        if !contact.email.isEmpty { estimate.customerEmail = contact.email }
        if !contact.address.isEmpty { estimate.address = contact.address }
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
                NumberField(placeholder: "0", value: $estimate.startingFee, prefix: Format.currencySymbol,
                            accessibilityLabel: "Starting fee")
                    .focused($focus, equals: .fee)
            }
            LabeledContent("Price per \(units.volumeUnit)") {
                NumberField(placeholder: "0", value: $estimate.ratePerUnit, prefix: Format.currencySymbol,
                            accessibilityLabel: "Price per \(units.volumeUnit)")
                    .focused($focus, equals: .rate)
            }

            surchargeRow
            discountRow

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
                NumberField(placeholder: "0", value: $estimate.taxRate, suffix: "%",
                            accessibilityLabel: "Tax rate")
                    .focused($focus, equals: .tax)
            }
        } header: {
            Text("Pricing")
        } footer: {
            Text("Starts from your defaults in Settings. Changes here only affect this estimate. Tax rates are whatever you enter; the app doesn't look them up.")
        }
    }

    private var surchargeRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Additional charge")
                Spacer(minLength: 8)
                AdjustmentKindPicker(kind: $estimate.surcharge.kind)
                    .accessibilityLabel("Additional charge type")
            }
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) { surchargeAmountField; surchargeDescription }
            } else {
                HStack(spacing: 12) {
                    surchargeAmountField
                    Divider().frame(height: 22)
                    surchargeDescription
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var surchargeAmountField: some View {
        NumberField(placeholder: "0", value: $estimate.surcharge.amount,
                    prefix: estimate.surcharge.kind == .fixed ? Format.currencySymbol : nil,
                    suffix: estimate.surcharge.kind == .percent ? "%" : nil,
                    alignment: .leading,
                    accessibilityLabel: "Additional charge amount")
            .focused($focus, equals: .surchargeAmount)
            .frame(minWidth: 72, maxWidth: typeSize.isAccessibilitySize ? .infinity : 130)
    }

    private var surchargeDescription: some View {
        TextField("Description, e.g. Storm cleanup", text: $estimate.surchargeLabel)
            .font(.subheadline)
            .focused($focus, equals: .surchargeLabel)
    }

    private var discountRow: some View {
        let kind = estimate.discount.kind
        let field = NumberField(placeholder: "0", value: $estimate.discount.amount,
                                prefix: kind == .fixed ? Format.currencySymbol : nil,
                                suffix: kind == .percent ? "%" : nil,
                                accessibilityLabel: "Discount amount")
            .focused($focus, equals: .discount)
        return Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Discount")
                    field
                    AdjustmentKindPicker(kind: $estimate.discount.kind)
                        .accessibilityLabel("Discount type")
                }
            } else {
                HStack {
                    Text("Discount")
                    Spacer(minLength: 8)
                    field
                    AdjustmentKindPicker(kind: $estimate.discount.kind)
                        .accessibilityLabel("Discount type")
                }
            }
        }
    }

    // MARK: - Payment

    private var paymentSection: some View {
        Section {
            let kind = estimate.deposit.kind
            LabeledContent("Deposit on acceptance") {
                HStack(spacing: 8) {
                    NumberField(placeholder: "0", value: $estimate.deposit.amount,
                                prefix: kind == .fixed ? Format.currencySymbol : nil,
                                suffix: kind == .percent ? "%" : nil,
                                accessibilityLabel: "Deposit amount")
                        .focused($focus, equals: .deposit)
                    AdjustmentKindPicker(kind: $estimate.deposit.kind)
                        .accessibilityLabel("Deposit type")
                }
            }
            if estimate.status.isWon {
                LabeledContent("Amount paid") {
                    NumberField(placeholder: "0", value: $estimate.amountPaid, prefix: Format.currencySymbol,
                                accessibilityLabel: "Amount paid")
                        .focused($focus, equals: .amountPaid)
                }
            }
        } header: {
            Text("Payment")
        } footer: {
            Text("The deposit is shown on the estimate. The amount paid and the balance due are shown on the invoice.")
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        Section("Summary") {
            if totals.volume > 0 || estimate.lineItems.isEmpty {
                summaryRow("Tree removal",
                           detail: totals.volume > 0 ? "\(Format.volume(totals.volume, in: units)) × \(Format.unitPrice(estimate.ratePerUnit))" : nil,
                           value: totals.volumeCost)
            }
            otherWorkSummary
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
            if totals.deposit > 0 {
                summaryRow("Deposit due on acceptance", value: totals.deposit, color: .secondary)
            }
            if estimate.status.isWon && totals.paid > 0 {
                summaryRow("Paid", value: -totals.paid, color: .secondary)
                summaryRow("Balance due", value: totals.balanceDue, bold: true)
            }
        }
    }

    @ViewBuilder
    private var otherWorkSummary: some View {
        let priced = estimate.lineItems.filter { $0.amount > 0 }
        if totals.lineItems > 0 {
            if priced.count <= 4 {
                ForEach(priced) { item in
                    summaryRow(item.displayName, detail: lineItemDetail(item), value: item.amount)
                }
            } else {
                summaryRow("Other work", detail: "\(priced.count) items", value: totals.lineItems)
            }
        }
    }

    private func lineItemDetail(_ item: LineItem) -> String {
        let unit = item.unit.trimmed
        let quantity = Format.number(item.quantity) + (unit.isEmpty ? "" : " \(unit)")
        let base = "\(quantity) × \(Format.unitPrice(item.unitPrice))"
        return item.usesMinimum ? "\(base), minimum charge" : base
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

    // MARK: - Signature

    private var signatureSection: some View {
        Section {
            if let id = estimate.signatureID {
                SignaturePreview(id: id)
                Text(signedCaption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Clear Signature", role: .destructive) { clearSignature(id) }
            } else {
                Button {
                    focus = nil
                    showSignature = true
                } label: {
                    Label("Get Customer Signature", systemImage: "signature")
                }
                .disabled(!estimate.hasBillableWork)
                .accessibilityHint(estimate.hasBillableWork ? "Hand the phone to your customer to sign" : "Add the work and prices first")
            }
        } header: {
            Text("Customer Signature")
        } footer: {
            Text("Hand the phone to your customer to sign that they accept the estimate. The signature is printed on the PDF.")
        }
    }

    private var signedCaption: String {
        let name = estimate.signedName.trimmed
        let who = name.isEmpty ? "Signed" : "Signed by \(name)"
        guard let date = estimate.signedAt else { return who }
        return "\(who) on \(date.formatted(date: .abbreviated, time: .omitted))"
    }

    private func saveSignature(_ png: Data, name: String) {
        guard let id = PhotoStore.save(png) else { return }
        let old = estimate.signatureID
        estimate.signatureID = id
        estimate.signedName = name
        estimate.signedAt = Date()
        if estimate.status == .draft || estimate.status == .sent { estimate.status = .approved }
        if let old { persistThenDelete([old]) }
    }

    private func clearSignature(_ id: UUID) {
        estimate.signatureID = nil
        estimate.signedName = ""
        estimate.signedAt = nil
        persistThenDelete([id])
    }

    /// Writes the estimate to disk first so a crash can never leave it pointing at a deleted file.
    private func persistThenDelete(_ ids: [UUID]) {
        store.update(estimate)
        store.flush()
        Task.detached(priority: .utility) { PhotoStore.delete(ids) }
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
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    totalLabel
                    shareButton.frame(maxWidth: .infinity)
                }
            } else {
                HStack(spacing: 16) {
                    totalLabel
                    Spacer(minLength: 8)
                    shareButton
                }
            }
        }
        .frame(maxWidth: 720 - 40)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var totalLabel: some View {
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
    }

    private var shareButton: some View {
        Button {
            showPreview = true
        } label: {
            Label(estimate.status.isInvoice ? "Invoice & Share" : "Preview & Share", systemImage: "square.and.arrow.up")
                .font(.body.weight(.semibold))
                .lineLimit(1)
                // Keep the label on one line; the total shrinks to fit instead.
                .fixedSize(horizontal: !typeSize.isAccessibilitySize, vertical: false)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .layoutPriority(1)
        .disabled(!estimate.hasBillableWork)
        .accessibilityHint(estimate.hasBillableWork ? "Creates a PDF you can send to the customer" : "Enter a tree's measurements or add other work first")
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
            if [.draft, .sent, .approved].contains(estimate.status) {
                Button {
                    estimate.status = .invoiced
                    if estimate.invoiceDate == nil { estimate.invoiceDate = Date() }
                } label: {
                    Label("Create Invoice", systemImage: "doc.text")
                }
            }
            if estimate.status == .invoiced {
                Button {
                    estimate.status = .paid
                    estimate.amountPaid = totals.total
                } label: {
                    Label("Mark as Paid", systemImage: "checkmark.circle")
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
        for item in estimate.lineItems {
            order += [.itemName(item.id), .itemQuantity(item.id), .itemPrice(item.id)]
        }
        order += [.name, .phone, .email, .address, .fee, .rate, .surchargeAmount, .surchargeLabel, .discount, .tax, .deposit]
        if estimate.status.isWon { order.append(.amountPaid) }
        order.append(.notes)
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
    }

    private func useDefaultTax() {
        estimate.taxRate = UserDefaults.standard.double(forKey: SettingsKey.taxRate)
        estimate.regionName = ""
        estimate.regionRate = 0
        estimate.licenseNumber = defaultLicense
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
        Task { await focusWhenReady(.circumference(tree.id), firstDelay: 250) }
    }

    /// Focus is ignored while a screen or row is still animating in, so retry until it sticks
    /// (or the user has moved to another field).
    private func focusWhenReady(_ target: EditorField, firstDelay: Int) async {
        let start = focus
        for attempt in 0..<10 {
            try? await Task.sleep(for: .milliseconds(attempt == 0 ? firstDelay : 300))
            if Task.isCancelled { return }
            if let current = focus, current != target, current != start { return }
            focus = target
            try? await Task.sleep(for: .milliseconds(100))
            if focus == target { return }
        }
    }

    private func duplicateTree(_ id: UUID) {
        guard let index = estimate.trees.firstIndex(where: { $0.id == id }) else { return }
        let source = estimate.trees[index]
        let copy = TreeItem(label: source.label, circumference: source.circumference, height: source.height)
        withAnimation { estimate.trees.insert(copy, at: index + 1) }
        Task { await focusWhenReady(.circumference(copy.id), firstDelay: 250) }
    }

    private func deleteTree(_ id: UUID) {
        guard let index = estimate.trees.firstIndex(where: { $0.id == id }) else { return }
        let photos = estimate.trees[index].photoIDs
        withAnimation { _ = estimate.trees.remove(at: index) }
        if !photos.isEmpty { persistThenDelete(photos) }
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

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showHeightMeasure = false

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
                    Button { showHeightMeasure = true } label: { Label("Measure Height…", systemImage: "angle") }
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

            if typeSize.isAccessibilitySize {
                VStack(spacing: 12) { circumferenceField; heightField }
            } else {
                HStack(spacing: 12) { circumferenceField; heightField }
            }

            if let diameter = diameterText {
                Text(diameter)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button { showHeightMeasure = true } label: {
                Label("Measure Height…", systemImage: "angle")
                    .font(.subheadline)
            }
            .accessibilityHint("Uses the camera tilt to estimate the tree's height")

            PhotoAttachments(ids: $tree.photoIDs)
        }
        .padding(.vertical, 6)
        .buttonStyle(.borderless)
        .sheet(isPresented: $showHeightMeasure) {
            HeightMeasureSheet(units: units, onUse: { tree.height = $0 })
        }
    }

    private var circumferenceField: some View {
        MeasurementField(title: "Circumference", unit: units.lengthUnit, value: $tree.circumference,
                         isFocused: focus.wrappedValue == .circumference(tree.id))
            .focused(focus, equals: .circumference(tree.id))
    }

    private var heightField: some View {
        MeasurementField(title: "Height", unit: units.lengthUnit, value: $tree.height,
                         isFocused: focus.wrappedValue == .height(tree.id))
            .focused(focus, equals: .height(tree.id))
    }

    /// Trunk diameter (what arborists call DBH) from the circumference: ft to inches, or m to cm.
    private var diameterText: String? {
        guard tree.circumference > 0 else { return nil }
        let diameter = tree.circumference / Double.pi
        return units == .imperial
            ? "Diameter ≈ \(Format.number(diameter * 12)) in"
            : "Diameter ≈ \(Format.number(diameter * 100)) cm"
    }
}

/// The saved signature picture, loaded off the main thread.
private struct SignaturePreview: View {
    let id: UUID
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 120)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityLabel("Customer signature")
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 60)
            }
        }
        .task(id: id) {
            let target = id
            image = await Task.detached { PhotoStore.image(for: target, maxPixel: 800) }.value
        }
    }
}
