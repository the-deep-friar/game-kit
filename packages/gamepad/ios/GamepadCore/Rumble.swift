/// One rumble for a pad to play (`PadReader.rumble`): how hard, how crisp, how long, and which
/// hand feels it. Plain numbers, so a game's rules can pick rumbles (and be tested) with no
/// controller there.
public struct PadRumble: Hashable, Sendable {
  /// Which grip it plays in. A pad with one motor, or none per hand, plays every side in both.
  public enum Side: String, CaseIterable, Sendable {
    case both, left, right
  }

  /// 0...1: how hard.
  public var intensity: Double
  /// 0...1: dull and heavy (0) to crisp and light (1).
  public var sharpness: Double
  /// Seconds. 0 is a single tick, the shortest a pad can make.
  public var duration: Double
  public var side: Side

  public init(intensity: Double, sharpness: Double, duration: Double = 0, side: Side = .both) {
    self.intensity = min(1, max(0, intensity))
    self.sharpness = min(1, max(0, sharpness))
    self.duration = max(0, duration)
    self.side = side
  }

  /// A light, crisp tick: a hit landed, a menu moved.
  public static let tap = PadRumble(intensity: 0.4, sharpness: 0.9)
  /// A short heavy knock: a landing, a blow taken.
  public static let thud = PadRumble(intensity: 0.8, sharpness: 0.2, duration: 0.12)
  /// A longer hum: something big going on.
  public static let buzz = PadRumble(intensity: 0.6, sharpness: 0.5, duration: 0.35)
}
