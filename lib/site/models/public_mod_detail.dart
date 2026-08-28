import 'package:dart_mappable/dart_mappable.dart';

import 'mod_release.dart';
import 'public_mod.dart';

part 'public_mod_detail.mapper.dart';

/// `mods/<id>.json` — everything one mod's own page shows.
///
/// The page fetches this file and nothing else. [listing] is the same record
/// the browse page already has, repeated here so the page stands alone.
@MappableClass(ignoreNull: true)
class PublicModDetail with PublicModDetailMappable {
  /// When these files were built.
  final DateTime generatedAt;

  /// The mod as the browse page sees it — id, name, authors, versions and the
  /// switches the filters use.
  final PublicMod listing;

  /// A paragraph describing the mod, as plain words.
  final String? description;

  /// The same description with its formatting kept: paragraphs, lists,
  /// emphasis and links, and nothing else. Where the mod has a forum thread
  /// this is the author's own post, rebuilt from a short list of safe tags.
  final String? descriptionHtml;

  /// True when [description] is words the LLM wrote rather than words copied
  /// from the author's post.
  final bool descriptionIsGenerated;

  /// The paragraph the LLM wrote about this mod, whenever there is one — even
  /// when [description] already holds the author's own post. The detail page
  /// shows this in its own section unless the reader turned AI summaries off,
  /// so it has to be published beside the author's post rather than instead of
  /// it. Plain words, no formatting.
  final String? aiDescription;

  /// The author's own words on whether the mod can be added to a game already
  /// in progress. Null when the post does not say.
  final String? saveCompatibilityText;

  /// The shelves the forum's index and Discord's tags file this mod under. The
  /// list page shows the site's own short set instead; these are here so the
  /// mod's own page can still say how the sources file it.
  ///
  /// The merge has already folded plain synonyms together, so these are the
  /// sources' names as the merge holds them, not the exact words each source
  /// used. Anything that says where a mod was found rather than what it is —
  /// "Discord Only" — is left out, and published as a source instead.
  final List<String> rawCategories;

  /// Screenshots and other pictures from the post.
  final List<PublicImage> gallery;

  /// Every download the mod offers.
  final List<PublicDownload> downloads;

  /// The changelog split by version, keyed by the version string, copied word
  /// for word from the post.
  final Map<String, String> changelog;

  /// A link to a changelog the post points at instead of writing out. Null when
  /// the post offers none.
  final String? changelogUrl;

  /// The mod's license, in the author's own words. Null when the post does not
  /// say.
  final String? license;

  /// Where the mod's code is kept. Null when we know of nowhere.
  final String? sourceCodeUrl;

  /// Places readers can support the author.
  final List<PublicSupportLink> supportLinks;

  /// The mod's forum thread. Null when the mod has none.
  final String? forumUrl;

  /// The mod's Discord post. Null when the mod is not on Discord.
  final String? discordUrl;

  /// The mod's Nexus page. Null when the mod is not on Nexus.
  final String? nexusUrl;

  /// Every release recorded for this mod, newest first.
  final List<ModRelease> releases;

  /// The day this mod's forum thread was last posted on, or null when it has
  /// no thread or the forum gave no readable day. The same field as
  /// [PublicMod.threadLastPostOn], repeated here so the page stands alone.
  final String? threadLastPostOn;

  /// Every other published mod whose name matches this one's, so the page can
  /// say which is which. Empty for a mod whose name nothing else shares.
  ///
  /// Three different things end up in here and the page has to fit all three:
  /// this mod's own older thread, a fork that kept the name of the mod it
  /// forked, and a mod by somebody else that happens to be called the same.
  /// It was called `olderVersions` while it stood for the first of those alone
  /// and sat empty; a fork is not an older version of anything.
  final List<PublicSameNameMod> sameNameMods;

  /// Extra mods on the same thread that need this one. Empty on a thread with
  /// only one mod on it.
  final List<PublicAddon> addons;

  /// The title of the shared thread this mod was found on. The same field as
  /// [PublicMod.partOfThreadTitle], repeated here so the page stands alone.
  /// Null when this is the only mod on its thread and for every merged mod.
  final String? partOfThreadTitle;

  PublicModDetail({
    required this.generatedAt,
    required this.listing,
    this.description,
    this.descriptionHtml,
    this.descriptionIsGenerated = false,
    this.aiDescription,
    this.saveCompatibilityText,
    this.rawCategories = const [],
    this.gallery = const [],
    this.downloads = const [],
    this.changelog = const {},
    this.changelogUrl,
    this.license,
    this.sourceCodeUrl,
    this.supportLinks = const [],
    this.forumUrl,
    this.discordUrl,
    this.nexusUrl,
    this.releases = const [],
    this.threadLastPostOn,
    this.sameNameMods = const [],
    this.addons = const [],
    this.partOfThreadTitle,
  });
}

/// One picture from the mod's post.
@MappableClass(ignoreNull: true)
class PublicImage with PublicImageMappable {
  final String url;

  /// The picture's own caption or alt text. Null when it had none.
  final String? caption;

  PublicImage({required this.url, this.caption});
}

/// One way to get the mod.
///
/// [url] is the link as the post wrote it; [directUrl] is a straight-to-file
/// link where we could work one out. No confidence score is published — see the
/// `public-site-data` spec.
@MappableClass(ignoreNull: true)
class PublicDownload with PublicDownloadMappable {
  final String url;
  final String? directUrl;

  /// The file's name, where we know it.
  final String? fileName;

  /// `direct`, `mirror` or `trios`.
  final String kind;

  /// The link's text, copied from the post. Empty when the post had none.
  final String label;

  /// A plain name for where the file is hosted, e.g. "GitHub", "Google Drive".
  final String? host;

  /// True when the link needs a click or two on the host's own page before the
  /// file arrives.
  final bool needsAnotherStep;

  PublicDownload({
    required this.url,
    this.directUrl,
    this.fileName,
    this.kind = 'direct',
    this.label = '',
    this.host,
    this.needsAnotherStep = false,
  });
}

/// A place readers can support the mod's author.
@MappableClass(ignoreNull: true)
class PublicSupportLink with PublicSupportLinkMappable {
  final String url;

  /// A plain name for the kind of page, e.g. `patreon`, `kofi`.
  final String type;

  PublicSupportLink({required this.url, required this.type});
}

/// Another published mod that carries this one's name: its own older thread, a
/// fork that kept the name, or an unrelated mod that happens to share it.
///
/// [id] is that mod's page on this site, so the entry is a link a reader can
/// follow rather than a name they have to search for. It is optional because
/// the shape also has to hold a thread that was never published as a mod, and
/// then [url] — the forum thread — is the only address there is.
@MappableClass(ignoreNull: true)
class PublicSameNameMod with PublicSameNameModMappable {
  final String title;

  /// The mod's forum thread, where it has one. It is what a thread that was
  /// never published as a mod has instead of an [id].
  final String? url;

  /// The mod's page on this site, where it has one.
  final String? id;

  /// Who wrote it. The one fact that tells two unrelated mods of a name apart.
  final List<String> authors;

  final String? gameVersion;
  final String? modVersion;

  /// The day its forum thread was last posted on. Null where there is none.
  final String? threadLastPostOn;

  PublicSameNameMod({
    required this.title,
    this.url,
    this.id,
    this.authors = const [],
    this.gameVersion,
    this.modVersion,
    this.threadLastPostOn,
  });
}

/// Another download on the same thread that is not a mod of its own: either an
/// add-on that needs the main mod, or another build of it. Which one is
/// [role] — the two are shown apart, because installing an add-on beside the
/// mod is right and installing another build of it beside the mod is wrong.
@MappableClass(ignoreNull: true)
class PublicAddon with PublicAddonMappable {
  final String name;

  /// [PublicAddonRole.addon] or [PublicAddonRole.variant]. Defaults to
  /// `addon`, which is what every entry meant before this field existed.
  final String role;

  /// The name of the mod this one needs. Null when the post does not say.
  final String? requires;

  final List<PublicDownload> downloads;

  PublicAddon({
    required this.name,
    this.role = PublicAddonRole.addon,
    this.requires,
    this.downloads = const [],
  });
}

/// The two kinds of [PublicAddon]. Same words the LLM uses, published as they
/// are so the site and the extractor cannot drift apart over what they mean.
class PublicAddonRole {
  PublicAddonRole._();

  /// Something you install as well as the mod, and that needs it to work.
  static const String addon = 'addon';

  /// Another build of the mod itself — a lite version, a ships-only version.
  /// You install this INSTEAD of the mod, never beside it.
  static const String variant = 'variant';
}
