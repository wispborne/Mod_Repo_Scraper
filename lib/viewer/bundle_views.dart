import 'compare_rows.dart';

/// Works out what changed between two saved bundles.
///
/// A bundle keeps its three parts apart — the index list, the details map and
/// the assumed downloads map, all keyed by topic id — so the first job is
/// putting one topic's pieces back together. After that it is the same
/// comparing the merge side does.

/// The fields worth waking somebody up over.
///
/// Left out on purpose: `scrapedAt`, `replies`, `views` and anything else that
/// moves whether or not the mod did. A list full of "scraped at a different
/// time" is a list nobody reads.
final List<ComparedField> bundleFields = [
  const ComparedField('title'),
  const ComparedField('author'),
  const ComparedField('category'),
  const ComparedField('lastPostDate', label: 'last post'),
  const ComparedField('isWip', label: 'work in progress'),
  const ComparedField('inModIndex', label: 'in the mod index'),
  const ComparedField('sourceBoard', label: 'board'),
  const ComparedField('thumbnailPath', label: 'thumbnail'),
  ComparedField('contentFingerprint',
      label: 'post text', describe: _describePostChange),
  const ComparedField('imageCount', label: 'images'),
  const ComparedField('links'),
  const ComparedField('downloads'),
  const ComparedField('llm', label: 'LLM facts'),
];

/// The post text is not kept in a snapshot, only a fingerprint of it, so there
/// is no before and after to show — just the fact that it moved.
String _describePostChange(Object? before, Object? after) {
  if (before == null) return 'The post text was read for the first time.';
  if (after == null) return 'The post text is no longer saved.';
  return 'The post text changed. The words themselves are not kept in a '
      'snapshot, so open the topic to see what it says now.';
}

/// One topic, with its index row, its detail and its downloads put back
/// together.
List<Map<String, dynamic>> topicsOf(Map<String, dynamic> snapshot) {
  final details = (snapshot['details'] as Map?) ?? const {};
  final downloads = (snapshot['assumedDownloads'] as Map?) ?? const {};

  final topics = <Map<String, dynamic>>[];
  for (final row in (snapshot['index'] as List?) ?? const []) {
    if (row is! Map) continue;
    final id = '${row['topicId']}';
    final detail = details[id];
    final download = downloads[id];

    topics.add({
      'topicId': row['topicId'],
      'title': row['title'],
      'author': row['author'],
      'category': row['category'],
      'lastPostDate': row['lastPostDate'],
      'isWip': row['isWip'],
      'inModIndex': row['inModIndex'],
      'sourceBoard': row['sourceBoard'],
      'thumbnailPath': row['thumbnailPath'],
      'llm': row['llm'],
      'contentFingerprint':
          detail is Map ? detail['contentFingerprint'] : null,
      'imageCount': detail is Map ? ((detail['images'] as List?) ?? const []).length : null,
      'links': detail is Map ? detail['links'] : null,
      'downloads': download is Map ? download['candidates'] : null,
    });
  }
  return topics;
}

/// Compares the topics two saved bundles ended up with.
Map<String, dynamic> compareBundles({
  required Map<String, dynamic> older,
  required Map<String, dynamic> newer,
}) =>
    compareRows(
      older: topicsOf(older),
      newer: topicsOf(newer),
      keyOf: (topic) => 'topic:${topic['topicId']}',
      fields: bundleFields,
      labelOf: (topic) => (topic['title'] as String?) ?? '',
      authorOf: (topic) => (topic['author'] as String?) ?? '',
      recordKey: 'topic',
    );
