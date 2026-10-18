/** An analog stick, -1..1 on each axis with up and right positive (what `@game-kit/gamepad` reports). */
export type Stick = { x: number; y: number };

export type StickDirection = 'up' | 'down' | 'left' | 'right';

/** How far a stick has to move before it counts. Worn sticks drift a little at rest. */
export const DEFAULT_DEAD_ZONE = 0.3;

const EIGHT_WAYS: readonly (readonly StickDirection[])[] = [
  ['right'],
  ['up', 'right'],
  ['up'],
  ['up', 'left'],
  ['left'],
  ['down', 'left'],
  ['down'],
  ['down', 'right'],
];

/**
 * The directions a stick points, snapped to eight ways: none inside the dead zone, one along an
 * axis, two on a diagonal (`['up', 'right']`). Each eighth of the circle is 45° wide, centred on
 * its direction, so a stick pushed mostly right with a little up is just `['right']`.
 */
export function stickDirections(stick: Stick, deadZone: number = DEFAULT_DEAD_ZONE): readonly StickDirection[] {
  if (Math.hypot(stick.x, stick.y) <= deadZone) return [];
  const eighth = Math.round(Math.atan2(stick.y, stick.x) / (Math.PI / 4));
  return EIGHT_WAYS[(eighth + 8) % 8];
}
