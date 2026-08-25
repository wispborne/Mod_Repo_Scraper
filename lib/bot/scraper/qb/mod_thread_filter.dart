import 'forum_constants.dart';

/// Whether a scraped thread belongs in the bundle at all.
///
/// A thread is dropped only when **both** signals agree it is not a mod: the
/// LLM judged it a non-mod, and its title carries no game-version tag. A
/// version tag, a missing judgment (the LLM is off, has not reached this thread
/// yet, or bailed), or a positive call all keep the thread — so nothing is
/// dropped on the LLM's word alone.
///
/// It lives here on its own because two places have to give the same answer:
/// `BundlePublisher`, which builds the bundle that goes out, and the viewer,
/// which builds the bundle that *would* go out so a run can be watched
/// mid-flight. A thread the two disagreed about would read as added or removed
/// on the changes page for as long as the run lasted.
bool keepThreadInBundle({required String title, required bool? llmSaidMod}) {
  if (llmSaidMod != false) return true;
  return ForumConstants.gameVersionRegex.hasMatch(title);
}
