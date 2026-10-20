import GameController
import GamepadCore

/// Elements that have a picture but aren't buttons: the sticks and the d-pad as a whole.
enum GlyphElement {
  case control(PadControl)
  case leftStick, rightStick, dpad

  init?(_ name: String) {
    switch name {
    case "leftStick": self = .leftStick
    case "rightStick": self = .rightStick
    case "dpad": self = .dpad
    default:
      guard let control = PadControl(rawValue: name) else { return nil }
      self = .control(control)
    }
  }
}

struct PadInfo {
  let id: String
  let player: Int
  let name: String
  let productCategory: String
  let layout: PadLayout
  let shape: PadShape
  let facesSwapped: Bool
  let hasRumble: Bool

  var dictionary: [String: Any] {
    [
      "id": id, "player": player, "name": name, "productCategory": productCategory, "layout": layout.rawValue,
      "shape": shape.rawValue, "facesSwapped": facesSwapped, "hasRumble": hasRumble,
    ]
  }
}

struct ButtonState {
  var down = false
  var value: Float = 0
  var pressedSinceLastRead = false
}

/// What JS's `read()` gets: every button with its analog value and latch, and the sticks.
struct PadSnapshot {
  var buttons: [PadControl: ButtonState] = [:]
  var leftStick = (x: Float(0), y: Float(0))
  var rightStick = (x: Float(0), y: Float(0))

  /// Takes the newest values, keeping any press latched since the last read.
  mutating func merge(_ next: PadSnapshot) {
    for control in PadControl.allCases {
      let was = buttons[control] ?? ButtonState()
      var now = next.buttons[control] ?? ButtonState()
      now.pressedSinceLastRead = was.pressedSinceLastRead || (now.down && !was.down)
      buttons[control] = now
    }
    leftStick = next.leftStick
    rightStick = next.rightStick
  }

  mutating func clearLatches() {
    for control in PadControl.allCases {
      buttons[control]?.pressedSinceLastRead = false
    }
  }

  var dictionary: [String: Any] {
    var buttonDicts: [String: Any] = [:]
    for control in PadControl.allCases {
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

/// GameController → our names. What kind of pad it is and which way its face letters arrived
/// is GamepadCore's `PadKind` (the Nintendo fix lives there, once); this only fetches the
/// strings it needs and the elements it picks.
enum PadMapping {
  static func layout(of controller: GCController) -> PadLayout {
    PadKind.layout(productCategory: controller.productCategory, vendorName: controller.vendorName)
  }

  static func shape(of controller: GCController) -> PadShape {
    PadKind.shape(productCategory: controller.productCategory, vendorName: controller.vendorName)
  }

  static func faces(of controller: GCController, _ gamepad: GCExtendedGamepad) -> PadKind.Faces {
    PadKind.faces(productCategory: controller.productCategory, vendorName: controller.vendorName, buttonASymbol: gamepad.buttonA.sfSymbolsName)
  }

  /// The button that is `control` on this pad, by position: south is always the bottom button.
  static func button(_ control: PadControl, of gamepad: GCExtendedGamepad, faces: PadKind.Faces) -> GCControllerButtonInput? {
    if let face = PadKind.appleButton(for: control, faces: faces) {
      switch face {
      case .a: return gamepad.buttonA
      case .b: return gamepad.buttonB
      case .x: return gamepad.buttonX
      case .y: return gamepad.buttonY
      }
    }
    switch control {
    case .south, .east, .west, .north: return nil  // face buttons, answered above
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

  static func element(_ glyph: GlyphElement, of gamepad: GCExtendedGamepad, faces: PadKind.Faces) -> GCControllerElement? {
    switch glyph {
    case .control(let control): return button(control, of: gamepad, faces: faces)
    case .leftStick: return gamepad.leftThumbstick
    case .rightStick: return gamepad.rightThumbstick
    case .dpad: return gamepad.dpad
    }
  }

  static func snapshot(of gamepad: GCExtendedGamepad, faces: PadKind.Faces) -> PadSnapshot {
    var state = PadSnapshot()
    for control in PadControl.allCases {
      guard let button = button(control, of: gamepad, faces: faces) else { continue }
      state.buttons[control] = ButtonState(down: button.isPressed, value: button.value)
    }
    state.leftStick = (gamepad.leftThumbstick.xAxis.value, gamepad.leftThumbstick.yAxis.value)
    state.rightStick = (gamepad.rightThumbstick.xAxis.value, gamepad.rightThumbstick.yAxis.value)
    return state
  }
}
