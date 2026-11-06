// Numbers for the router's history entries, with no DOM, so Node can test
// them (test/web/history_steps_test.mjs).
//
// Each new history entry gets the previous entry's number plus one.
// The numbers track the direction and distance of Back and Forward,
// even when the browser does not provide an entry's place in the history.

const KEY = 'viewerStep';

/// The number written into an entry's state, or null when it has none.
export function stepOf(state) {
  const step = state && typeof state === 'object' ? state[KEY] : undefined;
  return Number.isInteger(step) ? step : null;
}

/// `state` with `step` written in. Other values in it are kept. A state
/// that is not an object cannot hold a number and is returned as it is.
export function withStep(state, step) {
  if (state == null) return { [KEY]: step };
  if (typeof state !== 'object' || Array.isArray(state)) return state;
  return { ...state, [KEY]: step };
}

/// The number of the entry the reader just arrived at. An entry with no
/// number is new: a link was followed from the shown page, so it comes
/// straight after it. `isNew` says the number still has to be written.
export function arrivedStep(state, shownStep) {
  const step = stepOf(state);
  if (step != null) return { step, isNew: false };
  return { step: shownStep == null ? 0 : shownStep + 1, isNew: true };
}
