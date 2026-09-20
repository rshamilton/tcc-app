//
//  Models.swift
//  Tree Cost Calculator
//
//  Created by Ryan Hamilton on 1/9/26.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Tree Calculation Model
struct TreeCalculation: Identifiable, Codable {
    var id = UUID()
    var date: Date = Date()
    var circumference: Double
    var height: Double
    var cubicFeet: Double
    var subtotal: Double
    var discountAmount: Double
    var taxAmount: Double
    var totalCost: Double
    var jobNotes: String
    var customerName: String
    var location: String
    var photoDataList: [Data]

    enum CodingKeys: String, CodingKey {
        case id, date, circumference, height, cubicFeet, subtotal, discountAmount, taxAmount, totalCost
        case jobNotes, customerName, location
        case photoDataList
        case photoData
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        circumference: Double,
        height: Double,
        cubicFeet: Double,
        subtotal: Double,
        discountAmount: Double,
        taxAmount: Double,
        totalCost: Double,
        jobNotes: String,
        customerName: String,
        location: String,
        photoDataList: [Data]
    ) {
        self.id = id
        self.date = date
        self.circumference = circumference
        self.height = height
        self.cubicFeet = cubicFeet
        self.subtotal = subtotal
        self.discountAmount = discountAmount
        self.taxAmount = taxAmount
        self.totalCost = totalCost
        self.jobNotes = jobNotes
        self.customerName = customerName
        self.location = location
        self.photoDataList = photoDataList
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        circumference = try container.decode(Double.self, forKey: .circumference)
        height = try container.decode(Double.self, forKey: .height)
        cubicFeet = try container.decode(Double.self, forKey: .cubicFeet)
        subtotal = try container.decode(Double.self, forKey: .subtotal)
        discountAmount = try container.decode(Double.self, forKey: .discountAmount)
        taxAmount = try container.decode(Double.self, forKey: .taxAmount)
        totalCost = try container.decode(Double.self, forKey: .totalCost)
        jobNotes = try container.decode(String.self, forKey: .jobNotes)
        customerName = try container.decode(String.self, forKey: .customerName)
        location = try container.decode(String.self, forKey: .location)
        if let list = try? container.decode([Data].self, forKey: .photoDataList) {
            photoDataList = list
        } else if let single = try? container.decode(Data.self, forKey: .photoData) {
            photoDataList = [single]
        } else {
            photoDataList = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(circumference, forKey: .circumference)
        try container.encode(height, forKey: .height)
        try container.encode(cubicFeet, forKey: .cubicFeet)
        try container.encode(subtotal, forKey: .subtotal)
        try container.encode(discountAmount, forKey: .discountAmount)
        try container.encode(taxAmount, forKey: .taxAmount)
        try container.encode(totalCost, forKey: .totalCost)
        try container.encode(jobNotes, forKey: .jobNotes)
        try container.encode(customerName, forKey: .customerName)
        try container.encode(location, forKey: .location)
        try container.encode(photoDataList, forKey: .photoDataList)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Tree Item (for multiple trees)
struct TreeItem: Identifiable, Codable {
    var id = UUID()
    var circumference: Double
    var height: Double
    var notes: String
    var photoDataList: [Data] = []
    
    func cubicFeet() -> Double {
        guard circumference > 0, height > 0 else { return 0 }
        return (circumference * circumference * height) / 12.56
    }

    enum CodingKeys: String, CodingKey {
        case id, circumference, height, notes, photoDataList
    }

    init(id: UUID = UUID(), circumference: Double, height: Double, notes: String, photoDataList: [Data] = []) {
        self.id = id
        self.circumference = circumference
        self.height = height
        self.notes = notes
        self.photoDataList = photoDataList
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        circumference = try container.decode(Double.self, forKey: .circumference)
        height = try container.decode(Double.self, forKey: .height)
        notes = try container.decode(String.self, forKey: .notes)
        photoDataList = (try? container.decode([Data].self, forKey: .photoDataList)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(circumference, forKey: .circumference)
        try container.encode(height, forKey: .height)
        try container.encode(notes, forKey: .notes)
        try container.encode(photoDataList, forKey: .photoDataList)
    }
}

// MARK: - Preset Model
struct TreePreset: Identifiable, Codable {
    var id = UUID()
    var name: String
    var circumference: Double
    var height: Double
}

// MARK: - Calculation History Manager
class CalculationHistory: ObservableObject {
    @Published var calculations: [TreeCalculation] = []
    
    private let saveKey = "SavedCalculations"
    
    init() {
        loadCalculations()
    }
    
    func addCalculation(_ calculation: TreeCalculation) {
        calculations.insert(calculation, at: 0)
        saveCalculations()
    }
    
    func deleteCalculation(at offsets: IndexSet) {
        calculations.remove(atOffsets: offsets)
        saveCalculations()
    }
    
    func deleteCalculation(_ calculation: TreeCalculation) {
        calculations.removeAll { $0.id == calculation.id }
        saveCalculations()
    }

    func updateCalculation(_ calculation: TreeCalculation) {
        if let index = calculations.firstIndex(where: { $0.id == calculation.id }) {
            calculations[index] = calculation
            saveCalculations()
        } else {
            addCalculation(calculation)
        }
    }
    
    private func saveCalculations() {
        if let encoded = try? JSONEncoder().encode(calculations) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadCalculations() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([TreeCalculation].self, from: data) {
            calculations = decoded
        }
    }
}

// MARK: - Presets Manager
class PresetsManager: ObservableObject {
    @Published var presets: [TreePreset] = []
    
    private let saveKey = "SavedPresets"
    
    init() {
        loadPresets()
        
        // Add default presets if none exist
        if presets.isEmpty {
            presets = [
                TreePreset(name: "Small Tree", circumference: 3.0, height: 20.0),
                TreePreset(name: "Medium Tree", circumference: 5.0, height: 35.0),
                TreePreset(name: "Large Tree", circumference: 8.0, height: 50.0)
            ]
            savePresets()
        }
    }
    
    func addPreset(_ preset: TreePreset) {
        presets.append(preset)
        savePresets()
    }
    
    func deletePreset(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
        savePresets()
    }
    
    func updatePreset(_ preset: TreePreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            savePresets()
        }
    }
    
    private func savePresets() {
        if let encoded = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([TreePreset].self, from: data) {
            presets = decoded
        }
    }
}
