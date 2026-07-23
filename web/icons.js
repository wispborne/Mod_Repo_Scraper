// Inline icons for the sidebar. These are Tabler Icons (https://tabler.io/icons),
// MIT-licensed, copied in as path data so the site loads nothing from the
// internet at run time. Each entry is the list of `<path d="...">` strings from
// the 24×24 outline icon of that name.

const PATHS = {
  home: [
    'M5 12l-2 0l9 -9l9 9l-2 0',
    'M5 12v7a2 2 0 0 0 2 2h10a2 2 0 0 0 2 -2v-7',
    'M9 21v-6a2 2 0 0 1 2 -2h2a2 2 0 0 1 2 2v6',
  ],
  'list-details': [
    'M13 5h8',
    'M13 9h5',
    'M13 15h8',
    'M13 19h5',
    'M3 5a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1l0 -4',
    'M3 15a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v4a1 1 0 0 1 -1 1h-4a1 1 0 0 1 -1 -1l0 -4',
  ],
  packages: [
    'M7 16.5l-5 -3l5 -3l5 3v5.5l-5 3l0 -5.5',
    'M2 13.5v5.5l5 3',
    'M7 16.545l5 -3.03',
    'M17 16.5l-5 -3l5 -3l5 3v5.5l-5 3l0 -5.5',
    'M12 19l5 3',
    'M17 16.5l5 -3',
    'M12 13.5v-5.5l-5 -3l5 -3l5 3v5.5',
    'M7 5.03v5.455',
    'M12 8l5 -3',
  ],
  'package-export': [
    'M12 21l-8 -4.5v-9l8 -4.5l8 4.5v4.5',
    'M12 12l8 -4.5',
    'M12 12v9',
    'M12 12l-8 -4.5',
    'M15 18h7',
    'M19 15l3 3l-3 3',
  ],
  'player-play': [
    'M7 4v16l13 -8l-13 -8',
  ],
  'git-merge': [
    'M5 18a2 2 0 1 0 4 0a2 2 0 1 0 -4 0',
    'M5 6a2 2 0 1 0 4 0a2 2 0 1 0 -4 0',
    'M15 12a2 2 0 1 0 4 0a2 2 0 1 0 -4 0',
    'M7 8l0 8',
    'M7 8a4 4 0 0 0 4 4h4',
  ],
  'file-diff': [
    'M14 3v4a1 1 0 0 0 1 1h4',
    'M17 21h-10a2 2 0 0 1 -2 -2v-14a2 2 0 0 1 2 -2h7l5 5v11a2 2 0 0 1 -2 2',
    'M12 10l0 4',
    'M10 12l4 0',
    'M10 17l4 0',
  ],
  'git-compare': [
    'M4 6a2 2 0 1 0 4 0a2 2 0 1 0 -4 0',
    'M16 18a2 2 0 1 0 4 0a2 2 0 1 0 -4 0',
    'M11 6h5a2 2 0 0 1 2 2v8',
    'M14 9l-3 -3l3 -3',
    'M13 18h-5a2 2 0 0 1 -2 -2v-8',
    'M10 15l3 3l-3 3',
  ],
  flask: [
    'M9 3l6 0',
    'M10 9l4 0',
    'M10 3v6l-4 11a.7 .7 0 0 0 .5 1h11a.7 .7 0 0 0 .5 -1l-4 -11v-6',
  ],
  files: [
    'M15 3v4a1 1 0 0 0 1 1h4',
    'M18 17h-7a2 2 0 0 1 -2 -2v-10a2 2 0 0 1 2 -2h4l5 5v7a2 2 0 0 1 -2 2',
    'M16 17v2a2 2 0 0 1 -2 2h-7a2 2 0 0 1 -2 -2v-10a2 2 0 0 1 2 -2h2',
  ],
  'terminal-2': [
    'M8 9l3 3l-3 3',
    'M13 15l3 0',
    'M3 6a2 2 0 0 1 2 -2h14a2 2 0 0 1 2 2v12a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2l0 -12',
  ],
};

/// Builds an inline SVG icon by name. It draws in the current text colour and
/// takes its size from the surrounding font unless a size is given. Decorative,
/// so it is hidden from screen readers — the label beside it says what it is.
export function icon(name, { size } = {}) {
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.setAttribute('viewBox', '0 0 24 24');
  svg.setAttribute('width', size || '1em');
  svg.setAttribute('height', size || '1em');
  svg.setAttribute('fill', 'none');
  svg.setAttribute('stroke', 'currentColor');
  svg.setAttribute('stroke-width', '2');
  svg.setAttribute('stroke-linecap', 'round');
  svg.setAttribute('stroke-linejoin', 'round');
  svg.setAttribute('aria-hidden', 'true');
  svg.classList.add('icon');
  for (const d of PATHS[name] || []) {
    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
    path.setAttribute('d', d);
    svg.append(path);
  }
  return svg;
}
