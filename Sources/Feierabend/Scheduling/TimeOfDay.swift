import Foundation

/// A wall-clock time without a date, such as "07:30".
nonisolated struct TimeOfDay: Hashable, Sendable {
  let hour: Int
  let minute: Int

  init(hour: Int, minute: Int) {
    self.hour = hour
    self.minute = minute
  }

  init(of date: Date, in calendar: Calendar = .current) {
    let components = calendar.dateComponents([.hour, .minute], from: date)
    self.init(hour: components.hour ?? 0, minute: components.minute ?? 0)
  }

  /// The first moment showing this time at or after `earliest`.
  func nextOccurrence(atOrAfter earliest: Date, in calendar: Calendar = .current) -> Date {
    let matching = DateComponents(hour: hour, minute: minute, second: 0)
    let justBefore = earliest.addingTimeInterval(-1)
    return calendar.nextDate(after: justBefore, matching: matching, matchingPolicy: .nextTime)
      ?? earliest
  }
}

nonisolated extension TimeOfDay: RawRepresentable {
  var rawValue: Int { hour * 60 + minute }

  init?(rawValue minutesSinceMidnight: Int) {
    guard (0..<24 * 60).contains(minutesSinceMidnight) else { return nil }
    self.init(hour: minutesSinceMidnight / 60, minute: minutesSinceMidnight % 60)
  }
}

nonisolated extension TimeOfDay {
  private static let minutesPerDay = 24 * 60

  /// Moves to the next multiple of `step` minutes, backwards for a negative step,
  /// wrapping around midnight. Stepping by 5 from 07:32 gives 07:35.
  func stepped(byMinutes step: Int) -> TimeOfDay {
    let size = abs(step)
    let minutes = rawValue
    let target =
      step > 0
      ? (minutes / size + 1) * size
      : (minutes % size == 0 ? minutes - size : minutes - minutes % size)
    let wrapped = (target % Self.minutesPerDay + Self.minutesPerDay) % Self.minutesPerDay
    return TimeOfDay(rawValue: wrapped)!
  }

  /// Reads digits typed in a row: "7" is 07:00, "73" and "730" are 07:30, "0730" is 07:30.
  init?(typedDigits digits: String) {
    guard (1...4).contains(digits.count), digits.allSatisfy({ $0.isASCII && $0.isNumber }),
      let value = Int(digits)
    else { return nil }
    let candidates: [(hour: Int, minute: Int)] =
      switch digits.count {
      case 1: [(value, 0)]
      case 2: [(value, 0), (value / 10, value % 10 * 10)]
      case 3: [(value / 100, value % 100), (value / 10, value % 10 * 10)]
      default: [(value / 100, value % 100)]
      }
    guard let time = candidates.first(where: { $0.hour < 24 && $0.minute < 60 }) else {
      return nil
    }
    self.init(hour: time.hour, minute: time.minute)
  }
}
