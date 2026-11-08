import SwiftUI

/// The plan as an itinerary from now to done: a dotted rail while the printer waits,
/// then a solid one while it prints. Every stop names its day, so a plan crossing
/// midnight reads as such.
struct PlanTimeline: View {
  let plan: PrintPlan
  let printDuration: TimeInterval?
  let now: Date

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private static let railWidth: CGFloat = 12
  private static let spacing: CGFloat = 10

  private var waitsBeforeStarting: Bool {
    plan.wait >= 60
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if waitsBeforeStarting {
        stop("Now", at: now, marker: .hollow)
        stretch("waits \(ClockText.duration(plan.wait))", rail: .waiting)
      }
      stop("Starts", at: plan.start, marker: .filled)
      if let finish = plan.finish, let printDuration {
        stretch("prints \(ClockText.duration(printDuration))", rail: .printing)
        stop("Done", at: finish, marker: .filled)
      }
    }
    .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: plan)
    .accessibilityElement(children: .combine)
  }

  private func stop(_ title: String, at date: Date, marker: StopMarker) -> some View {
    HStack(spacing: Self.spacing) {
      marker
        .frame(width: Self.railWidth)
      Text(title)
      Spacer(minLength: 0)
      Text(ClockText.dayAndTime(date, relativeTo: now))
        .monospacedDigit()
        .contentTransition(.numericText())
    }
    .font(.callout.weight(.medium))
    .foregroundStyle(marker == .hollow ? .secondary : .primary)
  }

  private func stretch(_ duration: String, rail: Rail) -> some View {
    HStack(spacing: Self.spacing) {
      rail
        .frame(width: Self.railWidth)
      Text(duration)
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .contentTransition(.numericText())
        .padding(.vertical, 6)
    }
    .fixedSize(horizontal: false, vertical: true)
  }
}

private enum StopMarker: View {
  case hollow
  case filled

  var body: some View {
    switch self {
    case .hollow:
      Circle()
        .strokeBorder(.tertiary, lineWidth: 2)
        .frame(width: 9, height: 9)
    case .filled:
      Circle()
        .fill(.tint)
        .frame(width: 9, height: 9)
    }
  }
}

private enum Rail: View {
  case waiting
  case printing

  var body: some View {
    switch self {
    case .waiting:
      VerticalLine()
        .stroke(.tertiary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [0, 5]))
        .frame(width: 3)
    case .printing:
      Capsule()
        .fill(.tint)
        .frame(width: 3)
        .padding(.vertical, 3)
    }
  }
}

private nonisolated struct VerticalLine: Shape {
  func path(in rect: CGRect) -> Path {
    Path { path in
      path.move(to: CGPoint(x: rect.midX, y: rect.minY + 4))
      path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 4))
    }
  }
}
