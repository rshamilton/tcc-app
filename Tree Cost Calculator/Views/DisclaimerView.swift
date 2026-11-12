//
//  DisclaimerView.swift
//  Tree Cost Calculator
//

import SwiftUI

/// The full disclaimer: what the app is and is not, and where the user's responsibility begins.
/// The same text appears in the Terms of Use on the website and in the README.
struct DisclaimerView: View {
    init() {}

    private struct Clause: Identifiable {
        let id: Int
        let title: String
        let text: String
    }

    private static let clauses: [Clause] = [
        Clause(id: 1, title: "Who is \"the Developer\"",
               text: "In this disclaimer, \"the Developer\" means the app's authors, copyright holders and contributors (including Ryan Hamilton), its App Store seller and publisher (Susan Hamilton), and anyone acting for any of them."),
        Clause(id: 2, title: "Provided as is",
               text: "Tree Cost Calculator is provided \"AS IS\" and \"AS AVAILABLE\", without warranties of any kind, express or implied, including merchantability, fitness for a particular purpose, accuracy, completeness, non-infringement, or uninterrupted or error-free operation."),
        Clause(id: 3, title: "Estimates only",
               text: "Every calculation, volume, diameter, price, tax, total, deposit and balance is an estimate worked out from numbers you enter. It may be wrong or out of date. Example figures are examples only."),
        Clause(id: 4, title: "Not professional advice",
               text: "Nothing in the app is professional, arborist, engineering, safety, legal, tax, accounting, financial or insurance advice."),
        Clause(id: 5, title: "You are responsible",
               text: "You alone are responsible for: checking every figure and document before you use or send it; setting your prices; every quote, contract, invoice and set of terms you send; your agreements with your customers; whether an on-screen signature is legally valid or sufficient where you work; collecting, reporting and paying taxes; licensing, permits and insurance; complying with all laws that apply to you (including consumer protection, contractor, privacy and tax laws); and backing up your own data."),
        Clause(id: 6, title: "Tree work is dangerous",
               text: "Tree work can cause serious injury, death and property damage. The app does not assess a tree or a site and does not tell you how to work safely. Hire qualified, insured professionals for any tree work."),
        Clause(id: 7, title: "Your data and backups",
               text: "Your data is stored on your device and in your own iCloud Drive. The Developer does not receive it, cannot recover it and provides no backup service. You are responsible for any customer information you store, including photos and signatures, and for your own privacy obligations to your customers. Data can be lost or damaged, including through iCloud sync or restore failures, device failures or failures of third-party services."),
        Clause(id: 8, title: "No liability",
               text: "To the fullest extent permitted by law, the Developer is not liable for any loss or damage of any kind arising from the app or its use. That includes direct, indirect, incidental, consequential, special and punitive damages; lost profits, revenue, data or business; property damage; personal injury or death arising from tree work; mispriced jobs; disputes with customers or others; tax penalties; data loss; and device or third-party service failures. This applies even if the Developer was told such loss was possible."),
        Clause(id: 9, title: "Limit",
               text: "The Developer's total aggregate liability is limited to the amount you paid for the app, which is zero. Where the law requires a minimum, it is limited to the lowest amount the law allows."),
        Clause(id: 10, title: "Indemnity",
               text: "You agree to defend and indemnify the Developer against any claim, loss, cost or expense (including reasonable legal fees) arising from your use of the app, your estimates, invoices or work, your customers, or your breach of these terms."),
        Clause(id: 11, title: "Third parties",
               text: "Apple, iCloud, email and share targets, GitHub and any other third-party service you use with the app are governed by their own terms. The Developer is not responsible for them."),
        Clause(id: 12, title: "Source code",
               text: "The \"NO WARRANTY\" and \"LIMITATION OF LIABILITY\" sections (15 and 16) of the GNU General Public License version 3 also apply to the source code."),
        Clause(id: 13, title: "Local law and severability",
               text: "Some places do not allow certain exclusions or limits. Where that is so, the exclusions and limits above apply to the fullest extent permitted. If any part of this disclaimer is unenforceable, the rest still applies."),
        Clause(id: 14, title: "Acceptance and changes",
               text: "By using the app you accept this disclaimer and the Terms of Use. If you do not agree, do not use the app. These terms may change, and continued use means you accept the changes.")
    ]

    var body: some View {
        List {
            Section {
                Text("Please read this carefully. Tree Cost Calculator is a free tool. Everything it calculates is an estimate you must check, and you are solely responsible for your prices, documents, taxes, work and data.")
                    .font(.subheadline)
            }

            ForEach(Self.clauses) { clause in
                Section(clause.title) {
                    Text(clause.text)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section {
                Link(destination: AppLinks.terms) {
                    Label("Read the full Terms of Use", systemImage: "doc.text")
                }
                Link(destination: AppLinks.privacy) {
                    Label("Privacy Policy", systemImage: "hand.raised")
                }
            } footer: {
                Text("© 2026 Ryan Hamilton. Free and open-source software under the GNU GPL v3. This text is provided for convenience and is not legal advice.")
            }
        }
        .navigationTitle("Disclaimer & Terms")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { DisclaimerView() }
}
