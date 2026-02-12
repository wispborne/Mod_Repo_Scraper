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

import '../timber.dart' as timber_lib;

/// Wisp: Taken from timberkt (https://github.com/ajalt/timberkt) and adapted for Dart.
///
/// This provides lazy logging functionality similar to Kotlin's inline lambdas.
class Timber {
  /// Log a verbose exception and a message that will be evaluated lazily when the message is printed
  static void v({Object? t, required String Function() message}) {
    _log(() => timber_lib.Timber.vWithError(t, message()));
  }

  static void vError(Object? t) => timber_lib.Timber.vError(t);

  /// Log a debug exception and a message that will be evaluated lazily when the message is printed
  static void d({Object? t, required String Function() message}) {
    _log(() => timber_lib.Timber.dWithError(t, message()));
  }

  static void dError(Object? t) => timber_lib.Timber.dError(t);

  /// Log an info exception and a message that will be evaluated lazily when the message is printed
  static void i({Object? t, required String Function() message}) {
    _log(() => timber_lib.Timber.iWithError(t, message()));
  }

  static void iError(Object? t) => timber_lib.Timber.iError(t);

  /// Log a warning exception and a message that will be evaluated lazily when the message is printed
  static void w({Object? t, required String Function() message}) {
    _log(() => timber_lib.Timber.wWithError(t, message()));
  }

  static void wError(Object? t) => timber_lib.Timber.wError(t);

  /// Log an error exception and a message that will be evaluated lazily when the message is printed
  static void e({Object? t, required String Function() message}) {
    _log(() => timber_lib.Timber.eWithError(t, message()));
  }

  static void eError(Object? t) => timber_lib.Timber.eError(t);

  /// Log an assert exception and a message that will be evaluated lazily when the message is printed
  static void wtf({Object? t, required String Function() message}) {
    _log(() => timber_lib.Timber.wtfWithError(t, message()));
  }

  static void wtfError(Object? t) => timber_lib.Timber.wtfError(t);

  // Forward methods to real Timber
  static void plant(timber_lib.Tree tree) => timber_lib.Timber.plant(tree);

  static void tag(String tag) => timber_lib.Timber.tag(tag);

  static void uproot(timber_lib.Tree tree) => timber_lib.Timber.uproot(tree);

  static void uprootAll() => timber_lib.Timber.uprootAll();

  static void _log(void Function() block) {
    if (timber_lib.Timber.treeCount > 0) block();
  }
}

// Plain functions for convenience
void v({Object? t, required String Function() message}) =>
    Timber.v(t: t, message: message);

void vError(Object? t) => Timber.vError(t);

void d({Object? t, required String Function() message}) =>
    Timber.d(t: t, message: message);

void dError(Object? t) => Timber.dError(t);

void i({Object? t, required String Function() message}) =>
    Timber.i(t: t, message: message);

void iError(Object? t) => Timber.iError(t);

void w({Object? t, required String Function() message}) =>
    Timber.w(t: t, message: message);

void wError(Object? t) => Timber.wError(t);

void e({Object? t, required String Function() message}) =>
    Timber.e(t: t, message: message);

void eError(Object? t) => Timber.eError(t);

void wtf({Object? t, required String Function() message}) =>
    Timber.wtf(t: t, message: message);

void wtfError(Object? t) => Timber.wtfError(t);
