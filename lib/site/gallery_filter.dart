import 'package:html/parser.dart' as html_parser;

// Classify gallery pictures by host, URL and stated dimensions. Unknown sizes
// remain eligible as screenshots. Non-screenshots are published as small;
// forum furniture is omitted.

/// How wide a picture has to be before it can be a screenshot, where the post
/// says how wide it is.
const int smallestScreenshot = 200;

/// Hosts that only ever serve buttons, badges and avatars.
const List<String> _badgeHosts = [
  'ko-fi.com',
  'storage.ko-fi.com',
  'buymeacoffee.com',
  'img.buymeacoffee.com',
  'cdn.buymeacoffee.com',
  'patreon.com',
  'c5.patreon.com',
  'shields.io',
  'img.shields.io',
  'badgen.net',
  'forthebadge.com',
  'paypal.com',
  'paypalobjects.com',
  'liberapay.com',
  'img.youtube.com',
  'gravatar.com',
  'secure.gravatar.com',
];

/// Parts of a forum address that are the forum's own furniture rather than
/// anything an author posted. Only read on the forum's own host — a Starsector
/// mod's repository also keeps its pictures in a `graphics/` folder, and those
/// are the author's own.
const List<String> _forumFurniture = [
  '/smileys/',
  '/themes/',
  '/avatars/',
  '/graphics/',
];

/// Words in an address that say the picture is a button, a badge, an avatar or
/// a loading spinner — never a picture of a mod, whoever is asking. The
/// gallery's stricter words (logos, icons) are in [_notAScreenshot] below,
/// because a mod's own logo is a fine picture for its card but a poor
/// "screenshot".
final RegExp _neverAModPicture = RegExp(
  r'(donate|donation|button|badge|patreon|kofi|ko-fi|buymeacoffee|paypal'
  r'|avatar|signature|smiley|emoticon|banner_ad|favicon|favico|loading\.gif)',
  caseSensitive: false,
);

/// Words in an address that say the picture is not a screenshot, on top of
/// [_neverAModPicture]: a logo or an icon is the mod's mark, not a picture of
/// it running, and 88x31 is the size of the old web's little badges.
final RegExp _notAScreenshot = RegExp(
  r'(_icon|-icon|/icon|logo|88x31)',
  caseSensitive: false,
);

/// Hosts that only serve license badges. Kept out of the gallery only, not out
/// of [isBadgeOrDonationImage], because that list also decides what the LLM is
/// shown, and changing it would mean paying to read those threads again.
const List<String> _licenseBadgeHosts = [
  'creativecommons.org',
  'licensebuttons.net',
];

/// True when [url] can never be a picture of a mod at all: a donation button,
/// a badge, an avatar, a forum smiley, a loading spinner, or a piece of the
/// forum's own furniture. Shared with the LLM extraction step, which uses it
/// to keep such pictures out of the list the model may pick a mod's picture
/// from — [looksLikeAScreenshot] adds the gallery's stricter rules on top.
///
/// An address that cannot be parsed is not called a badge — the caller
/// decides what to do with those.
bool isBadgeOrDonationImage(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return false;

  final address = Uri.tryParse(trimmed);
  if (address == null) return false;

  final host = address.host.toLowerCase();
  for (final banned in _badgeHosts) {
    if (host == banned || host.endsWith('.$banned')) return true;
  }
  final path = address.path.toLowerCase();

  if (isForumFurniture(trimmed)) return true;

  // The query is where the forum puts its attachment ids, and an attachment is
  // a picture the author uploaded — so only the path is read for these words.
  return _neverAModPicture.hasMatch(path);
}

/// True when [url] is a piece of the forum's own furniture — a smiley, a theme
/// graphic, an avatar — rather than anything an author posted. The gallery
/// never publishes these, where it publishes every other picture and only
/// marks the small ones.
bool isForumFurniture(String url) {
  final address = Uri.tryParse(url.trim());
  if (address == null) return false;

  final host = address.host.toLowerCase();
  if (host != 'fractalsoftworks.com' && !host.endsWith('.fractalsoftworks.com')) {
    return false;
  }
  final path = address.path.toLowerCase();
  return _forumFurniture.any(path.contains);
}

/// A size written into a `style` attribute, e.g. "width: 64px".
final RegExp _styleWidth =
    RegExp(r'width\s*:\s*(\d+)\s*px', caseSensitive: false);

/// True when [url] looks like a picture of the mod rather than a button, a
/// badge or a piece of the forum's own furniture.
///
/// [sizes] is what the post said about how wide its pictures are, from
/// [pictureSizesInPost]. A picture the post said nothing about is kept — a
/// missing size is not evidence.
bool looksLikeAScreenshot(String url, {Map<String, int> sizes = const {}}) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return false;

  final address = Uri.tryParse(trimmed);
  if (address == null) return false;

  if (isBadgeOrDonationImage(trimmed)) return false;

  final host = address.host.toLowerCase();
  for (final banned in _licenseBadgeHosts) {
    if (host == banned || host.endsWith('.$banned')) return false;
  }

  // Same rule as [isBadgeOrDonationImage]: only the path is read for words.
  if (_notAScreenshot.hasMatch(address.path.toLowerCase())) return false;

  final width = sizes[trimmed];
  if (width != null && width < smallestScreenshot) return false;

  return true;
}

/// How wide the post said each of its pictures is, keyed by the picture's
/// address. A picture with no width given is left out of the map rather than
/// guessed at.
Map<String, int> pictureSizesInPost(String? postHtml) {
  final source = postHtml?.trim();
  if (source == null || source.isEmpty) return const {};

  final sizes = <String, int>{};
  for (final img in html_parser.parseFragment(source).querySelectorAll('img')) {
    final src = img.attributes['src']?.trim();
    if (src == null || src.isEmpty) continue;

    final width = int.tryParse(img.attributes['width']?.trim() ?? '') ??
        int.tryParse(_styleWidth.firstMatch(img.attributes['style'] ?? '')?[1] ?? '');
    if (width != null && width > 0) sizes[src] = width;
  }
  return sizes;
}
