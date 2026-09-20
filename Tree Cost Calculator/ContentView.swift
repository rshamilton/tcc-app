//
//  ContentView.swift
//  Tree Cost Calculator
//
//  Created by Ryan Hamilton on 1/9/26.
//

import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    // Settings from UserDefaults
    @AppStorage("startingFee") private var startingFee: Double = 0.0
    @AppStorage("pricePerCubicFoot") private var pricePerCubicFoot: Double = 10.0
    @AppStorage("showTaxCalculator") private var showTaxCalculator: Bool = false
    @AppStorage("taxRate") private var taxRate: Double = 0.0
    @AppStorage("showDiscount") private var showDiscount: Bool = false
    @AppStorage("defaultDiscountPercent") private var defaultDiscountPercent: Double = 0.0
    @AppStorage("showFullEstimate") private var showFullEstimate: Bool = true
    @AppStorage("showJobNotes") private var showJobNotes: Bool = true
    @AppStorage("showPhotoAttachment") private var showPhotoAttachment: Bool = true
    @AppStorage("showMultipleTrees") private var showMultipleTrees: Bool = true
    @AppStorage("useMetric") private var useMetric: Bool = false
    
    // Input values
    @State private var circumference: String = ""
    @State private var height: String = ""
    @State private var trees: [TreeItem] = []
    @State private var expandedTreeIndex: Int? = nil
    @State private var editingTreeCirc: String = ""
    @State private var editingTreeHeight: String = ""
    
    // Show views
    @State private var showingSettings = false
    @State private var showingEstimateDetail = false
    @State private var showingHistory = false
    
    // Keyboard management
    @FocusState private var focusedField: Field?
    
    enum Field {
        case circumference, height
    }
    
    // Computed properties for calculations
    private var cubicFeet: Double {
        guard let c = Double(circumference),
              let h = Double(height),
              c > 0, h > 0 else {
            return 0
        }
        return (c * c * h) / 12.56
    }
    
    private var totalCubicFeet: Double {
        if showMultipleTrees && !trees.isEmpty {
            return trees.reduce(0) { $0 + $1.cubicFeet() } + cubicFeet
        }
        return cubicFeet
    }
    
    private var allTreesForEstimate: [TreeItem] {
        var estimateTrees = trees
        if let c = Double(circumference), let h = Double(height), c > 0, h > 0 {
            estimateTrees.append(TreeItem(circumference: c, height: h, notes: ""))
        }
        return estimateTrees
    }
    
    private var subtotal: Double {
        return startingFee + (totalCubicFeet * pricePerCubicFoot)
    }
    
    private var discountAmount: Double {
        guard showDiscount else { return 0 }
        return subtotal * (defaultDiscountPercent / 100.0)
    }
    
    private var taxAmount: Double {
        guard showTaxCalculator else { return 0 }
        return (subtotal - discountAmount) * (taxRate / 100.0)
    }
    
    private var costEstimate: Double {
        return subtotal - discountAmount + taxAmount
    }
    
    private var unitLabel: String {
        useMetric ? "meters" : "feet"
    }
    
    private var hasValidInput: Bool {
        if let c = Double(circumference), let h = Double(height), c > 0, h > 0 {
            return true
        }
        return false
    }
    
    private var currentTreeIndex: Int {
        trees.count + 1
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    treeListSection
                    inputSection
                    resultsSection
                    actionButtons
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                    }
                }
                
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        if focusedField == .circumference {
                            Button("Done") {
                                focusedField = nil
                            }
                            .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Button("Next") {
                                focusedField = .height
                            }
                            .fontWeight(.semibold)
                        } else if focusedField == .height {
                            Spacer()
                            
                            Button("Done") {
                                focusedField = nil
                            }
                            .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingEstimateDetail) {
                EstimateDetailView(cubicFeet: totalCubicFeet, trees: allTreesForEstimate)
            }
            .sheet(isPresented: $showingHistory) {
                HistoryView()
            }
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
            Text("Tree Cost Calculator")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding(.top, 20)
    }

    @ViewBuilder
    private var treeListSection: some View {
        if showMultipleTrees && !trees.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Trees (\(trees.count))")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                ForEach(trees.indices, id: \.self) { index in
                    VStack(spacing: 0) {
                        treeHeader(for: index)
                        if expandedTreeIndex == index {
                            treeEditor
                        }
                    }
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                Button(role: .destructive, action: {
                    withAnimation {
                        trees.removeAll()
                        expandedTreeIndex = nil
                    }
                }) {
                    Label("Clear All Trees", systemImage: "trash.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(showMultipleTrees ? "Tree \(currentTreeIndex) Measurements" : "Tree Measurements")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                InputField(
                    icon: "ruler.fill",
                    title: "Base Circumference",
                    unit: unitLabel,
                    value: $circumference,
                    isFocused: focusedField == .circumference
                )
                .focused($focusedField, equals: .circumference)
                
                InputField(
                    icon: "arrow.up.to.line",
                    title: "Height",
                    unit: unitLabel,
                    value: $height,
                    isFocused: focusedField == .height
                )
                .focused($focusedField, equals: .height)
            }
            
            if showMultipleTrees {
                Button(action: { addTree() }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text(trees.isEmpty ? "Add Tree" : "Add Another Tree")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: hasValidInput ? [.blue, .cyan] : [.gray.opacity(0.3), .gray.opacity(0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(hasValidInput ? .white : .secondary)
                    .cornerRadius(12)
                }
                .disabled(!hasValidInput)
                .accessibilityHint(hasValidInput ? "Adds this tree to the list" : "Enter valid measurements to add a tree")
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var resultsSection: some View {
        VStack(spacing: 16) {
            ResultCard(
                icon: "shippingbox.fill",
                title: showMultipleTrees && !trees.isEmpty ? "Total Volume" : "Total Cubic Feet",
                value: totalCubicFeet,
                format: "%.2f",
                unit: useMetric ? "cu m" : "cu ft",
                color: .blue
            )
            
            ResultCard(
                icon: "banknote.fill",
                title: "Cost Estimate",
                value: costEstimate,
                format: "$%.2f",
                unit: "",
                color: .green
            )
            
            if (showDiscount && discountAmount > 0) || (showTaxCalculator && taxAmount > 0) {
                VStack(spacing: 8) {
                    if showDiscount && discountAmount > 0 {
                        HStack {
                            Text("Includes \(defaultDiscountPercent, specifier: "%.1f")% discount")
                            Spacer()
                            Text("-$\(discountAmount, specifier: "%.2f")")
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                    }
                    
                    if showTaxCalculator && taxAmount > 0 {
                        HStack {
                            Text("Includes \(taxRate, specifier: "%.1f")% tax")
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
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var actionButtons: some View {
        if hasValidInput {
            VStack(spacing: 12) {
                if showFullEstimate {
                    Button(action: { showingEstimateDetail = true }) {
                        Label("Create Full Estimate", systemImage: "doc.text.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .fontWeight(.semibold)
                    }
                }
                
                Button(action: { showingHistory = true }) {
                    Label("View History", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.primary.opacity(0.1))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                        .fontWeight(.medium)
                }

                Button(action: copyEstimate) {
                    Label("Copy Total", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.12))
                        .foregroundColor(.green)
                        .cornerRadius(12)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal)
        } else {
            Button(action: { showingHistory = true }) {
                Label("View History", systemImage: "clock.arrow.circlepath")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.primary.opacity(0.1))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                    .fontWeight(.medium)
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func treeHeader(for index: Int) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if expandedTreeIndex == index {
                    if let c = Double(editingTreeCirc), let h = Double(editingTreeHeight), c > 0, h > 0 {
                        trees[index].circumference = c
                        trees[index].height = h
                    }
                    expandedTreeIndex = nil
                } else {
                    expandedTreeIndex = index
                    editingTreeCirc = String(trees[index].circumference)
                    editingTreeHeight = String(trees[index].height)
                }
            }
        }) {
            HStack {
                Image(systemName: expandedTreeIndex == index ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tree \(index + 1)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    if expandedTreeIndex != index {
                        Text("\(trees[index].circumference, specifier: "%.1f") × \(trees[index].height, specifier: "%.1f") \(unitLabel)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if expandedTreeIndex != index {
                    Text("\(trees[index].cubicFeet(), specifier: "%.1f") cu ft")
                        .font(.callout)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    withAnimation {
                        trees.remove(at: index)
                        if expandedTreeIndex == index {
                            expandedTreeIndex = nil
                        }
                    }
                }) {
                    Image(systemName: "trash.circle.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.blue.opacity(expandedTreeIndex == index ? 0.1 : 0.05))
        }
        .buttonStyle(.plain)
    }

    private var treeEditor: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Circumference:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            HStack {
                TextField("0.0", text: $editingTreeCirc)
                    .keyboardType(.decimalPad)
                    .font(.title3.bold())
                    .padding()
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(10)
                Text(unitLabel)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
            }
            
            HStack {
                Text("Height:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            HStack {
                TextField("0.0", text: $editingTreeHeight)
                    .keyboardType(.decimalPad)
                    .font(.title3.bold())
                    .padding()
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(10)
                Text(unitLabel)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .leading)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
    }
    
    private func addTree() {
        guard let c = Double(circumference), let h = Double(height), c > 0, h > 0 else { return }
        trees.append(TreeItem(circumference: c, height: h, notes: ""))
        // Clear inputs for next tree
        circumference = ""
        height = ""
    }

    private func copyEstimate() {
        let text = String(format: "$%.2f", costEstimate)
        UIPasteboard.general.string = text
    }
}

// MARK: - Presets View
struct PresetsView: View {
    @ObservedObject var presetsManager: PresetsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var newPresetName = ""
    @State private var newPresetCirc = ""
    @State private var newPresetHeight = ""
    @State private var showingAddPreset = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Quick Presets")) {
                    ForEach(presetsManager.presets) { preset in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(preset.name)
                                    .fontWeight(.medium)
                                Text("\(preset.circumference, specifier: "%.1f") × \(preset.height, specifier: "%.1f") ft")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(preset.circumference * preset.circumference * preset.height / 12.56, specifier: "%.1f") cu ft")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .onDelete(perform: presetsManager.deletePreset)
                }
                
                Section {
                    Button(action: { showingAddPreset = true }) {
                        Label("Add New Preset", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .alert("New Preset", isPresented: $showingAddPreset) {
                TextField("Name", text: $newPresetName)
                TextField("Circumference", text: $newPresetCirc)
                TextField("Height", text: $newPresetHeight)
                Button("Cancel", role: .cancel) {
                    newPresetName = ""
                    newPresetCirc = ""
                    newPresetHeight = ""
                }
                Button("Add") {
                    if let circ = Double(newPresetCirc), let height = Double(newPresetHeight), !newPresetName.isEmpty {
                        presetsManager.addPreset(TreePreset(name: newPresetName, circumference: circ, height: height))
                    }
                    newPresetName = ""
                    newPresetCirc = ""
                    newPresetHeight = ""
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
