//
//  Tree_Cost_CalculatorApp.swift
//  Tree Cost Calculator
//
//  Created by Ryan Hamilton on 1/9/26.
//

import SwiftUI

@main
struct Tree_Cost_CalculatorApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var quotesManager = QuotesManager()
    @StateObject private var historyManager = CalculationHistory()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    QuotesListView(quotesManager: quotesManager)
                        .environmentObject(historyManager)
                } else {
                    OnboardingView()
                        .environmentObject(historyManager)
                }
            }
            .id(hasCompletedOnboarding)
        }
    }
}
