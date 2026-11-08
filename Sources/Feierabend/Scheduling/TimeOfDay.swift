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

  /// Reads a time typed into a field: "7:30", "19.45", "730", "7", or "7:30 pm".
  init?(typed text: String, in calendar: Calendar = .current) {
    var clock = text.lowercased().trimmingCharacters(in: .whitespaces)
    let meridiem = Meridiem.remove(from: &clock, in: calendar)
    let fields = clock.split(separator: /[:.\s]+/).map(String.init)
    let time = Self.readings(of: fields).lazy
      .compactMap { reading -> TimeOfDay? in
        meridiem.hour(from: reading.hour).map { TimeOfDay(hour: $0, minute: reading.minute) }
      }
      .first { (0..<24).contains($0.hour) && (0..<60).contains($0.minute) }
    guard let time else { return nil }
    self = time
  }

  /// What the typed numbers could mean, likeliest first: "73" is 07:00 if it can't be 73:00.
  private static func readings(of fields: [String]) -> [(hour: Int, minute: Int)] {
    let numbers = fields.compactMap { field in
      field.allSatisfy { $0.isASCII && $0.isNumber } ? Int(field) : nil
    }
    guard numbers.count == fields.count else { return [] }
    switch fields.map(\.count) {
    case [1]: return [(numbers[0], 0)]
    case [2]: return [(numbers[0], 0), (numbers[0] / 10, numbers[0] % 10 * 10)]
    case [3]:
      return [(numbers[0] / 100, numbers[0] % 100), (numbers[0] / 10, numbers[0] % 10 * 10)]
    case [4]: return [(numbers[0] / 100, numbers[0] % 100)]
    case [1, 1], [1, 2], [2, 1], [2, 2]: return [(numbers[0], numbers[1])]
    default: return []
    }
  }
}

/// The "am" or "pm" of a time typed on a 12-hour clock, or neither on a 24-hour one.
private nonisolated enum Meridiem {
  case twentyFourHour
  case am
  case pm

  static func remove(from clock: inout String, in calendar: Calendar) -> Meridiem {
    let symbols: [(String, Meridiem)] = [
      (calendar.pmSymbol.lowercased(), .pm), (calendar.amSymbol.lowercased(), .am),
      ("pm", .pm), ("am", .am), ("p", .pm), ("a", .am),
    ]
    for (symbol, meridiem) in symbols where !symbol.isEmpty {
      if let range = clock.range(of: symbol) {
        clock.removeSubrange(range)
        return meridiem
      }
    }
    return .twentyFourHour
  }

  func hour(from clockHour: Int) -> Int? {
    switch self {
    case .twentyFourHour: clockHour
    case .am: (1...12).contains(clockHour) ? clockHour % 12 : nil
    case .pm: (1...12).contains(clockHour) ? clockHour % 12 + 12 : nil
    }
  }
}
