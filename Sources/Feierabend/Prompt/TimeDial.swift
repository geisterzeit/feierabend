import SwiftUI

/// A large, keyboard-first time of day: type digits ("730"), or step with the arrow keys
/// (⇧ for whole hours) and the chevrons, which repeat while held.
struct TimeDial: View {
  @Binding var time: TimeOfDay
  let label: String
  let day: String

  @FocusState private var isFocused: Bool
  @State private var isHovered = false
  @State private var entry = TimeEntry()
  @State private var entryTimeout: Task<Void, Never>?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private static let step = 5

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 0) {
        Text(ClockText.time(time))
          .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
          .contentTransition(.numericText(value: Double(time.rawValue)))
        Text(day)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)
          .contentTransition(.opacity)
      }
      Spacer(minLength: 0)
      VStack(spacing: 2) {
        stepButton("Later", systemImage: "chevron.up", minutes: Self.step)
        stepButton("Earlier", systemImage: "chevron.down", minutes: -Self.step)
      }
    }
    .padding(.leading, 16)
    .padding(.trailing, 8)
    .padding(.vertical, 8)
    .background(
      .fill.opacity(isFocused || isHovered ? 0.9 : 0.5), in: .rect(cornerRadius: 16)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .strokeBorder(.tint, lineWidth: 2)
        .opacity(isFocused ? 0.85 : 0)
    }
    .contentShape(.rect(cornerRadius: 16))
    .focusable()
    .focused($isFocused)
    .focusEffectDisabled()
    .defaultFocus($isFocused, true)
    .onHover { isHovered = $0 }
    .onTapGesture { isFocused = true }
    .onKeyPress(keys: [.upArrow, .downArrow]) { press in
      let hours = press.modifiers.contains(.shift)
      let size = hours ? 60 : Self.step
      step(byMinutes: press.key == .upArrow ? size : -size)
      return .handled
    }
    .onKeyPress(characters: .decimalDigits) { press in
      guard let digit = press.characters.first, let typed = entry.type(digit) else {
        return .ignored
      }
      time = typed
      restartEntryTimeout()
      return .handled
    }
    .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: time)
    .animation(.easeOut(duration: 0.15), value: isFocused)
    .animation(.easeOut(duration: 0.15), value: isHovered)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue("\(ClockText.time(time)), \(day)")
    .accessibilityAdjustableAction { direction in
      step(byMinutes: direction == .increment ? Self.step : -Self.step)
    }
  }

  private func stepButton(_ title: String, systemImage: String, minutes: Int) -> some View {
    Button(title, systemImage: systemImage) {
      step(byMinutes: minutes)
    }
    .labelStyle(.iconOnly)
    .buttonStyle(StepButtonStyle())
    .buttonRepeatBehavior(.enabled)
    .focusable(false)
  }

  private func step(byMinutes minutes: Int) {
    entry.reset()
    time = time.stepped(byMinutes: minutes)
  }

  /// A pause ends the typed time, so the next digit starts a new one.
  private func restartEntryTimeout() {
    entryTimeout?.cancel()
    entryTimeout = Task {
      try? await Task.sleep(for: .seconds(1.5))
      guard !Task.isCancelled else { return }
      entry.reset()
    }
  }
}

private struct StepButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    StepButton(configuration: configuration)
  }

  private struct StepButton: View {
    let configuration: ButtonStyleConfiguration
    @State private var isHovered = false

    var body: some View {
      configuration.label
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(isHovered ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        .frame(width: 30, height: 24)
        .background(.fill.opacity(isHovered ? 1 : 0), in: .rect(cornerRadius: 7))
        .scaleEffect(configuration.isPressed ? 0.86 : 1)
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
  }
}
