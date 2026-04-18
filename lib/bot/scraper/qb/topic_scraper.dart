import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:logging/logging.dart';

import 'forum_constants.dart';
import 'html_processor.dart';
import 'models/mod_detail.dart';
import 'throttled_client.dart';

class QbTopicScraper {
  final Logger _log;
  final ThrottledClient _client;

  static final RegExp _lazyImageAltRegex = RegExp(
    r'^https?://.+\.(png|jpg|jpeg|gif|webp|bmp|svg)',
    caseSensitive: false,
  );
  static final RegExp _postCountDigits = RegExp(r'[\d,]+');
  static final RegExp _postDateRegex =
      RegExp(r'on:\s*(.+?)\s*(?:\u00ab|\u00bb|Â»|»)');
  static final RegExp _lastEditRegex = RegExp(
    r'Last\s+Edit:\s*(.+?)(?:\s*(?:Â»|»|&raquo;)|$)',
    caseSensitive: false,
  );
  static final RegExp _htmlTagStrip = RegExp(r'<[^>]+>');
  static final RegExp _imgSrcRegex =
      RegExp(r'<img[^>]+src="([^"]+)"[^>]*/?>', caseSensitive: false);
  static final RegExp _altAttrRegex =
      RegExp(r'alt="([^"]*)"', caseSensitive: false);
  static final RegExp _linkRegex = RegExp(
    r'<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>',
    caseSensitive: false,
    dotAll: true,
  );
  static final RegExp _divTagRegex =
      RegExp(r'</?div\b[^>]*>', caseSensitive: false, dotAll: true);

  QbTopicScraper(this._client, {Logger? logger})
      : _log = logger ?? Logger('QbTopicScraper');

  Future<QbModDetail?> scrapeTopic(int topicId) async {
    final url = ForumConstants.topicUrl(topicId);
    _log.info('Scraping topic $topicId: $url');

    try {
      final response = await _client.get(Uri.parse(url));
      if (response.statusCode != 200) {
        _log.warning('Topic $topicId returned ${response.statusCode}');
        return null;
      }

      final doc = html_parser.parse(response.body);

      // Resolve lazy images in the parsed DOM
      _resolveLazyImages(doc);

      final firstPost = doc.querySelector(
              '#forumposts .windowbg') ??
          doc.querySelector('#forumposts .windowbg2');
      if (firstPost == null) {
        _log.warning('No posts found on topic $topicId');
        return null;
      }

      final title = _extractTitle(doc);
      final versionMatch = ForumConstants.gameVersionRegex.firstMatch(title);

      final authorInfo = _extractAuthorInfo(firstPost);
      final postDate = _extractPostDate(firstPost);
      final contentHtml = _extractContentHtml(firstPost);
      final lastEditDate = _extractLastEditDate(firstPost, contentHtml);
      final images = _extractImageUrls(contentHtml);
      final links = _extractLinks(contentHtml);

      return QbModDetail(
        topicId: topicId,
        title: title,
        gameVersion: versionMatch?.group(1),
        author: authorInfo.author,
        authorTitle: authorInfo.authorTitle,
        authorPostCount: authorInfo.postCount,
        authorAvatarPath: authorInfo.avatarUrl,
        postDate: postDate,
        lastEditDate: lastEditDate,
        contentHtml: contentHtml,
        images: images,
        links: links,
        scrapedAt: DateTime.now().toUtc(),
      );
    } catch (e) {
      _log.severe('Failed to scrape topic $topicId: $e');
      return null;
    }
  }

  void _resolveLazyImages(Document doc) {
    for (final img in doc.querySelectorAll('img')) {
      final src = img.attributes['src'] ?? '';
      if (!src.contains('loading.gif') && !src.contains('loading_sm.gif')) {
        continue;
      }

      final realUrl = img.attributes['data-imageurl'] ??
          img.attributes['data-src'] ??
          img.attributes['data-original'];

      if (realUrl != null && realUrl.isNotEmpty) {
        img.attributes['src'] = realUrl;
        continue;
      }

      final alt = img.attributes['alt'] ?? '';
      if (_lazyImageAltRegex.hasMatch(alt)) {
        img.attributes['src'] = alt;
        img.attributes['alt'] = '';
      }
    }
  }

  String _extractTitle(Document doc) {
    final topSubject = doc.querySelector('#top_subject');
    if (topSubject != null) {
      var raw = topSubject.text.replaceFirst('Topic:', '').trim();
      final readIdx = raw.toLowerCase().indexOf('(read');
      if (readIdx > 0) raw = raw.substring(0, readIdx).trim();
      raw = raw.replaceAll('\u00a0', ' ').trim();
      return raw;
    }

    final h5Link = doc.querySelector("h5[id^='subject_'] a");
    if (h5Link != null) return h5Link.text.trim();

    final titleEl = doc.querySelector('title');
    return titleEl?.text ?? '';
  }

  _AuthorInfo _extractAuthorInfo(Element firstPost) {
    var author = '';
    String? authorTitle;
    var postCount = 0;
    String? avatarUrl;

    final poster = firstPost.querySelector('div.poster');
    if (poster != null) {
      final authorLink = poster.querySelector('h4 a');
      if (authorLink != null) author = authorLink.text.trim();

      final listItems = poster.querySelectorAll('ul li');
      for (var i = 0; i < listItems.length; i++) {
        final text = listItems[i].text.trim();

        if (i == 0 &&
            text.isNotEmpty &&
            !text.startsWith('Posts:')) {
          authorTitle = text;
        }

        if (text.toLowerCase().startsWith('posts:')) {
          final numMatch = _postCountDigits.firstMatch(text);
          if (numMatch != null) {
            postCount =
                int.tryParse(numMatch.group(0)!.replaceAll(',', '')) ?? 0;
          }
        }
      }

      final avatar = poster.querySelector('img.avatar');
      if (avatar != null) {
        final src = avatar.attributes['src'];
        if (src != null) avatarUrl = ForumConstants.stripPhpSessId(src);
      }
    }

    return _AuthorInfo(author, authorTitle, postCount, avatarUrl);
  }

  String? _extractPostDate(Element firstPost) {
    final dateEl = firstPost.querySelector('.keyinfo .smalltext');
    if (dateEl != null) {
      final raw = dateEl.text;
      final dateMatch = _postDateRegex.firstMatch(raw);
      if (dateMatch != null) return dateMatch.group(1)!.trim();
      return raw.trim();
    }
    return null;
  }

  String _extractContentHtml(Element firstPost) {
    final innerDiv = firstPost.querySelector('div.post div.inner');
    if (innerDiv != null) return innerDiv.innerHtml;

    final postDiv = firstPost.querySelector('div.post');
    if (postDiv != null) return postDiv.innerHtml;

    return firstPost.innerHtml;
  }

  String? _extractLastEditDate(Element firstPost, String contentHtml) {
    String? parseLastEdit(String source) {
      if (source.trim().isEmpty) return null;
      final match = _lastEditRegex.firstMatch(source);
      if (match == null) return null;
      final value = match.group(1)!.replaceAll(_htmlTagStrip, '').trim();
      return value.isEmpty ? null : value;
    }

    // 1) Check smalltext spans in the post
    for (final el in firstPost.querySelectorAll('span.smalltext')) {
      final parsed = parseLastEdit(el.text);
      if (parsed != null && parsed.isNotEmpty) return parsed;
    }

    // 2) Check content HTML
    final parsedFromHtml = parseLastEdit(contentHtml);
    if (parsedFromHtml != null && parsedFromHtml.isNotEmpty) {
      return parsedFromHtml;
    }

    // 3) Full post text fallback
    return parseLastEdit(firstPost.text);
  }

  static List<ImageRef> _extractImageUrls(String html) {
    final images = <ImageRef>[];
    final seen = <String>{};

    for (final m in _imgSrcRegex.allMatches(html)) {
      final src = ForumConstants.stripPhpSessId(m.group(1)!);
      if (src.isEmpty || src.startsWith('data:')) continue;
      if (src.toLowerCase().contains('/smileys/') ||
          src.toLowerCase().contains('/icons/') ||
          src.toLowerCase().contains('star.gif')) {
        continue;
      }
      if (!seen.add(src)) continue;

      final altMatch = _altAttrRegex.firstMatch(m.group(0)!);
      images.add(ImageRef(
        originalUrl: src,
        localPath: '',
        alt: altMatch?.group(1),
      ));
    }

    return images;
  }

  static List<LinkRef> _extractLinks(String html) {
    final links = <LinkRef>[];
    final spoilerRanges = _findSpoilerRanges(html);
    final seen = <String>{};

    for (final m in _linkRegex.allMatches(html)) {
      if (spoilerRanges
          .any((r) => m.start >= r.start && m.start < r.end)) {
        continue;
      }

      final href = ForumConstants.stripPhpSessId(
          HtmlProcessor.decodeEntities(m.group(1)!).trim());
      final text = m.group(2)!.replaceAll(_htmlTagStrip, '').trim();

      if (href.isEmpty || href.startsWith('#') || href.startsWith('javascript:')) {
        continue;
      }
      if (!seen.add(href)) continue;

      final isExternal = !ForumConstants.isForumHosted(href);
      links.add(LinkRef(url: href, text: text, isExternal: isExternal));
    }

    return links;
  }

  static List<_Range> _findSpoilerRanges(String html) {
    final ranges = <_Range>[];
    if (html.isEmpty) return ranges;

    var spoilerStart = -1;
    var depth = 0;

    for (final m in _divTagRegex.allMatches(html)) {
      final tag = m.group(0)!;
      final isClose = tag.toLowerCase().startsWith('</div');

      if (spoilerStart < 0) {
        if (isClose) continue;
        if (!tag.toLowerCase().contains('sp-wrap')) continue;
        spoilerStart = m.start;
        depth = 1;
        continue;
      }

      if (isClose) {
        depth--;
      } else {
        depth++;
      }

      if (depth == 0) {
        ranges.add(_Range(spoilerStart, m.start + m.group(0)!.length));
        spoilerStart = -1;
      }
    }

    return ranges;
  }

}

class _AuthorInfo {
  final String author;
  final String? authorTitle;
  final int postCount;
  final String? avatarUrl;

  _AuthorInfo(this.author, this.authorTitle, this.postCount, this.avatarUrl);
}

class _Range {
  final int start;
  final int end;

  _Range(this.start, this.end);
}
