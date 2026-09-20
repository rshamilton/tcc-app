//
//  Quote.swift
//  Tree Cost Calculator
//
//  Created by Ryan Hamilton on 1/9/26.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Charge Type Enum
enum ChargeType: String, Codable {
    case percentage = "percentage"
    case fixed = "fixed"
}

// MARK: - Quote Model
struct Quote: Identifiable, Codable {
    let id: UUID
    var name: String
    var date: Date = Date()
    var lastModified: Date = Date()
    
    // Trees
    var trees: [TreeItem]
    var currentTreeCircumference: Double
    var currentTreeHeight: Double
    
    // Customer info
    var customerName: String
    var location: String
    var jobNotes: String
    
    // Pricing (snapshot at time of creation)
    var startingFee: Double
    var pricePerCubicFoot: Double
    var taxRate: Double
    
    // Flexible discount
    var discountAmount: Double = 0
    var discountType: ChargeType = .percentage
    
    // Flexible additional charge
    var additionalChargeAmount: Double = 0
    var additionalChargeType: ChargeType = .fixed
    var additionalChargeDescription: String = ""
    
    init(id: UUID = UUID(), name: String, trees: [TreeItem], currentTreeCircumference: Double, currentTreeHeight: Double, customerName: String, location: String, jobNotes: String, startingFee: Double, pricePerCubicFoot: Double, taxRate: Double, discountAmount: Double = 0, discountType: ChargeType = .percentage, additionalChargeAmount: Double = 0, additionalChargeType: ChargeType = .fixed, additionalChargeDescription: String = "") {
        self.id = id
        self.name = name
        self.trees = trees
        self.currentTreeCircumference = currentTreeCircumference
        self.currentTreeHeight = currentTreeHeight
        self.customerName = customerName
        self.location = location
        self.jobNotes = jobNotes
        self.startingFee = startingFee
        self.pricePerCubicFoot = pricePerCubicFoot
        self.taxRate = taxRate
        self.discountAmount = discountAmount
        self.discountType = discountType
        self.additionalChargeAmount = additionalChargeAmount
        self.additionalChargeType = additionalChargeType
        self.additionalChargeDescription = additionalChargeDescription
    }
    
    var totalCubicFeet: Double {
        let currentCF = currentTreeCircumference > 0 && currentTreeHeight > 0
            ? (currentTreeCircumference * currentTreeCircumference * currentTreeHeight) / 12.56
            : 0
        return trees.reduce(0) { $0 + $1.cubicFeet() } + currentCF
    }
    
    var volumeCost: Double {
        totalCubicFeet * pricePerCubicFoot
    }
    
    var subtotal: Double {
        let baseSubtotal = startingFee + volumeCost
        
        // Add additional charge
        let additionalCharge: Double
        if additionalChargeType == .percentage {
            additionalCharge = baseSubtotal * (additionalChargeAmount / 100.0)
        } else {
            additionalCharge = additionalChargeAmount
        }
        
        return baseSubtotal + additionalCharge
    }
    
    var calculatedDiscountAmount: Double {
        guard discountAmount > 0 else { return 0 }
        
        if discountType == .percentage {
            return subtotal * (discountAmount / 100.0)
        } else {
            return discountAmount
        }
    }
    
    var afterDiscount: Double {
        subtotal - calculatedDiscountAmount
    }
    
    var taxAmount: Double {
        afterDiscount * (taxRate / 100.0)
    }
    
    var totalCost: Double {
        afterDiscount + taxAmount
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var formattedLastModified: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastModified, relativeTo: Date())
    }
}

// MARK: - Quotes Manager
class QuotesManager: ObservableObject {
    @Published var quotes: [Quote] = []
    
    private let saveKey = "SavedQuotes"
    private var saveTimer: Timer?
    
    init() {
        loadQuotes()
    }
    
    func addQuote(_ quote: Quote) {
        quotes.insert(quote, at: 0)
        saveQuotes()
    }
    
    func updateQuote(_ quote: Quote) {
        if let index = quotes.firstIndex(where: { $0.id == quote.id }) {
            var updatedQuote = quote
            updatedQuote.lastModified = Date()
            quotes[index] = updatedQuote
            // Debounce auto-save
            saveTimer?.invalidate()
            saveTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                self?.saveQuotes()
            }
        }
    }
    
    func deleteQuote(at offsets: IndexSet) {
        quotes.remove(atOffsets: offsets)
        saveQuotes()
    }
    
    func deleteQuote(_ quote: Quote) {
        quotes.removeAll { $0.id == quote.id }
        saveQuotes()
    }
    
    private func saveQuotes() {
        if let encoded = try? JSONEncoder().encode(quotes) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadQuotes() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Quote].self, from: data) {
            quotes = decoded
        }
    }
}
