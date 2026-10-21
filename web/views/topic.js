// Topic detail and history share the Mod Details views, with Topics breadcrumbs.

import { renderThreadPage } from './bundle.js';
import { render as renderHistory } from './topic_history.js';

export async function render(root, parts) {
  const parent = { label: 'Topics', href: '#/topics' };
  if (parts[1] === 'history') {
    return renderHistory(root, parts[0], { parent });
  }
  return renderThreadPage(root, parts[0], { parent });
}
