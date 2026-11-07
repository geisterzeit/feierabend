import SwiftUI

/// Asks when a freshly sliced print should start or finish.
struct SchedulePrintView: View {
  let printName: String?
  let printDuration: TimeInterval?
  let insertWait: (PrintPlan) throws -> Void
  let close: () -> Void

  @AppStorage("scheduleAnchor") private var preferredAnchor = ScheduleAnchor.finish
  @AppStorage("scheduleTime") private var time = TimeOfDay(hour: 7, minute: 30)
  @State private var failure: String?
  @State private var isScheduled = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  /// Finishing by a time needs the slicer's estimate, so without one the time pins the start.
  private var anchor: ScheduleAnchor {
    printDuration == nil ? .start : preferredAnchor
  }

  private var schedule: PrintSchedule {
    PrintSchedule(anchor: anchor, time: time)
  }

  var body: some View {
    TimelineView(.everyMinute) { context in
      let plan = PrintPlan(schedule, printDuration: printDuration, now: context.date)
      VStack(alignment: .leading, spacing: 16) {
        header
        if printDuration != nil {
          anchorPicker
        }
        TimeDial(
          time: $time,
          label: anchor == .start ? "Start at" : "Finish by",
          day: plan.map { ClockText.day(of: anchoredDate(of: $0), relativeTo: context.date) } ?? ""
        )
        if let plan {
          PlanTimeline(plan: plan, printDuration: printDuration, now: context.date)
        }
        if let failure {
          Label(failure, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.red)
            .transition(.opacity)
        }
        actions(isEnabled: plan != nil)
      }
      .padding(20)
      .frame(width: 340)
    }
    .tint(.bambuGreen)
  }

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(printName ?? "Schedule Print")
        .font(.headline)
        .lineLimit(1)
        .truncationMode(.middle)
      Spacer()
      if let printDuration {
        Label(ClockText.duration(printDuration), systemImage: "printer.fill")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)
          .accessibilityLabel("Prints for \(ClockText.duration(printDuration))")
      }
    }
  }

  private var anchorPicker: some View {
    Picker("Plan by", selection: $preferredAnchor) {
      Text("Start at").tag(ScheduleAnchor.start)
      Text("Finish by").tag(ScheduleAnchor.finish)
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .frame(maxWidth: .infinity)
  }

  private func actions(isEnabled: Bool) -> some View {
    HStack(spacing: 10) {
      Button {
        close()
      } label: {
        Text("Print Now")
          .frame(maxWidth: .infinity)
      }
      .keyboardShortcut(.cancelAction)
      .tint(nil)

      Button {
        scheduleWait()
      } label: {
        Label(
          isScheduled ? "Scheduled" : "Schedule",
          systemImage: isScheduled ? "checkmark" : "moon.zzz.fill"
        )
        .contentTransition(.symbolEffect(.replace))
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .keyboardShortcut(.defaultAction)
      .disabled(!isEnabled)
      .help(
        "The wait counts from when the printer receives the job, so press Print in Bambu Studio right away."
      )
    }
    .controlSize(.large)
    .disabled(isScheduled)
  }

  private func anchoredDate(of plan: PrintPlan) -> Date {
    anchor == .finish ? plan.finish ?? plan.start : plan.start
  }

  /// Plans from this very moment, so time spent in the prompt doesn't lengthen the wait.
  private func scheduleWait() {
    guard let plan = PrintPlan(schedule, printDuration: printDuration, now: .now) else { return }
    do {
      try insertWait(plan)
    } catch {
      withAnimation { failure = "Couldn't add the wait: \(error.localizedDescription)" }
      return
    }
    withAnimation(.snappy(duration: 0.25)) { isScheduled = true }
    Task {
      try? await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 550))
      close()
    }
  }
}
