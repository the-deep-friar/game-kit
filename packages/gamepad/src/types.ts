/** Every control a pad can report. Face buttons are named by position, not by the letter printed on them. */
export const CONTROLS = [
  'south',
  'east',
  'west',
  'north',
  'leftShoulder',
  'rightShoulder',
  'leftTrigger',
  'rightTrigger',
  'leftStickButton',
  'rightStickButton',
  'dpadUp',
  'dpadDown',
  'dpadLeft',
  'dpadRight',
  'menu',
  'options',
] as const;

export type Control = (typeof CONTROLS)[number];

/** Anything with its own picture: every control, plus each stick and the d-pad as a whole. */
export type GlyphElement = Control | 'leftStick' | 'rightStick' | 'dpad';

export type Pad = {
  /** Stable while the pad stays connected. */
  id: string;
  player: 1 | 2 | 3 | 4;
  /** What the system calls it, e.g. "Pro Controller". */
  name: string;
  /** GameController's product category, e.g. "Switch Pro Controller" or "Joy-Con (L)". For the pad tester and docs/pads.md. */
  productCategory: string;
  layout: 'nintendo' | 'xbox' | 'playstation' | 'other';
  /**
   * `'singleJoyCon'` for one Joy-Con on its own, held sideways: one stick (the left), no right
   * stick, and only the face buttons, the two side buttons (SL/SR) and a few others to reach.
   * Give it bindings that need nothing else. A pair of Joy-Cons used together is `'full'`.
   */
  shape: 'full' | 'singleJoyCon';
  /**
   * True when this Nintendo pad arrived with its printed letters in Apple's A/B/X/Y slots and
   * the module swapped them back, so `south` is still the bottom button (docs/gamepad.md §4).
   */
  facesSwapped: boolean;
  hasRumble: boolean;
};

export type ButtonState = {
  down: boolean;
  /** 0..1; analog triggers report in between. */
  value: number;
  /** True when the button went down at any point since the previous `read()`, even if it is already up again. */
  pressedSinceLastRead: boolean;
};

export type Stick = { x: number; y: number };

export type PadState = {
  buttons: Record<Control, ButtonState>;
  /** -1..1 on each axis, raw: no dead zone applied. Up and right are positive. */
  leftStick: Stick;
  rightStick: Stick;
};

export type RumbleKind = 'tap' | 'thud' | 'buzz';
