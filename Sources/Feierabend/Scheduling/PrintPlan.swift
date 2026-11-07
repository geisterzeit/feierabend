import Foundation

/// Which end of the print the chosen time pins down.
nonisolated enum ScheduleAnchor: String, CaseIterable, Sendable {
  case start
  case finish
}

nonisolated struct PrintSchedule: Hashable, Sendable {
  var anchor: ScheduleAnchor
  var time: TimeOfDay
}

/// When a print starts and finishes, and how long the printer waits before starting.
nonisolated struct PrintPlan: Hashable, Sendable {
  let start: Date
  let finish: Date?
  let wait: TimeInterval

  /// Returns `nil` when finishing by a time is requested without knowing how long the print takes.
  init?(
    _ schedule: PrintSchedule,
    printDuration: TimeInterval?,
    now: Date,
    calendar: Calendar = .current
  ) {
    switch schedule.anchor {
    case .start:
      let start = schedule.time.nextOccurrence(atOrAfter: now, in: calendar)
      self.start = start
      finish = printDuration.map { start.addingTimeInterval($0) }
    case .finish:
      guard let printDuration else { return nil }
      let earliestFinish = now.addingTimeInterval(printDuration)
      let finish = schedule.time.nextOccurrence(atOrAfter: earliestFinish, in: calendar)
      self.finish = finish
      start = finish.addingTimeInterval(-printDuration)
    }
    wait = max(0, start.timeIntervalSince(now))
  }
}
