import Foundation

/// A 3MF file opened in Bambu Studio: a zip archive whose project settings live in one entry.
nonisolated struct ProjectFile {
  static let settingsEntry = "Metadata/project_settings.config"

  let url: URL

  var name: String {
    url.deletingPathExtension().lastPathComponent
  }

  /// `nil` for a plain 3MF, which brings no settings and keeps Bambu Studio's presets.
  func settings() throws -> ProjectSettings? {
    let json = try ArchiveTool.run(
      "/usr/bin/unzip", ["-p", url.path, Self.settingsEntry], allowingStatus: ArchiveTool.noMatch)
    return try json.map(ProjectSettings.init(json:))
  }

  /// Rewrites a copy and swaps it in, so the project is never left half written.
  func replaceSettings(with settings: ProjectSettings) throws {
    let fileManager = FileManager.default
    let workspace = try fileManager.url(
      for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: url, create: true)
    defer { try? fileManager.removeItem(at: workspace) }

    let archive = workspace.appending(path: url.lastPathComponent)
    try fileManager.copyItem(at: url, to: archive)
    let entryRoot = workspace.appending(path: "entry")
    let entry = entryRoot.appending(path: Self.settingsEntry)
    try fileManager.createDirectory(
      at: entry.deletingLastPathComponent(), withIntermediateDirectories: true)
    try settings.json().write(to: entry)
    _ = try ArchiveTool.run(
      "/usr/bin/zip", ["-q", archive.path, Self.settingsEntry], in: entryRoot)
    _ = try fileManager.replaceItemAt(url, withItemAt: archive)
  }
}

/// Runs the zip tools macOS ships with, since Foundation has no zip archive API.
private nonisolated enum ArchiveTool {
  /// unzip's exit status when the archive has no entry by the requested name.
  static let noMatch: Int32 = 11

  struct Failure: LocalizedError {
    let tool: String
    let status: Int32
    let message: String

    var errorDescription: String? {
      "\(URL(filePath: tool).lastPathComponent) failed (\(status)): \(message)"
    }
  }

  /// The tool's output, or `nil` when it exits with `allowedStatus`.
  static func run(
    _ tool: String,
    _ arguments: [String],
    in directory: URL? = nil,
    allowingStatus allowedStatus: Int32? = nil
  ) throws -> Data? {
    let process = Process()
    process.executableURL = URL(filePath: tool)
    process.arguments = arguments
    process.currentDirectoryURL = directory
    let output = Pipe()
    let errors = Pipe()
    process.standardOutput = output
    process.standardError = errors
    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    let message = errors.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    switch process.terminationStatus {
    case 0:
      return data
    case allowedStatus:
      return nil
    case let status:
      throw Failure(
        tool: tool,
        status: status,
        message: String(decoding: message, as: UTF8.self)
          .trimmingCharacters(in: .whitespacesAndNewlines)
      )
    }
  }
}
