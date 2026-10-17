# game-kit

Shared game modules for our own Expo iOS apps (Charlie Craft first, then
Parlor and whatever comes next). Built for us: no npm publishing, no support
for setups we don't use.

| Package | What | Status |
|---|---|---|
| `packages/gamepad` | Expo native module: game controllers via Apple's GameController framework | design: [docs/gamepad.md](docs/gamepad.md) |
| `packages/input-actions` | TypeScript: many input sources (touch, gamepad, keyboard) → one set of held actions | design: [docs/gamepad.md §6](docs/gamepad.md#6-input-actions) |

Rule: a module moves in here when it's built for reuse on purpose (gamepad) or
when a second app actually needs it. No speculative extraction.
