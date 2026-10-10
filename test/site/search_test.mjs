// The public site's search, tried the way people really search.
//
// Every mod here is a real record copied from the published `mods.json`
// (see `search_fixture.json`), because the bugs this pins down came from real
// names: "Seeker - Unidentified Contact" could not be found by typing its own
// name without the dash.
//
// The checks are about order and membership ("this comes first", "that comes
// above the other", "this is not listed"), never about score numbers, so the
// scoring can be tuned without rewriting the tests.
//
// These were written before the code. When one fails, first work out whether
// the expectation or the code is wrong. If the expectation is wrong, fix it and
// add a line saying why. Never loosen a check just to make it pass.

import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { describe, test } from 'node:test';

// --- Loading the browser modules into Node ---
//
// Loaded through `data:` addresses so this works on Node releases both before
// and after automatic module detection for un-packaged `.js` files. A `data:`
// module cannot resolve `./mod_names.js` itself, so that import is pointed at
// the helper module's own `data:` address first.

const dataUrl = (source) =>
  `data:text/javascript;base64,${Buffer.from(source).toString('base64')}`;
const siteFile = (name) =>
  readFile(new URL(`../../site/${name}`, import.meta.url), 'utf8');

const modNamesUrl = dataUrl(await siteFile('mod_names.js'));
const nicknamesUrl = dataUrl(await siteFile('nicknames.js'));
const searchSource = (await siteFile('search.js'))
  .replace(/(['"])\.\/mod_names\.js\1/g, `'${modNamesUrl}'`)
  .replace(/(['"])\.\/nicknames\.js\1/g, `'${nicknamesUrl}'`);
const {
  normalize, editDistance, searchTerms, compileSearch, searchMods, suggestMods,
  peopleMatching,
} = await import(dataUrl(searchSource));

const fixture = JSON.parse(
  await readFile(new URL('./search_fixture.json', import.meta.url), 'utf8'));
const everyId = fixture.map((mod) => mod.id);

// --- Helpers ---

/// The ids found for a search, best first.
const ids = (text) => searchMods(fixture, text).map((mod) => mod.id);

/// What a failed check prints: the search and the first few ids it found.
const shown = (text) => {
  const found = ids(text);
  return `search ${JSON.stringify(text)} found ${found.length}: `
    + `${found.slice(0, 8).join(', ')}${found.length > 8 ? ', …' : ''}`;
};

/// The given mod is listed first.
function first(text, id) {
  assert.equal(ids(text)[0], id, shown(text));
}

/// The first few listed are exactly these, in any order. For mods that share
/// a name, whose order between themselves is not the point.
function firstFew(text, wanted) {
  const top = ids(text).slice(0, wanted.length);
  assert.deepEqual([...top].sort(), [...wanted].sort(), shown(text));
}

/// Every one of these is listed somewhere.
function finds(text, ...wanted) {
  const found = new Set(ids(text));
  for (const id of wanted) assert.ok(found.has(id), `${id} missing. ${shown(text)}`);
}

/// None of these is listed.
function misses(text, ...unwanted) {
  const found = new Set(ids(text));
  for (const id of unwanted) assert.ok(!found.has(id), `${id} listed. ${shown(text)}`);
}

/// Exactly these are listed, in any order.
function exactly(text, wanted) {
  assert.deepEqual([...ids(text)].sort(), [...wanted].sort(), shown(text));
}

/// Both are listed and the first is above the second.
function above(text, higher, lower) {
  const found = ids(text);
  const a = found.indexOf(higher);
  const b = found.indexOf(lower);
  assert.ok(a >= 0, `${higher} missing. ${shown(text)}`);
  assert.ok(b >= 0, `${lower} missing. ${shown(text)}`);
  assert.ok(a < b, `${higher} (#${a + 1}) should be above ${lower} (#${b + 1}). ${shown(text)}`);
}

/// Nothing is listed.
const nothing = (text) => exactly(text, []);

/// Every mod is listed: there was nothing to look for.
const everything = (text) => exactly(text, everyId);

/// The ids of the mods a test works out for itself from the fixture.
const idsWhere = (keep) => fixture.filter(keep).map((mod) => mod.id);

/// Whether any of a mod's own search terms holds the cleaned-up word as it
/// is, without any close-spelling help.
const plainlyHolds = (mod, word) =>
  searchTerms(mod).some((tag) => tag.term.includes(normalize(word)));

const DARK_REVENANT = ['graphicslib', 'interstellar-imperium', 'ship-weapon-pack',
  'starsector', 'underworld'];
const COMPUTICA = ['blackrock-drive-yards-2', 'fsf-military-corporation',
  'junk-pirates-2', 'stellar-networks-2', 'valkyrians-2'];
const SIR_HARTLEY = ['useful-tithes-1-0-a', 'disco-balls-1-1-c-more-lamp-colour-options',
  'grand-colonies', 'illustrated-entities', 'kaleidoscope', 'industrial-evolution'];
const WISPBORNE = ['exotica-technologies', 'magiclib', 'trios-launcher-mod-manager-toolkit',
  'shadowyards-reconstruction-authority'];
const SEEKERS = ['seeker', 'seeker-unidentified-contact', 'seeker-unknown-contact',
  'torched-seeker-1-0c-unofficial-fork-of-torchships-and-seeker'];

// --- The clean-up ---

describe('normalize', () => {
  const cases = [
    ['Seeker - Unidentified Contact', 'seeker unidentified contact'],
    ["Amazigh's Ship Foundry", 'amazighs ship foundry'],
    ['M’s Mod', 'ms mod'],
    ['Re:  mepgear´s bullships v0.1.0', 're mepgears bullships v0.1.0'],
    ['Starsector en Español', 'starsector en espanol'],
    ['0.98a-RC8', '0.98a rc8'],
    ['Useful.Tithes 1.0.a', 'useful tithes 1.0 a'],
    ['Disco.Balls 1.1.c', 'disco balls 1.1 c'],
    ['Ship/Weapon Pack', 'ship weapon pack'],
    ["Black Lion Ships v1.0.0 — Unique Lion's Guard Encounter",
      'black lion ships v1.0.0 unique lions guard encounter'],
    ['Better Vanilla Hullmods v0.8.0 - Shield Invictus ECM Maxxing edition™',
      'better vanilla hullmods v0.8.0 shield invictus ecm maxxing edition'],
    ['TriOS: Launcher/Mod Manager/Toolkit', 'trios launcher mod manager toolkit'],
    ['Iron Shell (DEV) ((probably scuffed))', 'iron shell dev probably scuffed'],
    ['Starsector+', 'starsector'],
    ['ATTD+ - All the Domain Drones+', 'attd all the domain drones'],
    ['ＳＷＰ', 'swp'],
    ['Crème Brûlée', 'creme brulee'],
    ['星际 Mod', '星际 mod'],
    // Marks come off in every alphabet, so "й" becomes "и" as "ё" becomes "е".
    // Typed text is cleaned the same way, so it still matches.
    ['Звёздный сектор', 'звездныи сектор'],
    ['  lots   of    spaces  ', 'lots of spaces'],
    ['tab\tand\nnewline', 'tab and newline'],
    ['.98', '98'],
    ['1.', '1'],
    ['v.2', 'v 2'],
    ['a.b', 'a b'],
    ['10.5.3', '10.5.3'],
    ['Dark.Revenant', 'dark revenant'],
    ['nathan_the_grudge_bearer', 'nathan the grudge bearer'],
    ['', ''],
    ['---', ''],
    ['!!!', ''],
    ["'", ''],
  ];
  for (const [input, expected] of cases) {
    test(`${JSON.stringify(input)} → ${JSON.stringify(expected)}`, () => {
      assert.equal(normalize(input), expected);
    });
  }

  test('nothing at all comes back as empty text', () => {
    assert.equal(normalize(null), '');
    assert.equal(normalize(undefined), '');
  });

  test('cleaning up twice changes nothing', () => {
    for (const [input] of cases) {
      assert.equal(normalize(normalize(input)), normalize(input), JSON.stringify(input));
    }
  });
});

describe('editDistance', () => {
  const cases = [
    ['tahlan', 'tahlan', 0],
    ['tahaln', 'tahlan', 1], // two letters swapped
    ['nexerlin', 'nexerelin', 1], // a letter missing
    ['nexerelinn', 'nexerelin', 1], // a letter extra
    ['nexrelin', 'nexerelin', 1],
    ['tartiflete', 'tartiflette', 1],
    ['histadine', 'histidine', 1], // a letter wrong
    ['avoinics', 'avionics', 1],
    ['collection', 'collective', 2],
    ['kitten', 'sitting', 3],
    ['', 'abc', 3],
    ['ab', 'ba', 1],
  ];
  for (const [a, b, expected] of cases) {
    test(`${a} ↔ ${b} is ${expected}`, () => {
      assert.equal(editDistance(a, b), expected);
      assert.equal(editDistance(b, a), expected);
    });
  }
});

// --- The bug that started this ---

describe('the name as people type it', () => {
  const typings = [
    'seeker unidentified contact',
    'Seeker Unidentified Contact',
    'SEEKER UNIDENTIFIED CONTACT',
    'Seeker - Unidentified Contact',
    'Seeker — Unidentified Contact',
    'seeker: unidentified contact',
    'seeker-unidentified-contact',
    '  seeker   unidentified   contact  ',
    'seeker unidentified',
    'seeker unid',
    'unidentified contact',
    'contact seeker unidentified',
    'unidentified',
  ];
  for (const text of typings) {
    test(JSON.stringify(text), () => first(text, 'seeker-unidentified-contact'));
  }

  test('the other Seeker mods are each found by their own name', () => {
    first('seeker unknown contact', 'seeker-unknown-contact');
    first('Seeker - Unknown Contact', 'seeker-unknown-contact');
    first('torched seeker', 'torched-seeker-1-0c-unofficial-fork-of-torchships-and-seeker');
  });

  test('"seeker" alone lists all four, the one called just that first', () => {
    first('seeker', 'seeker');
    finds('seeker', ...SEEKERS);
  });

  test('a name starting with the word beats one with it further in', () => {
    above('seeker', 'seeker-unidentified-contact',
      'torched-seeker-1-0c-unofficial-fork-of-torchships-and-seeker');
  });

  test('the two contacts are told apart', () => {
    misses('seeker unknown contact', 'seeker-unidentified-contact');
    misses('seeker unidentified contact', 'seeker-unknown-contact');
  });

  test('words shared by both list both, in either order', () => {
    firstFew('contact seeker', ['seeker-unidentified-contact', 'seeker-unknown-contact']);
    firstFew('seeker contact', ['seeker-unidentified-contact', 'seeker-unknown-contact']);
  });
});

// --- Punctuation, apostrophes and accents ---

describe('apostrophes', () => {
  for (const text of ['amazighs', "amazigh's", 'amazigh’s ship', "Amazigh's Ship Foundry",
    'amazighs ship foundry']) {
    test(JSON.stringify(text), () => first(text, 'amazigh-s-ship-foundry'));
  }

  test('the plain name finds both of that author\'s mods', () => {
    finds('amazigh', 'amazigh-s-ship-foundry', 'rotcesrats');
  });

  for (const text of ['ms mod', "m's mod", 'M’s Mod']) {
    test(JSON.stringify(text), () => first(text, 'm-s-mod'));
  }

  for (const text of ['mepgears', "mepgear's bullships", 'mepgear´s', 'mepgear`s bullships',
    're: mepgear', 'Re: mepgear´s bullships']) {
    test(JSON.stringify(text), () => first(text, 're-mepgear-s-bullships'));
  }

  for (const text of ['arthrs ships', "arthr's ships", 'ships n shit', "ships n' shit"]) {
    test(JSON.stringify(text), () => first(text, 'arthr-s-ships-n-shit-pre-release'));
  }

  for (const text of ["lion's guard", 'lions guard encounter', 'black lion',
    "Black Lion Ships v1.0.0 — Unique Lion's Guard Encounter",
    'black lion ships unique lions guard encounter']) {
    test(JSON.stringify(text), () => first(text, 'black-lion-ships-unique-lion-s-guard-encounter'));
  }

  for (const text of ["vayra's sector", 'vayras sector', 'Vayra’s Sector']) {
    test(JSON.stringify(text), () => first(text, 'vayra-s-sector'));
  }

  test("vayra's ship pack", () => first("vayra's ship pack", 'vayra-s-ship-pack'));
});

describe('accents and other alphabets', () => {
  for (const text of ['espanol', 'español', 'ESPAÑOL', 'starsector en espanol',
    'Starsector en Español']) {
    test(JSON.stringify(text), () => first(text, 'starsector-en-espa-ol-spanish-translation'));
  }

  test('full-width letters', () => first('ＳＷＰ', 'ship-weapon-pack'));
});

describe('dots, slashes and pluses in names', () => {
  for (const text of ['useful tithes', 'usefultithes', 'useful.tithes', 'Useful.Tithes 1.0.a',
    'tithes']) {
    test(JSON.stringify(text), () => first(text, 'useful-tithes-1-0-a'));
  }
  for (const text of ['disco balls', 'discoballs', 'disco.balls']) {
    test(JSON.stringify(text), () => first(text, 'disco-balls-1-1-c-more-lamp-colour-options'));
  }
  for (const text of ['grand colonies', 'grand.colonies', 'grandcolonies']) {
    test(JSON.stringify(text), () => first(text, 'grand-colonies'));
  }
  test('illustrated entities', () => first('illustrated entities', 'illustrated-entities'));

  for (const text of ['ship weapon pack', 'ship/weapon pack', 'Ship/Weapon Pack', 'shipweapon',
    'shipweaponpack', 'swp']) {
    test(JSON.stringify(text), () => first(text, 'ship-weapon-pack'));
  }
  test('the full name beats a longer name holding it', () => {
    above('ship weapon pack', 'ship-weapon-pack', 'scav-co-ship-weapon-pack');
    above('swp', 'ship-weapon-pack', 'scav-co-ship-weapon-pack');
  });

  for (const text of ['scav-co', 'scavco', 'scav co ship weapon pack', 'SCAV-CO Ship/Weapon Pack']) {
    test(JSON.stringify(text), () => first(text, 'scav-co-ship-weapon-pack'));
  }

  for (const text of ['trios', 'TriOS', 'trios launcher', 'TriOS: Launcher/Mod Manager/Toolkit']) {
    test(JSON.stringify(text), () => first(text, 'trios-launcher-mod-manager-toolkit'));
  }

  for (const text of ['starsector+', 'Starsector+', 'starsector', 'starsector +']) {
    test(JSON.stringify(text), () => first(text, 'starsector'));
  }

  for (const text of ['attd', 'ATTD+', 'attd+', 'all the domain drones']) {
    test(JSON.stringify(text), () => first(text, 'attd-all-the-domain-drones'));
  }

  for (const text of ['second in command', 'second-in-command', 'Second-in-Command',
    'secondincommand', 'sic']) {
    test(JSON.stringify(text), () => first(text, 'second-in-command'));
  }
  test('its add-on comes next, and a mod that only mentions it after that', () => {
    above('second in command', 'second-in-command-auxiliaries', 'dustkeeper-xo');
    above('sic', 'second-in-command', 'second-in-command-auxiliaries');
  });

  for (const text of ['va11 hall-a', 'va11 hall a', 'va11']) {
    test(JSON.stringify(text), () => first(text, 'va11-hall-a-portrait-pack'));
  }
  test('va-11 hall-a, as the game itself is written', () => {
    finds('va-11 hall-a', 'va11-hall-a-portrait-pack');
  });

  test('a dash inside a word is not a minus', () => {
    finds('sci-fi', 'wow-portraits');
    finds('x-8', 'scav-co-ship-weapon-pack');
  });

  test('brackets and parentheses in a name', () => {
    finds('(dev)', 'iron-shell-dev-probably-scuffed-im-sorry-save-compatible');
    finds('[wip]', 'united-aurora-federation');
    finds('iron shell dev', 'iron-shell-dev-probably-scuffed-im-sorry-save-compatible');
    first('tidal fork', 'diable-avionics-tidal-fork');
    first('(TIDAL FORK)', 'diable-avionics-tidal-fork');
  });
});

// --- Words in any order, from different facts ---

describe('words in any order', () => {
  for (const text of ['battlestar portrait', 'portrait battlestar', 'galactica',
    'battlestar galactica', 'Battlestar Galactica - Portrait Pack']) {
    test(JSON.stringify(text), () => first(text, 'battlestar-galactica-portrait-pack'));
  }

  test('words little and large are both kept', () => {
    first('ashes domain', 'ashes-of-the-domain');
    first('knights ludd', 'the-knights-of-ludd');
  });

  test('the name and the author in one search', () => {
    first('kadur timid', 'kadur-remnant-2');
    misses('kadur timid', 'kadur-remnant');
    first('kadur vayra', 'kadur-remnant');
    misses('kadur vayra', 'kadur-remnant-2');
    first('valkyrians computica', 'valkyrians-2');
    first('stellar networks computica', 'stellar-networks-2');
    first('tartiflette seeker', 'seeker');
    misses('tartiflette seeker', 'torched-seeker-1-0c-unofficial-fork-of-torchships-and-seeker');
  });

  test('the name and a category in one search', () => {
    finds('diable factions', 'diable-avionics', 'diable-avionics-tidal-fork');
    misses('diable factions', 'diable-armaonics');
  });

  test('every word has to match', () => {
    nothing('seeker nexerelin');
    nothing('lazylib portrait');
  });

  test('a word is never made by running two facts together', () => {
    nothing('nexerelincampaign');
    nothing('lazylibraries');
  });

  test('saying a word twice changes nothing', () => {
    exactly('seeker seeker', ids('seeker'));
  });

  test('which of Tartiflette\'s Diable mods', () => {
    finds('diable tartiflette', 'diable-avionics', 'diable-avionics-2',
      'diable-avionics-original-flavor-2');
    misses('diable tartiflette', 'diable-avionics-tidal-fork', 'diable-armaonics');
  });
});

// --- What comes first ---

describe('exact names come first', () => {
  const cases = [
    ['nexerelin', 'nexerelin'],
    ['NeXeReLiN', 'nexerelin'],
    ['console commands', 'console-commands'],
    ['consolecommands', 'console-commands'],
    ['console', 'console-commands'],
    ['tolerant luddic majority', 'tolerant-luddic-majority'],
    ['brighton federation', 'brighton-federation'],
    ['the brighton federation', 'the-brighton-federation'],
    ['interstellar federation', 'interstellar-federation'],
    ['portrait pack', 'portrait-pack'],
    ['rat', 'rat'],
    ['RAT', 'rat'],
    ['random assortment of things', 'random-assortment-of-things'],
    ['scy nation', 'scy-nation'],
    ['iron shell', 'iron-shell'],
    ['exotica', 'exotica-technologies'],
    ['underworld', 'underworld'],
    ['kaleidoscope', 'kaleidoscope'],
    ['magiclib', 'magiclib'],
    ['magic lib', 'magiclib'],
    ['lazylib', 'lazylib'],
    ['lazy lib', 'lazylib'],
    ['graphicslib', 'graphicslib'],
    ['graphics lib', 'graphicslib'],
    ['tahlan', 'tahlan-shipworks'],
    ['tahlan shipworks', 'tahlan-shipworks'],
    ['qol', 'qol-pack'],
    ['qol pack', 'qol-pack'],
    ['dark qol', 'dark-qol'],
    ['qbmbamm', 'qb-mod-browser-and-mod-manager-qbmbamm'],
    ['aotd', 'ashes-of-the-domain'],
    ['ashes', 'ashes-of-the-domain'],
    ['ashes of the domain', 'ashes-of-the-domain'],
    ['knights of ludd', 'the-knights-of-ludd'],
    ['the knights of ludd', 'the-knights-of-ludd'],
    ['knights hospitaller', 'knights-hospitaller-unique-luddic-church-quest-ship-questline'],
    ['missing ships', 'missing-ships-mod'],
    ['missiles and sundry', 'missiles-and-sundry'],
    ['sunrider', 'sunrider'],
    ['sundiving', 'sundiving'],
    ['polaris prime', 'polaris-prime'],
    ['price of command', 'price-of-command'],
    ['target practice', 'target-practice'],
    ['uma musume', 'uma-musume-portrait-pack'],
    ["girls' frontline 2", 'girls-frontline-2-exilium-portraits-pack'],
    ['exilium', 'girls-frontline-2-exilium-portraits-pack'],
    ['apex design collective', 'apex-design-collective'],
    ['apex peak', 'apex-design-collective-skin-peak'],
    ['hazard mining', 'hazard-mining-incorporated'],
    ['better vanilla hullmods', 'better-vanilla-hullmods-shield-invictus-ecm-maxxing-edition'],
    ['maxxing edition', 'better-vanilla-hullmods-shield-invictus-ecm-maxxing-edition'],
    ['privateering', 'privateering-commission-overhaul'],
    ['commissioned crews', 'commissioned-crews'],
    ['luddic enhancement', 'luddic-enhancement-mod'],
    ['weebshit', 'weebshit-ai-portrait-pack'],
    ['pirate mini mod', 'pirate-mini-mod'],
    ['pirate utility pack', 'pirate-utility-pack'],
  ];
  for (const [text, id] of cases) {
    test(JSON.stringify(text), () => first(text, id));
  }

  test('mods sharing a name come first together', () => {
    // "HMI" is both a word in one name and the initials of another.
    firstFew('hmi', ['hmi-supervillians', 'hazard-mining-incorporated']);
    firstFew('scy', ['scy', 'scy-2']);
    firstFew('unknown skies', ['unknown-skies', 'unknown-skies-2']);
    firstFew('diable avionics', ['diable-avionics', 'diable-avionics-2']);
    firstFew('random assortment', ['random-assortment-of-things', 'random-assortment-of-battlegroups']);
    firstFew('stellar networks', ['stellar-networks', 'stellar-networks-2']);
    firstFew('valkyrians', ['valkyrians', 'valkyrians-2']);
    firstFew('junk pirates', ['junk-pirates', 'junk-pirates-2']);
    firstFew('blackrock', ['blackrock-drive-yards', 'blackrock-drive-yards-2']);
    firstFew('kadur', ['kadur-remnant', 'kadur-remnant-2']);
    firstFew('pirate collection', ['pirate-collection', 'pirate-collection-2']);
    firstFew('more tolerant luddic majority',
      ['more-tolerant-luddic-majority', 'more-tolerant-luddic-majority-2']);
  });

  test('a longer name holding the search comes after the exact one', () => {
    above('console commands', 'console-commands', 'additional-console-commands');
    above('tolerant luddic majority', 'tolerant-luddic-majority', 'more-tolerant-luddic-majority');
    above('brighton federation', 'brighton-federation', 'the-brighton-federation');
    above('scy', 'scy-2', 'scy-nation');
    above('diable avionics', 'diable-avionics-2', 'diable-avionics-skin-luxurious-bronze');
    above('interstellar federation', 'interstellar-federation',
      'interstellar-federation-refurbished');
    above('knights of ludd', 'the-knights-of-ludd',
      'knights-hospitaller-unique-luddic-church-quest-ship-questline');
    above('qol', 'qol-pack', 'dark-qol');
    above('rat', 'rat', 'pirate-mini-mod');
  });
});

describe('better matches come first', () => {
  test('the start of a word beats the middle of one', () => {
    above('sector', 'vayra-s-sector', 'starsector');
  });

  test('a name beats a summary', () => {
    above('pirate', 'pirate-mini-mod', 'underworld');
    above('ship', 'ship-weapon-pack', 'seeker');
    // Was "underworld" against Vayra's Sector, whose summary never says
    // "underworld", so it was never going to be listed at all.
    above('starsector', 'starsector', 'lazylib');
  });

  test('a name starting with the word beats a name with it later on', () => {
    above('pirate', 'pirate-collection', 'junk-pirates');
    above('pirate', 'pirate-utility-pack', 'arthr-s-pirates-but-epicer-mrmagolor-edition-1-3-1-fool-me-not-at-all');
    above('ship', 'ship-weapon-pack', 'amazigh-s-ship-foundry');
    above('luddic', 'luddic-enhancement-mod', 'tolerant-luddic-majority');
  });

  test('a person beats a summary that mentions them', () => {
    above('tartiflette', 'seeker', 'seeker-unidentified-contact');
    above('tartiflette', 'magiclib', 'seeker-unidentified-contact');
  });

  test('an acronym that is exactly the search beats one that holds it', () => {
    above('swp', 'ship-weapon-pack', 'scav-co-ship-weapon-pack');
  });

  test('a mod mentioning another in its summary comes after that mod', () => {
    above('second in command', 'second-in-command', 'dustkeeper-xo');
    above('diable', 'diable-avionics', 'project-mistral-a-diable-armaa-expansion-mod');
  });
});

// --- People ---

describe('people', () => {
  test('one person\'s mods', () => {
    exactly('computica', COMPUTICA);
    exactly('hartley', SIR_HARTLEY);
    exactly('sirhartley', SIR_HARTLEY);
    exactly('sir hartley', SIR_HARTLEY);
    finds('dark.revenant', ...DARK_REVENANT);
    finds('dark revenant', ...DARK_REVENANT);
    finds('darkrevenant', ...DARK_REVENANT);
    finds('Dark Revenant', ...DARK_REVENANT);
    finds('wisp', 'exotica-technologies', 'magiclib', 'trios-launcher-mod-manager-toolkit');
    finds('wispborne', 'exotica-technologies', 'magiclib', 'trios-launcher-mod-manager-toolkit');
    finds('lukas', 'rat', 'random-assortment-of-things', 'second-in-command',
      'privateering-commission-overhaul', 'console-commands', 'exotica-technologies');
    finds('lukas04', 'rat', 'second-in-command', 'console-commands');
  });

  test('a person\'s other known names', () => {
    finds('techpriest', 'commissioned-crews', 'iron-shell', 'kadur-remnant-2');
    finds('histidine_my', 'nexerelin');
    finds('spiritfox', 'pirate-utility-pack');
    finds('arkmagius', 'lazylib', 'console-commands');
  });

  test('two spellings of one person', () => {
    finds('king alfonzo', 'hazard-mining-incorporated', 'the-brighton-federation',
      'luddic-enhancement-mod');
    finds('kingalfonzo', 'hmi-supervillians', 'brighton-federation',
      'hazard-mining-incorporated', 'the-brighton-federation');
  });

  test('a name with odd punctuation', () => {
    finds('arthr', 'arthr-s-ships-n-shit-pre-release');
    finds('.arthr.', 'arthr-s-ships-n-shit-pre-release');
    finds('nathan the grudge bearer', 'attd-all-the-domain-drones');
    finds('nathan_the_grudge_bearer', 'attd-all-the-domain-drones');
    finds('p.m.damon', 'the-knights-of-ludd');
    finds('pm damon', 'the-knights-of-ludd');
    finds('nia tahl', 'tahlan-shipworks');
  });
});

// --- Close spellings ---

describe('close spellings', () => {
  const cases = [
    ['nexerlin', 'nexerelin'],
    ['nexrelin', 'nexerelin'],
    ['nexereiln', 'nexerelin'],
    ['nexerelinn', 'nexerelin'],
    ['Nexerlin', 'nexerelin'],
    ['tahaln', 'tahlan-shipworks'],
    ['talhan shipworks', 'tahlan-shipworks'],
    ['tahlan shipwroks', 'tahlan-shipworks'],
    ['histadine', 'nexerelin'],
    ['seeker unidentifed contact', 'seeker-unidentified-contact'],
    ['seeker unidentifed', 'seeker-unidentified-contact'],
    ['second in comand', 'second-in-command'],
    ['magiclbi', 'magiclib'],
    ['graphiclib', 'graphicslib'],
    ['kaliedoscope', 'kaleidoscope'],
    ['underwrold', 'underworld'],
    ['exoitca', 'exotica-technologies'],
    ['ashes of the domian', 'ashes-of-the-domain'],
    ['battlestar galatica', 'battlestar-galactica-portrait-pack'],
    ['amazihg', 'amazigh-s-ship-foundry'],
  ];
  for (const [text, id] of cases) {
    test(JSON.stringify(text), () => first(text, id));
  }

  test('a close spelling of a person', () => {
    finds('tartiflete', 'seeker', 'scy-2', 'magiclib', 'target-practice');
    finds('computca', ...COMPUTICA);
  });

  test('a close spelling inside a longer search', () => {
    finds('diable avoinics', 'diable-avionics', 'diable-avionics-2');
  });

  test('a half-typed word with a mistake in it', () => {
    first('nexerl', 'nexerelin');
    finds('tahln', 'tahlan-shipworks');
  });

  test('only what it is close to: one misspelt mod, not a crowd', () => {
    exactly('nexerlin', ['nexerelin']);
    exactly('tahaln', ['tahlan-shipworks']);
  });

  test('a misspelling somebody wrote in a summary', () => {
    // Luddic Enhancement's summary spells it "Nexerellin". That must not
    // stop the real Nexerelin being found, or push it below.
    finds('nexerellin', 'nexerelin', 'luddic-enhancement-mod');
    above('nexerellin', 'nexerelin', 'luddic-enhancement-mod');
  });

  test('common words bring in nothing that does not hold them', () => {
    for (const word of ['portrait', 'pirate', 'faction', 'federation', 'luddic', 'campaign',
      'library']) {
      for (const mod of searchMods(fixture, word)) {
        assert.ok(plainlyHolds(mod, word), `${mod.id} listed for ${word} without holding it`);
      }
    }
  });

  test('a real near-miss is listed below the names that really match', () => {
    // "collection" is two letters from "Collective". That is a fair guess, as
    // long as it never beats a mod whose name really says "collection". It may
    // beat a mod that only says it in its summary: a close name is worth more
    // than a word in a paragraph, which is what finds Nexerelin above.
    above('collection', 'pirate-collection', 'apex-design-collective');
    above('collection', 'pirate-collection-2', 'apex-design-collective');
  });

  test('a close spelling has to start with the right letter', () => {
    // Almost every typo keeps the first letter. Without this, "faction" is
    // one letter from "action" and finds Fleet Action History.
    nothing('rexerelin');
    misses('faction', 'fleet-action-history');
  });

  test('short words are not guessed at', () => {
    nothing('magc');
    nothing('qxzv');
    // Was "lazl", but that is "Laz-y L-ib" run together, which the shorthand
    // rule rightly finds.
    nothing('lzay');
  });

  test('numbers are not guessed at', () => {
    misses('0.99', 'nexerelin');
    misses('0.97', 'nexerelin');
    misses('1.7.2', 'amazigh-s-ship-foundry');
  });

  test('a minus word is not guessed at', () => {
    // Nobody is called "tartiflete", so nothing is taken out.
    finds('seeker -tartiflete', ...SEEKERS);
  });

  test('nonsense finds nothing', () => {
    nothing('xyzzy');
    nothing('qwertyuiop');
    nothing('zzzzzzzzzz');
  });
});

// --- Shorthand ---

describe('common shorthand', () => {
  // Every one of these is how people write the mod's name on the forum and on
  // Discord, and none of them is in the mod's name as written.
  const cases = [
    // The start of each word, run together.
    ['indevo', 'industrial-evolution'],
    ['IndEvo', 'industrial-evolution'],
    ['grandcol', 'grand-colonies'],
    ['armaa', 'arma-armatura'],
    // The first letter of each word, the little words left out or kept.
    ['kol', 'the-knights-of-ludd'],
    ['tkol', 'the-knights-of-ludd'],
    ['uaf', 'united-aurora-federation'],
    ['dme', 'dassault-mikoyan-engineering'],
    ['sotf', 'secrets-of-the-frontier'],
    ['aotd', 'ashes-of-the-domain'],
    ['vic', 'volkov-industrial-conglomerate'],
    ['thi', 'tiandong-heavy-industries'],
    ['sra', 'shadowyards-reconstruction-authority'],
    ['tsc', 'tyrador-safeguard-coalition'],
    ['ii', 'interstellar-imperium'],
    ['ae', 'arsenal-expansion'],
    ['bc', 'better-colonies'],
    ['sic', 'second-in-command'],
    // A name written in one piece with capitals inside it.
    ['gl', 'graphicslib'],
    ['ml', 'magiclib'],
    // The start of the name.
    ['nex', 'nexerelin'],
    ['tahl', 'tahlan-shipworks'],
    ['magic', 'magiclib'],
    ['lazy', 'lazylib'],
    // A nickname nothing in the name gives away, from the nickname table.
    ['ssp', 'starsector'],
  ];
  for (const [text, id] of cases) {
    test(JSON.stringify(text), () => first(text, id));
  }

  test('a nickname shared by a mod and its fork finds both', () => {
    firstFew('brdy', ['blackrock-drive-yards', 'blackrock-drive-yards-2']);
  });

  test('both ED Shipyards come first', () => {
    firstFew('ed shipyard', ['ed-shipyard', 'ed-shipyard-2']);
    firstFew('edshipyard', ['ed-shipyard', 'ed-shipyard-2']);
  });

  test('shorthand works beside other words', () => {
    first('indevo hartley', 'industrial-evolution');
    first('kol 0.98', 'the-knights-of-ludd');
    exactly('author:sirhartley indevo', ['industrial-evolution']);
  });

  test('shorthand ranks below a mod whose name really is those letters', () => {
    // "RAT" is a mod's whole name, and also the initials of Random Assortment
    // of Things. The one called that comes first; the other still turns up.
    first('rat', 'rat');
    finds('rat', 'random-assortment-of-things');
    // Project MISTRAL's name holds the word "ArmaA", but the nickname table
    // says whose shorthand it is.
    above('armaa', 'arma-armatura', 'project-mistral-a-diable-armaa-expansion-mod');
  });

  test('two letters are only ever a whole name\'s initials', () => {
    // Runs of word starts need three letters or more, or "ae" would match
    // every name with an "a…" word next to an "e…" word.
    first('ae', 'arsenal-expansion');
    // "Starsector en Español" has "en" next to "Español", but two letters are
    // not enough for a run of word starts, so only real matches come back.
    for (const mod of searchMods(fixture, 'ee')) {
      assert.ok(plainlyHolds(mod, 'ee'), `${mod.id} listed for ee without holding it`);
    }
  });

  test('word starts only count in whole steps', () => {
    // "f" + "action" is not how anybody writes Fleet Action History. A run of
    // word starts is either one letter from every word, or two or more from
    // every word but the last.
    misses('faction', 'fleet-action-history');
    finds('fah', 'fleet-action-history');
    finds('fleact', 'fleet-action-history');
  });

  test('word starts must come from words next to each other', () => {
    misses('vicon', 'volkov-industrial-conglomerate');
    finds('volind', 'volkov-industrial-conglomerate');
  });

  test('part of a nickname works too', () => {
    finds('brd', 'blackrock-drive-yards');
  });

  test('a nickname the author\'s post uses, from the mod\'s own record', () => {
    // The real records carry these only once every topic has been read again
    // with the prompt that asks for them, so these mods are made up for it.
    const mods = [
      { id: 'pirates-and-pathers', name: "Yunru's Pirates and Pathers",
        nicknames: ['Pirate Collection'] },
      { id: 'pirate-collection', name: 'Pirate Collection' },
      { id: 'yunrucore', name: 'YunruCore' },
      { id: 'swp', name: 'Ship/Weapon Pack', nicknames: ['SWP'] },
    ];
    const found = (text) => searchMods(mods, text).map((mod) => mod.id);
    // A mod really called that and one whose post says it used to be called
    // that are both what the reader could mean.
    assert.deepEqual([...found('pirate collection').slice(0, 2)].sort(),
      ['pirate-collection', 'pirates-and-pathers']);
    assert.ok(!found('pirate collection').includes('yunrucore'));
    assert.equal(found('swp')[0], 'swp');
    assert.equal(found('"pirate collection"').length, 2);
  });
});

// --- Quotes ---

describe('quoted phrases', () => {
  test('a phrase in order', () => {
    exactly('"unknown contact"', ['seeker-unknown-contact']);
    first('"seeker - unknown contact"', 'seeker-unknown-contact');
    first('"Unknown Contact"', 'seeker-unknown-contact');
  });

  test('a phrase out of order finds nothing', () => {
    nothing('"contact unknown"');
    nothing('"contact seeker"');
  });

  test('a phrase must sit inside one fact', () => {
    nothing('"nexerelin campaign"');
  });

  test('a quote with no closing mark runs to the end', () => {
    exactly('"unknown contact', ['seeker-unknown-contact']);
  });

  test('a phrase beside plain words', () => {
    exactly('"unknown contact" tartiflette', ['seeker-unknown-contact']);
    exactly('seeker "unidentified contact"', ['seeker-unidentified-contact']);
  });

  test('a comma inside quotes is part of the phrase', () => {
    finds('"church quest, ship"', 'knights-hospitaller-unique-luddic-church-quest-ship-questline');
  });

  test('a phrase is cleaned up like everything else', () => {
    first('"lion\'s guard"', 'black-lion-ships-unique-lion-s-guard-encounter');
    first('"ship/weapon"', 'ship-weapon-pack');
  });

  test('a quoted minus is a phrase, not a minus', () => {
    finds('"-portrait"', 'portrait-pack');
  });
});

// --- Commas, minus and plus ---

describe('commas mean any of these', () => {
  test('two groups widen the list', () => {
    finds('faction, portrait', 'the-knights-of-ludd', 'battlestar-galactica-portrait-pack');
    finds('nexerelin, lazylib', 'nexerelin', 'lazylib');
    finds('nexerelin,lazylib', 'nexerelin', 'lazylib');
    finds('seeker unknown contact, nexerelin', 'seeker-unknown-contact', 'nexerelin');
  });

  test('each group is scored on its own, and the best one speaks for the mod', () => {
    first('nexerelin, faction', 'nexerelin');
  });

  test('empty groups are ignored', () => {
    exactly('nexerelin,', ids('nexerelin'));
    exactly(', , nexerelin , ,', ids('nexerelin'));
  });
});

describe('a minus leaves mods out', () => {
  test('a minus group takes mods out of everything else', () => {
    finds('faction, -portrait', 'the-knights-of-ludd');
    misses('faction, -portrait', 'battlestar-galactica-portrait-pack', 'weebshit-ai-portrait-pack');
  });

  test('a minus word inside a group', () => {
    finds('pirate -junk', 'pirate-mini-mod', 'pirate-utility-pack');
    misses('pirate -junk', 'junk-pirates', 'junk-pirates-2');
    finds('diable -skin', 'diable-avionics');
    misses('diable -skin', 'diable-avionics-skin-luxurious-bronze');
    misses('portrait pack -girls', 'girls-frontline-portrait-pack',
      'girls-frontline-2-exilium-portraits-pack');
    finds('portrait pack -girls', 'portrait-pack');
  });

  test('a minus field', () => {
    exactly('seeker -author:tartiflette', ['seeker-unidentified-contact',
      'torched-seeker-1-0c-unofficial-fork-of-torchships-and-seeker']);
  });

  test('a minus phrase', () => {
    misses('seeker -"unknown contact"', 'seeker-unknown-contact');
    finds('seeker -"unknown contact"', 'seeker', 'seeker-unidentified-contact');
  });

  test('only minus words start from every mod', () => {
    exactly('-portrait', idsWhere((mod) => !plainlyHolds(mod, 'portrait')));
    exactly('-portrait -faction',
      idsWhere((mod) => !plainlyHolds(mod, 'portrait') && !plainlyHolds(mod, 'faction')));
    exactly('-portrait, -faction',
      idsWhere((mod) => !plainlyHolds(mod, 'portrait') && !plainlyHolds(mod, 'faction')));
  });

  test('a mod let in and then left out stays out', () => {
    nothing('nexerelin, -nexerelin');
    nothing('nexerelin -nexerelin');
  });

  test('a bare minus is ignored', () => {
    everything('-');
    exactly('seeker -', ids('seeker'));
    exactly('seeker - ', ids('seeker'));
  });
});

describe('a plus is a space', () => {
  test('both words must match', () => {
    exactly('hartley + tithes', ['useful-tithes-1-0-a']);
    exactly('hartley+tithes', ['useful-tithes-1-0-a']);
    exactly('hartley tithes', ['useful-tithes-1-0-a']);
  });

  test('the same answer as a space, in the same order', () => {
    for (const [plus, space] of [['seeker + tartiflette', 'seeker tartiflette'],
      ['diable + factions', 'diable factions'], ['portrait + pack', 'portrait pack']]) {
      assert.deepEqual(ids(plus), ids(space), `${plus} vs ${space}`);
    }
  });

  test('a bare plus is ignored', () => {
    everything('+');
    everything('+ + +');
  });
});

// --- Fields ---

describe('asking about one field', () => {
  test('author', () => {
    exactly('author:computica', COMPUTICA);
    exactly('AUTHOR:Computica', COMPUTICA);
    exactly('authors:computica', COMPUTICA);
    exactly('author:wisp', WISPBORNE);
    exactly('author:sirhartley', SIR_HARTLEY);
  });

  test('a person\'s name written any way', () => {
    exactly('author:dark.revenant', DARK_REVENANT);
    exactly('author:"Dark Revenant"', DARK_REVENANT);
    exactly('author:"dark.revenant"', DARK_REVENANT);
    exactly('author:DARK.REVENANT', DARK_REVENANT);
    // The value stops at the space, and "revenant" is then an ordinary word.
    // Dark.Revenant's own name holds it, so the answer is the same.
    exactly('author:dark revenant', DARK_REVENANT);
  });

  test('author does not look anywhere else', () => {
    // Tartiflette is named in three summaries, but credited on none of them.
    misses('author:tartiflette', 'seeker-unidentified-contact', 'diable-avionics-tidal-fork');
    finds('author:tartiflette', 'seeker', 'magiclib');
  });

  test('category', () => {
    exactly('category:libraries', ['graphicslib', 'lazylib', 'magiclib', 'price-of-command']);
    exactly('categories:libraries', ['graphicslib', 'lazylib', 'magiclib', 'price-of-command']);
    exactly('category:libraries magic', ['magiclib']);
    exactly('category:"portraits and flags" battlestar', ['battlestar-galactica-portrait-pack']);
  });

  test('versions', () => {
    exactly('version:0.65', idsWhere((mod) => normalize(mod.gameVersion).includes('0.65')));
    exactly('gameversion:0.98a-rc8', ['starsector-en-espa-ol-spanish-translation']);
    exactly('modversion:0.12.2c', ['nexerelin']);
    exactly('modversion:v1.7.1', ['amazigh-s-ship-foundry']);
  });

  test('name looks only at the name', () => {
    exactly('name:seeker', SEEKERS);
    exactly('name:"unknown contact"', ['seeker-unknown-contact']);
    misses('name:tartiflette', 'seeker');
  });

  test('summary', () => {
    exactly('summary:tartiflette',
      idsWhere((mod) => normalize(mod.summary).includes('tartiflette')));
  });

  test('source', () => {
    exactly('source:discord', idsWhere((mod) => (mod.sources || []).includes('discord')));
    exactly('source:forum -source:discord', idsWhere(
      (mod) => (mod.sources || []).includes('forum') && !(mod.sources || []).includes('discord')));
  });

  test('url', () => {
    const urls = (mod) => [mod.forumUrl, mod.discordUrl, mod.bestDownload && mod.bestDownload.url];
    exactly('url:github', idsWhere((mod) => urls(mod).some((u) => normalize(u).includes('github'))));
  });

  test('fields join the comma and minus rules', () => {
    exactly('category:libraries, -source:forum', ['price-of-command']);
    nothing('category:libraries magic, -source:discord');
    finds('author:computica, author:wisp', ...COMPUTICA, 'magiclib');
  });

  test('a key the site does not know is just words', () => {
    first('re: mepgear', 're-mepgear-s-bullships');
    assert.deepEqual(ids('foo:bar'), ids('foo bar'));
    first('seeker:unknown', 'seeker-unknown-contact');
  });

  test('a key with nothing after it is just the word', () => {
    assert.deepEqual(ids('author:'), ids('author'));
    assert.deepEqual(ids('author:""'), ids('author'));
  });
});

// --- Versions typed as plain words ---

describe('versions as plain words', () => {
  test('a game version', () => {
    finds('0.98', 'nexerelin', 'seeker-unidentified-contact');
    misses('0.98', 'seeker');
    finds('0.65.2a', 'seeker', 'starsector');
  });

  test('a version narrows a name', () => {
    exactly('seeker 0.98', ['seeker-unidentified-contact']);
    exactly('0.98 seeker', ['seeker-unidentified-contact']);
    exactly('seeker 0.65', ['seeker']);
  });

  test('a mod version', () => {
    first('nexerelin 0.12', 'nexerelin');
    first('v1.7.1', 'amazigh-s-ship-foundry');
    finds('1.7.1', 'amazigh-s-ship-foundry');
  });
});

// --- Nothing to look for ---

describe('nothing to look for lists every mod', () => {
  for (const text of ['', '   ', ',', ' , , ', '-', '+', '-,-', '""', '"', '---', '!!!',
    '™', '—', '\t', '- , +']) {
    test(JSON.stringify(text), () => everything(text));
  }

  test('with nothing to look for, the list keeps its own order', () => {
    assert.deepEqual(ids(''), everyId);
  });

  test('compileSearch says when it is empty', () => {
    assert.equal(compileSearch('', fixture).isEmpty, true);
    assert.equal(compileSearch(' - ', fixture).isEmpty, true);
    assert.equal(compileSearch('seeker', fixture).isEmpty, false);
    assert.equal(compileSearch('-seeker', fixture).isEmpty, false);
  });
});

// --- Strange input ---

describe('strange input never breaks anything', () => {
  const strange = ['(dev)', '[wip]', 'c++', '.*', '\\', '$^', '%', "'", '´', '`', '()', '[]',
    '{}', '|', '?', '*', ':', '::', 'key:value:more', 'author:"', '-author:', '-"', '"-',
    '🚀 ships', '\u0000', '​', '<script>', '&amp;', 'a'.repeat(500),
    'seeker '.repeat(100), '-'.repeat(100), ',,,,,,,,,,'];
  for (const text of strange) {
    test(JSON.stringify(text.length > 40 ? `${text.slice(0, 40)}…` : text), () => {
      assert.doesNotThrow(() => searchMods(fixture, text));
      assert.doesNotThrow(() => suggestMods(fixture, text, 5));
      assert.doesNotThrow(() => peopleMatching(fixture, text, 5));
    });
  }

  test('an emoji is ignored', () => {
    assert.deepEqual(ids('🚀 ships'), ids('ships'));
  });

  test('a very long search finds nothing rather than everything', () => {
    nothing('a'.repeat(500));
  });

  test('a mod with almost nothing filled in', () => {
    const bare = [{ id: 'bare', name: 'Bare Mod' }, { id: 'empty', name: '' },
      { id: 'nulls', name: 'Nulls', authors: null, categories: null, summary: null,
        otherAuthorNames: null, sources: null }];
    assert.deepEqual(searchMods(bare, 'bare').map((m) => m.id), ['bare']);
    assert.deepEqual(searchMods(bare, 'nulls').map((m) => m.id), ['nulls']);
    assert.doesNotThrow(() => searchMods(bare, 'author:x, -category:y'));
  });

  test('the list passed in is left as it was', () => {
    const before = fixture.map((mod) => mod.id);
    searchMods(fixture, 'portrait');
    assert.deepEqual(fixture.map((mod) => mod.id), before);
  });

  test('the same search always gives the same order', () => {
    for (const text of ['portrait', 'diable', 'pirate', 'scy', 'faction, portrait']) {
      assert.deepEqual(ids(text), ids(text), text);
    }
  });
});

// --- The box in the top bar ---

describe('suggestions in the top bar', () => {
  const suggested = (text, count = 5) => suggestMods(fixture, text, count).map((mod) => mod.id);

  test('the same order as Browse, cut short', () => {
    for (const text of ['seeker', 'diable', 'nex', 'portrait pack', 'swp', 'faction, portrait',
      'pirate -junk', 'seeker unidentified contact', 'nexerlin', '"unknown contact"']) {
      assert.deepEqual(suggested(text), ids(text).slice(0, 5), text);
    }
  });

  test('the reported search suggests the right mod first', () => {
    assert.equal(suggested('seeker unidentified contact')[0], 'seeker-unidentified-contact');
    assert.equal(suggested('seeker - unid')[0], 'seeker-unidentified-contact');
  });

  test('as the reader types, letter by letter', () => {
    // From "seek" on, the mod being typed is always among the suggestions.
    for (const text of ['seek', 'seeke', 'seeker', 'seeker ', 'seeker u', 'seeker un',
      'seeker uni', 'seeker unid', 'seeker unide', 'seeker unidentified c']) {
      assert.ok(suggested(text).includes('seeker-unidentified-contact'),
        `${JSON.stringify(text)}: ${suggested(text).join(', ')}`);
    }
    assert.equal(suggested('seeker unid')[0], 'seeker-unidentified-contact');
    assert.equal(suggested('nexe')[0], 'nexerelin');
    assert.equal(suggested('tahl')[0], 'tahlan-shipworks');
  });

  test('commas work here too', () => {
    const both = suggested('nexerelin, lazylib');
    assert.ok(both.includes('nexerelin') && both.includes('lazylib'), both.join(', '));
  });

  test('only minus words suggest nothing', () => {
    assert.deepEqual(suggested('-portrait'), []);
    assert.deepEqual(suggested('-portrait, -faction'), []);
  });

  test('too little typed suggests nothing', () => {
    for (const text of ['', ' ', 'a', 'x', '"', '!!', '-', '+', ' a ']) {
      assert.deepEqual(suggested(text), [], JSON.stringify(text));
    }
  });

  test('two letters are enough', () => {
    assert.ok(suggested('qb').includes('qb-mod-browser-and-mod-manager-qbmbamm'));
  });

  test('never more than asked for', () => {
    assert.equal(suggested('portrait', 5).length, 5);
    assert.equal(suggested('portrait', 3).length, 3);
  });
});

describe('people suggested in the top bar', () => {
  const people = (text, count = 6) => peopleMatching(fixture, text, count).map((p) => p.name);

  test('a person\'s name written any way', () => {
    for (const text of ['dark revenant', 'dark.revenant', 'darkrevenant', 'Dark Revenant',
      'revenant']) {
      assert.deepEqual(people(text), ['Dark.Revenant'], text);
    }
  });

  test('one person spelt two ways in the data is offered once', () => {
    assert.equal(people('sirhartley').length, 1);
    assert.equal(people('sir hartley').length, 1);
    assert.equal(people('lukas04').length, 1);
  });

  test('a part of the name is enough', () => {
    assert.deepEqual(people('tartif'), ['Tartiflette']);
    assert.deepEqual(people('computica'), ['Computica']);
  });

  test('listed by name, never by how many mods they have', () => {
    const found = people('an', 50);
    assert.ok(found.length > 3, found.join(', '));
    assert.deepEqual(found, [...found].sort((a, b) => a.localeCompare(b)));
  });

  test('too little typed suggests nobody, the same as for mods', () => {
    // Added once the box was tried for real: one letter hid the mods but
    // still listed every person with an "a" in their name.
    for (const text of ['a', ' a ', 'x', '"', '-']) {
      assert.deepEqual(people(text), [], JSON.stringify(text));
    }
  });

  test('a mod is not a person', () => {
    assert.deepEqual(people('nexerelin'), []);
  });

  test('only minus words suggest nobody', () => {
    assert.deepEqual(people('-tartiflette'), []);
  });

  test('never more than asked for', () => {
    assert.ok(people('a', 3).length <= 3);
  });
});

// --- Speed ---

describe('speed', () => {
  test('a search over a full-sized list is quick enough to run on every key press', () => {
    // About the size of the real list: the fixture ten times over, each copy
    // its own object so nothing is shared between copies.
    const big = [];
    for (let copy = 0; copy < 10; copy++) {
      for (const mod of fixture) big.push({ ...mod, id: `${mod.id}-${copy}` });
    }
    const searches = ['seeker unidentified contact', 'nexerlin', 'portrait pack -girls',
      'faction, portrait', 'author:tartiflette diable', 'tahaln shipwroks', 'p', 'pi', 'pir',
      'pira', 'pirat', 'pirate'];
    searchMods(big, 'warm up');
    const started = performance.now();
    for (const text of searches) searchMods(big, text);
    const each = (performance.now() - started) / searches.length;
    // Generous, so a slow test machine does not fail it. The aim in the design
    // is well under 16 ms on an ordinary computer.
    assert.ok(each < 60, `${each.toFixed(1)} ms per search`);
  });
});
