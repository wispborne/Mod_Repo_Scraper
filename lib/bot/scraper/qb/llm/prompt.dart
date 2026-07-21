/// The prompt text and what we ask the model to return, kept in one place.
/// [promptVersion] is part of the cache key (see [LlmExtractionStore]);
/// bumping it re-runs every affected post.
///
/// Bump [promptVersion] whenever the system prompt, the requested field set, or
/// the user-message shape changes.
class ExtractionPrompt {
  ExtractionPrompt._();

  static const int promptVersion = 9;

  /// Fixed request settings live here too so a change to them also
  /// forces a re-run via [promptVersion].
  static const double temperature = 0;
  static const int maxTokens = 4000;

  /// The system message. When [includeSummary] is false this is byte-identical
  /// to the long-standing prompt, so posts already saved without summaries keep
  /// their cache. When true, it adds a `summary` field and the rules for it —
  /// the one place the model is asked to write in its own words.
  static String buildSystemPrompt({bool includeSummary = false}) {
    final summaryRule = includeSummary
        ? '\n- The "summary" field is the ONE exception to the copy-exactly '
            'rule: write it in your own plain English. Base it only on this '
            'post, keep it factual, and do not invent features the post does '
            'not mention.'
        : '';
    final summaryField = includeSummary
        ? ',\n'
            '  "summary": {\n'
            '    "sentence": "<one plain-English sentence describing what it adds or changes, starting with a verb, without naming the mod, or null>",\n'
            '    "paragraph": "<two to four plain-English sentences describing what it adds or changes, without naming the mod, or null>"\n'
            '  }'
        : '';
    final summaryGuidance = includeSummary
        ? '\n- The "summary" is shown directly under the mod name, so write it as '
            'a description of what the mod does, not as a headline about the mod:\n'
            '  - Do NOT mention the mod name, and do NOT start the summary with it.\n'
            '  - Do NOT say "this mod", "the mod", "is a mod", or "a mod that" — '
            'the reader already knows it is a mod.\n'
            '  - Do NOT name the game or tack on "in Starsector", "to Starsector", '
            'or "for Starsector". It is shown inside the game, so the reader knows '
            'that too.\n'
            '  - Start with a verb where you can: "Adds...", "Overhauls...", '
            '"Replaces...", "Lets you...".\n'
            '  - "summary.sentence" is one sentence; "summary.paragraph" is two to '
            'four sentences. Use plain, everyday words.\n'
            '  - Good sentence: "Adds dynamic lighting, HDR bloom, and distortion '
            'effects in battle."\n'
            '  - Good paragraph: "Adds numerous graphical improvements: a variety '
            'of effects plugins, a dynamic lighting engine, and a screen-space '
            'distortion shader. Other mods can build on it through its lighting, '
            'distortion, and post-processing APIs."\n'
            '  - Bad, do NOT write like this: "ShaderLib is a mod that adds '
            'shaders to Starsector." It names the mod and says "is a mod".\n'
            '  - Also bad: "Adds a suite of shader effects for enhanced graphics '
            'in Starsector." Drop "in Starsector" and end at "graphics".\n'
            '  Leave a summary field null only when the post says too little to '
            'write it.'
        : '';

    return '''
You read a single forum post about a Starsector mod and pull out facts that are
actually present in the post. You return ONLY a JSON object in the exact shape
below. No prose, no markdown, no comments.

Hard rules:
- Copy text exactly as it appears. NEVER summarize, paraphrase, translate, or
  invent. If a fact is not stated in the post, leave that field null.
- Only use links that literally appear in the post. Never construct or guess a
  URL. Never "fix up" a URL.
- The mod's own version is NOT the game version it targets. If the post says it
  targets a game version, do not report that as the mod's version.
- List ONLY mods that can actually be downloaded from THIS post. Do NOT add a
  mod that is merely mentioned, recommended, linked as a successor, or that has
  to be downloaded somewhere else. Example: a post for one mod that also links a
  successor mod and recommends a separate tool still has EXACTLY ONE mod — the
  one this thread is about.$summaryRule

Return this JSON object:
{
  "isMod": <true or false: is this thread a downloadable Starsector mod release?>,
  "mods": [
    {
      "name": "<the mod's name as written in the post>",
      "role": "<main | addon | separate | variant>",
      "requires": "<for an addon, the exact name of the mod it needs; else null>",
      "downloads": [
        {
          "url": "<a download link exactly as it appears in the post>",
          "label": "<the link's text, copied word-for-word; or \\"\\" if it had none>",
          "kind": "<direct | mirror | trios>"
        }
      ],
      "image": "<the URL of an image from the post that clearly belongs to THIS mod, copied exactly from the images list; else null>",
      "changelog": {
        "link": "<a changelog URL from the post, or null>",
        "entries": {
          "<version string, e.g. 1.2.3>": "<that version's notes, copied word-for-word from the post>",
          "<next version>": "<its notes>"
        }
      },
      "version": "<the mod's own current version string, or null>",
      "supportLinks": ["<Patreon/Ko-fi/donate URL from the post>", "..."],
      "license": "<the license exactly as stated in the post, or null>",
      "saveCompatibility": "<the post's own words on whether it can be added to an existing save or needs a new game, copied exactly, or null>"$summaryField
    }
  ]
}

Guidance:
- "isMod" says whether this thread is itself a downloadable Starsector mod
  release:
  - true: the post offers a mod you can download and load into the game — this
    is the normal case. If you listed any real download in "mods", "isMod" is
    true.
  - false: the thread is NOT a mod release. Examples: a discussion or question,
    a guide or tutorial, a modding-help request, a list or index that only
    points to other threads, artwork, or a tool that is not itself a mod you
    load into the game.
  When unsure, say true. It is safer to keep a borderline thread than to drop a
  real mod.
- Most posts describe exactly one mod, so "mods" is usually a one-item list with
  role "main". Use more than one entry only when the post really offers more than
  one downloadable mod.
- "role" tells how each mod relates to the others:
  - "main": the mod this thread is about.
  - "addon": an optional extra that needs another mod to work. Set "requires" to
    that mod's exact name.
  - "separate": a second, unrelated mod that also has its own download here.
  - "variant": an alternative build of the main mod (e.g. a lite version).
- Add-on vs mirror — do not confuse these:
  - A DIFFERENT file that adds to or extends the mod is its OWN mod entry, with
    role "addon".
  - The SAME file offered on another host is NOT a new mod. It is another
    download under the same mod, with kind "mirror".
- "downloads" is that mod's real download links. You are given the links the
  scraper already auto-detected: confirm the real ones, add any it missed
  (including links inside spoiler boxes or on hosts it does not know), and leave
  out anything that is not a download of the mod. A mod may offer more than one
  link — list each. Use "kind":
  - "direct": a normal download of the mod's file.
  - "mirror": the same file offered on another host.
  - "trios": an "Install with TriOS" link.
- The changelog has two parts, and a post can have BOTH — return each part that
  the post actually has. Summarizing the changelog or fixing up a url will result in them being treated as invalid!
  - "link": a changelog URL copied from the post (e.g. a GitHub releases page or a
    changelog file). Leave null when the post links none.
  - "entries": changelog text copied from the post, as a map keyed by the
    version string, valued by that version's notes copied word-for-word
    including typos and whitespace. Include only the highest three versions, in
    descending order. Leave "entries" out (or null) when the post shows no
    changelog text.
  Return a link when the post links one, entries when the post shows changelog
  text, and both when the post has both.
- "image" is a picture for the mod, taken from the images list below:
  - Set it only when the post clearly shows a picture that belongs to THAT
    specific mod — a banner, logo, or screenshot next to the mod's name or its
    download. This matters most when a post offers several mods or a main mod
    plus add-ons, so each one can show its own picture.
  - Copy the image URL exactly from the images list. Never guess or build a URL,
    and never use one that is not in that list.
  - Do NOT use badges or icons (license shields, version badges, forum smileys).
  - Leave it null when the post ties no clear picture to this mod. A single-mod
    thread usually needs no image here — the thread already has one.
- "saveCompatibility" is the post's own words on adding the mod to a game in
  progress:
  - Copy the exact phrase or sentence that says whether you can add the mod to an
    existing/ongoing save, or whether it needs a new game — for example "Save
    compatible", "Can be added to an existing save", "Safe to add mid-game",
    "Requires a new game", or "Not save-game compatible".
  - Copy it word-for-word. Do not summarize, judge, or decide it yourself. Leave
    it null when the post does not say either way.
- Leave any field null/empty when the post does not state it. Do not guess.$summaryGuidance
''';
  }

  /// The JSON Schema for the answer, matching the shape in [buildSystemPrompt].
  /// Sent as `response_format: json_schema` when structured output is on, so a
  /// compliant endpoint can only return valid JSON in this shape. Nullable
  /// fields use a `["<type>", "null"]` union, matching the "or null" wording in
  /// the prompt. Kept in step with the prompt: change one, change the other, and
  /// bump [promptVersion] if the shape changes.
  static Map<String, dynamic> buildResponseSchema({bool includeSummary = false}) {
    Map<String, dynamic> nullableString() => {
          'type': ['string', 'null']
        };

    final modProps = <String, dynamic>{
      'name': {'type': 'string'},
      'role': {
        'type': 'string',
        'enum': ['main', 'addon', 'separate', 'variant'],
      },
      'requires': nullableString(),
      'downloads': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'url': {'type': 'string'},
            'label': {'type': 'string'},
            'kind': {
              'type': 'string',
              'enum': ['direct', 'mirror', 'trios'],
            },
          },
          'required': ['url', 'label', 'kind'],
          'additionalProperties': false,
        },
      },
      'image': nullableString(),
      'changelog': {
        'type': ['object', 'null'],
        'properties': {
          'link': nullableString(),
          'entries': {
            'type': ['object', 'null'],
            // Keyed by an arbitrary version string, valued by that version's
            // notes.
            'additionalProperties': {'type': 'string'},
          },
        },
        'required': ['link', 'entries'],
        'additionalProperties': false,
      },
      'version': nullableString(),
      'supportLinks': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'license': nullableString(),
      'saveCompatibility': nullableString(),
    };

    final modRequired = <String>[
      'name',
      'role',
      'requires',
      'downloads',
      'image',
      'changelog',
      'version',
      'supportLinks',
      'license',
      'saveCompatibility',
    ];

    if (includeSummary) {
      modProps['summary'] = {
        'type': ['object', 'null'],
        'properties': {
          'sentence': nullableString(),
          'paragraph': nullableString(),
        },
        'required': ['sentence', 'paragraph'],
        'additionalProperties': false,
      };
      modRequired.add('summary');
    }

    return {
      'type': 'object',
      'properties': {
        'isMod': {'type': 'boolean'},
        'mods': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': modProps,
            'required': modRequired,
            'additionalProperties': false,
          },
        },
      },
      'required': ['isMod', 'mods'],
      'additionalProperties': false,
    };
  }

  /// Builds the user message: the reduced post plus the hints the scraper
  /// already knows. Always builds the same string for the same post (the
  /// content hash depends on it).
  static String buildUserPrompt({
    required String reducedText,
    required List<({String url, String text, bool isDownloadable})> links,
    required List<String> ruleLinks,
    List<({String url, String? alt})> images = const [],
    String? gameVersion,
    String? modTitle,
  }) {
    final buffer = StringBuffer();

    // Only sent when summaries are on, so posts saved without summaries keep
    // the same prompt (and the same cache key).
    if (modTitle != null && modTitle.trim().isNotEmpty) {
      buffer.writeln('=== MOD TITLE ===');
      buffer.writeln(modTitle.trim());
      buffer.writeln();
    }

    buffer.writeln('=== POST TEXT (spoiler boxes included) ===');
    buffer.writeln(reducedText.trim());
    buffer.writeln();

    buffer.writeln('=== LINKS IN THE POST ===');
    if (links.isEmpty) {
      buffer.writeln('(none)');
    } else {
      for (final l in links) {
        final flag = l.isDownloadable ? ' [flagged downloadable]' : '';
        final text = l.text.trim().isEmpty ? '' : '  "${l.text.trim()}"';
        buffer.writeln('- ${l.url}$text$flag');
      }
    }
    buffer.writeln();

    buffer.writeln('=== LINKS THE SCRAPER AUTO-DETECTED AS DOWNLOADS ===');
    if (ruleLinks.isEmpty) {
      buffer.writeln('(none)');
    } else {
      for (final u in ruleLinks) {
        buffer.writeln('- $u');
      }
    }
    buffer.writeln();

    buffer.writeln('=== IMAGES IN THE POST (use only these URLs for "image") ===');
    if (images.isEmpty) {
      buffer.writeln('(none)');
    } else {
      for (final img in images) {
        final alt = img.alt != null && img.alt!.trim().isNotEmpty
            ? '  "${img.alt!.trim()}"'
            : '';
        buffer.writeln('- ${img.url}$alt');
      }
    }
    buffer.writeln();

    if (gameVersion != null && gameVersion.trim().isNotEmpty) {
      buffer.writeln('=== GAME VERSION (do NOT report as the mod version) ===');
      buffer.writeln(gameVersion.trim());
    }

    return buffer.toString();
  }
}
