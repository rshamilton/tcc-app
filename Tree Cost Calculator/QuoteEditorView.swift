//
//  QuoteEditorView.swift
//  Tree Cost Calculator
//
//  Created by Ryan Hamilton on 1/9/26.
//

import SwiftUI
import PhotosUI
import UIKit

struct QuoteEditorView: View {
    @ObservedObject var quotesManager: QuotesManager
    @Environment(\.dismiss) private var dismiss
    
    // Settings
    @AppStorage("startingFee") private var defaultStartingFee: Double = 0.0
    @AppStorage("pricePerCubicFoot") private var defaultPricePerCubicFoot: Double = 10.0
    @AppStorage("showTaxCalculator") private var showTaxCalculator: Bool = false
    @AppStorage("taxRate") private var defaultTaxRate: Double = 0.0
    @AppStorage("showDiscount") private var showDiscount: Bool = false
    @AppStorage("defaultDiscountPercent") private var defaultDiscountPercent: Double = 0.0
    @AppStorage("showFullEstimate") private var showFullEstimate: Bool = true
    @AppStorage("showAdditionalCharge") private var showAdditionalCharge: Bool = true
    @AppStorage("showMultipleTrees") private var showMultipleTrees: Bool = true
    @AppStorage("useMetric") private var useMetric: Bool = false
    
    // Quote data
    @State private var quote: Quote
    @State private var isNewQuote: Bool
    
    // UI State
    @State private var expandedTreeIndex: Int? = 0 // Tree 1 (index 0) auto-opens
    @State private var editingTreeCirc: String = ""
    @State private var editingTreeHeight: String = ""
    @State private var showingEstimateDetail = false
    @State private var hasClearedDefaultName = false
    @State private var showAdditionalChargeField = false
    @State private var showDiscountField = false
    
    // Keyboard management
    @FocusState private var focusedField: Field?
    
    enum Field {
        case quoteName, circumference, height, additionalCharge, additionalChargeDescription, discountPercent
    }
    
    init(quotesManager: QuotesManager, quote: Quote?) {
        self.quotesManager = quotesManager
        let startingFee = UserDefaults.standard.double(forKey: "startingFee")
        let pricePerCubicFoot = UserDefaults.standard.double(forKey: "pricePerCubicFoot")
        let taxRate = UserDefaults.standard.double(forKey: "taxRate")
        let discountPercent = UserDefaults.standard.double(forKey: "defaultDiscountPercent")
        
        if let existingQuote = quote {
            _quote = State(initialValue: existingQuote)
            _isNewQuote = State(initialValue: false)
        } else {
            _quote = State(initialValue: Quote(
                name: "Untitled Quote",
                trees: [],
                currentTreeCircumference: 0,
                currentTreeHeight: 0,
                customerName: "",
                location: "",
                jobNotes: "",
                startingFee: startingFee,
                pricePerCubicFoot: pricePerCubicFoot > 0 ? pricePerCubicFoot : 10.0,
                taxRate: taxRate,
                discountAmount: discountPercent,
                discountType: .percentage
            ))
            _isNewQuote = State(initialValue: true)
        }
    }
    
    private var unitLabel: String {
        useMetric ? "meters" : "feet"
    }
    
    private var hasValidCurrentTree: Bool {
        quote.currentTreeCircumference > 0 && quote.currentTreeHeight > 0
    }
    
    private var currentTreeIndex: Int {
        quote.trees.count + 1
    }
    
    private var subtotal: Double {
        let base = quote.startingFee + (quote.totalCubicFeet * quote.pricePerCubicFoot)
        let additional: Double
        if quote.additionalChargeType == .percentage {
            additional = base * (quote.additionalChargeAmount / 100.0)
        } else {
            additional = quote.additionalChargeAmount
        }
        return base + additional
    }
    
    private var discountAmount: Double {
        guard showDiscountField, quote.discountAmount > 0 else { return 0 }
        if quote.discountType == .percentage {
            return subtotal * (quote.discountAmount / 100.0)
        } else {
            return quote.discountAmount
        }
    }
    
    private var taxAmount: Double {
        guard showTaxCalculator else { return 0 }
        return (subtotal - discountAmount) * (quote.taxRate / 100.0)
    }
    
    private var costEstimate: Double {
        return subtotal - discountAmount + taxAmount
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    quoteNameSection
                    treesSection
                    resultsSection
                    actionButton
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        saveQuote()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .keyboard) {
                    keyboardToolbar
                }
            }
            .sheet(isPresented: $showingEstimateDetail) {
                EstimateDetailView(
                    cubicFeet: quote.totalCubicFeet,
                    trees: quote.trees
                )
            }
        }
        .onAppear {
            if isNewQuote {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    focusedField = .quoteName
                }
            }
            if quote.additionalChargeAmount > 0 {
                showAdditionalChargeField = true
            }
            if quote.discountAmount > 0 {
                showDiscountField = true
            }
        }
        .onChange(of: focusedField) { _, newValue in
            if newValue == .quoteName, isNewQuote, !hasClearedDefaultName, quote.name == "Untitled Quote" {
                quote.name = ""
                hasClearedDefaultName = true
            }
        }
        .onDisappear {
            saveQuote()
        }
    }
    
    // MARK: - View Components
    
    private var quoteNameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quote Name")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal)
            
            quoteNameField
        }
        .padding(.top, 8)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    private var quoteNameField: some View {
        TextField("Enter quote name", text: $quote.name)
            .font(.title2)
            .fontWeight(.bold)
            .textFieldStyle(.plain)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
            .focused($focusedField, equals: .quoteName)
            .onChange(of: quote.name) { _, _ in autoSave() }
            .accessibilityLabel("Quote name")
            .accessibilityValue(quote.name.isEmpty ? "Untitled" : quote.name)
            .accessibilityHint("Enter a name for this quote")
            .animation(.easeInOut(duration: 0.2), value: quote.name)
    }
    
    private var treesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            treesHeader
            
            if quote.trees.isEmpty {
                emptyTreesState
            } else {
                treesList
            }
        }
    }
    
    private var treesHeader: some View {
        HStack {
            Text("Trees")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Spacer()
            if let lastTree = quote.trees.first {
                Button(action: { duplicateTree(lastTree) }) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                        Text("Duplicate")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.15))
                    )
                }
                .accessibilityLabel("Duplicate last tree")
                .accessibilityHint("Creates a copy of the most recent tree")
            }
            Button(action: addNewTree) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                    Text("Add Tree")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.blue)
                        .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                )
                .foregroundColor(.white)
            }
            .accessibilityLabel("Add new tree")
            .accessibilityHint("Creates a new tree entry")
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    private var emptyTreesState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "leaf.circle")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
            }
            VStack(spacing: 6) {
                Text("No trees yet")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text("Tap Add Tree to begin")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Button(action: addNewTree) {
                Label("Add Tree", systemImage: "plus.circle.fill")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.green.opacity(0.2)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.primary.opacity(0.03))
        )
        .padding(.horizontal)
    }
    
    private var treesList: some View {
        ForEach(quote.trees.indices, id: \.self) { index in
            TreeCard(
                index: index,
                tree: $quote.trees[index],
                unitLabel: unitLabel,
                isExpanded: expandedTreeIndex == index,
                canDelete: expandedTreeIndex != index,
                onToggle: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0.2)) {
                        if expandedTreeIndex == index {
                            expandedTreeIndex = nil
                        } else {
                            expandedTreeIndex = index
                            editingTreeCirc = String(format: "%.15g", quote.trees[index].circumference)
                            editingTreeHeight = String(format: "%.15g", quote.trees[index].height)
                        }
                    }
                },
                onDelete: {
                    withAnimation {
                        quote.trees.remove(at: index)
                        if expandedTreeIndex == index {
                            expandedTreeIndex = nil
                        }
                        autoSave()
                    }
                },
                circumference: $editingTreeCirc,
                height: $editingTreeHeight,
                onUpdate: {
                    if let c = Double(editingTreeCirc), let h = Double(editingTreeHeight), c > 0, h > 0 {
                        quote.trees[index].circumference = c
                        quote.trees[index].height = h
                        autoSave()
                    }
                },
                focusedField: $focusedField
            )
            .padding(.horizontal)
        }
    }
    
    private var resultsSection: some View {
        VStack(spacing: 16) {
            ResultCard(
                icon: "shippingbox.fill",
                title: showMultipleTrees && !quote.trees.isEmpty ? "Total Volume" : "Total Cubic Feet",
                value: quote.totalCubicFeet,
                format: "%.2f",
                unit: useMetric ? "cu m" : "cu ft",
                color: .blue
            )
            
            additionalChargeAndDiscountSection
            
            ResultCard(
                icon: "banknote.fill",
                title: "Cost Estimate",
                value: costEstimate,
                format: "$%.2f",
                unit: "",
                color: .green
            )
            
            if (showDiscountField && discountAmount > 0) || (showTaxCalculator && taxAmount > 0) {
                taxAndDiscountInfo
            }
        }
        .padding(.horizontal)
    }
    
    private var additionalChargeAndDiscountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                if !showAdditionalChargeField {
                    Button(action: { showAdditionalChargeField = true }) {
                        Label("Add Additional Charge", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                if !showDiscountField {
                    Button(action: { showDiscountField = true }) {
                        Label("Add Discount", systemImage: "tag.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .padding(.horizontal)

            if showAdditionalChargeField {
                additionalChargeAmountField
                additionalChargeDescriptionField
                Button(role: .destructive, action: {
                    quote.additionalChargeAmount = 0
                    quote.additionalChargeDescription = ""
                    showAdditionalChargeField = false
                    autoSave()
                }) {
                    Label("Remove Additional Charge", systemImage: "trash")
                }
                .padding(.horizontal)
            }

            if showDiscountField {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.orange)
                            .accessibilityHidden(true)
                        Text("Discount")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal)

                    HStack {
                        TextField(
                            "0",
                            value: Binding(
                                get: { quote.discountAmount },
                                set: {
                                    quote.discountAmount = $0
                                    autoSave()
                                }
                            ),
                            format: .number
                        )
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .padding()
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(10)
                        .focused($focusedField, equals: .discountPercent)
                        Text("%")
                            .fontWeight(.semibold)
                            .padding(.trailing)
                    }
                    .padding(.horizontal)
                }

                Button(role: .destructive, action: {
                    quote.discountAmount = 0
                    showDiscountField = false
                    autoSave()
                }) {
                    Label("Remove Discount", systemImage: "trash")
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var additionalChargeAmountField: some View {
        HStack {
            Text("$")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.secondary)
                .padding(.leading)
                .accessibilityHidden(true)
            TextField("0.00", text: Binding(
                get: { quote.additionalChargeAmount == 0 ? "" : String(format: "%.15g", quote.additionalChargeAmount) },
                set: {
                    if $0.isEmpty {
                        quote.additionalChargeAmount = 0
                    } else if let value = Double($0) {
                        quote.additionalChargeAmount = value
                    }
                    autoSave()
                }
            ))
            .keyboardType(.decimalPad)
            .font(.system(size: 28, weight: .bold))
            .padding(.trailing)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.05))
            )
            .focused($focusedField, equals: .additionalCharge)
            .accessibilityLabel("Additional charge amount in dollars")
            .accessibilityValue(quote.additionalChargeAmount == 0 ? "0 dollars" : "\(quote.additionalChargeAmount, specifier: "%.2f") dollars")
            .accessibilityHint("Enter any additional charges for this quote")
        }
        .frame(height: 56)
    }
    
    private var additionalChargeDescriptionField: some View {
        TextField("Description (optional)", text: $quote.additionalChargeDescription)
            .font(.callout)
            .padding()
            .background(Color.primary.opacity(0.05))
            .cornerRadius(10)
            .focused($focusedField, equals: .additionalChargeDescription)
            .onChange(of: quote.additionalChargeDescription) { _, _ in autoSave() }
            .accessibilityLabel("Additional charge description")
            .accessibilityHint("Enter a description for this additional charge")
    }
    
    private var taxAndDiscountInfo: some View {
        VStack(spacing: 8) {
            if showDiscountField && discountAmount > 0 {
                HStack {
                    Text("Includes \(quote.discountAmount, specifier: "%.1f")% discount")
                    Spacer()
                    Text("-$\(discountAmount, specifier: "%.2f")")
                }
                .font(.caption)
                .foregroundColor(.orange)
            }
            
            if showTaxCalculator && taxAmount > 0 {
                HStack {
                    Text("Includes \(quote.taxRate, specifier: "%.1f")% tax")
                    Spacer()
                    Text("+$\(taxAmount, specifier: "%.2f")")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var actionButton: some View {
        if hasValidCurrentTree || !quote.trees.isEmpty {
            if showFullEstimate {
                Button(action: { showingEstimateDetail = true }) {
                    Label("Create Full Estimate", systemImage: "doc.text.fill")
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue)
                                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
    }
    
    private var keyboardToolbar: some View {
        HStack {
            switch focusedField {
            case .quoteName, .additionalCharge, .additionalChargeDescription, .discountPercent:
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
                .fontWeight(.semibold)
            case .circumference:
                Button("Done") {
                    focusedField = nil
                }
                .fontWeight(.semibold)
                Spacer()
                Button("Next") {
                    focusedField = .height
                }
                .fontWeight(.semibold)
            case .height:
                Button("Back") {
                    focusedField = .circumference
                }
                .fontWeight(.semibold)
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
                .fontWeight(.semibold)
            case .none:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func addTree() {
        guard hasValidCurrentTree else { return }
        quote.trees.insert(
            TreeItem(
                circumference: quote.currentTreeCircumference,
                height: quote.currentTreeHeight,
                notes: ""
            ),
            at: 0
        )
        quote.currentTreeCircumference = 0
        quote.currentTreeHeight = 0
        expandedTreeIndex = 0
        autoSave()
    }

    private func addNewTree() {
        // Add empty tree to beginning and expand it
        quote.trees.insert(
            TreeItem(circumference: 0, height: 0, notes: ""),
            at: 0
        )
        expandedTreeIndex = 0
        editingTreeCirc = ""
        editingTreeHeight = ""
        autoSave()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedField = .circumference
        }
    }

    private func duplicateTree(_ tree: TreeItem) {
        quote.trees.insert(
            TreeItem(circumference: tree.circumference, height: tree.height, notes: tree.notes),
            at: 0
        )
        expandedTreeIndex = 0
        editingTreeCirc = String(format: "%.15g", tree.circumference)
        editingTreeHeight = String(format: "%.15g", tree.height)
        autoSave()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedField = .circumference
        }
    }
    
    private func autoSave() {
        if isNewQuote {
            quotesManager.addQuote(quote)
            isNewQuote = false
        } else {
            quotesManager.updateQuote(quote)
        }
    }
    
    private func saveQuote() {
        if isNewQuote {
            quotesManager.addQuote(quote)
        } else {
            quotesManager.updateQuote(quote)
        }
    }
}

// MARK: - Tree Card Component
struct TreeCard: View {
    let index: Int
    @Binding var tree: TreeItem
    let unitLabel: String
    let isExpanded: Bool
    let canDelete: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    @Binding var circumference: String
    @Binding var height: String
    let onUpdate: () -> Void
    var focusedField: FocusState<QuoteEditorView.Field?>.Binding
    @State private var selectedTreePhotos: [PhotosPickerItem] = []
    
    var body: some View {
        VStack(spacing: 0) {
            treeHeader
            
            if isExpanded {
                expandedEditSection
            }
        }
        .background(Color.primary.opacity(0.03))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var treeHeader: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                    .accessibilityHidden(true)
                
                treeInfo
                
                Spacer()
                
                if !isExpanded {
                    volumeBadge
                }
                
                if canDelete {
                    deleteButton
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(isExpanded ? 0.12 : 0.06))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? "Collapse tree \(index + 1)" : "Expand tree \(index + 1)")
        .accessibilityValue(accessibilityValueText)
        .accessibilityHint(isExpanded ? "Tap to collapse" : "Tap to expand and edit")
    }

    private var accessibilityValueText: String {
        let circ = String(format: "%.1f", tree.circumference)
        let heightStr = String(format: "%.1f", tree.height)
        let volumeStr = String(format: "%.1f", tree.cubicFeet())
        return "Circumference \(circ), height \(heightStr) \(unitLabel), volume \(volumeStr) cubic feet"
    }
    
    private var treeInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tree \(index + 1)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            if !isExpanded {
                Text("\(tree.circumference, specifier: "%.1f") × \(tree.height, specifier: "%.1f") \(unitLabel)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var volumeBadge: some View {
        Text("\(tree.cubicFeet(), specifier: "%.1f") cu ft")
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundColor(.blue)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.blue.opacity(0.15))
            )
    }
    
    private var deleteButton: some View {
        Button(action: onDelete) {
            Image(systemName: "trash.circle.fill")
                .foregroundColor(.red)
                .font(.title3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete tree \(index + 1)")
        .accessibilityHint("Removes this tree from the quote")
    }
    
    private var expandedEditSection: some View {
        VStack(spacing: 20) {
            measurementField(
                label: "Circumference",
                text: $circumference,
                focusField: .circumference
            )
            
            measurementField(
                label: "Height",
                text: $height,
                focusField: .height
            )

            treePhotoSection
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.06))
        )
        .padding(.top, -12)
    }

    private var treePhotoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundColor(.blue)
                    .accessibilityHidden(true)
                Text("Tree Photos")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            if !tree.photoDataList.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(tree.photoDataList.enumerated()), id: \.offset) { index, data in
                            if let uiImage = UIImage(data: data) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 90)
                                        .clipped()
                                        .cornerRadius(8)

                                    Button(action: { removeTreePhoto(at: index) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .shadow(radius: 2)
                                    }
                                    .padding(4)
                                    .accessibilityLabel("Remove tree photo \(index + 1)")
                                }
                            }
                        }
                    }
                }
            }

            PhotosPicker(selection: $selectedTreePhotos, maxSelectionCount: 6, matching: .images) {
                Label(tree.photoDataList.isEmpty ? "Add Photos" : "Add More Photos", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .onChange(of: selectedTreePhotos) { _, newValue in
                Task {
                    await appendTreePhotos(newValue)
                    selectedTreePhotos = []
                }
            }
        }
    }
    
    private func measurementField(label: String, text: Binding<String>, focusField: QuoteEditorView.Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            HStack(spacing: 12) {
                TextField("0.0", text: text)
                    .keyboardType(.decimalPad)
                    .font(.title3.bold())
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(uiColor: .systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                    .focused(focusedField, equals: focusField)
                    .onChange(of: text.wrappedValue) { _, _ in onUpdate() }
                Text(unitLabel)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
                    .fixedSize()
            }
        }
    }

    private func removeTreePhoto(at index: Int) {
        guard tree.photoDataList.indices.contains(index) else { return }
        tree.photoDataList.remove(at: index)
    }

    private func appendTreePhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                tree.photoDataList.append(data)
            }
        }
    }
}

#Preview {
    QuoteEditorView(quotesManager: QuotesManager(), quote: nil)
}

