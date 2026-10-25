# gamepad — design

Status: **building** (0.4.1) · 2026-10-24

A small Expo native module that lets our games read physical game controllers
on iPad (and later iPhone / tvOS). First user: Charlie Craft roadmap 2.3, where
Charlie plays on the sofa with the game AirPlayed to the TV.

**tvOS** (0.4.1): both pods (`Gamepad`, `GamepadCore`) and the SwiftPM library declare tvOS 18,
so autolinking keeps them in a tvOS build. The Siri Remote is a `GCMicroGamepad` with no
extended gamepad: `PadRegistry` and `PadReader` skip it, so it never gets a player slot or
shows up in `pads()` / `readings()`. It still drives tvOS focus and the menu button as usual.

Controllers we actually own: Nintendo Switch Pro, Joy-Cons, one 8BitDo. Those
are the test devices; Xbox and PlayStation pads should work for free through
the same API but aren't tested until someone has one.

---

## 1. Goals

- Read every connected controller's buttons and sticks from the game loop, cheaply, every frame.
- Never miss a quick tap that starts and ends between two frames.
- Name buttons **by position** (south / east / west / north), so "jump is the
  bottom button" holds on Nintendo, Xbox and PlayStation layouts alike.
- Tell the game which picture to show for a button on *this* controller
  (Switch "B" vs Xbox "A") so on-screen hints match the pad in his hands.
- Players 1–4, with the player LEDs lit on controllers that have them.
- Connect / disconnect events, so the game can pause or swap to touch controls.
- Rumble for digs, hits and landings, where the controller supports it.

Not goals: keyboards/mice (maybe later, same shape), remapping UI, controller
navigation of normal app screens, Android.

## 2. Shape

```
packages/gamepad/
  expo-module.config.json      apple: GamepadModule; pods Gamepad + GamepadCore
  ios/GamepadCore/             plain-Swift pad logic, also the SwiftPM library (docs/swift-core.md)
  ios/GamepadCore.podspec      that folder as its own pod, module GamepadCore
  ios/Gamepad.podspec          everything else in ios/, depends on GamepadCore
  ios/GamepadModule.swift      Expo module definition: functions + events
  ios/PadRegistry.swift        tracks GCControllers, player slots, latches for JS read()
  ios/PadMapping.swift         GCExtendedGamepad → our controls and snapshots, via GamepadCore
  ios/PadReader.swift          per-frame readings for game loops in Swift (0.4.0)
  ios-tests/GamepadCoreTests/  swift test
  src/index.ts                 typed JS API (§3)
  src/use-gamepads.ts          React hook: connected pads, re-renders on connect/disconnect
```

Native does only what needs Apple APIs: discovery, reading values, latching
presses, LEDs, haptics. Everything else (dead zones, action mapping, which
pad is "player 1" in the game) is TypeScript, tested with jest, for games
whose loop runs in JS. Games whose loop runs in Swift (Charlie Craft and Jude
Craft since October 2026) use `PadReader` and GamepadCore instead: the same
rules in Swift, tested with `swift test` (docs/swift-core.md).

## 3. JS API

```ts
type Control =
  | 'south' | 'east' | 'west' | 'north'            // face buttons by position
  | 'leftShoulder' | 'rightShoulder'
  | 'leftTrigger' | 'rightTrigger'
  | 'leftStickButton' | 'rightStickButton'
  | 'dpadUp' | 'dpadDown' | 'dpadLeft' | 'dpadRight'
  | 'menu' | 'options';

type Pad = {
  id: string;                    // stable while connected
  player: 1 | 2 | 3 | 4;
  name: string;                  // "Pro Controller"
  productCategory: string;       // "Switch Pro Controller", "Joy-Con (L)" (0.3.0)
  layout: 'nintendo' | 'xbox' | 'playstation' | 'other';
  shape: 'full' | 'singleJoyCon'; // one Joy-Con alone, held sideways (0.3.0)
  facesSwapped: boolean;         // Nintendo letters arrived in Apple's A/B/X/Y slots and were swapped back (0.3.0)
  hasRumble: boolean;
};

type GlyphElement = Control | 'leftStick' | 'rightStick' | 'dpad';   // 0.3.0

type PadState = {
  buttons: Record<Control, { down: boolean; value: number; pressedSinceLastRead: boolean }>;
  leftStick: { x: number; y: number };             // -1..1, raw (dead zone applied in TS)
  rightStick: { x: number; y: number };
};

Gamepad.pads(): Pad[];                              // sync
Gamepad.read(id: string): PadState | null;          // sync, call once per frame
Gamepad.glyph(id: string, element: GlyphElement): string | null;   // SF Symbol name for this pad's button, stick or d-pad
Gamepad.rumble(id: string, kind: 'tap' | 'thud' | 'buzz'): void;
Gamepad.addListener('onConnect' | 'onDisconnect', (pad: Pad) => void);

useGamepads(): Pad[];
```

**Polling, not a stream of events.** The game loop already ticks every frame
(`useGameLoop` in Charlie Craft). A synchronous `read()` per frame through the
Expo module's JSI functions is simpler and more predictable than sending a
bridge event on every stick wiggle. Connect/disconnect are rare, so those are events.

**Latch for quick taps.** Native sets `pressedSinceLastRead` from the
`GCExtendedGamepad` value-changed handler and clears it on `read()`, so a tap
shorter than a frame still jumps.

## 4. Button positions and Nintendo pads

`GCExtendedGamepad.buttonA/B/X/Y` are positional in Apple's model (A = bottom,
B = right, X = left, Y = top), but whether a Switch controller arrives with
its *labels* or its *positions* mapped to those has to be checked on our
hardware; it may differ between the Pro Controller, a Joy-Con pair and an
8BitDo in different modes. Plan:

1. Build a tiny "pad tester" screen first (shows each control lighting up).
2. Press every button on each pad we own; record what arrives in `docs/pads.md`.
3. If a pad arrives label-mapped, `PadRegistry` swaps it back to positions.

**Built (0.3.0): the pad says which way it arrived.** Rather than a table of
product names, `PadKind.faces` (GamepadCore, 0.4.0; was `PadMapping.faces`) asks the pad itself when it connects: on a
Nintendo pad, if Apple's `buttonA` (bottom, in Apple's model) has the SF Symbol
`a.circle…`, the letters came through by label. Nintendo prints A on the right,
B at the bottom, X on top and Y on the left, so the module swaps back:
south ← `buttonB`, east ← `buttonA`, north ← `buttonX`, west ← `buttonY`.
If `buttonA` is drawn as B, or has no symbol, Apple's positions are kept.
Snapshots and glyphs both go through the same mapping, so `glyph(id, 'south')`
is the picture of the bottom button either way (`b.circle` on a Switch pad).
`Pad.facesSwapped` reports which happened, for the tester and `docs/pads.md`.
Non-Nintendo pads are never swapped.

Glyphs come from `GCControllerElement.sfSymbolsName` on the real element, so
they're right for each pad without our own table. `layout` is derived from
`productCategory` for anything that needs to know more.

**Joy-Cons.** A pair held together shows up as one combined controller. A
single Joy-Con held sideways is a small pad with fewer buttons (no right stick,
fewer shoulders); `read()` reports what's missing as never pressed, and the
game's action map should give everything a binding that works on one
Joy-Con (useful later for two players on one TV).

**Built (0.3.0):** `Pad.shape` is `'singleJoyCon'` when the product category
names a Joy-Con but not the pair (`Joy-Con (L)` / `Joy-Con (R)`, not
`Joy-Con (L/R)`), else `'full'`. Each single Joy-Con is its own controller with
its own player slot, so a split pair is two players with no extra work. Apps
pick a smaller binding map for that shape: the one stick, the four face
buttons and the side buttons (SL/SR, expected as the shoulders; to be
confirmed in `docs/pads.md`).

## 5. Info.plist and the system

The config plugin sets what the system needs to treat this as a game, not a
remote for the app's UI (exact keys verified against current Apple docs before
writing the plugin):

- `GCSupportsControllerUserInteraction` and `GCSupportedGameControllers`
  (`ExtendedGamepad`), so presses go to the game.
- Leave the Home / capture buttons to the system.
- `GCController.shouldMonitorBackgroundEvents` stays false; when the app
  backgrounds, `PadRegistry` releases everything so nothing stays held.

## 6. Input actions

Separate TS package, `packages/input-actions`: Charlie Craft's
`src/lib/input.ts` made generic over the action names.

**Status (2026-10-20):** for games whose loop runs in JS (Parlor, anything
new and simple). Charlie Craft and Jude Craft now run their loop in Swift and
read pads natively through GamepadCore's `Sticks` / `PadActions`, the same
rules ported; from this package they import only the `PadBindings` type, for
the HUD's copy of the bindings. Kept, not deprecated. No native code, no
dependency on `gamepad`; fully unit-tested.

**Built (0.2.0):** one `Input` per player, fed by any number of sources.

```ts
const ACTIONS = ['moveLeft', 'moveRight', 'jump', 'dig', 'place', 'nextTool', 'prevTool', 'craft'] as const;
const inputs = createInputs([1, 2], ACTIONS);   // { 1: Input, 2: Input }

// event-driven sources (touch buttons, a keyboard)
inputs[1].press('touch', 'jump');  inputs[1].release('touch', 'jump');
// polled sources (a pad, once per frame): what's down now, plus taps between polls
inputs[pad.player].set(`pad:${pad.id}`, heldActions, tappedActions);
inputs[2].releaseAll(`pad:${pad.id}`);          // on disconnect

// game loop, once per frame per player
const { held, pressed } = inputs[1].read();
held.moveLeft;      // down now, by any source: walk, swim, hold-to-dig
pressed.nextTool;   // true for exactly one read per press, even a tap shorter than a frame
axis(held, 'moveLeft', 'moveRight');            // -1 | 0 | 1
stickDirections(state.leftStick);               // [] | ['up'] | ['up', 'right'] ..., dead zone 0.3
```

An action is held while any source holds it. A press is counted when a source
newly holds an action (`press`, or newly in `set`'s held list) or reports a
tap (`set`'s third argument, from the pad's `pressedSinceLastRead`); `read()`
clears them, and `releaseAll` drops a source's unread ones.

**Built (0.3.0, with Charlie Craft 2.3):** an action map turning a pad snapshot
into `set()`'s two lists, on top of `stickDirections`. It lives here, not in
`gamepad`, typed by shape (`PadSnapshot`: `buttons` with `down` and
`pressedSinceLastRead`, `leftStick`, `rightStick`), so neither package depends
on the other: `gamepad`'s `PadState` fits it as is.

```ts
const bindings: PadBindings<Action, Control> = {
  jump: ['south'], dig: ['rightTrigger'], place: ['leftTrigger'],
  moveLeft: [{ stick: 'leftStick', dir: 'left' }, 'dpadLeft'], ...
};
padActions(Gamepad.read(pad.id), bindings);       // { held: ['jump'], pressed: ['jump'] }
applyGamepad(inputs[pad.player], `pad:${pad.id}`, Gamepad.read(pad.id), bindings);
```

- An action is held while **any** of its bindings is: a button `down`, or a
  stick pushed that way (diagonals hold both ways, dead zone 0.3 or the one given).
- It's pressed when any of its buttons has `pressedSinceLastRead`. Sticks have
  no latch; a newly pushed direction counts as a press through `set()`.
- Buttons a snapshot lacks are never down, so a map may name controls a small
  pad doesn't have.
- `applyGamepad(input, source, null, ...)` (the pad has gone) is `releaseAll(source)`.
- The map itself (which button does what) belongs to the game, not here.

## 7. How apps get it — decided: A (public repo)

The release build runs `npm ci` then `eas build --local` on the self-hosted
Mac runner, checking out only the app repo (the-deep-friar/ios-ci
`ios-build.yml`). EAS cloud builds are the fallback. A private git dependency
needs credentials in all of those places.

| Option | Build setup | Dev loop | Notes |
|---|---|---|---|
| **A. Public repo**, git dependency pinned to a tag | none | `npm link` / `file:` override while developing | Simplest. Nothing secret in a gamepad module |
| **B. Private repo + vendoring**: a script copies a tagged package into the app's `modules/` and commits it | none | edit in place, sync back | No install-time fetch. Copies again, but scripted and versioned |
| C. Private repo, git dependency | SSH key or token on the runner and in EAS secrets | as A | Most setup; breaks EAS fallback until done |
| D. GitHub Packages (private npm) | `NODE_AUTH_TOKEN` on runner + EAS + every dev machine | publish per change | Most ceremony |

**Decided 2026-10-17: A.** The repo is public. Plain npm can't point a git
dependency at a subfolder of a monorepo, so each release publishes packed
tarballs as GitHub release assets and apps install those
(`npm i https://github.com/the-deep-friar/game-kit/releases/download/gamepad-v0.1.0/game-kit-gamepad-0.1.0.tgz`),
which pins exactly and needs no credentials anywhere.

## 8. Build order

| # | What | Done when |
|---|---|---|
| 1 | ✅ Settle §7; package skeleton, CI (typecheck + jest) | Charlie Craft installs it and builds on the runner |
| 2 | 🔨 Native discovery + `pads()` + connect events + pad tester screen (gamepad 0.2.0, Charlie Craft About tab) | Pro Controller and 8BitDo show up with player LEDs |
| 3 | 🔨 `read()` with latches (0.2.0); record real mappings in [`docs/pads.md`](pads.md); fix-ups | Every button on every pad we own lights the right control |
| 4 | 🔨 `input-actions` package: held + pressed per player, stick directions (0.2.0); Charlie Craft's input moved onto it (its 2.2) | Touch still works; jest green |
| 5 | 🔨 Glyphs for every control, stick and the d-pad (gamepad 0.3.0); Nintendo face fix from the pad's own glyphs; single Joy-Con shape. Rumble still to do | On-screen hints show Switch letters with a Switch pad |
| 6 | 🔨 Action map (`padActions` / `applyGamepad`, input-actions 0.3.0); Charlie Craft 2.3: bindings per player. Hiding touch controls is Charlie Craft 2.6 | Charlie plays a whole session from the sofa |
| 7 | 🔨 Swift pad core: GamepadCore (SwiftPM + pod) and `PadReader` (gamepad 0.4.0), so the native engines stop copying `PadMapping` ([swift-core.md](swift-core.md)) | Charlie Craft and Jude Craft build against it; CraftCore's tests still pass |
