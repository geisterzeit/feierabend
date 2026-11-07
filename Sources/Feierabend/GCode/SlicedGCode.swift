import Foundation

/// A sliced G-code file that Bambu Studio hands to its post-processing scripts.
nonisolated struct SlicedGCode: Sendable {
  private static let headerLength = 64 * 1024
  /// Bambu Studio's machine start G-code begins after this line, so the wait runs before heating.
  private static let insertionAnchors = ["; EXECUTABLE_BLOCK_START", "; HEADER_BLOCK_END"]

  let url: URL

  func printDuration() throws -> TimeInterval? {
    let file = try FileHandle(forReadingFrom: url)
    defer { try? file.close() }
    let header = try file.read(upToCount: Self.headerLength) ?? Data()
    return PrintTimeEstimate.duration(inHeader: String(decoding: header, as: UTF8.self))
  }

  /// Rewrites the file in place, replacing any wait an earlier run inserted.
  func insert(_ waitBlock: WaitBlock) throws {
    let gcode = try Data(contentsOf: url, options: .alwaysMapped)
    try Self.inserting(waitBlock, into: gcode).write(to: url, options: .atomic)
  }

  static func inserting(_ waitBlock: WaitBlock, into gcode: Data) -> Data {
    let gcode = removingWait(from: gcode)
    let insertionPoint = insertionPoint(in: gcode)
    var result = Data(gcode[..<insertionPoint])
    result.append(Data(waitBlock.gcode.utf8))
    result.append(gcode[insertionPoint...])
    return result
  }

  private static func insertionPoint(in gcode: Data) -> Data.Index {
    for anchor in insertionAnchors {
      if let anchorRange = gcode.firstRange(of: Data(anchor.utf8)) {
        return endOfLine(containing: anchorRange.upperBound, in: gcode)
      }
    }
    return gcode.startIndex
  }

  private static func removingWait(from gcode: Data) -> Data {
    guard let start = gcode.firstRange(of: Data(WaitBlock.startMarker.utf8)),
      let end = gcode[start.upperBound...].firstRange(of: Data(WaitBlock.endMarker.utf8))
    else { return gcode }
    var result = Data(gcode[..<start.lowerBound])
    result.append(gcode[endOfLine(containing: end.upperBound, in: gcode)...])
    return result
  }

  private static func endOfLine(containing index: Data.Index, in gcode: Data) -> Data.Index {
    guard let newline = gcode[index...].firstIndex(of: UInt8(ascii: "\n")) else {
      return gcode.endIndex
    }
    return gcode.index(after: newline)
  }
}
