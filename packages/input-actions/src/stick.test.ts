import { DEFAULT_DEAD_ZONE, stickDirections } from './stick';

describe('stickDirections', () => {
  it('is nothing inside the dead zone', () => {
    expect(stickDirections({ x: 0, y: 0 })).toEqual([]);
    expect(stickDirections({ x: 0.2, y: -0.2 })).toEqual([]);
    expect(stickDirections({ x: DEFAULT_DEAD_ZONE, y: 0 })).toEqual([]);
  });

  it('points along an axis', () => {
    expect(stickDirections({ x: 1, y: 0 })).toEqual(['right']);
    expect(stickDirections({ x: -1, y: 0 })).toEqual(['left']);
    expect(stickDirections({ x: 0, y: 1 })).toEqual(['up']);
    expect(stickDirections({ x: 0, y: -1 })).toEqual(['down']);
  });

  it('points two ways on a diagonal', () => {
    expect(stickDirections({ x: 0.7, y: 0.7 })).toEqual(['up', 'right']);
    expect(stickDirections({ x: -0.7, y: 0.7 })).toEqual(['up', 'left']);
    expect(stickDirections({ x: -0.7, y: -0.7 })).toEqual(['down', 'left']);
    expect(stickDirections({ x: 0.7, y: -0.7 })).toEqual(['down', 'right']);
  });

  it('snaps to the nearest of eight ways', () => {
    expect(stickDirections({ x: 0.9, y: 0.3 })).toEqual(['right']);
    expect(stickDirections({ x: 0.9, y: 0.5 })).toEqual(['up', 'right']);
    expect(stickDirections({ x: -0.2, y: -0.9 })).toEqual(['down']);
  });

  it('takes its own dead zone', () => {
    expect(stickDirections({ x: 0.5, y: 0 }, 0.6)).toEqual([]);
    expect(stickDirections({ x: 0.1, y: 0 }, 0)).toEqual(['right']);
  });
});
