//
//  EstimatePreviewSheet.swift
//  Tree Cost Calculator
//

import SwiftUI
import PDFKit

/// Shows the finished PDF and lets the user share, print or save it.
struct EstimatePreviewSheet: View {
    let estimate: Estimate

    @Environment(\.dismiss) private var dismiss
    @State private var pdfURL: URL?
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Group {
                if let pdfURL {
                    PDFKitView(url: pdfURL)
                        .ignoresSafeArea(edges: .bottom)
                } else if failed {
                    ContentUnavailableView("Couldn't Create the PDF", systemImage: "exclamationmark.triangle",
                                           description: Text("Please close this screen and try again."))
                } else {
                    ProgressView("Preparing estimate…")
                }
            }
            .navigationTitle(estimate.numberLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if let pdfURL {
                        ShareLink(item: pdfURL,
                                  subject: Text("Tree removal estimate \(estimate.numberLabel)"),
                                  message: Text("Here is your tree removal estimate."),
                                  preview: SharePreview(pdfURL.lastPathComponent, image: Image(systemName: "doc.richtext")))
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .task { await build() }
    }

    private func build() async {
        // Let the sheet finish presenting before doing the heavy work.
        try? await Task.sleep(for: .milliseconds(250))
        let data = EstimatePDF(estimate: estimate, business: .current(), logo: PhotoStore.loadLogo()).render()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: url, options: .atomic)
            pdfURL = url
        } catch {
            failed = true
        }
    }

    private var fileName: String {
        let name = estimate.customerName.trimmed
        let safe = name.components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "")
            .replacingOccurrences(of: " ", with: "-")
        return ["Estimate", estimate.numberLabel, safe.isEmpty ? nil : safe].compactMap { $0 }.joined(separator: "-") + ".pdf"
    }
}

extension View {
    /// On iPad, sheets are small by default; a PDF deserves the full page-style sheet (iOS 18+).
    @ViewBuilder
    func pageSizedSheet() -> some View {
        if #available(iOS 18.0, *) {
            self.presentationSizing(.page)
        } else {
            self
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .secondarySystemBackground
        view.pageShadowsEnabled = true
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}
