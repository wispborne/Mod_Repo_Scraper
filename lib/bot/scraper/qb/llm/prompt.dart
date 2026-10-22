import '../../../../catalog/source_post.dart';
import '../models/post_extraction.dart';

/// Prompts and response schema for extracting mod facts.
///
/// [promptVersion] controls forum cache invalidation; [discordPromptVersion]
/// controls Discord. Bump both when the system prompt, response fields or
/// shared user-message format changes. Bump only [discordPromptVersion] for
/// Discord-only user-message changes.
class ExtractionPrompt {
  ExtractionPrompt._();

  static const int promptVersion = 25;
  static const int discordPromptVersion = 3;

  /// Cache version for [kind]. Nexus extraction is not supported yet.
  static int promptVersionFor(SourceKind kind) =>
      kind == SourceKind.discord ? discordPromptVersion : promptVersion;

  /// Bump both prompt versions when changing these request settings.
  static const double temperature = 0;
  static const int maxTokens = 4000;

  /// Builds the system prompt, with summary rules when [includeSummary] is true.
  /// The system text is not hashed in the cache key; bump both prompt versions
  /// when changing it so cached posts are extracted again.
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
            '  - Good paragraph: "Adds effects plugins, a dynamic lighting '
            'engine, and a screen-space distortion shader. Other mods can use '
            'its lighting, distortion, and post-processing APIs."\n'
            '  - Bad, do NOT write like this: "ShaderLib is a mod that adds '
            'shaders to Starsector." It names the mod and says "is a mod".\n'
            '  - Also bad: "Adds a suite of shader effects for enhanced graphics '
            'in Starsector." Drop "in Starsector" and end at "graphics".\n'
            '  The generated summary and descriptionAnchors are independent: '
            'return both when the post supports them. The anchors select the '
            'author\'s words; the summary describes the mod in your own words '
            'rather than copying that passage. Null anchors do not prevent a '
            'generated summary when the post contains enough facts. Leave a '
            'summary field null only '
            'when the post says too little to write it.'
        : '';

    return '''
Extract only facts stated in the opening posts of this Starsector mod thread.
Return ONLY a JSON object in the exact shape below. No prose, markdown, or comments.

All supplied posts are by the same author at the start of one thread. Read them
together. The number of posts does not determine the number of mods. Below,
"the post" means all supplied posts.

The post text has "[link: <url>]" written into it, marking where each link sat.
That is our note, not the author's words. Use it to see which mod a download
belongs to: a link written right by a mod's name is that mod's download. Never
copy a marker into "name", "descriptionAnchors", a changelog entry, or any other
field of copied text.

Hard rules:
- Copy text exactly as it appears. NEVER summarize, paraphrase, translate, or
  invent. If a fact is not stated in the post, leave that field null.
- Only use links that literally appear in the post. Never construct or guess a
  URL. Never "fix up" a URL.
- The mod's own version is NOT the game version it targets. If the post says it
  targets a game version, do not report that as the mod's version.
- Write every version without a leading "v": "3.0.2", not "v3.0.2". This
  applies to "version", the changelog's version keys and each update note's
  "version". Keep the rest exactly as the post writes it, so "0.12.2c" and
  "1.0-rc1" stay as they are.
- List ONLY mods that can actually be downloaded from THIS thread. Do NOT add a
  mod that is merely mentioned, recommended, linked as a successor, or that has
  to be downloaded somewhere else. Example: a post for one mod that also links a
  successor mod and recommends a separate tool wouldn't add the successor and tool to this thread.
  Example: a post lists the author's other mods "that do have their own
  thread", each with a description and a link to that thread but no download.
  Those mods are downloaded from their own threads, so none of them is an entry
  here, even when the post says they are safe to add.
- A patch for another mod is not a mod. Leave it out, even when its download is
  named after that mod. A patch is a file you copy into another mod's folder to
  change or overwrite that mod's files. Example: a thread for a mod that fixes
  ship collisions also offers one download per other ship mod, each named after
  that mod, holding .ship files to copy into it. That is one entry, the
  collision mod.
  $summaryRule

Return this JSON object:
{
  "isMod": <true or false: is this thread a downloadable Starsector mod or Starsector tool release?>,
  "mods": [
    {
      "name": "<the mod's name as written in the post>",
      "role": "<main | addon | separate | variant>",
      "isTool": <true for a program you run beside the game, such as a mod manager, launcher or editor; false for anything loaded into the game>,
      "nicknames": ["<another name the post itself uses for THIS mod, such as a short form, copied exactly>", "..."],
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
      "version": "<the mod's own current version, without a leading v, or null>",
      "supportLinks": [
        {
          "url": "<a link where readers can support THIS mod's own author with money, copied exactly from the post>",
          "label": "<1 to 4 words naming what the link is, e.g. Donate, Patreon, Buy me a coffee>"
        }
      ],
      "license": "<the license exactly as stated in the post, or null>",
      "sourceCode": "<the URL of the page where this mod's code is kept, copied from the post, or null>",
      "saveCompatibility": "<the post's own words on whether the mod can be ADDED to a game already in progress or needs a new game, copied exactly, or null>",
      "removalCompatibility": "<the post's own words on whether the mod can be REMOVED from a game in progress, copied exactly, or null>",
      "canAdd": "<yes | no | depends: the short answer to saveCompatibility, or null>",
      "canRemove": "<yes | no | depends: the short answer to removalCompatibility, or null>",
      "updateNotes": [
        {
          "version": "<the release this note is about, without a leading v, or null>",
          "quote": "<the post's own words on whether a save made with an older version survives UPDATING, copied exactly>",
          "answer": "<yes | no | depends>"
        }
      ],
      "needs": ["<the name of another mod this one will not run without>", "..."],
      "descriptionAnchors": {
        "startsWith": "<the first few words of the run of text that describes THIS mod, copied exactly>",
        "endsWith": "<the last few words of that same run of text, copied exactly>"
      },
      "aiUse": {
        "quote": "<the author's own words on whether AI tools were used to make this mod, copied exactly>",
        "usesAi": <true if the quote says AI tools were used, false if it says none were>,
        "uses": [
          {
            "area": "<portraits | illustrations | sprites | icons | music | voice | writing | translation | code | other>",
            "how": "<generated | edited | assisted, or null>",
            "extent": "<all | most | some, or null>",
            "optional": <true when the quote says the player can leave this part out; else false>
          }
        ],
        "tools": ["<an AI tool the post names, copied exactly>", "..."]
      }$summaryField
    }
  ]
}

Guidance:
- "isMod" says whether this thread is itself a downloadable Starsector mod or
  Starsector tool release:
  - true: the post offers a mod you can download and load into the game — this
    is the normal case. If you listed any real download in "mods", "isMod" is
    true.
  - also true: the post offers a program made for Starsector that you download
    and run beside the game rather than load into it — a mod manager, a
    launcher, a ship or save editor.
  - false: the thread is NOT a mod or tool release. Examples: a discussion or
    question, a guide or tutorial, a modding-help request, a list or index that
    only points to other threads, or artwork.
  When unsure, say true. It is safer to keep a borderline thread than to drop a
  real mod.
- Most threads are about exactly one mod, so "mods" is usually a one-item list
  with role "main". But some threads are a collection of mods, or have addon/example/etc mods.
  - Count the names that have a download of their own. That is how many entries
    you return. What each one's "role" is, is worked out separately below.
- "role" tells how each mod relates to the OTHER mods declared on this thread.
  - "main": a mod you can install on its own, without any other mod from this
    thread. Some threads have multiple "main" mods.
  - "addon": a mod that needs another mod FROM THIS THREAD to work. Set
    "requires" to that mod's exact name.
  - "variant": another build of a main mod on this thread — a lite, basic or
    stripped-down version, a version for an older game release. A variant is
    still a variant when it can be installed on its own.
  Example: A thread opens with "MyLib — this must be enabled if you use
  any of the other mods listed here", and then describes five packs of ships.
  That is SIX entries: "MyLib" with role "main", and five with role "addon" and
  "requires": "MyLib".
  Example: A thread for a ship pack that says it requires MagicLib. This is one main mod.
  Example: A thread describes the author's philosophy in the first post and lists 5 mods
    with downloads they made in the second post. This is 5 main mods.
  Example: A thread for a mod that has the titular mod as well as a stripped-down version.
    This is one main mod and one variant.
  Example: A thread has a mod that the thread title is about as well as a 'standalone' mod
    that adds one ship as an alternative to one in the main mod. This is two main mods because
     the second one is standalone, not needing the first one to run.

- "isTool" says whether this entry is a program made for Starsector that you
  download and run beside the game — a mod manager, a launcher, a ship or save
  editor — rather than a mod loaded into the game. Almost every entry is false.
  A tool still gets its role like any other entry: on its own thread it is
  "main". List a tool's downloads exactly as you would a mod's.

- "nicknames" is the other names the post itself uses for THIS mod. Players
  search for mods by these, so they matter, but most posts use none and the
  list is then empty.
  - A short form or abbreviation the author writes: "Industrial Evolution
    (IndEvo)" gives "nicknames": ["IndEvo"]. "Ship/Weapon Pack, or SWP for
    short" gives ["SWP"].
  - A name the post says the mod used to have: "formerly known as Exerelin"
    gives ["Exerelin"].
  - Copy each one exactly as the post writes it. NEVER make one up, not even an
    obvious set of initials, when the post does not write it. A name that only
    appears inside a link address or a file name does not count.
  - Do NOT include the mod's own name again, a version, the author's name, the
    name of a different mod, or a word that is just a description ("faction
    mod", "ship pack").

- Add-on vs mirror — do not confuse these:
  - A DIFFERENT file that adds to or extends the mod is its OWN mod entry, with
    role "addon".
  - The SAME file (incl version) offered on another host is NOT a new mod. It is another
    download under the same mod, with kind "mirror".
- "downloads" is that mod's real download links. You are given the links the
  scraper already auto-detected: confirm the real ones, add any it missed
  (including links inside spoiler boxes or on hosts it does not know), and leave
  out anything that is not a download of the mod. A mod may offer more than one
  link — list each. Use "kind":
  - "direct": a normal download of the mod's file.
  - "mirror": the same file (incl version) offered on another host.
  - "trios": an "Install with TriOS" link.
- The changelog has two parts, and a post can have BOTH — return each part that
  the post actually has. Copy changelog text and URLs exactly;
  paraphrased notes and altered URLs are rejected.
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
  - On a thread offering exactly one mod, the post's main banner, logo, or
    first screenshot is that mod's picture — set it.
  - When a post offers several mods, or a main mod plus add-ons, give each mod
    the picture that clearly belongs to it: a banner, logo, or screenshot next
    to its name or its download. Leave it null for a mod the post ties no
    picture to.
  - Copy the image URL exactly from the images list. Never guess or build a URL,
    and never use one that is not in that list.
  - A picture may carry "(seen: <kind>: <what it shows>)" after its address. We
    wrote that by looking at the picture, so it is not the author's words. Use
    it to choose: the mod's banner, logo or a screenshot of it is a good
    picture; a button, a badge, a divider or a picture of another mod is not.
    Never copy those words into any field.
  - Do NOT use badges or icons (license shields, version badges, forum smileys, donation links).
- "supportLinks" is where readers can give money to the author of THIS mod: a
  Patreon, Ko-fi, PayPal or donation page. Most posts have none, and the list
  is then empty.
  - Only the mod's OWN author. Posts often credit other people — a composer, an
    artist, a playtester — and say "Support him here!" beside their links.
    Those support somebody else: leave them out.
    Example: "Credits: Ed Harrison — Music, used with permission. Support him
    here! https://edharrison.bandcamp.com/" is a credit, so it gives nothing.
  - A link only to somebody's social media, website, video channel or music
    page is not a support link, even beside the word "support".
  - A forum thread is never a support link, and nor is a feedback form.
  - "label" is a short name for the button, in 1 to 4 words: "Donate",
    "Patreon", "Ko-fi", "Buy me a coffee". The post often gives the link no
    words of its own (it is a picture button, or a bare address), so name it
    from what the post says around it. Never put the address in the label.
- "sourceCode" is where the mod's code is kept — a GitHub, GitLab, Bitbucket or
  similar repository page:
  - Give the repository's own page (e.g. "https://github.com/someone/theirmod"),
    never a file you download from it. A release, a release asset, a .zip, or a
    "download" link is not the source code, even on GitHub. A link to one file
    in the repository (a LICENSE file, a changelog, one source file) is not it
    either.
  - This is the ONE place you may shorten a link rather than copy it whole: when
    the post links a file inside the repository but never the repository itself,
    give the repository that link is part of. Keep the host and the owner and
    repository names exactly as the post writes them, and drop everything after.
    Example: the post links
    "https://github.com/someone/theirmod/raw/master/theirmod%201.2.zip", so
    "sourceCode" is "https://github.com/someone/theirmod".
  - Never take a repository from anywhere but a link in the post, and never
    change how the post spells it. Leave it null when the post links nothing on
    a code site.
- Saves: posts answer up to three DIFFERENT questions about saves. Keep them
  apart. A mod can be safe to add to a running game and still break that game
  when you update it, so one answer never stands in for another. Most posts
  answer one of these questions or none of them, so it is normal for
  "saveCompatibility" and "removalCompatibility" to be null and "updateNotes"
  to be empty. NEVER put the same words in two of these places: each one holds
  only the words about its own question.
  - "saveCompatibility" is about ADDING the mod to a game that does not have it
    yet. For example "Save compatible", "Can be added to an existing save",
    "Safe to add mid-game", "Requires a new game", or "Not save-game
    compatible".
  - "updateNotes" is about UPDATING: a game that already uses an older version
    of this mod, moving to a newer one. For example "This update is not save
    compatible", "Not save compatible with versions prior to 2.0.0",
    "Save-compatible with previous versions", or "Safe to update midsave".
    Words that name an update, an older or previous version, or a version
    number belong here, NOT in "saveCompatibility". Give one entry per note;
    a thread can carry several, one for each release that mentions saves.
    - "quote" is the note, copied word-for-word.
    - "version" is the release the note was written for, copied as the post
      writes it, without a leading "v". Give it when the note names that
      release, or sits in that release's announcement or changelog entry:
      "Minor patch v1.0.1 is out. It is save-compatible." gives "version":
      "1.0.1", and "NOT save compatible" inside the changelog entry for 0.8.0
      gives "version": "0.8.0".
    - "version" is null when the note is not tied to one release: a rule about
      every update ("All updates are save-compatible"), or a statement about the
      mod as it is now ("Not save compatible with versions prior to 2.0.0" says
      which old saves still work, not which release it was written for).
    - Never guess a version. Copy one only when the post ties the note to it.
  - "removalCompatibility" is about REMOVING the mod from a game in progress.
    For example "Cannot be removed from a save" or "Safe to remove at any
    time".
  - When one sentence answers two of these, split it: copy only the part about
    each question into that question's field, and leave the rest out. Never
    copy the whole sentence into both. Examples:
    - "Can be added to a running game, and can be taken out again at any time
      (ships you already own will stay)" gives "saveCompatibility": "Can be
      added to a running game" and "removalCompatibility": "can be taken out
      again at any time (ships you already own will stay)".
    - "Safe to add to ongoing saves, but version 0.8.0 will break existing
      saves" gives "saveCompatibility": "Safe to add to ongoing saves" and one
      update note: "version": "0.8.0", "quote": "version 0.8.0 will break
      existing saves".
  - A plain "Save compatible" with nothing about updates or versions answers
    ADDING only. Leave "updateNotes" empty.
  - Copy word-for-word. Do not summarize, judge, or decide it yourself. Leave
    each one null, or the list empty, when the post does not answer that
    question.
  - "canAdd", "canRemove" and each update note's "answer" are the short answers,
    read off the words you copied:
    - "yes": the words say plainly that you can. "Save compatible" gives
      "canAdd": "yes".
    - "no": the words say plainly that you cannot. "Requires a new game" gives
      "canAdd": "no". "This update is not save compatible" gives an update note
      with "answer": "no".
    - "depends": the answer has a condition or an exception, so a reader has to
      read the words to know. "Save compatible with versions 1.6.0 and higher"
      gives an update note with "answer": "depends". "Safe to add, but some
      derelicts won't spawn" gives "canAdd": "depends".
    - "canAdd" and "canRemove" are null whenever their words are null. Never
      give a short answer without the words it came from.
- "needs" is the other mods this one will not run without:
  - Nearly every Starsector mod needs a library — LazyLib, MagicLib,
    GraphicsLib, LunaLib, ShaderLib — and many need Nexerelin. The post nearly
    always says so, in a line like "Requires LazyLib and MagicLib" or under a
    "Requirements" or "Dependencies" heading.
  - Give the mod's NAME only, as the post writes it. Not a link, not a version,
    not a sentence. One entry per mod.
  - "needs" is for mods you get somewhere ELSE. A mod on THIS thread that this
    one will not run without goes in "requires", with role "addon" — not here.
  - Only mods the post says are REQUIRED. A mod that is merely recommended,
    supported, compatible, or "works well with" is NOT a requirement, and nor is
    the game itself or a Java version.
  - Leave it as an empty list when the post names no requirement. Do not guess a
    library from what the mod appears to do.
- "descriptionAnchors" is optional and points at the author's own words about
  ONE mod. You do not write a description — you say where the author's already is:
  - Use it when a suitable description exists, on single-mod threads as well
    as threads carrying several mods.
    On a single-mod thread, select a focused introduction explaining what the
    mod does, such as the paragraph under "WHAT DOES THIS MOD DO?". This supplies
    an author-written listing summary; the full post remains the description.
    Keep installation steps, requirements, credits, FAQs and changelogs outside
    that introduction. On a collection thread, select the author's description
    of this mod, for example the passage under or above its name, without taking
    in another mod's words.
  - "startsWith" is the first few words of that run of text, copied exactly.
    "endsWith" is the last few words of the SAME run, copied exactly. Five to
    ten words each is right. Copy them letter for letter — they are looked up in
    the post, and anything not found there is thrown away.
  - The run must be one unbroken stretch of text inside ONE post. Never point at
    the start in one post and the end in another, and never stitch together
    pieces from different places.
  - Do not include the mod's own name line, the version line, or the download
    link if you can start after them — the description is what the mod does.
    Never let an anchor take in a "[link: ...]" marker; it is our note, so it is
    not in the author's text and the anchor will be thrown away.
  - Leave it null when the author does not give this mod a suitable continuous
    description, or whenever you are unsure. A name, download link, requirements
    or installation instructions alone are not a description of what the mod
    does. Return null rather than pointing at unrelated text just to fill it.
- "aiUse" is what the author says about using AI tools to MAKE this mod: image
  generators, voice or music generators, chatbots, code assistants. Most posts
  say nothing about it, and "aiUse" is then null.
  - In Starsector, "AI" usually means the game's own AI: ship AI, fleet AI, AI
    cores, AI-controlled factions. Text about those is NOT about AI use.
    Examples:
    - "AI Tweaks provides various improvements focused on ship AI and
      AI-assisted player support" is about the game. "aiUse" is null.
    - "AI fleets now use carriers better" is about the game. "aiUse" is null.
    - A portrait pack called "AI Portraits of AI Cores (As People)" is about AI
      cores, and its title is not about AI use. But its post also says "All the
      portraits were generated using Severian Void's Stable Diffusion model".
      That sentence IS about AI use: "usesAi": true, with one use, "area":
      "portraits".
  - "quote" is the author's statement, copied word for word. Give one
    statement only. When the post has two, take the one that says most plainly
    which parts were made with AI, such as one under a heading like "AI
    disclaimer". A thank-you in the credits is the last choice. Your "uses"
    can still cover both.
  - "usesAi" is true when the quote says AI tools were used for any part of the
    mod. It is false when the quote says no AI was used: "This mod contains
    zero AI generated content" or "No AI Generation". When the post makes
    neither statement, "aiUse" is null.
  - "uses" has one entry per part of the mod the quote says AI was used for.
    It is empty when "usesAi" is false. When the quote says AI was used but not
    for what, give one entry with "area": "other".
    - "area": "portraits" (character portraits), "illustrations" (pictures for
      markets, planets, events or dialogue), "sprites" (ships, weapons and other
      in-game sprites), "icons", "music", "voice" (voice lines, speech),
      "writing" (descriptions, dialogue and other text), "translation",
      "code", or "other".
    - "how": "generated" when the AI tool made it and it is used as it came;
      "edited" when the tool made it and a person then changed it by hand,
      including a picture upscaled with AI; "assisted" when a person made it
      with the tool's help, such as a grammar pass, code completion or help with
      a translation. null when the quote does not say.
    - "extent": "all", "most" or "some", only when the quote says how much:
      "All images are AI-generated", "most of the images", "a small portion of
      the portraits". A sentence saying the AI tool made the whole mod also
      counts as "all", for every area it covers: "Claude Code built this" or
      "this mod was written entirely by ChatGPT". null when it does not say.
    - "optional": true only when the post says the player can leave that part
      out, such as an optional portrait pack. Look for this anywhere in the
      post, not only in your quote: a heading such as "Optional AI generated
      portraits", or steps to switch them on ("to enable, unzip..."), make
      those portraits optional. Otherwise false.
    - "Upscaled" on its own is not AI use. In these posts it usually just means
      made bigger.
  - "tools" is the AI tools the post names, such as Midjourney, Stable
    Diffusion, DALL-E, ChatGPT or ElevenLabs, copied as the post writes them.
    Never add a tool the post does not name. Empty when it names none.
  - Example: "The optional portraits were generated with DALL-E 3 and edited by
    hand. LLMs were used for grammar passes on written text, and code
    assistance." gives "usesAi": true, "tools": ["DALL-E 3"] and three uses:
    "portraits" with "how": "edited" and "optional": true, "writing" with
    "how": "assisted", and "code" with "how": "assisted".
  - Example: the credits thank someone for "AI generated versions" of the
    portraits, and elsewhere a section is headed "Optional AI generated
    Portraits" and says "To enable, unzip the file". That gives one use,
    "portraits" with "optional": true.
  - On a thread offering several mods, a statement written for the whole
    thread goes on every "main" mod it covers. A statement about one mod stays
    on that mod.
- Leave any field null/empty when the post does not state it. Do not guess.$summaryGuidance
''';
  }

  /// JSON Schema matching the response described by [buildSystemPrompt].
  ///
  /// Used for `response_format: json_schema` when structured output is enabled.
  /// Keep the schema and prompt in sync, and bump both prompt versions when
  /// changing the response shape.
  static Map<String, dynamic> buildResponseSchema(
      {bool includeSummary = false}) {
    Map<String, dynamic> nullableString() => {
          'type': ['string', 'null']
        };
    Map<String, dynamic> saveAnswer() => {
          'type': ['string', 'null'],
          'enum': ['yes', 'no', 'depends', null],
        };

    final modProps = <String, dynamic>{
      'name': {'type': 'string'},
      'role': {
        'type': 'string',
        'enum': ['main', 'addon', 'separate', 'variant'],
      },
      'isTool': {'type': 'boolean'},
      'nicknames': {
        'type': 'array',
        'items': {'type': 'string'},
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
            // Version keys come from the post, so additional properties are allowed.
            'additionalProperties': {'type': 'string'},
          },
        },
        'required': ['link', 'entries'],
        'additionalProperties': false,
      },
      'version': nullableString(),
      'supportLinks': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'url': {'type': 'string'},
            'label': {'type': 'string'},
          },
          'required': ['url', 'label'],
          'additionalProperties': false,
        },
      },
      'license': nullableString(),
      'sourceCode': nullableString(),
      'saveCompatibility': nullableString(),
      'removalCompatibility': nullableString(),
      'canAdd': saveAnswer(),
      'canRemove': saveAnswer(),
      'updateNotes': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'version': nullableString(),
            'quote': {'type': 'string'},
            'answer': saveAnswer(),
          },
          'required': ['version', 'quote', 'answer'],
          'additionalProperties': false,
        },
      },
      'needs': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'descriptionAnchors': {
        'type': ['object', 'null'],
        'properties': {
          'startsWith': nullableString(),
          'endsWith': nullableString(),
        },
        'required': ['startsWith', 'endsWith'],
        'additionalProperties': false,
      },
      'aiUse': {
        'type': ['object', 'null'],
        'properties': {
          'quote': {'type': 'string'},
          'usesAi': {
            'type': ['boolean', 'null']
          },
          'uses': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'area': {
                  'type': 'string',
                  'enum': [for (final a in AiUseArea.values) a.name],
                },
                'how': {
                  'type': ['string', 'null'],
                  'enum': [for (final h in AiUseHow.values) h.name, null],
                },
                'extent': {
                  'type': ['string', 'null'],
                  'enum': [for (final e in AiUseExtent.values) e.name, null],
                },
                'optional': {'type': 'boolean'},
              },
              'required': ['area', 'how', 'extent', 'optional'],
              'additionalProperties': false,
            },
          },
          'tools': {
            'type': 'array',
            'items': {'type': 'string'},
          },
        },
        'required': ['quote', 'usesAi', 'uses', 'tools'],
        'additionalProperties': false,
      },
    };

    final modRequired = <String>[
      'name',
      'role',
      'isTool',
      'nicknames',
      'requires',
      'downloads',
      'image',
      'changelog',
      'version',
      'supportLinks',
      'license',
      'sourceCode',
      'saveCompatibility',
      'removalCompatibility',
      'canAdd',
      'canRemove',
      'updateNotes',
      'needs',
      'descriptionAnchors',
      'aiUse',
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

  /// Builds a deterministic user message from the reduced post and scraper hints.
  /// Its text is part of the cache fingerprint.
  static String buildUserPrompt({
    required String reducedText,
    required List<({String url, String text, bool isDownloadable})> links,
    required List<String> ruleLinks,
    List<({String url, String? alt, String? seen})> images = const [],
    String? gameVersion,
    String? modTitle,
    List<String> followUpTexts = const [],
    bool isDiscordThread = false,
  }) {
    final buffer = StringBuffer();

    // Keep this section Discord-only to preserve forum cache fingerprints.
    if (isDiscordThread) {
      buffer.writeln('=== SOURCE ===');
      buffer.writeln('A Discord announcement thread. The title below is the '
          "thread's name. The post is the author's announcement message, and "
          'each follow-up post is a later message by the same author in the '
          'same thread, often an update note.');
      buffer.writeln();
    }

    // Titles can carry release versions, so title changes must invalidate the cache.
    if (modTitle != null && modTitle.trim().isNotEmpty) {
      buffer.writeln('=== MOD TITLE ===');
      buffer.writeln(modTitle.trim());
      buffer.writeln();
    }

    buffer.writeln('=== POST TEXT (spoiler boxes included; '
        '"[link: <url>]" marks where a link sat) ===');
    buffer.writeln(reducedText.trim());
    buffer.writeln();

    // Authors may put their downloads in a follow-up post.
    for (var i = 0; i < followUpTexts.length; i++) {
      final text = followUpTexts[i].trim();
      if (text.isEmpty) continue;
      buffer.writeln('=== FOLLOW-UP POST ${i + 1} BY THE SAME AUTHOR '
          '(same thread, read it with the post above) ===');
      buffer.writeln(text);
      buffer.writeln();
    }

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

    buffer.writeln(
        '=== IMAGES IN THE POST (use only these URLs for "image") ===');
    if (images.isEmpty) {
      buffer.writeln('(none)');
    } else {
      for (final img in images) {
        final alt = img.alt != null && img.alt!.trim().isNotEmpty
            ? '  "${img.alt!.trim()}"'
            : '';
        // Left off when there is no description, so the prompt of a post
        // whose pictures were never looked at is exactly what it was.
        final seen = img.seen != null && img.seen!.trim().isNotEmpty
            ? '  (seen: ${img.seen!.trim()})'
            : '';
        buffer.writeln('- ${img.url}$alt$seen');
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
