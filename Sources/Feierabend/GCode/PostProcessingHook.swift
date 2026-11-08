import Foundation

/// How Bambu Studio runs Feierabend as a post-processing script.
///
/// Bambu Studio runs each script line through `/bin/sh`, appends the path of the sliced
/// G-code (sometimes a `.gcode.pp` working copy) and expects the file to be changed in place.
nonisolated enum PostProcessingHook {
  static let outputNameVariable = "SLIC3R_PP_OUTPUT_NAME"

  /// The line that runs this copy of Feierabend.
  static var scriptLine: String {
    scriptLine(
      forExecutableAt: Bundle.main.executablePath
        ?? "/Applications/Feierabend.app/Contents/MacOS/Feierabend")
  }

  static func scriptLine(forExecutableAt path: String) -> String {
    "\"\(path)\""
  }

  /// Whether `line` runs Feierabend, wherever it was installed at the time.
  static func isScriptLine(_ line: String) -> Bool {
    line.hasSuffix("/Feierabend.app/Contents/MacOS/Feierabend\"")
  }

  static func gcodeFile(
    inArguments arguments: [String],
    fileManager: FileManager = .default
  ) -> URL? {
    guard arguments.count > 1, let path = arguments.last, path.contains(".gcode") else {
      return nil
    }
    var isDirectory: ObjCBool = false
    guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue
    else { return nil }
    return URL(filePath: path)
  }

  /// The plate name Bambu Studio would use for the exported file, without extensions.
  static func printName(in environment: [String: String]) -> String? {
    guard let outputName = environment[outputNameVariable], !outputName.isEmpty else {
      return nil
    }
    var name = URL(filePath: outputName).lastPathComponent
    for suffix in [".3mf", ".gcode"] where name.hasSuffix(suffix) {
      name.removeLast(suffix.count)
    }
    return name.isEmpty ? nil : name
  }
}
