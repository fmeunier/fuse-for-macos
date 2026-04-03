import AppKit
import SwiftUI

private let phantomTypistModes = optionChoices(
  { cocoa_media_phantom_typist_mode_bridge() },
  fallback: [
    "Disabled",
    "Auto",
    "Keyword",
    "Keystroke",
    "Menu",
    "Plus 2A",
    "Plus 3",
  ]
)

func generalPreferencesPane(resetAction: @escaping () -> Void) -> AnyView {
  AnyView(GeneralPreferencesView(resetAction: resetAction))
}

private struct GeneralPreferencesView: View {
  @AppStorage("speed") private var speed = 100
  @AppStorage("rate") private var rate = 1.0
  @AppStorage("issue2") private var issue2 = false
  @AppStorage("latetimings") private var lateTimings = false
  @AppStorage("z80iscmos") private var z80IsCMOS = false
  @AppStorage("writableroms") private var writableROMs = false
  @AppStorage("joyprompt") private var joystickPrompt = false
  @AppStorage("slttraps") private var sltTraps = false
  @AppStorage("confirmactions") private var confirmActions = false
  @AppStorage("statusbar") private var statusBar = false
  @AppStorage("accelerateloader") private var accelerateLoader = false
  @AppStorage("detectloader") private var detectLoader = false
  @AppStorage("fastload") private var fastLoad = false
  @AppStorage("tapetraps") private var tapeTraps = false
  @AppStorage("phantomtypistmode") private var phantomTypistMode = ""

  private let resetAction: () -> Void

  init(resetAction: @escaping () -> Void) {
    self.resetAction = resetAction
  }

  var body: some View {
    CenteredPreferencesPane(width: 548) {
      VStack(alignment: .leading, spacing: 14) {
        topFields
          .frame(maxWidth: .infinity, alignment: .center)

        HStack(alignment: .top, spacing: 22) {
          tapeLoadingOptions
            .frame(maxWidth: .infinity, alignment: .topLeading)

          rightColumn
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }

        Button("Reset Preferences", action: resetAction)
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .padding(18)
    }
  }

  private var topFields: some View {
    VStack(alignment: .leading, spacing: 12) {
      numberFieldRow(title: "Emulation speed:", value: $speed,
                     formatter: speedFormatter, suffix: "%")
      numberFieldRow(title: "Screen refresh rate (1:n):", value: $rate,
                     formatter: rateFormatter, suffix: nil)
    }
  }

  private var tapeLoadingOptions: some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 6) {
        Toggle("Use tape traps", isOn: $tapeTraps)
        Toggle("Fast tape loading", isOn: $fastLoad)
        Toggle("Accelerate tape loaders", isOn: $accelerateLoader)
        Toggle("Detect tape loaders", isOn: $detectLoader)

        HStack(alignment: .center, spacing: 10) {
          Text("Auto-load media")
            .frame(minWidth: 120, alignment: .leading)

          Picker(
            "Auto-load media",
            selection: enumeratedStringBinding(
              for: $phantomTypistMode,
              canonicalize: {
                canonicalOptionString(
                  $0,
                  enumerator: { cocoa_string_media_phantom_typist_mode_bridge( $0 ) },
                  fallback: phantomTypistModes[0]
                )
              }
            )
          ) {
            ForEach(phantomTypistModes, id: \.self) { mode in
              Text(mode).tag(mode)
            }
          }
          .labelsHidden()
          .pickerStyle(MenuPickerStyle())
          .frame(width: 123)
        }
        .padding(.top, 2)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
    } label: {
      Text("Tape Loading Options")
    }
  }

  private var rightColumn: some View {
    VStack(alignment: .leading, spacing: 8) {
      Toggle("Issue 2 keyboard", isOn: $issue2)
      Toggle("Late CPU timings", isOn: $lateTimings)
      Toggle("Z80 is CMOS", isOn: $z80IsCMOS)
      Toggle("Allow writes to ROM", isOn: $writableROMs)
      Toggle("Use .slt traps", isOn: $sltTraps)
      Toggle("Set joysticks on snapshot load", isOn: $joystickPrompt)
      Toggle("Show tape/disk status", isOn: $statusBar)
      Toggle("Confirm actions", isOn: $confirmActions)
    }
  }

  private func numberFieldRow<Value>(title: String, value: Binding<Value>,
                                     formatter: Formatter,
                                     suffix: String?) -> some View {
    HStack(spacing: 12) {
      fieldLabel( title )

      TextField(title, value: value, formatter: formatter)
        .textFieldStyle(.roundedBorder)
        .frame(width: 116)

      if let suffix {
        Text(suffix)
          .foregroundColor(.secondary)
      }
    }
  }

  private func fieldLabel(_ title: String) -> some View {
    Text(title)
      .frame(width: 210, alignment: .trailing)
  }

  private var speedFormatter: NumberFormatter {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimum = 1
    formatter.maximumFractionDigits = 0
    return formatter
  }

  private var rateFormatter: NumberFormatter {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimum = 1
    formatter.maximum = 50
    formatter.maximumFractionDigits = 3
    return formatter
  }
}
