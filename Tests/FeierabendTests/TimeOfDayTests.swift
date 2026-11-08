import Foundation
import Testing

@testable import Feierabend

struct TimeOfDayTests {
  let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
  }()

  @Test(arguments: [
    ("7", TimeOfDay(hour: 7, minute: 0)),
    ("73", TimeOfDay(hour: 7, minute: 30)),
    ("730", TimeOfDay(hour: 7, minute: 30)),
    ("0730", TimeOfDay(hour: 7, minute: 30)),
    ("23", TimeOfDay(hour: 23, minute: 0)),
    ("1230", TimeOfDay(hour: 12, minute: 30)),
    ("7:30", TimeOfDay(hour: 7, minute: 30)),
    ("07:30", TimeOfDay(hour: 7, minute: 30)),
    ("19.45", TimeOfDay(hour: 19, minute: 45)),
    (" 7:5 ", TimeOfDay(hour: 7, minute: 5)),
    ("7:", TimeOfDay(hour: 7, minute: 0)),
  ])
  func `reads a typed time`(text: String, time: TimeOfDay) {
    #expect(TimeOfDay(typed: text, in: calendar) == time)
  }

  @Test(arguments: [
    ("7:30 PM", TimeOfDay(hour: 19, minute: 30)),
    ("7:30 am", TimeOfDay(hour: 7, minute: 30)),
    ("12:15 AM", TimeOfDay(hour: 0, minute: 15)),
    ("12 pm", TimeOfDay(hour: 12, minute: 0)),
    ("830p", TimeOfDay(hour: 20, minute: 30)),
  ])
  func `reads a time on a 12-hour clock`(text: String, time: TimeOfDay) {
    #expect(TimeOfDay(typed: text, in: calendar) == time)
  }

  @Test(arguments: [
    "", ":", "2460", "12345", "x", "25:00", "7:60", "7:300", "7:75", "13:00 pm", "0 am", "7:30:00",
  ])
  func `rejects text that is no time`(text: String) {
    #expect(TimeOfDay(typed: text, in: calendar) == nil)
  }

  @Test func `steps snap to the step size and wrap around midnight`() {
    #expect(TimeOfDay(hour: 7, minute: 32).stepped(byMinutes: 5) == TimeOfDay(hour: 7, minute: 35))
    #expect(TimeOfDay(hour: 7, minute: 32).stepped(byMinutes: -5) == TimeOfDay(hour: 7, minute: 30))
    #expect(TimeOfDay(hour: 7, minute: 30).stepped(byMinutes: -5) == TimeOfDay(hour: 7, minute: 25))
    #expect(TimeOfDay(hour: 23, minute: 55).stepped(byMinutes: 5) == TimeOfDay(hour: 0, minute: 0))
    #expect(TimeOfDay(hour: 0, minute: 0).stepped(byMinutes: -60) == TimeOfDay(hour: 23, minute: 0))
  }
}
