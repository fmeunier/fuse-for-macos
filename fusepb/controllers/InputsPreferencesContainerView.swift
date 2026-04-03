import AppKit
import SwiftUI

private let emulatedJoystickOptions = optionChoices(
  { cocoa_inputs_joysticks_bridge() },
  fallback: [
    "None",
    "Kempston",
    "Cursor",
  ]
)

private let realJoystickOptions = optionChoices(
  { cocoa_inputs_hid_joysticks_bridge() },
  fallback: [
    "None",
  ]
)

private enum InputsSetupTarget: Int {
  case joystick1 = 1
  case joystick2 = 2
}

@objc(InputsPreferencesContainerView)
@objcMembers
final class InputsPreferencesContainerView: NSView {
  private weak var setupTarget: AnyObject?
  private var setupAction: Selector?
  private var hostingView: NSHostingView<InputsPreferencesView>?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    installHostingView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    installHostingView()
  }

  @objc(configureWithSetupTarget:action:)
  func configure(setupTarget: AnyObject?, action: Selector) {
    self.setupTarget = setupTarget
    self.setupAction = action
    hostingView?.rootView = makeRootView()
  }

  private func installHostingView() {
    let hostingView = NSHostingView(rootView: makeRootView())
    hostingView.frame = bounds
    hostingView.autoresizingMask = [.width, .height]
    addSubview(hostingView)
    self.hostingView = hostingView
  }

  private func makeRootView() -> InputsPreferencesView {
    InputsPreferencesView { [weak self] target in
      self?.sendSetupAction(target)
    }
  }

  private func sendSetupAction(_ target: InputsSetupTarget) {
    guard let setupTarget = setupTarget as? NSObject, let setupAction else { return }

    let sender = NSButton()
    sender.tag = target.rawValue
    setupTarget.perform(setupAction, with: sender)
  }
}

private struct InputsPreferencesView: View {
  private let panelWidth: CGFloat = 630
  private let panelHeight: CGFloat = 397
  private let groupWidth: CGFloat = 481
  private let labelWidth: CGFloat = 122
  private let keyboardRowWidth: CGFloat = 452
  private let pickerToSetupSpacing: CGFloat = 6
  private let smallMenuWidth: CGFloat = 125
  private let largeMenuWidth: CGFloat = 239
  private let setupButtonWidth: CGFloat = 76

  @AppStorage("joystickkeyboardoutput") private var joystickKeyboardOutput = 0
  @AppStorage("joy1num") private var joy1Num = 0
  @AppStorage("joystick1output") private var joystick1Output = 0
  @AppStorage("joy2num") private var joy2Num = 0
  @AppStorage("joystick2output") private var joystick2Output = 0
  @AppStorage("interface2") private var interface2 = false
  @AppStorage("kempston") private var kempston = false
  @AppStorage("kempstonmouse") private var kempstonMouse = false
  @AppStorage("mouseswapbuttons") private var mouseSwapButtons = false

  private let setupAction: (InputsSetupTarget) -> Void

  init(setupAction: @escaping (InputsSetupTarget) -> Void) {
    self.setupAction = setupAction
  }

  var body: some View {
    CenteredPreferencesPane(width: panelWidth, height: panelHeight) {
      VStack(alignment: .leading, spacing: 6) {
        keyboardSection
          .frame(width: groupWidth, alignment: .leading)

        joystickSection(title: "Joystick 1", realSelection: $joy1Num,
                        emulatedSelection: $joystick1Output, setupTarget: .joystick1)
          .frame(width: groupWidth, alignment: .leading)

        joystickSection(title: "Joystick 2", realSelection: $joy2Num,
                        emulatedSelection: $joystick2Output, setupTarget: .joystick2)
          .frame(width: groupWidth, alignment: .leading)

        optionsSection
          .padding(.leading, 2)
      }
      .padding(.leading, 73)
      .padding(.top, 16)
      .padding(.trailing, 76)
      .padding(.bottom, 13)
      .frame(width: panelWidth, height: panelHeight, alignment: .topLeading)
      .flexibleButtonSizingIfAvailable()
    }
  }

  private var keyboardSection: some View {
    GroupBox("Keyboard") {
      HStack(spacing: 2) {
        rowLabel("Emulated joystick:")
        indexPicker(width: smallMenuWidth, options: emulatedJoystickOptions,
                    selection: $joystickKeyboardOutput)
        Spacer(minLength: 0)
      }
      .frame(width: keyboardRowWidth, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.leading, 13)
      .padding(.trailing, 16)
      .padding(.top, 10)
      .padding(.bottom, 11)
    }
    .frame(width: groupWidth, alignment: .leading)
  }

  private func joystickSection(title: String, realSelection: Binding<Int>,
                               emulatedSelection: Binding<Int>,
                               setupTarget: InputsSetupTarget) -> some View {
    GroupBox(title) {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 2) {
          rowLabel("Real device:")

          HStack(spacing: pickerToSetupSpacing) {
            indexPicker(width: largeMenuWidth, options: realJoystickOptions,
                        selection: realSelection)
            setupButton(setupTarget)
          }
        }

        HStack(spacing: 2) {
          rowLabel("Emulated joystick:")
          indexPicker(width: smallMenuWidth, options: emulatedJoystickOptions,
                      selection: emulatedSelection)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.leading, 17)
      .padding(.trailing, 16)
      .padding(.top, 8)
      .padding(.bottom, 10)
    }
    .frame(width: groupWidth, alignment: .leading)
  }

  private var optionsSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      Toggle("Interface 2", isOn: $interface2)
      Toggle("Kempston joystick interface", isOn: $kempston)

      HStack(alignment: .center, spacing: 18) {
        Toggle("Kempston mouse", isOn: $kempstonMouse)
        Toggle("Swap mouse buttons", isOn: $mouseSwapButtons)
      }
    }
  }

  private func indexPicker(width: CGFloat, options: [String], selection: Binding<Int>) -> some View {
    Picker("", selection: selection) {
      ForEach(Array(options.enumerated()), id: \.offset) { index, title in
        Text(title).tag(index)
      }
    }
    .labelsHidden()
    .pickerStyle(.menu)
    .frame(width: width, alignment: .leading)
  }

  private func rowLabel(_ title: String) -> some View {
    Text(title)
      .frame(width: labelWidth, alignment: .leading)
  }

  private func setupButton(_ target: InputsSetupTarget) -> some View {
    Button("Setup") {
      setupAction(target)
    }
    .frame(width: setupButtonWidth, alignment: .leading)
    .padding(.leading, pickerToSetupSpacing)
  }
}

private extension View {
  @ViewBuilder
  func flexibleButtonSizingIfAvailable() -> some View {
    if #available(macOS 26.0, *) {
      buttonSizing(.flexible)
    } else {
      self
    }
  }
}
