import SwiftUI

/// The plan at a glance: a dotted stretch while the printer waits, then a solid one while it prints.
struct PlanTimeline: View {
  let plan: PrintPlan
  let printDuration: TimeInterval?
  let now: Date

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Both stretches stay visible, however lopsided the plan.
  private var waitShare: CGFloat {
    guard let printDuration else { return 1 }
    guard plan.wait >= 60 else { return 0 }
    let share = plan.wait / (plan.wait + printDuration)
    return min(max(share, 0.15), 0.85)
  }

  var body: some View {
    VStack(spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        endpoint("Starts", plan.start, alignment: .leading)
        Spacer()
        if let finish = plan.finish {
          endpoint("Done", finish, alignment: .trailing)
        }
      }
      bar
        .frame(height: 6)
      HStack {
        Text("waits \(ClockText.duration(plan.wait))")
        Spacer()
        if let printDuration {
          Text("prints \(ClockText.duration(printDuration))")
        }
      }
      .font(.caption.weight(.medium))
      .foregroundStyle(.secondary)
      .contentTransition(.numericText())
    }
    .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: plan)
    .accessibilityElement(children: .combine)
  }

  private func endpoint(_ title: String, _ date: Date, alignment: HorizontalAlignment) -> some View
  {
    VStack(alignment: alignment, spacing: 1) {
      Text(title)
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
      Text(ClockText.dayAndTime(date, relativeTo: now))
        .font(.callout.weight(.medium).monospacedDigit())
        .contentTransition(.numericText())
    }
  }

  private var bar: some View {
    GeometryReader { geometry in
      let spacing: CGFloat = waitShare > 0 && waitShare < 1 ? 4 : 0
      let waitWidth = (geometry.size.width - spacing) * waitShare
      HStack(spacing: spacing) {
        DottedLine()
          .stroke(.tertiary, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [0, 8]))
          .frame(width: waitWidth)
        Capsule()
          .fill(.tint)
      }
    }
  }
}

private nonisolated struct DottedLine: Shape {
  func path(in rect: CGRect) -> Path {
    Path { path in
      path.move(to: CGPoint(x: rect.minX + 2, y: rect.midY))
      path.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.midY))
    }
  }
}
