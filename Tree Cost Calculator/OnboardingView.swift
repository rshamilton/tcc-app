//
//  OnboardingView.swift
//  Tree Cost Calculator
//
//  Created by Ryan Hamilton on 1/9/26.
//

import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.green.opacity(0.3), Color.mint.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") {
                        hasCompletedOnboarding = true
                    }
                    .foregroundColor(.secondary)
                    .padding()
                }
                
                Spacer()
                
                // Page content
                TabView(selection: $currentPage) {
                    OnboardingPage(
                        icon: "leaf.fill",
                        iconGradient: [.green, .mint],
                        title: "Welcome to Tree Cost Calculator",
                        description: "Calculate tree removal costs quickly and professionally. Perfect for contractors and arborists."
                    )
                    .tag(0)
                    
                    OnboardingPage(
                        icon: "ruler.fill",
                        iconGradient: [.blue, .cyan],
                        title: "Easy Measurements",
                        description: "Simply enter the tree's base circumference and height. The app automatically calculates the cubic footage."
                    )
                    .tag(1)
                    
                    OnboardingPage(
                        icon: "gearshape.fill",
                        iconGradient: [.orange, .yellow],
                        title: "Customize Your Pricing",
                        description: "Set your starting fee and price per cubic foot in Settings. Add tax calculations and discounts as needed."
                    )
                    .tag(2)
                    
                    OnboardingPage(
                        icon: "doc.text.fill",
                        iconGradient: [.purple, .pink],
                        title: "Professional Estimates",
                        description: "Create detailed estimates with customer info, photos, and notes. Export as PDF to share with clients."
                    )
                    .tag(3)
                    
                    OnboardingPage(
                        icon: "clock.arrow.circlepath",
                        iconGradient: [.indigo, .blue],
                        title: "Track Your Work",
                        description: "All calculations are automatically saved to History. Review past estimates anytime."
                    )
                    .tag(4)

                    OnboardingPage(
                        icon: "hand.raised.fill",
                        iconGradient: [.green, .teal],
                        title: "Your Data Stays Private",
                        description: "Estimates are stored on your device. Support and privacy info are available in Settings."
                    )
                    .tag(5)
                    
                    OnboardingFinalPage(onComplete: {
                        hasCompletedOnboarding = true
                    })
                    .tag(6)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                Spacer()
                
                // Navigation buttons - only show when not on final page
                if currentPage < 6 {
                    HStack(spacing: 20) {
                        if currentPage > 0 {
                            Button(action: {
                                withAnimation {
                                    currentPage -= 1
                                }
                            }) {
                                Label("Back", systemImage: "chevron.left")
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.white.opacity(0.3))
                                    .cornerRadius(25)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation {
                                currentPage += 1
                            }
                        }) {
                            Label("Next", systemImage: "chevron.right")
                                .labelStyle(.trailingIcon)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(25)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Onboarding Page
struct OnboardingPage: View {
    let icon: String
    let iconGradient: [Color]
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: icon)
                .font(.system(size: 100))
                .foregroundStyle(
                    LinearGradient(
                        colors: iconGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: iconGradient[0].opacity(0.4), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding()
    }
}

// MARK: - Final Onboarding Page
struct OnboardingFinalPage: View {
    @AppStorage("startingFee") private var startingFee: Double = 0.0
    @AppStorage("pricePerCubicFoot") private var pricePerCubicFoot: Double = 10.0
    @AppStorage("companyName") private var companyName: String = ""
    @AppStorage("useMetric") private var useMetric: Bool = false
    
    @FocusState private var focusedField: FinalPageField?
    @State private var scrollProxy: ScrollViewProxy? = nil
    
    let onComplete: () -> Void
    
    enum FinalPageField: Hashable {
        case companyName, startingFee, pricePerCubicFoot
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 30) {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(.green)
                                
                                Text("Quick Setup")
                                    .font(.title)
                                    .fontWeight(.bold)
                                
                                Text("Set your preferences (you can change these anytime in Settings)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                            .padding(.top, 40)
                            .id("header")
                            
                            // Measurement Units Selector
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Measurement Units")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 32)
                                
                                HStack(spacing: 0) {
                                    Button(action: { useMetric = false }) {
                                        HStack {
                                            Image(systemName: useMetric ? "circle" : "checkmark.circle.fill")
                                            Text("Imperial (Feet)")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(useMetric ? Color.clear : Color.blue.opacity(0.15))
                                        .foregroundColor(useMetric ? .secondary : .blue)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    Button(action: { useMetric = true }) {
                                        HStack {
                                            Image(systemName: useMetric ? "checkmark.circle.fill" : "circle")
                                            Text("Metric (Meters)")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(useMetric ? Color.blue.opacity(0.15) : Color.clear)
                                        .foregroundColor(useMetric ? .blue : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .background(Color.primary.opacity(0.05))
                                .cornerRadius(10)
                                .padding(.horizontal, 32)
                            }
                            
                            VStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Company Name (Optional)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    TextField("Your Company Name", text: $companyName)
                                        .textFieldStyle(.roundedBorder)
                                        .focused($focusedField, equals: .companyName)
                                }
                                .id(FinalPageField.companyName)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Starting Fee")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    HStack {
                                        Text("$")
                                        TextField("0.00", value: $startingFee, format: .number)
                                            .keyboardType(.decimalPad)
                                            .textFieldStyle(.roundedBorder)
                                            .focused($focusedField, equals: .startingFee)
                                    }
                                }
                                .id(FinalPageField.startingFee)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Price per Cubic Foot")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    HStack {
                                        Text("$")
                                        TextField("10.00", value: $pricePerCubicFoot, format: .number)
                                            .keyboardType(.decimalPad)
                                            .textFieldStyle(.roundedBorder)
                                            .focused($focusedField, equals: .pricePerCubicFoot)
                                    }
                                }
                                .id(FinalPageField.pricePerCubicFoot)
                            }
                            .padding(.horizontal, 32)
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("These settings can be changed anytime")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.green)
                                    Text("All data stays on your device")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.top, 20)
                            
                            // Extra padding for keyboard
                            Spacer()
                                .frame(height: 200)
                        }
                        .frame(minHeight: geometry.size.height - 100)
                    }
                    .onAppear {
                        scrollProxy = proxy
                    }
                    .onChange(of: focusedField) { _, field in
                        if let field = field {
                            withAnimation {
                                proxy.scrollTo(field, anchor: .center)
                            }
                        }
                    }
                }
                
                // Get Started button - stays at bottom
                if focusedField == nil {
                    VStack {
                        Button(action: onComplete) {
                            Text("Get Started")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)
                        .background(
                            LinearGradient(
                                colors: [Color.clear, Color.green.opacity(0.1), Color.mint.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                HStack {
                    if let field = focusedField {
                        let previous = previousField(for: field)
                        let next = nextField(for: field)

                        if previous == nil && next == nil {
                            Spacer()
                            Button("Done") {
                                focusedField = nil
                            }
                            .fontWeight(.semibold)
                        } else if previous == nil && next != nil {
                            Button("Done") {
                                focusedField = nil
                            }
                            .fontWeight(.semibold)

                            Spacer()

                            Button("Next") {
                                focusedField = next
                            }
                            .fontWeight(.semibold)
                        } else if previous != nil {
                            Button("Back") {
                                focusedField = previous
                            }
                            .fontWeight(.semibold)

                            Spacer()

                            Button("Done") {
                                focusedField = nil
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
    }

    private func nextField(for field: FinalPageField) -> FinalPageField? {
        switch field {
        case .companyName:
            return .startingFee
        case .startingFee:
            return .pricePerCubicFoot
        case .pricePerCubicFoot:
            return nil
        }
    }

    private func previousField(for field: FinalPageField) -> FinalPageField? {
        switch field {
        case .companyName:
            return nil
        case .startingFee:
            return .companyName
        case .pricePerCubicFoot:
            return .startingFee
        }
    }
}

// MARK: - Trailing Icon Label Style
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon
        }
    }
}

extension LabelStyle where Self == TrailingIconLabelStyle {
    static var trailingIcon: TrailingIconLabelStyle { TrailingIconLabelStyle() }
}

#Preview {
    OnboardingView()
}
