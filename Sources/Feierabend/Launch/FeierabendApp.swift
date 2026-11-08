import SwiftUI

@main
enum Launcher {
  static func main() {
    let environment = ProcessInfo.processInfo.environment
    switch LaunchRole(arguments: CommandLine.arguments) {
    case .setup:
      FeierabendApp.main()
    case .postProcessingScript(let gcode):
      SchedulerRelay.run(for: gcode, environment: environment)
    case .scheduler(let gcode):
      SchedulePrompt.run(
        for: SlicedGCode(url: gcode),
        printName: PostProcessingHook.printName(in: environment)
      )
    }
  }
}

struct FeierabendApp: App {
  @NSApplicationDelegateAdaptor private var delegate: SetupAppDelegate

  var body: some Scene {
    Window("Feierabend", id: "setup") {
      SetupView()
    }
    .windowResizability(.contentSize)
  }
}

/// Receives 3MF projects opened with Feierabend from Finder or the Dock.
final class SetupAppDelegate: NSObject, NSApplicationDelegate {
  private var isLaunching = true

  func applicationDidFinishLaunching(_ notification: Notification) {
    isLaunching = false
  }

  /// Launched just to open projects, it keeps the setup window out of the way and quits
  /// once the projects are in Bambu Studio.
  func application(_ application: NSApplication, open urls: [URL]) {
    let launchedForProjects = isLaunching
    if launchedForProjects {
      for window in application.windows { window.orderOut(nil) }
    }
    Task {
      await ProjectOpener.open(urls)
      if launchedForProjects { NSApp.terminate(nil) }
    }
  }
}
