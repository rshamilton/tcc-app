//
//  EstimateDetailView.swift
//  Tree Cost Calculator
//
//  Created by Ryan Hamilton on 1/9/26.
//

import SwiftUI
import PhotosUI
import UIKit

struct EstimateDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var history: CalculationHistory
    
    // Settings
    @AppStorage("startingFee") private var startingFee: Double = 0.0
    @AppStorage("pricePerCubicFoot") private var pricePerCubicFoot: Double = 10.0
    @AppStorage("showTaxCalculator") private var showTaxCalculator: Bool = false
    @AppStorage("taxRate") private var taxRate: Double = 0.0
    @AppStorage("showDiscount") private var showDiscount: Bool = false
    @AppStorage("useMetric") private var useMetric: Bool = false
    @AppStorage("companyName") private var companyName: String = ""
    @AppStorage("companyLogoData") private var companyLogoData: Data = Data()
    @AppStorage("showIndividualTrees") private var showIndividualTrees: Bool = true
    @AppStorage("showJobNotes") private var showJobNotes: Bool = true
    @AppStorage("showPhotoAttachment") private var showPhotoAttachment: Bool = true
    @AppStorage("includePhotoInPDF") private var includePhotoInPDF: Bool = true
    
    // Passed data
    let cubicFeet: Double
    let trees: [TreeItem]
    
    // State for estimate details
    @State private var customerName: String = ""
    @State private var location: String = ""
    @State private var jobNotes: String = ""
    
    // Discount & Charge state
    @State private var discountAmount: Double = 0
    @State private var discountType: ChargeType = .percentage
    @State private var additionalChargeAmount: Double = 0
    @State private var additionalChargeType: ChargeType = .fixed
    @State private var additionalChargeDescription: String = ""
    
    // Photo state
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoDataList: [Data] = []
    @State private var showingShareSheet = false
    @State private var pdfData: Data?
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var showingPhotoOptions = false
    @State private var historyEntryId: UUID?
    @State private var historyEntryDate: Date?
    
    init(cubicFeet: Double, trees: [TreeItem]) {
        self.cubicFeet = cubicFeet
        self.trees = trees
    }
    
    // MARK: - Computed Properties
    private var volumeCost: Double {
        cubicFeet * pricePerCubicFoot
    }
    
    private var baseSubtotal: Double {
        startingFee + volumeCost
    }
    
    private var calculatedAdditionalCharge: Double {
        guard additionalChargeAmount > 0 else { return 0 }
        if additionalChargeType == .percentage {
            return baseSubtotal * (additionalChargeAmount / 100.0)
        } else {
            return additionalChargeAmount
        }
    }
    
    private var subtotal: Double {
        baseSubtotal + calculatedAdditionalCharge
    }
    
    private var calculatedDiscountAmount: Double {
        guard showDiscount && discountAmount > 0 else { return 0 }
        if discountType == .percentage {
            return subtotal * (discountAmount / 100.0)
        } else {
            return discountAmount
        }
    }
    
    private var afterDiscount: Double {
        subtotal - calculatedDiscountAmount
    }
    
    private var calculatedTaxAmount: Double {
        guard showTaxCalculator else { return 0 }
        return afterDiscount * (taxRate / 100.0)
    }
    
    private var totalCost: Double {
        afterDiscount + calculatedTaxAmount
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Header with company info
                        headerSection
                        
                        // Main content
                        VStack(spacing: 20) {
                            customerInfoSection
                            treeMeasurementsSection
                            discountChargeSection
                            costBreakdownSection
                            
                            if showPhotoAttachment {
                                photoAttachmentSection
                            }
                            
                            if showJobNotes {
                                jobNotesSection
                            }
                        }
                        .padding(16)
                        
                        // Action button
                        actionButtonsSection
                    }
                }
                .navigationTitle("Estimate Details")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .keyboard) {
                        HStack {
                            Spacer()
                            Button("Done") {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                            .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .sheet(isPresented: $showingShareSheet) {
                    if let pdfData = pdfData {
                        ShareSheet(items: [pdfData])
                    }
                }
                .sheet(isPresented: $showingCamera) {
                    ImagePicker(sourceType: .camera) { image in
                        if let data = image.jpegData(compressionQuality: 0.85) {
                            photoDataList.append(data)
                        }
                    }
                }
                .photosPicker(isPresented: $showingPhotoLibrary, selection: $selectedPhotos, maxSelectionCount: 8, matching: .images)
                .confirmationDialog("Add Photo", isPresented: $showingPhotoOptions) {
                    Button("Take Photo") {
                        showingCamera = true
                    }
                    Button("Choose from Library") {
                        showingPhotoLibrary = true
                    }
                    Button("Cancel", role: .cancel) {}
                }
                .onChange(of: selectedPhotos) { _, newValue in
                    Task {
                        await appendSelectedPhotos(newValue)
                        selectedPhotos = []
                    }
                }
                .onAppear {
                    saveOrUpdateHistory()
                }
                .onChange(of: customerName) { _, _ in saveOrUpdateHistory() }
                .onChange(of: location) { _, _ in saveOrUpdateHistory() }
                .onChange(of: jobNotes) { _, _ in saveOrUpdateHistory() }
                .onChange(of: discountAmount) { _, _ in saveOrUpdateHistory() }
                .onChange(of: photoDataList) { _, _ in saveOrUpdateHistory() }
                .onDisappear {
                    saveOrUpdateHistory()
                }
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 12) {
            if let logoImage = UIImage(data: companyLogoData), !companyLogoData.isEmpty {
                Image(uiImage: logoImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 70)
            }
            
            if !companyName.isEmpty {
                Text(companyName)
                    .font(.system(.title2, design: .default))
                    .fontWeight(.bold)
            }
            
            Text("Tree Removal Estimate")
                .font(.system(.subheadline, design: .default))
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatDate())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.systemGray6))
    }
    
    private var customerInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Customer Information", icon: "person.fill")
            
            VStack(spacing: 12) {
                TextField("Customer Name", text: $customerName)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Location / Address", text: $location)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var treeMeasurementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Tree Measurements", icon: "tree.fill")
            
            VStack(spacing: 12) {
                if showIndividualTrees && !trees.isEmpty {
                    ForEach(Array(trees.enumerated()), id: \.offset) { index, tree in
                        treeCard(index: index, tree: tree)
                    }
                }
                
                VStack(spacing: 8) {
                    HStack {
                        Label("Total Volume", systemImage: "shippingbox.fill")
                            .font(.system(.subheadline, design: .default))
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(cubicFeet, specifier: "%.2f") cu \(useMetric ? "m" : "ft")")
                            .font(.system(.subheadline, design: .default))
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func treeCard(index: Int, tree: TreeItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tree \(index + 1)")
                .font(.system(.subheadline, design: .default))
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Circumference", systemImage: "ruler.fill")
                        .font(.system(.caption2, design: .default))
                        .foregroundColor(.secondary)
                    Text("\(tree.circumference, specifier: "%.2f") \(useMetric ? "m" : "ft")")
                        .font(.system(.subheadline, design: .default))
                        .fontWeight(.semibold)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Label("Height", systemImage: "arrow.up")
                        .font(.system(.caption2, design: .default))
                        .foregroundColor(.secondary)
                    Text("\(tree.height, specifier: "%.2f") \(useMetric ? "m" : "ft")")
                        .font(.system(.subheadline, design: .default))
                        .fontWeight(.semibold)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Label("Volume", systemImage: "cube.fill")
                        .font(.system(.caption2, design: .default))
                        .foregroundColor(.secondary)
                    Text("\(tree.cubicFeet(), specifier: "%.2f") cu ft")
                        .font(.system(.subheadline, design: .default))
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            if !tree.photoDataList.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(tree.photoDataList.enumerated()), id: \.offset) { photoIndex, data in
                            if let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 90)
                                    .clipped()
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var discountChargeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Discounts & Charges", icon: "percent")
            
            VStack(spacing: 12) {
                if showDiscount {
                    discountEditor
                }
                
                additionalChargeEditor
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var discountEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Discount", systemImage: "minus.circle.fill")
                    .font(.system(.subheadline, design: .default))
                    .foregroundColor(.orange)
                Spacer()
                Text("-\(calculatedDiscountAmount, specifier: "$%.2f")")
                    .font(.system(.subheadline, design: .default))
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }
            
            HStack(spacing: 12) {
                TextField("Amount", value: $discountAmount, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                
                Picker("Type", selection: $discountType) {
                    Text("%").tag(ChargeType.percentage)
                    Text("$").tag(ChargeType.fixed)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var additionalChargeEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Additional Charge", systemImage: "plus.circle.fill")
                    .font(.system(.subheadline, design: .default))
                    .foregroundColor(.blue)
                Spacer()
                Text("+\(calculatedAdditionalCharge, specifier: "$%.2f")")
                    .font(.system(.subheadline, design: .default))
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            }
            
            TextField("Description (optional)", text: $additionalChargeDescription)
                .textFieldStyle(.roundedBorder)
                .font(.system(.caption, design: .default))
            
            HStack(spacing: 12) {
                TextField("Amount", value: $additionalChargeAmount, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                
                Picker("Type", selection: $additionalChargeType) {
                    Text("$").tag(ChargeType.fixed)
                    Text("%").tag(ChargeType.percentage)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }
        }
        .padding(12)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var costBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Cost Breakdown", icon: "dollarsign.circle.fill")
            
            VStack(spacing: 12) {
                breakdownRow("Starting Fee", startingFee)
                breakdownRow("Volume Cost", volumeCost, secondary: true)
                
                Divider()
                
                breakdownRow("Subtotal", baseSubtotal, bold: true)
                
                if calculatedAdditionalCharge > 0 {
                    breakdownRow(additionalChargeDescription.isEmpty ? "Additional Charge" : additionalChargeDescription, calculatedAdditionalCharge, color: .blue)
                }
                
                if calculatedDiscountAmount > 0 {
                    breakdownRow("Discount", -calculatedDiscountAmount, color: .orange)
                }
                
                if showTaxCalculator && calculatedTaxAmount > 0 {
                    breakdownRow("Tax (\(String(format: "%.1f", taxRate))%)", calculatedTaxAmount)
                }
                
                Divider()
                
                HStack {
                    Text("Total")
                        .font(.system(.headline, design: .default))
                        .fontWeight(.bold)
                    Spacer()
                    Text(totalCost, format: .currency(code: "USD"))
                        .font(.system(.headline, design: .default))
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                .padding(12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func breakdownRow(_ label: String, _ value: Double, bold: Bool = false, secondary: Bool = false, color: Color = .primary) -> some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .default))
                .fontWeight(bold ? .semibold : .regular)
                .foregroundColor(secondary ? .secondary : color)
            
            Spacer()
            
            Text(value, format: .currency(code: "USD"))
                .font(.system(.subheadline, design: .default))
                .fontWeight(bold ? .semibold : .regular)
                .foregroundColor(secondary ? .secondary : color)
        }
    }
    
    @ViewBuilder
    private var photoAttachmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Photos", icon: "photo.fill")
            
            if !photoDataList.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(photoDataList.enumerated()), id: \.offset) { index, data in
                            if let uiImage = UIImage(data: data) {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 150, height: 120)
                                        .clipped()
                                        .cornerRadius(10)
                                    
                                    Button(action: { removePhoto(at: index) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .shadow(radius: 2)
                                    }
                                    .padding(8)
                                }
                            }
                        }
                    }
                }
            }
            
            Button(action: { showingPhotoOptions = true }) {
                Label(photoDataList.isEmpty ? "Add Photo" : "Add Another Photo", systemImage: "photo.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
                    .fontWeight(.semibold)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var jobNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Job Notes", icon: "note.text")
            
            TextEditor(text: $jobNotes)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button(action: shareEstimate) {
                Label("Share / Export PDF", systemImage: "square.and.arrow.up.fill")
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .fontWeight(.semibold)
            }
        }
        .padding(16)
    }
    
    // MARK: - Helper Methods
    
    private func formatDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }
    
    private func shareEstimate() {
        pdfData = generatePDF()
        showingShareSheet = true
    }
    
    private func removePhoto(at index: Int) {
        guard photoDataList.indices.contains(index) else { return }
        photoDataList.remove(at: index)
    }
    
    private func appendSelectedPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                photoDataList.append(data)
            }
        }
    }
    
    private func saveOrUpdateHistory() {
        let combinedPhotos = photoDataList + trees.flatMap { $0.photoDataList }
        let calculationId = historyEntryId ?? UUID()
        let calculationDate = historyEntryDate ?? Date()
        let calculation = TreeCalculation(
            id: calculationId,
            date: calculationDate,
            circumference: trees.first?.circumference ?? 0,
            height: trees.first?.height ?? 0,
            cubicFeet: cubicFeet,
            subtotal: subtotal,
            discountAmount: calculatedDiscountAmount,
            taxAmount: calculatedTaxAmount,
            totalCost: totalCost,
            jobNotes: jobNotes,
            customerName: customerName,
            location: location,
            photoDataList: combinedPhotos
        )
        historyEntryId = calculationId
        historyEntryDate = calculationDate
        history.updateCalculation(calculation)
    }
    
    private func generatePDF() -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: companyName.isEmpty ? "Tree Cost Calculator" : companyName,
            kCGPDFContextTitle: "Tree Removal Estimate"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = 40
            let marginLeft: CGFloat = 40
            let marginRight: CGFloat = 40
            let contentWidth = pageWidth - marginLeft - marginRight
            
            // Logo
            if let logoImage = UIImage(data: companyLogoData), !companyLogoData.isEmpty {
                let maxLogoWidth: CGFloat = 100
                let aspectRatio = logoImage.size.width / logoImage.size.height
                let logoHeight = maxLogoWidth / aspectRatio
                let logoRect = CGRect(x: marginLeft, y: yPosition, width: maxLogoWidth, height: logoHeight)
                logoImage.draw(in: logoRect)
                yPosition += logoHeight + 20
            }
            
            // Title
            let title = companyName.isEmpty ? "TREE REMOVAL ESTIMATE" : companyName.uppercased()
            drawText(title, at: CGPoint(x: marginLeft, y: yPosition), fontSize: 26, bold: true, maxWidth: contentWidth)
            yPosition += 35
            
            // Date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            drawText("Date: \(dateFormatter.string(from: Date()))", at: CGPoint(x: marginLeft, y: yPosition), fontSize: 11, maxWidth: contentWidth)
            yPosition += 25
            
            // Customer Info
            if !customerName.isEmpty || !location.isEmpty {
                drawText("CUSTOMER INFORMATION", at: CGPoint(x: marginLeft, y: yPosition), fontSize: 12, bold: true)
                yPosition += 18
                if !customerName.isEmpty {
                    drawText("Name: \(customerName)", at: CGPoint(x: marginLeft, y: yPosition), fontSize: 11, maxWidth: contentWidth)
                    yPosition += 16
                }
                if !location.isEmpty {
                    drawText("Location: \(location)", at: CGPoint(x: marginLeft, y: yPosition), fontSize: 11, maxWidth: contentWidth)
                    yPosition += 20
                }
                yPosition += 5
            }
            
            // Measurements
            drawText("TREE MEASUREMENTS", at: CGPoint(x: marginLeft, y: yPosition), fontSize: 12, bold: true)
            yPosition += 18
            
            if showIndividualTrees && !trees.isEmpty {
                for (index, tree) in trees.enumerated() {
                    drawText("Tree \(index + 1):", at: CGPoint(x: marginLeft, y: yPosition), fontSize: 11, bold: true)
                    yPosition += 16
                    drawText("  Circumference: \(String(format: "%.2f", tree.circumference)) \(useMetric ? "m" : "ft")", at: CGPoint(x: marginLeft, y: yPosition), fontSize: 10, maxWidth: contentWidth)
                    yPosition += 14
                    drawText("  Height: \(String(format: "%.2f", tree.height)) \(useMetric ? "m" : "ft")", at: CGPoint(x: marginLeft, y: yPosition), fontSize: 10, maxWidth: contentWidth)
                    yPosition += 14
                    drawText("  Volume: \(String(format: "%.2f", tree.cubicFeet())) cu \(useMetric ? "m" : "ft")", at: CGPoint(x: marginLeft, y: yPosition), fontSize: 10, maxWidth: contentWidth)
                    yPosition += 18
                    
                    // Tree photos
                    if !tree.photoDataList.isEmpty && includePhotoInPDF {
                        for photoData in tree.photoDataList.prefix(1) {
                            guard let image = UIImage(data: photoData) else { continue }
                            if yPosition > pageHeight - 200 {
                                context.beginPage()
                                yPosition = 40
                            }
                            
                            let maxImageWidth: CGFloat = contentWidth * 0.7
                            let maxImageHeight: CGFloat = 150
                            let aspectRatio = image.size.width / image.size.height
                            
                            let imageWidth: CGFloat
                            let imageHeight: CGFloat
                            
                            if aspectRatio > 1 {
                                imageWidth = min(maxImageWidth, image.size.width)
                                imageHeight = imageWidth / aspectRatio
                            } else {
                                imageHeight = min(maxImageHeight, image.size.height)
                                imageWidth = imageHeight * aspectRatio
                            }
                            
                            let imageRect = CGRect(x: marginLeft + 10, y: yPosition, width: imageWidth, height: imageHeight)
                            image.draw(in: imageRect)
                            yPosition += imageHeight + 16
                        }
                    }
                }
            }
            
            drawText("Total Volume: \(String(format: "%.2f", cubicFeet)) cu \(useMetric ? "m" : "ft")", at: CGPoint(x: marginLeft, y: yPosition), fontSize: 11, bold: true, maxWidth: contentWidth)
            yPosition += 25
            
            // Cost Breakdown
            drawText("COST BREAKDOWN", at: CGPoint(x: marginLeft, y: yPosition), fontSize: 12, bold: true)
            yPosition += 18
            
            drawText("Starting Fee:", at: CGPoint(x: marginLeft, y: yPosition), fontSize: 11, maxWidth: contentWidth * 0.6)
            drawText("$\(String(format: "%.2f", startingFee))", at: CGPoint(x: pageWidth - marginRight - 60, y: yPosition), fontSize: 11)
            yPosition += 14
            
            drawText("Volume Cost (\(String(format: "%.2f", cubicFeet)) cu ft × $\(String(format: "%.2f", pricePerCubicFoot))):", at: CGPoint(x: marginLeft, y: yPosition), fontSize: 11, maxWidth: contentWidth * 0.6)
            drawText("$\(String(format: "%.2f", volumeCost))", at: CGPoint(x: pageWidth - marginRight - 60, y: yPosition), fontSize: 11)
            yPosition += 14
            
            if calculatedAdditionalCharge > 0 {
                let chargeLabel = additionalChargeDescription.isEmpty ? "Additional Charge:" : "\(additionalChargeDescription):"
                drawText(chargeLabel, at: CGPoint(x: marginLeft, y: yPosition), fontSize: 11, maxWidth: contentWidth * 0.6)
                drawText("$\(String(format: "%.2f", calculatedAdditionalCharge))", at: CGPoint(x: pageWidth - marginRight - 60, y: yPosition), fontSize: 11)
                yPosition += 14
            }
            
            yPosition += 3
            drawLine(from: CGPoint(x: marginLeft, y: yPosition), to: CGPoint(x: pageWidth - marginRight, y: yPosition))
            yPosition += 8
            
            drawText("Subtotal:", at: CGPoint(x: marginLeft, y: yPosition), fontSize: 11, bold: true, maxWidth: contentWidth * 0.6)
            drawText("$\(String(format: "%.2f", subtotal))", at: CGPoint(x: pageWidth - marginRight - 60, y: yPosition), fontSize: 11, bold: true)
            yPosition += 14
            
            if calculatedDiscountAmount > 0 {
                let discountLabel = discountType == .percentage ? "Discount (\(String(format: "%.1f", discountAmount))%):" : "Discount:"
                drawText(discountLabel, at: CGPoint(x: marginLeft, y: yPosition), fontSize: 11, maxWidth: contentWidth * 0.6)
                drawText("-$\(String(format: "%.2f", calculatedDiscountAmount))", at: CGPoint(x: pageWidth - marginRight - 60, y: yPosition), fontSize: 11)
                yPosition += 14
            }
            
            if showTaxCalculator && calculatedTaxAmount > 0 {
                drawText("Tax (\(String(format: "%.1f", taxRate))%):", at: CGPoint(x: marginLeft, y: yPosition), fontSize: 11, maxWidth: contentWidth * 0.6)
                drawText("$\(String(format: "%.2f", calculatedTaxAmount))", at: CGPoint(x: pageWidth - marginRight - 60, y: yPosition), fontSize: 11)
                yPosition += 14
            }
            
            yPosition += 3
            drawLine(from: CGPoint(x: marginLeft, y: yPosition), to: CGPoint(x: pageWidth - marginRight, y: yPosition))
            yPosition += 12
            
            drawText("TOTAL:", at: CGPoint(x: marginLeft, y: yPosition), fontSize: 14, bold: true, maxWidth: contentWidth * 0.6)
            drawText("$\(String(format: "%.2f", totalCost))", at: CGPoint(x: pageWidth - marginRight - 60, y: yPosition), fontSize: 14, bold: true)
            yPosition += 30
            
            // Notes
            if showJobNotes && !jobNotes.isEmpty {
                drawText("NOTES", at: CGPoint(x: marginLeft, y: yPosition), fontSize: 12, bold: true)
                yPosition += 18
                drawText(jobNotes, at: CGPoint(x: marginLeft, y: yPosition), fontSize: 10, maxWidth: contentWidth)
                yPosition += 50
            }
            
            // Photos
            if includePhotoInPDF && !photoDataList.isEmpty {
                for (index, data) in photoDataList.enumerated() {
                    guard let image = UIImage(data: data) else { continue }
                    if yPosition > pageHeight - 250 {
                        context.beginPage()
                        yPosition = 40
                    }
                    
                    drawText("PHOTO \(index + 1)", at: CGPoint(x: marginLeft, y: yPosition), fontSize: 12, bold: true)
                    yPosition += 20
                    
                    let maxImageWidth: CGFloat = contentWidth * 0.8
                    let maxImageHeight: CGFloat = 250
                    let aspectRatio = image.size.width / image.size.height
                    
                    let imageWidth: CGFloat
                    let imageHeight: CGFloat
                    
                    if aspectRatio > 1 {
                        imageWidth = min(maxImageWidth, image.size.width)
                        imageHeight = imageWidth / aspectRatio
                    } else {
                        imageHeight = min(maxImageHeight, image.size.height)
                        imageWidth = imageHeight * aspectRatio
                    }
                    
                    let imageRect = CGRect(x: marginLeft + 10, y: yPosition, width: imageWidth, height: imageHeight)
                    image.draw(in: imageRect)
                    yPosition += imageHeight + 20
                }
            }
        }
        
        return data
    }
    
    private func drawText(_ text: String, at point: CGPoint, fontSize: CGFloat, bold: Bool = false, maxWidth: CGFloat? = nil) {
        let font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.black]
        
        if let maxWidth = maxWidth {
            let nsString = text as NSString
            let rect = CGRect(x: point.x, y: point.y, width: maxWidth, height: 1000)
            nsString.draw(in: rect, withAttributes: attributes)
        } else {
            (text as NSString).draw(at: point, withAttributes: attributes)
        }
    }
    
    private func drawLine(from: CGPoint, to: CGPoint) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setLineWidth(0.5)
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.move(to: from)
        context.addLine(to: to)
        context.strokePath()
    }
}

// MARK: - Helper Views

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(.subheadline, design: .default))
                .foregroundColor(.green)
            
            Text(title)
                .font(.system(.subheadline, design: .default))
                .fontWeight(.semibold)
            
            Spacer()
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImagePicked: (UIImage) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    EstimateDetailView(cubicFeet: 45.5, trees: [
        TreeItem(circumference: 5.0, height: 35.0, notes: ""),
        TreeItem(circumference: 4.5, height: 30.0, notes: "")
    ])
    .environmentObject(CalculationHistory())
}
