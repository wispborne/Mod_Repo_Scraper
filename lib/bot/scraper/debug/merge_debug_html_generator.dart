import 'dart:io';

import 'merge_debug_data.dart';

class MergeDebugHtmlGenerator {
  static Future<void> generate(MergeDebugData data, String outputPath) async {
    final html = _buildHtml(data);
    await File(outputPath).writeAsString(html);
  }

  static String _buildHtml(MergeDebugData data) {
    final buf = StringBuffer();
    buf.writeln('<!DOCTYPE html>');
    buf.writeln('<html lang="en">');
    _writeHead(buf);
    buf.writeln('<body>');
    buf.writeln('<div class="container">');
    buf.writeln('<h1>Mod Merger Debug Report</h1>');
    buf.writeln('<p class="subtitle">Generated ${DateTime.now().toIso8601String()}</p>');
    _writeSummaryDashboard(buf, data);
    _writeTimingSection(buf, data);
    _writePreDedupSection(buf, data);
    _writeGroupsSection(buf, data);
    _writeSameSourceDedupSection(buf, data);
    _writeMergeDecisionsSection(buf, data);
    _writeValidationSection(buf, data);
    _writeFinalOutputSection(buf, data);
    buf.writeln('</div>');
    _writeScript(buf);
    buf.writeln('</body>');
    buf.writeln('</html>');
    return buf.toString();
  }

  static void _writeHead(StringBuffer buf) {
    buf.writeln('<head>');
    buf.writeln('<meta charset="UTF-8">');
    buf.writeln('<meta name="viewport" content="width=device-width, initial-scale=1.0">');
    buf.writeln('<title>Mod Merger Debug Report</title>');
    buf.writeln('<style>');
    buf.writeln('''
:root {
  --primary: rgb(73, 252, 255);
  --secondary: rgb(59, 203, 232);
  --surface: rgb(14, 22, 43);
  --surface-container: rgb(32, 41, 65);
  --text: rgb(220, 225, 240);
  --text-dim: rgb(140, 150, 170);
  --warning: rgb(255, 183, 77);
  --error: rgb(255, 100, 100);
  --success: rgb(100, 255, 150);
  --border: rgba(73, 252, 255, 0.15);
}
* { box-sizing: border-box; margin: 0; padding: 0; }
body { background: var(--surface); color: var(--text); font-family: 'Segoe UI', system-ui, -apple-system, sans-serif; line-height: 1.5; padding: 24px; }
.container { max-width: 1400px; margin: 0 auto; }
h1 { color: var(--primary); font-size: 1.8rem; margin-bottom: 4px; }
.subtitle { color: var(--text-dim); font-size: 0.85rem; margin-bottom: 32px; }
h2 { color: var(--secondary); font-size: 1.3rem; margin: 32px 0 16px 0; padding-bottom: 8px; border-bottom: 1px solid var(--border); }
h3 { color: var(--text); font-size: 1rem; margin: 12px 0 8px 0; }

/* Summary Dashboard */
.stat-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 12px; margin-bottom: 24px; }
.stat-card { background: var(--surface-container); border-radius: 8px; padding: 16px; border: 1px solid var(--border); }
.stat-card .label { color: var(--text-dim); font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; }
.stat-card .value { color: var(--primary); font-size: 1.8rem; font-weight: 700; }
.stat-card.warning .value { color: var(--warning); }
.stat-card.error .value { color: var(--error); }

/* Timing bars */
.timing-bar-container { margin-bottom: 8px; }
.timing-bar-label { display: flex; justify-content: space-between; font-size: 0.8rem; margin-bottom: 2px; }
.timing-bar-label span:first-child { color: var(--text); }
.timing-bar-label span:last-child { color: var(--text-dim); }
.timing-bar { height: 6px; border-radius: 3px; background: var(--surface); }
.timing-bar-fill { height: 100%; border-radius: 3px; background: linear-gradient(90deg, var(--primary), var(--secondary)); min-width: 2px; }

/* Tables */
table { width: 100%; border-collapse: collapse; font-size: 0.85rem; margin-bottom: 16px; }
th { background: var(--surface-container); color: var(--secondary); text-align: left; padding: 10px 12px; border-bottom: 2px solid var(--border); font-weight: 600; position: sticky; top: 0; }
td { padding: 8px 12px; border-bottom: 1px solid var(--border); vertical-align: top; }
tr:hover td { background: rgba(73, 252, 255, 0.03); }
.table-wrapper { overflow-x: auto; border-radius: 8px; border: 1px solid var(--border); }

/* Details/Summary (collapsible cards) */
details { background: var(--surface-container); border-radius: 8px; border: 1px solid var(--border); margin-bottom: 8px; }
details[open] { border-color: rgba(73, 252, 255, 0.3); }
summary { padding: 12px 16px; cursor: pointer; font-size: 0.9rem; color: var(--text); user-select: none; }
summary:hover { background: rgba(73, 252, 255, 0.05); }
summary::marker { color: var(--primary); }
.details-body { padding: 4px 16px 16px 16px; }

/* Badges */
.badge { display: inline-block; padding: 2px 8px; border-radius: 4px; font-size: 0.75rem; font-weight: 600; }
.badge-primary { background: rgba(73, 252, 255, 0.15); color: var(--primary); }
.badge-secondary { background: rgba(59, 203, 232, 0.15); color: var(--secondary); }
.badge-warning { background: rgba(255, 183, 77, 0.15); color: var(--warning); }
.badge-error { background: rgba(255, 100, 100, 0.15); color: var(--error); }
.badge-success { background: rgba(100, 255, 150, 0.15); color: var(--success); }
.badge-dim { background: rgba(140, 150, 170, 0.15); color: var(--text-dim); }

/* Mod cards inside details */
.mod-entry { padding: 8px 0; border-bottom: 1px solid var(--border); font-size: 0.85rem; }
.mod-entry:last-child { border-bottom: none; }
.mod-name { color: var(--primary); font-weight: 600; }
.mod-meta { color: var(--text-dim); font-size: 0.8rem; }

/* Merge step arrow */
.merge-step { padding: 8px 0; border-bottom: 1px solid var(--border); font-size: 0.85rem; }
.merge-step:last-child { border-bottom: none; }
.merge-arrow { color: var(--primary); font-weight: 700; margin: 4px 0; }

/* Section controls */
.section-controls { display: flex; gap: 8px; margin-bottom: 12px; }
.section-controls button { background: var(--surface-container); color: var(--text-dim); border: 1px solid var(--border); border-radius: 4px; padding: 4px 12px; font-size: 0.75rem; cursor: pointer; }
.section-controls button:hover { color: var(--primary); border-color: var(--primary); }

/* Empty state */
.empty-state { color: var(--text-dim); font-style: italic; padding: 16px; text-align: center; }

/* Field list */
.field-list { list-style: none; }
.field-list li { padding: 2px 0; font-size: 0.83rem; }
.field-label { color: var(--text-dim); min-width: 120px; display: inline-block; }
.field-value { color: var(--text); }

/* Priority winner */
.winner { color: var(--success); }
.loser { color: var(--text-dim); }
''');
    buf.writeln('</style>');
    buf.writeln('</head>');
  }

  static void _writeSummaryDashboard(StringBuffer buf, MergeDebugData data) {
    buf.writeln('<h2>Summary</h2>');
    buf.writeln('<div class="stat-grid">');
    _writeStatCard(buf, 'Input Mods', data.inputCount.toString());
    _writeStatCard(buf, 'Pre-dedup Removals', data.preDedupEntries.length.toString(),
        className: data.preDedupEntries.isNotEmpty ? 'warning' : '');
    _writeStatCard(buf, 'After Pre-dedup', data.afterPreDedupCount.toString());
    _writeStatCard(buf, 'Groups Created', data.groupsCreated.toString());
    _writeStatCard(buf, 'Same-source Dedup', data.sameSourceDedupEntries.where((e) => !e.wasSafetyBlocked).length.toString(),
        className: data.sameSourceDedupEntries.isNotEmpty ? 'warning' : '');
    final mergedCount = data.mergeDecisions.where((d) => d.steps.isNotEmpty).length;
    _writeStatCard(buf, 'Groups Merged', mergedCount.toString());
    _writeStatCard(buf, 'Validation Removals', data.validationRemovalEntries.length.toString(),
        className: data.validationRemovalEntries.isNotEmpty ? 'error' : '');
    _writeStatCard(buf, 'Final Output', data.finalCount.toString());
    buf.writeln('</div>');
  }

  static void _writeStatCard(StringBuffer buf, String label, String value, {String className = ''}) {
    buf.writeln('<div class="stat-card $className">');
    buf.writeln('<div class="label">${_esc(label)}</div>');
    buf.writeln('<div class="value">${_esc(value)}</div>');
    buf.writeln('</div>');
  }

  static void _writeTimingSection(StringBuffer buf, MergeDebugData data) {
    if (data.timings.isEmpty) return;

    buf.writeln('<h2>Timing</h2>');
    final maxMs = data.timings.map((t) => t.durationMs).fold(1, (a, b) => a > b ? a : b);

    for (final timing in data.timings) {
      final pct = (timing.durationMs / maxMs * 100).clamp(1, 100);
      buf.writeln('<div class="timing-bar-container">');
      buf.writeln('<div class="timing-bar-label"><span>${_esc(timing.phaseName)}</span><span>${timing.durationMs}ms</span></div>');
      buf.writeln('<div class="timing-bar"><div class="timing-bar-fill" style="width: ${pct.toStringAsFixed(1)}%"></div></div>');
      buf.writeln('</div>');
    }
  }

  static void _writePreDedupSection(StringBuffer buf, MergeDebugData data) {
    buf.writeln('<h2>Pre-dedup Removals (${data.preDedupEntries.length})</h2>');

    if (data.preDedupEntries.isEmpty) {
      buf.writeln('<div class="empty-state">No pre-dedup removals.</div>');
      return;
    }

    _writeSectionControls(buf, 'predeup');
    buf.writeln('<div class="table-wrapper">');
    buf.writeln('<table>');
    buf.writeln('<thead><tr><th>Kept</th><th>Discarded</th><th>Source</th><th>Reason</th><th>Kept Richness</th><th>Discarded Richness</th></tr></thead>');
    buf.writeln('<tbody>');
    for (final entry in data.preDedupEntries) {
      buf.writeln('<tr>');
      buf.writeln('<td><span class="mod-name">${_esc(entry.kept.name)}</span></td>');
      buf.writeln('<td>${_esc(entry.discarded.name)}</td>');
      buf.writeln('<td>${_esc(entry.kept.getSources().map((s) => s.name).join(', '))}</td>');
      buf.writeln('<td><span class="badge badge-dim">${_esc(entry.reason)}</span></td>');
      buf.writeln('<td>${entry.keptRichness}</td>');
      buf.writeln('<td>${entry.discardedRichness}</td>');
      buf.writeln('</tr>');
    }
    buf.writeln('</tbody></table>');
    buf.writeln('</div>');
  }

  static void _writeGroupsSection(StringBuffer buf, MergeDebugData data) {
    final multiMemberGroups = data.groups.where((g) => g.members.length > 1).toList();
    final singletonCount = data.groups.length - multiMemberGroups.length;

    buf.writeln('<h2>Groups (${data.groups.length} total, ${multiMemberGroups.length} with matches, $singletonCount singletons)</h2>');

    if (multiMemberGroups.isEmpty) {
      buf.writeln('<div class="empty-state">No multi-member groups. All mods are singletons.</div>');
      return;
    }

    _writeSectionControls(buf, 'groups');

    for (final group in multiMemberGroups) {
      final primaryName = group.members.first.name;
      buf.writeln('<details data-section="groups">');
      buf.writeln('<summary>Group #${group.groupIndex} &mdash; <span class="mod-name">${_esc(primaryName)}</span> (${group.members.length} members)</summary>');
      buf.writeln('<div class="details-body">');

      buf.writeln('<h3>Members</h3>');
      for (final mod in group.members) {
        buf.writeln('<div class="mod-entry">');
        buf.writeln('<span class="mod-name">${_esc(mod.name)}</span>');
        buf.writeln('<div class="mod-meta">by ${_esc(mod.getAuthors().join(', '))} | ${_esc(mod.getSources().map((s) => s.name).join(', '))} | v${_esc(mod.gameVersionReq ?? '?')}</div>');
        buf.writeln('</div>');
      }

      if (group.matchEntries.isNotEmpty) {
        buf.writeln('<h3>Match Reasons</h3>');
        for (final match in group.matchEntries) {
          buf.writeln('<div class="mod-entry">');
          buf.writeln('<span class="mod-name">${_esc(match.outerMod.name)}</span> &harr; <span class="mod-name">${_esc(match.innerMod.name)}</span>');
          buf.writeln('<div class="mod-meta">');
          for (final reason in match.reasons) {
            switch (reason) {
              case GroupMatchReason.nameAndAuthor:
                buf.write('<span class="badge badge-primary">Name+Author</span> ');
                if (match.nameScore != null) buf.write('name score: ${match.nameScore} ');
                if (match.authorScore != null) buf.write('author score: ${match.authorScore} ');
                if (match.nameLengthRatio != null) buf.write('length ratio: ${(match.nameLengthRatio! * 100).toStringAsFixed(0)}% ');
                break;
              case GroupMatchReason.forumUrl:
                buf.write('<span class="badge badge-secondary">Forum URL</span> ');
                if (match.matchedForumTopicId != null) buf.write('topic: ${_esc(match.matchedForumTopicId!)} ');
                break;
            }
          }
          buf.writeln('</div>');
          buf.writeln('</div>');
        }
      }

      buf.writeln('</div>');
      buf.writeln('</details>');
    }
  }

  static void _writeSameSourceDedupSection(StringBuffer buf, MergeDebugData data) {
    buf.writeln('<h2>Same-source Dedup (${data.sameSourceDedupEntries.length})</h2>');

    if (data.sameSourceDedupEntries.isEmpty) {
      buf.writeln('<div class="empty-state">No same-source dedup actions.</div>');
      return;
    }

    _writeSectionControls(buf, 'dedup');
    buf.writeln('<div class="table-wrapper">');
    buf.writeln('<table>');
    buf.writeln('<thead><tr><th>Kept</th><th>Discarded</th><th>Source</th><th>Kept Version</th><th>Discarded Version</th><th>Status</th></tr></thead>');
    buf.writeln('<tbody>');
    for (final entry in data.sameSourceDedupEntries) {
      buf.writeln('<tr>');
      buf.writeln('<td><span class="mod-name">${_esc(entry.kept.name)}</span></td>');
      buf.writeln('<td>${_esc(entry.discarded.name)}</td>');
      buf.writeln('<td>${_esc(entry.source.name)}</td>');
      buf.writeln('<td>${_esc(entry.keptGameVersion ?? '?')}</td>');
      buf.writeln('<td>${_esc(entry.discardedGameVersion ?? '?')}</td>');
      if (entry.wasSafetyBlocked) {
        buf.writeln('<td><span class="badge badge-warning">SAFETY BLOCKED</span> ${entry.nameLengthRatio != null ? '(${(entry.nameLengthRatio! * 100).toStringAsFixed(0)}% ratio)' : ''}</td>');
      } else {
        buf.writeln('<td><span class="badge badge-success">Discarded</span></td>');
      }
      buf.writeln('</tr>');
    }
    buf.writeln('</tbody></table>');
    buf.writeln('</div>');
  }

  static void _writeMergeDecisionsSection(StringBuffer buf, MergeDebugData data) {
    final nonTrivial = data.mergeDecisions.where((d) => d.steps.isNotEmpty).toList();
    buf.writeln('<h2>Merge Decisions (${nonTrivial.length} groups with merges)</h2>');

    if (nonTrivial.isEmpty) {
      buf.writeln('<div class="empty-state">No merge decisions (all groups were singletons).</div>');
      return;
    }

    _writeSectionControls(buf, 'merges');

    for (final decision in nonTrivial) {
      final name = decision.finalResult.name;
      buf.writeln('<details data-section="merges">');
      buf.writeln('<summary>Group #${decision.groupIndex} &mdash; <span class="mod-name">${_esc(name)}</span> (${decision.inputMods.length} inputs &rarr; 1)</summary>');
      buf.writeln('<div class="details-body">');

      for (var i = 0; i < decision.steps.length; i++) {
        final step = decision.steps[i];
        final reasonBadge = switch (step.reason) {
          MergePriorityReason.indexSource => '<span class="badge badge-primary">Index Source</span>',
          MergePriorityReason.higherGameVersion => '<span class="badge badge-success">Higher Version</span>',
          MergePriorityReason.fallback => '<span class="badge badge-dim">Fallback</span>',
        };

        buf.writeln('<div class="merge-step">');
        buf.writeln('<div>Step ${i + 1}: $reasonBadge Priority &rarr; <strong>${step.doesRightHavePriority ? "right" : "left"}</strong></div>');
        buf.writeln('<div class="${step.doesRightHavePriority ? 'loser' : 'winner'}">Left: ${_esc(step.left.name)} by ${_esc(step.left.getAuthors().join(', '))} [${_esc(step.left.getSources().map((s) => s.name).join(', '))}] v${_esc(step.left.gameVersionReq ?? '?')}</div>');
        buf.writeln('<div class="${step.doesRightHavePriority ? 'winner' : 'loser'}">Right: ${_esc(step.right.name)} by ${_esc(step.right.getAuthors().join(', '))} [${_esc(step.right.getSources().map((s) => s.name).join(', '))}] v${_esc(step.right.gameVersionReq ?? '?')}</div>');
        buf.writeln('<div class="merge-arrow">&darr; Result: ${_esc(step.result.name)}</div>');
        buf.writeln('</div>');
      }

      // Final result summary
      final result = decision.finalResult;
      buf.writeln('<h3>Final Merged Mod</h3>');
      buf.writeln('<ul class="field-list">');
      buf.writeln('<li><span class="field-label">Name:</span> <span class="field-value">${_esc(result.name)}</span></li>');
      buf.writeln('<li><span class="field-label">Authors:</span> <span class="field-value">${_esc(result.getAuthors().join(', '))}</span></li>');
      buf.writeln('<li><span class="field-label">Game Version:</span> <span class="field-value">${_esc(result.gameVersionReq ?? '?')}</span></li>');
      buf.writeln('<li><span class="field-label">Mod Version:</span> <span class="field-value">${_esc(result.modVersion ?? '?')}</span></li>');
      buf.writeln('<li><span class="field-label">Sources:</span> <span class="field-value">${_esc(result.getSources().map((s) => s.name).join(', '))}</span></li>');
      buf.writeln('<li><span class="field-label">URLs:</span> <span class="field-value">${_esc(result.getUrls().entries.map((e) => '${e.key.name}: ${e.value}').join(', '))}</span></li>');
      if (result.getCategories().isNotEmpty) {
        buf.writeln('<li><span class="field-label">Categories:</span> <span class="field-value">${_esc(result.getCategories().join(', '))}</span></li>');
      }
      buf.writeln('</ul>');

      buf.writeln('</div>');
      buf.writeln('</details>');
    }
  }

  static void _writeValidationSection(StringBuffer buf, MergeDebugData data) {
    buf.writeln('<h2>Validation Removals (${data.validationRemovalEntries.length})</h2>');

    if (data.validationRemovalEntries.isEmpty) {
      buf.writeln('<div class="empty-state">No mods removed during validation.</div>');
      return;
    }

    buf.writeln('<div class="table-wrapper">');
    buf.writeln('<table>');
    buf.writeln('<thead><tr><th>Mod Name</th><th>Authors</th><th>Reason</th></tr></thead>');
    buf.writeln('<tbody>');
    for (final removal in data.validationRemovalEntries) {
      buf.writeln('<tr>');
      buf.writeln('<td>${_esc(removal.mod.name.isEmpty ? '(empty)' : removal.mod.name)}</td>');
      buf.writeln('<td>${_esc(removal.mod.getAuthors().join(', '))}</td>');
      buf.writeln('<td><span class="badge badge-error">${_esc(removal.reason)}</span></td>');
      buf.writeln('</tr>');
    }
    buf.writeln('</tbody></table>');
    buf.writeln('</div>');
  }

  static void _writeFinalOutputSection(StringBuffer buf, MergeDebugData data) {
    buf.writeln('<h2>Final Output (${data.finalOutput.length} mods)</h2>');

    if (data.finalOutput.isEmpty) {
      buf.writeln('<div class="empty-state">No final output.</div>');
      return;
    }

    _writeSectionControls(buf, 'final');

    for (var i = 0; i < data.finalOutput.length; i++) {
      final mod = data.finalOutput[i];
      buf.writeln('<details data-section="final">');
      buf.writeln('<summary>#${i + 1} <span class="mod-name">${_esc(mod.name)}</span> by ${_esc(mod.getAuthors().join(', '))} &mdash; v${_esc(mod.gameVersionReq ?? '?')}</summary>');
      buf.writeln('<div class="details-body">');
      buf.writeln('<ul class="field-list">');
      buf.writeln('<li><span class="field-label">Name:</span> <span class="field-value">${_esc(mod.name)}</span></li>');
      buf.writeln('<li><span class="field-label">Authors:</span> <span class="field-value">${_esc(mod.getAuthors().join(', '))}</span></li>');
      buf.writeln('<li><span class="field-label">Game Version:</span> <span class="field-value">${_esc(mod.gameVersionReq ?? '?')}</span></li>');
      buf.writeln('<li><span class="field-label">Mod Version:</span> <span class="field-value">${_esc(mod.modVersion ?? '?')}</span></li>');
      buf.writeln('<li><span class="field-label">Sources:</span> <span class="field-value">${_esc(mod.getSources().map((s) => s.name).join(', '))}</span></li>');
      buf.writeln('<li><span class="field-label">URLs:</span></li>');
      for (final urlEntry in mod.getUrls().entries) {
        buf.writeln('<li>&nbsp;&nbsp;<span class="field-label">${_esc(urlEntry.key.name)}:</span> <span class="field-value">${_esc(urlEntry.value)}</span></li>');
      }
      if (mod.getCategories().isNotEmpty) {
        buf.writeln('<li><span class="field-label">Categories:</span> <span class="field-value">${_esc(mod.getCategories().join(', '))}</span></li>');
      }
      if (mod.summary != null && mod.summary!.isNotEmpty) {
        buf.writeln('<li><span class="field-label">Summary:</span> <span class="field-value">${_esc(mod.summary!)}</span></li>');
      }
      buf.writeln('</ul>');
      buf.writeln('</div>');
      buf.writeln('</details>');
    }
  }

  static void _writeSectionControls(StringBuffer buf, String sectionName) {
    buf.writeln('<div class="section-controls">');
    buf.writeln('<button onclick="toggleAll(\'$sectionName\', true)">Expand All</button>');
    buf.writeln('<button onclick="toggleAll(\'$sectionName\', false)">Collapse All</button>');
    buf.writeln('</div>');
  }

  static void _writeScript(StringBuffer buf) {
    buf.writeln('<script>');
    buf.writeln('''
function toggleAll(section, open) {
  document.querySelectorAll('details[data-section="' + section + '"]').forEach(function(el) {
    el.open = open;
  });
}
''');
    buf.writeln('</script>');
  }

  static String _esc(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  static String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
