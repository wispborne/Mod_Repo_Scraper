import '../bot/scraper/qb/models/assumed_download.dart';
import '../bot/scraper/qb/models/post_extraction.dart';
import '../bot/scraper/scraped_mod.dart';
import 'models/public_mod_detail.dart';

/// The download link a Discord announcement carried, ready to publish, or null
/// when it carried nothing worth showing.
///
/// The website used to throw these away. Every download it published came off a
/// forum thread — the LLM's per-thread list, or the resolver's candidates,
/// both keyed by forum topic id — so a mod announced only on Discord reached
/// the site with no download button and fell back to "On Discord". That was 224
/// of 1,112 published mods. The Astartes Minipack is the one that made it
/// obvious: its Google Drive link was sitting in `ModRepo.json` the whole time.
///
/// Only the Discord reader fills in [ModUrlType.DirectDownload] and
/// [ModUrlType.DownloadPage]. TriOS already reads the first of them
/// (`catalogDirect`, in its `catalog_download_resolver.dart`), so this is the
/// two agreeing about a mod's download rather than the site inventing one.
///
/// Two things stop it publishing nonsense, and both were found in real data.
///
/// **Not every one of these URLs is a download.** `getUrlsFromMessage` in
/// `discord_reader.dart` ends with `?? forumUrl`, so a mod whose announcement
/// had no download link of its own gets its forum thread stored as the download
/// page — 138 of them do. A button saying "Download page" that opens the forum
/// thread is worse than the "On the forum" button it would replace. Discord
/// message links and a link to a subreddit are wrong the same way. The merge
/// knows about this one and only strips it in a single narrow case
/// (`_dropForumLinksToOtherMods` in `mod_merger.dart`), so it is dealt with
/// here.
///
/// **`DirectDownload` does not mean the file arrives.** It means the scraper's
/// probe thought the URL was downloadable. Google Drive `/file/d/.../view`
/// links are filed under it and open Drive's preview page; so does every
/// mega.nz link. So the host decides [PublicDownload.needsAnotherStep] here,
/// not which of the two fields the URL came out of. [PublicDownload.directUrl]
/// is set only where the file really does arrive, because the "Has a download"
/// switch on the browse page tests that field and promises "a link that goes
/// straight to a file".
///
/// A link that is plainly a download but plainly dead — the example-mod thread
/// offers `https://DownloadThisMod.com` — is published as a dead link, which is
/// what the site does with every other dead download.
PublicDownload? discordDownloadFor(Map<ModUrlType, String> urls) {
  for (final field in const [
    ModUrlType.DirectDownload,
    ModUrlType.DownloadPage,
  ]) {
    final url = urls[field]?.trim() ?? '';
    if (url.isEmpty || _isNotADownload(url, urls)) continue;
    return _asDownload(url);
  }
  return null;
}

/// Hosts and paths that are somewhere to read about a mod, not somewhere to get
/// it. Matched against the host and path together, so a path decides where the
/// host alone would not.
const _notDownloads = [
  'fractalsoftworks.com/forum',
  'discord.com/channels',
  'discordapp.com/channels',
  'reddit.com',
];

/// The mod's own pages. Each already has a button of its own, so offering one
/// as a download says the same thing twice and says it less honestly.
const _ownPages = [
  ModUrlType.Forum,
  ModUrlType.Discord,
  ModUrlType.NexusMods,
];

bool _isNotADownload(String url, Map<ModUrlType, String> urls) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return true;
  if (!uri.isScheme('http') && !uri.isScheme('https')) return true;
  if (uri.host.isEmpty) return true;

  for (final field in _ownPages) {
    if ((urls[field]?.trim() ?? '') == url) return true;
  }

  final where = '${uri.host}${uri.path}'.toLowerCase();
  return _notDownloads.any((bad) => where.contains(bad));
}

PublicDownload _asDownload(String url) {
  final fileName = _archiveNameIn(url);
  final straightToAFile = fileName != null || _skipsTheHostsOwnPage(url);
  final host = AssumedDownloadCandidate.inferSourceHost(url);

  return PublicDownload(
    url: url,
    directUrl: straightToAFile ? url : null,
    fileName: fileName,
    kind: LlmDownloadKind.direct,
    host: host.isEmpty ? null : host,
    needsAnotherStep: !straightToAFile,
  );
}

/// True for the addresses a host offers when you want the file rather than the
/// page about it: Google Drive's `export=download` and Dropbox's `dl=1`.
bool _skipsTheHostsOwnPage(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  try {
    final query = uri.queryParameters;
    return query['export'] == 'download' || query['dl'] == '1';
  } on FormatException {
    return false;
  }
}

final _archiveName = RegExp(r'\.(zip|rar|7z|jar)$', caseSensitive: false);

/// The file's name, when the address ends in an archive we can name. This is
/// also what says the link hands over a file: a GitHub release asset, a raw
/// file and a Dropbox share all end this way, while Drive's `/view` and
/// mega.nz's `/file/<key>` do not.
String? _archiveNameIn(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  try {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty);
    if (segments.isEmpty) return null;
    final last = segments.last;
    return _archiveName.hasMatch(last) ? last : null;
  } on FormatException {
    // A path we cannot decode is a path we cannot name a file from.
    return null;
  }
}
