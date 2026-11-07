import Foundation

nonisolated enum ClockText {
  static func dayAndTime(
    _ date: Date,
    relativeTo now: Date,
    in calendar: Calendar = .current
  ) -> String {
    "\(day(of: date, relativeTo: now, in: calendar)), \(date.formatted(date: .omitted, time: .shortened))"
  }

  static func day(of date: Date, relativeTo now: Date, in calendar: Calendar = .current) -> String {
    if calendar.isDate(date, inSameDayAs: now) {
      return "Today"
    }
    if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
      calendar.isDate(date, inSameDayAs: tomorrow)
    {
      return "Tomorrow"
    }
    return date.formatted(.dateTime.weekday(.wide))
  }

  static func time(_ time: TimeOfDay, in calendar: Calendar = .current) -> String {
    time.nextOccurrence(atOrAfter: calendar.startOfDay(for: .now), in: calendar)
      .formatted(date: .omitted, time: .shortened)
  }

  static func duration(_ interval: TimeInterval) -> String {
    Duration.seconds(interval.rounded())
      .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
  }
}
