/// Which family a pad belongs to, from GameController's names. Same raw values as `Pad.layout`.
public enum PadLayout: String, CaseIterable, Sendable {
  case nintendo, xbox, playstation, other
}

/// A pad's shape, as `Pad.shape` reports it: a full pad, or one Joy-Con on its own held sideways
/// (one stick, the face buttons, SL/SR and a few others).
public enum PadShape: String, CaseIterable, Sendable {
  case full
  case singleJoyCon
}

/// One of Apple's four face buttons, `GCExtendedGamepad.buttonA/B/X/Y`.
public enum AppleFaceButton: Sendable {
  case a, b, x, y
}

/// What kind of pad a controller is, from GameController's strings (docs/gamepad.md §4): its
/// layout, a lone Joy-Con's shape, and which way a Nintendo pad's face letters arrived. Callers
/// pass `controller.productCategory`, `controller.vendorName` and
/// `extendedGamepad.buttonA.sfSymbolsName`.
public enum PadKind {
  /// How Apple's buttonA/B/X/Y sit on this pad.
  public enum Faces: Sendable {
    /// A = bottom, B = right, X = left, Y = top: Apple's model, and the positions we name.
    case positional
    /// A, B, X, Y are the buttons printed with those letters, which on a Nintendo pad sit at
    /// right, bottom, top and left: the bottom button is buttonB, and so on.
    case nintendoLabels
  }

  static func names(_ productCategory: String, _ vendorName: String?) -> String {
    "\(productCategory) \(vendorName ?? "")".lowercased()
  }

  /// There are no GCProductCategory constants for Nintendo pads, so this matches on names.
  public static func layout(productCategory: String, vendorName: String?) -> PadLayout {
    let names = names(productCategory, vendorName)
    if names.contains("switch") || names.contains("joy-con") || names.contains("joycon") || names.contains("nintendo") { return .nintendo }
    if names.contains("xbox") { return .xbox }
    if names.contains("dualsense") || names.contains("dualshock") { return .playstation }
    return .other
  }

  /// One Joy-Con on its own is "Joy-Con (L)" or "Joy-Con (R)"; a pair used together,
  /// "Joy-Con (L/R)", is a full pad.
  public static func shape(productCategory: String, vendorName: String?) -> PadShape {
    let names = names(productCategory, vendorName)
    let joyCon = names.contains("joy-con") || names.contains("joycon")
    return joyCon && !names.contains("l/r") ? .singleJoyCon : .full
  }

  /// The Nintendo face fix. The pad's own pictures say which way it arrived: if Apple's buttonA
  /// (the bottom button in its model) is drawn as "A", the letters came through by label. Without
  /// a picture, or on any other layout, Apple's positions are trusted.
  public static func faces(productCategory: String, vendorName: String?, buttonASymbol: String?) -> Faces {
    guard layout(productCategory: productCategory, vendorName: vendorName) == .nintendo, let symbol = buttonASymbol else { return .positional }
    return symbol.hasPrefix("a.") ? .nintendoLabels : .positional
  }

  /// Which of Apple's face buttons is `control` on a pad whose faces arrived this way; nil for
  /// anything that isn't a face button.
  public static func appleButton(for control: PadControl, faces: Faces) -> AppleFaceButton? {
    switch (control, faces) {
    case (.south, .positional), (.east, .nintendoLabels): return .a
    case (.east, .positional), (.south, .nintendoLabels): return .b
    case (.west, .positional), (.north, .nintendoLabels): return .x
    case (.north, .positional), (.west, .nintendoLabels): return .y
    default: return nil
    }
  }
}
