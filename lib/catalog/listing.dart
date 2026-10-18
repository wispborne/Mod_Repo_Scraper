import 'package:dart_mappable/dart_mappable.dart';

import '../bot/scraper/scraped_mod.dart';
import 'download_key.dart';
import 'source_post.dart';

part 'listing.mapper.dart';

/// Who found a listing: the scraper's fixed rules, the LLM, or the rules with
/// the LLM's reading of the same post joined on.
@MappableEnum()
enum ListingOrigin { rules, llm, rulesAndLlm }

/// One mod as one source post describes it. A forum topic gives one listing
/// per mod it holds, a Discord thread the same, a Nexus page one. The merge's
/// job is to join listings that describe the same mod.
///
/// [mod] is the same [ScrapedMod] the merge has always read, so its grouping,
/// name matching and tidying are unchanged. [ref] says which post the listing
/// came from, and — for a listing the LLM found or joined — which of the LLM's
/// mods it is, so a reader can look its facts up without matching names.
@MappableClass(ignoreNull: true)
class Listing with ListingMappable {
  final ScrapedMod mod;
  final SourcePostRef ref;
  final ListingOrigin origin;

  /// Other names the post uses for this mod: the mod index's other lines for
  /// the same topic, and the LLM's grounded nicknames. Used to match the rules
  /// listing to one of several LLM mods; the merge does not read them.
  final List<String> otherNames;

  /// When the post was last written to, where the source says. Used to read the
  /// newer of two posts of one kind first.
  final DateTime? postedAt;

  /// The downloads the LLM tied to this mod, as [downloadKey]s. Empty for a
  /// listing the LLM had no part in. The merge reads them to join two listings
  /// with the same name that offer the same file, even when the two sources
  /// spell the author differently.
  final Set<String> downloadKeys;

  const Listing({
    required this.mod,
    required this.ref,
    this.origin = ListingOrigin.rules,
    this.otherNames = const [],
    this.postedAt,
    this.downloadKeys = const {},
  });

  bool get fromLlm => origin != ListingOrigin.rules;
}

/// One source post a merged mod came from, as the catalog records it: the
/// post, the LLM mod name where the LLM found or joined the listing, and who
/// found it.
@MappableClass(ignoreNull: true)
class CatalogSourcePost with CatalogSourcePostMappable {
  final SourceKind kind;
  final String id;
  final String? llmModName;
  final ListingOrigin foundBy;

  const CatalogSourcePost({
    required this.kind,
    required this.id,
    this.llmModName,
    this.foundBy = ListingOrigin.rules,
  });

  factory CatalogSourcePost.of(Listing listing) => CatalogSourcePost(
        kind: listing.ref.kind,
        id: listing.ref.id,
        llmModName: listing.ref.llmModName,
        foundBy: listing.origin,
      );

  SourcePostRef get ref => SourcePostRef(kind: kind, id: id, llmModName: llmModName);
}
