class GameVersionComparer {
  GameVersionComparer._();

  static final RegExp _segmentRegex = RegExp(r'^(\d*)(.*)$');

  static int compare(String? a, String? b) {
    final aEmpty = a == null || a.trim().isEmpty;
    final bEmpty = b == null || b.trim().isEmpty;
    if (aEmpty && bEmpty) return 0;
    if (aEmpty) return -1;
    if (bEmpty) return 1;

    final aParts = a.trim().split('.');
    final bParts = b.trim().split('.');

    if (aParts.length >= 2 &&
        bParts.length >= 2 &&
        _isAllDigits(aParts[0]) &&
        _isAllDigits(aParts[1]) &&
        _isAllDigits(bParts[0]) &&
        _isAllDigits(bParts[1])) {
      final da = double.tryParse('${aParts[0]}.${aParts[1]}');
      final db = double.tryParse('${bParts[0]}.${bParts[1]}');
      if (da != null && db != null) {
        final c = da.compareTo(db);
        if (c != 0) return c;
        return _compareTail(aParts, bParts, 2);
      }
    }

    final max = aParts.length > bParts.length ? aParts.length : bParts.length;
    for (var i = 0; i < max; i++) {
      final ap = i < aParts.length ? aParts[i].trim() : '';
      final bp = i < bParts.length ? bParts[i].trim() : '';
      final seg = _compareSegment(ap, bp);
      if (seg != 0) return seg;
    }
    return 0;
  }

  static bool isAtLeast(String? modVersion, String minVersion) {
    if (modVersion == null || modVersion.trim().isEmpty) return false;
    return compare(modVersion, minVersion) >= 0;
  }

  static int _compareTail(List<String> aParts, List<String> bParts, int start) {
    final max = aParts.length > bParts.length ? aParts.length : bParts.length;
    for (var i = start; i < max; i++) {
      final ap = i < aParts.length ? aParts[i].trim() : '';
      final bp = i < bParts.length ? bParts[i].trim() : '';
      final c = _compareSegment(ap, bp);
      if (c != 0) return c;
    }
    return 0;
  }

  static bool _isAllDigits(String s) =>
      s.isNotEmpty && s.runes.every((r) => r >= 48 && r <= 57);

  static int _compareSegment(String a, String b) {
    final ma = _segmentRegex.firstMatch(a);
    final mb = _segmentRegex.firstMatch(b);
    final an =
        ma != null ? (int.tryParse(ma.group(1) ?? '') ?? 0) : 0;
    final bn =
        mb != null ? (int.tryParse(mb.group(1) ?? '') ?? 0) : 0;
    if (an != bn) return an.compareTo(bn);

    final asuf = ma != null ? (ma.group(2) ?? '') : '';
    final bsuf = mb != null ? (mb.group(2) ?? '') : '';
    return asuf.toLowerCase().compareTo(bsuf.toLowerCase());
  }
}
