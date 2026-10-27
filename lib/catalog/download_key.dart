import '../bot/scraper/qb/llm/picture_caption_store.dart';
import '../bot/scraper/qb/models/post_extraction.dart';

/// A download address written so that two spellings of the same file compare
/// equal: no `http`/`https`, no `www.`, the host in lower case, no trailing
/// slash, and no Dropbox `dl=` switch (`?dl=0` opens a page, `?dl=1` sends the
/// file, and both are the same file). A file attached on Discord loses its
/// signature (`ex`, `is`, `hm`), which changes on every fetch, and is filed
/// under one host whichever of Discord's two it was given on. Null for an
/// address that is not http(s).
///
/// Used only to tell whether two listings offer the same file. It is never
/// published or followed.
String? downloadKey(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) return null;
  var host = uri.host.toLowerCase();
  if (host.startsWith('www.')) host = host.substring(4);
  final discord = PictureCaptionStore.isDiscordAttachment(url);
  if (discord) host = 'cdn.discordapp.com';
  var path = uri.path;
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  final query = {
    for (final entry in uri.queryParameters.entries)
      if (entry.key != 'dl' && !(discord && const {'ex', 'is', 'hm'}.contains(entry.key)))
        entry.key: entry.value,
  };
  final queryText = query.isEmpty ? '' : '?${(query.keys.toList()..sort()).map((k) => '$k=${query[k]}').join('&')}';
  return '$host$path$queryText';
}

/// The keys of every download the LLM tied to [mod]: the address in the post,
/// and the file it leads to where the resolver found one.
Set<String> downloadKeysOf(LlmMod mod) => {
      for (final download in mod.downloads)
        for (final url in [download.url, download.resolvedDirectUrl])
          if (url != null)
            if (downloadKey(url) case final key?) key,
    };
