import '../bot/scraper/qb/models/post_extraction.dart';
import '../bot/scraper/scraped_mod.dart';
import '../site/mod_name_match.dart';
import '../site/post_html.dart';
import 'download_key.dart';
import 'listing.dart';
import 'source_post.dart';

/// What one source post gives the merge.
class PostListings {
  /// The listings that go into the merge.
  final List<Listing> listings;

  /// When the post is a Collection — two or more mods, none of them the one
  /// the rules named — this is the rules listing it dropped. Its name is the
  /// Collection's name, and its permanent id, if it already had one, stays
  /// reserved for a page listing the mods. Null when the post is not one.
  final Listing? collection;

  const PostListings(this.listings, {this.collection});

  bool get isCollection => collection != null;
}

/// Works out which mods one forum topic or Discord thread describes, by
/// combining the listing the rules found with the LLM's reading of the post.
///
/// Forum and Discord go through this one rule. Only the LLM's `main` mods that
/// are *grounded* count: the name has to be written in the author's opening run
/// and at least one download has to be tied to it. A model asked what a thread
/// holds will pad the list out, and a mod invented here would be given a
/// permanent address nobody can take back.
///
/// | Grounded main mods | Result |
/// | --- | --- |
/// | None | The rules listing, alone. |
/// | One | The rules listing with the LLM's facts, whatever either is called. |
/// | Two or more | One listing each. The rules listing joins the one whose name or grounded nickname matches its name or other names; when none does, the post is a Collection and the rules listing is dropped. |
///
/// Add-ons and variants are never listings: they are listed on their main
/// mod's page. A `separate` mod is no listing either.
///
/// With the LLM off, every post gives exactly its rules listing. The
/// Collection case is the only way the LLM can take the rules listing away; it
/// can never rename it or merge it into a different mod.
class SourcePostListings {
  SourcePostListings._();

  /// [rules] is the post's rules listing. [llmMods] is the LLM's answer for
  /// the post, empty when it has none. [postWords] is the plain text of the
  /// author's opening run, which a mod's name has to appear in.
  static PostListings combine({
    required Listing rules,
    required List<LlmMod> llmMods,
    required String? postWords,
  }) {
    final grounded = groundedMainMods(llmMods, postWords);

    if (grounded.isEmpty) {
      // Unchanged, except that the post's one LLM mod — where it is plain which
      // one — is where the mod's facts are read from. The listing itself is the
      // rules' own: same name, same everything.
      final factSource = _factSourceFor(rules, llmMods);
      return PostListings([
        factSource == null ? rules : rules.copyWith(ref: rules.ref.copyWith(llmModName: factSource.name)),
      ]);
    }

    if (grounded.length == 1) {
      return PostListings([_joined(rules, grounded.single)]);
    }

    final match = _matchFor(rules, grounded);
    if (match == null) {
      return PostListings(
        [for (final llmMod in grounded) _llmListing(rules, llmMod)],
        collection: rules,
      );
    }
    return PostListings([
      for (final llmMod in grounded)
        identical(llmMod, match) ? _joined(rules, llmMod) : _llmListing(rules, llmMod),
    ]);
  }

  /// The LLM's `main` mods on a post that count: named in the author's own
  /// words, with a download tied to them, each name once.
  ///
  /// Two mods offering exactly the same downloads are one mod, and only the
  /// first is kept: one file cannot be two mods. Discord thread
  /// 1355071745366822950 offers one Emergent Threats zip, and the LLM listed it
  /// as "Emergent Threats" and "ET: IX Revival", which made the thread a
  /// Collection and moved the mod off its own address.
  static List<LlmMod> groundedMainMods(List<LlmMod> llmMods, String? postWords) {
    final kept = <LlmMod>[];
    final keptDownloads = <Set<String>>[];
    for (final llmMod in llmMods) {
      if (llmMod.role != LlmModRole.main) continue;
      final name = llmMod.name.trim();
      if (name.isEmpty) continue;
      if (llmMod.downloads.isEmpty) continue;
      if (!postNames(name, postWords)) continue;
      if (kept.any((other) => modNamesMatch(other.name, name))) continue;
      final downloads = downloadKeysOf(llmMod);
      if (downloads.isNotEmpty && keptDownloads.any((other) => _sameSet(other, downloads))) continue;
      kept.add(llmMod);
      keptDownloads.add(downloads);
    }
    return kept;
  }

  static bool _sameSet(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

  /// The plain words of a source post's title and opening run, run together,
  /// for [combine]'s name check. The title counts because it is the author's
  /// own words too, and the extractor's own check counts it: topic 34457 names
  /// its four start options in its title and nowhere in the post.
  static String? openingRunWords(SourcePost post) {
    final words = <String>[
      if (post.title.trim().isNotEmpty) post.title.trim(),
      for (final entry in post.posts)
        if (plainWordsOf(cleanPostHtml(entry.contentHtml)) case final plain?) plain,
    ];
    return words.isEmpty ? null : words.join('\n\n');
  }

  /// True when the post really writes this name. `&nbsp;` in any spelling
  /// counts as a space, capitals do not matter, and runs of space are one.
  static bool postNames(String name, String? postWords) {
    if (postWords == null || postWords.isEmpty) return false;
    String tidy(String s) => s.replaceAll(_nbsp, ' ').toLowerCase().replaceAll(_spaces, ' ').trim();
    final wanted = tidy(name);
    return wanted.isNotEmpty && tidy(postWords).contains(wanted);
  }

  static final RegExp _nbsp = RegExp(r'&nbsp;|&#0*160;|&#x0*a0;', caseSensitive: false);
  static final RegExp _spaces = RegExp(r'\s+');

  /// The rules listing with one LLM mod's reading joined on. The name and
  /// everything else the rules found stay; the LLM adds the mod's version
  /// where the rules have none, its nicknames as other names, and the name its
  /// facts are filed under.
  static Listing _joined(Listing rules, LlmMod llmMod) => rules.copyWith(
        mod: rules.mod.copyWith(
          modVersion: _firstNonEmpty([rules.mod.modVersion, llmMod.extras?.version]),
        ),
        ref: rules.ref.copyWith(llmModName: llmMod.name.trim()),
        origin: ListingOrigin.rulesAndLlm,
        otherNames: [...rules.otherNames, ...?llmMod.nicknames],
        downloadKeys: downloadKeysOf(llmMod),
      );

  /// A listing for a mod only the LLM found on this post. It carries the post's
  /// own links — the forum topic, the Discord thread and the forum link a
  /// thread names, which is how the merge joins a Discord announcement to its
  /// own mod on a shared forum topic — but not the post's download links, which
  /// belong to whichever mod the rules picked them for.
  static Listing _llmListing(Listing rules, LlmMod llmMod) {
    final urls = <ModUrlType, String>{
      for (final entry in rules.mod.getUrls().entries)
        if (entry.key == ModUrlType.Forum || entry.key == ModUrlType.Discord || entry.key == ModUrlType.NexusMods)
          entry.key: entry.value,
    };
    final sources = rules.ref.kind == SourceKind.forum ? const [ModSource.ModdingSubforum] : rules.mod.sources;
    return Listing(
      mod: ScrapedMod(
        name: llmMod.name.trim(),
        gameVersionReq: rules.mod.gameVersionReq,
        modVersion: _firstNonEmpty([llmMod.extras?.version]),
        authorsList: rules.mod.authorsList,
        urls: urls,
        sources: sources,
        categories: rules.mod.categories,
        images: const {},
        dateTimeCreated: rules.mod.dateTimeCreated,
        dateTimeEdited: rules.mod.dateTimeEdited,
      ),
      ref: rules.ref.copyWith(llmModName: llmMod.name.trim()),
      origin: ListingOrigin.llm,
      otherNames: [...?llmMod.nicknames],
      postedAt: rules.postedAt,
      downloadKeys: downloadKeysOf(llmMod),
    );
  }

  /// The grounded mod whose name or nickname matches the rules listing's name
  /// or other names, or null.
  static LlmMod? _matchFor(Listing rules, List<LlmMod> grounded) {
    final rulesNames = [rules.mod.name, ...rules.otherNames];
    for (final llmMod in grounded) {
      final llmNames = [llmMod.name, ...?llmMod.nicknames];
      for (final a in rulesNames) {
        for (final b in llmNames) {
          if (modNamesMatch(a, b)) return llmMod;
        }
      }
    }
    return null;
  }

  /// Where the facts of a post with no grounded main mod are read from: an LLM
  /// mod with the rules listing's name, else the post's only main mod, else
  /// its only mod. This is the choice the site made for a merged mod before the
  /// catalog did it, so the pages keep their facts.
  static LlmMod? _factSourceFor(Listing rules, List<LlmMod> llmMods) {
    if (llmMods.isEmpty) return null;
    final rulesNames = [rules.mod.name, ...rules.otherNames];
    for (final llmMod in llmMods) {
      if (llmMod.name.trim().isEmpty) continue;
      if (rulesNames.any((name) => modNamesMatch(name, llmMod.name))) return llmMod;
    }
    final mains = [for (final m in llmMods) if (m.role == LlmModRole.main) m];
    if (mains.length == 1) return mains.single;
    if (mains.isEmpty && llmMods.length == 1) return llmMods.single;
    return null;
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }
}
