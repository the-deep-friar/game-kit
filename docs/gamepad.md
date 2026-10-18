# gamepad — design

Status: **proposed** · 2026-10-17

A small Expo native module that lets our games read physical game controllers
on iPad (and later iPhone / tvOS). First user: Charlie Craft roadmap 2.3, where
Charlie plays on the sofa with the game AirPlayed to the TV.

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
  expo-module.config.json      apple: GamepadModule
  app.plugin.js                Info.plist keys (§5)
  ios/GamepadModule.swift      Expo module definition: functions + events
  ios/PadRegistry.swift        tracks GCControllers, player slots, latches
  ios/PadSnapshot.swift        GCExtendedGamepad → snapshot record
  src/index.ts                 typed JS API (§3)
  src/use-gamepads.ts          React hook: connected pads, re-renders on connect/disconnect
  src/testing.ts               fake native module for app-side jest tests
```

Native does only what needs Apple APIs: discovery, reading values, latching
presses, LEDs, haptics. Everything else (dead zones, action mapping, which
pad is "player 1" in the game) is TypeScript, tested with jest.

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
  layout: 'nintendo' | 'xbox' | 'playstation' | 'other';
  hasRumble: boolean;
};

type PadState = {
  buttons: Record<Control, { down: boolean; value: number; pressedSinceLastRead: boolean }>;
  leftStick: { x: number; y: number };             // -1..1, raw (dead zone applied in TS)
  rightStick: { x: number; y: number };
};

Gamepad.pads(): Pad[];                              // sync
Gamepad.read(id: string): PadState | null;          // sync, call once per frame
Gamepad.glyph(id: string, control: Control): string | null;   // SF Symbol name for this pad's button
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
3. If a pad arrives label-mapped, `PadRegistry` swaps it back to positions,
   keyed by `GCController.productCategory`.

Glyphs come from `GCControllerElement.sfSymbolsName` on the real element, so
they're right for each pad without our own table. `layout` is derived from
`productCategory` for anything that needs to know more.

**Joy-Cons.** A pair held together shows up as one combined controller. A
single Joy-Con held sideways is a small pad with fewer buttons (no right stick,
fewer shoulders); `read()` reports what's missing as never pressed, and the
game's action map should give everything a binding that works on one
Joy-Con (useful later for two players on one TV).

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
`src/lib/input.ts` made generic over the action names. No native code, no
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

**Next (with Charlie Craft 2.3):** an action map turning a pad snapshot into
`set()`'s two lists, on top of `stickDirections`:

```ts
const bindings = { jump: ['south'], dig: ['rightTrigger'], place: ['leftTrigger'],
                   moveLeft: [{ stick: 'left', dir: 'left' }], ... };
applyGamepad(inputs[pad.player], `pad:${pad.id}`, Gamepad.read(pad.id), bindings);
```

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
| 5 | Glyphs + rumble | On-screen hints show Switch letters with a Switch pad |
| 6 | Charlie Craft 2.3: bindings, hide touch controls while a pad is connected | Charlie plays a whole session from the sofa |
