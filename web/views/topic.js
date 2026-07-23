// #/topics/<id> — one thread in full. The page itself lives in bundle.js as
// renderThreadPage, shared with the Forum Data Bundle so both routes show the
// same thing; this just calls it with a "back to topics" link.

import { renderThreadPage } from './bundle.js';

export async function render(root, parts) {
  return renderThreadPage(root, parts[0], {
    parent: { label: 'Topics', href: '#/topics' },
  });
}
