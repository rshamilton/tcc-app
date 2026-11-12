//
//  AboutView.swift
//  Tree Cost Calculator
//

import SwiftUI

/// What the app is, who made it, and the open-source licence it is shared under.
struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    BrandTile()
                        .frame(width: 96, height: 96)
                        .shadow(color: Color.accentColor.opacity(0.3), radius: 10, y: 5)
                        .accessibilityHidden(true)
                    Text("Tree Cost Calculator")
                        .font(.title3.weight(.bold))
                    Text("Version \(AppLinks.versionString)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Tree Cost Calculator is free and open source. It has no ads, no accounts and no tracking, and your estimates stay on your device and in your own iCloud Drive. Anyone can read, use and improve the code.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
            }

            Section {
                Link(destination: AppLinks.sourceCode) {
                    Label("View Source Code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: AppLinks.license) {
                    Label("License: GNU GPL v3", systemImage: "scroll")
                }
                Link(destination: AppLinks.privacy) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
                Link(destination: AppLinks.terms) {
                    Label("Terms of Use", systemImage: "doc.text")
                }
                NavigationLink {
                    DisclaimerView()
                } label: {
                    Label("Disclaimer & Terms", systemImage: "exclamationmark.shield")
                }
                Link(destination: AppLinks.website) {
                    Label("Website", systemImage: "globe")
                }
            }

            Section {
                Text("This program comes with ABSOLUTELY NO WARRANTY. It is free software, and you are welcome to redistribute it under the terms of the GNU General Public License version 3 or later.")
                Text("Provided \"as is\", without warranty. Everything this app calculates is an estimate that you must check. It is not professional, legal, tax or safety advice. You are solely responsible for your prices, documents, taxes, work and data, and the Developer is not liable for any loss or damage. See the Disclaimer & Terms and the Terms of Use.")
                Text("© 2026 Ryan Hamilton")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { AboutView() }
}
