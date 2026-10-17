import { Gamepad } from './gamepad';

// jest has no native module linked, which is also how Expo Go and web behave.
describe('Gamepad without the native module', () => {
  it('reports no pads', () => {
    expect(Gamepad.pads()).toEqual([]);
  });

  it('reads nothing and has no glyphs', () => {
    expect(Gamepad.read('pad')).toBeNull();
    expect(Gamepad.glyph('pad', 'south')).toBeNull();
  });

  it('accepts rumble and listeners without throwing', () => {
    expect(() => Gamepad.rumble('pad', 'tap')).not.toThrow();
    const subscription = Gamepad.addListener('onConnect', () => {});
    expect(() => subscription.remove()).not.toThrow();
  });
});
