import native from './GamepadModule';
import type { Control, Pad, PadState, RumbleKind } from './types';

export type Subscription = { remove(): void };

/**
 * The connected game controllers. Call `read()` once per frame from the game loop; listen for
 * connects and disconnects to switch between touch and pad controls. Where the native module
 * isn't linked (jest, Expo Go) there are simply never any pads.
 */
export const Gamepad = {
  pads(): Pad[] {
    return native?.pads() ?? [];
  },
  read(id: string): PadState | null {
    return native?.read(id) ?? null;
  },
  /** SF Symbol name for `control` as drawn on this pad (Switch "B" vs Xbox "A"), or null if it has none. */
  glyph(id: string, control: Control): string | null {
    return native?.glyph(id, control) ?? null;
  },
  rumble(id: string, kind: RumbleKind): void {
    native?.rumble(id, kind);
  },
  addListener(event: 'onConnect' | 'onDisconnect', listener: (pad: Pad) => void): Subscription {
    return native?.addListener(event, listener) ?? { remove() {} };
  },
};
