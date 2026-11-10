import test from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { hasIcon, actionsWithoutIcon } from '../../web/icons.js';

const WEB = join(import.meta.dirname, '..', '..', 'web');

function sources() {
  return ['.', 'views'].flatMap((dir) => readdirSync(join(WEB, dir))
    .filter((name) => /\.(js|css)$/.test(name) && name !== 'icons.js')
    .map((name) => ({ name: join(dir, name), text: readFileSync(join(WEB, dir, name), 'utf8') })));
}

test('every action has an icon', () => {
  assert.deepEqual(actionsWithoutIcon(), []);
});

// An unknown name draws an empty icon and raises no error.
test('every icon name used in the viewer exists', () => {
  const unknown = [];
  for (const { name, text } of sources()) {
    const uses = [
      ...[...text.matchAll(/\bicon\(([^)]*)\)/g)].flatMap((m) => [...m[1].replace(/=== '[^']*'/g, '').matchAll(/'([^']+)'/g)].map((q) => q[1])),
      ...[...text.matchAll(/\bicon: '([^']+)'/g)].map((m) => m[1]),
    ];
    for (const use of uses) if (!hasIcon(use)) unknown.push(`${name}: ${use}`);
  }
  assert.deepEqual(unknown, []);
});

// A browser tab's title and a notification can hold only text, so routes.js
// and status.js keep their typed marks.
test('no typed character stands in for an icon', () => {
  const typed = /[↗↘←→↑↓↔▲▼▶◀‹›«»✓✔✗✕×]/;
  const found = [];
  for (const { name, text } of sources()) {
    if (/routes\.js$|status\.js$/.test(name)) continue;
    text.split('\n').forEach((line, i) => {
      if (/^\s*(\/\/|\/\*|\*)/.test(line)) return;
      if (typed.test(line)) found.push(`${name}:${i + 1}: ${line.trim()}`);
    });
  }
  assert.deepEqual(found, []);
});
