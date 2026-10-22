import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:synchronized/synchronized.dart';

/// What kind of picture a post shows, as the model saw it.
enum PictureKind {
  /// The game running with the mod: a ship, a fleet, a menu.
  screenshot,

  /// The mod's name or emblem.
  logo,

  /// A title picture, usually wide, often with the mod's name on it.
  banner,

  /// A drawing, a portrait or ship art that is not a game screen.
  art,

  /// A link button such as "Download" or "Become a patron".
  button,

  /// A small label, shield or version mark.
  badge,

  /// A line or a spacer between parts of the post.
  divider,

  /// The host's notice that the picture is gone, such as Photobucket's or
  /// Imgur's "removed" picture. Old links rarely fail outright: they answer
  /// with one of these, and it looks like a real picture to everything else.
  missing,

  other,
}

/// How well a picture would work as the small picture on a mod's card or row
/// on the site, as the model judged it.
enum CardFit {
  /// Shows this mod clearly and still reads when shown small.
  good,

  /// Shows the mod, but is busy, a thin strip, or mostly words.
  okay,

  /// Not a picture of this mod at all.
  poor,
}

/// One picture as the model described it.
class PictureCaption {
  final PictureKind kind;

  /// One short sentence saying what the picture shows.
  final String caption;

  final CardFit fit;

  const PictureCaption({required this.kind, required this.caption, this.fit = CardFit.okay});

  /// True when the picture may never be a mod's card picture, whatever else
  /// asks for it.
  bool get neverOnACard =>
      fit == CardFit.poor ||
      const {PictureKind.missing, PictureKind.button, PictureKind.badge, PictureKind.divider}
          .contains(kind);

  /// How the extraction prompt shows it, after the picture's address.
  String get promptText => '${kind.name}: $caption';
}

/// The saved descriptions of the pictures in posts, so each picture is looked
/// at by the model once and not on every run.
///
/// Kept in `<qb_data_path>/picture-captions.json`, keyed by the picture's
/// address. A Discord attachment's address is kept without its query: Discord
/// signs the address afresh on every fetch while the picture stays the same.
///
/// A picture the model's server could not fetch (a dead imgur link, a forum
/// attachment that needs a login) is remembered as unreadable, so it is not
/// tried on every run. It is tried again after [retryUnreadableAfter], since a
/// host can be down for a day.
///
/// Saved as the run goes, every few captions or every few seconds, like the
/// LLM's own answers, so a run that is stopped keeps what it paid for.
class PictureCaptionStore {
  static const String fileName = 'picture-captions.json';

  /// Goes up when the caption prompt changes in a way that makes the old
  /// captions worth paying for again.
  static const int captionVersion = 3;

  static const Duration retryUnreadableAfter = Duration(days: 30);

  final String _dataPath;
  final Logger _log;
  final int _flushEveryN;
  final Duration _flushInterval;

  final Map<String, _Entry> _entries = {};
  final Lock _writeLock = Lock();
  int _dirtySinceFlush = 0;
  DateTime? _lastFlush;

  PictureCaptionStore(
    this._dataPath, {
    Logger? logger,
    int flushEveryN = 5,
    Duration flushInterval = const Duration(seconds: 5),
  })  : _log = logger ?? Logger('PictureCaptionStore'),
        _flushEveryN = flushEveryN,
        _flushInterval = flushInterval;

  File get _file => File(p.join(_dataPath, fileName));

  int get length => _entries.length;

  Future<void> load() async {
    final file = _file;
    if (!file.existsSync()) return;
    try {
      final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _entries.clear();
      final pictures = map['pictures'];
      if (pictures is! Map<String, dynamic>) return;
      for (final MapEntry(:key, :value) in pictures.entries) {
        if (value is! Map<String, dynamic>) continue;
        final entry = _Entry.fromJson(value);
        if (entry != null) _entries[key] = entry;
      }
    } catch (e) {
      // Losing the descriptions costs a few hours of the model's time, not
      // the run.
      _log.warning('Could not read ${file.path}; pictures will be looked at '
          'again: $e');
    }
  }

  /// The description of [url], or null when the model has not described it
  /// under the current [captionVersion].
  PictureCaption? captionFor(String url) {
    final entry = _entries[keyFor(url)];
    if (entry == null || entry.version != captionVersion) return null;
    return entry.caption;
  }

  /// True when the model's server could not fetch or open [url] when it last
  /// tried, whatever the version. A dead picture stays dead.
  bool isUnreadable(String url) => _entries[keyFor(url)]?.unreadable != null;

  /// True when [url] needs no call: it is described, or it could not be read
  /// lately.
  bool isDone(String url, {DateTime? now}) {
    final entry = _entries[keyFor(url)];
    if (entry == null) return false;
    if (entry.caption != null) return entry.version == captionVersion;
    final at = now ?? DateTime.now().toUtc();
    return at.difference(entry.at) < retryUnreadableAfter;
  }

  Future<void> putCaption(String url, PictureCaption caption,
          {String? model, String? endpoint, DateTime? now}) =>
      _put(
          url,
          _Entry(
            version: captionVersion,
            caption: caption,
            model: model,
            endpoint: endpoint,
            at: now ?? DateTime.now().toUtc(),
          ));

  /// Remembers that the model's server could not fetch [url], with its reason.
  Future<void> putUnreadable(String url, String reason, {DateTime? now}) => _put(
      url,
      _Entry(
        version: captionVersion,
        unreadable: reason,
        at: now ?? DateTime.now().toUtc(),
      ));

  Future<void> _put(String url, _Entry entry) async {
    _entries[keyFor(url)] = entry;
    _dirtySinceFlush++;
    final last = _lastFlush;
    if (_dirtySinceFlush >= _flushEveryN ||
        last == null ||
        DateTime.now().difference(last) >= _flushInterval) {
      await flush();
    }
  }

  /// Writes the file now. Through a temporary file, so a run killed while
  /// writing never leaves half a file behind.
  Future<void> flush() => _writeLock.synchronized(() async {
        _lastFlush = DateTime.now();
        if (_dirtySinceFlush == 0 && _file.existsSync()) return;
        _dirtySinceFlush = 0;
        final file = _file;
        await file.parent.create(recursive: true);
        final keys = _entries.keys.toList()..sort();
        final text = const JsonEncoder.withIndent('  ').convert({
          'pictures': {for (final key in keys) key: _entries[key]!.toJson()},
        });
        final temp = File('${file.path}.tmp');
        await temp.writeAsString(text);
        await temp.rename(file.path);
      });

  /// The key a picture is filed under: its address, trimmed, with the query
  /// taken off a Discord attachment's.
  static String keyFor(String url) {
    final trimmed = url.trim();
    if (!isDiscordAttachment(trimmed)) return trimmed;
    final q = trimmed.indexOf('?');
    return q < 0 ? trimmed : trimmed.substring(0, q);
  }

  /// True when [url] is a file attached to a Discord message.
  static bool isDiscordAttachment(String url) {
    final address = Uri.tryParse(url.trim());
    if (address == null) return false;
    final host = address.host.toLowerCase();
    return (host == 'cdn.discordapp.com' || host == 'media.discordapp.net') &&
        address.pathSegments.isNotEmpty &&
        address.pathSegments.first == 'attachments';
  }

  /// True when [url] is a Discord attachment whose signature has run out, so
  /// Discord will answer "not found" to anybody who asks for it. The `ex` part
  /// of the address says when, in seconds written in hex. An address without
  /// one has not worked since Discord began signing them.
  static bool discordLinkExpired(String url, {DateTime? now}) {
    if (!isDiscordAttachment(url)) return false;
    final ex = Uri.tryParse(url.trim())?.queryParameters['ex'];
    final seconds = ex == null ? null : int.tryParse(ex, radix: 16);
    if (seconds == null) return true;
    final ends = DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    return !ends.isAfter(now ?? DateTime.now().toUtc());
  }
}

class _Entry {
  final int version;
  final PictureCaption? caption;

  /// Why the picture could not be read, when it could not.
  final String? unreadable;
  final String? model;
  final String? endpoint;
  final DateTime at;

  _Entry({
    required this.version,
    this.caption,
    this.unreadable,
    this.model,
    this.endpoint,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'v': version,
        if (caption != null) 'kind': caption!.kind.name,
        if (caption != null) 'caption': caption!.caption,
        if (caption != null) 'fit': caption!.fit.name,
        if (unreadable != null) 'unreadable': unreadable,
        if (model != null) 'model': model,
        if (endpoint != null) 'endpoint': endpoint,
        'at': at.toIso8601String(),
      };

  static _Entry? fromJson(Map<String, dynamic> json) {
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    if (at == null) return null;
    final text = json['caption'] as String?;
    final kind = PictureKind.values
            .where((k) => k.name == json['kind'])
            .firstOrNull ??
        PictureKind.other;
    final fit = CardFit.values.where((f) => f.name == json['fit']).firstOrNull ?? CardFit.okay;
    return _Entry(
      version: json['v'] as int? ?? 0,
      caption: text == null ? null : PictureCaption(kind: kind, caption: text, fit: fit),
      unreadable: json['unreadable'] as String?,
      model: json['model'] as String?,
      endpoint: json['endpoint'] as String?,
      at: at.toUtc(),
    );
  }
}
