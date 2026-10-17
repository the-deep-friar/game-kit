import ExpoModulesCore

/// game-kit's gamepad module (docs/gamepad.md). Step 1 of the build order: the
/// JS surface exists and links into an app, but no controllers are discovered
/// yet. Discovery, `read()` and latches arrive in steps 2–3.
///
/// JS API (all synchronous):
///   pads()              connected pads
///   read(id)            one pad's buttons and sticks, or null
///   glyph(id, control)  SF Symbol name for that pad's control, or null
///   rumble(id, kind)    'tap' | 'thud' | 'buzz'
/// Events:
///   onConnect    pad
///   onDisconnect pad
public class GamepadModule: Module {
  public func definition() -> ModuleDefinition {
    Name("Gamepad")

    Events("onConnect", "onDisconnect")

    Function("pads") { () -> [[String: Any]] in
      []
    }

    Function("read") { (_: String) -> [String: Any]? in
      nil
    }

    Function("glyph") { (_: String, _: String) -> String? in
      nil
    }

    Function("rumble") { (_: String, _: String) in
    }
  }
}
