import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

// Load the browser module as source so this works on Node releases both before
// and after automatic ES-module syntax detection for un-packaged `.js` files.
const source = await readFile(
  new URL('../../site/address.js', import.meta.url),
  'utf8',
);
const { siteAddress } = await import(
  `data:text/javascript;base64,${Buffer.from(source).toString('base64')}`
);

test('the front document takes its route from the hash', () => {
  const browser = fakeBrowser('https://example.test/#/browse?q=ships');
  assert.deepEqual(siteAddress(browser).parts(), ['browse']);
});

test('a mod takes its route from its own path', () => {
  const browser = fakeBrowser('https://example.test/mods/nexerelin/', {
    baseHref: '../../',
  });
  assert.deepEqual(siteAddress(browser).parts(), ['mods', 'nexerelin']);
});

test('a mod address with the trailing slash rubbed off still opens it', () => {
  // Most hosts redirect this to the folder form, but a shared link that lost
  // its slash must not land the reader on the home page.
  const browser = fakeBrowser('https://example.test/mods/nexerelin', {
    baseHref: '../../',
  });
  assert.deepEqual(siteAddress(browser).parts(), ['mods', 'nexerelin']);
});

test('a mod under a deployment folder does too', () => {
  const browser = fakeBrowser(
    'https://example.test/catalog/mods/A%20mod/index.html',
    { baseHref: '../../' },
  );
  assert.deepEqual(siteAddress(browser).parts(), ['mods', 'A mod']);
});

test('the front document with nothing after it is the home page', () => {
  const browser = fakeBrowser('https://example.test/catalog/index.html');
  assert.deepEqual(siteAddress(browser).parts(), []);
});

test("a mod's link is its own page, and carries the sample-data switch", () => {
  const browser = fakeBrowser('https://example.test/?data=sample#/browse');
  assert.equal(
    siteAddress(browser).modHref('A mod'),
    'mods/A%20mod/?data=sample',
  );
});

test('opening a mod from Browse draws it without reloading the site', () => {
  const browser = fakeBrowser('https://example.test/#/browse');
  const address = siteAddress(browser);
  const drawn = [];
  address.watch(() => drawn.push(address.parts()));

  browser.click('mods/nexerelin/');

  assert.equal(browser.locationRef.href, 'https://example.test/mods/nexerelin/');
  assert.deepEqual(drawn, [['mods', 'nexerelin']]);
  assert.equal(browser.loads, 1, 'the site was reloaded');
});

test('Back from a mod draws the page it came from', () => {
  const browser = fakeBrowser('https://example.test/#/browse');
  const address = siteAddress(browser);
  const drawn = [];
  address.watch(() => drawn.push(address.parts()));

  browser.click('mods/nexerelin/');
  browser.back();

  // The whole point. The two addresses differ by more than their fragment, so
  // the browser says only "popstate" and never "hashchange"; listening for one
  // of those alone leaves the page showing the mod while the address says
  // Browse.
  assert.equal(browser.locationRef.href, 'https://example.test/#/browse');
  assert.deepEqual(drawn, [['mods', 'nexerelin'], ['browse']]);
});

test('Forward draws the mod again', () => {
  const browser = fakeBrowser('https://example.test/#/browse');
  const address = siteAddress(browser);
  const drawn = [];
  address.watch(() => drawn.push(address.parts()));

  browser.click('mods/nexerelin/');
  browser.back();
  browser.forward();

  assert.equal(browser.locationRef.href, 'https://example.test/mods/nexerelin/');
  assert.deepEqual(
    drawn,
    [['mods', 'nexerelin'], ['browse'], ['mods', 'nexerelin']],
  );
});

test('an ordinary hash link is drawn once, not twice', () => {
  const browser = fakeBrowser('https://example.test/#/browse');
  const address = siteAddress(browser);
  const drawn = [];
  address.watch(() => drawn.push(address.parts()));

  browser.click('#/about');

  // A hash link makes some browsers say both "popstate" and "hashchange".
  browser.fire('popstate');
  browser.fire('hashchange');

  assert.deepEqual(drawn, [['about']]);
});

test('a hash link from a mod stays in the page and keeps the sample data', () => {
  const browser = fakeBrowser(
    'https://example.test/mods/nexerelin/?data=sample',
    { baseHref: '../../' },
  );
  const address = siteAddress(browser);
  const drawn = [];
  address.watch(() => drawn.push(address.parts()));

  // What the DOM resolves "#/browse" to on a mod's page: the site's root,
  // which carries no query of its own.
  browser.click('#/browse');

  assert.equal(
    browser.locationRef.href,
    'https://example.test/?data=sample#/browse',
  );
  assert.deepEqual(drawn, [['browse']]);
  assert.equal(browser.loads, 1, 'the site was reloaded');
});

test("the site's files stay put when the address bar moves to a mod", () => {
  const browser =
    fakeBrowser('https://example.test/catalog/?data=sample#/browse');
  const address = siteAddress(browser);
  address.watch(() => {});

  // Pinned as the site starts, so it is already absolute…
  assert.equal(browser.baseTag.href, 'https://example.test/catalog/?data=sample');

  browser.click('mods/nexerelin/');

  // … and a data file is still asked for beside the front document, not
  // inside the mod's folder, even though that is what the address bar says.
  assert.equal(
    new URL('./mods/nexerelin.json', browser.baseTag.href).href,
    'https://example.test/catalog/mods/nexerelin.json',
  );
  // A hash link written anywhere on the site keeps the sample data.
  assert.equal(
    new URL('#/about', browser.baseTag.href).href,
    'https://example.test/catalog/?data=sample#/about',
  );
});

test('links that are not ours are left to the browser', () => {
  const browser = fakeBrowser('https://example.test/#/browse');
  const address = siteAddress(browser);
  const drawn = [];
  address.watch(() => drawn.push(address.parts()));

  const left = [
    browser.click('https://fractalsoftworks.com/forum/'),
    browser.click('updates.xml'),
    browser.click('mods/nexerelin.json'),
    browser.click('mods/nexerelin/', { link: { target: '_blank' } }),
    browser.click('mods/nexerelin/', { link: { download: true } }),
    browser.click('mods/nexerelin/', { event: { ctrlKey: true } }),
    browser.click('mods/nexerelin/', { event: { button: 1 } }),
    browser.click('mods/nexerelin/', { event: { defaultPrevented: true } }),
  ];

  for (const event of left) {
    assert.equal(event.defaultPrevented, event.wasPrevented,
      `${event.forHref} was taken over`);
  }
  assert.deepEqual(drawn, []);
  assert.equal(browser.locationRef.href, 'https://example.test/#/browse');
});

test('a filter change moves the address without redrawing', () => {
  const browser = fakeBrowser('https://example.test/#/browse');
  const address = siteAddress(browser);
  const drawn = [];
  address.watch(() => drawn.push(address.parts()));

  address.replace('#/browse?q=ships');

  assert.equal(
    browser.locationRef.href,
    'https://example.test/#/browse?q=ships',
  );
  assert.deepEqual(drawn, []);
  assert.equal(browser.entries(), 1, 'a filter change piled up in the history');
});

test("a mod's scroll position is filed under its route", () => {
  const mod = fakeBrowser('https://example.test/mods/nexerelin/', {
    baseHref: '../../',
  });
  assert.equal(siteAddress(mod).scrollKey(), '#/mods/nexerelin');

  const browse = fakeBrowser('https://example.test/#/browse?q=ships');
  assert.equal(siteAddress(browse).scrollKey(), '#/browse?q=ships');
});

test('nothing is kept in history state', () => {
  const browser = fakeBrowser('https://example.test/#/browse');
  const address = siteAddress(browser);
  address.watch(() => {});

  browser.click('mods/nexerelin/');
  address.replace('#/browse');

  // The address is the only place the route lives. State that has to agree
  // with the address bar is a second truth to keep in step.
  assert.deepEqual(browser.states(), [null, null]);
});

/// A browser with a history stack: entries can be added, replaced and walked,
/// and walking fires the events a real browser fires. "loads" counts how many
/// times a whole document would have been fetched, which is what tells a
/// same-page move from a reload.
function fakeBrowser(href, { baseHref } = {}) {
  const listeners = { popstate: [], hashchange: [], click: [] };
  const stack = [{ href, state: null }];
  let at = 0;

  const locationRef = {};
  const apply = () => {
    const url = new URL(stack[at].href);
    locationRef.href = url.href;
    locationRef.origin = url.origin;
    locationRef.pathname = url.pathname;
    locationRef.search = url.search;
    locationRef.hash = url.hash;
  };
  apply();

  const fire = (name, event = {}) => {
    for (const fn of [...listeners[name]]) fn(event);
    return event;
  };

  const historyRef = {
    pushState(state, _title, url) {
      stack.length = at + 1;
      stack.push({ href: new URL(url, locationRef.href).href, state });
      at = stack.length - 1;
      apply();
    },
    replaceState(state, _title, url) {
      stack[at] = { href: new URL(url, locationRef.href).href, state };
      apply();
    },
  };

  const travel = (delta) => {
    const wanted = at + delta;
    if (wanted < 0 || wanted >= stack.length) return;
    const before = new URL(stack[at].href);
    at = wanted;
    apply();
    const after = new URL(stack[at].href);
    fire('popstate');
    // A browser only says the hash changed when nothing else about the address
    // did. Two addresses with different paths are not a fragment change.
    const onlyTheHash = before.origin === after.origin
      && before.pathname === after.pathname
      && before.search === after.search;
    if (onlyTheHash && before.hash !== after.hash) fire('hashchange');
  };

  const baseTag = { href: baseHref || './' };
  const documentRef = {
    baseURI: new URL(baseHref || './', href).href,
    querySelector: (sel) => (sel === 'base' ? baseTag : null),
    addEventListener: (name, fn) => listeners[name].push(fn),
  };
  const windowRef = {
    addEventListener: (name, fn) => listeners[name].push(fn),
  };

  const browser = {
    documentRef,
    locationRef,
    historyRef,
    windowRef,
    fire,
    baseTag,
    back: () => travel(-1),
    forward: () => travel(1),
    entries: () => stack.length,
    states: () => stack.map((entry) => entry.state),

    /// How many whole-document loads this visit would have cost: the first one,
    /// plus one for every click the site left to the browser.
    loads: 1,

    /// A click on a link, resolved the way the DOM would resolve it.
    click(rawHref, { link = {}, event = {} } = {}) {
      const target = {
        href: new URL(rawHref, baseTag.href).href,
        target: link.target || '',
        hasAttribute: (name) => name === 'download' && !!link.download,
      };
      const clicked = fire('click', {
        defaultPrevented: false,
        button: 0,
        metaKey: false,
        ctrlKey: false,
        shiftKey: false,
        altKey: false,
        ...event,
        forHref: rawHref,
        wasPrevented: !!event.defaultPrevented,
        target: { closest: (sel) => (sel === 'a[href]' ? target : null) },
        preventDefault() { this.defaultPrevented = true; },
      });
      // Anything the site did not take over is a real navigation.
      if (!clicked.defaultPrevented && clicked.button === 0) browser.loads += 1;
      return clicked;
    },
  };
  return browser;
}
