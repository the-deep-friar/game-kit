# game-kit

Shared game modules for our own Expo iOS apps (Charlie Craft first, then
Parlor and whatever comes next). Built for us: no npm publishing, no support
for setups we don't use.

| Package | What | Status |
|---|---|---|
| `packages/gamepad` (`@game-kit/gamepad`) | Expo native module: game controllers via Apple's GameController framework | skeleton; design: [docs/gamepad.md](docs/gamepad.md) |
| `packages/input-actions` (`@game-kit/input-actions`) | TypeScript: many input sources (touch, gamepad, keyboard) → one set of held actions per player, with once-per-press presses | working; design: [docs/gamepad.md §6](docs/gamepad.md#6-input-actions) |

Rule: a module moves in here when it's built for reuse on purpose (gamepad) or
when a second app actually needs it. No speculative extraction.

## Using a package in an app

Each release is a tarball on a GitHub release; no registry, no credentials.

```bash
npm i https://github.com/the-deep-friar/game-kit/releases/download/gamepad-v0.1.0/game-kit-gamepad-0.1.0.tgz
```

Native packages autolink like any Expo module; rebuild the dev client after adding one.

## Developing

```bash
npm ci
npm run ci        # lint, typecheck, test, build — same as GitHub Actions
```

To try a change in an app before releasing: `npm pack -w packages/<name>` here,
then `npm i ../game-kit/game-kit-<name>-<version>.tgz` in the app.

## Releasing

Bump `version` in `packages/<name>/package.json`, merge, then push a tag
`<name>-v<version>` (e.g. `gamepad-v0.1.0`). `release.yml` checks the versions
match, runs the full CI, packs and attaches the tarball to a GitHub release.
