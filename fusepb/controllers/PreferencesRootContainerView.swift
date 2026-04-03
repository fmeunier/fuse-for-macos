import AppKit
import SwiftUI

private enum PreferencesPaneIdentifier: String {
  case general = "General"
  case sound = "Sound"
  case peripherals = "Peripherals"
  case recording = "Recording"
  case inputs = "Inputs"
  case rom = "ROM"
  case machine = "Machine"
  case video = "Video"

  var fallbackContentHeight: CGFloat {
    switch self {
    case .general:
      336
    case .sound:
      302
    case .peripherals:
      585
    case .recording:
      172
    case .inputs:
      397
    case .rom:
      343
    case .machine:
      390
    case .video:
      296
    }
  }
}

@objc(PreferencesRootContainerView)
@objcMembers
final class PreferencesRootContainerView: NSView {
  private weak var controller: NSObject?
  private weak var machineRomsController: NSArrayController?
  private let romModel = ROMPreferencesModel()
  private var selectedPane: PreferencesPaneIdentifier = .general
  private var hostingView: NSHostingView<AnyView>?
  private var measuredPaneHeights: [PreferencesPaneIdentifier: CGFloat] = [:]

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    installHostingView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    installHostingView()
  }

  override var fittingSize: NSSize {
    hostingView?.fittingSize ?? super.fittingSize
  }

  @objc(configureWithController:machineRomsController:)
  func configure(controller: NSObject?, machineRomsController: NSArrayController?) {
    self.controller = controller
    self.machineRomsController = machineRomsController
    romModel.configure(machineRomsController: machineRomsController)
    updateRootView()
  }

  @objc(selectPaneWithIdentifier:)
  func selectPane(withIdentifier identifier: NSString) {
    selectedPane = PreferencesPaneIdentifier(rawValue: identifier as String) ?? .general
    updateRootView()
  }

  @objc(preferredPaneSize)
  func preferredPaneSize() -> NSSize {
    NSSize(width: 0, height: measuredPaneHeights[selectedPane] ?? selectedPane.fallbackContentHeight)
  }

  private func installHostingView() {
    let hostingView = NSHostingView(rootView: makeRootView())
    hostingView.frame = bounds
    hostingView.autoresizingMask = [.width, .height]
    addSubview(hostingView)
    self.hostingView = hostingView
  }

  private func updateRootView() {
    hostingView?.rootView = makeRootView()
    layoutSubtreeIfNeeded()
  }

  private func makeRootView() -> AnyView {
    let paneView: AnyView

    switch selectedPane {
    case .general:
      paneView = generalPreferencesPane { [weak self] in
        self?.sendAction("resetUserDefaults:")
      }
    case .sound:
      paneView = soundPreferencesPane()
    case .peripherals:
      paneView = peripheralsPreferencesPane { [weak self] tag in
        self?.sendAction("chooseFile:", tag: tag)
      }
    case .recording:
      paneView = recordingPreferencesPane()
    case .inputs:
      paneView = inputsPreferencesPane { [weak self] tag in
        self?.sendAction("setup:", tag: tag)
      }
    case .rom:
      paneView = romPreferencesPane(
        model: romModel,
        chooseROM: { [weak self] tag in
          self?.sendAction("chooseROMFile:", tag: tag, refreshROMSelection: true)
        },
        resetROM: { [weak self] tag in
          self?.sendAction("resetROMFile:", tag: tag, refreshROMSelection: true)
        }
      )
    case .machine:
      paneView = machinePreferencesPane()
    case .video:
      paneView = videoPreferencesPane()
    }

    return AnyView(
      paneView
        .onPreferenceChange(PreferencesPaneHeightKey.self) { [weak self] height in
          self?.updateMeasuredHeight(height)
        }
    )
  }

  private func updateMeasuredHeight(_ height: CGFloat) {
    guard height > 0 else { return }

    let roundedHeight = ceil(height)
    let currentHeight = measuredPaneHeights[selectedPane] ?? selectedPane.fallbackContentHeight
    guard abs(currentHeight - roundedHeight) > 0.5 else { return }

    measuredPaneHeights[selectedPane] = roundedHeight
    sendAction("applyPreferredPaneSize")
  }

  private func sendAction(_ selectorName: String, tag: Int? = nil,
                          refreshROMSelection: Bool = false) {
    guard let controller else { return }

    let selector = NSSelectorFromString(selectorName)
    if let tag {
      let sender = NSButton()
      sender.tag = tag
      controller.perform(selector, with: sender)
    } else {
      NSApp.sendAction(selector, to: controller, from: self)
    }

    if refreshROMSelection {
      romModel.refreshSelection()
    }
  }
}
