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
import 'dart:io';

import 'scraped_mod.dart';

class ModRepoCache {
  static final File location = File("ModRepo.json");
  late Map<String, dynamic> _data;

  ModRepoCache() {
    _data = _readFile();
  }

  String? get lastUpdated => _data['lastUpdated'] as String?;

  set lastUpdated(String? value) => _data['lastUpdated'] = value;

  int get totalCount => (_data['totalCount'] as int?) ?? 0;

  set totalCount(int value) => _data['totalCount'] = value;

  List<ScrapedMod> get items {
    final itemsJson = _data['items'] as List?;
    if (itemsJson == null) return [];
    return itemsJson
        .map((json) => ScrapedModMapper.fromMap(json as Map<String, dynamic>))
        .toList();
  }

  set items(List<ScrapedMod> value) {
    _data['items'] = value.map((mod) => mod.toMap()).toList();
  }

  void save() {
    const encoder = JsonEncoder.withIndent('  ');
    location.writeAsStringSync(encoder.convert(_data));
  }

  Map<String, dynamic> _readFile() {
    if (!location.existsSync()) {
      location.createSync(recursive: true);
      location.writeAsStringSync('{}');
    }
    final content = location.readAsStringSync();
    if (content.isEmpty) return {};
    return jsonDecode(content) as Map<String, dynamic>;
  }
}
