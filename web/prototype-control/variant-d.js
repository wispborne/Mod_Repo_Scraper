// PROTOTYPE — throwaway. Variant D: the Workbench layout (variant C) in the
// Homeworld colours picked from space-themes.html, with that sample's framing:
// corner brackets, cut-corner buttons, small upper-case labels, IBM Plex.
import { render as renderC, css as cssC } from './variant-c.js';

export const name = 'Workbench, Homeworld colours';
export const render = renderC;

export const css = cssC.replaceAll('.variant-C', '.variant-D') + `
.variant-D {
  --bg: #11151a; --panel: #171c22; --panel-2: #212831; --line: #222a33; --line-2: #3a4450;
  --frame: #4a4130; --frame-2: #5c5340;
  --text: #dce2e8; --dim: #8b96a2; --faint: #66717d;
  --accent: #e3b45a; --accent-ink: #1a1306; --head: #f2e6cc;
  --run: #79c7c0; --ok: #8fd18a; --bad: #e8604f; --warn: #f2a65a;
  --mono: 'IBM Plex Mono', Consolas, monospace;
  font-family: 'IBM Plex Sans', 'Segoe UI', sans-serif;
}
.variant-D .rail, .variant-D .tool, .variant-D .statusbar { border-color: var(--frame); }
.variant-D .center { border-right-color: var(--frame); }

/* Square everything; buttons get cut corners instead. */
.variant-D .tb, .variant-D .search, .variant-D .badge, .variant-D .rail a, .variant-D .rail .logo,
.variant-D .chip, .variant-D .pill, .variant-D .meter { border-radius: 0; }
.variant-D .tb { clip-path: polygon(0 0, calc(100% - 6px) 0, 100% 6px, 100% 100%, 6px 100%, 0 calc(100% - 6px)); }
.variant-D .tb.primary { color: var(--accent-ink); }
.variant-D .tb:hover { border-color: var(--accent); }
.variant-D .rail .logo { clip-path: polygon(50% 0, 100% 100%, 0 100%); width: 22px; height: 20px; font-size: 0; }
.variant-D .rail a.on { background: var(--panel-2); }

/* Small upper-case labels in the frame colour family. */
.variant-D .tool h1, .variant-D .pane h2, .variant-D .tabs a {
  font-family: var(--mono); font-size: 11px; font-weight: 600; letter-spacing: .14em; text-transform: uppercase; }
.variant-D .tool h1, .variant-D .pane h2 { color: var(--accent); }
.variant-D .pane h2 { border-bottom: 1px solid var(--line); }
.variant-D .tabs a.on { color: var(--head); }
.variant-D .runhead b { color: var(--head); }

/* Running is an outlined pill; status dots become diamonds. */
.variant-D .pill { background: none !important; border: 1px solid currentColor; font-family: var(--mono); }
.variant-D .sd, .variant-D .statusbar .st i { border-radius: 0; transform: rotate(45deg); }
.variant-D .meter { height: 4px; position: relative; }
.variant-D .meter i { background: var(--run); }
.variant-D .meter::after { content: ''; position: absolute; inset: 0; background: repeating-linear-gradient(90deg, transparent 0 9px, var(--bg) 9px 10px); }
.variant-D .term { background: #0c0f13; }
.variant-D .term .cursor { background: var(--accent); }

/* Corner brackets on the two main areas. */
.variant-D .center, .variant-D .stack { position: relative; }
.variant-D .center::before, .variant-D .stack::before {
  content: ''; position: absolute; top: 4px; left: 4px; width: 10px; height: 10px; z-index: 2;
  border-top: 2px solid var(--accent); border-left: 2px solid var(--accent); pointer-events: none; }
.variant-D .center::after {
  content: ''; position: absolute; bottom: 4px; right: 4px; width: 10px; height: 10px; z-index: 2;
  border-bottom: 2px solid var(--accent); border-right: 2px solid var(--accent); pointer-events: none; }
`;
