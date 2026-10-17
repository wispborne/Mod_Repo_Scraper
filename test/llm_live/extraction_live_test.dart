@Tags(['llm'])
@Timeout(Duration(minutes: 10))
library;

import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:mod_repo_scraper/site/description_slice.dart';
import 'package:mod_repo_scraper/site/post_html.dart';
import 'package:test/test.dart';

import 'live_llm.dart';

/// These run the real model against real forum posts saved in
/// `test/llm_live/posts/`. They are not part of `dart test` — see
/// `test/llm_live/README.md` for how to run them and what to do when one
/// fails.
///
/// A failure here is usually a prompt to tighten, not a broken build. The model
/// is not deterministic, so read the failure message (it prints everything the
/// model said) before changing anything, and run it a second time to see
/// whether it was a one-off.
void main() {
  /// Reads a thread with the model, or skips the test when there is no model
  /// to read it with. [markTestSkipped] rather than a `skip:` argument, so
  /// `--run-skipped` can't force a run against a server that isn't there.
  Future<LlmStoreEntry?> read(int topicId) async {
    final off = await whyLiveLlmIsOff();
    if (off != null) {
      markTestSkipped('No live model: $off');
      return null;
    }
    return readWithTheModel(topicId);
  }

  group('a thread that is one mod', () {
    for (final summaries in [true, false]) {
      test(
          'Extra Systems (36143) extracts its introduction with summaries '
          '${summaries ? 'on' : 'off'}',
          () async {
        final off = await whyLiveLlmIsOff();
        if (off != null) {
          markTestSkipped('No live model: $off');
          return;
        }
        final answer = await readWithTheModel(36143, summaries: summaries);
        final why = describe(answer);
        expect(answer, isNotNull, reason: why);
        expect(answer!.mods, hasLength(1), reason: why);
        final mod = answer.mods.single;
        final anchors = mod.descriptionAnchors;
        expect(anchors, isNotNull, reason: why);
        final excerpt = sliceDescriptionHtml(
            cleanPostHtml(loadPost(36143).contentHtml),
            anchors!.startsWith, anchors.endsWith);
        final words = plainWordsOf(excerpt);
        expect(words, isNotNull, reason: why);
        expect(flatten(words!), contains('creditsmaterialsandstorypoints'),
            reason: why);
        expect(flatten(words), contains('extrasystemsbay'), reason: why);
        expect(words, isNot(contains('WHAT DOES THIS MOD DO?')), reason: why);
        expect(words, isNot(contains('Requires LunaLib')), reason: why);
        expect(words, isNot(contains('FAQ')), reason: why);
        if (summaries) {
          expect(mod.extras?.summary?.sentence, isNotEmpty, reason: why);
          expect(mod.extras?.summary?.paragraph, isNotEmpty, reason: why);
        } else {
          expect(mod.extras?.summary, isNull, reason: why);
        }
      });
    }

    test('Nexerelin (9175) is one mod, with its own version and needs',
        () async {
      final answer = await read(9175);
      if (answer == null) return;
      final why = describe(answer);

      expect(answer.isMod, isTrue, reason: why);
      expect(answer.mods, hasLength(1), reason: why);

      final mod = answer.mods.single;
      expect(sameName(mod.name, 'Nexerelin'), isTrue,
          reason: 'the thread title carries the version and the game version, '
              'and neither belongs in the name.\n$why');
      expect(mod.role, 'main', reason: why);
      expect(mod.downloads, isNotEmpty, reason: why);
      expect(mod.downloads.first.url, contains('github.com/Histidine91'),
          reason: why);

      // 0.98a is the game version. Reporting it as the mod's own is the
      // mistake the prompt spends a hard rule on.
      expect(mod.extras?.version, isNot('0.98a'), reason: why);
      expect(mod.extras?.version, contains('0.12.2'), reason: why);

      final needs = (mod.extras?.needs ?? const <String>[])
          .map(flatten)
          .toList();
      expect(needs, contains('lazylib'), reason: why);
      expect(needs, contains('magiclib'), reason: why);
    });

    test('MagicLib (25868) is one mod and needs only what the post says',
        () async {
      final answer = await read(25868);
      if (answer == null) return;
      final why = describe(answer);

      expect(answer.mods, hasLength(1), reason: why);
      final mod = answer.mods.single;
      expect(sameName(mod.name, 'MagicLib'), isTrue, reason: why);
      expect(mod.extras?.version, isNot('0.98a'), reason: why);

      // The post names LazyLib and nothing else. A model asked what a mod
      // needs will happily add the rest of the usual libraries.
      final needs = (mod.extras?.needs ?? const <String>[])
          .map(flatten)
          .toList();
      expect(needs, isNot(contains('graphicslib')), reason: why);
      expect(needs, isNot(contains('nexerelin')), reason: why);
    });
  });

  group('what a post says about saves', () {
    // The post says it in one sentence: "Safe to add to existing saves, and
    // safe to remove from existing saves (though already-generated systems
    // will remain in place)". The model once copied the whole sentence into
    // both the adding and the removing field, so the page said it twice.
    test('Customizable Star Systems (27785) splits adding from removing',
        () async {
      final answer = await read(27785);
      if (answer == null) return;
      final why = describe(answer);

      expect(answer.mods, hasLength(1), reason: why);
      final extras = answer.mods.single.extras;
      final adding = extras?.saveCompatibility;
      final removing = extras?.removalCompatibility;

      expect(adding, isNotNull, reason: why);
      expect(removing, isNotNull, reason: why);
      expect(flatten(adding!), contains('safetoadd'), reason: why);
      expect(flatten(adding), isNot(contains('remove')),
          reason: 'the adding field took in the words about removing.\n$why');
      expect(flatten(removing!), contains('safetoremove'), reason: why);
      expect(flatten(removing), isNot(contains('safetoadd')),
          reason: 'the removing field took in the words about adding.\n$why');

      expect(extras!.canAdd, SaveAnswer.yes, reason: why);

      // The author's second post says "Minor patch v1.0.1 is out ... It is
      // save-compatible." That is about updating to v1.0.1 and nothing else;
      // the mod is on v3.0.2 now. Without its version it read as a note about
      // the current release.
      for (final note in extras.updateNotes ?? const <LlmUpdateNote>[]) {
        if (!flatten(note.quote).contains('savecompatible')) continue;
        expect(note.version, isNotNull,
            reason: 'the patch note lost the version it was written for.\n$why');
        expect(flatten(note.version!), contains('101'), reason: why);
      }
    });
  });

  group('a thread that is several mods', () {
    // The thread this whole change was made for. Every download is a
    // shields.io badge inside a link with no words of its own, and they all
    // sit in the author's SECOND post, under the name each belongs to. Before
    // the links were written back into the post text, the model returned one
    // mod called "Computica's Faction Forks" with all seven downloads on it.
    test('Computica\'s Faction Forks (35651) splits into its seven forks',
        () async {
      final answer = await read(35651);
      if (answer == null) return;
      final why = describe(answer);

      // Each fork, and the piece of its GitHub address that proves the right
      // download went to the right mod.
      const forks = {
        'Kwin': 'Starsector-CFF-Kwin',
        'Farsight Drive': 'Starsector-CFF-FarsightDrive',
        'Junk Pirates': 'Starsector-CFF-JunkPirates',
        'Valkyrians': 'Starsector-CFF-Valkyrians',
        'Blackrock': 'Starsector-CFF-BRDY',
        'FSF': 'Starsector-CFF-FSF',
        'Stellar Networks': 'Starsector-UFP-StelNet',
      };

      expect(answer.mods.length, greaterThanOrEqualTo(forks.length),
          reason: 'the second post gives seven mods a name, a paragraph and a '
              'download each.\n$why');

      for (final entry in forks.entries) {
        final mod = modNamed(answer, entry.key);
        expect(mod, isNotNull,
            reason: 'no mod named for "${entry.key}".\n$why');
        expect(mod!.downloads.map((d) => d.url).join(' '),
            contains(entry.value),
            reason: '"${mod.name}" did not get its own download '
                '(${entry.value}).\n$why');
      }

      // The thread's title names the shelf the forks sit on, not a mod.
      for (final mod in answer.mods) {
        expect(nameHolds(mod.name, 'Faction Forks'), isFalse,
            reason: 'the collection was returned as a mod of its own.\n$why');
      }

      // The first post lists forks that are not out yet — "Neutrino
      // Corporation: Waiting for permission...", "The Nomads: Paused...".
      // A name with no download is not a mod.
      for (final notOut in ['Neutrino', 'Nomads', 'Avali', 'Eridani Combine']) {
        expect(modNamed(answer, notOut), isNull,
            reason: '"$notOut" has no download in this thread.\n$why');
      }
    });

    test('Hartley\'s Miscellaneous Mods (34161) is four mods, one post',
        () async {
      final answer = await read(34161);
      if (answer == null) return;
      final why = describe(answer);

      const mods = {
        'Useful.Tithes': 'Useful.Tithes',
        'Big Pilum Energy': 'Big-Pilum-Energy',
        'Lost.Sector': 'Lost.Sector',
        'Disco.Balls': 'Disco.Balls',
      };

      expect(answer.mods, hasLength(mods.length), reason: why);
      for (final entry in mods.entries) {
        final mod = modNamed(answer, entry.key);
        expect(mod, isNotNull, reason: 'no mod named "${entry.key}".\n$why');
        expect(mod!.role, 'main',
            reason: 'each of these installs on its own.\n$why');
        expect(mod.downloads.map((d) => d.url).join(' '), contains(entry.value),
            reason: '"${mod.name}" did not get its own download.\n$why');
      }
    });

    test('Yunru Mods (21968) is a library plus add-ons that name it', () async {
      final answer = await read(21968);
      if (answer == null) return;
      final why = describe(answer);

      final core = modNamed(answer, 'YunruCore');
      expect(core, isNotNull, reason: why);
      expect(core!.role, 'main', reason: why);

      final addons =
          answer.mods.where((m) => m.role == LlmModRole.addon).toList();
      expect(addons.length, greaterThanOrEqualTo(3),
          reason: 'the post lists several packs that need YunruCore.\n$why');
      for (final addon in addons) {
        expect(addon.requires, isNotNull,
            reason: '"${addon.name}" is an add-on with nothing to add to.'
                '\n$why');
        expect(nameHolds(addon.requires!, 'YunruCore'), isTrue,
            reason: '"${addon.name}" says it needs "${addon.requires}".\n$why');
      }

      // The author writes a paragraph about each pack under its own name, so
      // each one has its own description to point at.
      final withAnchors =
          answer.mods.where((m) => m.descriptionAnchors != null).length;
      expect(withAnchors, greaterThanOrEqualTo(3), reason: why);
    });
  });

  group('other names the post uses for a mod', () {
    // Readers search by these, so a made-up one sends them to the wrong mod.
    // The extractor throws out any the post does not write; these check the
    // model finds the real one and does not hand it to the wrong thing.
    test('Yunru Mods (21968) gives a pack the name it used to have', () async {
      final answer = await read(21968);
      if (answer == null) return;
      final why = describe(answer);

      // "Yunru's Pirates and Pathers — My first, and thus oldest mod. Formerly
      // known as the Pirate Collection, this adds…"
      final pack = modNamed(answer, 'Pirates and Pathers');
      expect(pack, isNotNull, reason: why);
      final nicknames = pack!.nicknames ?? const <String>[];
      expect(nicknames.any((n) => nameHolds(n, 'Pirate Collection')), isTrue,
          reason: why);

      // The old name belongs to that one pack, not to the library or the
      // other packs beside it.
      for (final mod in answer.mods) {
        if (identical(mod, pack)) continue;
        expect(
            (mod.nicknames ?? const <String>[])
                .any((n) => nameHolds(n, 'Pirate Collection')),
            isFalse,
            reason: '"${mod.name}" was given another pack\'s old name.\n$why');
      }
    });

    test('MagicLib (25868) is not given the name of one of its parts',
        () async {
      final answer = await read(25868);
      if (answer == null) return;
      final why = describe(answer);

      // The post writes `MagicRender … (aka "SpriteRenderManager")`. That is
      // another name for one part of the library, not for MagicLib.
      final nicknames = answer.mods.single.nicknames ?? const <String>[];
      expect(nicknames.any((n) => nameHolds(n, 'SpriteRenderManager')),
          isFalse,
          reason: why);
      expect(nicknames.any((n) => nameHolds(n, 'MagicRender')), isFalse,
          reason: why);
    });
  });

  group('who a support link is for', () {
    test("Draconis Fleet (33489) gives no support links: its credits' links "
        'support other people', () async {
      final answer = await read(33489);
      if (answer == null) return;
      final why = describe(answer);

      // The post's credits say "Support him here!" beside a composer's, an
      // artist's and a playtester's links. None of them is the mod's author.
      final links = [
        for (final mod in answer.mods)
          ...?mod.extras?.supportLinks?.map((l) => l.url),
      ];
      for (final credit in [
        'edharrison',
        '00edit',
        'DrSolis',
        'Duckie0012',
      ]) {
        expect(links, isNot(contains(contains(credit))),
            reason: 'a link in the credits supports that person, not the '
                "mod's author.\n$why");
      }
    });

    test("GraphicsLib (10982) keeps its author's donate button, and names it",
        () async {
      final answer = await read(10982);
      if (answer == null) return;
      final why = describe(answer);

      // The link is a picture with no words of its own and none around it, on
      // a host nothing recognises. Only the address says "donate".
      final donate = [
        for (final mod in answer.mods)
          ...?mod.extras?.supportLinks
              ?.where((l) => l.url.contains('sc2mafia.com/Starsector/donate')),
      ];
      expect(donate, isNotEmpty,
          reason: "it is the author's own donation page.\n$why");
      expect(donate.first.label, isNotNull,
          reason: 'with no words in the post, the label is the only name the '
              'button will have.\n$why');
    });
  });

  group('a program run beside the game', () {
    test('a mod manager (35155) is kept as a tool, not dropped as a non-mod',
        () async {
      final answer = await read(35155);
      if (answer == null) return;
      final why = describe(answer);

      expect(answer.isMod, isTrue,
          reason: 'QBMBAMM is a program made for Starsector with its own '
              'download — a release worth keeping, even though it is not '
              'loaded into the game.\n$why');
      expect(answer.mods, hasLength(1), reason: why);
      final tool = answer.mods.single;
      expect(tool.isTool, isTrue,
          reason: 'it is a mod manager you run beside the game, so TriOS must '
              'not offer to install it as a mod.\n$why');
      expect(tool.role, LlmModRole.main, reason: why);
      expect(tool.downloads.map((d) => d.url),
          contains(contains('QBMBAMM-Windows.zip')),
          reason: why);
    });
  });

  group('a Discord announcement thread', () {
    /// [read] for a saved Discord thread.
    Future<LlmStoreEntry?> readDiscord(String threadId) async {
      final off = await whyLiveLlmIsOff();
      if (off != null) {
        markTestSkipped('No live model: $off');
        return null;
      }
      return readDiscordWithTheModel(threadId);
    }

    test('Adjustable S-Mods (one announcement) is one mod with its download and needs', () async {
      final answer = await readDiscord('1255421874075336824');
      if (answer == null) return;
      final why = describe(answer);

      expect(answer.isMod, isTrue, reason: why);
      expect(answer.mods, hasLength(1), reason: why);
      final mod = answer.mods.single;
      expect(nameHolds(mod.name, 'Adjustable S-Mods'), isTrue, reason: why);
      expect(mod.downloads.map((d) => d.url), contains(contains('AdjustableSMods-1.1.2.zip')),
          reason: why);
      expect((mod.extras?.needs ?? const []).map(flatten), contains('lunalib'), reason: why);
      expect(mod.extras?.canRemove, SaveAnswer.no,
          reason: 'the post says "Not safe to remove from an ongoing campaign".\n$why');
    });

    test("Retrofitted Bridge reads the author's update message as a changelog", () async {
      final answer = await readDiscord('1257247685723820112');
      if (answer == null) return;
      final why = describe(answer);

      expect(answer.mods, hasLength(1), reason: why);
      final mod = answer.mods.single;
      expect(mod.extras?.version, '0.0.2',
          reason: 'the later message announces v0.0.2.\n$why');
      final entries = mod.extras?.changelog?.entries ?? const {};
      expect(entries.keys, contains('0.0.2'), reason: '$entries\n$why');
      expect(entries['0.0.2'], contains('UI improvements'), reason: why);
    });

    test('All the Domain Drones+ is two mods, each with its own download', () async {
      // The one recorded thread announcing two independent mods: "Vanilla"
      // changes the vanilla drones, "New Drones" adds new ones, and each is its
      // own download. Neither needs the other.
      final answer = await readDiscord('1271590391065477143');
      if (answer == null) return;
      final why = describe(answer);

      final mains = answer.mods.where((m) => m.role == LlmModRole.main).toList();
      expect(mains, hasLength(2), reason: 'two mods that do not need each other are both main.\n$why');
      final vanilla = mains.where((m) => nameHolds(m.name, 'Vanilla')).toList();
      final newDrones = mains.where((m) => nameHolds(m.name, 'New Drones')).toList();
      expect(vanilla, hasLength(1), reason: why);
      expect(newDrones, hasLength(1), reason: why);
      expect(vanilla.single.downloads.map((d) => d.url), everyElement(contains('Vanilla')),
          reason: 'the wrong download under the wrong mod.\n$why');
      expect(newDrones.single.downloads.map((d) => d.url), everyElement(contains('New%20Drones')),
          reason: 'the wrong download under the wrong mod.\n$why');
    });

    test('Galactic Constellate is one mod offered as two builds, one per game version', () async {
      final answer = await readDiscord('1359352557348065311');
      if (answer == null) return;
      final why = describe(answer);

      final mains = answer.mods.where((m) => m.role == LlmModRole.main).toList();
      expect(mains, hasLength(1),
          reason: 'a 0.98 build and a 0.97 build of one mod are not two mods.\n$why');
      expect(allDownloadUrls(answer), containsAll([contains('0.98.zip'), contains('0.97.zip')]), reason: why);
      final needs = (mains.single.extras?.needs ?? const []).map(flatten).toList();
      expect(needs, containsAll(['lazylib', 'magiclib']), reason: why);
      expect(mains.single.extras?.canAdd, SaveAnswer.yes,
          reason: 'the post says "Safe to add mid-save".\n$why');
      expect(mains.single.extras?.canRemove, SaveAnswer.no,
          reason: 'the post says it "cannot be removed".\n$why');
    });

    test("Eridani Combine needs BoxUtil, and BoxUtil's download is not Eridani's", () async {
      // The announcement links the BoxUtil build it needs. BoxUtil is a mod of
      // its own with its own thread, so it must not become a second main mod
      // here, and its zip must not be offered as Eridani Combine's download.
      final answer = await readDiscord('1447000749992312953');
      if (answer == null) return;
      final why = describe(answer);

      final mains = answer.mods.where((m) => m.role == LlmModRole.main).toList();
      expect(mains, hasLength(1), reason: why);
      final eridani = mains.single;
      expect(nameHolds(eridani.name, 'Eridani Combine'), isTrue, reason: why);
      expect(eridani.downloads.map((d) => d.url), contains(contains('EridaniCombine1.0.3.6.zip')), reason: why);
      expect(eridani.downloads.map((d) => d.url), isNot(contains(contains('BoxUtil.zip'))), reason: why);
      expect((eridani.extras?.needs ?? const []).map(flatten), contains('boxutil'), reason: why);
    });

    test('Wide Horizons keeps the version its announcement gives, not an older patch note', () async {
      // The announcement was edited up to 1.3.0g; the messages after it are the
      // older 1.2.2 patch notes. "Newest message" is not the same as "newest
      // version".
      final answer = await readDiscord('1403520779907498095');
      if (answer == null) return;
      final why = describe(answer);

      final mains = answer.mods.where((m) => m.role == LlmModRole.main).toList();
      expect(mains, hasLength(1), reason: why);
      final mod = mains.single;
      expect(mod.extras?.version, '1.3.0g', reason: why);
      final needs = (mod.extras?.needs ?? const []).map(flatten).toList();
      expect(needs, containsAll(['lunalib', 'graphicslib']), reason: why);
      final notes = mod.extras?.updateNotes ?? const <LlmUpdateNote>[];
      expect(notes.any((n) => n.answer == SaveAnswer.no), isTrue,
          reason: 'the post says 1.3.x is not save-compatible with 1.2.x.\n$why');
    });

    test('Hiver Swarm reads its newest update message as the current version', () async {
      // Nine messages: the announcement, then one per release, the last being
      // "v1.1.7 - Save compatible" with its changes.
      final answer = await readDiscord('1203417843732058202');
      if (answer == null) return;
      final why = describe(answer);

      final mains = answer.mods.where((m) => m.role == LlmModRole.main).toList();
      expect(mains, hasLength(1), reason: why);
      final mod = mains.single;
      expect(mod.extras?.version, '1.1.7', reason: why);
      final notes = mod.extras?.updateNotes ?? const <LlmUpdateNote>[];
      expect(notes.where((n) => n.version == '1.1.7').map((n) => n.answer), contains(SaveAnswer.yes),
          reason: 'the 1.1.7 message says "Save compatible".\n$why');
      expect((mod.extras?.supportLinks ?? const []).map((l) => l.url), contains(contains('ko-fi.com')),
          reason: why);
    });

    test('TriOS on Discord is one tool with a download for each system', () async {
      final answer = await readDiscord('1355300468968001586');
      if (answer == null) return;
      final why = describe(answer);

      expect(answer.isMod, isTrue, reason: why);
      expect(answer.mods, hasLength(1), reason: 'three builds of one program are one entry.\n$why');
      final trios = answer.mods.single;
      expect(trios.isTool, isTrue, reason: 'a launcher runs beside the game.\n$why');
      expect(trios.downloads.map((d) => d.url),
          containsAll([contains('TriOS-Windows.zip'), contains('TriOS-Linux.zip'), contains('TriOS-MacOS.zip')]),
          reason: why);
      expect(trios.extras?.sourceCode, contains('github.com/wispborne/TriOS'), reason: why);
    });

    test('the Library of Ruina pack keeps its optional extra pack off its own download', () async {
      // One portrait pack, plus a "Distortions" pack offered as a separate
      // download. The main pack's download must be its own zip only.
      final answer = await readDiscord('1321884585096777840');
      if (answer == null) return;
      final why = describe(answer);

      final mains = answer.mods.where((m) => m.role == LlmModRole.main).toList();
      final pack = mains.firstWhere((m) => m.downloads.any((d) => d.url.contains('LoR_portraits_1.1.0.zip')),
          orElse: () => throw TestFailure('no mod carries the main pack\'s download.\n$why'));
      expect(pack.downloads.map((d) => d.url), isNot(contains(contains('distortion'))), reason: why);
      expect(pack.extras?.version, '1.1.0', reason: why);
    });

    test('the channel\'s example post is not a mod', () async {
      // The pinned template the channel asks authors to copy: a made-up mod
      // with a made-up download. Listing it would publish a page for nothing.
      final answer = await readDiscord('1203053249377079297');
      if (answer == null) return;
      final why = describe(answer);

      expect(!answer.isMod || answer.mods.every((m) => m.downloads.isEmpty), isTrue,
          reason: 'this is a template for authors, not a release.\n$why');
    });

    test('Gamma Wars is one mod, with its UNGP rules as an add-on', () async {
      // The recorded threads hold no announcement of two independent mods. This
      // is the nearest shape: two downloads, one of which is an add-on.
      final answer = await readDiscord('1247514078101114911');
      if (answer == null) return;
      final why = describe(answer);

      final mains = answer.mods.where((m) => m.role == LlmModRole.main).toList();
      expect(mains, hasLength(1), reason: why);
      expect(mains.single.downloads.map((d) => d.url), contains(contains('Gamma_Legion.1.0.zip')),
          reason: why);
      final ungp = answer.mods.where((m) => m.downloads.any((d) => d.url.contains('UNGP'))).toList();
      expect(ungp, hasLength(1), reason: why);
      expect(ungp.single.role, isNot(LlmModRole.main),
          reason: 'the UNGP rules need the faction mod, so they are its add-on.\n$why');
    });
  });

  group('a thread that is not a mod', () {
    test('a question thread (34645) is not a mod release', () async {
      final answer = await read(34645);
      if (answer == null) return;
      final why = describe(answer);

      expect(answer.isMod, isFalse,
          reason: 'this thread asks "Any mods with swappable modules?" — it '
              'offers nothing to download.\n$why');
      expect(answer.mods, isEmpty, reason: why);
    });
  });
}
