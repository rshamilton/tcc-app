//
//  OnboardingView.swift
//  Tree Cost Calculator
//

import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    #if DEBUG
    @State private var page = DebugLaunch.onboardingPage
    #else
    @State private var page = 0
    #endif
    private let lastPage = 3

    var body: some View {
        content
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var content: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < lastPage {
                    Button("Skip") { onFinish() }
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 44)
            .padding(.horizontal, 20)

            TabView(selection: $page) {
                IntroPage(
                    hero: AnyView(BrandTile().frame(width: 150, height: 150).shadow(color: Color.accentColor.opacity(0.35), radius: 20, y: 10)),
                    title: "Estimate tree jobs in minutes",
                    message: "Enter a tree's circumference and height. Tree Cost Calculator works out the volume and the price for you."
                )
                .tag(0)

                IntroPage(
                    hero: AnyView(SymbolHero(symbol: "dollarsign.circle.fill", colors: [.orange, .yellow])),
                    title: "Your prices, your rules",
                    message: "Set your starting fee, rate per cubic foot and tax once. Add a discount or an extra charge to any job."
                )
                .tag(1)

                IntroPage(
                    hero: AnyView(SymbolHero(symbol: "doc.richtext.fill", colors: [.blue, .cyan])),
                    title: "Send a professional PDF",
                    message: "Add the customer, photos and notes, then share a clean estimate with your logo straight from your phone."
                )
                .tag(2)

                SetupPage(onFinish: onFinish)
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            PageDots(count: lastPage + 1, current: page)
                .padding(.bottom, 12)

            if page < lastPage {
                Button {
                    withAnimation { page += 1 }
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .controlSize(.large)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Pages

private struct IntroPage: View {
    let hero: AnyView
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            hero
            VStack(spacing: 12) {
                Text(title)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }
}

private struct SymbolHero: View {
    let symbol: String
    let colors: [Color]

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 76))
            .foregroundStyle(.white)
            .frame(width: 150, height: 150)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 34, style: .continuous)
            )
            .shadow(color: colors[0].opacity(0.4), radius: 20, y: 10)
            .accessibilityHidden(true)
    }
}

private struct SetupPage: View {
    let onFinish: () -> Void

    @AppStorage(SettingsKey.companyName) private var companyName = ""
    @AppStorage(SettingsKey.startingFee) private var startingFee = 0.0
    @AppStorage(SettingsKey.ratePerUnit) private var ratePerUnit = 10.0
    @AppStorage(SettingsKey.taxRate) private var taxRate = 0.0
    @AppStorage(SettingsKey.useMetric) private var useMetric = false
    @FocusState private var nameFocused: Bool

    private var units: UnitSystem { useMetric ? .metric : .imperial }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 8) {
                    Text("Set up your pricing")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text("You can change all of this later in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                VStack(spacing: 0) {
                    setupRow("Company name") {
                        TextField("Optional", text: $companyName)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                            .focused($nameFocused)
                    }
                    Divider().padding(.leading, 16)
                    setupRow("Measurements") {
                        Picker("Measurements", selection: $useMetric) {
                            Text("Feet").tag(false)
                            Text("Meters").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                    Divider().padding(.leading, 16)
                    setupRow("Starting fee") {
                        NumberField(placeholder: "0", value: $startingFee, prefix: Format.currencySymbol)
                    }
                    Divider().padding(.leading, 16)
                    setupRow("Price per \(units.volumeUnit)") {
                        NumberField(placeholder: "0", value: $ratePerUnit, prefix: Format.currencySymbol)
                    }
                    Divider().padding(.leading, 16)
                    setupRow("Tax rate") {
                        NumberField(placeholder: "0", value: $taxRate, suffix: "%")
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(spacing: 10) {
                    Label("Your data is saved on your device and backed up to your own iCloud Drive. We never receive it.", systemImage: "lock.fill")
                    Text("All prices, volumes and tax figures are estimates and examples only, worked out from what you enter. Check everything yourself: the app's maker accepts no responsibility for estimates, jobs, taxes or data.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                Button(action: onFinish) {
                    Text("Start Estimating")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .controlSize(.large)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func setupRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            content()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
    }
}

// MARK: - Page dots

private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.accentColor : Color(.tertiaryLabel))
                    .frame(width: index == current ? 22 : 8, height: 8)
                    .animation(.snappy, value: current)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
