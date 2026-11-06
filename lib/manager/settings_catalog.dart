import '../bot/common.dart';

/// The Settings page group for a setting.
enum SettingGroup {
  /// Tokens. Never sent to the browser.
  secret('Secrets'),

  /// Folders, addresses, models and how much history to keep.
  environment('Environment'),

  /// Call caps, delays and timeouts.
  limits('Limits'),

  /// Switches that choose what CLI and cron jobs run.
  /// Browser jobs specify what to run in their requests.
  jobShape('Command-line and cron runs only');

  final String label;

  const SettingGroup(this.label);
}

/// What sort of value a setting holds.
enum SettingKind { bool, int, text, address, choice }

/// One key in `config.properties`, and everything the Settings page needs to
/// know about it apart from its note.
class SettingSpec {
  final String key;
  final SettingGroup group;
  final SettingKind kind;

  /// The built-in default, written the way the file would hold it. Blank means
  /// "not set", which is the default for optional settings.
  final String defaultValue;

  /// The smallest whole number allowed. Only for [SettingKind.int].
  final int? min;

  /// The values allowed. Only for [SettingKind.choice].
  final List<String>? choices;

  /// Alternative spellings accepted by `readConfig` or the value's reader,
  /// mapped to their corresponding choices.
  final Map<String, String> aliases;

  /// True when the setting only takes effect after the server restarts.
  final bool restart;

  /// True when a blank value is allowed. For these, blank means off, no cap, or
  /// not set.
  final bool blankAllowed;

  /// For [SettingKind.address]: also allow an SSH address (`ssh://` or
  /// `git@host:path`).
  final bool sshAllowed;

  /// An extra rule for this key. Returns what is wrong, or null.
  final String? Function(String value)? check;

  const SettingSpec(
    this.key,
    this.group,
    this.kind, {
    this.defaultValue = '',
    this.min,
    this.choices,
    this.aliases = const {},
    this.restart = false,
    this.blankAllowed = false,
    this.sshAllowed = false,
    this.check,
  });

  bool get isSecret => group == SettingGroup.secret;
}

/// Every setting the server knows, in the order `config.example.properties`
/// lists them.
///
/// Each default must be what `Common.configFromProperties` does when the key is
/// missing. A test writes each one into an otherwise empty file and checks the
/// settings come out the same as for an empty file.
class SettingsCatalog {
  /// The mark put in place of a hidden part of an address.
  static const String hidden = '•••';

  static const List<SettingSpec> settings = [
    SettingSpec('log_level', SettingGroup.environment, SettingKind.choice,
        defaultValue: 'INFO',
        choices: ['VERBOSE', 'DEBUG', 'INFO', 'WARN', 'ERROR'],
        restart: true),
    // ModRepo pipeline.
    SettingSpec('modrepo_enabled', SettingGroup.jobShape, SettingKind.bool,
        defaultValue: 'true'),
    SettingSpec(
        'modrepo_forums_enabled', SettingGroup.jobShape, SettingKind.bool,
        defaultValue: 'false'),
    SettingSpec(
        'modrepo_discord_enabled', SettingGroup.jobShape, SettingKind.bool,
        defaultValue: 'false'),
    SettingSpec('modrepo_nexus_enabled', SettingGroup.jobShape, SettingKind.bool,
        defaultValue: 'false'),
    SettingSpec(
        'modrepo_discord_auth_token', SettingGroup.secret, SettingKind.text,
        blankAllowed: true),
    SettingSpec(
        'modrepo_discord_server_id', SettingGroup.environment, SettingKind.text,
        blankAllowed: true, check: _digitsOnly),
    SettingSpec('modrepo_discord_forum_channels', SettingGroup.environment,
        SettingKind.text,
        blankAllowed: true, check: _forumChannels),
    SettingSpec(
        'modrepo_nexus_api_token', SettingGroup.secret, SettingKind.text,
        blankAllowed: true),
    SettingSpec('modrepo_use_cached', SettingGroup.jobShape, SettingKind.bool,
        defaultValue: 'false'),
    SettingSpec('modrepo_less_scraping', SettingGroup.jobShape, SettingKind.bool,
        defaultValue: 'false'),
    SettingSpec(
        'modrepo_keep_all_game_versions', SettingGroup.jobShape, SettingKind.bool,
        defaultValue: 'false'),
    SettingSpec('modrepo_merge_debug', SettingGroup.jobShape, SettingKind.bool,
        defaultValue: 'false'),
    SettingSpec(
        'modrepo_merges_to_keep', SettingGroup.environment, SettingKind.int,
        defaultValue: '20', min: 0),
    // QB pipeline.
    SettingSpec('qb_enabled', SettingGroup.jobShape, SettingKind.bool,
        defaultValue: 'false'),
    SettingSpec('qb_data_path', SettingGroup.environment, SettingKind.text,
        defaultValue: 'qb_data', restart: true),
    SettingSpec('qb_scope', SettingGroup.jobShape, SettingKind.choice,
        defaultValue: 'newData',
        choices: ['newData', 'all', 'pages', 'topics', 'librariesOnly'],
        aliases: {'new_data': 'newData', 'libraries_only': 'librariesOnly'}),
    SettingSpec('qb_boards', SettingGroup.jobShape, SettingKind.text,
        defaultValue: 'main,libraries,lesser', check: _boards),
    SettingSpec('qb_delay_ms', SettingGroup.limits, SettingKind.int,
        defaultValue: '1500', min: 0),
    SettingSpec('qb_max_pages_main', SettingGroup.jobShape, SettingKind.int,
        min: 1, blankAllowed: true),
    SettingSpec('qb_max_pages_lesser', SettingGroup.jobShape, SettingKind.int,
        defaultValue: '20', min: 1),
    SettingSpec('qb_max_pages_libraries', SettingGroup.jobShape, SettingKind.int,
        min: 1, blankAllowed: true),
    SettingSpec('qb_use_cached', SettingGroup.jobShape, SettingKind.bool,
        defaultValue: 'false'),
    SettingSpec('qb_runs_to_keep', SettingGroup.environment, SettingKind.int,
        defaultValue: '100', min: 0),
    SettingSpec('qb_bundles_to_keep', SettingGroup.environment, SettingKind.int,
        defaultValue: '500', min: 0),
    SettingSpec('qb_manager_url', SettingGroup.environment, SettingKind.address,
        blankAllowed: true),
    // Asking an LLM about each post.
    SettingSpec('llm_enabled', SettingGroup.environment, SettingKind.bool,
        defaultValue: 'false'),
    SettingSpec('llm_base_url', SettingGroup.environment, SettingKind.address,
        defaultValue: 'https://openrouter.ai/api/v1/chat/completions'),
    SettingSpec('llm_model', SettingGroup.environment, SettingKind.text,
        defaultValue: 'deepseek/deepseek-chat'),
    SettingSpec('llm_api_token', SettingGroup.secret, SettingKind.text,
        blankAllowed: true),
    SettingSpec('llm_max_topics', SettingGroup.limits, SettingKind.int,
        min: 0, blankAllowed: true),
    SettingSpec('llm_max_concurrent_calls', SettingGroup.limits, SettingKind.int,
        defaultValue: '3', min: 1),
    SettingSpec('llm_idle_timeout_seconds', SettingGroup.limits, SettingKind.int,
        defaultValue: '180', min: 1),
    SettingSpec('llm_timeout_seconds', SettingGroup.limits, SettingKind.int,
        defaultValue: '900', min: 1),
    SettingSpec(
        'llm_max_consecutive_failures', SettingGroup.limits, SettingKind.int,
        defaultValue: '10', min: 1),
    SettingSpec('llm_max_tokens', SettingGroup.limits, SettingKind.int,
        min: 1, blankAllowed: true),
    SettingSpec('llm_max_input_chars', SettingGroup.limits, SettingKind.int,
        min: 1, blankAllowed: true),
    SettingSpec('llm_disable_thinking', SettingGroup.environment, SettingKind.bool,
        defaultValue: 'false'),
    SettingSpec(
        'llm_structured_output', SettingGroup.environment, SettingKind.bool,
        defaultValue: 'false'),
    SettingSpec('llm_summaries', SettingGroup.environment, SettingKind.bool,
        defaultValue: 'false'),
    SettingSpec('llm_caption_pictures', SettingGroup.environment, SettingKind.bool,
        defaultValue: 'false'),
    SettingSpec(
        'llm_fallback_base_url', SettingGroup.environment, SettingKind.address,
        blankAllowed: true),
    SettingSpec('llm_fallback_model', SettingGroup.environment, SettingKind.text,
        blankAllowed: true),
    SettingSpec('llm_fallback_api_token', SettingGroup.secret, SettingKind.text,
        blankAllowed: true),
    SettingSpec('llm_fallback_disable_thinking', SettingGroup.environment,
        SettingKind.bool,
        defaultValue: 'false'),
    SettingSpec('llm_fallback_structured_output', SettingGroup.environment,
        SettingKind.bool,
        defaultValue: 'false'),
    SettingSpec(
        'llm_fallback_free_to_paid', SettingGroup.environment, SettingKind.bool,
        defaultValue: 'false'),
    SettingSpec('llm_reprocess_only', SettingGroup.jobShape, SettingKind.bool,
        defaultValue: 'false'),
    SettingSpec('llm_test_mode', SettingGroup.jobShape, SettingKind.bool,
        defaultValue: 'false'),
    SettingSpec('llm_test_limit', SettingGroup.jobShape, SettingKind.int,
        defaultValue: '5', min: 1),
    SettingSpec('llm_test_topic_ids', SettingGroup.jobShape, SettingKind.text,
        blankAllowed: true, check: _topicIds),
    // Publishing.
    SettingSpec('publish_repo_url', SettingGroup.environment, SettingKind.address,
        defaultValue: 'git@github.com:wispborne/StarsectorModRepo.git',
        sshAllowed: true),
    SettingSpec('publish_clone_dir', SettingGroup.environment, SettingKind.text,
        blankAllowed: true),
    SettingSpec('publish_site_path', SettingGroup.environment, SettingKind.text,
        defaultValue: 'site'),
    // The results viewer.
    SettingSpec(
        'viewer_allowed_hosts', SettingGroup.environment, SettingKind.text,
        blankAllowed: true, restart: true, check: _hostNames),
  ];

  static final Map<String, SettingSpec> _byKey = {
    for (final spec in settings) spec.key: spec,
  };

  /// The setting called [key], or null when there is none.
  static SettingSpec? byKey(String key) => _byKey[key];

  /// The settings an empty file gives. Used to tell whether a value differs
  /// from the default.
  static final BotConfig _defaults = Common.configFromProperties(const {});

  // --- Notes ---

  /// Reads the note for every key out of `config.example.properties`: the
  /// comment lines straight above the key, with the `#` marks taken off. Keys
  /// on lines next to each other share the comment above the first of them.
  ///
  /// Lines that run on are joined into one paragraph. Paragraphs are separated
  /// by a blank line, and an indented line (an item in a list) keeps a line of
  /// its own.
  static Map<String, String> readNotes(String exampleText) {
    final lines = exampleText.replaceAll('\r\n', '\n').split('\n');
    final notes = <String, String>{};
    for (var i = 0; i < lines.length; i++) {
      final key = _keyOn(lines[i]);
      if (key == null) continue;

      // Step back over the keys straight above this one.
      var j = i - 1;
      while (j >= 0 && _keyOn(lines[j]) != null) {
        j--;
      }
      // Then gather the comment lines above them.
      final comment = <String>[];
      while (j >= 0 && lines[j].trim().startsWith('#')) {
        comment.insert(0, lines[j].trim());
        j--;
      }
      notes[key] = _noteFrom(comment);
    }
    return notes;
  }

  /// The key a `key = value` line sets, read the way `readConfig` reads it, or
  /// null for a blank line or a comment.
  static String? _keyOn(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) return null;
    final parts = line.split('=');
    if (parts.length < 2) return null;
    return parts.first.trim();
  }

  static String _noteFrom(List<String> commentLines) {
    final out = <String>[];
    var paragraph = <String>[];
    void endParagraph() {
      if (paragraph.isNotEmpty) out.add(paragraph.join(' '));
      paragraph = [];
    }

    for (final raw in commentLines) {
      var text = raw.substring(1);
      // A heading such as "--- A second endpoint ---" or a row of "=" says
      // nothing about one key.
      final bare = text.trim();
      if (RegExp(r'^=+$').hasMatch(bare) ||
          RegExp(r'^-{3}.*-{3}$').hasMatch(bare)) {
        continue;
      }
      if (bare.isEmpty) {
        endParagraph();
        if (out.isNotEmpty && out.last.isNotEmpty) out.add('');
        continue;
      }
      if (text.startsWith(' ')) text = text.substring(1);
      if (text.startsWith(' ')) {
        // An indented line is an item in a list.
        endParagraph();
        out.add(text.trim());
      } else {
        paragraph.add(text.trim());
      }
    }
    endParagraph();
    while (out.isNotEmpty && out.last.isEmpty) {
      out.removeLast();
    }
    return out.join('\n');
  }

  // --- Values ---

  /// The value as the page shows it: a choice in the spelling of its list, and
  /// anything else as written.
  static String canonical(SettingSpec spec, String value) {
    final trimmed = value.trim();
    if (spec.kind != SettingKind.choice) return trimmed;
    for (final choice in spec.choices!) {
      if (choice.toLowerCase() == trimmed.toLowerCase()) return choice;
    }
    for (final alias in spec.aliases.entries) {
      if (alias.key.toLowerCase() == trimmed.toLowerCase()) return alias.value;
    }
    return trimmed;
  }

  /// True when [value] gives different settings from the built-in default.
  static bool differsFromDefault(SettingSpec spec, String value) =>
      Common.configFromProperties({spec.key: canonical(spec, value)}) !=
      _defaults;

  /// Hides the user name, password and query of an address: the parts that
  /// can hold a secret. `git@host:path` addresses hold no password and are
  /// left as they are.
  static ({String value, bool masked}) maskAddress(String address) {
    final schemeEnd = address.indexOf('://');
    if (schemeEnd < 0) return (value: address, masked: false);
    final start = schemeEnd + 3;
    var authorityEnd = address.length;
    for (final mark in ['/', '?', '#']) {
      final at = address.indexOf(mark, start);
      if (at >= 0 && at < authorityEnd) authorityEnd = at;
    }
    var authority = address.substring(start, authorityEnd);
    var rest = address.substring(authorityEnd);
    var masked = false;

    final at = authority.lastIndexOf('@');
    if (at >= 0) {
      authority = '$hidden${authority.substring(at)}';
      masked = true;
    }
    final query = rest.indexOf('?');
    if (query >= 0) {
      final fragment = rest.indexOf('#', query);
      final end = fragment >= 0 ? fragment : rest.length;
      if (end > query + 1) {
        rest = '${rest.substring(0, query + 1)}$hidden${rest.substring(end)}';
        masked = true;
      }
    }
    return (
      value: '${address.substring(0, start)}$authority$rest',
      masked: masked,
    );
  }

  // --- Checking values ---

  /// What is wrong with [value] for [spec], in words that follow the key's
  /// name, or null when it is fine.
  static String? problemWith(SettingSpec spec, String value) {
    if (value.contains('\n') || value.contains('\r')) {
      return 'must be on one line';
    }
    final trimmed = value.trim();
    if (trimmed.contains(hidden)) {
      return spec.kind == SettingKind.address
          ? 'still holds the hidden part ($hidden). Type the whole address '
              'again, with its user name or password'
          : 'still holds the hidden mark ($hidden)';
    }
    if (trimmed.isEmpty) {
      if (spec.isSecret) {
        return 'is blank. To remove a token, clear it instead';
      }
      if (spec.blankAllowed) return null;
      return 'cannot be blank. Reset it to go back to the default';
    }

    switch (spec.kind) {
      case SettingKind.bool:
        final lower = trimmed.toLowerCase();
        if (lower != 'true' && lower != 'false') {
          return 'must be true or false';
        }
      case SettingKind.int:
        final number = int.tryParse(trimmed);
        if (number == null) return 'must be a whole number';
        final min = spec.min;
        if (min != null && number < min) return 'must be $min or more';
      case SettingKind.choice:
        final choice = canonical(spec, trimmed);
        if (!spec.choices!.contains(choice)) {
          return 'must be one of: ${spec.choices!.join(', ')}';
        }
      case SettingKind.address:
        if (!_isAddress(trimmed, sshAllowed: spec.sshAllowed)) {
          return spec.sshAllowed
              ? 'must be an address starting with http://, https:// or '
                  'ssh://, or an SSH address such as git@github.com:owner/repo.git'
              : 'must be an address starting with http:// or https://';
        }
      case SettingKind.text:
        break;
    }
    return spec.check?.call(trimmed);
  }

  static bool _isAddress(String value, {required bool sshAllowed}) {
    if (value.contains(' ')) return false;
    if (sshAllowed && RegExp(r'^[\w.-]+@[\w.-]+:\S+$').hasMatch(value)) {
      return true;
    }
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return false;
    final schemes = sshAllowed ? {'http', 'https', 'ssh'} : {'http', 'https'};
    return schemes.contains(uri.scheme);
  }

  static String? _digitsOnly(String value) =>
      RegExp(r'^\d+$').hasMatch(value) ? null : 'must be a number id';

  static String? _boards(String value) {
    const boards = {'main', 'lesser', 'libraries'};
    final names = value
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty);
    return names.isNotEmpty && names.every(boards.contains)
        ? null
        : 'must be one or more of main, lesser and libraries, separated by '
            'commas';
  }

  static String? _topicIds(String value) =>
      value.split(',').every((s) => int.tryParse(s.trim()) != null)
          ? null
          : 'must be topic ids separated by commas, such as 1234,5678';

  static String? _hostNames(String value) => value.split(',').every(
          (name) => RegExp(r'^\s*[a-z0-9]([a-z0-9.-]*[a-z0-9])?\s*$',
                  caseSensitive: false)
              .hasMatch(name))
      ? null
      : 'must be host names only, separated by commas, such as '
          'starsector-scraper.example.com (no http:// and no port)';

  static String? _forumChannels(String value) =>
      value.split(',').every(
              (entry) => RegExp(r'^\s*\d+\s*:\s*\S+\s*$').hasMatch(entry))
          ? null
          : 'must be channel ids, each with its game version, separated by '
              'commas, such as 1203051351307985046:0.97a';
}
