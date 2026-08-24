import 'package:dart_mappable/dart_mappable.dart';

part 'public_mod.mapper.dart';

/// `mods.json` — every mod the site can list, plus the day the files were built.
///
/// This is the one file the browse page fetches whole, so it holds only what a
/// card and a filter need. Everything else lives in the per-mod files.
@MappableClass(ignoreNull: true)
class PublicModList with PublicModListMappable {
  /// When these files were built. Every page shows this, so a reader can see
  /// how fresh the data is.
  final DateTime generatedAt;

  final List<PublicMod> mods;

  PublicModList({required this.generatedAt, this.mods = const []});
}

/// One mod as the browse page sees it.
///
/// Nothing here comes from the config file, and nothing here is a local path or
/// a run id — see the `public-site-data` spec. [summary] is the one field that
/// may be words the LLM wrote rather than copied, and [summaryIsGenerated] says
/// which it is.
@MappableClass(ignoreNull: true)
class PublicMod with PublicModMappable {
  /// The mod's permanent id, handed out the first time the mod was seen and
  /// never changed after that. The mod's web address is built from it.
  final String id;

  /// The mod's name as its thread wrote it, brackets, version and all. The
  /// site searches this, so an old spelling still finds the mod.
  final String name;

  /// The name a reader sees: [name] with the bracketed game version, the mod
  /// version, any date and any leading dash taken off. Left out when it would
  /// be the same as [name], to keep this file small.
  final String? displayName;

  /// Every person credited, tidied and folded together across sources.
  final List<String> authors;

  /// The other names each of these people is known by, keyed by the name in
  /// [authors], so a search for an old or Discord-only spelling still finds
  /// their mods. It never repeats a name already in [authors].
  ///
  /// Kept per person, not as one list for the mod: on a mod by two people, a
  /// flat list made each of them look like another name for the other.
  final Map<String, List<String>> otherAuthorNames;

  /// The site's own short set of categories — see `public_categories.dart`.
  /// The names each source gave the mod are kept on its own page instead, so
  /// nothing is lost, and this stays a list a reader can browse by.
  final List<String> categories;

  /// Where the mod was found: `forum`, `discord`, `nexus`. It is what tells a
  /// reader that a mod with no forum thread is a Discord one, which used to be
  /// published as a category called "Discord Only".
  final List<String> sources;

  /// The game version the mod is for, e.g. "0.98a".
  final String? gameVersion;

  /// The mod's own version, as the author wrote it. Null when nothing readable
  /// was found.
  final String? modVersion;

  /// One picture for the card. Null when the mod has none.
  final String? imageUrl;

  /// A single line describing the mod.
  final String? summary;

  /// True when [summary] is words the LLM wrote rather than words copied from
  /// the author's post. The site labels these, and can hide them.
  final bool summaryIsGenerated;

  /// True when the mod can be added to a game already in progress, false when
  /// it needs a new one, null when nobody said.
  final bool? saveCompatible;

  /// True when at least one download goes straight to a file.
  final bool hasDirectDownload;

  /// The download a button should offer, picked by `download_order.dart`. Null
  /// when the mod has none, in which case the site offers the forum thread.
  ///
  /// This is the one thing about downloads that `mods.json` carries, because
  /// browse loads that file whole and draws hundreds of cards from it — a card
  /// that had to fetch a mod's own file to know what its button does would mean
  /// hundreds of requests to draw one page.
  final PublicBestDownload? bestDownload;

  /// How many downloads the mod offers. The card shows the best one and says
  /// how many more there are.
  final int downloadCount;

  /// The mod's forum thread. Null when it has none.
  ///
  /// A quarter of mods have nothing to download, and their card offers the
  /// thread instead — so the address has to be in the file the cards are drawn
  /// from, not only in the mod's own file.
  final String? forumUrl;

  /// The mod's Discord post. Null when it is not on Discord.
  ///
  /// The other half of the same fallback: 160 mods have no download and no
  /// forum thread, and every one of them is on Discord. Without this their
  /// cards are the only ones on the page offering nothing at all.
  final String? discordUrl;

  /// True when we know where the mod's code is kept.
  final bool sourceIsPublic;

  /// True when the thread marks the mod as a work in progress.
  final bool isWorkInProgress;

  /// The day the mod last put out a new version, as the release feed saw it.
  /// Null when no release has been recorded for it yet.
  final DateTime? lastReleaseDate;

  /// The day this mod first showed up, as `YYYY-MM-DD` — the day its forum
  /// thread was posted, or the day of the Discord message or Nexus page it was
  /// read from, whichever is earlier. Where there is no such date, the day we
  /// first gave it an id stands in. It is what "newest" and "recently added"
  /// mean on the site.
  final String? addedOn;

  /// The other mods this one will not run without. Nearly every Starsector mod
  /// needs LazyLib, MagicLib, GraphicsLib or Nexerelin, and knowing which is
  /// the single most useful thing a reader can be told before they download.
  final List<PublicNeededMod> needs;

  PublicMod({
    required this.id,
    required this.name,
    this.displayName,
    this.authors = const [],
    this.otherAuthorNames = const {},
    this.categories = const [],
    this.sources = const [],
    this.gameVersion,
    this.modVersion,
    this.imageUrl,
    this.summary,
    this.summaryIsGenerated = false,
    this.saveCompatible,
    this.hasDirectDownload = false,
    this.bestDownload,
    this.downloadCount = 0,
    this.forumUrl,
    this.discordUrl,
    this.sourceIsPublic = false,
    this.isWorkInProgress = false,
    this.lastReleaseDate,
    this.addedOn,
    this.needs = const [],
  });
}

/// One mod another mod needs.
///
/// [name] is what the post called it. [id] is the page it belongs to on this
/// site, where the name matched a mod we publish — so most of these are links,
/// and the rest are still worth naming.
@MappableClass(ignoreNull: true)
class PublicNeededMod with PublicNeededModMappable {
  final String name;
  final String? id;

  PublicNeededMod({required this.name, this.id});
}

/// The download a card or a row offers, as `mods.json` carries it.
///
/// [url] is one address, already resolved: the straight-to-file link where the
/// resolver worked one out, and the link as the post wrote it otherwise. The
/// unresolved link is of no use to a card, and this file is the one the whole
/// site loads at once, so only one address is published.
@MappableClass(ignoreNull: true)
class PublicBestDownload with PublicBestDownloadMappable {
  final String url;

  /// `direct`, `mirror` or `trios`.
  final String kind;

  /// True when the link opens the host's own page rather than handing over the
  /// file. The button says so, so nobody is surprised by what they land on.
  final bool needsAnotherStep;

  PublicBestDownload({
    required this.url,
    this.kind = 'direct',
    this.needsAnotherStep = false,
  });
}
