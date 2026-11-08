import Foundation

/// The process, filament, and printer settings a Bambu Studio project brings along, which
/// replace the presets chosen in Bambu Studio when the project opens.
nonisolated struct ProjectSettings: Equatable {
  private static let postProcessingScriptsKey = "post_process"
  /// Lists the settings each preset changes, the process preset's first, as `;`-separated keys.
  private static let changedSettingsKey = "different_settings_to_system"

  private var values: [String: Value]

  init(json: Data) throws {
    values = try JSONDecoder().decode([String: Value].self, from: json)
  }

  func json() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(values)
  }

  var postProcessingScripts: [String] {
    values[Self.postProcessingScriptsKey]?.list ?? []
  }

  /// Makes Bambu Studio run `scriptLine` after slicing this project, in place of a line
  /// for a Feierabend installed elsewhere.
  mutating func addPostProcessingScript(_ scriptLine: String) {
    guard !postProcessingScripts.contains(scriptLine) else { return }
    var scripts = postProcessingScripts.filter { !PostProcessingHook.isScriptLine($0) }
    scripts.append(scriptLine)
    values[Self.postProcessingScriptsKey] = .list(scripts)
    markProcessSettingChanged(Self.postProcessingScriptsKey)
  }

  /// Bambu Studio records which process settings differ from the preset, as it would after
  /// changing them by hand.
  private mutating func markProcessSettingChanged(_ key: String) {
    guard var presets = values[Self.changedSettingsKey]?.list, let processSettings = presets.first
    else { return }
    var keys = Set(processSettings.split(separator: ";").map(String.init))
    keys.insert(key)
    presets[0] = keys.sorted().joined(separator: ";")
    values[Self.changedSettingsKey] = .list(presets)
  }
}

extension ProjectSettings {
  /// Bambu Studio stores every setting as a string, or as a list of strings for settings
  /// that differ per extruder or filament.
  fileprivate nonisolated enum Value: Codable, Equatable {
    case single(String)
    case list([String])

    var list: [String]? {
      if case .list(let values) = self { values } else { nil }
    }

    init(from decoder: any Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let value = try? container.decode(String.self) {
        self = .single(value)
      } else {
        self = .list(try container.decode([String].self))
      }
    }

    func encode(to encoder: any Encoder) throws {
      var container = encoder.singleValueContainer()
      switch self {
      case .single(let value): try container.encode(value)
      case .list(let values): try container.encode(values)
      }
    }
  }
}
