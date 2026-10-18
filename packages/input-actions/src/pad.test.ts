import { createInput } from './input';
import { applyGamepad, type PadBindings, type PadButton, padActions, type PadSnapshot } from './pad';

type Button = 'south' | 'east' | 'leftShoulder' | 'rightTrigger';
const ACTIONS = ['moveLeft', 'moveRight', 'aimUp', 'jump', 'dig', 'nextTool'] as const;
type Action = (typeof ACTIONS)[number];

const BINDINGS: PadBindings<Action, Button> = {
  moveLeft: [{ stick: 'leftStick', dir: 'left' }],
  moveRight: [{ stick: 'leftStick', dir: 'right' }],
  aimUp: [
    { stick: 'leftStick', dir: 'up' },
    { stick: 'rightStick', dir: 'up' },
  ],
  jump: ['south'],
  dig: ['rightTrigger', 'east'],
  nextTool: ['leftShoulder'],
};

const UP: PadButton = { down: false, pressedSinceLastRead: false };

function snapshot(
  buttons: Partial<Record<Button, Partial<PadButton>>> = {},
  sticks: Partial<Pick<PadSnapshot, 'leftStick' | 'rightStick'>> = {},
): PadSnapshot<Button> {
  const all = Object.fromEntries(
    (['south', 'east', 'leftShoulder', 'rightTrigger'] as const).map((b) => [b, { ...UP, ...buttons[b] }]),
  ) as Record<Button, PadButton>;
  return { buttons: all, leftStick: { x: 0, y: 0 }, rightStick: { x: 0, y: 0 }, ...sticks };
}

describe('padActions', () => {
  it('is nothing at rest', () => {
    expect(padActions(snapshot(), BINDINGS)).toEqual({ held: [], pressed: [] });
  });

  it('holds an action while its button is down', () => {
    expect(padActions(snapshot({ south: { down: true } }), BINDINGS).held).toEqual(['jump']);
  });

  it('holds an action from any of its buttons', () => {
    expect(padActions(snapshot({ east: { down: true } }), BINDINGS).held).toEqual(['dig']);
    expect(padActions(snapshot({ rightTrigger: { down: true } }), BINDINGS).held).toEqual(['dig']);
  });

  it('reports a tap between reads as pressed, not held', () => {
    expect(padActions(snapshot({ leftShoulder: { pressedSinceLastRead: true } }), BINDINGS)).toEqual({
      held: [],
      pressed: ['nextTool'],
    });
  });

  it('turns a stick into directions, diagonals holding both ways', () => {
    const pushed = padActions(snapshot({}, { leftStick: { x: -0.7, y: 0.7 } }), BINDINGS);
    expect(pushed.held).toEqual(['moveLeft', 'aimUp']);
    expect(pushed.pressed).toEqual([]);
  });

  it('applies the dead zone, its own when given', () => {
    const nudge = snapshot({}, { leftStick: { x: 0.25, y: 0 } });
    expect(padActions(nudge, BINDINGS).held).toEqual([]);
    expect(padActions(nudge, BINDINGS, 0.1).held).toEqual(['moveRight']);
  });

  it('reads either stick for an action bound to both', () => {
    expect(padActions(snapshot({}, { rightStick: { x: 0, y: 1 } }), BINDINGS).held).toEqual(['aimUp']);
  });

  it('treats buttons the pad lacks as never down', () => {
    const small: PadSnapshot<Button> = {
      buttons: { south: { down: true, pressedSinceLastRead: true } },
      leftStick: { x: 0, y: 0 },
      rightStick: { x: 0, y: 0 },
    };
    expect(padActions(small, BINDINGS)).toEqual({ held: ['jump'], pressed: ['jump'] });
  });
});

describe('applyGamepad', () => {
  it('feeds held and tapped actions to the input under its source', () => {
    const input = createInput(ACTIONS);
    applyGamepad(input, 'pad:1', snapshot({ south: { down: true }, leftShoulder: { pressedSinceLastRead: true } }), BINDINGS);
    const frame = input.read();
    expect(frame.held.jump).toBe(true);
    expect(frame.pressed.jump).toBe(true);
    expect(frame.held.nextTool).toBe(false);
    expect(frame.pressed.nextTool).toBe(true);
  });

  it('presses a stick direction once when it is newly pushed', () => {
    const input = createInput(ACTIONS);
    const right = snapshot({}, { leftStick: { x: 1, y: 0 } });
    applyGamepad(input, 'pad:1', right, BINDINGS);
    expect(input.read().pressed.moveRight).toBe(true);
    applyGamepad(input, 'pad:1', right, BINDINGS);
    const frame = input.read();
    expect(frame.held.moveRight).toBe(true);
    expect(frame.pressed.moveRight).toBe(false);
  });

  it('lets go when the pad has gone, keeping other sources', () => {
    const input = createInput(ACTIONS);
    input.press('touch', 'moveLeft');
    applyGamepad(input, 'pad:1', snapshot({ south: { down: true } }), BINDINGS);
    applyGamepad(input, 'pad:1', null, BINDINGS);
    const frame = input.read();
    expect(frame.held.jump).toBe(false);
    expect(frame.pressed.jump).toBe(false);
    expect(frame.held.moveLeft).toBe(true);
  });

  it('keeps two pads on one input apart', () => {
    const input = createInput(ACTIONS);
    applyGamepad(input, 'pad:1', snapshot({ south: { down: true } }), BINDINGS);
    applyGamepad(input, 'pad:2', snapshot(), BINDINGS);
    expect(input.read().held.jump).toBe(true);
  });
});
