// Icons for the new viewer. These are Tabler Icons (https://tabler.io/icons),
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
  list: ['M9 6h11', 'M9 12h11', 'M9 18h11', 'M5 6v.01', 'M5 12v.01', 'M5 18v.01'],
  compare: ['M6 6m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M18 18m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M11 6h5a2 2 0 0 1 2 2v8', 'M14 9l-3 -3l3 -3', 'M13 18h-5a2 2 0 0 1 -2 -2v-8', 'M10 15l3 3l-3 3'],
  merge: ['M7 18m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M7 6m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M17 12m-2 0a2 2 0 1 0 4 0a2 2 0 1 0 -4 0', 'M7 8l0 8', 'M7 8a4 4 0 0 0 4 4h4'],
  flask: ['M9 3l6 0', 'M10 9l4 0', 'M10 3v6l-4 11a.7 .7 0 0 0 .5 1h11a.7 .7 0 0 0 .5 -1l-4 -11v-6'],
  files: ['M15 3v4a1 1 0 0 0 1 1h4', 'M18 17h-7a2 2 0 0 1 -2 -2v-10a2 2 0 0 1 2 -2h4l5 5v7a2 2 0 0 1 -2 2z', 'M16 17v2a2 2 0 0 1 -2 2h-7a2 2 0 0 1 -2 -2v-10a2 2 0 0 1 2 -2h2'],
  search: ['M10 10m-7 0a7 7 0 1 0 14 0a7 7 0 1 0 -14 0', 'M21 21l-6 -6'],
  inbox: ['M4 4m0 2a2 2 0 0 1 2 -2h12a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2h-12a2 2 0 0 1 -2 -2z', 'M4 13h3l3 3h4l3 -3h3'],
  'chevron-down': ['M6 9l6 6l6 -6'],
  'chevron-right': ['M9 6l6 6l-6 6'],
  clock: ['M12 12m-9 0a9 9 0 1 0 18 0a9 9 0 1 0 -18 0', 'M12 7v5l3 3'],
  'external-link': ['M12 6h-6a2 2 0 0 0 -2 2v10a2 2 0 0 0 2 2h10a2 2 0 0 0 2 -2v-6', 'M11 13l9 -9', 'M15 4h5v5'],
  upload: ['M4 17v2a2 2 0 0 0 2 2h12a2 2 0 0 0 2 -2v-2', 'M7 9l5 -5l5 5', 'M12 4l0 12'],
};

const SVG = 'http://www.w3.org/2000/svg';

/// An outline icon as an <svg> element, hidden from screen readers. Drawn at
/// a whole number of pixels so its lines stay sharp.
export function icon(name, size = 16) {
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
  for (const d of PATHS[name] || []) {
    const path = document.createElementNS(SVG, 'path');
    path.setAttribute('d', d);
    svg.append(path);
  }
  return svg;
}
