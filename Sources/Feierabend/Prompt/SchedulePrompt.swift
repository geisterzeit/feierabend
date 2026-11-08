import AppKit
import SwiftUI
import os

/// Runs Feierabend as Bambu Studio's post-processing step: shows the scheduler,
/// rewrites the G-code if a time was chosen, and quits so slicing can continue.
enum SchedulePrompt {
  private static let logger = Logger(
    subsystem: "dev.julianmeser.Feierabend", category: "SchedulePrompt")

  static func run(for gcode: SlicedGCode, printName: String?) {
    let printDuration = estimatedPrintDuration(of: gcode)
    let view = SchedulePrintView(
      printName: printName,
      printDuration: printDuration,
      insertWait: { plan in
        try gcode.insert(WaitBlock(plan: plan, printDuration: printDuration))
        logger.notice("Scheduled start in \(Int(plan.wait)) s")
      },
      close: { NSApp.terminate(nil) }
    )

    let app = NSApplication.shared
    let delegate = PromptDelegate(content: view)
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
  }

  private static func estimatedPrintDuration(of gcode: SlicedGCode) -> TimeInterval? {
    do {
      return try gcode.printDuration()
    } catch {
      logger.error("Couldn't read the print time estimate: \(error.localizedDescription)")
      return nil
    }
  }
}

private final class PromptDelegate: NSObject, NSApplicationDelegate {
  private let content: SchedulePrintView
  private var panel: NSPanel?

  init(content: SchedulePrintView) {
    self.content = content
  }

  /// A borderless glass panel, so the prompt reads as a popup rather than a whole app.
  func applicationDidFinishLaunching(_ notification: Notification) {
    let card = NSHostingView(rootView: GlassCard(content: content))
    let cardSize = card.fittingSize
    // The card grows inside the panel, so the panel mustn't shrink to fit it.
    card.sizingOptions = []
    let panel = PopupPanel(
      contentRect: NSRect(origin: .zero, size: cardSize),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    panel.title = "Schedule Print"
    panel.contentView = card
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.isMovableByWindowBackground = true
    // Bambu Studio waits for this panel, so keep it from getting lost behind Bambu Studio.
    panel.level = .floating
    panel.hidesOnDeactivate = false
    panel.animationBehavior = .alertPanel
    panel.center()
    extendToBottomOfScreen(panel)
    panel.makeKeyAndOrderFront(nil)
    self.panel = panel
    NSApp.activate()
  }

  /// Gives the card room to grow downwards inside the transparent panel. Resizing the window
  /// while the card animates would make the card jump.
  private func extendToBottomOfScreen(_ panel: NSPanel) {
    guard let screen = panel.screen ?? NSScreen.main else { return }
    var frame = panel.frame
    frame.origin.y = min(screen.visibleFrame.minY, frame.minY)
    frame.size.height = panel.frame.maxY - frame.minY
    panel.setFrame(frame, display: false)
  }
}

/// Liquid Glass around the prompt, pinned to the top of a transparent panel with room below
/// for the card to grow into. Transparent parts of the panel let clicks through.
private struct GlassCard<Content: View>: View {
  let content: Content

  var body: some View {
    content
      .glassEffect(.regular, in: .rect(cornerRadius: 26))
      .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
      .padding(32)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }
}

/// Borderless panels don't take keyboard input unless they say so. Escape closes the prompt,
/// so Bambu Studio prints right away.
private final class PopupPanel: NSPanel {
  override var canBecomeKey: Bool { true }

  override func cancelOperation(_ sender: Any?) {
    NSApp.terminate(nil)
  }
}
