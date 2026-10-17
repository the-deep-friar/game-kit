import GameController

/// Every control the JS side knows, by position (docs/gamepad.md §3).
enum Control: String, CaseIterable {
  case south, east, west, north
  case leftShoulder, rightShoulder, leftTrigger, rightTrigger
  case leftStickButton, rightStickButton
  case dpadUp, dpadDown, dpadLeft, dpadRight
  case menu, options
}

struct PadInfo {
  let id: String
  let player: Int
  let name: String
  let layout: String
  let hasRumble: Bool

  var dictionary: [String: Any] {
    ["id": id, "player": player, "name": name, "layout": layout, "hasRumble": hasRumble]
  }
}

struct ButtonState {
  var down = false
  var value: Float = 0
  var pressedSinceLastRead = false
}

struct PadState {
  var buttons: [Control: ButtonState] = [:]
  var leftStick = (x: Float(0), y: Float(0))
  var rightStick = (x: Float(0), y: Float(0))

  /// Takes the newest values, keeping any press latched since the last read.
  mutating func merge(_ next: PadState) {
    for control in Control.allCases {
      let was = buttons[control] ?? ButtonState()
      var now = next.buttons[control] ?? ButtonState()
      now.pressedSinceLastRead = was.pressedSinceLastRead || (now.down && !was.down)
      buttons[control] = now
    }
    leftStick = next.leftStick
    rightStick = next.rightStick
  }

  mutating func clearLatches() {
    for control in Control.allCases {
      buttons[control]?.pressedSinceLastRead = false
    }
  }

  var dictionary: [String: Any] {
    var buttonDicts: [String: Any] = [:]
    for control in Control.allCases {
      let button = buttons[control] ?? ButtonState()
      buttonDicts[control.rawValue] = [
        "down": button.down, "value": button.value, "pressedSinceLastRead": button.pressedSinceLastRead,
      ]
    }
    return [
      "buttons": buttonDicts,
      "leftStick": ["x": leftStick.x, "y": leftStick.y],
      "rightStick": ["x": rightStick.x, "y": rightStick.y],
    ]
  }
}

/// GameController → our names. Face buttons use Apple's buttonA/B/X/Y, which
/// Apple defines by position (A = bottom). Whether Nintendo pads arrive that
/// way is checked with the pad tester before anything is swapped here.
enum PadMapping {
  static func element(_ control: Control, of gamepad: GCExtendedGamepad) -> GCControllerElement? {
    switch control {
    case .south: return gamepad.buttonA
    case .east: return gamepad.buttonB
    case .west: return gamepad.buttonX
    case .north: return gamepad.buttonY
    case .leftShoulder: return gamepad.leftShoulder
    case .rightShoulder: return gamepad.rightShoulder
    case .leftTrigger: return gamepad.leftTrigger
    case .rightTrigger: return gamepad.rightTrigger
    case .leftStickButton: return gamepad.leftThumbstickButton
    case .rightStickButton: return gamepad.rightThumbstickButton
    case .dpadUp: return gamepad.dpad.up
    case .dpadDown: return gamepad.dpad.down
    case .dpadLeft: return gamepad.dpad.left
    case .dpadRight: return gamepad.dpad.right
    case .menu: return gamepad.buttonMenu
    case .options: return gamepad.buttonOptions
    }
  }

  static func snapshot(of gamepad: GCExtendedGamepad) -> PadState {
    var state = PadState()
    for control in Control.allCases {
      guard let button = element(control, of: gamepad) as? GCControllerButtonInput else { continue }
      state.buttons[control] = ButtonState(down: button.isPressed, value: button.value)
    }
    state.leftStick = (gamepad.leftThumbstick.xAxis.value, gamepad.leftThumbstick.yAxis.value)
    state.rightStick = (gamepad.rightThumbstick.xAxis.value, gamepad.rightThumbstick.yAxis.value)
    return state
  }

  /// There are no GCProductCategory constants for Nintendo pads, so match on names.
  static func layout(of controller: GCController) -> String {
    let names = "\(controller.productCategory) \(controller.vendorName ?? "")".lowercased()
    if names.contains("switch") || names.contains("joy-con") || names.contains("nintendo") { return "nintendo" }
    if names.contains("xbox") { return "xbox" }
    if names.contains("dualsense") || names.contains("dualshock") { return "playstation" }
    return "other"
  }
}
