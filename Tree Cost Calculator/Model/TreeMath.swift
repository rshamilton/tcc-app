//
//  TreeMath.swift
//  Tree Cost Calculator
//

import Foundation

/// Small unit and trunk-size helpers. Everything here is an estimate: real trunks are not perfect circles.
nonisolated enum TreeMath {

    // MARK: Unit helpers

    static let feetPerMeter = 3.280839895

    static func feet(fromMeters m: Double) -> Double { m * feetPerMeter }
    static func meters(fromFeet ft: Double) -> Double { ft / feetPerMeter }
    static func inches(fromCentimeters cm: Double) -> Double { cm / 2.54 }
    static func centimeters(fromInches inch: Double) -> Double { inch * 2.54 }

    // MARK: Diameter

    /// Diameter = circumference / π. Works in any unit as long as it stays the same.
    static func diameter(fromCircumference c: Double) -> Double {
        c > 0 ? c / .pi : 0
    }

    /// Circumference = diameter × π.
    static func circumference(fromDiameter d: Double) -> Double {
        d > 0 ? d * .pi : 0
    }
}
