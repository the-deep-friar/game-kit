# game-kit

Shared game modules for our own Expo iOS apps: Charlie Craft, Jude Craft (a
fork of Charlie Craft sharing its engine), Parlor and whatever comes next.
Built for us: no npm publishing, no support for setups we don't use.

| Package | What | Status |
|---|---|---|
| `packages/gamepad` (`@game-kit/gamepad`) | Expo native module: game controllers via Apple's GameController framework; `PadReader` for game loops in Swift | working: discovery, player slots, buttons and sticks, glyphs, Nintendo face fix; rumble to do. Design: [docs/gamepad.md](docs/gamepad.md) |
| `GamepadCore` (Swift, in `packages/gamepad/ios/GamepadCore`) | Plain-Swift pad logic, no GameController: controls by position, layout/shape, Nintendo face fix, stick directions, action maps. A SwiftPM library (root `Package.swift`) and a pod in the gamepad tarball | working; used by Charlie Craft and Jude Craft's native engine. Design: [docs/swift-core.md](docs/swift-core.md) |
| `packages/input-actions` (`@game-kit/input-actions`) | TypeScript: many input sources (touch, gamepad, keyboard) → one set of held actions per player, with once-per-press presses; pad action maps | working, for games whose loop runs in JS (Parlor). Charlie Craft and Jude Craft read pads in Swift through GamepadCore and only use its `PadBindings` type. Design: [docs/gamepad.md §6](docs/gamepad.md#6-input-actions) |

Rule: a module moves in here when it's built for reuse on purpose (gamepad) or
when a second app actually needs it. No speculative extraction.

## Using a package in an app

Each release is a tarball on a GitHub release; no registry, no credentials.

```bash
npm i https://github.com/the-deep-friar/game-kit/releases/download/gamepad-v0.1.0/game-kit-gamepad-0.1.0.tgz
```

Native packages autolink like any Expo module; rebuild the dev client after adding one.

### The Swift core

In the iOS app, `@game-kit/gamepad` brings the `GamepadCore` pod along (autolinked); a native
pod of the app's that uses it adds `s.dependency 'GamepadCore'` (and `'Gamepad'` for
`PadReader`) and does `import GamepadCore`. An engine core that also builds with SwiftPM (say,
tested on Linux) depends on this repo by git URL at the same version:

```swift
.package(url: "https://github.com/the-deep-friar/game-kit.git", exact: "0.4.0"),
// target: dependencies: [.product(name: "GamepadCore", package: "game-kit")]
```

Same sources, same module name, so `import GamepadCore` works in both builds. Keep the npm and
SwiftPM versions equal. Step by step for the Craft apps: [docs/swift-core.md §4](docs/swift-core.md#4-moving-charlie-craft--jude-craft-onto-it).

## Developing

```bash
npm ci
npm run ci        # lint, typecheck, test, build — same as GitHub Actions
npm run test:swift   # GamepadCore's swift test (GitHub Actions runs it on Linux)
```

To try a change in an app before releasing: `npm pack -w packages/<name>` here,
then `npm i ../game-kit/game-kit-<name>-<version>.tgz` in the app.

## Releasing

Bump `version` in `packages/<name>/package.json`, merge, then push a tag
`<name>-v<version>` (e.g. `gamepad-v0.1.0`). `release.yml` checks the versions
match, runs the full CI, packs and attaches the tarball to a GitHub release.

A gamepad release also bumps `s.version` in both podspecs and gets a second, bare semver tag
on the same commit for SwiftPM (which ignores tags like `gamepad-v0.4.0`):

```bash
git tag gamepad-v0.4.0 && git tag 0.4.0 && git push origin gamepad-v0.4.0 0.4.0
```

`release.yml` checks a bare tag equals `packages/gamepad`'s version and runs `swift test`.
Bare semver tags belong to gamepad alone; other packages never use them.
