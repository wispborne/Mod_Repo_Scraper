/*
 * This file is distributed under the GPLv3. An informal description follows:
 * - Anyone can copy, modify and distribute this software as long as the other points are followed.
 * - You must include the license and copyright notice with each and every distribution.
 * - You may use this software for commercial purposes.
 * - If you modify it, you must indicate changes made to the code.
 * - Any modifications of this code base MUST be distributed with the same license, GPLv3.
 * - This software is provided without warranty.
 * - The software author or license can not be held liable for any damages inflicted by the software.
 * The full license is available from <https://www.gnu.org/licenses/gpl-3.0.txt>.
 */

import 'package:mod_repo_scraper/timber/ktx/timber_kt.dart' as timber;
import 'package:mod_repo_scraper/utilities/console_progress_bar.dart';
import 'package:mod_repo_scraper/utilities/parallel_map.dart';

import 'debug/merge_debug_collector.dart';
import 'debug/merge_debug_data.dart';
import 'main_repo_scraper.dart';
import 'mod_repo_utils.dart';
import 'scraped_mod.dart';
import 'version.dart';

class ModMerger {
  Future<List<ScrapedMod>> merge(
    List<ScrapedMod> mods, {
    bool keepAllGameVersionsFromSameSource = false,
    MergeDebugCollector? debugCollector,
  }) async {
    final startTime = DateTime.now();

    final summary = StringBuffer();

    final sortedMods = List<ScrapedMod>.from(mods)..sort((a, b) => a.name.compareTo(b.name));
    final preprocessedMods = _preprocessMods(sortedMods);
    debugCollector?.setInputCount(preprocessedMods.length);

    var stepStartTime = DateTime.now();
    final dedupedInput = await _dropForumLinksToOtherMods(
      _removeDuplicateInputs(preprocessedMods, debugCollector: debugCollector),
    );
    debugCollector?.addTiming('Pre-dedup', DateTime.now().difference(stepStartTime).inMilliseconds);
    debugCollector?.setAfterPreDedupCount(dedupedInput.length);
    timber.i(
        message: () =>
            "Pre-dedup: removed ${preprocessedMods.length - dedupedInput.length} duplicate inputs (${preprocessedMods.length} -> ${dedupedInput.length}).");

    timber.i(message: () => "Grouping ${dedupedInput.length} mods by similarity...");
    stepStartTime = DateTime.now();

    // Build indexes for fast candidate generation instead of O(n²) pairwise comparison.
    final cleanedNames = <int, String?>{};
    final strippedNames = <int, String?>{};
    final forumTopicIds = <int, String?>{};
    final topicBuckets = <String, List<int>>{};
    final nameBuckets = <String, List<int>>{};
    final trigramIndex = <String, Set<int>>{};

    for (var i = 0; i < dedupedInput.length; i++) {
      final mod = dedupedInput[i];

      final cleanName = _prepForMatching(mod.name);
      cleanedNames[i] = cleanName;
      strippedNames[i] = _prepForMatching(stripVersionNoise(mod.name));

      final topicId = extractForumTopicId(mod.getUrls()[ModUrlType.Forum]);
      forumTopicIds[i] = topicId;

      if (topicId != null) {
        topicBuckets.putIfAbsent(topicId, () => []).add(i);
      }

      if (cleanName != null) {
        nameBuckets.putIfAbsent(cleanName, () => []).add(i);

        if (cleanName.length >= 3) {
          for (var t = 0; t <= cleanName.length - 3; t++) {
            final trigram = cleanName.substring(t, t + 3);
            trigramIndex.putIfAbsent(trigram, () => {}).add(i);
          }
        }
      }
    }

    // Check each pair of similar-looking mods once, and join matches into
    // shared groups. Joining carries over: when an old thread and a new thread
    // both match a third entry, all three end up in one group. It also means a
    // mod can only ever be in one group — the old one-pass approach could put
    // a mod that started one group into a later group as well, publishing the
    // same mod twice.
    final groupOf = List<int>.generate(dedupedInput.length, (i) => i);

    int findGroup(int i) {
      var root = i;
      while (groupOf[root] != root) {
        root = groupOf[root];
      }
      // Point everything on the path straight at the root to keep lookups fast.
      var current = i;
      while (groupOf[current] != root) {
        final next = groupOf[current];
        groupOf[current] = root;
        current = next;
      }
      return root;
    }

    void joinGroups(int a, int b) {
      groupOf[findGroup(a)] = findGroup(b);
    }

    final authorNames = List<List<String>>.generate(
      dedupedInput.length,
      (i) => _authorMatchNames(dedupedInput[i]),
    );

    // Matches found, remembered by their lower-index side for the debug view.
    final debugPairEntries = debugCollector != null ? <(int, GroupMatchEntry)>[] : null;

    final groupingBar =
        ConsoleProgressBar.start('Merging mods', dedupedInput.length);
    for (var index = 0; index < dedupedInput.length; index++) {
      groupingBar.update(index + 1);

      final outerLoopMod = dedupedInput[index];
      final outer = cleanedNames[index];
      final outerTopicId = forumTopicIds[index];

      // Gather candidate indices from indexes.
      final candidates = <int>{};

      // Candidates from forum topic bucket.
      if (outerTopicId != null) {
        candidates.addAll(topicBuckets[outerTopicId] ?? []);
      }

      // Candidates from exact name bucket.
      if (outer != null) {
        candidates.addAll(nameBuckets[outer] ?? []);

        // Candidates from trigram overlap.
        if (outer.length >= 3) {
          final trigramHits = <int, int>{};
          for (var t = 0; t <= outer.length - 3; t++) {
            final trigram = outer.substring(t, t + 3);
            for (final candidateIdx in trigramIndex[trigram] ?? <int>{}) {
              trigramHits[candidateIdx] = (trigramHits[candidateIdx] ?? 0) + 1;
            }
          }
          // Only consider candidates sharing >= 40% of the shorter name's
          // trigrams, so a short name against a long one is judged by the
          // short one — the same answer no matter which side asks.
          final outerTrigramCount = outer.length - 2;
          for (final entry in trigramHits.entries) {
            final otherName = cleanedNames[entry.key];
            if (otherName == null || otherName.length < 3) continue;
            final otherTrigramCount = otherName.length - 2;
            final shorterTrigramCount =
                outerTrigramCount < otherTrigramCount ? outerTrigramCount : otherTrigramCount;
            if (entry.value >= shorterTrigramCount * 0.4) {
              candidates.add(entry.key);
            }
          }
        }
      }

      // Each pair is checked once, from its lower-index side.
      candidates.removeWhere((idx) => idx <= index);

      for (final candidateIdx in candidates) {
        final innerLoopMod = dedupedInput[candidateIdx];
        final inner = cleanedNames[candidateIdx];

        if (outer == null || inner == null) continue;

        // --- First reading: names as scraped ---
        final bestNameResult = await ModRepoUtils.compareToFindBestMatch(
          leftList: [outer],
          rightList: [inner],
        );
        final scrapedRatio = _nameLengthRatio(outer, inner);
        final scrapedNamePasses = bestNameResult.isMatch && scrapedRatio >= 0.85;

        // --- Second reading: version-stripped names ---
        final outerStripped = strippedNames[index];
        final innerStripped = strippedNames[candidateIdx];
        MatchResult? strippedNameResult;
        double? strippedRatio;
        var strippedNamePasses = false;

        if (!scrapedNamePasses &&
            outerStripped != null &&
            innerStripped != null &&
            (outerStripped != outer || innerStripped != inner)) {
          strippedNameResult = await ModRepoUtils.compareToFindBestMatch(
            leftList: [outerStripped],
            rightList: [innerStripped],
          );
          strippedRatio = _nameLengthRatio(outerStripped, innerStripped);
          strippedNamePasses = strippedNameResult.isMatch && strippedRatio >= 0.85;
        }

        final nameMatchPasses = scrapedNamePasses || strippedNamePasses;

        final bestAuthorsResult = await ModRepoUtils.compareToFindBestMatch(
          leftList: authorNames[index],
          rightList: authorNames[candidateIdx],
        );

        final innerTopicId = forumTopicIds[candidateIdx];
        final doForumLinksMatch = outerTopicId != null &&
            outerTopicId == innerTopicId &&
            _namesLookRelated(outerLoopMod.name, innerLoopMod.name, outer, inner);

        final doNameAndAuthorMatch = nameMatchPasses && bestAuthorsResult.isMatch;

        final isMatch = doNameAndAuthorMatch || doForumLinksMatch;

        if (doNameAndAuthorMatch) {
          timber.d(message: () => "Matched names (${strippedNamePasses ? 'stripped' : 'scraped'}) and authors $bestAuthorsResult.");
        }

        if (doForumLinksMatch) {
          timber.d(message: () => "Matching forum topic id for ${outerLoopMod.name} and ${innerLoopMod.name}: $outerTopicId.");
        }

        if (isMatch) {
          joinGroups(index, candidateIdx);

          if (debugPairEntries != null) {
            final reasons = <GroupMatchReason>{};
            if (doNameAndAuthorMatch) {
              reasons.add(strippedNamePasses
                  ? GroupMatchReason.strippedNameAndAuthor
                  : GroupMatchReason.nameAndAuthor);
            }
            if (doForumLinksMatch) reasons.add(GroupMatchReason.forumUrl);
            debugPairEntries.add((
              index,
              GroupMatchEntry(
                outerMod: outerLoopMod,
                innerMod: innerLoopMod,
                reasons: reasons,
                nameScore: bestNameResult.isMatch ? bestNameResult.score : null,
                authorScore: bestAuthorsResult.isMatch ? bestAuthorsResult.score : null,
                nameLengthRatio: scrapedRatio,
                matchedForumTopicId: doForumLinksMatch ? outerTopicId : null,
                outerStrippedName: stripVersionNoise(outerLoopMod.name),
                innerStrippedName: stripVersionNoise(innerLoopMod.name),
                strippedNameScore: strippedNameResult?.isMatch == true ? strippedNameResult!.score : null,
                strippedNameLengthRatio: strippedRatio,
              )
            ));
          }
        }
      }
    }

    groupingBar.finish();

    // Collect the joined groups, keeping the input order.
    final memberIndexesByRoot = <int, List<int>>{};
    for (var i = 0; i < dedupedInput.length; i++) {
      memberIndexesByRoot.putIfAbsent(findGroup(i), () => []).add(i);
    }

    final groupedMods = <List<ScrapedMod>>[];
    final groupIndexByRoot = <int, int>{};
    for (final entry in memberIndexesByRoot.entries) {
      groupIndexByRoot[entry.key] = groupedMods.length;
      groupedMods.add(entry.value.map((i) => dedupedInput[i]).toList());
    }

    if (debugPairEntries != null) {
      final entriesByGroup = <int, List<GroupMatchEntry>>{};
      for (final (memberIndex, entry) in debugPairEntries) {
        entriesByGroup.putIfAbsent(groupIndexByRoot[findGroup(memberIndex)]!, () => []).add(entry);
      }
      for (var g = 0; g < groupedMods.length; g++) {
        debugCollector!.recordGroup(DebugModGroup(
          groupIndex: g,
          members: groupedMods[g],
          matchEntries: entriesByGroup[g] ?? [],
        ));
      }
    }

    final msg = "Grouped ${mods.length} mods by similarity, created ${groupedMods.length} groups.";
    timber.i(message: () => msg);
    timber.i(message: () => "Grouping completed in ${DateTime.now().difference(stepStartTime).inMilliseconds}ms.");
    debugCollector?.setGroupsCreated(groupedMods.length);
    debugCollector?.addTiming('Grouping', DateTime.now().difference(stepStartTime).inMilliseconds);
    summary.writeln(msg);

    if (MainRepoScraper.verboseOutput) {
      for (final modGroup in groupedMods) {
        timber.i(message: () {
          final buffer = StringBuffer();
          buffer.writeln("Mod group of ${modGroup.length}:");
          for (final mod in modGroup) {
            final sourceUrl = switch (mod.getSources().firstOrNull) {
              ModSource.Index => mod.getUrls()[ModUrlType.Forum]?.toString(),
              ModSource.ModdingSubforum => mod.getUrls()[ModUrlType.Forum]?.toString(),
              ModSource.Discord => mod.getUrls()[ModUrlType.Discord]?.toString(),
              ModSource.NexusMods => mod.getUrls()[ModUrlType.NexusMods]?.toString(),
              null => "no source",
            };
            buffer.writeln("  '${mod.name}' by '${mod.getAuthors().join(', ')}' from ${mod.sources} ($sourceUrl)");
          }
          return buffer.toString();
        });
      }
    }

    // When not keeping all game versions from the same source, deduplicate
    // each group so only the newest game version per source survives.
    stepStartTime = DateTime.now();
    final dedupedGroups = keepAllGameVersionsFromSameSource
        ? groupedMods
        : groupedMods.map((group) => _deduplicateSameSourceByGameVersion(group, debugCollector: debugCollector)).toList();
    timber.i(message: () => "Deduplication completed in ${DateTime.now().difference(stepStartTime).inMilliseconds}ms.");
    debugCollector?.addTiming('Same-source dedup', DateTime.now().difference(stepStartTime).inMilliseconds);

    timber.i(message: () => "Merging ${mods.length} mods by similarity...");
    stepStartTime = DateTime.now();
    final nonEmptyGroups = dedupedGroups.where((group) => group.isNotEmpty).toList();

    final List<ScrapedMod> mergedMods;
    if (debugCollector != null) {
      // Debug path: sequential to capture step-by-step merge decisions.
      mergedMods = [];
      for (var i = 0; i < nonEmptyGroups.length; i++) {
        final (result, decision) = _mergeSimilarModsWithDebug(nonEmptyGroups[i], i);
        mergedMods.add(result);
        debugCollector.recordMergeDecision(decision);
      }
    } else {
      mergedMods = await nonEmptyGroups.parallelMap((modGroup) async => _mergeSimilarMods(modGroup));
    }
    timber.i(message: () => "Merging step completed in ${DateTime.now().difference(stepStartTime).inMilliseconds}ms.");
    debugCollector?.addTiming('Merge', DateTime.now().difference(stepStartTime).inMilliseconds);

    final msg2 =
        "Merged ${mods.length} mods by similarity. ${mods.length - mergedMods.length} mods were duplicates, resulting in a total of ${mergedMods.length} merged mods.";
    timber.i(message: () => msg2);
    summary.writeln(msg2);

    stepStartTime = DateTime.now();
    final cleanedMods = _removeInvalidMods(mergedMods, debugCollector: debugCollector);
    timber.i(message: () => "Validation completed (removed ${mergedMods.length - cleanedMods.length} invalid mods) in ${DateTime.now().difference(stepStartTime).inMilliseconds}ms.");
    debugCollector?.addTiming('Validation', DateTime.now().difference(stepStartTime).inMilliseconds);

    stepStartTime = DateTime.now();
    final tidiedMods = _tidyAuthorNames(cleanedMods);
    debugCollector?.addTiming('Author names', DateTime.now().difference(stepStartTime).inMilliseconds);

    for (final mod in tidiedMods) {
      timber.v(message: () => mod.toString());
    }

    timber.i(message: () => summary.toString());
    timber.i(
        message: () =>
            "Total time to merge ${mods.length} mods: ${DateTime.now().difference(startTime).inMilliseconds}ms.");

    debugCollector?.setFinalCount(tidiedMods.length);
    debugCollector?.setFinalOutput(tidiedMods);
    debugCollector?.addTiming('Total', DateTime.now().difference(startTime).inMilliseconds);

    return tidiedMods;
  }

  /// Last pass: make sure each mod names each of its authors once.
  ///
  /// Merging brings the same person in from every source at once, so Nexerelin
  /// came out credited to "Histidine", "Histidine, Zaphide" and "histidine_my"
  /// — two people written three ways. This runs at the very end, so matching
  /// and grouping still see every spelling a source gave us.
  List<ScrapedMod> _tidyAuthorNames(List<ScrapedMod> mods) {
    var changedCount = 0;

    final result = mods.map((mod) {
      final before = mod.getAuthors();
      final after = ModRepoUtils.tidyAuthorNames(before);
      if (_sameNames(before, after)) return mod;

      changedCount++;
      timber.d(
          message: () => "Tidied the authors of '${mod.name}': "
              "'${before.join("', '")}' -> '${after.join("', '")}'.");
      return mod.copyWith(authorsList: after);
    }).toList();

    timber.i(message: () => "Tidied the author names on $changedCount of ${mods.length} mods.");
    return result;
  }

  static bool _sameNames(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Merges two mods, determining priority, and returns the result along with
  /// the priority reason and direction.
  (ScrapedMod, MergePriorityReason, bool) _mergeTwoMods(ScrapedMod mergedMod, ScrapedMod modToFoldIn) {
    if (mergedMod == modToFoldIn) return (mergedMod, MergePriorityReason.fallback, false);

    // Mods from the Index always have priority in case of conflicts.
    final MergePriorityReason reason;
    final bool doesNewModHavePriority;
    if (mergedMod.getSources().contains(ModSource.Index)) {
      timber.d(
          message: () =>
              "Merging '${modToFoldIn.name}' from '${modToFoldIn.getAuthors()}' with higher priority '${mergedMod.name}' from '${mergedMod.getAuthors()}' because of Index source.");
      doesNewModHavePriority = false;
      reason = MergePriorityReason.indexSource;
    } else if (modToFoldIn.getSources().contains(ModSource.Index)) {
      timber.d(
          message: () =>
              "Merging '${mergedMod.name}' from '${mergedMod.getAuthors()}' with higher priority '${modToFoldIn.name}' from '${modToFoldIn.getAuthors()}' because of Index source.");
      doesNewModHavePriority = true;
      reason = MergePriorityReason.indexSource;
    } else if (modToFoldIn.gameVersionReq != null &&
        mergedMod.gameVersionReq != null &&
        modToFoldIn.gameVersionReq != mergedMod.gameVersionReq) {
      final isFoldInHigher = Version.parse(modToFoldIn.gameVersionReq!) > Version.parse(mergedMod.gameVersionReq!);
      if (isFoldInHigher) {
        timber.d(
            message: () =>
                "Merging '${mergedMod.name}' from '${mergedMod.getAuthors()}' with higher priority '${modToFoldIn.name}' from '${modToFoldIn.getAuthors()}' because of game version.");
      } else {
        timber.d(
            message: () =>
                "Merging '${modToFoldIn.name}' from '${modToFoldIn.getAuthors()}' with higher priority '${mergedMod.name}' from '${mergedMod.getAuthors()}' because of game version.");
      }
      doesNewModHavePriority = isFoldInHigher;
      reason = MergePriorityReason.higherGameVersion;
    } else {
      timber.d(
          message: () =>
              "Merging '${modToFoldIn.name}' from '${modToFoldIn.getAuthors()}' with higher priority '${mergedMod.name}' from '${mergedMod.getAuthors()}' because of fallback.");
      doesNewModHavePriority = false;
      reason = MergePriorityReason.fallback;
    }

    final mergedAuthorsList = <String>{
      ...mergedMod.getAuthors(),
      ...modToFoldIn.getAuthors(),
    }.map((a) => a.trim()).where((a) => a.isNotEmpty).toList()
      ..sort();

    final mergedUrls = Map<ModUrlType, String>.from(mergedMod.getUrls())..addAll(modToFoldIn.getUrls());

    final mergedSources = <ModSource>{
      ...modToFoldIn.getSources(),
      ...mergedMod.getSources(),
    }.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final mergedCategories = <String>{
      ...modToFoldIn.getCategories(),
      ...mergedMod.getCategories(),
    }.toList()
      ..sort();

    final mergedImages = <String, Image>{
      ...modToFoldIn.getImages(),
      ...mergedMod.getImages(),
    };

    final result = ScrapedMod(
      name: _chooseBest(
            left: mergedMod.name.trim().isEmpty ? null : mergedMod.name,
            right: modToFoldIn.name.trim().isEmpty ? null : modToFoldIn.name,
            doesRightHavePriority: doesNewModHavePriority,
          ) ??
          "",
      summary: _chooseBest(
        left: mergedMod.summary?.trim().isEmpty == true ? null : mergedMod.summary,
        right: modToFoldIn.summary?.trim().isEmpty == true ? null : modToFoldIn.summary,
        doesRightHavePriority: doesNewModHavePriority,
      ),
      description: _chooseBest(
        left: mergedMod.description?.trim().isEmpty == true ? null : mergedMod.description,
        right: modToFoldIn.description?.trim().isEmpty == true ? null : modToFoldIn.description,
        doesRightHavePriority: doesNewModHavePriority,
      ),
      modVersion: _chooseBest(
        left: mergedMod.modVersion?.trim().isEmpty == true ? null : mergedMod.modVersion,
        right: modToFoldIn.modVersion?.trim().isEmpty == true ? null : modToFoldIn.modVersion,
        doesRightHavePriority: doesNewModHavePriority,
      ),
      gameVersionReq: _chooseBest(
        left: mergedMod.gameVersionReq?.trim().isEmpty == true ? null : mergedMod.gameVersionReq,
        right: modToFoldIn.gameVersionReq?.trim().isEmpty == true ? null : modToFoldIn.gameVersionReq,
        doesRightHavePriority: doesNewModHavePriority,
      ),
      authorsList: mergedAuthorsList,
      urls: mergedUrls,
      sources: mergedSources,
      categories: mergedCategories,
      images: mergedImages,
      dateTimeCreated: _chooseBest(
        left: mergedMod.dateTimeCreated,
        right: modToFoldIn.dateTimeCreated,
        doesRightHavePriority: doesNewModHavePriority,
      ),
      dateTimeEdited: _chooseBest(
        left: mergedMod.dateTimeEdited,
        right: modToFoldIn.dateTimeEdited,
        doesRightHavePriority: doesNewModHavePriority,
      ),
    );

    return (result, reason, doesNewModHavePriority);
  }

  ScrapedMod _mergeSimilarMods(List<ScrapedMod> mods) {
    return mods.reduce((mergedMod, modToFoldIn) {
      final (result, _, _) = _mergeTwoMods(mergedMod, modToFoldIn);
      return result;
    });
  }

  (ScrapedMod, MergeDecision) _mergeSimilarModsWithDebug(List<ScrapedMod> mods, int groupIndex) {
    final steps = <MergeStepEntry>[];
    var accumulated = mods.first;
    for (final mod in mods.skip(1)) {
      final (result, reason, rightHasPriority) = _mergeTwoMods(accumulated, mod);
      steps.add(MergeStepEntry(
        left: accumulated,
        right: mod,
        reason: reason,
        doesRightHavePriority: rightHasPriority,
        result: result,
      ));
      accumulated = result;
    }
    return (
      accumulated,
      MergeDecision(
        groupIndex: groupIndex,
        inputMods: mods,
        steps: steps,
        finalResult: accumulated,
      ),
    );
  }

  /// Within a mod group, for each source that appears more than once, keep
  /// only the entry with the highest game version and discard the rest.
  List<ScrapedMod> _deduplicateSameSourceByGameVersion(
    List<ScrapedMod> group, {
    MergeDebugCollector? debugCollector,
  }) {
    if (group.length <= 1) return group;

    // Build a map of source -> list of mods from that source.
    final bySource = <ModSource, List<ScrapedMod>>{};
    for (final mod in group) {
      for (final source in mod.getSources()) {
        bySource.putIfAbsent(source, () => []).add(mod);
      }
    }

    // Collect mods that should be removed (lower game version duplicates).
    final modsToRemove = <ScrapedMod>{};
    for (final entry in bySource.entries) {
      final modsForSource = entry.value;
      if (modsForSource.length <= 1) continue;

      // Find the mod with the highest game version for this source.
      ScrapedMod best = modsForSource.first;
      for (final mod in modsForSource.skip(1)) {
        final bestVersion = best.gameVersionReq;
        final modVersion = mod.gameVersionReq;
        if (bestVersion == null || bestVersion.isEmpty) {
          best = mod;
        } else if (modVersion != null &&
            modVersion.isNotEmpty &&
            Version.parse(modVersion) > Version.parse(bestVersion)) {
          best = mod;
        }
      }

      // Mark all others from this source for removal.
      for (final mod in modsForSource) {
        if (!identical(mod, best)) {
          // Safety: verify names are similar enough before discarding.
          // Prevents data loss if different mods were incorrectly grouped.
          final bestName = _prepForMatching(best.name);
          final modName = _prepForMatching(mod.name);
          if (bestName != null && modName != null) {
            final scrapedOk = _nameLengthRatio(bestName, modName) >= 0.70;
            final bestStripped = _prepForMatching(stripVersionNoise(best.name));
            final modStripped = _prepForMatching(stripVersionNoise(mod.name));
            final strippedOk = bestStripped != null &&
                modStripped != null &&
                _nameLengthRatio(bestStripped, modStripped) >= 0.70;
            if (!scrapedOk && !strippedOk) {
              final safetyRatio = _nameLengthRatio(bestName, modName);
              timber.w(
                  message: () =>
                      "Dedup safety: NOT discarding '${mod.name}' in favor of '${best.name}' — names too different (${(safetyRatio * 100).toStringAsFixed(0)}% length ratio).");
              debugCollector?.recordSameSourceDedup(SameSourceDedupEntry(
                kept: best,
                discarded: mod,
                source: entry.key,
                keptGameVersion: best.gameVersionReq,
                discardedGameVersion: mod.gameVersionReq,
                wasSafetyBlocked: true,
                nameLengthRatio: safetyRatio,
              ));
              continue;
            }
          }

          timber.d(
              message: () =>
                  "Dedup: discarding '${mod.name}' (${mod.gameVersionReq}) from ${entry.key} in favor of '${best.name}' (${best.gameVersionReq}).");
          debugCollector?.recordSameSourceDedup(SameSourceDedupEntry(
            kept: best,
            discarded: mod,
            source: entry.key,
            keptGameVersion: best.gameVersionReq,
            discardedGameVersion: mod.gameVersionReq,
          ));
          modsToRemove.add(mod);
        }
      }
    }

    return group.where((mod) => !modsToRemove.contains(mod)).toList();
  }

  T? _chooseBest<T>({required T? left, required T? right, required bool doesRightHavePriority}) {
    if (left != null && right != null) {
      return doesRightHavePriority ? right : left;
    } else if (doesRightHavePriority) {
      return right ?? left;
    } else {
      return left ?? right;
    }
  }

  List<ScrapedMod> _preprocessMods(List<ScrapedMod> mods) {
    return mods.map((mod) {
      return ScrapedMod(
        name: mod.name.trim(),
        summary: mod.summary?.trim(),
        description: mod.description?.trim(),
        modVersion: mod.modVersion?.trim(),
        gameVersionReq: mod.gameVersionReq?.trim(),
        authorsList: mod.authorsList.map((a) => a.trim()).toList(),
        urls: mod.urls,
        sources: mod.sources,
        categories: mod.categories,
        images: mod.images,
        dateTimeCreated: mod.dateTimeCreated,
        dateTimeEdited: mod.dateTimeEdited,
      );
    }).toList();
  }

  List<ScrapedMod> _removeInvalidMods(
    List<ScrapedMod> mods, {
    MergeDebugCollector? debugCollector,
  }) {
    return mods.where((mod) {
      final hasLink = mod.urls?.isNotEmpty == true;
      if (!hasLink) {
        timber.i(message: () => "Removing mod without any links: '${mod.name}' by '${mod.getAuthors()}'.");
        debugCollector?.recordValidationRemoval(ValidationRemoval(mod: mod, reason: 'no URLs'));
      }

      final hasName = mod.name.trim().isNotEmpty;
      if (!hasName) {
        timber.i(
            message: () => "Removing mod without a name: mod by '${mod.getAuthors()}' with links ${mod.getUrls()}.");
        debugCollector?.recordValidationRemoval(ValidationRemoval(mod: mod, reason: 'no name'));
      }

      return hasLink && hasName;
    }).toList();
  }

  String? _prepForMatching(String str) {
    final cleaned = str.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return cleaned.isEmpty ? null : cleaned;
  }

  static double _nameLengthRatio(String a, String b) {
    final shorter = a.length < b.length ? a.length : b.length;
    final longer = a.length > b.length ? a.length : b.length;
    return shorter / longer;
  }

  /// Whether two names look like versions of the same mod name.
  ///
  /// True when most of the shorter cleaned name's three-letter pieces appear
  /// in the longer one — which covers version suffixes ("edshipyard" in
  /// "edshipyardsrc"), renames that keep the old name ("red" in
  /// "oculianarmadaakared"), and small typos ("cooperation" next to
  /// "corporation") — or when one name is the other's initials ("SCVE" for
  /// "Ship Catalogue/Variant Editor"). "Bushi" against "Hiigaran Descendants"
  /// shares nothing and fails.
  static bool _namesLookRelated(String rawA, String rawB, String cleanedA, String cleanedB) {
    final shorter = cleanedA.length <= cleanedB.length ? cleanedA : cleanedB;
    final longer = cleanedA.length <= cleanedB.length ? cleanedB : cleanedA;
    if (shorter.length < 3) return longer.contains(shorter);

    var shared = 0;
    for (var t = 0; t <= shorter.length - 3; t++) {
      if (longer.contains(shorter.substring(t, t + 3))) shared++;
    }
    if (shared >= (shorter.length - 2) * 0.4) return true;

    final acronymA = _acronymOf(rawA);
    final acronymB = _acronymOf(rawB);
    return (acronymA.length >= 3 && cleanedB.startsWith(acronymA)) ||
        (acronymB.length >= 3 && cleanedA.startsWith(acronymB));
  }

  /// The initials of a name: first letter of each word, keeping short
  /// all-capitals words whole. "Another random SWP" gives "arswp".
  static String _acronymOf(String name) {
    final words = RegExp(r'[A-Za-z]+').allMatches(name).map((m) => m.group(0)!);
    final buffer = StringBuffer();
    for (final word in words) {
      final isAllCaps = word.length > 1 && word.length <= 5 && word == word.toUpperCase();
      buffer.write(isAllCaps ? word.toLowerCase() : word[0].toLowerCase());
    }
    return buffer.toString();
  }

  /// If a Discord/Nexus entry claims a forum thread we also scraped, and that
  /// thread is clearly a different mod (no name overlap, no author overlap),
  /// strip the forum link. Threads we never scraped are left alone.
  ///
  /// Much looser than grouping — only drops when the names share *nothing*.
  /// "Bultach 'Of Humanity.'" keeps its link to "Bultach Coalition" (shared
  /// trigrams); "-Moci ship pack-" loses its link to "Box Util" (zero shared).
  Future<List<ScrapedMod>> _dropForumLinksToOtherMods(List<ScrapedMod> mods) async {
    final threadsByTopicId = <String, ScrapedMod>{};
    for (final mod in mods) {
      if (!_isFromTheForum(mod)) continue;
      final topicId = extractForumTopicId(mod.getUrls()[ModUrlType.Forum]);
      if (topicId != null) threadsByTopicId.putIfAbsent(topicId, () => mod);
    }
    if (threadsByTopicId.isEmpty) return mods;

    final kept = <ScrapedMod>[];
    var droppedCount = 0;

    for (final mod in mods) {
      final urls = mod.getUrls();
      final topicId = extractForumTopicId(urls[ModUrlType.Forum]);
      final thread = topicId == null ? null : threadsByTopicId[topicId];

      if (_isFromTheForum(mod) || thread == null || await _couldBeTheSameMod(mod, thread)) {
        kept.add(mod);
        continue;
      }

      // The download page is often just the forum link repeated.
      final trimmedUrls = Map<ModUrlType, String>.from(urls)..remove(ModUrlType.Forum);
      if (extractForumTopicId(trimmedUrls[ModUrlType.DownloadPage]) == topicId) {
        trimmedUrls.remove(ModUrlType.DownloadPage);
      }

      droppedCount++;
      timber.i(
          message: () => "Dropped the forum link on '${mod.name}' "
              "(${mod.getSources().map((s) => s.name).join(", ")}): topic $topicId is "
              "'${thread.name}', a different mod.");
      kept.add(mod.copyWith(urls: trimmedUrls));
    }

    if (droppedCount > 0) {
      timber.i(message: () => "Dropped $droppedCount forum link(s) that pointed at another mod's thread.");
    }

    return kept;
  }

  static bool _isFromTheForum(ScrapedMod mod) =>
      mod.getSources().any((source) => source == ModSource.Index || source == ModSource.ModdingSubforum);

  /// Errs towards yes — only returns false when names share nothing *and* no
  /// author matches.
  Future<bool> _couldBeTheSameMod(ScrapedMod a, ScrapedMod b) async {
    final cleanedA = _prepForMatching(a.name);
    final cleanedB = _prepForMatching(b.name);
    if (cleanedA == null || cleanedB == null) return true;
    if (!_namesShareNothing(a.name, b.name, cleanedA, cleanedB)) return true;

    final authors = await ModRepoUtils.compareToFindBestMatch(
      leftList: _authorMatchNames(a),
      rightList: _authorMatchNames(b),
    );
    return authors.isMatch;
  }

  /// True when the two names share zero trigrams and neither is the other's
  /// initials. Much weaker than [_namesLookRelated] — that's on purpose, since
  /// this decides whether to *delete* a link, not whether to merge.
  static bool _namesShareNothing(String rawA, String rawB, String cleanedA, String cleanedB) {
    final shorter = cleanedA.length <= cleanedB.length ? cleanedA : cleanedB;
    final longer = cleanedA.length <= cleanedB.length ? cleanedB : cleanedA;
    // Too short to split into trigrams — can't tell, so say no.
    if (shorter.length < 3) return false;

    for (var t = 0; t <= shorter.length - 3; t++) {
      if (longer.contains(shorter.substring(t, t + 3))) return false;
    }

    // "SWP" shares no trigrams with "Ship and Weapon Pack" but is its initials.
    final acronymA = _acronymOf(rawA);
    final acronymB = _acronymOf(rawB);
    final initialsMatch = (acronymA.length >= 2 && cleanedB.startsWith(acronymA)) ||
        (acronymB.length >= 2 && cleanedA.startsWith(acronymB));
    return !initialsMatch;
  }

  /// All cleaned names an author credit can match under, including aliases.
  List<String> _authorMatchNames(ScrapedMod mod) {
    final names = <String>{};
    for (final author in mod.getAuthors()) {
      names.add(author);
      names.addAll(ModRepoUtils.splitAuthorNames(author));
    }
    for (final name in names.toList()) {
      names.addAll(ModRepoUtils.getOtherMatchingAliases(name));
    }
    return names.map(_prepForMatching).whereType<String>().toList();
  }

  /// Removes duplicate input entries that have the same cleaned name, source, and forum URL.
  /// Keeps the entry with the most data (more URLs, has description, etc.).
  List<ScrapedMod> _removeDuplicateInputs(
    List<ScrapedMod> mods, {
    MergeDebugCollector? debugCollector,
  }) {
    final seen = <String, ScrapedMod>{};
    for (final mod in mods) {
      final key = '${_prepForMatching(mod.name)}'
          '|${mod.getSources().map((s) => s.name).join(",")}'
          '|${extractForumTopicId(mod.getUrls()[ModUrlType.Forum]) ?? ""}';
      final existing = seen[key];
      if (existing == null) {
        seen[key] = mod;
      } else {
        // Keep the one with more data, or higher game version as tiebreaker.
        final existingRichness = _dataRichness(existing);
        final modRichness = _dataRichness(mod);
        if (modRichness > existingRichness) {
          seen[key] = mod;
          debugCollector?.recordPreDedupRemoval(PreDedupEntry(
            kept: mod,
            discarded: existing,
            reason: 'higher data richness',
            keptRichness: modRichness,
            discardedRichness: existingRichness,
          ));
        } else if (modRichness == existingRichness) {
          // Tiebreaker: prefer the higher game version.
          final existingVersion = existing.gameVersionReq;
          final modVersion = mod.gameVersionReq;
          if (existingVersion != null &&
              modVersion != null &&
              existingVersion.isNotEmpty &&
              modVersion.isNotEmpty &&
              Version.parse(modVersion) > Version.parse(existingVersion)) {
            seen[key] = mod;
            debugCollector?.recordPreDedupRemoval(PreDedupEntry(
              kept: mod,
              discarded: existing,
              reason: 'higher game version (tiebreaker)',
              keptRichness: modRichness,
              discardedRichness: existingRichness,
            ));
          } else {
            debugCollector?.recordPreDedupRemoval(PreDedupEntry(
              kept: existing,
              discarded: mod,
              reason: 'existing kept (equal or better)',
              keptRichness: existingRichness,
              discardedRichness: modRichness,
            ));
          }
        } else {
          debugCollector?.recordPreDedupRemoval(PreDedupEntry(
            kept: existing,
            discarded: mod,
            reason: 'existing has higher data richness',
            keptRichness: existingRichness,
            discardedRichness: modRichness,
          ));
        }
      }
    }
    return seen.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  int _dataRichness(ScrapedMod mod) {
    var score = 0;
    if (mod.summary?.isNotEmpty == true) score++;
    if (mod.description?.isNotEmpty == true) score++;
    if (mod.modVersion?.isNotEmpty == true) score++;
    if (mod.gameVersionReq?.isNotEmpty == true) score++;
    score += mod.getUrls().length;
    return score;
  }

  /// Extracts the topic ID from a Starsector forum URL for comparison.
  /// Handles http/https differences and trailing `.0` variations.
  /// Returns null if not a recognizable forum URL.
  static String? extractForumTopicId(String? url) {
    if (url == null || url.isEmpty) return null;
    final match = RegExp(r'topic=(\d+)').firstMatch(url);
    return match?.group(1);
  }
}

extension _FirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
