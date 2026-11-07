import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_detail.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/mod_summary.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/scraper_engine.dart';
import 'package:test/test.dart';

/// Which stored threads a new-data scrape fetches again, so a first post
/// edited without a new reply still reaches the post guide check.
void main() {
  final now = DateTime.utc(2026, 11, 6, 12);

  QbModSummary summary(int id, {int hoursOld = 24}) => QbModSummary(
        topicId: id,
        title: 'Topic $id',
        scrapedAt: now.subtract(Duration(hours: hoursOld)),
      );

  // 1: posted after the guide. 2: old, edited after the guide. 3: old and
  // untouched since. 4: a placeholder.
  final details = {
    1: QbModDetail(topicId: 1, postDate: 'October 02, 2026, 10:00:00 AM'),
    2: QbModDetail(
        topicId: 2,
        postDate: 'May 04, 2014, 01:33:25 AM',
        lastEditDate: 'October 30, 2026, 08:07:22 AM by Someone'),
    3: QbModDetail(
        topicId: 3,
        postDate: 'May 04, 2014, 01:33:25 AM',
        lastEditDate: 'August 30, 2026, 08:07:22 AM by Someone'),
    4: QbModDetail(topicId: 4, postDate: 'October 02, 2026, 10:00:00 AM', isPlaceholderDetail: true),
  };
  Future<QbModDetail?> load(int id) async => details[id];

  test('picks threads the guide covers whose copy is old enough, oldest first', () async {
    final picked = await QbScraperEngine.guidePostsToRecheck(
      stored: [summary(1, hoursOld: 21), summary(2, hoursOld: 30), summary(3), summary(4)],
      scraping: {},
      loadDetail: load,
      now: now,
    );
    expect(picked, [2, 1]);
  });

  test('leaves out a copy fetched less than 20 hours ago, and threads already being fetched', () async {
    final picked = await QbScraperEngine.guidePostsToRecheck(
      stored: [summary(1, hoursOld: 12), summary(2)],
      scraping: {2},
      loadDetail: load,
      now: now,
    );
    expect(picked, isEmpty);
  });

  test('takes at most the limit', () async {
    final picked = await QbScraperEngine.guidePostsToRecheck(
      stored: [summary(1, hoursOld: 25), summary(2, hoursOld: 30)],
      scraping: {},
      loadDetail: load,
      now: now,
      limit: 1,
    );
    expect(picked, [2]);
  });
}
