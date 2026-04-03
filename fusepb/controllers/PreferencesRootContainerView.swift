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
  private var peripheralsHostingView: NSHostingView<AnyView>?
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
    activeHostingView?.fittingSize ?? super.fittingSize
  }

  @objc(configureWithController:machineRomsController:)
  func configure(controller: NSObject?, machineRomsController: NSArrayController?) {
    self.controller = controller
    self.machineRomsController = machineRomsController
    romModel.configure(machineRomsController: machineRomsController)
    updateRootView()
  }

  @objc(schedulePeripheralsWarmup)
  func schedulePeripheralsWarmup() {
    DispatchQueue.main.async { [weak self] in
      self?.warmPeripheralsHostingView()
    }
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

  private var activeHostingView: NSHostingView<AnyView>? {
    selectedPane == .peripherals ? peripheralsHostingView : hostingView
  }

  private func installHostingView() {
    let hostingView = NSHostingView(rootView: makeRootView(for: selectedPane))
    hostingView.frame = bounds
    hostingView.autoresizingMask = [.width, .height]
    addSubview(hostingView)
    self.hostingView = hostingView
  }

  private func warmPeripheralsHostingView() {
    guard peripheralsHostingView == nil else { return }

    let hostingView = NSHostingView(rootView: makePeripheralsRootView())
    hostingView.frame = bounds
    hostingView.autoresizingMask = [.width, .height]
    hostingView.isHidden = true
    addSubview(hostingView)
    hostingView.layoutSubtreeIfNeeded()
    peripheralsHostingView = hostingView
  }

  private func updateRootView() {
    if selectedPane == .peripherals {
      warmPeripheralsHostingView()
      hostingView?.isHidden = true
      peripheralsHostingView?.isHidden = false
      peripheralsHostingView?.layoutSubtreeIfNeeded()
    } else {
      hostingView?.rootView = makeRootView(for: selectedPane)
      hostingView?.isHidden = false
      peripheralsHostingView?.isHidden = true
      hostingView?.layoutSubtreeIfNeeded()
    }

    layoutSubtreeIfNeeded()
  }

  private func makeRootView(for pane: PreferencesPaneIdentifier) -> AnyView {
    let paneView: AnyView

    switch pane {
    case .general:
      paneView = generalPreferencesPane { [weak self] in
        self?.sendAction("resetUserDefaults:")
      }
    case .sound:
      paneView = soundPreferencesPane()
    case .peripherals:
      paneView = makePeripheralsPaneView()
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
          self?.updateMeasuredHeight(height, for: pane)
        }
    )
  }

  private func makePeripheralsPaneView() -> AnyView {
    peripheralsPreferencesPane { [weak self] tag in
      self?.sendAction("chooseFile:", tag: tag)
    }
  }

  private func makePeripheralsRootView() -> AnyView {
    makeRootView(for: .peripherals)
  }

  private func updateMeasuredHeight(_ height: CGFloat, for pane: PreferencesPaneIdentifier) {
    guard height > 0 else { return }

    let roundedHeight = ceil(height)
    let currentHeight = measuredPaneHeights[pane] ?? pane.fallbackContentHeight
    guard abs(currentHeight - roundedHeight) > 0.5 else { return }

    measuredPaneHeights[pane] = roundedHeight
    guard pane == selectedPane else { return }

    DispatchQueue.main.async { [weak self] in
      self?.sendAction("applyPreferredPaneSize")
    }
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
