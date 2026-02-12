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

import 'dart:convert';
import '../timber/ktx/timber_kt.dart' as timber;

class Jsanity {
  /// Parse JSON from string with optional comment stripping
  /// [filename] is just used for logging
  T fromJson<T>(
    String json,
    String filename,
    T Function(Map<String, dynamic>) fromJsonFunc, {
    bool shouldStripComments = false,
  }) {
    return _fromJsonString(json, filename, fromJsonFunc, shouldStripComments);
  }

  /// Parse JSON from already decoded Map
  T fromJsonMap<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonFunc,
  ) {
    return fromJsonFunc(json);
  }

  /// Parse a list from JSON string
  List<T> fromJsonList<T>(
    String json,
    String filename,
    T Function(Map<String, dynamic>) fromJsonFunc, {
    bool shouldStripComments = false,
  }) {
    final strippedJson = shouldStripComments ? stripJsonComments(json) : json;

    try {
      final decoded = jsonDecode(strippedJson);
      if (decoded is! List) {
        throw FormatException('Expected JSON array but got ${decoded.runtimeType}');
      }
      return decoded.map((item) => fromJsonFunc(item as Map<String, dynamic>)).toList();
    } catch (e, stackTrace) {
      timber.e(t: e, message: () => 'Failed to parse JSON list from $filename');
      rethrow;
    }
  }

  /// Internal method to parse JSON from string
  T _fromJsonString<T>(
    String json,
    String filename,
    T Function(Map<String, dynamic>) fromJsonFunc,
    bool shouldStripComments,
  ) {
    final strippedJson = shouldStripComments ? stripJsonComments(json) : json;

    try {
      // Note: Dart's jsonDecode handles most HJson-like features natively
      // (trailing commas, unquoted keys in some cases)
      // For full HJson support, would need a separate package
      timber.v(message: () => 'Parsing JSON from $filename');
      final decoded = jsonDecode(strippedJson);

      if (decoded is! Map<String, dynamic>) {
        throw FormatException('Expected JSON object but got ${decoded.runtimeType}');
      }

      return fromJsonFunc(decoded);
    } catch (e, stackTrace) {
      timber.w(message: () {
        final preview = strippedJson
            .split('\n')
            .take(10)
            .map((line) => line.length > 100 ? line.substring(0, 100) : line)
            .join('\n');
        return 'JSON parse error in $filename: \n$preview';
      });
      timber.e(t: e, message: () => 'Full stacktrace: $stackTrace');
      rethrow;
    }
  }

  /// Convert object to JSON string
  String toJson(Object? obj) {
    return jsonEncode(obj);
  }

  /// Convert object to JSON and write to StringBuffer/StringSink
  void toJsonWriter(Object? obj, StringSink writer) {
    writer.write(jsonEncode(obj));
  }

  /// Strip comments from JSON string
  /// Removes lines starting with # (outside of strings)
  String stripJsonComments(String json) {
    // Fast but chokes on
    // "#t"# comment
    return json.replaceAll(RegExp(r'("*?")*((?<!")[#].*(?!"))', multiLine: true), '');
  }
}

/// Extension to safely get nullable values from Map
extension JsonMapExtensions on Map<String, dynamic> {
  /// Get a value that might not exist
  dynamic getNullable(String key) {
    try {
      return this[key];
    } catch (e) {
      return null;
    }
  }
}
