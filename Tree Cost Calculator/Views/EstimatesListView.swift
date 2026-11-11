//
//  EstimatesListView.swift
//  Tree Cost Calculator
//

import SwiftUI

struct EstimatesListView: View {
    @EnvironmentObject private var store: EstimateStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// The open estimate. On iPhone this drives a push; on iPad it fills the detail pane.
    @State private var selection: UUID?
    /// Which column shows when the split view is collapsed (iPhone). Set explicitly so opening an
    /// estimate from code always works, even when its row isn't in the list (empty state, filter, search).
    @State private var compactColumn = NavigationSplitViewColumn.sidebar
    /// A new first estimate, opened once the list has replaced the empty state (see `newEstimate`).
    @State private var openWhenListAppears: UUID?
    @State private var search = ""
    @State private var filter: EstimateStatus?
    @State private var showSettings = false
    @State private var pendingDelete: Estimate?
    @State private var showTools = false
    @Environment(\.dynamicTypeSize) private var typeSize

    private var visible: [Estimate] {
        var result = store.sortedEstimates
        let query = search.trimmed
        if query.isEmpty {
            if let filter { result = result.filter { $0.status == filter } }
        } else {
            // Searching looks at everything: the status chips are hidden meanwhile, so a leftover filter
            // must not silently narrow the results.
            result = result.filter { e in
                let fields = [e.customerName, e.address, e.customerPhone, e.customerEmail,
                              e.numberLabel, e.invoiceLabel, e.notes] + e.lineItems.map(\.name)
                return fields.contains { $0.localizedCaseInsensitiveContains(query) }
            }
        }
        return result
    }

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(store) }
        .sheet(isPresented: $showTools) { ToolsView() }
        .confirmationDialog(
            "Delete this estimate?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { estimate in
            Button("Delete Estimate", role: .destructive) { store.delete(id: estimate.id) }
            Button("Cancel", role: .cancel) {}
        } message: { estimate in
            Text("\(estimate.displayName) and its photos will be removed. This can't be undone.")
        }
        .onChange(of: store.estimates) { _, _ in
            // The open estimate was deleted (from the list, or from inside the editor).
            if let id = selection, store.estimate(id: id) == nil { close() }
            // The filtered status no longer exists (e.g. the last "Sent" estimate was approved): drop the
            // filter, otherwise the list is empty and the chips to undo it are hidden.
            if let filter, !store.estimates.contains(where: { $0.status == filter }) { self.filter = nil }
        }
        .onChange(of: selection) { old, id in
            // Tapping a row sets the selection; make sure the editor is what's showing on iPhone.
            if id != nil { compactColumn = .detail }
            // Leaving an estimate that was never filled in throws it away.
            if let old, old != id, store.estimate(id: old)?.isBlank == true { store.delete(id: old) }
        }
        #if DEBUG
        .task {
            if DebugLaunch.showSettings { showSettings = true }
            if let index = DebugLaunch.openEstimateIndex, selection == nil, store.sortedEstimates.indices.contains(index) {
                open(store.sortedEstimates[index].id)
            }
        }
        #endif
    }

    // MARK: Columns

    private var sidebar: some View {
        Group {
            if store.estimates.isEmpty {
                emptyState
            } else {
                list
                    .onAppear {
                        if let id = openWhenListAppears {
                            openWhenListAppears = nil
                            open(id)
                        }
                    }
            }
        }
        .navigationTitle("Estimates")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showTools = true } label: {
                    Image(systemName: "ruler")
                }
                .accessibilityLabel("Tree Tools")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { newEstimateButton }
        .navigationSplitViewColumnWidth(min: 340, ideal: 390, max: 480)
    }

    @ViewBuilder
    private var detail: some View {
        if let id = selection, let estimate = store.estimate(id: id) {
            EstimateEditorView(estimate: estimate)
                .id(estimate.id)
        } else if store.estimates.isEmpty {
            hero(title: "Quote your first tree",
                 message: "Measure trees, add stump grinding or other work, and send the customer a PDF estimate or invoice.")
        } else {
            hero(title: "Select an estimate",
                 message: "Choose one from the list, or start a new one.")
        }
    }

    // MARK: List

    private var list: some View {
        List(selection: $selection) {
            if search.trimmed.isEmpty {
                Section {
                    summaryHeader
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                ForEach(visible) { estimate in
                    NavigationLink(value: estimate.id) {
                        EstimateRow(estimate: estimate)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        // Not `.destructive`: that role animates the row away before the confirmation appears.
                        Button { pendingDelete = estimate } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                    .swipeActions(edge: .leading) {
                        Button { duplicate(estimate) } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button { duplicate(estimate) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                        Menu {
                            ForEach(EstimateStatus.allCases) { status in
                                Button {
                                    var updated = estimate
                                    updated.status = status
                                    store.update(updated)
                                } label: {
                                    Label(status.title, systemImage: estimate.status == status ? "checkmark" : status.symbol)
                                }
                            }
                        } label: {
                            Label("Set Status", systemImage: "flag")
                        }
                        Divider()
                        Button(role: .destructive) { pendingDelete = estimate } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            } footer: {
                if visible.isEmpty {
                    Text(search.trimmed.isEmpty ? "No \(filter?.title.lowercased() ?? "") estimates." : "No estimates match \"\(search.trimmed)\".")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search name, address or number")
        .animation(.default, value: visible.map(\.id))
        // Leave room for the floating button.
        .contentMargins(.bottom, 8, for: .scrollContent)
    }

    private var unpaidTotal: Double {
        store.unpaidInvoices.reduce(0) { $0 + $1.totals.balanceDue }
    }

    private var summaryTiles: [AnyView] {
        let open = store.openEstimates
        let won = store.approvedEstimates
        var tiles = [
            AnyView(SummaryTile(title: "Open", amount: open.reduce(0) { $0 + $1.totals.total },
                                caption: "\(open.count) \(open.count == 1 ? "estimate" : "estimates")",
                                symbol: "hourglass", color: .blue)),
            AnyView(SummaryTile(title: "Won", amount: won.reduce(0) { $0 + $1.totals.total },
                                caption: "\(won.count) \(won.count == 1 ? "job" : "jobs")",
                                symbol: "checkmark.seal.fill", color: .green))
        ]
        if !store.unpaidInvoices.isEmpty {
            let count = store.unpaidInvoices.count
            tiles.append(AnyView(SummaryTile(title: "Unpaid", amount: unpaidTotal,
                                             caption: "\(count) \(count == 1 ? "invoice" : "invoices")",
                                             symbol: "creditcard.fill", color: .purple)))
        }
        return tiles
    }

    @ViewBuilder
    private var tileLayout: some View {
        let tiles = summaryTiles
        if typeSize.isAccessibilitySize {
            VStack(spacing: 12) {
                ForEach(tiles.indices, id: \.self) { tiles[$0] }
            }
        } else {
            HStack(spacing: 12) {
                ForEach(tiles.indices, id: \.self) { tiles[$0] }
            }
        }
    }

    @ViewBuilder
    private var summaryHeader: some View {
        VStack(spacing: 14) {
            tileLayout
            if filter != nil || presentStatuses.count > 1 {
                statusFilter
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private var presentStatuses: [EstimateStatus] {
        EstimateStatus.allCases.filter { status in store.estimates.contains { $0.status == status } }
    }

    private var statusFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", count: store.estimates.count, isSelected: filter == nil) { filter = nil }
                ForEach(presentStatuses) { status in
                    FilterChip(title: status.title, count: store.estimates.filter { $0.status == status }.count, isSelected: filter == status) {
                        filter = (filter == status) ? nil : status
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    // MARK: Empty states

    /// Sidebar content when there are no estimates. On iPad the detail pane already shows the
    /// welcome message, so the sidebar stays quiet.
    @ViewBuilder
    private var emptyState: some View {
        if sizeClass == .regular {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "doc.text")
                    .font(.system(size: 34))
                    .foregroundStyle(.tertiary)
                Text("No estimates yet")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else {
            hero(title: "Quote your first tree",
                 message: "Measure trees, add stump grinding or other work, and send the customer a PDF estimate or invoice.")
        }
    }

    private func hero(title: String, message: String) -> some View {
        // A ScrollView so the text never clips at large Dynamic Type sizes.
        GeometryReader { geo in
            ScrollView {
                heroContent(title: title, message: message)
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private func heroContent(title: String, message: String) -> some View {
        VStack(spacing: 20) {
            BrandTile()
                .frame(width: 120, height: 120)
                .shadow(color: Color.accentColor.opacity(0.35), radius: 18, y: 8)
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.bold))
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 40)
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }

    // MARK: Actions

    private var newEstimateButton: some View {
        Button(action: newEstimate) {
            Label("New Estimate", systemImage: "plus")
                .font(.headline)
                .padding(.horizontal, 10)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    private func newEstimate() {
        // A filter or search would hide the new estimate's row.
        filter = nil
        search = ""
        // A blank estimate that's still open (iPad) was created with the prices of that moment, which may be
        // stale if Settings changed since. Replace it rather than reuse it, so blanks don't pile up either.
        if let id = selection, let current = store.estimate(id: id), current.isBlank {
            store.delete(id: id)
        }
        let wasEmpty = store.estimates.isEmpty
        let id = store.createEstimate().id
        if wasEmpty {
            // The first estimate swaps the empty state for the list. Navigating during that swap can be
            // dropped by the split view (the button then seemed to do nothing), so wait for the list.
            openWhenListAppears = id
        } else {
            open(id)
        }
    }

    private func duplicate(_ estimate: Estimate) {
        guard let copy = store.duplicate(id: estimate.id) else { return }
        filter = nil
        search = ""
        open(copy.id)
    }

    private func open(_ id: UUID) {
        selection = id
        compactColumn = .detail
    }

    private func close() {
        selection = nil
        compactColumn = .sidebar
    }
}

// MARK: - Row

struct EstimateRow: View {
    let estimate: Estimate
    @Environment(\.dynamicTypeSize) private var typeSize

    private var details: String {
        var parts: [String] = []
        let count = estimate.measuredTreeCount
        if count > 0 || estimate.lineItems.isEmpty {
            parts.append("\(count) \(count == 1 ? "tree" : "trees")")
        }
        let extras = estimate.lineItems.count
        if extras > 0 { parts.append("\(extras) other \(extras == 1 ? "item" : "items")") }
        if estimate.totals.volume > 0 { parts.append(Format.volume(estimate.totals.volume, in: estimate.unitSystem)) }
        return parts.joined(separator: " · ")
    }

    private var amountText: some View {
        Text(Format.money(estimate.totals.total))
            .font(.system(.headline, design: .rounded, weight: .bold))
            .monospacedDigit()
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(estimate.displayName)
                .font(.headline)
                .foregroundStyle(estimate.customerName.trimmed.isEmpty ? .secondary : .primary)
                .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
            if !estimate.address.trimmed.isEmpty {
                Text(estimate.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
            }
            Text(details)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(estimate.documentLabel) · \(estimate.updatedAt.formatted(.relative(presentation: .named)))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                // Name first, then amount and status underneath, so nothing is squeezed.
                VStack(alignment: .leading, spacing: 8) {
                    textColumn
                    amountText
                    StatusPill(status: estimate.status)
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    textColumn
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 8) {
                        amountText
                        StatusPill(status: estimate.status)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Header pieces

struct SummaryTile: View {
    let title: String
    let amount: Double
    let caption: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
            Text(Format.money(amount))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                Text("\(count)")
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : .secondary)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground), in: Capsule())
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
