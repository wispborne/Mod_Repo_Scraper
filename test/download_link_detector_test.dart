import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'package:mod_repo_scraper/bot/scraper/download_link_detector.dart';

void main() {
  group('isLikelyModDownloadUrl', () {
    test('archive extensions return true', () {
      expect(isLikelyModDownloadUrl('https://example.com/mod.zip'), isTrue);
      expect(isLikelyModDownloadUrl('https://example.com/mod.rar'), isTrue);
      expect(isLikelyModDownloadUrl('https://example.com/mod.7z'), isTrue);
    });

    test('known file-hosting hosts return true', () {
      expect(
        isLikelyModDownloadUrl('https://drive.google.com/file/d/abc/view'),
        isTrue,
      );
      expect(isLikelyModDownloadUrl('https://mega.nz/file/xyz'), isTrue);
      expect(isLikelyModDownloadUrl('https://www.mediafire.com/file/a'),
          isTrue);
    });

    test('non-download URLs return false', () {
      expect(isLikelyModDownloadUrl('https://imgur.com/a/abc'), isFalse);
      expect(isLikelyModDownloadUrl('https://www.youtube.com/watch?v=1'),
          isFalse);
      expect(
        isLikelyModDownloadUrl(
            'https://fractalsoftworks.com/forum/index.php?topic=123'),
        isFalse,
      );
      expect(
        isLikelyModDownloadUrl('https://www.nexusmods.com/starsector/mods/5'),
        isFalse,
      );
    });

    test('empty or malformed URLs return false', () {
      expect(isLikelyModDownloadUrl(''), isFalse);
    });
  });

  group('isDownloadableUrl', () {
    test('obvious .zip URL short-circuits without touching the client',
        () async {
      var touched = false;
      final client = MockClient((_) async {
        touched = true;
        return http.Response('', 200);
      });

      final result =
          await isDownloadableUrl('https://x.example/mod.zip', client: client);

      expect(result, isTrue);
      expect(touched, isFalse);
    });

    test('ambiguous URL with attachment Content-Disposition → true',
        () async {
      final client = MockClient((req) async {
        expect(req.method, anyOf(equals('HEAD'), equals('GET')));
        return http.Response('', 200, headers: {
          'content-disposition': 'attachment; filename="thing.bin"',
          'content-type': 'application/octet-stream',
        });
      });

      final result = await isDownloadableUrl(
        'https://ambiguous.example/path',
        client: client,
      );

      expect(result, isTrue);
    });

    test(
        'ambiguous URL with Content-Type: application/octet-stream → true',
        () async {
      final client = MockClient((_) async {
        return http.Response('', 200, headers: {
          'content-type': 'application/octet-stream',
        });
      });

      final result = await isDownloadableUrl(
        'https://ambiguous.example/path',
        client: client,
      );

      expect(result, isTrue);
    });

    test('ambiguous URL with Content-Type: text/html → false', () async {
      final client = MockClient((_) async {
        return http.Response('<html></html>', 200, headers: {
          'content-type': 'text/html; charset=utf-8',
        });
      });

      final result = await isDownloadableUrl(
        'https://ambiguous.example/path',
        client: client,
      );

      expect(result, isFalse);
    });

    test('timeout returns false', () async {
      final client = MockClient((_) async {
        // Never completes within the test window.
        await Future<void>.delayed(const Duration(seconds: 5));
        return http.Response('', 200);
      });

      final result = await isDownloadableUrl(
        'https://slow.example/path',
        client: client,
        timeout: const Duration(milliseconds: 50),
      );

      expect(result, isFalse);
    });

    test('network error returns false', () async {
      final client = MockClient((_) async {
        throw const SocketExceptionLike();
      });

      final result = await isDownloadableUrl(
        'https://broken.example/path',
        client: client,
      );

      expect(result, isFalse);
    });
  });
}

class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
