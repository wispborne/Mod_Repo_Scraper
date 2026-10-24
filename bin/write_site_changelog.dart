import 'dart:io';

import 'package:mod_repo_scraper/site/site_changelog.dart';

/// Writes `site/changelog.json` from git: one entry for each commit that
/// changed the website. The release workflow runs it, so the published site
/// carries its own changelog. Run it from the repo's root folder.
void main() {
  final written = SiteChangelog(Directory.current.path).writeFromGit();
  if (written == null) {
    stderr.writeln('Could not read the git history, so no changelog was written.');
    exitCode = 1;
    return;
  }
  stdout.writeln('Wrote $written changelog entries to site/changelog.json.');
}
