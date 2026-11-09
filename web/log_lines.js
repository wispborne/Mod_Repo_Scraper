// Reads a run log's lines. No DOM, so Node can test it.

// A log entry starts "2026-10-29 18:04:41 [main] E/e->_getMessages/ ...". The
// letter after the thread name is its level. A line that does not start this
// way is a later line of the entry above it.
const ENTRY_START = /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \[[^\]]*\] ([A-Z])\//;

/// 'error', 'warn', or '' for any other line. Only the level mark counts: mod
/// names and post titles in the log can hold the word "error".
export function logLevel(line) {
  const level = ENTRY_START.exec(line)?.[1];
  return level === 'E' ? 'error' : level === 'W' ? 'warn' : '';
}

/// The error entries in `lines`, each with its later lines.
export function errorLines(lines) {
  const kept = [];
  let inError = false;
  for (const line of lines) {
    if (ENTRY_START.test(line)) inError = logLevel(line) === 'error';
    if (inError) kept.push(line);
  }
  return kept;
}
