import 'package:dart_mappable/dart_mappable.dart';

part 'post_extraction.mapper.dart';

/// A changelog the LLM found in a post. A post can have both: [link] is a URL
/// to the mod's changelog when the post offers one, and [entries] holds the
/// changelog copied word-for-word (never summarized), split by version — keyed
/// by the version string, valued by that version's notes. Either or both may be
/// set. Each entry is checked against the post.
@MappableClass(ignoreNull: true)
class LlmChangelog with LlmChangelogMappable {
  final String? link;
  final Map<String, String>? entries;

  LlmChangelog({this.link, this.entries});

  /// True when there is no link and no entries.
  bool get isEmpty =>
      (link == null || link!.isEmpty) && (entries == null || entries!.isEmpty);
}

/// A place readers can support the mod author (Patreon, Ko-fi, PayPal, ...).
/// [url] is the link exactly as it appeared in the post; [type] is what kind
/// of page it is, worked out from the link's host — see [SupportLinkType].
@MappableClass()
class LlmSupportLink with LlmSupportLinkMappable {
  final String url;
  final String type;

  LlmSupportLink({required this.url, required this.type});

  /// Builds a support link, working out its [type] from the [url]'s host.
  factory LlmSupportLink.fromUrl(String url) =>
      LlmSupportLink(url: url, type: SupportLinkType.fromUrl(url));
}

/// Names the kind of support page a URL points at, based on its host. Returns
/// [other] for any host we don't have a name for. The values are plain,
/// lowercase words so the viewer and TriOS can match on them.
class SupportLinkType {
  SupportLinkType._();

  static const String other = 'other';

  /// Each entry: a substring to look for in the host, and the type name to use
  /// when it's found. Checked in order, first match wins.
  static const List<(String, String)> _hostRules = [
    ('patreon.', 'patreon'),
    ('ko-fi.', 'kofi'),
    ('kofi.', 'kofi'),
    ('paypal.', 'paypal'),
    ('buymeacoffee.', 'buymeacoffee'),
    ('buymeacoff.ee', 'buymeacoffee'),
    ('liberapay.', 'liberapay'),
    ('subscribestar.', 'subscribestar'),
    ('boosty.', 'boosty'),
    ('opencollective.', 'opencollective'),
    ('github.com/sponsors', 'githubsponsors'),
  ];

  /// Works out the support type from a URL. Looks at the host (and, for GitHub
  /// Sponsors, the path). Falls back to [other].
  static String fromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return other;
    final host = uri.host.toLowerCase();
    // GitHub Sponsors lives on a path, so check host+path for that one.
    final hostAndPath = '$host${uri.path}'.toLowerCase();
    for (final (needle, type) in _hostRules) {
      final hay = needle.contains('/') ? hostAndPath : host;
      if (hay.contains(needle)) return type;
    }
    return other;
  }
}

/// A short, plain-English description of the mod that the LLM writes in its own
/// words. Unlike everything else the extractor pulls, this is NOT copied from
/// the post — it is generated, and only when the summaries option is on.
/// [sentence] is a single sentence; [paragraph] is a few sentences.
@MappableClass(ignoreNull: true)
class LlmModSummary with LlmModSummaryMappable {
  final String? sentence;
  final String? paragraph;

  LlmModSummary({this.sentence, this.paragraph});

  /// True when neither summary was produced.
  bool get isEmpty =>
      (sentence == null || sentence!.isEmpty) &&
      (paragraph == null || paragraph!.isEmpty);
}

/// The optional extras the LLM produces from a single post read: the mod's own
/// version, a changelog, support links, the license, whether it can be added to
/// an existing save, and (only when the summaries option is on) a generated
/// [summary]. Every copied field is filled only when the post actually states
/// it; [summary] is written in the model's own words, so it is the one field not
/// taken verbatim from the post.
/// - [saveCompatibility]: the post's own words on whether the mod can be added to
///   an ongoing game or needs a new one (e.g. "Save compatible", "Requires a new
///   game"), copied word-for-word. Null when the post does not say.
@MappableClass(ignoreNull: true)
class LlmExtras with LlmExtrasMappable {
  final String? version;
  final LlmChangelog? changelog;
  final List<LlmSupportLink>? supportLinks;
  final String? license;
  final String? saveCompatibility;
  final LlmModSummary? summary;

  LlmExtras({
    this.version,
    this.changelog,
    this.supportLinks,
    this.license,
    this.saveCompatibility,
    this.summary,
  });

  /// True when none of the extra fields were produced.
  bool get isEmpty =>
      (version == null || version!.isEmpty) &&
      (changelog == null || changelog!.isEmpty) &&
      (supportLinks == null || supportLinks!.isEmpty) &&
      (license == null || license!.isEmpty) &&
      (saveCompatibility == null || saveCompatibility!.isEmpty) &&
      (summary == null || summary!.isEmpty);
}

/// What kind of link a download is. Plain, lowercase words so the viewer and
/// TriOS can match on them.
/// - [direct]: a normal download of the mod's file.
/// - [mirror]: the same file offered on another host.
/// - [trios]: an "Install with TriOS" link.
class LlmDownloadKind {
  LlmDownloadKind._();

  static const String direct = 'direct';
  static const String mirror = 'mirror';
  static const String trios = 'trios';

  static const List<String> all = [direct, mirror, trios];

  /// Returns [value] when it is a known kind, else [direct].
  static String orDirect(String? value) =>
      all.contains(value) ? value! : direct;
}

/// How a mod on a thread relates to the others.
/// - [main]: the thread's primary mod.
/// - [addon]: an optional extra that needs another mod (see [LlmMod.requires]).
/// - [separate]: an unrelated second mod that stands on its own.
/// - [variant]: an alternative build of the main mod.
class LlmModRole {
  LlmModRole._();

  static const String main = 'main';
  static const String addon = 'addon';
  static const String separate = 'separate';
  static const String variant = 'variant';

  static const List<String> all = [main, addon, separate, variant];

  /// Returns [value] when it is a known role, else [main].
  static String orMain(String? value) => all.contains(value) ? value! : main;
}

/// One download the LLM assigned to a mod. The LLM chooses the link and its
/// [kind]; the download resolver then fills the rest, so the entry stands alone.
/// - [url]: the raw link exactly as it appeared in the post.
/// - [label]: the link text copied word-for-word (empty when the post had none).
/// - [kind]: [LlmDownloadKind] — direct, mirror, or trios.
/// - [resolvedDirectUrl], [sourceHost], [fileName], [confidence],
///   [requiresManualStep]: filled by the resolver, the same work the rules-based
///   download step does. [resolvedDirectUrl] is null when the resolver could not
///   turn the link into a direct download (e.g. an unknown host).
@MappableClass(ignoreNull: true)
class LlmDownload with LlmDownloadMappable {
  final String url;
  final String label;
  final String kind;
  final String? resolvedDirectUrl;
  final String sourceHost;
  final String? fileName;
  final String confidence;
  final bool requiresManualStep;

  LlmDownload({
    this.url = '',
    this.label = '',
    this.kind = LlmDownloadKind.direct,
    this.resolvedDirectUrl,
    this.sourceHost = '',
    this.fileName,
    this.confidence = 'medium',
    this.requiresManualStep = false,
  });
}

/// One mod the LLM found on a thread. A thread carries a list of these — one for
/// a single-mod thread, more for a thread with several mods or a main mod plus
/// add-ons. Each mod owns its own [downloads] and [extras].
/// - [name]: the mod's name as stated in the post.
/// - [role]: [LlmModRole] — main, addon, separate, or variant.
/// - [requires]: the name of the mod an add-on needs, else null.
/// - [downloads]: the mod's grouped downloads (see [LlmDownload]).
/// - [image]: an image from the post that clearly belongs to THIS mod, stored as
///   `ext:<url>` — the same form as the thread's `thumbnailPath`, so a consumer
///   handles it the same way. Most useful when a post offers several mods or a
///   main mod plus add-ons, so each one can show its own picture. Null when the
///   post ties no image to this mod (a single-mod thread already has a
///   thread-level thumbnail).
/// - [extras]: version, changelog, support links, license, summary. Null when
///   the LLM found none.
@MappableClass(ignoreNull: true)
class LlmMod with LlmModMappable {
  final String name;
  final String role;
  final String? requires;
  final List<LlmDownload> downloads;
  final String? image;
  final LlmExtras? extras;

  LlmMod({
    this.name = '',
    this.role = LlmModRole.main,
    this.requires,
    this.downloads = const [],
    this.image,
    this.extras,
  });

  /// True when this mod carries nothing worth publishing. An image alone does
  /// not count: it decorates a mod, it does not make an otherwise-empty entry
  /// worth keeping.
  bool get isEmpty =>
      name.isEmpty &&
      downloads.isEmpty &&
      (extras == null || extras!.isEmpty);
}

/// Everything the LLM produced for one thread: the [mods] it found, always a
/// list — a single-mod thread is a one-item list. This sits on the thread's
/// `index` item as its `llm` field and is the complete, standalone answer for
/// that thread's mods and downloads when present.
@MappableClass(ignoreNull: true)
class LlmThreadData with LlmThreadDataMappable {
  final List<LlmMod> mods;

  LlmThreadData({this.mods = const []});

  /// True when there are no mods, or every mod is empty.
  bool get isEmpty => mods.every((m) => m.isEmpty);
}
