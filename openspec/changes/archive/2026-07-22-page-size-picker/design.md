## Context

Seven paged lists, six of them drawing the shared `pager()` from `web/lib.js` and one (the run history) drawing the same helper over the manager API. Each view kept its own `pageSize` in a module-level state object, all of them fixed numbers written into the source. The two servers each had a `_pageSize` helper that clamped what it was given to between 1 and 500.

## Goals / Non-Goals

**Goals:**

- One box, in the place people already look for paging, on every list.
- "All on one page", for reading a long list with the browser's own find, or copying it out.
- A choice that sticks, so nobody re-picks it on every page.

**Non-Goals:**

- A settings page. One box in the pager is the whole feature.
- Loosening the rule that no endpoint hands over the whole bundle or all per-topic details. Rows are summaries; that rule is about the big ones and stays exactly as it was.
- Making very large pages fast. 700 rows is fine; if some list ever gets slow, that is a job for the list, not for the picker.

## Decisions

### 0 means "all of them"

`pageSize=0` on the wire. It reads as "no limit", it survives a round trip through a query string without a special word to spell, and the old clamp already treated everything below 1 as nonsense — so no existing caller can hit it by accident. Both servers answer with `page: 0, pageSize: 0`, which is how the frontend knows to stop drawing page buttons.

*Alternative considered:* `pageSize=all`. Rejected — every caller then has to handle a value that is sometimes a number and sometimes a word.

### The cap stays, but only for a number

A named page size over 500 is still capped at 500. Somebody typing a huge number into the URL is probably guessing, and the cap keeps a bad guess cheap. Asking for 0 is not a guess — it says plainly "all of them" — so it is honoured.

### One remembered setting for the whole site, in localStorage

The choice lives in `localStorage` under one key, read by `pageSizePreference()` when each view's state object is built. Not one setting per list: somebody who wants long pages wants them everywhere, and a per-list memory would mean explaining which list remembered what.

The catch is that a view's state object is built once when its module first loads, so a list already visited keeps the size it was built with until it is redrawn. In practice every list rebuilds its rows when the picker fires, and the next fresh page load reads the saved value — so the only oddity is a stale number on a list visited earlier in the same session, which corrects itself the moment that list is used.

### Changing the size returns to the first page

Page 4 of 50-row pages is not page 4 of 250-row pages. Keeping the number would land the reader somewhere they did not ask to be, so every picker callback sets `page = 0`.

## Risks / Trade-offs

- **A huge list on one page makes the browser work** → the biggest list here is around 1,700 rows and renders fine. It is opt-in, and the reader can pick a number again.
- **The manager's run list is filtered after paging** (running and queued runs are dropped from the rows and from the count) → that logic is untouched and works the same with everything on one page, since it only ever removes the newest rows.
