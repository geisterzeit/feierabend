import Testing

@testable import Feierabend

struct TimeEntryTests {
  @Test(arguments: [
    ("7", TimeOfDay(hour: 7, minute: 0)),
    ("73", TimeOfDay(hour: 7, minute: 30)),
    ("730", TimeOfDay(hour: 7, minute: 30)),
    ("0730", TimeOfDay(hour: 7, minute: 30)),
    ("23", TimeOfDay(hour: 23, minute: 0)),
    ("1230", TimeOfDay(hour: 12, minute: 30)),
  ])
  func `reads typed digits as a time`(digits: String, time: TimeOfDay) {
    #expect(TimeOfDay(typedDigits: digits) == time)
  }

  @Test(arguments: ["", "2460", "12345", "x"])
  func `rejects digits that are no time`(digits: String) {
    #expect(TimeOfDay(typedDigits: digits) == nil)
  }

  @Test func `typing digits in a row builds the time`() {
    var entry = TimeEntry()

    let times = "0730".map { entry.type($0) }

    #expect(times.last == TimeOfDay(hour: 7, minute: 30))
  }

  @Test func `typing past a full time starts over`() {
    var entry = TimeEntry()
    _ = "2359".map { entry.type($0) }

    #expect(entry.type("6") == TimeOfDay(hour: 6, minute: 0))
  }

  @Test func `steps snap to the step size and wrap around midnight`() {
    #expect(TimeOfDay(hour: 7, minute: 32).stepped(byMinutes: 5) == TimeOfDay(hour: 7, minute: 35))
    #expect(TimeOfDay(hour: 7, minute: 32).stepped(byMinutes: -5) == TimeOfDay(hour: 7, minute: 30))
    #expect(TimeOfDay(hour: 7, minute: 30).stepped(byMinutes: -5) == TimeOfDay(hour: 7, minute: 25))
    #expect(TimeOfDay(hour: 23, minute: 55).stepped(byMinutes: 5) == TimeOfDay(hour: 0, minute: 0))
    #expect(TimeOfDay(hour: 0, minute: 0).stepped(byMinutes: -60) == TimeOfDay(hour: 23, minute: 0))
  }
}
