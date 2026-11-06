import 'dart:io';

/// Updates keys in `config.properties` without changing other content.
///
/// The file is edited line by line. Comments, blank lines, the order of lines
/// and the file's own line endings stay as they were. Only the lines of the
/// keys being changed are touched.
class ConfigFileEditor {
  /// The comment written once above keys the file did not have before.
  static const String marker = '# Set from the viewer';

  /// Returns [text] with every key in [set] given its new value and every key
  /// in [remove] taken out, so its built-in default applies.
  ///
  /// A key already in the file keeps its `key = ` part as written. A key
  /// written more than once has every copy changed, because the last value
  /// is used when reading the file. A missing key is added at the end,
  /// under [marker].
  static String edit(
    String text, {
    Map<String, String> set = const {},
    Set<String> remove = const {},
  }) {
    final eol = text.contains('\r\n') ? '\r\n' : '\n';
    final lines = text.isEmpty ? <String>[] : text.split(eol);
    final endedWithNewline = lines.isNotEmpty && lines.last.isEmpty;
    if (endedWithNewline) lines.removeLast();

    final out = <String>[];
    final written = <String>{};
    for (final line in lines) {
      final key = keyOn(line);
      if (key != null && remove.contains(key)) continue;
      if (key != null && set.containsKey(key)) {
        out.add(_withValue(line, set[key]!));
        written.add(key);
        continue;
      }
      out.add(line);
    }

    final added = [
      for (final entry in set.entries)
        if (!written.contains(entry.key))
          entry.value.isEmpty
              ? '${entry.key} ='
              : '${entry.key} = ${entry.value}',
    ];
    if (added.isNotEmpty) {
      if (!out.any((line) => line.trim() == marker)) {
        if (out.isNotEmpty && out.last.trim().isNotEmpty) out.add('');
        out.add(marker);
      }
      out.addAll(added);
    }

    if (out.isEmpty) return '';
    return out.join(eol) + (endedWithNewline || added.isNotEmpty ? eol : '');
  }

  /// The key a line sets, read the way `Common.readConfig` reads it, or null
  /// for a blank line, a comment, or a line with no `=`.
  static String? keyOn(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) return null;
    final equals = line.indexOf('=');
    if (equals < 0) return null;
    return line.substring(0, equals).trim();
  }

  /// [line] with its value replaced, keeping the `key = ` part as written.
  static String _withValue(String line, String value) {
    final equals = line.indexOf('=');
    var end = equals + 1;
    while (end < line.length && (line[end] == ' ' || line[end] == '\t')) {
      end++;
    }
    var prefix = line.substring(0, end);
    // "key =" with nothing after it: put a space in, so it reads "key = 300".
    if (end == equals + 1 && equals > 0 && line[equals - 1] == ' ') {
      prefix = '$prefix ';
    }
    return value.isEmpty ? prefix.trimRight() : '$prefix$value';
  }

  /// Applies [set] and [remove] to the file at [path] and saves it.
  ///
  /// The new text is written to `<path>.tmp`, which then replaces the file, so
  /// a crash part-way never leaves half a file. On Linux and macOS the new file
  /// gets the old one's permissions, because the file holds tokens and is
  /// usually readable by its owner only. A missing file is treated as empty.
  static Future<void> save(
    String path, {
    Map<String, String> set = const {},
    Set<String> remove = const {},
  }) async {
    final file = File(path);
    final exists = file.existsSync();
    final text = exists ? await file.readAsString() : '';
    final updated = edit(text, set: set, remove: remove);

    final temp = File('$path.tmp');
    if (exists) {
      // A copy starts with the old file's permissions.
      await file.copy(temp.path);
      if (!Platform.isWindows) {
        final mode = (await file.stat()).mode & 0x1ff;
        await Process.run('chmod', [mode.toRadixString(8), temp.path]);
      }
    }
    await temp.writeAsString(updated, flush: true);
    await temp.rename(path);
  }
}
