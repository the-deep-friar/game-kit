import GameController

/// Every control the JS side knows, by position (docs/gamepad.md §3).
enum Control: String, CaseIterable {
  case south, east, west, north
  case leftShoulder, rightShoulder, leftTrigger, rightTrigger
  case leftStickButton, rightStickButton
  case dpadUp, dpadDown, dpadLeft, dpadRight
  case menu, options
}

/// Elements that have a picture but aren't buttons: the sticks and the d-pad as a whole.
enum GlyphElement {
  case control(Control)
  case leftStick, rightStick, dpad

  init?(_ name: String) {
    switch name {
    case "leftStick": self = .leftStick
    case "rightStick": self = .rightStick
    case "dpad": self = .dpad
    default:
      guard let control = Control(rawValue: name) else { return nil }
      self = .control(control)
    }
  }
}

/// How Apple's buttonA/B/X/Y sit on this pad.
enum FaceMapping {
  /// A = bottom, B = right, X = left, Y = top: Apple's model, and what we name by position.
  case positional
  /// A, B, X, Y are the buttons printed with those letters, which on a Nintendo pad sit at
  /// right, bottom, top and left. Swapped back to positions in `element(_:of:faces:)`.
  case nintendoLabels
}

struct PadInfo {
  let id: String
  let player: Int
  let name: String
  let productCategory: String
  let layout: String
  /// "full", or "singleJoyCon" for one Joy-Con on its own (held sideways: one stick, few buttons).
  let shape: String
  let facesSwapped: Bool
  let hasRumble: Bool

  var dictionary: [String: Any] {
    [
      "id": id, "player": player, "name": name, "productCategory": productCategory, "layout": layout,
      "shape": shape, "facesSwapped": facesSwapped, "hasRumble": hasRumble,
    ]
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
/// Apple defines by position (A = bottom). A Nintendo pad that arrives with its
/// letters in those slots instead is swapped back (`faces(of:)`), so south is
/// always the bottom button.
enum PadMapping {
  static func element(_ control: Control, of gamepad: GCExtendedGamepad, faces: FaceMapping) -> GCControllerElement? {
    switch (control, faces) {
    case (.south, .positional), (.east, .nintendoLabels): return gamepad.buttonA
    case (.east, .positional), (.south, .nintendoLabels): return gamepad.buttonB
    case (.west, .positional), (.north, .nintendoLabels): return gamepad.buttonX
    case (.north, .positional), (.west, .nintendoLabels): return gamepad.buttonY
    default: return nonFaceElement(control, of: gamepad)
    }
  }

  private static func nonFaceElement(_ control: Control, of gamepad: GCExtendedGamepad) -> GCControllerElement? {
    switch control {
    case .south, .east, .west, .north: return nil  // handled with the face mapping above
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

  static func element(_ glyph: GlyphElement, of gamepad: GCExtendedGamepad, faces: FaceMapping) -> GCControllerElement? {
    switch glyph {
    case .control(let control): return element(control, of: gamepad, faces: faces)
    case .leftStick: return gamepad.leftThumbstick
    case .rightStick: return gamepad.rightThumbstick
    case .dpad: return gamepad.dpad
    }
  }

  static func snapshot(of gamepad: GCExtendedGamepad, faces: FaceMapping) -> PadState {
    var state = PadState()
    for control in Control.allCases {
      guard let button = element(control, of: gamepad, faces: faces) as? GCControllerButtonInput else { continue }
      state.buttons[control] = ButtonState(down: button.isPressed, value: button.value)
    }
    state.leftStick = (gamepad.leftThumbstick.xAxis.value, gamepad.leftThumbstick.yAxis.value)
    state.rightStick = (gamepad.rightThumbstick.xAxis.value, gamepad.rightThumbstick.yAxis.value)
    return state
  }

  /// There are no GCProductCategory constants for Nintendo pads, so match on names.
  static func layout(of controller: GCController) -> String {
    let names = names(of: controller)
    if names.contains("switch") || names.contains("joy-con") || names.contains("joycon") || names.contains("nintendo") { return "nintendo" }
    if names.contains("xbox") { return "xbox" }
    if names.contains("dualsense") || names.contains("dualshock") { return "playstation" }
    return "other"
  }

  /// A Joy-Con on its own reports as "Joy-Con (L)" or "Joy-Con (R)"; a pair used together as
  /// "Joy-Con (L/R)", which is a full pad.
  static func shape(of controller: GCController) -> String {
    let names = names(of: controller)
    let joyCon = names.contains("joy-con") || names.contains("joycon")
    return joyCon && !names.contains("l/r") ? "singleJoyCon" : "full"
  }

  /// The face buttons' own pictures say which way a Nintendo pad arrived: if Apple's buttonA
  /// (the bottom button in its model) is drawn as "A", the letters came through by label and
  /// the bottom button is really buttonB. Without a picture, trust Apple's positions.
  static func faces(of controller: GCController, _ gamepad: GCExtendedGamepad) -> FaceMapping {
    guard layout(of: controller) == "nintendo", let symbol = gamepad.buttonA.sfSymbolsName else { return .positional }
    return symbol.hasPrefix("a.") ? .nintendoLabels : .positional
  }

  private static func names(of controller: GCController) -> String {
    "\(controller.productCategory) \(controller.vendorName ?? "")".lowercased()
  }
}
