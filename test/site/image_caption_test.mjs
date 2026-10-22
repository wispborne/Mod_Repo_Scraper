import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';

async function moduleUrl(file) {
  let source = await readFile(file, 'utf8');
  for (const match of [...source.matchAll(/from ['"](\.\/[^'"]+)['"]/g)]) {
    const url = await moduleUrl(new URL(match[1], file));
    source = source.replaceAll(match[0], `from '${url}'`);
  }
  source += `\n//# sourceURL=${file.pathname}\n`;
  return `data:text/javascript;base64,${Buffer.from(source).toString('base64')}`;
}
const saved = new Map();
globalThis.localStorage = {
  getItem: (key) => saved.get(key) ?? null,
  setItem: (key, value) => saved.set(key, value),
};
globalThis.window = new EventTarget();
globalThis.location = { search: '' };
globalThis.history = {};
globalThis.document = { cookie: '' };
const { imageCaption, setAiSummaryMode, setAiOnModPages } =
  await import(await moduleUrl(new URL('../../site/lib.js', import.meta.url)));

test('caption choices follow both AI preferences and preserve author text', () => {
  for (const mode of ['always', 'whenMissing', 'never']) {
    for (const visibility of ['show', 'hide']) {
      setAiSummaryMode(mode);
      setAiOnModPages(visibility);
      const allowed = mode !== 'never' && visibility !== 'hide';
      assert.equal(imageCaption({ caption: 'Author', aiCaption: 'Generated' }),
        allowed && mode === 'always' ? 'AI description: Generated' : 'Author');
      assert.equal(imageCaption({ aiCaption: 'Generated' }),
        allowed ? 'AI description: Generated' : '');
      assert.equal(imageCaption({ caption: 'Author' }), 'Author');
      assert.equal(imageCaption({}), '');
      assert.equal(imageCaption({ caption: '  ', aiCaption: '  ' }), '');
    }
  }
});

test('changing visibility notifies the gallery and changes caption selection', () => {
  setAiSummaryMode('always');
  setAiOnModPages('show');
  let caption;
  const update = () => { caption = imageCaption({ aiCaption: 'Generated' }); };
  window.addEventListener('ai-caption-preference-changed', update);
  setAiOnModPages('hide');
  assert.equal(caption, '');
  setAiOnModPages('show');
  assert.equal(caption, 'AI description: Generated');
  window.removeEventListener('ai-caption-preference-changed', update);
});
