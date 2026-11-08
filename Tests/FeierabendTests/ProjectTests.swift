import Foundation
import Testing

@testable import Feierabend

struct ProjectSettingsTests {
  let scriptLine = #""/Applications/Feierabend.app/Contents/MacOS/Feierabend""#

  func settings(_ json: String) throws -> ProjectSettings {
    try ProjectSettings(json: Data(json.utf8))
  }

  @Test func `adds the script and marks it as a changed process setting`() throws {
    var settings = try settings(
      #"""
      {
        "post_process": [],
        "different_settings_to_system": ["wall_loops;enable_support", "nozzle_temperature", ""],
        "print_settings_id": "0.20mm Standard @BBL X1C"
      }
      """#)

    settings.addPostProcessingScript(scriptLine)

    let expected = try self.settings(
      #"""
      {
        "post_process": ["\"/Applications/Feierabend.app/Contents/MacOS/Feierabend\""],
        "different_settings_to_system": [
          "enable_support;post_process;wall_loops", "nozzle_temperature", ""
        ],
        "print_settings_id": "0.20mm Standard @BBL X1C"
      }
      """#)
    #expect(settings == expected)
  }

  @Test func `leaves a project that already runs the script alone`() throws {
    let original = try settings(
      #"{"post_process": ["\"/Applications/Feierabend.app/Contents/MacOS/Feierabend\""]}"#)
    var settings = original

    settings.addPostProcessingScript(scriptLine)

    #expect(settings == original)
  }

  @Test func `replaces Feierabend installed elsewhere and keeps other scripts`() throws {
    var settings = try settings(
      #"""
      {"post_process": [
        "/usr/local/bin/cleanup.sh",
        "\"/Users/me/build/Feierabend.app/Contents/MacOS/Feierabend\""
      ]}
      """#)

    settings.addPostProcessingScript(scriptLine)

    #expect(settings.postProcessingScripts == ["/usr/local/bin/cleanup.sh", scriptLine])
  }

  @Test func `adds the script to a project without any`() throws {
    var settings = try settings(#"{"layer_height": "0.2"}"#)

    settings.addPostProcessingScript(scriptLine)

    #expect(settings.postProcessingScripts == [scriptLine])
  }

  @Test func `writes every other setting back unchanged`() throws {
    let original = try settings(
      #"{"layer_height": "0.2", "filament_type": ["PLA", "PETG"], "post_process": []}"#)

    let reread = try ProjectSettings(json: original.json())

    #expect(reread == original)
  }

  @Test func `refuses settings it doesn't understand`() {
    #expect(throws: (any Error).self) {
      try settings(#"{"layer_height": 0.2}"#)
    }
  }
}

struct ProjectFileTests {
  let folder: URL

  init() throws {
    folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  }

  /// Zips `entries` into a 3MF the way Bambu Studio lays them out.
  func project(_ entries: [String: String]) throws -> ProjectFile {
    let contents = folder.appending(path: "contents")
    for (path, text) in entries {
      let file = contents.appending(path: path)
      try FileManager.default.createDirectory(
        at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
      try Data(text.utf8).write(to: file)
    }
    let url = folder.appending(path: "Pot Saver.3mf")
    let zip = Process()
    zip.executableURL = URL(filePath: "/usr/bin/zip")
    zip.arguments = ["-q", "-r", url.path, "."]
    zip.currentDirectoryURL = contents
    try zip.run()
    zip.waitUntilExit()
    try #require(zip.terminationStatus == 0)
    return ProjectFile(url: url)
  }

  func entry(_ path: String, of project: ProjectFile) throws -> String {
    let unzip = Process()
    let output = Pipe()
    unzip.executableURL = URL(filePath: "/usr/bin/unzip")
    unzip.arguments = ["-p", project.url.path, path]
    unzip.standardOutput = output
    try unzip.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    unzip.waitUntilExit()
    return String(decoding: data, as: UTF8.self)
  }

  @Test func `a plain 3MF brings no settings`() throws {
    let project = try project(["3D/3dmodel.model": "<model/>"])

    #expect(try project.settings() == nil)
  }

  @Test func `replacing the settings keeps the rest of the project`() throws {
    let project = try project([
      "3D/3dmodel.model": "<model/>",
      ProjectFile.settingsEntry: #"{"post_process": [], "layer_height": "0.2"}"#,
    ])
    var settings = try #require(try project.settings())
    settings.addPostProcessingScript(#""/Applications/Feierabend.app/Contents/MacOS/Feierabend""#)

    try project.replaceSettings(with: settings)

    #expect(try project.settings() == settings)
    #expect(try entry("3D/3dmodel.model", of: project) == "<model/>")
  }

  @Test func `a file that isn't a zip archive can't be read`() throws {
    let url = folder.appending(path: "broken.3mf")
    try Data("not a zip".utf8).write(to: url)

    #expect(throws: (any Error).self) {
      try ProjectFile(url: url).settings()
    }
  }
}
