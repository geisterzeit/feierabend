import Foundation
import Testing

@testable import Feierabend

struct PrintTimeEstimateTests {
  @Test func `reads Bambu Studio's total estimated time`() {
    let header = """
      ; HEADER_BLOCK_START
      ; BambuStudio 02.08.02.61
      ; model printing time: 1h 2m 3s; total estimated time: 1h 10m 5s
      ; HEADER_BLOCK_END
      """

    #expect(PrintTimeEstimate.duration(inHeader: header) == TimeInterval(3600 + 10 * 60 + 5))
  }

  @Test func `reads multi-day estimates`() {
    let header = "; model printing time: 1d 2h; total estimated time: 1d 2h 0m 30s"

    #expect(PrintTimeEstimate.duration(inHeader: header) == TimeInterval(86_400 + 2 * 3600 + 30))
  }

  @Test func `reads Orca and PrusaSlicer estimates`() {
    let header = "; estimated printing time (normal mode) = 45m 12s"

    #expect(PrintTimeEstimate.duration(inHeader: header) == TimeInterval(45 * 60 + 12))
  }

  @Test func `has no estimate without a time line`() {
    #expect(PrintTimeEstimate.duration(inHeader: "G28\nG1 X10") == nil)
  }
}

struct WaitBlockTests {
  func waitBlock(wait: Int, printDuration: TimeInterval?) -> WaitBlock {
    WaitBlock(wait: wait, printDuration: printDuration, plannedStart: .now)
  }

  @Test func `splits the wait into dwells the firmware accepts`() {
    let gcode = waitBlock(wait: 150, printDuration: nil).gcode

    let dwells = gcode.split(separator: "\n").filter { $0.hasPrefix("G4") }
    #expect(dwells == ["G4 S60", "G4 S60", "G4 S30"])
    #expect(!gcode.contains("M73"))
  }

  @Test func `counts the wait into the remaining time`() {
    let gcode = waitBlock(wait: 120, printDuration: 3600).gcode

    let progress = gcode.split(separator: "\n").filter { $0.hasPrefix("M73") }
    #expect(progress == ["M73 P0 R62", "M73 P0 R61"])
  }

  @Test func `keeps the heaters off before every dwell`() {
    let lines = waitBlock(wait: 120, printDuration: nil).gcode.split(separator: "\n")
    let dwellIndices = lines.indices.filter { lines[$0].hasPrefix("G4") }

    for dwell in dwellIndices {
      #expect(lines[dwell - 2] == "M104 S0")
      #expect(lines[dwell - 1] == "M140 S0")
    }
  }

  @Test func `is wrapped in markers`() {
    let lines = waitBlock(wait: 60, printDuration: nil).gcode.split(separator: "\n")

    #expect(lines.first.map(String.init) == WaitBlock.startMarker)
    #expect(lines.last.map(String.init) == WaitBlock.endMarker)
  }
}

struct SlicedGCodeTests {
  let bambuGCode = """
    ; HEADER_BLOCK_START
    ; total estimated time: 10m 0s
    ; HEADER_BLOCK_END

    ; EXECUTABLE_BLOCK_START
    M73 P0 R10
    M140 S55

    """

  func waitBlock(seconds: Int) -> WaitBlock {
    WaitBlock(wait: seconds, printDuration: nil, plannedStart: .now)
  }

  func inserting(_ waitBlock: WaitBlock, into gcode: String) -> String {
    String(decoding: SlicedGCode.inserting(waitBlock, into: Data(gcode.utf8)), as: UTF8.self)
  }

  @Test func `waits right before the machine start G-code`() {
    let result = inserting(waitBlock(seconds: 60), into: bambuGCode)

    #expect(result.contains("; EXECUTABLE_BLOCK_START\n\(WaitBlock.startMarker)\n"))
    #expect(result.contains("\(WaitBlock.endMarker)\nM73 P0 R10\nM140 S55"))
  }

  @Test func `replaces a wait from an earlier run`() {
    let first = inserting(waitBlock(seconds: 120), into: bambuGCode)
    let second = inserting(waitBlock(seconds: 60), into: first)

    #expect(second.components(separatedBy: WaitBlock.startMarker).count == 2)
    #expect(second.contains("G4 S60\n\(WaitBlock.endMarker)"))
    #expect(!second.contains("G4 S60\nG4 S60"))
  }

  @Test func `waits at the top of G-code without Bambu markers`() {
    let result = inserting(waitBlock(seconds: 60), into: "G28\nG1 X10\n")

    #expect(result.hasPrefix(WaitBlock.startMarker))
    #expect(result.hasSuffix("\(WaitBlock.endMarker)\nG28\nG1 X10\n"))
  }

  @Test func `rewrites the file in place and reads its estimate`() throws {
    let url = FileManager.default.temporaryDirectory
      .appending(path: "feierabend-\(UUID().uuidString).gcode")
    defer { try? FileManager.default.removeItem(at: url) }
    try Data(bambuGCode.utf8).write(to: url)
    let gcode = SlicedGCode(url: url)

    try gcode.insert(waitBlock(seconds: 60))

    #expect(try gcode.printDuration() == 600)
    #expect(try String(contentsOf: url, encoding: .utf8).contains("G4 S60"))
  }
}

struct PostProcessingHookTests {
  @Test func `finds the G-code Bambu Studio appends`() throws {
    let url = FileManager.default.temporaryDirectory
      .appending(path: "plate-\(UUID().uuidString).gcode.pp")
    defer { try? FileManager.default.removeItem(at: url) }
    try Data().write(to: url)

    let gcodeFile = PostProcessingHook.gcodeFile(inArguments: ["Feierabend", url.path])

    #expect(gcodeFile?.path == url.path)
  }

  @Test(arguments: [
    ["Feierabend"],
    ["Feierabend", "-NSDocumentRevisionsDebugMode", "YES"],
    ["Feierabend", "/does/not/exist.gcode"],
  ])
  func `ignores ordinary launches`(arguments: [String]) {
    #expect(PostProcessingHook.gcodeFile(inArguments: arguments) == nil)
  }

  @Test func `quotes the executable path`() {
    let line = PostProcessingHook.scriptLine(forExecutableAt: "/Applications/My Apps/Feierabend")

    #expect(line == "\"/Applications/My Apps/Feierabend\"")
  }

  @Test func `names the print after Bambu Studio's output name`() {
    #expect(
      PostProcessingHook.printName(in: ["SLIC3R_PP_OUTPUT_NAME": "/tmp/Benchy_plate_1.gcode.3mf"])
        == "Benchy_plate_1")
    #expect(PostProcessingHook.printName(in: [:]) == nil)
  }
}

struct LaunchRoleTests {
  @Test func `tells the post-processing script from the scheduler it relaunches`() throws {
    let gcode = FileManager.default.temporaryDirectory
      .appending(path: "plate-\(UUID().uuidString).gcode")
    defer { try? FileManager.default.removeItem(at: gcode) }
    try Data().write(to: gcode)

    let script = LaunchRole(arguments: ["Feierabend", gcode.path])
    let scheduler = LaunchRole(
      arguments: ["Feierabend"] + LaunchRole.schedulerArguments(for: gcode))

    #expect(script == .postProcessingScript(gcode: URL(filePath: gcode.path)))
    #expect(scheduler == .scheduler(gcode: URL(filePath: gcode.path)))
    #expect(LaunchRole(arguments: ["Feierabend"]) == .setup)
  }
}
