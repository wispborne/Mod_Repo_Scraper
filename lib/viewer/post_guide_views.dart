import '../bot/scraper/qb/llm/post_guide_report.dart';
import 'data_access.dart';

/// The post guide report for `GET /api/post-guide`, the same report a build
/// publishes as `post-guide-report.json` ([postGuideReport]). Null when no
/// post has been checked yet; the page then reads the published copy.
Map<String, dynamic>? postGuideReportFor(DataAccess data) {
  final file = data.postGuideFile;
  if (file == null) return null;
  return postGuideReport(file, data.index ?? const []);
}
