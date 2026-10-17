import { createInput } from './input';

const ACTIONS = ['moveLeft', 'moveRight', 'jump'] as const;
const NOTHING = { moveLeft: false, moveRight: false, jump: false };

describe('input', () => {
  it('starts with nothing held', () => {
    expect(createInput(ACTIONS).read()).toEqual(NOTHING);
  });

  it('holds an action until it is released', () => {
    const input = createInput(ACTIONS);
    input.press('touch', 'jump');
    expect(input.read().jump).toBe(true);
    input.release('touch', 'jump');
    expect(input.read().jump).toBe(false);
  });

  it('keeps an action held while any source still holds it', () => {
    const input = createInput(ACTIONS);
    input.press('touch', 'moveLeft');
    input.press('pad:1', 'moveLeft');
    input.release('touch', 'moveLeft');
    expect(input.read().moveLeft).toBe(true);
    input.releaseAll('pad:1');
    expect(input.read().moveLeft).toBe(false);
  });

  it('replaces what a polled source holds', () => {
    const input = createInput(ACTIONS);
    input.set('pad:1', ['jump', 'moveRight']);
    expect(input.read()).toEqual({ ...NOTHING, jump: true, moveRight: true });
    input.set('pad:1', ['moveRight']);
    expect(input.read()).toEqual({ ...NOTHING, moveRight: true });
  });

  it('leaves other sources alone when one is replaced', () => {
    const input = createInput(ACTIONS);
    input.press('touch', 'jump');
    input.set('pad:1', []);
    expect(input.read().jump).toBe(true);
  });

  it('releases everything at once', () => {
    const input = createInput(ACTIONS);
    input.press('touch', 'moveRight');
    input.press('pad:1', 'jump');
    input.releaseAll();
    expect(input.read()).toEqual(NOTHING);
  });
});
