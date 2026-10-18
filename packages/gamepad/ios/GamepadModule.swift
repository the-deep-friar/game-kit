import ExpoModulesCore

/// game-kit's gamepad module (docs/gamepad.md). Native discovers controllers,
/// gives them player slots and keeps their latest state; TypeScript does dead
/// zones and mapping to game actions.
///
/// JS API (all synchronous):
///   pads()              connected pads, by player
///   read(id)            one pad's buttons and sticks, or null; clears its press latches
///   glyph(id, element)  SF Symbol name for that pad's control, stick or d-pad, or null
///   rumble(id, kind)    'tap' | 'thud' | 'buzz' (not yet: build step 5)
/// Events:
///   onConnect    pad
///   onDisconnect pad
public class GamepadModule: Module {
  private let registry = PadRegistry()

  public func definition() -> ModuleDefinition {
    Name("Gamepad")

    Events("onConnect", "onDisconnect")

    OnCreate {
      // The registry lets go of these in stop(), which breaks the module ↔ registry cycle.
      self.registry.onConnect = { pad in self.sendEvent("onConnect", pad.dictionary) }
      self.registry.onDisconnect = { pad in self.sendEvent("onDisconnect", pad.dictionary) }
      self.registry.start()
    }

    OnDestroy {
      self.registry.stop()
    }

    OnAppEntersBackground {
      self.registry.releaseAll()
    }

    Function("pads") { () -> [[String: Any]] in
      self.registry.pads().map(\.dictionary)
    }

    Function("read") { (id: String) -> [String: Any]? in
      self.registry.read(id)?.dictionary
    }

    Function("glyph") { (id: String, element: String) -> String? in
      guard let element = GlyphElement(element) else { return nil }
      return self.registry.glyph(id, element)
    }

    Function("rumble") { (_: String, _: String) in
    }
  }
}
