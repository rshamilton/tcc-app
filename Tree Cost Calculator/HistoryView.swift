//
//  HistoryView.swift
//  Tree Cost Calculator
//
//  Created by Ryan Hamilton on 1/9/26.
//

import SwiftUI
import UIKit

struct HistoryView: View {
    @EnvironmentObject private var history: CalculationHistory
    @State private var selectedCalculation: TreeCalculation?
    @State private var showingDetail = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if history.calculations.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No Saved Calculations")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Your calculation history will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(history.calculations) { calculation in
                            HistoryRow(calculation: calculation)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedCalculation = calculation
                                    showingDetail = true
                                }
                        }
                        .onDelete(perform: history.deleteCalculation)
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                
                if !history.calculations.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingDetail) {
                if let calculation = selectedCalculation {
                    HistoryDetailView(calculation: calculation)
                }
            }
        }
    }
}

// MARK: - History Row
struct HistoryRow: View {
    let calculation: TreeCalculation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if !calculation.customerName.isEmpty {
                    Text(calculation.customerName)
                        .font(.headline)
                } else {
                    Text("Estimate")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("$\(calculation.totalCost, specifier: "%.2f")")
                    .font(.headline)
                    .foregroundColor(.green)
            }
            
            HStack {
                Label("\(calculation.cubicFeet, specifier: "%.1f") cu ft", systemImage: "shippingbox.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !calculation.location.isEmpty {
                    Text("•")
                        .foregroundColor(.secondary)
                    Label(calculation.location, systemImage: "location.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Text(calculation.formattedDate)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - History Detail View
struct HistoryDetailView: View {
    let calculation: TreeCalculation
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var history: CalculationHistory
    @State private var showingShareSheet = false
    @State private var pdfData: Data?
    
    @AppStorage("useMetric") private var useMetric: Bool = false
    @AppStorage("companyName") private var companyName: String = ""
    @AppStorage("showTaxCalculator") private var showTaxCalculator: Bool = false
    @AppStorage("showDiscount") private var showDiscount: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Photos if available
                    if !calculation.photoDataList.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(calculation.photoDataList.enumerated()), id: \.offset) { index, data in
                                    if let uiImage = UIImage(data: data) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 160, height: 120)
                                            .clipped()
                                            .cornerRadius(12)
                                            .accessibilityLabel("Photo \(index + 1)")
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Customer Info
                    if !calculation.customerName.isEmpty || !calculation.location.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Customer Information")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            if !calculation.customerName.isEmpty {
                                HStack {
                                    Label("Name", systemImage: "person.fill")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(calculation.customerName)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            if !calculation.location.isEmpty {
                                HStack {
                                    Label("Location", systemImage: "location.fill")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(calculation.location)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        .padding()
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Tree Measurements
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tree Measurements")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Label("Circumference", systemImage: "ruler.fill")
                                .font(.subheadline)
                            Spacer()
                            Text("\(calculation.circumference, specifier: "%.2f") \(useMetric ? "m" : "ft")")
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Label("Height", systemImage: "arrow.up.to.line")
                                .font(.subheadline)
                            Spacer()
                            Text("\(calculation.height, specifier: "%.2f") \(useMetric ? "m" : "ft")")
                                .fontWeight(.semibold)
                        }
                        
                        Divider()
                        
                        HStack {
                            Label("Volume", systemImage: "shippingbox.fill")
                                .font(.subheadline)
                            Spacer()
                            Text("\(calculation.cubicFeet, specifier: "%.2f") cu \(useMetric ? "m" : "ft")")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Cost Details
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Cost Breakdown")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("Subtotal")
                                Spacer()
                                Text("$\(calculation.subtotal, specifier: "%.2f")")
                            }
                            
                            if showDiscount && calculation.discountAmount > 0 {
                                HStack {
                                    Text("Discount")
                                    Spacer()
                                    Text("-$\(calculation.discountAmount, specifier: "%.2f")")
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            if showTaxCalculator && calculation.taxAmount > 0 {
                                HStack {
                                    Text("Tax")
                                    Spacer()
                                    Text("$\(calculation.taxAmount, specifier: "%.2f")")
                                }
                            }
                            
                            Divider()
                            
                            HStack {
                                Text("Total")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Spacer()
                                Text("$\(calculation.totalCost, specifier: "%.2f")")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Notes
                    if !calculation.jobNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Job Notes")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text(calculation.jobNotes)
                                .font(.subheadline)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Date
                    Text(calculation.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Actions
                    VStack(spacing: 12) {
                        Button(action: shareEstimate) {
                            Label("Share / Export PDF", systemImage: "square.and.arrow.up.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .fontWeight(.semibold)
                        }
                        
                        Button(action: deleteEstimate) {
                            Label("Delete", systemImage: "trash.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(12)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
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
            }
            .sheet(isPresented: $showingShareSheet) {
                if let pdfData = pdfData {
                    ShareSheet(items: [pdfData])
                }
            }
        }
    }
    
    private func shareEstimate() {
        pdfData = generatePDF(for: calculation)
        showingShareSheet = true
    }
    
    private func deleteEstimate() {
        history.deleteCalculation(calculation)
        dismiss()
    }
    
    private func generatePDF(for calculation: TreeCalculation) -> Data {
        // Reuse the same PDF generation logic from EstimateDetailView
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
            
            var yPosition: CGFloat = 50
            let font12 = UIFont.systemFont(ofSize: 12)
            let font14Bold = UIFont.boldSystemFont(ofSize: 14)
            let font24Bold = UIFont.boldSystemFont(ofSize: 24)
            
            // Title
            let title = companyName.isEmpty ? "TREE REMOVAL ESTIMATE" : companyName.uppercased()
            title.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [.font: font24Bold])
            yPosition += 40
            
            // Date
            "Date: \(calculation.formattedDate)".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [.font: font12])
            yPosition += 30
            
            // Customer Info
            if !calculation.customerName.isEmpty || !calculation.location.isEmpty {
                "CUSTOMER INFORMATION".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [.font: font14Bold])
                yPosition += 25
                if !calculation.customerName.isEmpty {
                    "Name: \(calculation.customerName)".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [.font: font12])
                    yPosition += 20
                }
                if !calculation.location.isEmpty {
                    "Location: \(calculation.location)".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [.font: font12])
                    yPosition += 30
                }
            }
            
            // Measurements and cost
            "TREE MEASUREMENTS".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [.font: font14Bold])
            yPosition += 25
            String(format: "Circumference: %.2f %@", calculation.circumference, useMetric ? "m" : "ft").draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [.font: font12])
            yPosition += 20
            String(format: "Height: %.2f %@", calculation.height, useMetric ? "m" : "ft").draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [.font: font12])
            yPosition += 20
            String(format: "Volume: %.2f cu %@", calculation.cubicFeet, useMetric ? "m" : "ft").draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [.font: font12])
            yPosition += 35
            
            // Cost
            "COST BREAKDOWN".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [.font: font14Bold])
            yPosition += 25
            "Subtotal:".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [.font: font12])
            String(format: "$%.2f", calculation.subtotal).draw(at: CGPoint(x: pageWidth - 100, y: yPosition), withAttributes: [.font: font12])
            yPosition += 20
            
            if calculation.discountAmount > 0 {
                "Discount:".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [.font: font12])
                String(format: "-$%.2f", calculation.discountAmount).draw(at: CGPoint(x: pageWidth - 100, y: yPosition), withAttributes: [.font: font12])
                yPosition += 20
            }
            
            if calculation.taxAmount > 0 {
                "Tax:".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [.font: font12])
                String(format: "$%.2f", calculation.taxAmount).draw(at: CGPoint(x: pageWidth - 100, y: yPosition), withAttributes: [.font: font12])
                yPosition += 20
            }
            
            yPosition += 5
            "TOTAL:".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 16)])
            String(format: "$%.2f", calculation.totalCost).draw(at: CGPoint(x: pageWidth - 100, y: yPosition), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 16)])
            yPosition += 35
            
            // Notes
            if !calculation.jobNotes.isEmpty {
                "NOTES".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [.font: font14Bold])
                yPosition += 25
                let rect = CGRect(x: 50, y: yPosition, width: pageWidth - 100, height: 1000)
                calculation.jobNotes.draw(in: rect, withAttributes: [.font: UIFont.systemFont(ofSize: 10)])
                yPosition += 120
            }

            // Photos
            if !calculation.photoDataList.isEmpty {
                if yPosition > pageHeight - 300 {
                    context.beginPage()
                    yPosition = 50
                }
                "PHOTOS".draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [.font: font14Bold])
                yPosition += 25

                for (index, data) in calculation.photoDataList.enumerated() {
                    guard let image = UIImage(data: data) else { continue }
                    if yPosition > pageHeight - 300 {
                        context.beginPage()
                        yPosition = 50
                    }
                    let label = "Photo \(index + 1)"
                    label.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: [.font: font12])
                    yPosition += 18

                    let maxImageWidth: CGFloat = pageWidth - 100
                    let maxImageHeight: CGFloat = 280
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

                    let imageRect = CGRect(x: 50, y: yPosition, width: imageWidth, height: imageHeight)
                    image.draw(in: imageRect)
                    yPosition += imageHeight + 20
                }
            }
        }
        
        return data
    }
}

#Preview {
    HistoryView()
        .environmentObject(CalculationHistory())
}
