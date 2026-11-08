import SwiftUI

/// Asks whether a freshly sliced print should start right away, or when it should start or finish.
struct SchedulePrintView: View {
  let printName: String?
  let printDuration: TimeInterval?
  let insertWait: (PrintPlan) throws -> Void
  let close: () -> Void

  @AppStorage("scheduleAnchor") private var preferredAnchor = ScheduleAnchor.finish
  @AppStorage("scheduleTime") private var time = TimeOfDay(hour: 7, minute: 30)
  @State private var isScheduling = false
  @State private var isTimeReadable = true
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
      VStack(spacing: 16) {
        header
        Toggle("Schedule for later", isOn: $isScheduling.animation(toggleAnimation))
          .toggleStyle(.switch)
          .font(.body.weight(.medium))
        if isScheduling {
          scheduleControls(plan: plan, now: context.date)
            .transition(scheduleControlsTransition)
        }
        if let failure {
          Label(failure, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.red)
            .transition(.opacity)
        }
        primaryAction(canSchedule: plan != nil)
      }
      .padding(20)
      .frame(width: 340)
    }
    .tint(.bambuGreen)
  }

  /// The controls fade in once the card has made room, and out before it closes over them.
  private var scheduleControlsTransition: AnyTransition {
    .asymmetric(
      insertion: .opacity.animation(.easeOut(duration: 0.2).delay(reduceMotion ? 0 : 0.08)),
      removal: .opacity.animation(.easeOut(duration: 0.1))
    )
  }

  private var toggleAnimation: Animation? {
    reduceMotion ? .easeOut(duration: 0.15) : .snappy(duration: 0.3)
  }

  private func scheduleControls(plan: PrintPlan?, now: Date) -> some View {
    VStack(spacing: 16) {
      if printDuration != nil {
        anchorPicker
      }
      TimeDial(
        time: $time,
        isReadable: $isTimeReadable,
        label: anchor == .start ? "Start at" : "Finish by",
        day: plan.map { ClockText.day(of: anchoredDate(of: $0), relativeTo: now) } ?? ""
      )
      // The time field takes Return for itself, which would otherwise press Schedule.
      .onSubmit(scheduleWait)
      if let plan {
        PlanTimeline(plan: plan, printDuration: printDuration, now: now)
      }
    }
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

  /// Prints right away unless scheduling, in which case it first adds the wait.
  /// Both titles stay in the button and cross-fade, so they move with it while the card resizes.
  private func primaryAction(canSchedule: Bool) -> some View {
    Button {
      if isScheduling { scheduleWait() } else { close() }
    } label: {
      ZStack {
        Label("Print Now", systemImage: "printer.fill")
          .opacity(isScheduling ? 0 : 1)
          .accessibilityHidden(isScheduling)
        Label(
          isScheduled ? "Scheduled" : "Schedule",
          systemImage: isScheduled ? "checkmark" : "moon.zzz.fill"
        )
        .contentTransition(.symbolEffect(.replace))
        .opacity(isScheduling ? 1 : 0)
        .accessibilityHidden(!isScheduling)
      }
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(.borderedProminent)
    .controlSize(.large)
    .keyboardShortcut(.defaultAction)
    .disabled(isScheduled || (isScheduling && !(canSchedule && isTimeReadable)))
    .help(
      isScheduling
        ? "The wait counts from when the printer receives the job, so press Print in Bambu Studio right away."
        : "Continue to Bambu Studio and print without waiting."
    )
  }

  private func anchoredDate(of plan: PrintPlan) -> Date {
    anchor == .finish ? plan.finish ?? plan.start : plan.start
  }

  /// Plans from this very moment, so time spent in the prompt doesn't lengthen the wait.
  private func scheduleWait() {
    guard isTimeReadable, let plan = PrintPlan(schedule, printDuration: printDuration, now: .now)
    else { return }
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
