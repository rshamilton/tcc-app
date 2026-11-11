//
//  SignatureView.swift
//  Tree Cost Calculator
//

import SwiftUI
import UIKit

/// Full-screen pad where the customer signs to accept the estimate.
struct SignatureCaptureSheet: View {
    let customerName: String
    let onSave: (_ imagePNG: Data, _ printedName: String) -> Void

    @Environment(\.dismiss) private var dismiss
    /// Strokes in 0...1 coordinates of the pad, so the picture is the same at any screen size or rotation.
    @State private var strokes: [[CGPoint]] = []
    @State private var printedName: String

    init(customerName: String, onSave: @escaping (_ imagePNG: Data, _ printedName: String) -> Void) {
        self.customerName = customerName
        self.onSave = onSave
        _printedName = State(initialValue: customerName)
    }

    /// Shape of the saved picture, in points (rendered at 2x).
    private static let designSize = CGSize(width: 600, height: 200)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("By signing, you accept this estimate.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    pad

                    HStack {
                        Spacer()
                        Button("Clear") { strokes = [] }
                            .disabled(strokes.isEmpty)
                            .accessibilityHint("Erases the signature so you can start over")
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Printed name")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        TextField("Printed name", text: $printedName)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .padding(12)
                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(20)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Customer Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(strokes.isEmpty)
                }
            }
        }
        .interactiveDismissDisabled(!strokes.isEmpty)
    }

    // MARK: Pad

    private var pad: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .bottomLeading) {
                Color.white
                // Baseline and hint stay out of the saved picture.
                VStack(spacing: 4) {
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                        Text("Sign here")
                    }
                    .font(.footnote)
                    .foregroundStyle(Color.black.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Rectangle()
                        .fill(Color.black.opacity(0.35))
                        .frame(height: 1)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, size.height * 0.2)
                .allowsHitTesting(false)

                Canvas { context, canvasSize in
                    for stroke in strokes {
                        let path = Self.path(for: stroke, in: canvasSize)
                        context.stroke(path, with: .color(.black),
                                       style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }
                }
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let point = CGPoint(x: min(max(value.location.x / max(size.width, 1), 0), 1),
                                            y: min(max(value.location.y / max(size.height, 1), 0), 1))
                        if value.translation == .zero || strokes.isEmpty || isFinished {
                            isFinished = false
                            strokes.append([point])
                        } else {
                            strokes[strokes.count - 1].append(point)
                        }
                    }
                    .onEnded { _ in isFinished = true }
            )
        }
        .aspectRatio(Self.designSize.width / Self.designSize.height, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1))
        .accessibilityElement()
        .accessibilityLabel("Signature pad")
        .accessibilityHint("Draw your signature with your finger")
    }

    /// True after a stroke ends, so the next touch starts a new line.
    @State private var isFinished = true

    private static func path(for stroke: [CGPoint], in size: CGSize) -> Path {
        var path = Path()
        guard let first = stroke.first else { return path }
        let start = CGPoint(x: first.x * size.width, y: first.y * size.height)
        path.move(to: start)
        if stroke.count == 1 {
            // A tap becomes a dot (round caps need a segment to draw).
            path.addLine(to: CGPoint(x: start.x + 0.01, y: start.y))
        } else {
            for point in stroke.dropFirst() {
                path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
            }
        }
        return path
    }

    // MARK: Save

    private func save() {
        guard let png = render() else { return }
        onSave(png, printedName.trimmed)
        dismiss()
    }

    /// Black ink on white (the picture is stored like a photo, which has no transparency).
    private func render() -> Data? {
        let size = Self.designSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.black.setStroke()
            for stroke in strokes {
                let path = UIBezierPath()
                path.lineWidth = 3
                path.lineCapStyle = .round
                path.lineJoinStyle = .round
                guard let first = stroke.first else { continue }
                let start = CGPoint(x: first.x * size.width, y: first.y * size.height)
                path.move(to: start)
                if stroke.count == 1 {
                    path.addLine(to: CGPoint(x: start.x + 0.01, y: start.y))
                } else {
                    for point in stroke.dropFirst() {
                        path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
                    }
                }
                path.stroke()
            }
        }
        return image.pngData()
    }
}
