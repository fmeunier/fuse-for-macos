import AppKit
import SwiftUI

@objcMembers
final class JoystickConfigurationEditorModel: NSObject, ObservableObject {
  @Published var state = JoystickConfigurationState(target: .joystick1)

  func configure(targetNumber: NSNumber, xAxis: NSNumber, yAxis: NSNumber, fireValues: [NSNumber]) {
    let target = JoystickConfigurationTarget(rawValue: targetNumber.intValue) ?? .joystick1
    state = JoystickConfigurationState(
      target: target,
      xAxis: xAxis.intValue,
      yAxis: yAxis.intValue,
      fireButtons: fireValues.map(\.intValue)
    )
  }

  func defaultsValues() -> NSDictionary {
    state.defaultsValues() as NSDictionary
  }

  func selectedXAxisValue() -> NSNumber {
    NSNumber(value: state.xAxis)
  }

  func selectedYAxisValue() -> NSNumber {
    NSNumber(value: state.yAxis)
  }

  func selectedFireValues() -> [NSNumber] {
    state.fireButtons.map { NSNumber(value: $0) }
  }
}

@objc(JoystickConfigurationContainerView)
@objcMembers
final class JoystickConfigurationContainerView: NSView {
  private let model = JoystickConfigurationEditorModel()
  private var hostingView: NSHostingView<AnyView>?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    installHostingView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    installHostingView()
  }

  @objc(configureForTargetNumber:xAxis:yAxis:fireValues:)
  func configure(targetNumber: NSNumber, xAxis: NSNumber, yAxis: NSNumber, fireValues: [NSNumber]) {
    model.configure(targetNumber: targetNumber, xAxis: xAxis, yAxis: yAxis, fireValues: fireValues)
    hostingView?.layoutSubtreeIfNeeded()
    hostingView?.displayIfNeeded()
  }

  @objc(defaultsValues)
  func defaultsValues() -> NSDictionary {
    model.defaultsValues()
  }

  @objc(selectedXAxisValue)
  func selectedXAxisValue() -> NSNumber {
    model.selectedXAxisValue()
  }

  @objc(selectedYAxisValue)
  func selectedYAxisValue() -> NSNumber {
    model.selectedYAxisValue()
  }

  @objc(selectedFireValues)
  func selectedFireValues() -> [NSNumber] {
    model.selectedFireValues()
  }

  private func installHostingView() {
    let hostingView = NSHostingView(rootView: AnyView(rootView))
    hostingView.frame = bounds
    hostingView.autoresizingMask = [.width, .height]
    addSubview(hostingView)
    self.hostingView = hostingView
  }

  private var rootView: some View {
    JoystickConfigurationPaneView(model: model)
  }
}

private struct JoystickConfigurationPaneView: View {
  private let panelWidth: CGFloat = 696
  private let panelHeight: CGFloat = 312
  private let labelWidth: CGFloat = 75
  private let pickerWidth: CGFloat = 125
  private let buttonWidth: CGFloat = 84

  @ObservedObject private var model: JoystickConfigurationEditorModel

  init(model: JoystickConfigurationEditorModel) {
    self.model = model
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      buttonGrid

      axisSection

      buttonRowPlaceholder
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(.horizontal, 17)
    .padding(.top, 18)
    .padding(.bottom, 24)
    .frame(width: panelWidth, height: panelHeight, alignment: .topLeading)
    .flexibleButtonSizingIfAvailable()
  }

  private var buttonGrid: some View {
    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
      ForEach(0..<5, id: \.self) { row in
        GridRow {
          ForEach(0..<3, id: \.self) { column in
            let button = button(forRow: row, column: column)
            pickerRow(label: button.title, selection: fireButtonBinding(for: button))
              .gridCellAnchor(.leading)
          }
        }
      }
    }
  }

  private var axisSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      axisRow(label: "X Axis:", selection: axisBinding(\.xAxis))
      axisRow(label: "Y Axis:", selection: axisBinding(\.yAxis))
    }
  }

  private func pickerRow(label: String, selection: Binding<Int>) -> some View {
    HStack {
      Text(label)
        .frame(width: labelWidth, alignment: .leading)

      selectionMenu(options: joystickConfigurationKeyOptions, selection: selection)
    }
  }

  private func axisRow(label: String, selection: Binding<Int>) -> some View {
    HStack {
      Text(label)
        .frame(width: labelWidth, alignment: .leading)

      selectionMenu(options: joystickAxisOptions, selection: selection)
    }
  }

  private func selectionMenu(options: [JoystickConfigurationOption], selection: Binding<Int>) -> some View {
    Menu {
      ForEach(options) { option in
        Button {
          selection.wrappedValue = option.value
        } label: {
          if option.value == selection.wrappedValue {
            Label(option.title, systemImage: "checkmark")
          } else {
            Text(option.title)
          }
        }
      }
    } label: {
      Text(selectedTitle(for: selection.wrappedValue, in: options))
        .lineLimit(1)
        .truncationMode(.tail)
      .frame(width: pickerWidth, alignment: .leading)
    }
    .frame(width: pickerWidth, alignment: .leading)
  }

  private var buttonRowPlaceholder: some View {
    HStack(spacing: 8) {
      Color.clear
        .frame(width: buttonWidth, height: 32)

      Color.clear
        .frame(width: buttonWidth, height: 32)
    }
  }

  private func selectedTitle(for value: Int, in options: [JoystickConfigurationOption]) -> String {
    options.first(where: { $0.value == value })?.title ?? options.first?.title ?? ""
  }

  private func button(forRow row: Int, column: Int) -> JoystickConfigurationButton {
    joystickConfigurationButtons[row + (column * 5)]
  }

  private func fireButtonBinding(for button: JoystickConfigurationButton) -> Binding<Int> {
    Binding {
      model.state.fireButtonValue(for: button)
    } set: { newValue in
      model.state.setFireButtonValue(newValue, for: button)
    }
  }

  private func axisBinding(_ keyPath: WritableKeyPath<JoystickConfigurationState, Int>) -> Binding<Int> {
    Binding {
      model.state[keyPath: keyPath]
    } set: { newValue in
      model.state[keyPath: keyPath] = newValue
    }
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
