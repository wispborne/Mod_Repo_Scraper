import 'days.dart';
import 'models/mod_release.dart';

/// The release feed written as an Atom file, so a reader can subscribe to it.
///
/// Modders and server admins live in feed readers and in Discord, and both can
/// take a feed file. It costs nothing to write — the same releases the site
/// already shows — and it is the thing most likely to bring somebody back
/// without them having to remember to visit.
///
/// Every link in it is **relative**. A feed reader resolves a relative link
/// against the address it fetched the feed from, which is exactly right here:
/// the site is served from whatever folder it was copied into, and it has no
/// one address to hard-code. Nothing from the config file gets in.

/// How many releases the file carries. The feed keeps every release ever
/// recorded, and a reader only wants the recent ones; without this the file
/// would grow for ever.
const int maxFeedEntries = 200;

/// A name that is this feed's alone, and never changes. Atom asks for one, and
/// a `tag:` name is the way to give one without owning a web address.
const String _feedName = 'tag:starmodder,2026:releases';

/// [feed] as an Atom file.
String buildReleaseFeedXml(ModReleaseFeed feed) {
  final out = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="utf-8"?>')
    ..writeln('<feed xmlns="http://www.w3.org/2005/Atom">')
    ..writeln('  <title>Starmodder — new Starsector mod releases</title>')
    ..writeln('  <subtitle>Mods whose version really moved forward, newest '
        'first.</subtitle>')
    ..writeln('  <id>$_feedName</id>')
    // Atom asks every feed for an author, and a feed without one is turned away
    // by validators and shown as authorless by some readers. Each entry is
    // about somebody else's mod, so the feed itself is the author.
    ..writeln('  <author><name>Starmodder</name></author>')
    ..writeln('  <updated>${_atomTime(feed.generatedAt)}</updated>')
    ..writeln('  <link rel="self" href="updates.xml"/>')
    ..writeln('  <link rel="alternate" type="text/html" href="index.html"/>');

  for (final release in feed.releases.take(maxFeedEntries)) {
    _writeEntry(out, release);
  }

  out.writeln('</feed>');
  return out.toString();
}

void _writeEntry(StringBuffer out, ModRelease release) {
  final page = 'index.html#/mods/${Uri.encodeComponent(release.modId)}';
  final name = '${release.modName} ${release.newVersion}'.trim();
  final story = release.oldVersion == null
      ? '${release.modName} is now at ${release.newVersion}.'
      : '${release.modName} went from ${release.oldVersion} to '
          '${release.newVersion}.';
  final notes = release.changelogNotes?.trim();

  out
    ..writeln('  <entry>')
    ..writeln('    <title>${_escape(name)}</title>')
    ..writeln('    <id>tag:starmodder,2026:release/${release.modId}/'
        '${release.newVersion}</id>')
    ..writeln('    <updated>${_atomDay(release.seenOn)}</updated>')
    ..writeln('    <link rel="alternate" type="text/html" '
        'href="${_escapeAttribute(page)}"/>')
    ..writeln('    <content type="text">'
        '${_escape(notes == null || notes.isEmpty ? story : '$story\n\n$notes')}'
        '</content>')
    ..writeln('  </entry>');
}

/// A moment written the way Atom wants it, always in UTC.
String _atomTime(DateTime when) {
  final at = when.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${at.year}-${two(at.month)}-${two(at.day)}T'
      '${two(at.hour)}:${two(at.minute)}:${two(at.second)}Z';
}

/// A `YYYY-MM-DD` day as the start of that day in UTC. A day with nothing
/// readable in it falls back to the start of time rather than failing the
/// build — one odd entry must not cost the whole file.
String _atomDay(String day) => _atomTime(readDay(day) ?? DateTime.utc(1970));

/// Characters XML has no way to carry. A changelog copied off a forum post can
/// hold the odd stray control character, and one of those makes the whole file
/// unreadable to every feed reader.
final RegExp _cannotBeWritten = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]');

String _escape(String text) => text
    .replaceAll(_cannotBeWritten, '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

/// The same, plus the quote marks that would otherwise end an attribute early.
String _escapeAttribute(String value) =>
    _escape(value).replaceAll('"', '&quot;');
