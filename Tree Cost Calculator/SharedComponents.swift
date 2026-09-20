//
//  SharedComponents.swift
//  Tree Cost Calculator
//
//  Created by Ryan Hamilton on 1/9/26.
//

import SwiftUI
import UIKit

// MARK: - Input Field Component
struct InputField: View {
    let icon: String
    let title: String
    let unit: String
    @Binding var value: String
    let isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .font(.body.weight(.semibold))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            HStack {
                TextField("0.0", text: $value)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 28, weight: .bold))
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.primary.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(isFocused ? Color.accentColor : Color.clear, lineWidth: 2.5)
                            )
                    )
                    .accessibilityLabel("\(title) in \(unit)")
                    .accessibilityValue(value.isEmpty ? "0" : value)
                    .accessibilityHint("Enter numeric value")
                
                Text(unit)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
                    .fixedSize()
                    .accessibilityHidden(true)
            }
        }
    }
}

// MARK: - Result Card Component
struct ResultCard: View {
    let icon: String
    let title: String
    let value: Double
    let format: String
    let unit: String
    let color: Color
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .font(.title2)
                    .fontWeight(.bold)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: format, value))
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundColor(color)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .fixedSize()
                }
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(color.opacity(colorScheme == .dark ? 0.2 : 0.08))
                .shadow(color: color.opacity(colorScheme == .dark ? 0.3 : 0.15), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    LinearGradient(
                        colors: [color.opacity(0.3), color.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(String(format: format, value)) \(unit)")
    }
}

// MARK: - Select All Text Field
struct SelectAllTextField: UIViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var font: UIFont

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.font = font
        field.borderStyle = .none
        field.delegate = context.coordinator
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged), for: .editingChanged)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        @objc func textChanged(_ sender: UITextField) {
            text = sender.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
        }
    }
}
