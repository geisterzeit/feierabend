/// Collects digits typed one after another into a time of day.
nonisolated struct TimeEntry {
  private var digits = ""

  /// Extends the typed time with `digit`, or starts over when the result wouldn't be a time.
  mutating func type(_ digit: Character) -> TimeOfDay? {
    for candidate in [digits + String(digit), String(digit)] {
      if let time = TimeOfDay(typedDigits: candidate) {
        digits = candidate
        return time
      }
    }
    return nil
  }

  mutating func reset() {
    digits = ""
  }
}
