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

export type Pad = {
  /** Stable while the pad stays connected. */
  id: string;
  player: 1 | 2 | 3 | 4;
  /** What the system calls it, e.g. "Pro Controller". */
  name: string;
  layout: 'nintendo' | 'xbox' | 'playstation' | 'other';
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
  /** -1..1 on each axis, raw: no dead zone applied. Up is +y. */
  leftStick: Stick;
  rightStick: Stick;
};

export type RumbleKind = 'tap' | 'thud' | 'buzz';
