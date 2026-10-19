import 'forum_constants.dart';

/// Whether a scraped thread belongs in the bundle at all.
///
/// A thread is dropped only when **both** signals agree it is not a mod: the
/// LLM judged it a non-mod, and its title carries no game-version tag. A
/// version tag, a missing judgment (the LLM is off, has not reached this thread
/// yet, or bailed), or a positive call all keep the thread — so nothing is
/// dropped on the LLM's word alone.
///
/// A thread the forum's mod index lists ([inModIndex]) is always kept: the
/// index is the forum staff's own list of mods, which outranks the model. The
/// catalog reads the same rule, so an indexed mod with a plain title — "MOSS",
/// a tool the model once called a non-mod — keeps its page.
///
/// It lives here on its own because two places have to give the same answer:
/// `BundlePublisher`, which builds the bundle that goes out, and the viewer,
/// which builds the bundle that *would* go out so a run can be watched
/// mid-flight. A thread the two disagreed about would read as added or removed
/// on the changes page for as long as the run lasted.
bool keepThreadInBundle({
  required String title,
  required bool? llmSaidMod,
  bool inModIndex = false,
}) {
  if (inModIndex) return true;
  if (llmSaidMod != false) return true;
  return ForumConstants.gameVersionRegex.hasMatch(title);
}

/// Whether a thread gives the catalog a mod. Stricter than
/// [keepThreadInBundle], which still decides what the old bundle carries.
///
/// A thread the LLM judged a non-mod is kept only when the mod index lists it
/// or the rules found something to download in it ([hasDownload]). A game
/// version in the title no longer counts on its own: question threads carry
/// one too ("[0.98a] Null error using the Star Wars mod", topic 33546). So
/// two signals still have to agree before a thread is dropped — the LLM, and
/// a post with nothing to install.
///
/// On real data every thread this drops had no download at all: questions,
/// old threads marked "MOVED:" whose mod is published from its new thread,
/// and work-in-progress showcases.
bool keepThreadInCatalog({
  required String title,
  required bool? llmSaidMod,
  bool inModIndex = false,
  required bool hasDownload,
}) {
  if (!keepThreadInBundle(title: title, llmSaidMod: llmSaidMod, inModIndex: inModIndex)) return false;
  if (inModIndex) return true;
  if (llmSaidMod != false) return true;
  return hasDownload;
}
