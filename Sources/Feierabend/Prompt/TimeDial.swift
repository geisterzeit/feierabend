import SwiftUI

/// A large time of day to type into ("7:30", "730"), or to step with the arrow keys
/// (⇧ for whole hours) and the chevrons, which repeat while held.
struct TimeDial: View {
  @Binding var time: TimeOfDay
  /// Whether the typed text reads as the time it shows, so it may be scheduled.
  @Binding var isReadable: Bool
  let label: String
  let day: String

  @State private var text: String
  @FocusState private var isFocused: Bool
  @State private var isHovered = false

  private static let step = 5

  init(time: Binding<TimeOfDay>, isReadable: Binding<Bool>, label: String, day: String) {
    _time = time
    _isReadable = isReadable
    self.label = label
    self.day = day
    _text = State(initialValue: ClockText.time(time.wrappedValue))
  }

  private var typedTime: TimeOfDay? {
    TimeOfDay(typed: text)
  }

  /// An empty field keeps the last time, which it shows as its placeholder.
  private var isUnreadable: Bool {
    typedTime == nil && !text.trimmingCharacters(in: .whitespaces).isEmpty
  }

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 0) {
        timeField
        Text(isUnreadable ? "Type a time like 7:30" : day)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(isUnreadable ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
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
    .onHover { isHovered = $0 }
    .onTapGesture { isFocused = true }
    .task { isFocused = true }
    .onChange(of: text, initial: true) {
      isReadable = !isUnreadable
      if let typedTime { time = typedTime }
    }
    .onChange(of: time) {
      if typedTime != time { showTime() }
    }
    .onChange(of: isFocused) {
      if !isFocused { showTime() }
    }
    .animation(.easeOut(duration: 0.15), value: isFocused)
    .animation(.easeOut(duration: 0.15), value: isHovered)
  }

  private var timeField: some View {
    TextField(label, text: $text, prompt: Text(ClockText.time(time)))
      .textFieldStyle(.plain)
      .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
      .focused($isFocused)
      // Without a content type, AutoFill flashes an empty suggestions panel on keyboard focus.
      .textContentType(.dateTime)
      .autocorrectionDisabled()
      .onSubmit {
        if !isUnreadable { showTime() }
      }
      .onKeyPress(keys: [.upArrow, .downArrow]) { press in
        let hours = press.modifiers.contains(.shift)
        let size = hours ? 60 : Self.step
        step(byMinutes: press.key == .upArrow ? size : -size)
        return .handled
      }
      .accessibilityValue(day)
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
    time = time.stepped(byMinutes: minutes)
  }

  /// Replaces whatever was typed with the time in the clock's own format, "730" with "07:30".
  private func showTime() {
    text = ClockText.time(time)
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
