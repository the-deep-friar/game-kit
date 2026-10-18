import { axis, createInput, createInputs } from './input';

const ACTIONS = ['moveLeft', 'moveRight', 'jump', 'dig', 'nextTool'] as const;
const NOTHING = { moveLeft: false, moveRight: false, jump: false, dig: false, nextTool: false };

describe('held actions', () => {
  it('starts with nothing held or pressed', () => {
    expect(createInput(ACTIONS).read()).toEqual({ held: NOTHING, pressed: NOTHING });
  });

  it('reports the actions it was made with', () => {
    expect(createInput(ACTIONS).actions).toEqual(ACTIONS);
  });

  it('holds an action until it is released', () => {
    const input = createInput(ACTIONS);
    input.press('touch', 'moveRight');
    expect(input.read().held.moveRight).toBe(true);
    expect(input.read().held.moveRight).toBe(true);
    input.release('touch', 'moveRight');
    expect(input.read().held.moveRight).toBe(false);
  });

  it('keeps an action held while any source still holds it', () => {
    const input = createInput(ACTIONS);
    input.press('touch', 'moveLeft');
    input.press('pad:1', 'moveLeft');
    input.release('touch', 'moveLeft');
    expect(input.read().held.moveLeft).toBe(true);
    input.releaseAll('pad:1');
    expect(input.read().held.moveLeft).toBe(false);
  });

  it('releases everything at once', () => {
    const input = createInput(ACTIONS);
    input.press('touch', 'moveRight');
    input.press('pad:1', 'jump');
    input.releaseAll();
    expect(input.read().held).toEqual(NOTHING);
  });
});

describe('presses', () => {
  it('fires once per press, however long it is held', () => {
    const input = createInput(ACTIONS);
    input.press('touch', 'jump');
    expect(input.read()).toEqual({ held: { ...NOTHING, jump: true }, pressed: { ...NOTHING, jump: true } });
    expect(input.read().pressed.jump).toBe(false);
    expect(input.read().held.jump).toBe(true);
  });

  it('fires again after a release and a new press', () => {
    const input = createInput(ACTIONS);
    input.press('touch', 'nextTool');
    input.read();
    input.release('touch', 'nextTool');
    input.press('touch', 'nextTool');
    expect(input.read().pressed.nextTool).toBe(true);
  });

  it('counts a tap that starts and ends between two reads', () => {
    const input = createInput(ACTIONS);
    input.press('touch', 'jump');
    input.release('touch', 'jump');
    expect(input.read()).toEqual({ held: NOTHING, pressed: { ...NOTHING, jump: true } });
    expect(input.read().pressed.jump).toBe(false);
  });

  it('does not fire again when a source presses what it already holds', () => {
    const input = createInput(ACTIONS);
    input.press('touch', 'jump');
    input.read();
    input.press('touch', 'jump');
    expect(input.read().pressed.jump).toBe(false);
  });

  it('fires once per read even when several sources press together', () => {
    const input = createInput(ACTIONS);
    input.press('touch', 'jump');
    input.set('pad:1', ['jump']);
    expect(input.read().pressed.jump).toBe(true);
    expect(input.read().pressed.jump).toBe(false);
  });

  it('drops a source’s unread presses when it is released', () => {
    const input = createInput(ACTIONS);
    input.press('touch', 'jump');
    input.press('pad:1', 'dig');
    input.releaseAll('pad:1');
    expect(input.read().pressed).toEqual({ ...NOTHING, jump: true });
    input.press('touch', 'jump');
    input.releaseAll();
    expect(input.read().pressed).toEqual(NOTHING);
  });
});

describe('polled sources', () => {
  it('replaces what a polled source holds', () => {
    const input = createInput(ACTIONS);
    input.set('pad:1', ['jump', 'moveRight']);
    expect(input.read().held).toEqual({ ...NOTHING, jump: true, moveRight: true });
    input.set('pad:1', ['moveRight']);
    expect(input.read().held).toEqual({ ...NOTHING, moveRight: true });
  });

  it('presses what is newly held, once', () => {
    const input = createInput(ACTIONS);
    input.set('pad:1', ['dig']);
    expect(input.read().pressed.dig).toBe(true);
    input.set('pad:1', ['dig']);
    expect(input.read().pressed.dig).toBe(false);
    input.set('pad:1', []);
    input.set('pad:1', ['dig']);
    expect(input.read().pressed.dig).toBe(true);
  });

  it('presses what the source says was tapped between polls', () => {
    const input = createInput(ACTIONS);
    input.set('pad:1', [], ['nextTool']);
    expect(input.read()).toEqual({ held: NOTHING, pressed: { ...NOTHING, nextTool: true } });
  });

  it('counts a press that is both newly held and tapped only once', () => {
    const input = createInput(ACTIONS);
    input.set('pad:1', ['jump'], ['jump']);
    expect(input.read().pressed.jump).toBe(true);
    input.set('pad:1', ['jump']);
    expect(input.read().pressed.jump).toBe(false);
  });

  it('leaves other sources alone when one is replaced', () => {
    const input = createInput(ACTIONS);
    input.press('touch', 'jump');
    input.set('pad:1', []);
    expect(input.read().held.jump).toBe(true);
  });

  it('feeds from a gamepad snapshot', () => {
    // The shape `@game-kit/gamepad`'s `read()` returns, cut down to what this needs.
    const snapshot = {
      buttons: {
        south: { down: true, pressedSinceLastRead: true },
        rightTrigger: { down: false, pressedSinceLastRead: true },
      },
    };
    const bindings = { jump: 'south', dig: 'rightTrigger' } as const;
    const bound = Object.entries(bindings) as [keyof typeof bindings, keyof typeof snapshot.buttons][];
    const input = createInput(ACTIONS);
    input.set(
      'pad:abc',
      bound.filter(([, control]) => snapshot.buttons[control].down).map(([action]) => action),
      bound.filter(([, control]) => snapshot.buttons[control].pressedSinceLastRead).map(([action]) => action),
    );
    expect(input.read()).toEqual({
      held: { ...NOTHING, jump: true },
      pressed: { ...NOTHING, jump: true, dig: true },
    });
  });
});

describe('per player', () => {
  it('keeps each player’s actions apart', () => {
    const inputs = createInputs([1, 2], ACTIONS);
    inputs[1].press('touch', 'moveLeft');
    inputs[2].set('pad:b', ['jump']);
    expect(inputs[1].read()).toEqual({ held: { ...NOTHING, moveLeft: true }, pressed: { ...NOTHING, moveLeft: true } });
    expect(inputs[2].read()).toEqual({ held: { ...NOTHING, jump: true }, pressed: { ...NOTHING, jump: true } });
  });

  it('reads one player without clearing another’s presses', () => {
    const inputs = createInputs(['p1', 'p2'], ACTIONS);
    inputs.p1.press('touch', 'jump');
    inputs.p2.press('keyboard', 'jump');
    inputs.p1.read();
    expect(inputs.p2.read().pressed.jump).toBe(true);
  });
});

describe('axis', () => {
  it('is -1, 0 or 1 from a pair of actions', () => {
    expect(axis(NOTHING, 'moveLeft', 'moveRight')).toBe(0);
    expect(axis({ ...NOTHING, moveLeft: true }, 'moveLeft', 'moveRight')).toBe(-1);
    expect(axis({ ...NOTHING, moveRight: true }, 'moveLeft', 'moveRight')).toBe(1);
    expect(axis({ ...NOTHING, moveLeft: true, moveRight: true }, 'moveLeft', 'moveRight')).toBe(0);
  });
});
