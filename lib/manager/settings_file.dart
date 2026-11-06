import 'dart:io';

import 'package:path/path.dart' as p;

import '../bot/common.dart';
import 'config_file_editor.dart';
import 'settings_catalog.dart';

/// A rejected settings change. [message] lists each invalid key and the
/// reason it was rejected. Nothing was written.
class SettingsRefused implements Exception {
  final String message;

  SettingsRefused(this.message);

  @override
  String toString() => message;
}

/// The config file the server was started with, as the Settings page sees it.
///
/// Responses show only whether a token is set. Address user names,
/// passwords and query strings are hidden.
class SettingsFile {
  /// The config file, usually `config.properties`.
  final String configPath;

  /// Where the notes for each setting are read from. A missing file leaves the
  /// notes empty and everything else works.
  final String examplePath;

  /// Saves run one at a time to prevent one from overwriting another.
  Future<void> _saving = Future.value();

  SettingsFile({required this.configPath, String? examplePath})
      : examplePath = examplePath ??
            p.join(p.dirname(configPath), 'config.example.properties');

  /// The values the file holds now, read the way the server reads them.
  Map<String, String> _values() {
    final file = File(configPath);
    if (!file.existsSync()) return const {};
    return Common.parseProperties(file.readAsLinesSync());
  }

  Map<String, String> _notes() {
    final file = File(examplePath);
    if (!file.existsSync()) return const {};
    try {
      return SettingsCatalog.readNotes(file.readAsStringSync());
    } catch (_) {
      return const {};
    }
  }

  /// Every setting with its group, kind, note, default and value, for
  /// `GET /settings`. Secret values are excluded.
  Map<String, Object?> describe() {
    final values = _values();
    final notes = _notes();
    return {
      'file': p.basename(configPath),
      'groups': [
        for (final group in SettingGroup.values)
          {'id': group.name, 'label': group.label},
      ],
      'settings': [
        for (final spec in SettingsCatalog.settings)
          _describeOne(spec, values[spec.key], notes[spec.key] ?? ''),
      ],
    };
  }

  static Map<String, Object?> _describeOne(
      SettingSpec spec, String? written, String note) {
    final value = written ?? spec.defaultValue;
    final entry = <String, Object?>{
      'key': spec.key,
      'group': spec.group.name,
      'kind': spec.kind.name,
      if (spec.choices != null) 'choices': spec.choices,
      if (spec.min != null) 'min': spec.min,
      'note': note,
      'default': spec.defaultValue,
    };
    if (spec.isSecret) {
      entry['isSet'] = value.trim().isNotEmpty;
    } else if (spec.kind == SettingKind.address) {
      final shown = SettingsCatalog.maskAddress(value.trim());
      entry['value'] = shown.value;
      if (shown.masked) entry['masked'] = true;
    } else {
      entry['value'] = SettingsCatalog.canonical(spec, value);
    }
    entry['differs'] = SettingsCatalog.differsFromDefault(spec, value);
    entry['restart'] = spec.restart;
    return entry;
  }

  /// Checks every change, then writes them all, or nothing.
  ///
  /// [set] gives keys new values, [reset] takes keys out of the file so their
  /// default applies, and [clearSecrets] empties tokens. Throws
  /// [SettingsRefused] naming every bad key when anything is wrong. Returns the
  /// keys saved.
  Future<List<String>> save({
    Map<String, String> set = const {},
    List<String> reset = const [],
    List<String> clearSecrets = const [],
  }) {
    final result = _saving.then((_) => _save(set, reset, clearSecrets));
    _saving = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<List<String>> _save(Map<String, String> set, List<String> reset,
      List<String> clearSecrets) async {
    final problems = <String>[];
    final seen = <String>{};
    void twice(String key) {
      if (!seen.add(key)) {
        problems.add('$key is asked for more than once (set, reset or '
            'cleared). Pick one');
      }
    }

    final toSet = <String, String>{};
    for (final entry in set.entries) {
      twice(entry.key);
      final spec = SettingsCatalog.byKey(entry.key);
      if (spec == null) {
        problems.add('${entry.key} is not a setting');
        continue;
      }
      final problem = SettingsCatalog.problemWith(spec, entry.value);
      if (problem != null) {
        problems.add('${entry.key} $problem');
        continue;
      }
      toSet[entry.key] = SettingsCatalog.canonical(spec, entry.value);
    }

    final toRemove = <String>{};
    for (final key in reset) {
      twice(key);
      if (SettingsCatalog.byKey(key) == null) {
        problems.add('$key is not a setting');
        continue;
      }
      toRemove.add(key);
    }

    final values = _values();
    for (final key in clearSecrets) {
      twice(key);
      final spec = SettingsCatalog.byKey(key);
      if (spec == null) {
        problems.add('$key is not a setting');
        continue;
      }
      if (!spec.isSecret) {
        problems.add('$key is not a token, so it cannot be cleared. Reset it '
            'instead');
        continue;
      }
      // A token that is not in the file is already clear.
      if (values.containsKey(key)) toSet[key] = '';
    }

    if (problems.isNotEmpty) {
      throw SettingsRefused('Nothing was saved. ${problems.join('. ')}.');
    }
    if (seen.isEmpty) {
      throw SettingsRefused('Nothing was saved: the request named no '
          'settings to change.');
    }

    await ConfigFileEditor.save(configPath, set: toSet, remove: toRemove);
    return [
      for (final spec in SettingsCatalog.settings)
        if (seen.contains(spec.key)) spec.key,
    ];
  }
}
