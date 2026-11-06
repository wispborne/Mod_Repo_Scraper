/// The text matching shared by the Mods list, the Source posts list and
/// `GET /api/search`, so a search box and a full list always agree about
/// which rows match.
///
/// A row matches when any of its fields contains the search text, ignoring
/// capitals. The lists keep their own order; the search box ranks the same
/// rows by how well they matched (see [rankSearch]).
library;

/// The field type, which determines the match rank.
enum SearchFieldKind {
  /// The row's id: a mod's permanent id, a topic or thread id.
  id,

  /// The row's name: a mod's name, a post's title.
  name,

  /// Another name for the same thing: a nickname, the LLM's name for a mod,
  /// a mod made from a post. An exact match, or one at its start, ranks with
  /// the name. A forum title starts with its game version, so the name of the
  /// mod a topic became is often the better match.
  alias,

  /// Anything else, such as an author.
  other,
}

/// One piece of text a row can be found by.
class SearchField {
  final SearchFieldKind kind;
  final String text;

  /// Why the row is in the results when this field matched, such as
  /// "author: Histidine". Null when the row's own name or id says it.
  final String? detail;

  const SearchField(this.kind, this.text, {this.detail});

  const SearchField.id(this.text)
      : kind = SearchFieldKind.id,
        detail = null;
}

/// How well a row matched. A lower [rank] is better.
class SearchHit {
  /// 0: the id, the name or another name is exactly the text.
  /// 1: the name or another name starts with the text. 2: the name contains
  /// it. 3: another field starts with it. 4: another field contains it.
  final int rank;

  /// The length of the name that matched, for ranks 1 and 2, so the closest
  /// name comes first. 0 otherwise.
  final int nameLength;

  final String? detail;

  const SearchHit(this.rank, this.nameLength, this.detail);
}

/// The search text as the lists compare it.
String searchQuery(String q) => q.trim().toLowerCase();

/// Whether any field contains [query] (already passed through [searchQuery]).
/// An empty query matches every row.
bool matchesSearch(String query, Iterable<SearchField> fields) {
  if (query.isEmpty) return true;
  for (final field in fields) {
    if (field.text.toLowerCase().contains(query)) return true;
  }
  return false;
}

/// The best way [fields] match [query], or null when none does. Agrees with
/// [matchesSearch]: a row it matches always gets a hit.
///
/// When fields match equally well, the first one in [fields] gives the note.
/// No note is given when the displayed name contains the text.
/// The name already shows why the row matched.
SearchHit? rankSearch(String query, Iterable<SearchField> fields) {
  if (query.isEmpty) return null;
  SearchHit? best;
  var nameHolds = false;
  for (final field in fields) {
    final hit = _hitOn(query, field);
    if (hit == null) continue;
    if (field.kind == SearchFieldKind.name && field.detail == null) nameHolds = true;
    if (best == null || hit.rank < best.rank || (hit.rank == best.rank && hit.nameLength < best.nameLength)) {
      best = hit;
    }
  }
  if (best != null && nameHolds && best.detail != null) return SearchHit(best.rank, best.nameLength, null);
  return best;
}

SearchHit? _hitOn(String query, SearchField field) {
  final text = field.text.toLowerCase();
  if (!text.contains(query)) return null;
  final exact = text == query;
  final starts = text.startsWith(query);
  switch (field.kind) {
    case SearchFieldKind.id:
      if (exact) return const SearchHit(0, 0, null);
      return SearchHit(starts ? 3 : 4, 0, 'id: ${field.text}');
    case SearchFieldKind.name:
      if (exact) return SearchHit(0, 0, field.detail);
      return SearchHit(starts ? 1 : 2, text.length, field.detail);
    case SearchFieldKind.alias:
      if (exact) return SearchHit(0, 0, field.detail);
      return starts ? SearchHit(1, text.length, field.detail) : SearchHit(4, 0, field.detail);
    case SearchFieldKind.other:
      return SearchHit(starts ? 3 : 4, 0, field.detail);
  }
}

/// A searchable row: its search fields, sort order for equal matches,
/// and response data.
class Searchable {
  /// The fields it is found by.
  final List<SearchField> fields;

  /// The name shown in the results, used to break ties.
  final String sortName;

  /// The id, used to break ties last.
  final String id;

  /// The row in the search response, without `detail`.
  final Map<String, dynamic> item;

  const Searchable({required this.fields, required this.sortName, required this.id, required this.item});
}

/// The rows in [rows] that match [query], best first, and the total count. Rows that matched equally well keep name order, then id
/// order. Each row carries `detail` when it matched on something other than
/// its name or id.
({int total, List<Map<String, dynamic>> items}) searchRows(String query, Iterable<Searchable> rows, int limit) {
  final hits = <(Searchable, SearchHit)>[];
  for (final row in rows) {
    final hit = rankSearch(query, row.fields);
    if (hit != null) hits.add((row, hit));
  }
  hits.sort((a, b) {
    final byRank = a.$2.rank.compareTo(b.$2.rank);
    if (byRank != 0) return byRank;
    final byLength = a.$2.nameLength.compareTo(b.$2.nameLength);
    if (byLength != 0) return byLength;
    final byName = a.$1.sortName.toLowerCase().compareTo(b.$1.sortName.toLowerCase());
    return byName != 0 ? byName : a.$1.id.compareTo(b.$1.id);
  });
  return (
    total: hits.length,
    items: [
      for (final (row, hit) in hits.take(limit)) {...row.item, if (hit.detail != null) 'detail': hit.detail},
    ],
  );
}
