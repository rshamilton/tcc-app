//
//  EstimatePreviewSheet.swift
//  Tree Cost Calculator
//

import SwiftUI
import PDFKit
import StoreKit
import UniformTypeIdentifiers

/// Shows the finished PDF and lets the user share, print or save it.
struct EstimatePreviewSheet: View {
    let estimate: Estimate
    /// Called on the main actor after the user completes a share, print or save.
    let onShared: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @State private var pdfURL: URL?
    @State private var failed = false
    @State private var showShare = false

    private var isInvoice: Bool { estimate.status.isInvoice }

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
                    ProgressView(isInvoice ? "Preparing invoice…" : "Preparing estimate…")
                }
            }
            .navigationTitle(estimate.documentLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if pdfURL != nil {
                        Button {
                            showShare = true
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .fontWeight(.semibold)
                        .accessibilityLabel(isInvoice ? "Share or print invoice" : "Share or print estimate")
                    }
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let pdfURL {
                ActivityView(items: [PDFShareItem(url: pdfURL, subject: subject)]) { completed in
                    showShare = false
                    if completed { didShare() }
                }
                .ignoresSafeArea()
                .presentationDetents([.medium, .large])
            }
        }
        .task { await build() }
    }

    private var subject: String {
        let kind = isInvoice ? "Invoice" : "Estimate"
        let name = BusinessProfile.current().name
        return name.isEmpty ? "\(kind) \(estimate.documentLabel)" : "\(kind) \(estimate.documentLabel) from \(name)"
    }

    /// Tells the caller, then (only after a few good shares, and only here) lets iOS ask for a rating.
    private func didShare() {
        onShared()
        guard ReviewPrompter.noteSuccessfulShare() else { return }
        Task {
            try? await Task.sleep(for: .seconds(1))
            requestReview()
            ReviewPrompter.didRequest()
        }
    }

    private func build() async {
        // Let the sheet finish presenting before doing the heavy work.
        try? await Task.sleep(for: .milliseconds(250))
        await Task.yield()
        let data = EstimatePDF(estimate: estimate, business: .current(), logo: PhotoStore.loadLogo()).render()
        do {
            // Old PDFs from earlier previews are cleared out so they don't pile up in temporary storage.
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Share", isDirectory: true)
            try? FileManager.default.removeItem(at: folder)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let url = folder.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomic)
            pdfURL = url
        } catch {
            failed = true
        }
    }

    private var fileName: String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>").union(.newlines).union(.controlCharacters)
        // The customer's name identifies the file best; the job name stands in when there is none.
        let base = estimate.customerName.trimmed.isEmpty ? estimate.title.trimmed : estimate.customerName.trimmed
        var safe = base.components(separatedBy: invalid).joined()
            .replacingOccurrences(of: " ", with: "-")
        while safe.hasPrefix(".") { safe.removeFirst() }
        safe = String(safe.prefix(60))
        let kind = isInvoice ? "Invoice" : "Estimate"
        return [kind, estimate.documentLabel, safe.isEmpty ? nil : safe].compactMap { $0 }.joined(separator: "-") + ".pdf"
    }
}

/// Hands the PDF to the share sheet with an email subject line.
final class PDFShareItem: NSObject, UIActivityItemSource {
    let url: URL
    let subject: String

    init(url: URL, subject: String) {
        self.url = url
        self.subject = subject
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any { url }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? { url }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String { subject }

    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String { UTType.pdf.identifier }
}

/// The system share sheet. Presented through a SwiftUI sheet so it also works on iPad without a popover anchor.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    let onFinish: (_ completed: Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            Task { @MainActor in onFinish(completed) }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
