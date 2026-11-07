import Foundation

/// The G-code that keeps the printer idle until the planned start.
///
/// Bambu firmware limits a single `G4` dwell to roughly 90 seconds, so the wait is split
/// into one-minute dwells. Before each dwell an `M73` progress update keeps the remaining
/// time shown by the printer and Bambu Handy accurate, including the wait.
///
/// Bambu firmware sets the start G-code's first nozzle and bed temperatures while it prepares
/// the job, before the wait runs. So every dwell first switches both heaters off; the start
/// G-code heats them again once the wait is over.
nonisolated struct WaitBlock: Sendable {
  static let startMarker = "; FEIERABEND_WAIT_START"
  static let endMarker = "; FEIERABEND_WAIT_END"
  static let longestDwell = 60
  static let heatersOff = ["M104 S0", "M140 S0"]

  let wait: Int
  let printDuration: TimeInterval?
  let plannedStart: Date

  var gcode: String {
    var lines = [
      Self.startMarker,
      "; Feierabend: wait \(wait) s, planned start \(Date.ISO8601FormatStyle(timeZone: .current).format(plannedStart))",
    ]
    var remainingWait = wait
    while remainingWait > 0 {
      if let progressUpdate = progressUpdate(remainingWait: remainingWait) {
        lines.append(progressUpdate)
      }
      lines.append(contentsOf: Self.heatersOff)
      let dwell = min(remainingWait, Self.longestDwell)
      lines.append("G4 S\(dwell)")
      remainingWait -= dwell
    }
    lines.append(Self.endMarker)
    return lines.joined(separator: "\n") + "\n"
  }

  private func progressUpdate(remainingWait: Int) -> String? {
    guard let printDuration else { return nil }
    let remainingMinutes = Int((TimeInterval(remainingWait) + printDuration) / 60)
    return "M73 P0 R\(remainingMinutes)"
  }
}

nonisolated extension WaitBlock {
  init(plan: PrintPlan, printDuration: TimeInterval?) {
    self.init(
      wait: Int(plan.wait.rounded()), printDuration: printDuration, plannedStart: plan.start)
  }
}
