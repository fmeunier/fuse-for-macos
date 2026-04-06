import Foundation

@_silgen_name("cocoa_joystick_configuration_key_titles")
private func cocoaJoystickConfigurationKeyTitlesBridge() -> Unmanaged<AnyObject>?

@_silgen_name("cocoa_joystick_configuration_key_values")
private func cocoaJoystickConfigurationKeyValuesBridge() -> Unmanaged<AnyObject>?

struct JoystickConfigurationOption: Identifiable, Hashable {
  let title: String
  let value: Int

  var id: Int { value }
}

struct JoystickConfigurationButton: Identifiable, Hashable {
  let number: Int

  var id: Int { number }
  var title: String { "Button \(number):" }
}

enum JoystickConfigurationTarget: Int, CaseIterable, Identifiable {
  case joystick1 = 1
  case joystick2 = 2

  var id: Int { rawValue }
  var xAxisDefaultsKey: String { "joy\(rawValue)x" }
  var yAxisDefaultsKey: String { "joy\(rawValue)y" }

  func fireDefaultsKey(for button: JoystickConfigurationButton) -> String {
    "joystick\(rawValue)fire\(button.number)"
  }
}

struct JoystickConfigurationState: Equatable {
  static let buttonCount = 15

  let target: JoystickConfigurationTarget
  var xAxis: Int
  var yAxis: Int
  var fireButtons: [Int]

  init(target: JoystickConfigurationTarget,
       xAxis: Int = 0,
       yAxis: Int = 1,
       fireButtons: [Int] = Array(
         repeating: joystickConfigurationDefaultFireValue,
         count: JoystickConfigurationState.buttonCount
       )) {
    self.target = target
    self.xAxis = xAxis
    self.yAxis = yAxis
    self.fireButtons = Self.normalizedFireButtons(fireButtons)
  }

  func fireButtonValue(for button: JoystickConfigurationButton) -> Int {
    let index = button.number - 1
    guard index >= 0, index < fireButtons.count else {
      return joystickConfigurationDefaultFireValue
    }

    return fireButtons[index]
  }

  mutating func setFireButtonValue(_ value: Int, for button: JoystickConfigurationButton) {
    let index = button.number - 1
    guard index >= 0, index < fireButtons.count else { return }

    fireButtons[index] = value
  }

  func defaultsValues() -> [String: NSNumber] {
    var values: [String: NSNumber] = [
      target.xAxisDefaultsKey: NSNumber(value: xAxis),
      target.yAxisDefaultsKey: NSNumber(value: yAxis)
    ]

    for button in joystickConfigurationButtons {
      values[target.fireDefaultsKey(for: button)] = NSNumber(value: fireButtonValue(for: button))
    }

    return values
  }

  private static func normalizedFireButtons(_ values: [Int]) -> [Int] {
    if values.count == buttonCount {
      return values
    }

    if values.count > buttonCount {
      return Array(values.prefix(buttonCount))
    }

    return values + Array(
      repeating: joystickConfigurationDefaultFireValue,
      count: buttonCount - values.count
    )
  }
}

let joystickConfigurationButtons =
  (1...JoystickConfigurationState.buttonCount).map(JoystickConfigurationButton.init)

let joystickAxisOptions =
  (0..<15).map { JoystickConfigurationOption(title: "\($0)", value: $0) }

let joystickConfigurationKeyOptions = makeJoystickConfigurationKeyOptions()

private let joystickConfigurationDefaultFireValue = 4096

private func makeJoystickConfigurationKeyOptions() -> [JoystickConfigurationOption] {
  guard let titles = cocoaJoystickConfigurationKeyTitlesBridge()?.takeUnretainedValue() as? [String],
        let values = cocoaJoystickConfigurationKeyValuesBridge()?.takeUnretainedValue() as? [NSNumber] else {
    return [JoystickConfigurationOption(title: "Joystick Fire",
                                        value: joystickConfigurationDefaultFireValue)]
  }

  return zip(titles, values).map {
    JoystickConfigurationOption(title: $0.0, value: $0.1.intValue)
  }
}
