/** Where a press came from, e.g. 'touch' or 'pad:1'. */
export type InputSource = string;

/**
 * Collects held actions from any number of input sources (on-screen buttons, gamepads, a
 * keyboard). An action is active while at least one source holds it. The game loop only ever
 * calls `read()`.
 */
export type Input<A extends string> = {
  press(source: InputSource, action: A): void;
  release(source: InputSource, action: A): void;
  /** Replaces everything a source holds, for sources that are polled each frame (gamepads). */
  set(source: InputSource, actions: Iterable<A>): void;
  /** Lets go of everything a source holds, or everything when no source is given. */
  releaseAll(source?: InputSource): void;
  read(): Readonly<Record<A, boolean>>;
};

export function createInput<const A extends string>(actions: readonly A[]): Input<A> {
  const held = new Map<InputSource, Set<A>>();
  return {
    press(source, action) {
      const sourceHeld = held.get(source) ?? new Set<A>();
      sourceHeld.add(action);
      held.set(source, sourceHeld);
    },
    release(source, action) {
      held.get(source)?.delete(action);
    },
    set(source, sourceActions) {
      held.set(source, new Set(sourceActions));
    },
    releaseAll(source) {
      if (source === undefined) held.clear();
      else held.delete(source);
    },
    read() {
      const isHeld = (action: A) => [...held.values()].some((sourceHeld) => sourceHeld.has(action));
      return Object.fromEntries(actions.map((action) => [action, isHeld(action)])) as Record<A, boolean>;
    },
  };
}
