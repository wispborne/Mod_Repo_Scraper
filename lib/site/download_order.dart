import 'models/public_mod_detail.dart';

/// Puts a mod's downloads in the order a reader should try them, best first.
///
/// A mod can offer a dozen links, and a page that shows all of them as buttons
/// is asking the reader to guess. So the site shows one and says how many more
/// there are. This is the rule that decides which one, and it is the same rule
/// TriOS's catalog uses to pick the button on a mod's card — the two should
/// never disagree about which download is best.
///
/// Two deliberate differences from TriOS:
///
/// - TriOS refuses to lead with a link that needs another step on the host's
///   own page. On a website every download is a link the browser follows
///   anyway, so such a link is pushed down rather than thrown out: sending a
///   reader to a MediaFire page is worse than a straight file, and much better
///   than "here is the forum thread, go and find it".
/// - TriOS breaks ties inside a kind using the LLM's confidence score. The site
///   publishes no score — see the `public-site-data` spec — so the sorting is
///   done here, before publishing, and the site simply takes the first.
///
/// The order:
///
/// 1. A TriOS link, always. It installs what the mod needs as well, and opening
///    it *is* the extra step, so it is never counted as needing one.
/// 2. Anything that goes straight to a file.
/// 3. Anything that needs a click or two on the host's own page.
///
/// Inside 2 and 3, a plain download comes before a mirror. Two downloads the
/// rule cannot tell apart keep the order the post wrote them in.
List<PublicDownload> sortedDownloads(List<PublicDownload> downloads) {
  final ordered = [...downloads];
  // A stable sort, so equal downloads keep the post's own order.
  mergeSortByRank(ordered, _rankOf);
  return ordered;
}

/// The download a button should offer, or null when the mod has none.
PublicDownload? bestDownloadOf(List<PublicDownload> downloads) =>
    downloads.isEmpty ? null : sortedDownloads(downloads).first;

/// True when this download hands the reader a file rather than another page.
///
/// A TriOS link is always counted as one: it is the whole point of the link
/// that opening it does the work. Most of them are marked as needing another
/// step, because the download resolver could not turn the link into a file —
/// which is true of it and beside the point.
bool goesStraightToAFile(PublicDownload download) =>
    isTriosLink(download) || !download.needsAnotherStep;

/// True when this is a TriOS link, which installs the mod and everything it
/// needs.
bool isTriosLink(PublicDownload download) => download.kind == 'trios';

/// Where a download sits in the order. Lower comes first.
int _rankOf(PublicDownload download) {
  if (isTriosLink(download)) return 0;
  final needsAnotherStep = download.needsAnotherStep ? 2 : 0;
  final isMirror = download.kind == 'mirror' ? 1 : 0;
  // 1, 2: straight to a file, download then mirror.
  // 3, 4: needs another step, download then mirror.
  return 1 + needsAnotherStep + isMirror;
}

/// Sorts [items] by [rankOf], keeping the order of anything that ranks the
/// same.
///
/// Dart's own `sort` is not stable, and two downloads the rule cannot tell
/// apart must come out in the order the author's post wrote them.
void mergeSortByRank<T>(List<T> items, int Function(T) rankOf) {
  final byRank = <int, List<T>>{};
  for (final item in items) {
    byRank.putIfAbsent(rankOf(item), () => <T>[]).add(item);
  }
  final ranks = byRank.keys.toList()..sort();
  var at = 0;
  for (final rank in ranks) {
    for (final item in byRank[rank]!) {
      items[at++] = item;
    }
  }
}
