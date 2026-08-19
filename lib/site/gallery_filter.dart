import 'package:html/parser.dart' as html_parser;

/// Tells a screenshot from everything else in a forum post.
///
/// A post's pictures are not all screenshots. Most threads carry a "Buy me a
/// coffee" button, a build badge, the author's avatar, a title banner and a
/// handful of the forum's own smileys, and publishing all of them as
/// "Screenshots" made the gallery useless.
///
/// Three rules, in order of how sure they are:
///
/// - The host says what it is. Nothing hosted by Ko-fi, Patreon or a badge
///   service is a screenshot of a mod.
/// - The address says what it is: "donate", "button", "badge", "avatar".
/// - The post says how big it is. A picture under [smallestScreenshot] pixels
///   on its widest side is a button or an icon, whatever it is called. Where
///   the post gives no size, nothing is assumed and the picture is kept.

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
/// anything an author posted.
const List<String> _forumFurniture = [
  '/smileys/',
  '/themes/',
  '/avatars/',
  '/graphics/',
];

/// Words in an address that say the picture is a button, a badge or an avatar.
final RegExp _notAScreenshot = RegExp(
  r'(donate|donation|button|badge|patreon|kofi|ko-fi|buymeacoffee|paypal'
  r'|avatar|signature|smiley|emoticon|banner_ad|favicon|favico|_icon|-icon|/icon|logo)',
  caseSensitive: false,
);

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

  final host = address.host.toLowerCase();
  for (final banned in _badgeHosts) {
    if (host == banned || host.endsWith('.$banned')) return false;
  }

  final path = address.path.toLowerCase();
  for (final part in _forumFurniture) {
    if (path.contains(part)) return false;
  }

  // The query is where the forum puts its attachment ids, and an attachment is
  // a picture the author uploaded — so only the path is read for these words.
  if (_notAScreenshot.hasMatch(path)) return false;

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
