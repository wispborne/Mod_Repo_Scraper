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

import 'dart:io';
import 'dart:math';
import '../timber/ktx/timber_kt.dart' as timber;

extension PathExtensions on String {
  String? toPathOrNull() {
    try {
      return this;
    } catch (e) {
      timber.d(t: e, message: () => 'Failed to convert to path');
      return null;
    }
  }
}

extension FileSystemEntityExtensions on FileSystemEntity {
  bool exists() {
    return existsSync();
  }
}

extension ThrowableExtensions on Object {
  Object rootCause() {
    if (this is Error) {
      final error = this as Error;
      // Dart doesn't have a cause field, so just return this
      return this;
    }
    return this;
  }
}

extension StringExtensions on String {
  static String get empty => '';

  String? nullIfBlank() {
    return trim().isEmpty ? null : this;
  }
}

extension AnyExtensions on Object {
  bool equalsAny(List<Object> others) {
    return others.any((other) => this == other);
  }
}

extension StringEqualsExtensions on String {
  bool equalsAnyString(List<String> others, {bool ignoreCase = true}) {
    return others.any((other) => ignoreCase
        ? toLowerCase() == other.toLowerCase()
        : this == other);
  }
}

extension CollectionExtensions<T> on Iterable<T> {
  /// Returns items matching the predicate or, if none are matching, returns the original collection.
  Iterable<T> prefer(bool Function(T item) predicate) {
    final filtered = where(predicate).toList();
    return filtered.isEmpty ? this : filtered;
  }
}

extension NullableExtensions<T> on T? {
  List<T> asList() {
    return this == null ? [] : [this as T];
  }
}

extension DoubleExtensions on double {
  double makeFinite() {
    return isFinite ? this : 0.0;
  }
}

extension ListExtensions<T> on List<T> {
  /// Returns a list containing all elements except first [n] elements.
  List<T> skip(int n) => sublist(n);
}

extension DiffExtensions<T> on List<T> {
  DiffResult<T> diff<K>(List<T> newList, K Function(T item) keyFinder) {
    final cur = {for (var item in this) keyFinder(item): item};
    final newMap = {for (var item in newList) keyFinder(item): item};

    return DiffResult(
      removed: cur.entries
          .where((e) => !newMap.containsKey(e.key))
          .map((e) => e.value)
          .toList(),
      added: newMap.entries
          .where((e) => !cur.containsKey(e.key))
          .map((e) => e.value)
          .toList(),
    );
  }
}

class DiffResult<T> {
  final List<T> removed;
  final List<T> added;

  DiffResult({required this.removed, required this.added});
}

extension IterableExtensions on Iterable<Object> {
  String sIfPlural() => length == 1 ? '' : 's';
}

extension LongBytesExtensions on int {
  /// A megabyte is 8^6 bytes.
  double get bitsToMB => this / 8000000.0;

  /// A megabyte is 1^6 byte.
  double get bytesToMB => this / 1000000.0;

  /// 0.111 MB
  String get bytesAsReadableMB => '${bytesToMB.toStringAsFixed(3)} MB';

  /// 0.1 MB
  String get bytesAsShortReadableMB => '${bytesToMB.toStringAsFixed(2)} MB';
}

/// Time how long it takes to run [func].
T trace<T>(T Function() func, void Function(T result, int millis)? onFinished) {
  final stopwatch = Stopwatch()..start();
  final result = func();
  stopwatch.stop();
  if (onFinished != null) {
    onFinished(result, stopwatch.elapsedMilliseconds);
  }
  return result;
}

/// Return a string with a maximum length of [length] characters.
/// If there are more than [length] characters, then string ends with an ellipsis ("…").
extension StringEllipsis on String {
  String ellipsizeAfter(int length) {
    // The letters [iIl1] are slim enough to only count as half a character.
    var lengthMod = length;
    lengthMod += (replaceAll(RegExp(r'[^iIl]'), '').length / 2.0).ceil();
    return this.length > lengthMod
        ? '${substring(0, max(0, lengthMod - 3))}…'
        : this;
  }
}
