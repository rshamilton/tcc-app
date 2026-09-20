//
//  SettingsView.swift
//  Tree Cost Calculator
//
//  Created by Ryan Hamilton on 1/9/26.
//

import SwiftUI
import PhotosUI
import UIKit

struct SettingsView: View {
    // Pricing
    @AppStorage("startingFee") private var startingFee: Double = 150.0
    @AppStorage("pricePerCubicFoot") private var pricePerCubicFoot: Double = 15.0
    
    // Feature Toggles
    @AppStorage("showTaxCalculator") private var showTaxCalculator: Bool = true
    @AppStorage("taxRate") private var taxRate: Double = 8.5
    
    @AppStorage("showDiscount") private var showDiscount: Bool = true
    @AppStorage("defaultDiscountPercent") private var defaultDiscountPercent: Double = 10.0
    
    @AppStorage("showFullEstimate") private var showFullEstimate: Bool = true
    @AppStorage("showJobNotes") private var showJobNotes: Bool = true
    @AppStorage("showPhotoAttachment") private var showPhotoAttachment: Bool = true
    @AppStorage("includePhotoInPDF") private var includePhotoInPDF: Bool = true
    @AppStorage("showAdditionalCharge") private var showAdditionalCharge: Bool = true
    @AppStorage("showMultipleTrees") private var showMultipleTrees: Bool = true
    @AppStorage("showIndividualTrees") private var showIndividualTrees: Bool = true
    
    @AppStorage("useMetric") private var useMetric: Bool = false
    @AppStorage("companyName") private var companyName: String = ""
    @AppStorage("companyLogoData") private var companyLogoData: Data = Data()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLogoItem: PhotosPickerItem?
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Company Information")) {
                    TextField("Company Name (Optional)", text: $companyName)
                }

                Section(header: Text("Branding")) {
                    if let logoImage = UIImage(data: companyLogoData), !companyLogoData.isEmpty {
                        HStack(spacing: 16) {
                            Image(uiImage: logoImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .cornerRadius(12)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Company Logo")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Shown on estimates and PDFs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    PhotosPicker(selection: $selectedLogoItem, matching: .images) {
                        Label(companyLogoData.isEmpty ? "Add Logo" : "Change Logo", systemImage: "photo.fill")
                    }

                    if !companyLogoData.isEmpty {
                        Button(role: .destructive) {
                            companyLogoData = Data()
                        } label: {
                            Label("Remove Logo", systemImage: "trash")
                        }
                    }
                }
                
                Section(header: Text("Pricing Configuration")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Starting Fee")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            Text("$")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            TextField("0.00", value: $startingFee, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Price per Cubic Foot")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack {
                            Text("$")
                                .font(.title3)
                                .foregroundColor(.secondary)
                            TextField("0.00", value: $pricePerCubicFoot, format: .number)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Tax & Discounts")) {
                    Toggle("Enable Tax Calculator", isOn: $showTaxCalculator)
                    
                    if showTaxCalculator {
                        HStack {
                            Text("Tax Rate")
                            Spacer()
                            TextField("0.0", value: $taxRate, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("%")
                        }
                    }
                    
                    Toggle("Enable Discounts", isOn: $showDiscount)
                    
                    if showDiscount {
                        HStack {
                            Text("Default Discount")
                            Spacer()
                            TextField("0.0", value: $defaultDiscountPercent, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("%")
                        }
                    }
                }
                
                Section(header: Text("Features")) {
                    Toggle("Full Estimate View", isOn: $showFullEstimate)
                        .accessibilityHint("Show detailed estimate view with customer information and notes")
                    Toggle("Job Notes", isOn: $showJobNotes)
                        .accessibilityHint("Enable notes field in estimates")
                    Toggle("Photo Attachment", isOn: $showPhotoAttachment)
                        .accessibilityHint("Allow attaching photos to estimates")
                    Toggle("Include Photo in PDF", isOn: $includePhotoInPDF)
                        .accessibilityHint("Add attached photos to exported PDF documents")
                    Toggle("Additional Charge", isOn: $showAdditionalCharge)
                        .accessibilityHint("Show field for custom additional charges in quotes")
                    Toggle("Multiple Trees", isOn: $showMultipleTrees)
                        .accessibilityHint("Enable multiple tree entries per quote")
                    Toggle("Show Individual Trees", isOn: $showIndividualTrees)
                        .accessibilityHint("Display each tree's measurements separately in estimates")
                }
                
                Section(header: Text("Measurement Units")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 0) {
                            Button(action: { useMetric = false }) {
                                HStack {
                                    Image(systemName: useMetric ? "circle" : "checkmark.circle.fill")
                                    Text("Imperial (Feet)")
                                        .fontWeight(useMetric ? .regular : .semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(useMetric ? Color.clear : Color.blue.opacity(0.15))
                                .foregroundColor(useMetric ? .secondary : .blue)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: { useMetric = true }) {
                                HStack {
                                    Image(systemName: useMetric ? "checkmark.circle.fill" : "circle")
                                    Text("Metric (Meters)")
                                        .fontWeight(useMetric ? .semibold : .regular)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(useMetric ? Color.blue.opacity(0.15) : Color.clear)
                                .foregroundColor(useMetric ? .blue : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(10)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section(header: Text("Support & Privacy")) {
                    Link(destination: URL(string: "https://ryham.me/treecostcalculator/support")!) {
                        Label("Support", systemImage: "lifepreserver.fill")
                    }
                    .accessibilityHint("Open the support page")

                    Link(destination: URL(string: "https://ryham.me/treecostcalculator/privacy")!) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                    .accessibilityHint("Open the privacy policy")
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("View Onboarding Again") {
                        hasCompletedOnboarding = false
                    }
                    .foregroundColor(.blue)
                }
            }
            .onChange(of: selectedLogoItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        companyLogoData = data
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
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
        }
    }
}

