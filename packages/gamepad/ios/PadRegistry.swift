import GameController

/// Tracks connected controllers, gives each a player slot, and keeps the
/// latest state of every control so `read()` can be answered from any thread.
///
/// GameController delivers connect/disconnect notifications and value changes
/// on the main queue; JS calls `pads()` and `read()` from its own thread. All
/// shared state sits behind `lock`.
final class PadRegistry {
  private let lock = NSLock()
  private var entries: [ObjectIdentifier: Entry] = [:]
  private var observers: [NSObjectProtocol] = []
  private var nextId = 1

  var onConnect: ((PadInfo) -> Void)?
  var onDisconnect: ((PadInfo) -> Void)?

  private final class Entry {
    let controller: GCController
    let info: PadInfo
    var state = PadState()
    init(controller: GCController, info: PadInfo) {
      self.controller = controller
      self.info = info
    }
  }

  func start() {
    let center = NotificationCenter.default
    observers = [
      center.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
        guard let controller = note.object as? GCController else { return }
        self?.connect(controller)
      },
      center.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] note in
        guard let controller = note.object as? GCController else { return }
        self?.disconnect(controller)
      },
    ]
    // Pads already paired and on when the app starts don't post a connect notification.
    DispatchQueue.main.async { [weak self] in
      GCController.controllers().forEach { self?.connect($0) }
    }
  }

  func stop() {
    observers.forEach { NotificationCenter.default.removeObserver($0) }
    observers = []
    onConnect = nil
    onDisconnect = nil
    lock.withLock { entries.removeAll() }
  }

  func pads() -> [PadInfo] {
    lock.withLock { entries.values.map(\.info).sorted { $0.player < $1.player } }
  }

  /// The pad's current state; clears its "pressed since last read" latches.
  func read(_ id: String) -> PadState? {
    lock.withLock {
      guard let entry = entries.values.first(where: { $0.info.id == id }) else { return nil }
      let state = entry.state
      entry.state.clearLatches()
      return state
    }
  }

  func glyph(_ id: String, _ control: Control) -> String? {
    let controller = lock.withLock { entries.values.first(where: { $0.info.id == id })?.controller }
    guard let gamepad = controller?.extendedGamepad else { return nil }
    return PadMapping.element(control, of: gamepad)?.sfSymbolsName
  }

  /// Lets go of every control, e.g. when the app goes to the background, so
  /// nothing reads as held when it comes back.
  func releaseAll() {
    lock.withLock { entries.values.forEach { $0.state = PadState() } }
  }

  private func connect(_ controller: GCController) {
    guard let gamepad = controller.extendedGamepad else { return }  // Siri Remote, keyboards, ...
    let info: PadInfo? = lock.withLock {
      let key = ObjectIdentifier(controller)
      guard entries[key] == nil else { return nil }
      let taken = Set(entries.values.map(\.info.player))
      guard let player = (1...4).first(where: { !taken.contains($0) }) else { return nil }
      let info = PadInfo(
        id: "pad-\(nextId)",
        player: player,
        name: controller.vendorName ?? controller.productCategory,
        layout: PadMapping.layout(of: controller),
        hasRumble: controller.haptics != nil
      )
      nextId += 1
      let entry = Entry(controller: controller, info: info)
      entry.state = PadMapping.snapshot(of: gamepad)
      entries[key] = entry
      return info
    }
    guard let info else { return }

    controller.playerIndex = GCControllerPlayerIndex(rawValue: info.player - 1) ?? .indexUnset
    gamepad.valueChangedHandler = { [weak self] gamepad, _ in
      self?.update(controller, from: gamepad)
    }
    onConnect?(info)
  }

  private func disconnect(_ controller: GCController) {
    let info = lock.withLock { entries.removeValue(forKey: ObjectIdentifier(controller))?.info }
    controller.extendedGamepad?.valueChangedHandler = nil
    if let info { onDisconnect?(info) }
  }

  private func update(_ controller: GCController, from gamepad: GCExtendedGamepad) {
    let next = PadMapping.snapshot(of: gamepad)
    lock.withLock {
      guard let entry = entries[ObjectIdentifier(controller)] else { return }
      entry.state.merge(next)
    }
  }
}

