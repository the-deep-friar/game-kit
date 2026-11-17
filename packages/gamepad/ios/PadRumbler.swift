import CoreHaptics
import GameController
import GamepadCore

/// One controller's rumble (`PadReader.rumble`): a CoreHaptics engine per grip, made the first
/// time that grip is asked for and started again whenever the system stops it (the app went to
/// the background, the pad slept).
///
/// - A pad with no haptics (the Siri Remote, many MFi pads, the simulator) plays nothing.
/// - A side the pad can't play alone (`left`, `right`) plays in the whole pad.
/// - The first rumble starts the engine and plays as soon as it's up, unless that took longer
///   than `late`: a tick that comes late is worse than none.
@MainActor
final class PadRumbler {
  /// Only ever touched on the main queue (its engine's handlers hop there first).
  private final class Motor: @unchecked Sendable {
    let engine: CHHapticEngine
    var running = false
    var starting = false
    var players: [PadRumble: CHHapticPatternPlayer] = [:]
    var waiting: (rumble: PadRumble, since: CFTimeInterval)?

    init(_ engine: CHHapticEngine) { self.engine = engine }
  }

  /// A rumble that waited on the engine longer than this isn't played.
  static let late = 0.15
  /// Kept players (one per rumble asked for); past this the oldest all go.
  static let kept = 32

  private let haptics: GCDeviceHaptics
  private var motors: [GCHapticsLocality: Motor] = [:]
  private var dead: Set<GCHapticsLocality> = []
  var log: ((String) -> Void)?

  init?(_ controller: GCController) {
    guard let haptics = controller.haptics else { return nil }
    self.haptics = haptics
  }

  func play(_ rumble: PadRumble) {
    guard let motor = motor(for: rumble.side) else { return }
    guard motor.running else {
      motor.waiting = (rumble, CACurrentMediaTime())
      start(motor)
      return
    }
    do {
      try player(for: rumble, in: motor).start(atTime: CHHapticTimeImmediate)
    } catch {
      // The engine went away under us: start afresh on the next rumble.
      motor.running = false
      motor.players = [:]
      log?("pads: rumble failed (\(error.localizedDescription))")
    }
  }

  private func locality(_ side: PadRumble.Side) -> GCHapticsLocality {
    let wanted: GCHapticsLocality = switch side {
    case .both: .default
    case .left: .leftHandle
    case .right: .rightHandle
    }
    return haptics.supportedLocalities.contains(wanted) ? wanted : .default
  }

  private func motor(for side: PadRumble.Side) -> Motor? {
    let place = locality(side)
    if let motor = motors[place] { return motor }
    guard !dead.contains(place) else { return nil }
    guard let engine = haptics.createEngine(withLocality: place) else {
      dead.insert(place)
      log?("pads: no rumble engine for \(place.rawValue)")
      return nil
    }
    let motor = Motor(engine)
    engine.playsHapticsOnly = true
    // Both come on CoreHaptics' own queue.
    engine.stoppedHandler = { [weak motor] _ in
      DispatchQueue.main.async {
        motor?.running = false
        motor?.players = [:]
      }
    }
    engine.resetHandler = { [weak motor] in
      DispatchQueue.main.async {
        motor?.running = false
        motor?.players = [:]
      }
    }
    motors[place] = motor
    return motor
  }

  private func start(_ motor: Motor) {
    guard !motor.starting else { return }
    motor.starting = true
    motor.engine.start { [weak self, weak motor] error in
      DispatchQueue.main.async {
        guard let motor else { return }
        motor.starting = false
        motor.running = error == nil
        if let error { self?.log?("pads: rumble engine didn't start (\(error.localizedDescription))") }
        guard error == nil, let waiting = motor.waiting else { return }
        motor.waiting = nil
        if CACurrentMediaTime() - waiting.since <= Self.late { self?.play(waiting.rumble) }
      }
    }
  }

  private func player(for rumble: PadRumble, in motor: Motor) throws -> CHHapticPatternPlayer {
    if let player = motor.players[rumble] { return player }
    let parameters = [
      CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(rumble.intensity)),
      CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(rumble.sharpness)),
    ]
    let event = rumble.duration > 0
      ? CHHapticEvent(eventType: .hapticContinuous, parameters: parameters, relativeTime: 0, duration: rumble.duration)
      : CHHapticEvent(eventType: .hapticTransient, parameters: parameters, relativeTime: 0)
    let player = try motor.engine.makePlayer(with: CHHapticPattern(events: [event], parameters: []))
    if motor.players.count >= Self.kept { motor.players = [:] }
    motor.players[rumble] = player
    return player
  }
}
