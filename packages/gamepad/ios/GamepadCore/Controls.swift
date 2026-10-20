/// GamepadCore: the game-agnostic part of reading a pad, in plain Swift (no GameController, no
/// UIKit), so it builds and tests on Linux (docs/swift-core.md). The `Gamepad` pod's native code
/// and the apps' engines both use it; nothing here knows any game's actions.

/// Every control a pad reports, by position: south is the bottom face button on every layout.
/// Same names and order as `CONTROLS` in @game-kit/gamepad.
public enum PadControl: String, CaseIterable, Sendable, Hashable {
  case south, east, west, north
  case leftShoulder, rightShoulder, leftTrigger, rightTrigger
  case leftStickButton, rightStickButton
  case dpadUp, dpadDown, dpadLeft, dpadRight
  case menu, options
}

/// The two analog sticks.
public enum PadStick: String, CaseIterable, Sendable, Hashable {
  case leftStick, rightStick
}

/// A stick's raw position: -1...1 each way, up and right positive, no dead zone applied.
public struct StickValue: Equatable, Sendable {
  public var x: Double
  public var y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }

  public static let rest = StickValue(x: 0, y: 0)
}

/// One pad this frame (input-actions' `PadSnapshot`): the buttons down now, the buttons that went
/// down since the last frame (even if already up again), and the sticks.
public struct PadState: Equatable, Sendable {
  public var down: Set<PadControl>
  public var pressed: Set<PadControl>
  public var leftStick: StickValue
  public var rightStick: StickValue

  public init(down: Set<PadControl> = [], pressed: Set<PadControl> = [], leftStick: StickValue = .rest, rightStick: StickValue = .rest) {
    self.down = down
    self.pressed = pressed
    self.leftStick = leftStick
    self.rightStick = rightStick
  }

  public func stick(_ stick: PadStick) -> StickValue {
    stick == .leftStick ? leftStick : rightStick
  }
}

/// One controller as a frame reader saw it: a stable id, its player slot (1–4, from
/// GameController's `playerIndex`; 0 while unset), its shape, and its state (nil: it has gone).
public struct PadReading: Equatable, Sendable {
  public var id: String
  public var slot: Int
  public var shape: PadShape
  public var state: PadState?

  public init(id: String, slot: Int, shape: PadShape, state: PadState?) {
    self.id = id
    self.slot = slot
    self.shape = shape
    self.state = state
  }
}
