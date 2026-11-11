//
//  TreeMath.swift
//  Tree Cost Calculator
//

import Foundation

/// Pure field-calculator maths for the Tree Tools screen. Everything here is an estimate:
/// real trees are not perfect cylinders, cones or cords.
nonisolated enum TreeMath {

    // MARK: Unit helpers

    static let feetPerMeter = 3.280839895
    static let inchesPerCentimeter = 1 / 2.54
    static let poundsPerKilogram = 2.20462262

    static func feet(fromMeters m: Double) -> Double { m * feetPerMeter }
    static func meters(fromFeet ft: Double) -> Double { ft / feetPerMeter }
    static func inches(fromCentimeters cm: Double) -> Double { cm / 2.54 }
    static func centimeters(fromInches inch: Double) -> Double { inch * 2.54 }
    static func kilograms(fromPounds lb: Double) -> Double { lb * 0.45359237 }

    // MARK: Diameter

    /// Diameter = circumference / π. Works in any unit as long as it stays the same.
    static func diameter(fromCircumference c: Double) -> Double {
        c > 0 ? c / .pi : 0
    }

    /// Circumference = diameter × π.
    static func circumference(fromDiameter d: Double) -> Double {
        d > 0 ? d * .pi : 0
    }

    // MARK: Height (tangent method)

    /// Tree height from a standing distance and sight angles (degrees above level are positive).
    ///
    /// - With a base angle (negative when you look down at the base):
    ///   `height = distance × (tan(top) − tan(base))`, so a downward base angle adds to the height.
    /// - Without one, the base is assumed to be at eye level below you:
    ///   `height = distance × tan(top) + eyeHeight`.
    ///
    /// `distance` and `eyeHeight` share one unit and so does the result. Angles are clamped to ±89°.
    static func height(distance: Double, topAngleDegrees: Double, baseAngleDegrees: Double?, eyeHeight: Double) -> Double {
        guard distance > 0 else { return 0 }
        let top = tan(clampAngle(topAngleDegrees) * .pi / 180)
        if let base = baseAngleDegrees {
            let bottom = tan(clampAngle(base) * .pi / 180)
            return max(0, distance * (top - bottom))
        }
        return max(0, distance * top + max(0, eyeHeight))
    }

    private static func clampAngle(_ degrees: Double) -> Double { min(89, max(-89, degrees)) }

    // MARK: Stump grinding

    /// Price = max(diameter × price per unit, minimum), rounded to cents.
    static func stumpGrindingPrice(diameter: Double, pricePerUnit: Double, minimum: Double) -> Double {
        let raw = max(0, diameter) * max(0, pricePerUnit)
        return (max(raw, max(0, minimum)) * 100).rounded() / 100
    }

    // MARK: Firewood

    static let cubicFeetPerCord = 128.0

    /// Cords = (length × width × height in feet) / 128. A full cord is a 4 × 4 × 8 ft stack.
    static func cords(length: Double, width: Double, height: Double) -> Double {
        guard length > 0, width > 0, height > 0 else { return 0 }
        return length * width * height / cubicFeetPerCord
    }

    /// Fraction of a full cord in a face-cord stack: `length × height × (pieceLength / 12) / 128`.
    /// Length and height are in feet, `pieceLength` is the log length in inches (default 16).
    /// A standard 4 × 8 ft face of 16 in pieces is 16/48 = one third of a cord.
    static func faceCords(length: Double, height: Double, pieceLength: Double = 16) -> Double {
        guard length > 0, height > 0, pieceLength > 0 else { return 0 }
        return length * height * (pieceLength / 12) / cubicFeetPerCord
    }

    /// Stacked volume in cubic metres (steres) = length × width × height, all in metres.
    static func steres(length: Double, width: Double, height: Double) -> Double {
        guard length > 0, width > 0, height > 0 else { return 0 }
        return length * width * height
    }

    /// One cord is about 3.62 m³ of stacked wood.
    static func cords(fromSteres s: Double) -> Double { s / 3.624556 }

    // MARK: Board feet

    /// Doyle log rule: `BF = ((D − 4)² / 16) × L`, D = small-end diameter (in), L = length (ft).
    /// Zero when D ≤ 4. Doyle under-reads small logs.
    static func doyleBoardFeet(smallEndDiameterInches d: Double, lengthFeet l: Double) -> Double {
        guard d > 4, l > 0 else { return 0 }
        return (d - 4) * (d - 4) / 16 * l
    }

    /// International ¼-inch rule. Each 4 ft section has `BF = 0.904762 × (0.22 d² − 0.71 d)`
    /// where d is the section's small-end diameter; the diameter grows 0.5 in per 4 ft section (taper).
    /// A leftover partial section adds the same fraction of the next section's board feet.
    static func international14BoardFeet(diameterInches d: Double, lengthFeet l: Double) -> Double {
        guard d > 0, l > 0 else { return 0 }
        func section(_ index: Int) -> Double {
            let dd = d + 0.5 * Double(index)
            return max(0, 0.904762 * (0.22 * dd * dd - 0.71 * dd))
        }
        let full = Int(l / 4)
        var total = 0.0
        for i in 0..<full { total += section(i) }
        let remainder = l - Double(full) * 4
        if remainder > 0.0001 { total += section(full) * (remainder / 4) }
        return max(0, total)
    }

    // MARK: Green wood weight

    /// Approximate green (freshly cut) weight of a species. Real logs vary a lot with moisture and site.
    struct WoodSpecies: Identifiable, Hashable {
        let name: String
        let greenLbPerCuFt: Double
        var id: String { name }
    }

    static let species: [WoodSpecies] = [
        .init(name: "Red oak", greenLbPerCuFt: 63),
        .init(name: "White oak", greenLbPerCuFt: 62),
        .init(name: "Hickory", greenLbPerCuFt: 64),
        .init(name: "Sugar maple", greenLbPerCuFt: 56),
        .init(name: "Red maple", greenLbPerCuFt: 50),
        .init(name: "Silver maple", greenLbPerCuFt: 45),
        .init(name: "Ash", greenLbPerCuFt: 49),
        .init(name: "American elm", greenLbPerCuFt: 54),
        .init(name: "Black walnut", greenLbPerCuFt: 58),
        .init(name: "Black cherry", greenLbPerCuFt: 45),
        .init(name: "Sycamore", greenLbPerCuFt: 52),
        .init(name: "Sweetgum", greenLbPerCuFt: 55),
        .init(name: "Tulip poplar", greenLbPerCuFt: 38),
        .init(name: "Cottonwood", greenLbPerCuFt: 49),
        .init(name: "Willow", greenLbPerCuFt: 45),
        .init(name: "Birch", greenLbPerCuFt: 50),
        .init(name: "Eastern white pine", greenLbPerCuFt: 36),
        .init(name: "Loblolly pine", greenLbPerCuFt: 53),
        .init(name: "Douglas-fir", greenLbPerCuFt: 38),
        .init(name: "Eastern red cedar", greenLbPerCuFt: 37),
        .init(name: "Hemlock", greenLbPerCuFt: 50),
        .init(name: "Spruce", greenLbPerCuFt: 33),
        .init(name: "Other hardwood", greenLbPerCuFt: 60),
        .init(name: "Other softwood", greenLbPerCuFt: 40)
    ]

    static func species(named name: String) -> WoodSpecies {
        species.first { $0.name == name } ?? species[0]
    }

    /// Log volume as a cylinder: `π × (D / 2 / 12)² × L` cubic feet (D in inches, L in feet).
    static func logVolumeCubicFeet(diameterInches d: Double, lengthFeet l: Double) -> Double {
        guard d > 0, l > 0 else { return 0 }
        let r = d / 2 / 12
        return .pi * r * r * l
    }

    /// Weight in pounds = cylinder volume × green density. Metric: kg = lb × 0.453592.
    static func logWeightPounds(diameterInches d: Double, lengthFeet l: Double, species: WoodSpecies) -> Double {
        logVolumeCubicFeet(diameterInches: d, lengthFeet: l) * species.greenLbPerCuFt
    }
}
