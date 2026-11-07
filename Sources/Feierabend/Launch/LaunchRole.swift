import Foundation

/// Why this Feierabend process was started.
nonisolated enum LaunchRole: Equatable {
  /// Opened by the user, so explain how to connect Bambu Studio.
  case setup
  /// Started by Bambu Studio as its post-processing script.
  case postProcessingScript(gcode: URL)
  /// Relaunched by the post-processing script to ask when the print should run.
  case scheduler(gcode: URL)

  private static let schedulerFlag = "--scheduler"

  init(arguments: [String], fileManager: FileManager = .default) {
    guard let gcode = PostProcessingHook.gcodeFile(inArguments: arguments, fileManager: fileManager)
    else {
      self = .setup
      return
    }
    self =
      arguments.dropFirst().contains(Self.schedulerFlag)
      ? .scheduler(gcode: gcode) : .postProcessingScript(gcode: gcode)
  }

  static func schedulerArguments(for gcode: URL) -> [String] {
    [schedulerFlag, gcode.path]
  }
}
