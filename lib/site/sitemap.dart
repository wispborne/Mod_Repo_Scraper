import 'guide_page_html.dart';
import 'models/public_mod.dart';

/// Where the public website is served from. A sitemap has to give whole
/// addresses, so this is the one place the site's own address is written down.
/// Everything else on the site uses addresses relative to the page.
const String siteAddress = 'https://starmodder.wispborne.com/';

/// `sitemap.xml`: the front page, the install guide and every mod's own page,
/// so a search engine finds every mod without having to run the site's script
/// and follow links.
///
/// Each mod carries the day it last changed where we know one — its newest
/// release or the last post on its forum thread, whichever is later — so a
/// search engine knows which pages are worth fetching again.
String buildSitemapXml(PublicModList list) {
  final out = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
    ..writeln('  <url><loc>$siteAddress</loc></url>')
    ..writeln('  <url><loc>$siteAddress$guideFolder/</loc></url>');

  for (final mod in list.mods) {
    final address = '${siteAddress}mods/${Uri.encodeComponent(mod.id)}/';
    final day = _lastChanged(mod);
    out.writeln(day == null
        ? '  <url><loc>${_escape(address)}</loc></url>'
        : '  <url><loc>${_escape(address)}</loc>'
            '<lastmod>$day</lastmod></url>');
  }

  out.writeln('</urlset>');
  return out.toString();
}

/// `robots.txt`: every page may be read, and this is where the sitemap is.
String buildRobotsTxt() => 'User-agent: *\n'
    'Allow: /\n'
    '\n'
    'Sitemap: ${siteAddress}sitemap.xml\n';

/// The later of the mod's newest release and the last post on its thread, as
/// `YYYY-MM-DD`. Null when neither is known.
String? _lastChanged(PublicMod mod) {
  final released =
      mod.lastReleaseDate?.toUtc().toIso8601String().substring(0, 10);
  final posted = _plainDay(mod.threadLastPostOn);
  if (released == null) return posted;
  if (posted == null) return released;
  // Both are written YYYY-MM-DD, so comparing the text compares the days.
  return released.compareTo(posted) >= 0 ? released : posted;
}

/// [text] when it is a plain `YYYY-MM-DD` day, which is the only shape a
/// sitemap accepts here.
String? _plainDay(String? text) {
  if (text == null) return null;
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) ? text : null;
}

String _escape(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
