/// What can hold an action (input-actions' `PadBinding`): a button, or a stick pushed one way
/// (by `Sticks.directions`, so a diagonal holds both of its ways).
public enum PadBinding: Equatable, Sendable, Hashable {
  case button(PadControl)
  case stick(PadStick, StickDirection)
}

/// One pad's frame as actions, ready for a game's per-player input.
public struct PadActionFrame<Action: Hashable & Sendable>: Equatable, Sendable {
  public var held: Set<Action>
  public var pressed: Set<Action>

  public init(held: Set<Action> = [], pressed: Set<Action> = []) {
    self.held = held
    self.pressed = pressed
  }
}

public enum PadActions {
  /// input-actions' `padActions`, over any game's action type. An action is held while any of its
  /// buttons is down or any of its stick directions is pushed; pressed when any of its buttons
  /// went down since the last frame (sticks have no latch: a newly pushed direction becomes a
  /// press in the game's input, as `Input.set` does in TS). Controls a pad lacks are never down,
  /// so one map can name controls a smaller pad doesn't have. Which button does what is the game's.
  public static func frame<Action>(
    _ pad: PadState, _ bindings: [Action: [PadBinding]], deadZone: Double = Sticks.defaultDeadZone
  ) -> PadActionFrame<Action> {
    let left = Sticks.directions(pad.leftStick, deadZone: deadZone)
    let right = Sticks.directions(pad.rightStick, deadZone: deadZone)
    var frame = PadActionFrame<Action>()
    for (action, list) in bindings {
      for binding in list {
        switch binding {
        case .button(let control):
          if pad.down.contains(control) { frame.held.insert(action) }
          if pad.pressed.contains(control) { frame.pressed.insert(action) }
        case .stick(let stick, let dir):
          if (stick == .leftStick ? left : right).contains(dir) { frame.held.insert(action) }
        }
      }
    }
    return frame
  }
}
