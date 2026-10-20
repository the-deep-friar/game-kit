# Swift pad core

Status: **built** (gamepad 0.4.0) · 2026-10-20

Charlie Craft (and Jude Craft, its fork on the same engine) moved the game loop to native Swift
in October 2026 and read pads there, which copied game-kit's pad logic into the app. This puts
the game-agnostic part back here, once, in two layers:

| Layer | Module | Where | Depends on | Tested |
|---|---|---|---|---|
| Pad logic | `GamepadCore` | `packages/gamepad/ios/GamepadCore/` | Foundation only | `swift test` (Linux CI + Mac) |
| Native reading | `Gamepad` (the Expo module pod) | `packages/gamepad/ios/*.swift` | GameController, ExpoModulesCore, GamepadCore | on device |

## 1. GamepadCore

Plain Swift, no GameController or UIKit, so an engine core that builds and tests on Linux can
depend on it.

- `PadControl`: the 16 controls by position, `CONTROLS`' names and order.
- `PadStick`, `StickValue`, `PadState` (down, pressed since last frame, sticks),
  `PadReading` (id, slot, shape, state) for one controller in one frame.
- `PadLayout`, `PadShape`, and `PadKind`: layout and shape from `productCategory` /
  `vendorName`, the **Nintendo face fix** (`PadKind.faces`, from `buttonA`'s SF Symbol name), and
  `PadKind.appleButton(for:faces:)`, which of Apple's buttonA/B/X/Y is each face control.
- `StickDirection` and `Sticks.directions`: input-actions' `stickDirections`, with V8's
  `Math.hypot` / `Math.round`, so it gives the same answer as the TS at the dead zone's edge.
- `PadBinding` and `PadActions.frame`: input-actions' `padActions` over any game's `Action`
  type, giving a `PadActionFrame<Action>` (held, pressed).

Not here: any game's actions, bindings tables, player feeds (Charlie Craft's `PadFeed`), menus.

## 2. Native reading (the `Gamepad` pod)

- `PadRegistry` / `GamepadModule`: the JS API (docs/gamepad.md §3), unchanged. Now built on
  GamepadCore: the Nintendo fix and shape/layout detection exist only in `PadKind`.
- `PadReader` (public, `@MainActor`, `PadReader.shared`): for a game loop running in Swift.
  Once a frame `readings()` gives every controller's `PadReading`, with its own per-button
  latches (taps between frames count) and slots from the `playerIndex` that `PadRegistry` sets.
  It never touches `valueChangedHandler` or `playerIndex`, so it runs alongside the JS module.
  `log` takes the app's logger; `logPresses` adds every press and let-go.

`PadReader` lives here rather than in the app because nothing in it is about one game: it is
"GameController → latched `PadState` per frame", and it depends on `PadRegistry`'s contract
(who owns `playerIndex` and the profile handler), which is easier to keep in one repo.

## 3. How apps get it

The same Swift sources reach both builds:

- **CocoaPods (the iOS app).** The `@game-kit/gamepad` tarball ships
  `ios/GamepadCore.podspec` next to `ios/Gamepad.podspec`; `expo-module.config.json` lists
  both (`podspecPath`), so autolinking adds both pods. The `GamepadCore` pod's module is
  `GamepadCore`, so `import GamepadCore` means the same thing as under SwiftPM.
- **SwiftPM (an engine core tested on Linux).** The repo-root `Package.swift` declares the
  `GamepadCore` library from the same folder. SwiftPM only reads the manifest and the target
  paths, so the npm workspace around it doesn't matter. SwiftPM needs semver tags, so each
  gamepad release also gets a bare tag equal to its version (README "Releasing").

Keep the two pins equal: the gamepad tarball version in `package.json` and the SwiftPM
`exact:` version in the engine's `Package.swift`.

## 4. Moving Charlie Craft / Jude Craft onto it

From `charliecraft` (and the same in Jude Craft), against gamepad 0.4.0 / SwiftPM `0.4.0`.
Paths are under `modules/craft-engine/ios/`.

1. **package.json**: `@game-kit/gamepad` →
   `https://github.com/the-deep-friar/game-kit/releases/download/gamepad-v0.4.0/game-kit-gamepad-0.4.0.tgz`,
   then `npm install`. `@game-kit/input-actions` stays at 0.3.0.
2. **CraftCore/Package.swift**:
   ```swift
   dependencies: [.package(url: "https://github.com/the-deep-friar/game-kit.git", exact: "0.4.0")],
   targets: [
     .target(name: "CraftCore", dependencies: [.product(name: "GamepadCore", package: "game-kit")]),
     .testTarget(name: "CraftCoreTests", dependencies: ["CraftCore", .product(name: "GamepadCore", package: "game-kit")], resources: [.copy("Fixtures")]),
   ],
   ```
   Committing the generated `Package.resolved` is optional; `exact:` pins either way, and the
   pod only takes `*.swift`.
3. **CraftEngine.podspec**: add `s.dependency 'GamepadCore'` and `s.dependency 'Gamepad'`
   (for `PadReader`). Nothing else changes; CraftCore's sources still compile into the pod.
4. **CraftCore/Sources/CraftCore/Pads.swift**: add `import GamepadCore`; delete `PadControl`,
   `StickValue`, `PadState`, `Sticks` (with `eightWays`), `jsHypot`, `PadReading` and `PadKind`.
   Keep `PadFeed` and keep `Bindings.actions` as a wrapper:
   ```swift
   public static func actions(_ pad: PadState, _ bindings: [Action: [PadBinding]], deadZone: Double = deadZone) -> Frame {
     let frame = PadActions.frame(pad, bindings, deadZone: deadZone)
     return Frame(held: frame.held, pressed: frame.pressed)
   }
   ```
   (`jsRound` in Blocks.swift stays; GamepadCore's copy is internal.)
5. **CraftCore/Sources/CraftCore/Bindings.swift**: add `import GamepadCore`; delete the local
   `PadBinding` and `PadShape` enums (GamepadCore's have the same cases, typed);
   `left`/`right` take a `StickDirection` and return `.stick(.leftStick, dir)` /
   `.stick(.rightStick, dir)`; every `.button("south")` becomes `.button(.south)`;
   `deadZone = Sticks.defaultDeadZone` (0.3, as before).
6. **Tests**: `import GamepadCore` in InputTests.swift and Piece5TablesTests.swift. In
   InputTests drop the `jsHypot` test (game-kit tests it) and compare `PadKind.layout` to
   `.nintendo` / `.xbox` / `.playstation` / `.other`. In Piece5TablesTests encode
   `.button(let control)` as `J(control.rawValue)` and the stick as `J(stick.rawValue)`.
   The fixtures don't change (`StickDirection`'s raw values are `MenuCommand`'s).
7. **Input/PadReader.swift**: delete it. Add `import Gamepad` to the files that use
   `PadReader` (CraftEngineModule.swift, CraftWorldView.swift, Render2D/WorldScene.swift) and
   `import GamepadCore` to every file outside CraftCore naming its types (CraftSession.swift:
   `PadShape`, `PadReading`; WorldScene.swift if it names any). Hook the log up once, before the
   first `start()` (e.g. in `CraftEngineModule`'s `OnCreate`):
   `PadReader.shared.log = { EngineLog.line($0) }`. The API is the old one: `shared`, `start()`,
   `stop()`, `readings()`, `clearLatches()`, `logPresses`, `running`.
8. Check: `npm run test:swift` (CraftCore against the game-kit tag) and a dev-client build
   (`pod install` picks up GamepadCore from the tarball).

Steps 2 and 4–6 were tried against a local copy of CraftCore with
`.package(path: "../game-kit")` in place of the URL: all 94 CraftCore tests pass, including the
1,500-case stick fixture.
