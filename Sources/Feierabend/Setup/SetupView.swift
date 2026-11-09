import AppKit
import SwiftUI

/// Walks through connecting Feierabend to Bambu Studio's post-processing scripts.
struct SetupView: View {
  private static let bambuStudioBundleID = "com.bambulab.bambu-studio"

  private let scriptLine = PostProcessingHook.scriptLine
  private let isInApplications = Bundle.main.bundlePath.hasPrefix("/Applications/")
  private let bambuStudio = NSWorkspace.shared.urlForApplication(
    withBundleIdentifier: bambuStudioBundleID)

  @State private var copiedScriptLine = false
  @State private var showsPresetSteps = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage(ProjectOpener.asksBeforeChangingKey) private var asksBeforeChangingProjects = true

  var body: some View {
    VStack(spacing: 0) {
      header
      Form {
        if !isInApplications {
          Section {
            Label(
              "Move Feierabend to the Applications folder first, so Bambu Studio always finds it.",
              systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.orange)
          }
        }
        Section {
          step(
            1,
            "In Finder, choose **File › Get Info** on any 3MF file, pick Feierabend under **Open With** and click **Change All**."
          )
          step(
            2,
            "Open a project. Feierabend adds its post-processing line and opens it in Bambu Studio."
          )
          step(
            3,
            "Slice the plate. Feierabend asks when to start or finish, then press **Print plate** as usual."
          )
          Toggle("Ask before adding the line to a project", isOn: $asksBeforeChangingProjects)
        } header: {
          Text("Open Projects with Feierabend")
        } footer: {
          Text(
            "A project's own process settings replace your preset, so Feierabend adds the line to each project."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        }
        Section("Models Without a Project") {
          DisclosureGroup(isExpanded: presetStepsExpansion) {
            presetSteps
          } label: {
            Text(
              "STL and STEP files, and new projects, use your process preset instead. To schedule them too, add the line to the preset."
            )
            .fixedSize(horizontal: false, vertical: true)
          }
        }
        Section("How It Works") {
          Text(
            "Feierabend adds a pause before the start G-code. The printer stays cold until the planned start, then heats up and prints. Bambu Studio still sends the job through Bambu Cloud."
          )
          .foregroundStyle(.secondary)
        }
      }
      .formStyle(.grouped)
    }
    .frame(width: 540)
    .fixedSize(horizontal: false, vertical: true)
    .tint(.bambuGreen)
  }

  /// Folds the preset steps faster than the system default, and without motion when reduced.
  private var presetStepsExpansion: Binding<Bool> {
    Binding {
      showsPresetSteps
    } set: { shows in
      withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
        showsPresetSteps = shows
      }
    }
  }

  private var presetSteps: some View {
    VStack(alignment: .leading, spacing: 14) {
      step(1, "Open the **Prepare** tab in Bambu Studio.") {
        if let bambuStudio {
          Button("Open Bambu Studio") {
            NSWorkspace.shared.openApplication(at: bambuStudio, configuration: .init())
          }
        }
      }
      step(
        2,
        "In the **Process** panel on the left, keep **Global** selected and turn on the **Advance** switch at its top right."
      )
      step(
        3, "Click the **Others** tab and scroll all the way down to **Post-processing scripts**.")
      step(4, "Paste this line into that box:") {
        scriptLineBox
      }
      step(
        5,
        "Save the process preset with the save icon next to its name. The line belongs to the preset, so prints with an unsaved preset won't ask."
      )
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, 10)
  }

  private var header: some View {
    HStack(spacing: 14) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text("Feierabend")
          .font(.title2.weight(.semibold))
        Text("Let Bambu prints wait, and finish when you need them.")
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 24)
    .padding(.top, 20)
  }

  private func step(
    _ number: Int,
    _ instruction: LocalizedStringKey,
    @ViewBuilder accessory: () -> some View = { EmptyView() }
  ) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: "\(number).circle.fill")
        .foregroundStyle(.tint)
        .accessibilityLabel("Step \(number)")
      VStack(alignment: .leading, spacing: 8) {
        Text(instruction)
          .fixedSize(horizontal: false, vertical: true)
        accessory()
      }
    }
  }

  private var scriptLineBox: some View {
    HStack(alignment: .center, spacing: 10) {
      Text(scriptLine)
        .font(.callout.monospaced())
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
      Button(
        copiedScriptLine ? "Copied" : "Copy",
        systemImage: copiedScriptLine ? "checkmark" : "doc.on.doc"
      ) {
        copyScriptLine()
      }
      .buttonStyle(.borderedProminent)
      .contentTransition(.symbolEffect(.replace))
    }
    .padding(10)
    .background(.fill.quaternary, in: .rect(cornerRadius: 8))
  }

  private func copyScriptLine() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(scriptLine, forType: .string)
    copiedScriptLine = true
    Task {
      try? await Task.sleep(for: .seconds(2))
      copiedScriptLine = false
    }
  }
}
