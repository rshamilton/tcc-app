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

    private var visible: [Estimate] {
        var result = store.sortedEstimates
        if let filter { result = result.filter { $0.status == filter } }
        let query = search.trimmed
        if !query.isEmpty {
            result = result.filter { e in
                [e.customerName, e.address, e.customerPhone, e.customerEmail, e.numberLabel, e.notes]
                    .contains { $0.localizedCaseInsensitiveContains(query) }
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
        .sheet(isPresented: $showSettings) { SettingsView() }
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
                 message: "Enter a tree's circumference and height and get a price on the spot. Add the customer and send them a PDF.")
        } else {
            hero(title: "Select an estimate",
                 message: "Choose one from the list, or start a new one.")
        }
    }

    // MARK: List

    private var list: some View {
        List(selection: $selection) {
            if search.isEmpty {
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
                        Button(role: .destructive) { pendingDelete = estimate } label: {
                            Label("Delete", systemImage: "trash")
                        }
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
                    Text(search.isEmpty ? "No \(filter?.title.lowercased() ?? "") estimates." : "No estimates match \"\(search.trimmed)\".")
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

    @ViewBuilder
    private var summaryHeader: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                SummaryTile(title: "Open", amount: store.openEstimates.reduce(0) { $0 + $1.totals.total },
                            caption: "\(store.openEstimates.count) \(store.openEstimates.count == 1 ? "estimate" : "estimates")",
                            symbol: "hourglass", color: .blue)
                SummaryTile(title: "Approved", amount: store.approvedEstimates.reduce(0) { $0 + $1.totals.total },
                            caption: "\(store.approvedEstimates.count) \(store.approvedEstimates.count == 1 ? "job" : "jobs")",
                            symbol: "checkmark.seal.fill", color: .green)
            }
            if presentStatuses.count > 1 {
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
                 message: "Enter a tree's circumference and height and get a price on the spot. Add the customer and send them a PDF.")
        }
    }

    private func hero(title: String, message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
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
            Spacer()
            Spacer()
        }
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
        // If an empty estimate is already open (iPad), keep using it rather than piling up blanks.
        if let id = selection, let current = store.estimate(id: id), current.isBlank {
            open(id)
            return
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

    private var details: String {
        var parts: [String] = []
        let count = estimate.measuredTreeCount
        parts.append("\(count) \(count == 1 ? "tree" : "trees")")
        if estimate.totals.volume > 0 { parts.append(Format.volume(estimate.totals.volume, in: estimate.unitSystem)) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(estimate.displayName)
                    .font(.headline)
                    .foregroundStyle(estimate.customerName.trimmed.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                if !estimate.address.trimmed.isEmpty {
                    Text(estimate.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(estimate.numberLabel) · \(estimate.updatedAt.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 8) {
                Text(Format.money(estimate.totals.total))
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .monospacedDigit()
                StatusPill(status: estimate.status)
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
