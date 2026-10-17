import { useEffect, useState } from 'react';

import { Gamepad } from './gamepad';
import type { Pad } from './types';

/** The connected pads, re-rendering when one connects or disconnects. */
export function useGamepads(): Pad[] {
  const [pads, setPads] = useState(Gamepad.pads);
  useEffect(() => {
    const refresh = () => setPads(Gamepad.pads());
    const subscriptions = [Gamepad.addListener('onConnect', refresh), Gamepad.addListener('onDisconnect', refresh)];
    refresh();
    return () => subscriptions.forEach((subscription) => subscription.remove());
  }, []);
  return pads;
}
