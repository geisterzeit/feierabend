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
    let card = GlassCard(content: NSHostingView(rootView: content))
    let panel = PopupPanel(
      contentRect: NSRect(origin: .zero, size: card.fittingSize),
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
    panel.makeKeyAndOrderFront(nil)
    self.panel = panel
    NSApp.activate()
  }
}

/// Liquid Glass with a shadow that follows its rounded corners. A borderless window's own
/// shadow would follow the full rectangle the glass is drawn in.
private final class GlassCard: NSView {
  private static let cornerRadius: CGFloat = 26
  private static let shadowMargin: CGFloat = 32

  private let glass = NSGlassEffectView()

  init(content: NSView) {
    super.init(frame: .zero)
    wantsLayer = true
    layer?.shadowColor = NSColor.black.cgColor
    layer?.shadowOpacity = 0.3
    layer?.shadowRadius = 16
    layer?.shadowOffset = CGSize(width: 0, height: -6)

    glass.cornerRadius = Self.cornerRadius
    glass.contentView = content
    glass.translatesAutoresizingMaskIntoConstraints = false
    addSubview(glass)
    NSLayoutConstraint.activate([
      glass.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.shadowMargin),
      glass.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.shadowMargin),
      glass.topAnchor.constraint(equalTo: topAnchor, constant: Self.shadowMargin),
      glass.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.shadowMargin),
    ])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not supported")
  }

  override func layout() {
    super.layout()
    layer?.shadowPath = CGPath(
      roundedRect: glass.frame,
      cornerWidth: Self.cornerRadius,
      cornerHeight: Self.cornerRadius,
      transform: nil
    )
  }
}

/// Borderless panels don't take keyboard input unless they say so.
private final class PopupPanel: NSPanel {
  override var canBecomeKey: Bool { true }
}
