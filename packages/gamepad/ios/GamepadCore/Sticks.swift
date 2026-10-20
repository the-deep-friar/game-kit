import Foundation

/// A way a stick can point (input-actions' `StickDirection`).
public enum StickDirection: String, CaseIterable, Sendable, Hashable {
  case up, down, left, right
}

/// input-actions' `stickDirections`, worked out exactly as the TS does it (V8's `Math.hypot` and
/// `Math.round`), so a game moving from a JS loop to a native one gets the same directions at the
/// dead zone's edge and on the eighths' boundaries.
public enum Sticks {
  /// `DEFAULT_DEAD_ZONE`: how far a stick has to move before it counts. Worn sticks drift at rest.
  public static let defaultDeadZone = 0.3

  /// `EIGHT_WAYS`: from right, anticlockwise.
  static let eightWays: [[StickDirection]] = [
    [.right], [.up, .right], [.up], [.up, .left], [.left], [.down, .left], [.down], [.down, .right],
  ]

  /// None inside the dead zone, one along an axis, two on a diagonal. Each eighth of the circle
  /// is 45° wide, centred on its direction, so mostly right with a little up is just `[.right]`.
  public static func directions(_ stick: StickValue, deadZone: Double = defaultDeadZone) -> [StickDirection] {
    if jsHypot(stick.x, stick.y) <= deadZone { return [] }
    let eighth = Int(jsRound(atan2(stick.y, stick.x) / (Double.pi / 4)))
    return eightWays[(eighth + 8) % 8]
  }
}

/// `Math.hypot(x, y)` as V8 works it out (normalise by the larger, Kahan-sum the squares, then
/// `sqrt × max`), so the dead zone's edge falls exactly where it does in TS.
func jsHypot(_ a: Double, _ b: Double) -> Double {
  if a.isInfinite || b.isInfinite { return .infinity }
  if a.isNaN || b.isNaN { return .nan }
  let values = [abs(a), abs(b)]
  var top = 0.0
  for v in values where v > top { top = v }
  if top == 0 { return 0 }
  var sum = 0.0
  var compensation = 0.0
  for v in values {
    let n = v / top
    let summand = n * n - compensation
    let preliminary = sum + summand
    compensation = (preliminary - sum) - summand
    sum = preliminary
  }
  return sum.squareRoot() * top
}

/// `Math.round`: halves go up (towards +infinity), unlike Swift's `.rounded()`, which takes them
/// away from zero. `x - floor(x)` is exact for every double, so this is exact too.
func jsRound(_ x: Double) -> Double {
  guard x.isFinite else { return x }
  let down = x.rounded(.down)
  return x - down >= 0.5 ? down + 1 : down
}
