import 'dart:convert';
import 'dart:io';

import 'package:mod_repo_scraper/bot/scraper/qb/llm/post_guide_report.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// `outputs/post-guide-report.json`, which the scheduled job publishes.
void main() {
  late Directory dir;
  late String dataPath;
  late String outputPath;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('post_guide_report');
    dataPath = p.join(dir.path, 'qb_data');
    outputPath = p.join(dir.path, 'outputs');
    Directory(dataPath).createSync(recursive: true);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('writes nothing before any post is checked', () {
    expect(writePostGuideReport(dataPath: dataPath, outputPath: outputPath), isNull);
    expect(File(p.join(outputPath, postGuideReportFileName)).existsSync(), isFalse);
  });

  test('writes the report with titles, and never the model, endpoint or fingerprint', () {
    File(p.join(dataPath, 'mods-index.json')).writeAsStringSync(jsonEncode([
      {'topicId': 1, 'title': '[0.98a] My Mod', 'author': 'Someone', 'scrapedAt': '2026-11-01T00:00:00Z'},
    ]));
    File(p.join(dataPath, 'post-guide-checks.json')).writeAsStringSync(jsonEncode({
      'guideVersion': 1,
      'lastPass': {'at': '2026-11-06T11:05:00.000Z', 'topics': [1]},
      'topics': {
        '1': {
          'fingerprint': 'secret-fingerprint',
          'checkedAt': '2026-11-06T11:00:00.000Z',
          'model': 'scraper',
          'endpoint': 'https://llm.example.com/v1/chat/completions',
          'llm': {'aiDisclaimer': 'no'},
          'rules': {'gameVersionInTitle': 'yes', 'pictures': 'yes'},
        },
      },
    }));

    expect(writePostGuideReport(dataPath: dataPath, outputPath: outputPath), 1);
    final text = File(p.join(outputPath, postGuideReportFileName)).readAsStringSync();
    final report = jsonDecode(text) as Map<String, dynamic>;
    expect((report['rows'] as List).single['title'], '[0.98a] My Mod');
    expect((report['rows'] as List).single['status'], 'failed');
    expect(report['counts'], {'threads': 1, 'failed': 1, 'imperfect': 0, 'follows': 0, 'unknown': 0});
    for (final private in ['secret-fingerprint', 'llm.example.com', '"model"', '"endpoint"', '"fingerprint"']) {
      expect(text, isNot(contains(private)), reason: private);
    }
  });
}
