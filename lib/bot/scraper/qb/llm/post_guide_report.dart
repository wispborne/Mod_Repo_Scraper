import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/mod_summary.dart';
import 'post_guide_check.dart';
import 'post_guide_store.dart';

/// The report published as `post-guide-report.json` beside the catalog, and
/// what the viewer's Post guide checks page shows.
///
/// Every mod thread the last guide pass found in scope (posted or edited since
/// the guide) is in one of four groups: `failed` (misses a required item),
/// `imperfect` (misses only recommended items), `follows` (misses nothing) and
/// `unknown` (not checked yet).
///
/// It is published, so it carries only what the page shows: no model, no
/// endpoint, no fingerprint.
const postGuideReportFileName = 'post-guide-report.json';

/// Where a published copy can be read when a viewer has no data of its own.
const postGuideReportPublishedUrl =
    'https://raw.githubusercontent.com/wispborne/StarsectorModRepo/main/$postGuideReportFileName';

/// The report for [file], with titles and authors from [index].
Map<String, dynamic> postGuideReport(PostGuideFile file, Iterable<QbModSummary> index) {
  final titles = {for (final summary in index) summary.topicId: summary};

  // The last pass's list says which threads are in scope today. A file saved
  // before passes were recorded only has its entries to go on.
  final ids = file.lastPassAt != null ? file.lastPassTopics : file.entries.keys.toList();
  final rows = <Map<String, dynamic>>[];
  final counts = {'failed': 0, 'imperfect': 0, 'follows': 0, 'unknown': 0};
  for (final id in ids) {
    final summary = titles[id];
    final entry = file.entries[id];
    final results = entry == null ? null : postGuideResults(entry);
    final missing = [
      for (final r in results ?? const <GuideItemResult>[])
        if (r.fails) r.item,
    ];
    final unanswered = (results ?? const <GuideItemResult>[]).where((r) => r.answer == null).length;
    final status = entry == null
        ? 'unknown'
        : missing.any((item) => item.required)
            ? 'failed'
            : missing.isNotEmpty
                ? 'imperfect'
                : 'follows';
    counts[status] = counts[status]! + 1;
    rows.add({
      'topicId': id,
      'title': summary?.title ?? 'Topic $id',
      'author': summary?.author ?? '',
      'url': 'https://fractalsoftworks.com/forum/index.php?topic=$id.0',
      'status': status,
      if (entry != null) 'checkedAt': entry.checkedAt.toIso8601String(),
      'missing': [
        for (final item in missing) {'id': item.id, 'reason': item.reason, 'required': item.required},
      ],
      'missingRequired': missing.where((item) => item.required).length,
      if (unanswered > 0) 'unanswered': unanswered,
    });
  }
  // Sorted by name: the bracketed game version and the dashes authors put
  // in front of a title would otherwise group the list by game version.
  String sortName(Map<String, dynamic> row) =>
      (row['title'] as String).replaceFirst(_leadingTags, '').toLowerCase();
  rows.sort((a, b) {
    final byName = sortName(a).compareTo(sortName(b));
    return byName != 0 ? byName : (a['topicId'] as int).compareTo(b['topicId'] as int);
  });

  return {
    'guide': postGuideUrl,
    'guideDate': postGuideDate.toIso8601String().substring(0, 10),
    if (file.lastPassAt != null) 'lastPassAt': file.lastPassAt!.toIso8601String(),
    'counts': {'threads': rows.length, ...counts},
    'items': [
      for (final item in postGuideItems)
        {'id': item.id, 'label': item.label, 'reason': item.reason, 'required': item.required},
    ],
    'rows': rows,
  };
}

/// Writes `<outputPath>/post-guide-report.json` from the saved checks in
/// [dataPath]. Does nothing when no post has been checked yet. Returns the
/// number of threads in the report, or null when nothing was written.
int? writePostGuideReport({required String dataPath, required String outputPath}) {
  final checks = File(p.join(dataPath, PostGuideStore.fileName));
  if (!checks.existsSync()) return null;
  final file = PostGuideFile.read(checks.readAsStringSync());
  final indexFile = File(p.join(dataPath, 'mods-index.json'));
  final index = indexFile.existsSync()
      ? [
          for (final e in jsonDecode(indexFile.readAsStringSync()) as List)
            QbModSummaryMapper.fromMap(e as Map<String, dynamic>),
        ]
      : const <QbModSummary>[];
  final report = postGuideReport(file, index);
  final out = File(p.join(outputPath, postGuideReportFileName));
  out.parent.createSync(recursive: true);
  final temp = File('${out.path}.tmp');
  temp.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  temp.renameSync(out.path);
  return (report['counts'] as Map)['threads'] as int;
}

/// Bracketed tags, dashes and spaces at the start of a thread title.
final RegExp _leadingTags = RegExp(r'^(?:\s|-|\[[^\]]*\]|\([^)]*\))*');
