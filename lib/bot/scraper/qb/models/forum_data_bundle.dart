import 'package:dart_mappable/dart_mappable.dart';

import 'assumed_download.dart';
import 'bundle_meta.dart';
import 'mod_detail.dart';
import 'mod_summary.dart';

part 'forum_data_bundle.mapper.dart';

@MappableClass(ignoreNull: true)
class ForumDataBundle with ForumDataBundleMappable {
  final DateTime updatedAt;
  final BundleMeta? meta;
  final List<QbModSummary> index;
  final Map<String, QbModDetail> details;
  final Map<String, List<AssumedDownloadCandidate>> assumedDownloads;

  ForumDataBundle({
    required this.updatedAt,
    this.meta,
    this.index = const [],
    this.details = const {},
    this.assumedDownloads = const {},
  });
}
