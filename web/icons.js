// Icons for the viewer. These are Tabler Icons (https://tabler.io/icons),
// MIT-licensed, copied in as path data so nothing loads from the internet.
// Each entry is the list of `<path d="...">` strings from the 24×24 outline
// icon of that name.

const PATHS = {
  gauge: ['M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0', 'M12 12l3.5 -3.5', 'M7 12h.01', 'M12 7h.01'],
  history: ['M12 8l0 4l2 2', 'M3.05 11a9 9 0 1 1 .5 4m-.5 5v-5h5'],
  settings: ['M14 6m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M4 6l8 0', 'M16 6l4 0', 'M8 12m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M4 12l2 0', 'M10 12l10 0', 'M17 18m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M4 18l11 0', 'M19 18l1 0'],
  'eye-off': ['M10.585 10.587a2 2 0 0 0 2.829 2.828', 'M16.681 16.673a8.717 8.717 0 0 1 -4.681 1.327c-3.6 0 -6.6 -2 -9 -6c1.272 -2.12 2.712 -3.678 4.32 -4.674m2.86 -1.146a9.055 9.055 0 0 1 1.82 -.18c3.6 0 6.6 2 9 6c-.666 1.11 -1.379 2.067 -2.138 2.87', 'M3 3l18 18'],
  users: ['M9 7m-4 0a4 4 0 1 0 8 0a4 4 0 1 0 -8 0', 'M3 21v-2a4 4 0 0 1 4 -4h4a4 4 0 0 1 4 4v2', 'M16 3.13a4 4 0 0 1 0 7.75', 'M21 21v-2a4 4 0 0 0 -3 -3.85'],
  link: ['M9 15l6 -6', 'M11 6l.463 -.536a5 5 0 0 1 7.071 7.072l-.534 .464', 'M13 18l-.397 .534a5.068 5.068 0 0 1 -7.127 0a4.972 4.972 0 0 1 0 -7.071l.524 -.463'],
  box: ['M12 3l8 4.5v9l-8 4.5l-8 -4.5v-9z', 'M12 12l8 -4.5', 'M12 12v9', 'M12 12l-8 -4.5'],
  'alert-triangle': ['M12 9v4', 'M10.363 3.591l-8.106 13.534a1.914 1.914 0 0 0 1.636 2.871h16.214a1.914 1.914 0 0 0 1.636 -2.87l-8.106 -13.536a1.914 1.914 0 0 0 -3.274 0z', 'M12 16h.01'],
  mail: ['M3 7a2 2 0 0 1 2 -2h14a2 2 0 0 1 2 2v10a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2v-10z', 'M3 7l9 6l9 -6'],
  'circle-x': ['M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0', 'M10 10l4 4m0 -4l-4 4'],
  'help-circle': ['M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0', 'M12 17l0 .01', 'M12 13.5a1.5 1.5 0 0 1 1 -1.5a2.6 2.6 0 1 0 -3 -4'],
  'circle-check': ['M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0', 'M9 12l2 2l4 -4'],
  'list-check': ['M3.5 5.5l1.5 1.5l2.5 -2.5', 'M3.5 11.5l1.5 1.5l2.5 -2.5', 'M3.5 17.5l1.5 1.5l2.5 -2.5', 'M11 6l9 0', 'M11 12l9 0', 'M11 18l9 0'],
  list: ['M9 6h11', 'M9 12h11', 'M9 18h11', 'M5 6v.01', 'M5 12v.01', 'M5 18v.01'],
  compare: ['M6 6m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M18 18m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M11 6h5a2 2 0 0 1 2 2v8', 'M14 9l-3 -3l3 -3', 'M13 18h-5a2 2 0 0 1 -2 -2v-8', 'M10 15l3 3l-3 3'],
  merge: ['M7 18m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M7 6m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M17 12m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M7 8l0 8', 'M7 8a4 4 0 0 0 4 4h4'],
  flask: ['M9 3l6 0', 'M10 9l4 0', 'M10 3v6l-4 11a.7 .7 0 0 0 .5 1h11a.7 .7 0 0 0 .5 -1l-4 -11v-6'],
  files: ['M15 3v4a1 1 0 0 0 1 1h4', 'M18 17h-7a2 2 0 0 1 -2 -2v-10a2 2 0 0 1 2 -2h4l5 5v7a2 2 0 0 1 -2 2z', 'M16 17v2a2 2 0 0 1 -2 2h-7a2 2 0 0 1 -2 -2v-10a2 2 0 0 1 2 -2h2'],
  search: ['M10 10m-7 0a7 7 0 1 0 14 0a7 7 0 1 0 -14 0', 'M21 21l-6 -6'],
  inbox: ['M4 4m0 2a2 2 0 0 1 2 -2h12a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2h-12a2 2 0 0 1 -2 -2z', 'M4 13h3l3 3h4l3 -3h3'],
  'chevron-down': ['M6 9l6 6l6 -6'],
  'chevron-right': ['M9 6l6 6l-6 6'],
  'chevron-left': ['M15 6l-6 6l6 6'],
  'chevron-up': ['M6 15l6 -6l6 6'],
  'chevrons-down': ['M7 7l5 5l5 -5', 'M7 13l5 5l5 -5'],
  'chevrons-up': ['M7 11l5 -5l5 5', 'M7 17l5 -5l5 5'],
  'chevrons-left': ['M11 7l-5 5l5 5', 'M17 7l-5 5l5 5'],
  'chevrons-right': ['M7 7l5 5l-5 5', 'M13 7l5 5l-5 5'],
  clock: ['M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0', 'M12 7v5l3 3'],
  'external-link': ['M12 6h-6a2 2 0 0 0 -2 2v10a2 2 0 0 0 2 2h10a2 2 0 0 0 2 -2v-6', 'M11 13l9 -9', 'M15 4h5v5'],
  upload: ['M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2 -2v-2', 'M7 9l5 -5l5 5', 'M12 4l0 12'],
  download: ['M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2 -2v-2', 'M7 11l5 5l5 -5', 'M12 4l0 12'],
  refresh: ['M20 11a8.1 8.1 0 0 0 -15.5 -2m-.5 -4v4h4', 'M4 13a8.1 8.1 0 0 0 15.5 2m.5 4v-4h-4'],
  repeat: ['M4 12v-3a3 3 0 0 1 3 -3h13m-3 -3l3 3l-3 3', 'M20 12v3a3 3 0 0 1 -3 3h-13m3 3l-3 -3l3 -3'],
  restore: ['M3.06 13a9 9 0 1 0 .49 -4.087', 'M3 4.001v5h5', 'M11 12a1 1 0 1 0 2 0a1 1 0 1 0 -2 0'],
  stop: ['M6 6h12v12h-12z'],
  x: ['M18 6l-12 12', 'M6 6l12 12'],
  plus: ['M12 5l0 14', 'M5 12l14 0'],
  minus: ['M5 12l14 0'],
  check: ['M5 12l5 5l10 -10'],
  checks: ['M7 12l5 5l10 -10', 'M2 12l5 5m5 -5l5 -5'],
  pencil: ['M4 20h4l10.5 -10.5a2.828 2.828 0 1 0 -4 -4l-10.5 10.5v4', 'M13.5 6.5l4 4'],
  trash: ['M4 7l16 0', 'M10 11l0 6', 'M14 11l0 6', 'M5 7l1 12a2 2 0 0 0 2 2h8a2 2 0 0 0 2 -2l1 -12', 'M9 7v-3a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v3'],
  ban: ['M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0', 'M5.7 5.7l12.6 12.6'],
  eye: ['M10 12a2 2 0 1 0 4 0a2 2 0 0 0 -4 0', 'M21 12c-2.4 4 -5.4 6 -9 6c-3.6 0 -6.6 -2 -9 -6c2.4 -4 5.4 -6 9 -6c3.6 0 6.6 2 9 6'],
  photo: ['M15 8h.01', 'M3 6a3 3 0 0 1 3 -3h12a3 3 0 0 1 3 3v12a3 3 0 0 1 -3 3h-12a3 3 0 0 1 -3 -3v-12z', 'M3 16l5 -5c.928 -.893 2.072 -.893 3 0l5 5', 'M14 14l1 -1c.928 -.893 2.072 -.893 3 0l3 3'],
  hammer: ['M11.414 10l-7.383 7.418a2.091 2.091 0 0 0 0 2.967a2.11 2.11 0 0 0 2.976 0l7.407 -7.385', 'M18.121 15.293l2.586 -2.586a1 1 0 0 0 0 -1.414l-7.586 -7.586a1 1 0 0 0 -1.414 0l-2.586 2.586a1 1 0 0 0 0 1.414l7.586 7.586a1 1 0 0 0 1.414 0z'],
  'file-check': ['M14 3v4a1 1 0 0 0 1 1h4', 'M17 21h-10a2 2 0 0 1 -2 -2v-14a2 2 0 0 1 2 -2h7l5 5v11a2 2 0 0 1 -2 2z', 'M9 15l2 2l4 -4'],
  'device-floppy': ['M6 4h10l4 4v10a2 2 0 0 1 -2 2h-12a2 2 0 0 1 -2 -2v-12a2 2 0 0 1 2 -2', 'M12 14m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M14 4l0 4l-6 0l0 -4'],
  'user-x': ['M8 7a4 4 0 1 0 8 0a4 4 0 0 0 -8 0', 'M6 21v-2a4 4 0 0 1 4 -4h3.5', 'M22 22l-5 -5', 'M17 22l5 -5'],
  'circle-arrow-up': ['M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0', 'M16 12l-4 -4l-4 4', 'M12 16v-8'],
  'arrow-right': ['M5 12l14 0', 'M13 18l6 -6', 'M13 6l6 6'],
  'arrow-back-up': ['M9 14l-4 -4l4 -4', 'M5 10h11a4 4 0 1 1 0 8h-1'],
  'arrows-exchange': ['M7 10h14l-4 -4', 'M17 14h-14l4 4'],
  'arrows-left-right': ['M21 17l-18 0', 'M6 10l-3 -3l3 -3', 'M3 7l18 0', 'M18 20l3 -3l-3 -3'],
  'info-circle': ['M3 12a9 9 0 1 0 18 0a9 9 0 0 0 -18 0', 'M12 9h.01', 'M11 12h1v4h1'],
  paperclip: ['M15 7l-6.5 6.5a1.5 1.5 0 0 0 3 3l6.5 -6.5a3 3 0 0 0 -6 -6l-6.5 6.5a4.5 4.5 0 0 0 9 9l6.5 -6.5'],
  sparkles: ['M16 18a2 2 0 0 1 2 2a2 2 0 0 1 2 -2a2 2 0 0 1 -2 -2a2 2 0 0 1 -2 2zm0 -12a2 2 0 0 1 2 2a2 2 0 0 1 2 -2a2 2 0 0 1 -2 -2a2 2 0 0 1 -2 2zm-7 12a6 6 0 0 1 6 -6a6 6 0 0 1 -6 -6a6 6 0 0 1 -6 6a6 6 0 0 1 6 6z'],
};

// Which icon each action uses, so an action looks the same on every page.
// A new button should use one of these names, or add one here.
const ACTIONS = {
  // Jobs.
  fetch: 'download',
  llm: 'sparkles',
  'recheck-downloads': 'file-check',
  'scan-images': 'photo',
  match: 'link',
  rebuild: 'hammer',
  publish: 'upload',
  'run-again': 'repeat',
  update: 'circle-arrow-up',
  // Corrections.
  'take-down': 'eye-off',
  restore: 'restore',
  reset: 'restore',
  undo: 'arrow-back-up',
  'same-person': 'users',
  'different-people': 'user-x',
  'not-in-catalog': 'ban',
  // On a page.
  save: 'device-floppy',
  discard: 'trash',
  clear: 'x',
  remove: 'x',
  add: 'plus',
  preview: 'eye',
  swap: 'arrows-exchange',
  'mark-read': 'checks',
  more: 'chevron-down',
  'expand-all': 'chevrons-down',
  'collapse-all': 'chevrons-up',
  'first-page': 'chevrons-left',
  'previous-page': 'chevron-left',
  'next-page': 'chevron-right',
  'last-page': 'chevrons-right',
};

const SVG = 'http://www.w3.org/2000/svg';

/// Whether `name` is an icon or an action that has one.
export function hasIcon(name) {
  return !!PATHS[ACTIONS[name] || name];
}

/// Every action's icon exists. Checked by a test.
export function actionsWithoutIcon() {
  return Object.keys(ACTIONS).filter((action) => !PATHS[ACTIONS[action]]);
}

/// An outline icon as an <svg> element, hidden from screen readers. `name` is
/// an action or an icon. There are three sizes, all a whole number of pixels
/// so the lines stay sharp: 14 beside words (the default), 16 alone in a
/// button, 20 in the nav rail.
export function icon(name, size = 14) {
  const svg = document.createElementNS(SVG, 'svg');
  svg.setAttribute('class', 'icon');
  svg.setAttribute('width', String(size));
  svg.setAttribute('height', String(size));
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('fill', 'none');
  svg.setAttribute('stroke', 'currentColor');
  svg.setAttribute('stroke-width', '2');
  svg.setAttribute('stroke-linecap', 'round');
  svg.setAttribute('stroke-linejoin', 'round');
  svg.setAttribute('aria-hidden', 'true');
  for (const d of PATHS[ACTIONS[name] || name] || []) {
    const path = document.createElementNS(SVG, 'path');
    path.setAttribute('d', d);
    svg.append(path);
  }
  return svg;
}
