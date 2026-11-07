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
  var body: some Scene {
    Window("Feierabend", id: "setup") {
      SetupView()
    }
    .windowResizability(.contentSize)
  }
}
