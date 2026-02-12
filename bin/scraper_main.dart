import 'dart:io';

import 'package:usc_scraper/bot/scraper/main_repo_scraper.dart';

Future<void> main(List<String> args) async {
  await MainRepoScraper.main(args);
  exit(0);
}
