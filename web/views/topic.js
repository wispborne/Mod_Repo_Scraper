// #/topics/<id> — one thread in full. The page itself lives in bundle.js as
// renderThreadPage, shared with the Forum Data Bundle so both routes show the
// same thing; this just calls it with a "back to topics" link.
//
// #/topics/<id>/history — the same thread's history, shared the same way.

import { renderThreadPage } from './bundle.js';
import { render as renderHistory } from './topic_history.js';

export async function render(root, parts) {
  const parent = { label: 'Topics', href: '#/topics' };
  if (parts[1] === 'history') {
    return renderHistory(root, parts[0], { parent });
  }
  return renderThreadPage(root, parts[0], { parent });
}
