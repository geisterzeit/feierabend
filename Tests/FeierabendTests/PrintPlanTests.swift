import Foundation
import Testing

@testable import Feierabend

struct PrintPlanTests {
  let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return calendar
  }()

  func date(day: Int, _ hour: Int, _ minute: Int) -> Date {
    calendar.date(
      from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
  }

  @Test func `a start time later today starts today`() {
    let plan = PrintPlan(
      PrintSchedule(anchor: .start, time: TimeOfDay(hour: 23, minute: 0)),
      printDuration: 2 * 3600,
      now: date(day: 7, 18, 0),
      calendar: calendar
    )

    #expect(plan?.start == date(day: 7, 23, 0))
    #expect(plan?.finish == date(day: 8, 1, 0))
    #expect(plan?.wait == TimeInterval(5 * 3600))
  }

  @Test func `a start time that already passed today starts tomorrow`() {
    let plan = PrintPlan(
      PrintSchedule(anchor: .start, time: TimeOfDay(hour: 6, minute: 0)),
      printDuration: nil,
      now: date(day: 7, 18, 0),
      calendar: calendar
    )

    #expect(plan?.start == date(day: 8, 6, 0))
    #expect(plan?.finish == nil)
  }

  @Test func `finishing by a time starts the print its duration earlier`() {
    let plan = PrintPlan(
      PrintSchedule(anchor: .finish, time: TimeOfDay(hour: 7, minute: 30)),
      printDuration: 5 * 3600 + 15 * 60,
      now: date(day: 7, 18, 0),
      calendar: calendar
    )

    #expect(plan?.finish == date(day: 8, 7, 30))
    #expect(plan?.start == date(day: 8, 2, 15))
    #expect(plan?.wait == TimeInterval(8 * 3600 + 15 * 60))
  }

  @Test func `a finish time too soon for the print moves to the next day`() {
    let plan = PrintPlan(
      PrintSchedule(anchor: .finish, time: TimeOfDay(hour: 19, minute: 0)),
      printDuration: 2 * 3600,
      now: date(day: 7, 18, 0),
      calendar: calendar
    )

    #expect(plan?.finish == date(day: 8, 19, 0))
    #expect(plan?.start == date(day: 8, 17, 0))
  }

  @Test func `finishing by a time needs a print duration`() {
    let plan = PrintPlan(
      PrintSchedule(anchor: .finish, time: TimeOfDay(hour: 7, minute: 0)),
      printDuration: nil,
      now: date(day: 7, 18, 0),
      calendar: calendar
    )

    #expect(plan == nil)
  }

  @Test func `time of day round-trips through its stored value`() {
    let time = TimeOfDay(hour: 7, minute: 30)

    #expect(TimeOfDay(rawValue: time.rawValue) == time)
    #expect(TimeOfDay(rawValue: 24 * 60) == nil)
  }
}
