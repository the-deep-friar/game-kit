import { NativeModule, requireOptionalNativeModule } from 'expo';

import type { Control, Pad, PadState, RumbleKind } from './types';

/** The Swift module's surface, exactly as it crosses the bridge. Everything is synchronous. */
export type GamepadEvents = {
  onConnect(pad: Pad): void;
  onDisconnect(pad: Pad): void;
};

export declare class GamepadNativeModule extends NativeModule<GamepadEvents> {
  pads(): Pad[];
  read(id: string): PadState | null;
  glyph(id: string, control: Control): string | null;
  rumble(id: string, kind: RumbleKind): void;
}

/** `null` where the native module isn't linked: jest, Expo Go, web. */
export default requireOptionalNativeModule<GamepadNativeModule>('Gamepad');
