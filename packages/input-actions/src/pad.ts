import type { Input, InputSource } from './input';
import { DEFAULT_DEAD_ZONE, type Stick, type StickDirection, stickDirections } from './stick';

/** One button as a polled pad reports it (what `@game-kit/gamepad`'s `read()` gives, by shape). */
export type PadButton = { down: boolean; pressedSinceLastRead: boolean };

/** The two sticks a pad snapshot carries. */
export type PadStick = 'leftStick' | 'rightStick';

/**
 * One frame of a polled pad, by shape: `@game-kit/gamepad`'s `PadState` fits it as is. This
 * package doesn't depend on the gamepad module; any source with buttons and sticks works.
 */
export type PadSnapshot<C extends string = string> = {
  buttons: Readonly<Partial<Record<C, PadButton>>>;
  leftStick: Stick;
  rightStick: Stick;
};

/** A stick pushed one way (by `stickDirections`, so diagonals hold both of their ways). */
export type StickBinding = { stick: PadStick; dir: StickDirection };

/** What can hold an action: a button by name (`'south'`, `'rightTrigger'`) or a stick direction. */
export type PadBinding<C extends string = string> = C | StickBinding;

/** For each action, the bindings that hold it; any one of them is enough. Unbound actions are never held. */
export type PadBindings<A extends string, C extends string = string> = Readonly<Partial<Record<A, readonly PadBinding<C>[]>>>;

/** A pad's frame as action lists, ready for `Input.set(source, held, pressed)`. */
export type PadActions<A extends string> = { held: A[]; pressed: A[] };

/**
 * Turns one pad snapshot into actions. An action is held while any of its buttons is down or
 * any of its stick directions is pushed; it's pressed when any of its buttons went down since
 * the previous read, even if already up (sticks have no latch: a newly pushed direction counts
 * as a press through `set()`). Buttons the snapshot doesn't have are never down, so one map can
 * name controls a smaller pad lacks.
 */
export function padActions<A extends string, C extends string>(
  pad: PadSnapshot<C>,
  bindings: PadBindings<A, C>,
  deadZone: number = DEFAULT_DEAD_ZONE,
): PadActions<A> {
  const directions: Record<PadStick, readonly StickDirection[]> = {
    leftStick: stickDirections(pad.leftStick, deadZone),
    rightStick: stickDirections(pad.rightStick, deadZone),
  };
  const held: A[] = [];
  const pressed: A[] = [];
  for (const action of Object.keys(bindings) as A[]) {
    const list = bindings[action] ?? [];
    const isHeld = list.some((binding) =>
      typeof binding === 'string' ? pad.buttons[binding]?.down === true : directions[binding.stick].includes(binding.dir),
    );
    const isPressed = list.some((binding) => typeof binding === 'string' && pad.buttons[binding]?.pressedSinceLastRead === true);
    if (isHeld) held.push(action);
    if (isPressed) pressed.push(action);
  }
  return { held, pressed };
}

/**
 * Feeds one pad's frame to a player's input under `source` (e.g. `pad:<id>`): call once per
 * frame, before the game loop reads that input. A `null` snapshot (the pad has gone) lets go of
 * everything that source held.
 */
export function applyGamepad<A extends string, C extends string>(
  input: Pick<Input<A>, 'set' | 'releaseAll'>,
  source: InputSource,
  pad: PadSnapshot<C> | null,
  bindings: PadBindings<A, C>,
  deadZone: number = DEFAULT_DEAD_ZONE,
): void {
  if (!pad) {
    input.releaseAll(source);
    return;
  }
  const { held, pressed } = padActions(pad, bindings, deadZone);
  input.set(source, held, pressed);
}
