import Foundation

/// Reads the slicer's print time estimate from a G-code header.
nonisolated enum PrintTimeEstimate {
  static func duration(inHeader header: String) -> TimeInterval? {
    // Bambu Studio writes `; total estimated time: 1h 2m 3s`,
    // Orca and PrusaSlicer write `; estimated printing time (normal mode) = 1h 2m 3s`.
    let estimateLine =
      /(?:total estimated time:|estimated printing time \(normal mode\) =)\s*((?:\d+[dhms]\s*)+)/
    guard let estimate = header.firstMatch(of: estimateLine) else { return nil }
    return estimate.1.matches(of: /(\d+)([dhms])/).reduce(0) { total, part in
      total + TimeInterval(part.1)! * secondsPerUnit(part.2)
    }
  }

  private static func secondsPerUnit(_ unit: Substring) -> TimeInterval {
    switch unit {
    case "d": 86_400
    case "h": 3_600
    case "m": 60
    default: 1
    }
  }
}
