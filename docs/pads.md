# Pads we've tested

Filled in from Charlie Craft's About tab → Controllers (the pad tester).
For each pad, press each button and note which control lights up.
"Expected" is by position: south = bottom face button, east = right, west = left, north = top.

| Pad | Reported name / productCategory / layout / shape / facesSwapped | Bottom button lights | Right lights | Left lights | Top lights | Shoulders / triggers / sticks OK? | Quick taps counted? | Glyphs right? | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Switch Pro Controller | | | | | | | | | |
| Joy-Con pair | | | | | | | | | |
| Single Joy-Con (sideways) | | | | | | | | | |
| 8BitDo (model?, mode?) | | | | | | | | | |

If a pad's face buttons arrive by label instead of position, `PadMapping`
swaps them for that pad (docs/gamepad.md §4), from 0.3.0 automatically: it
reads the bottom button's own SF Symbol, and the tester shows `facesSwapped`.
Either way the bottom button must light **south** and show a **B** picture on a
Switch pad.

For a single sideways Joy-Con also note: which controls SL and SR light
(expected: the shoulders), whether the stick's up/down/left/right match how
it's held, and that the right stick stays still.

Also check with a pad connected:
- Does the Home button still go to the Home Screen / the capture button take a screenshot? (should)
- Does pressing B or Menu do anything to the app's UI by itself, like going back? (shouldn't)
