// A page that is not built yet. It says so and links to the page in the old
// viewer that does the same work.

import { el } from '../lib.js';
import { icon } from '../icons.js';
import { oldViewerAddress } from '../routes.js';
import { pageLayout } from '../frame.js';

/// The "not built yet" note for a nav entry, with its old-viewer link.
export function notBuiltYet(entry) {
  const note = el('div', { class: 'note' }, [
    el('h2', { class: 'panel-heading', text: entry.label }),
    el('p', { text: 'Coming soon. Until then, use the old viewer.' }),
  ]);
  if (entry.old) {
    note.append(el('p', {}, [
      el('a', { class: 'out-link', href: oldViewerAddress(location.pathname, entry.old) }, [
        'Open in the old viewer',
        icon('external-link', 14),
      ]),
    ]));
  } else {
    note.append(el('p', {
      class: 'dim',
      text: 'This page is not available in the old viewer. For now, change settings in config.properties.',
    }));
  }
  return note;
}

export function render({ content, entry }) {
  content.append(pageLayout(notBuiltYet(entry)));
}
