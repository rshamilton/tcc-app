//
//  QuotesListView.swift
//  Tree Cost Calculator
//
//  Created by Ryan Hamilton on 1/9/26.
//

import SwiftUI

struct QuotesListView: View {
    @ObservedObject var quotesManager: QuotesManager
    @State private var showingNewQuote = false
    @State private var showingSettings = false
    @State private var selectedQuote: Quote?
    @State private var pendingDeleteOffsets: IndexSet?
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if quotesManager.quotes.isEmpty {
                    // Empty State
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 70))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("No Quotes Yet")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Tap the + button to create your first quote")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    // Quotes List
                    List {
                        ForEach(quotesManager.quotes) { quote in
                            Button(action: {
                                selectedQuote = quote
                            }) {
                                QuoteRow(quote: quote)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Quote: \(quote.name)")
                            .accessibilityValue("\(quote.customerName.isEmpty ? "No customer" : quote.customerName), total $\(quote.totalCost, specifier: "%.2f")")
                            .accessibilityHint("Double tap to edit this quote")
                        }
                        .onDelete { offsets in
                            pendingDeleteOffsets = offsets
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle("Quotes")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Configure app settings and pricing")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingNewQuote = true }) {
                        Label("New Quote", systemImage: "plus.circle.fill")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .accessibilityLabel("Create new quote")
                    .accessibilityHint("Opens the quote editor to create a new tree removal estimate")
                }
            }
            .sheet(isPresented: $showingNewQuote) {
                QuoteEditorView(quotesManager: quotesManager, quote: nil)
            }
            .sheet(item: $selectedQuote) { quote in
                QuoteEditorView(quotesManager: quotesManager, quote: quote)
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .confirmationDialog("Delete Quote?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let offsets = pendingDeleteOffsets {
                        quotesManager.deleteQuote(at: offsets)
                        pendingDeleteOffsets = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteOffsets = nil
                }
            } message: {
                Text("This cannot be undone.")
            }
        }
    }
}

// MARK: - Quote Row
struct QuoteRow: View {
    let quote: Quote
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(quote.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if !quote.customerName.isEmpty {
                        Text(quote.customerName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(quote.totalCost, specifier: "%.2f")")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text(quote.formattedLastModified)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Label("\(quote.trees.count + (quote.currentTreeCircumference > 0 && quote.currentTreeHeight > 0 ? 1 : 0)) trees", systemImage: "leaf.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                if quote.totalCubicFeet > 0 {
                    Text("•")
                        .foregroundColor(.secondary)
                    Label("\(quote.totalCubicFeet, specifier: "%.1f") cu ft", systemImage: "shippingbox.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                if !quote.location.isEmpty {
                    Text("•")
                        .foregroundColor(.secondary)
                    Label(quote.location, systemImage: "location.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    QuotesListView(quotesManager: QuotesManager())
}
