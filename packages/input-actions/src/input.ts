/** Where a press came from, e.g. 'touch', 'keyboard' or 'pad:<id>'. */
export type InputSource = string;

/** One frame of input for one player, as the game loop sees it. */
export type InputFrame<A extends string> = {
  /** Down right now, by at least one source. For walking, swimming, holding dig. */
  held: Readonly<Record<A, boolean>>;
  /**
   * Went down at least once since the previous `read()`, by any source, even if it is already
   * up again. True for one read per press. For edge-triggered actions: jump, next tool, craft.
   */
  pressed: Readonly<Record<A, boolean>>;
};

/**
 * One player's held actions, fed by any number of input sources (on-screen buttons, gamepads,
 * a keyboard). An action is held while at least one source holds it. The game loop calls
 * `read()` once per frame; make one `Input` per player.
 */
export type Input<A extends string> = {
  /** The action names this input reports, in the order given to `createInput`. */
  readonly actions: readonly A[];
  /** An event-driven source (a touch button) went down. */
  press(source: InputSource, action: A): void;
  /** An event-driven source let go. A press released before the next `read()` still counts once. */
  release(source: InputSource, action: A): void;
  /**
   * Replaces everything a polled source (a gamepad, read once per frame) holds. Actions newly in
   * `held` count as pressed; so does everything in `pressed`, for presses that started and ended
   * between two polls (a pad's `pressedSinceLastRead`).
   */
  set(source: InputSource, held: Iterable<A>, pressed?: Iterable<A>): void;
  /**
   * Lets go of everything a source holds, or of everything when no source is given, and drops
   * their presses not yet read (so nothing fires after a pad disconnects or the screen loses focus).
   */
  releaseAll(source?: InputSource): void;
  /** What's held now and what was pressed since the last call. Clears the presses: call once per frame. */
  read(): InputFrame<A>;
};

export function createInput<const A extends string>(actions: readonly A[]): Input<A> {
  const held = new Map<InputSource, Set<A>>();
  const latched = new Map<InputSource, Set<A>>();

  const latch = (source: InputSource, action: A) => {
    const sourceLatched = latched.get(source) ?? new Set<A>();
    sourceLatched.add(action);
    latched.set(source, sourceLatched);
  };
  const anyHas = (sets: Map<InputSource, Set<A>>, action: A) => [...sets.values()].some((set) => set.has(action));
  const record = (value: (action: A) => boolean) =>
    Object.fromEntries(actions.map((action) => [action, value(action)])) as Record<A, boolean>;

  return {
    actions,
    press(source, action) {
      const sourceHeld = held.get(source) ?? new Set<A>();
      if (!sourceHeld.has(action)) latch(source, action);
      sourceHeld.add(action);
      held.set(source, sourceHeld);
    },
    release(source, action) {
      held.get(source)?.delete(action);
    },
    set(source, sourceHeld, pressed = []) {
      const before = held.get(source);
      const next = new Set(sourceHeld);
      for (const action of next) if (!before?.has(action)) latch(source, action);
      for (const action of pressed) latch(source, action);
      held.set(source, next);
    },
    releaseAll(source) {
      if (source === undefined) {
        held.clear();
        latched.clear();
      } else {
        held.delete(source);
        latched.delete(source);
      }
    },
    read() {
      const frame = {
        held: record((action) => anyHas(held, action)),
        pressed: record((action) => anyHas(latched, action)),
      };
      latched.clear();
      return frame;
    },
  };
}

/** One `Input` per player, all with the same actions: `createInputs([1, 2], ACTIONS)[2].read()`. */
export function createInputs<const P extends PropertyKey, const A extends string>(
  players: readonly P[],
  actions: readonly A[],
): Record<P, Input<A>> {
  return Object.fromEntries(players.map((player) => [player, createInput(actions)])) as Record<P, Input<A>>;
}

/** -1 when only `negative` is on, 1 when only `positive` is, 0 when neither or both: walk left/right, aim up/down. */
export function axis<A extends string>(actions: Readonly<Record<A, boolean>>, negative: A, positive: A): -1 | 0 | 1 {
  if (actions[negative] === actions[positive]) return 0;
  return actions[negative] ? -1 : 1;
}
