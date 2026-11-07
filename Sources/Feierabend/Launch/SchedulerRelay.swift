import AppKit
import os

/// Bambu Studio starts post-processing scripts as plain child processes, and macOS doesn't let
/// those take keyboard focus from Bambu Studio. The relay relaunches Feierabend through
/// LaunchServices, which gives the scheduler an active window, and waits until it quits so
/// Bambu Studio only continues once the G-code is final.
enum SchedulerRelay {
  static func run(for gcode: URL, environment: [String: String]) {
    let app = NSApplication.shared
    let delegate = RelayDelegate(gcode: gcode, environment: environment)
    app.delegate = delegate
    app.setActivationPolicy(.prohibited)
    app.run()
  }
}

private final class RelayDelegate: NSObject, NSApplicationDelegate {
  private static let logger = Logger(
    subsystem: "dev.julianmeser.Feierabend", category: "SchedulerRelay")

  private let gcode: URL
  private let environment: [String: String]
  private var scheduler: NSRunningApplication?
  private var schedulerTermination: NSKeyValueObservation?

  init(gcode: URL, environment: [String: String]) {
    self.gcode = gcode
    self.environment = environment
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    Task {
      do {
        let scheduler = try await NSWorkspace.shared.openApplication(
          at: Bundle.main.bundleURL,
          configuration: schedulerConfiguration
        )
        self.scheduler = scheduler
        schedulerTermination = scheduler.observe(\.isTerminated, options: [.initial, .new]) {
          @Sendable scheduler, _ in
          guard scheduler.isTerminated else { return }
          Task { @MainActor in NSApp.terminate(nil) }
        }
      } catch {
        Self.logger.error("Couldn't open the scheduler: \(error.localizedDescription)")
        FileHandle.standardError.write(
          Data("Feierabend couldn't open the scheduler: \(error.localizedDescription)\n".utf8))
        exit(EXIT_FAILURE)
      }
    }
  }

  private var schedulerConfiguration: NSWorkspace.OpenConfiguration {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.createsNewApplicationInstance = true
    configuration.arguments = LaunchRole.schedulerArguments(for: gcode)
    configuration.environment = environment.filter {
      $0.key == PostProcessingHook.outputNameVariable
    }
    return configuration
  }
}
