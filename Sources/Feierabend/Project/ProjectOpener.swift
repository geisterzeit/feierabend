import AppKit
import os

/// Opens 3MF projects in Bambu Studio after adding Feierabend's post-processing script.
/// A project brings its own process settings, which replace the preset holding the script,
/// so without it Bambu Studio wouldn't run Feierabend after slicing the project.
enum ProjectOpener {
  /// Whether to ask before changing a project, or to add the script right away.
  static let asksBeforeChangingKey = "asksBeforeChangingProjects"

  private static let bambuStudioBundleID = "com.bambulab.bambu-studio"
  private static let logger = Logger(
    subsystem: "dev.julianmeser.Feierabend", category: "ProjectOpener")

  private static var asksBeforeChanging: Bool {
    UserDefaults.standard.object(forKey: asksBeforeChangingKey) as? Bool ?? true
  }

  static func open(_ projects: [URL]) async {
    guard
      let bambuStudio = NSWorkspace.shared.urlForApplication(
        withBundleIdentifier: bambuStudioBundleID)
    else {
      showAlert("Bambu Studio isn't installed.", "Feierabend opens projects in Bambu Studio.")
      return
    }
    for project in projects {
      addScriptIfWanted(to: ProjectFile(url: project))
    }
    do {
      try await NSWorkspace.shared.open(
        projects, withApplicationAt: bambuStudio, configuration: .init())
    } catch {
      showAlert("Couldn't open Bambu Studio.", error.localizedDescription)
    }
  }

  private static func addScriptIfWanted(to project: ProjectFile) {
    do {
      guard var settings = try project.settings() else { return }
      let original = settings
      settings.addPostProcessingScript(PostProcessingHook.scriptLine)
      guard settings != original, !asksBeforeChanging || confirmChange(of: project) else { return }
      try project.replaceSettings(with: settings)
      logger.notice("Added the post-processing script to \(project.name, privacy: .public)")
    } catch {
      showAlert(
        "Couldn't add Feierabend to “\(project.name)”.",
        "Bambu Studio opens it unchanged, so it won't ask when to print. \(error.localizedDescription)"
      )
    }
  }

  private static func confirmChange(of project: ProjectFile) -> Bool {
    let alert = NSAlert()
    alert.messageText = "Add the post-processing script to “\(project.name)”?"
    alert.informativeText = "Feierabend then asks when to print each time you slice this project."
    alert.addButton(withTitle: "Add and Open")
    alert.addButton(withTitle: "Open Unchanged").keyEquivalent = "\u{1b}"
    alert.showsSuppressionButton = true
    alert.suppressionButton?.title = "Always add without asking"
    NSApp.activate()
    let adds = alert.runModal() == .alertFirstButtonReturn
    if adds, alert.suppressionButton?.state == .on {
      UserDefaults.standard.set(false, forKey: asksBeforeChangingKey)
    }
    return adds
  }

  private static func showAlert(_ message: String, _ information: String) {
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = information
    NSApp.activate()
    alert.runModal()
  }
}
