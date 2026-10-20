import GameController
import GamepadCore

/// Reads controllers straight from GameController for a game loop that runs in Swift
/// (docs/swift-core.md): once a frame the game asks for `readings()`, each controller's buttons
/// down now, the buttons pressed since the last frame, its sticks, its slot and its shape, as
/// GamepadCore `PadReading`s. The game turns those into its actions (`PadActions.frame`).
/// Games whose loop runs in JS use the module's `read()` instead; both can run at once.
///
/// - **Latches.** Each button's own `pressedChangedHandler` (GameController calls it on the main
///   queue, for every change) sets a "pressed since last frame" flag, so a tap that's down and
///   up again between two frames still counts. `readings()` clears them. These latches are the
///   reader's own, apart from the ones `read()` clears for JS.
/// - **Slots** come from `controller.playerIndex`, which this package's `PadRegistry` sets when
///   the module starts (slot 1 → player 1, ...): the same slots JS sees as `Pad.player`. A pad
///   whose slot isn't set yet reads as slot 0.
/// - **It never touches a profile's `valueChangedHandler` or `playerIndex`**: `PadRegistry`
///   owns both. Only per-button handlers, which GameController keeps apart from the profile's.
/// - Face buttons are by position, with the Nintendo fix (`PadKind.faces`), as in `read()`.
///
/// Per frame it costs a look at ≤ 4 controllers' 16 buttons and 4 axes.
@MainActor
public final class PadReader {
  public static let shared = PadReader()

  private final class Entry {
    let id: String
    let controller: GCController
    let shape: PadShape
    let faces: PadKind.Faces
    /// Each control's element on this pad, worked out once.
    let buttons: [(PadControl, GCControllerButtonInput)]
    var latched: Set<PadControl> = []

    init(id: String, controller: GCController, pad: GCExtendedGamepad) {
      self.id = id
      self.controller = controller
      shape = PadMapping.shape(of: controller)
      let faces = PadMapping.faces(of: controller, pad)
      self.faces = faces
      buttons = PadControl.allCases.compactMap { control in PadMapping.button(control, of: pad, faces: faces).map { (control, $0) } }
    }
  }

  private var observers: [NSObjectProtocol] = []
  private var entries: [ObjectIdentifier: Entry] = [:]
  private var nextId = 1
  private var users = 0

  /// Where the reader's log lines go (connects, disconnects, and presses when `logPresses`).
  public var log: ((String) -> Void)?
  /// Log every press and let-go too (for a pad tester).
  public var logPresses = false

  public var running: Bool { !observers.isEmpty }

  public init() {}

  /// Starts reading. Counted: each `start()` needs its own `stop()`, so several views can hold it on.
  public func start() {
    users += 1
    guard !running else { return }
    let center = NotificationCenter.default
    observers = [
      center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
        guard let controller = note.object as? GCController else { return }
        MainActor.assumeIsolated { self?.attach(controller) }
      },
      center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] note in
        guard let controller = note.object as? GCController else { return }
        MainActor.assumeIsolated { self?.detach(controller) }
      },
    ]
    let pads = GCController.controllers()
    log?("pads: reader on, \(pads.count) connected")
    pads.forEach(attach)
  }

  public func stop() {
    users = max(0, users - 1)
    guard users == 0, running else { return }
    observers.forEach(NotificationCenter.default.removeObserver)
    observers = []
    for controller in entries.values.map(\.controller) { detach(controller) }
    log?("pads: reader off")
  }

  /// Every attached pad now, and the presses since the last call (which it clears).
  public func readings() -> [PadReading] {
    entries.values.sorted { $0.id < $1.id }.map { entry in
      let slot = Self.slot(of: entry.controller)
      guard let pad = entry.controller.extendedGamepad else { return PadReading(id: entry.id, slot: slot, shape: entry.shape, state: nil) }
      var down: Set<PadControl> = []
      for (control, button) in entry.buttons where button.isPressed { down.insert(control) }
      let state = PadState(
        down: down, pressed: entry.latched,
        leftStick: StickValue(x: Double(pad.leftThumbstick.xAxis.value), y: Double(pad.leftThumbstick.yAxis.value)),
        rightStick: StickValue(x: Double(pad.rightThumbstick.xAxis.value), y: Double(pad.rightThumbstick.yAxis.value)))
      entry.latched = []
      return PadReading(id: entry.id, slot: slot, shape: entry.shape, state: state)
    }
  }

  /// Drops every unread press (coming back to the game, or after letting everything go), so a
  /// button pressed while away doesn't fire.
  public func clearLatches() {
    for entry in entries.values { entry.latched = [] }
  }

  private static func slot(of controller: GCController) -> Int {
    controller.playerIndex == .indexUnset ? 0 : controller.playerIndex.rawValue + 1
  }

  private func name(_ controller: GCController) -> String {
    let slot = Self.slot(of: controller)
    return "\(controller.vendorName ?? "pad") (\(controller.productCategory), \(slot == 0 ? "no slot" : "slot \(slot)"))"
  }

  private func attach(_ controller: GCController) {
    let key = ObjectIdentifier(controller)
    guard entries[key] == nil else { return }
    guard let pad = controller.extendedGamepad else {
      log?("pads: \(name(controller)) has no extended gamepad, skipped")
      return
    }
    let entry = Entry(id: "gc-\(nextId)", controller: controller, pad: pad)
    nextId += 1
    entries[key] = entry
    log?("pads: \(name(controller)) connected as \(entry.id), \(entry.shape.rawValue), faces \(entry.faces)")
    for (control, button) in entry.buttons {
      button.pressedChangedHandler = { [weak self, weak entry] _, value, pressed in
        MainActor.assumeIsolated {
          guard let self, let entry else { return }
          if pressed { entry.latched.insert(control) }
          if self.logPresses {
            self.log?("pads: \(self.name(entry.controller)) \(control.rawValue) \(pressed ? "down" : "up") \(String(format: "%.2f", value))")
          }
        }
      }
    }
  }

  private func detach(_ controller: GCController) {
    guard let entry = entries.removeValue(forKey: ObjectIdentifier(controller)) else { return }
    for (_, button) in entry.buttons { button.pressedChangedHandler = nil }
    log?("pads: \(name(controller)) disconnected (\(entry.id))")
  }
}
