import 'package:mod_repo_scraper/site/download_order.dart';
import 'package:mod_repo_scraper/site/models/public_mod_detail.dart';
import 'package:test/test.dart';

/// The rule that decides which download a button offers.
///
/// Every list on the site shows one download and says how many more there are,
/// so this rule is the difference between a reader landing on the file and a
/// reader landing on a page full of adverts. It is meant to agree with TriOS's
/// catalog, which picks the button on a mod's card the same way.
void main() {
  PublicDownload download({
    String url = 'https://example.com/mod.zip',
    String? directUrl,
    String kind = 'direct',
    String label = '',
    bool needsAnotherStep = false,
  }) =>
      PublicDownload(
        url: url,
        directUrl: directUrl,
        kind: kind,
        label: label,
        needsAnotherStep: needsAnotherStep,
      );

  List<String> labelsOf(List<PublicDownload> downloads) =>
      sortedDownloads(downloads).map((d) => d.label).toList();

  test('a TriOS link leads, because it installs what the mod needs as well',
      () {
    final sorted = labelsOf([
      download(label: 'plain', directUrl: 'https://example.com/mod.zip'),
      download(label: 'trios', kind: 'trios'),
    ]);

    expect(sorted, ['trios', 'plain']);
  });

  test('a TriOS link leads even when it is marked as needing another step', () {
    // Most trilinks are marked that way, because the download resolver could
    // not turn the link into a file. Opening the link is the whole point of it.
    final sorted = labelsOf([
      download(label: 'plain', directUrl: 'https://example.com/mod.zip'),
      download(label: 'trios', kind: 'trios', needsAnotherStep: true),
    ]);

    expect(sorted, ['trios', 'plain']);
  });

  test('a link straight to a file beats one that opens the host\'s own page',
      () {
    final sorted = labelsOf([
      download(label: 'mediafire page', needsAnotherStep: true),
      download(label: 'straight to it', directUrl: 'https://example.com/a.zip'),
    ]);

    expect(sorted, ['straight to it', 'mediafire page']);
  });

  test('a short link the resolver could not follow keeps its place in the post', () {
    // Topic 35821 links to its release through dub.sh.
    // The debug build is on Google Drive in a spoiler further down.
    final sorted = labelsOf([
      download(
          label: 'release',
          url: 'https://dub.sh/hXs53ZS',
          needsAnotherStep: true),
      download(
          label: 'debug build',
          url: 'https://drive.google.com/uc?export=download&id=1',
          directUrl: 'https://drive.google.com/uc?export=download&id=1'),
    ]);

    expect(sorted, ['release', 'debug build']);
  });

  test('a short link stays after a file link listed earlier in the post', () {
    final sorted = labelsOf([
      download(label: 'straight to it', directUrl: 'https://example.com/a.zip'),
      download(
          label: 'short link',
          url: 'https://bit.ly/abc',
          needsAnotherStep: true),
    ]);

    expect(sorted, ['straight to it', 'short link']);
  });

  test('a short link comes before a page that needs another step', () {
    final sorted = labelsOf([
      download(label: 'mediafire page', needsAnotherStep: true),
      download(
          label: 'short link',
          url: 'https://dub.sh/abc',
          needsAnotherStep: true),
    ]);

    expect(sorted, ['short link', 'mediafire page']);
  });

  test('a short link still needs another step for the download button', () {
    final shortLink = download(url: 'https://dub.sh/abc', needsAnotherStep: true);

    expect(goesStraightToAFile(shortLink), isFalse);
  });

  test('a mirror that hands over the file beats a download that does not', () {
    final sorted = labelsOf([
      download(label: 'slow host', needsAnotherStep: true),
      download(label: 'mirror', kind: 'mirror'),
    ]);

    expect(sorted, ['mirror', 'slow host']);
  });

  test('among links that all hand over the file, a mirror comes last', () {
    final sorted = labelsOf([
      download(label: 'mirror', kind: 'mirror'),
      download(label: 'plain'),
    ]);

    expect(sorted, ['plain', 'mirror']);
  });

  test('two downloads the rule cannot tell apart keep the post\'s own order',
      () {
    final sorted = labelsOf([
      download(label: 'first the post named'),
      download(label: 'second the post named'),
      download(label: 'third the post named'),
    ]);

    expect(sorted, [
      'first the post named',
      'second the post named',
      'third the post named',
    ]);
  });

  test('the whole order, worst to best, comes back best first', () {
    final sorted = labelsOf([
      download(label: 'mirror page', kind: 'mirror', needsAnotherStep: true),
      download(label: 'download page', needsAnotherStep: true),
      download(label: 'mirror file', kind: 'mirror'),
      download(label: 'plain file'),
      download(label: 'trios', kind: 'trios', needsAnotherStep: true),
    ]);

    expect(sorted, [
      'trios',
      'plain file',
      'mirror file',
      'download page',
      'mirror page',
    ]);
  });

  test('the best download of nothing is nothing', () {
    expect(bestDownloadOf(const []), isNull);
  });

  test('the best download is the first one the sorting puts out', () {
    final downloads = [
      download(label: 'page', needsAnotherStep: true),
      download(label: 'file'),
    ];

    expect(bestDownloadOf(downloads)?.label, 'file');
  });

  test('the plain download is the best one that is not a TriOS link', () {
    final downloads = [
      download(label: 'page', needsAnotherStep: true),
      download(label: 'trios', kind: 'trios'),
      download(label: 'file'),
    ];

    expect(plainDownloadOf(downloads)?.label, 'file');
  });

  test('there is no plain download unless the best download is a TriOS link', () {
    expect(plainDownloadOf([download(label: 'file')]), isNull,
        reason: 'the best download is already a plain download');
    expect(plainDownloadOf([download(label: 'trios', kind: 'trios')]), isNull,
        reason: 'there is no download other than the TriOS link');
    expect(plainDownloadOf(const []), isNull);
  });

  test('a TriOS link never counts as needing another step', () {
    expect(
      goesStraightToAFile(download(kind: 'trios', needsAnotherStep: true)),
      isTrue,
    );
    expect(goesStraightToAFile(download(needsAnotherStep: true)), isFalse);
    expect(goesStraightToAFile(download()), isTrue);
  });

  test('sorting leaves the list it was given alone', () {
    final downloads = [
      download(label: 'page', needsAnotherStep: true),
      download(label: 'file'),
    ];
    sortedDownloads(downloads);

    expect(downloads.map((d) => d.label), ['page', 'file']);
  });
}
