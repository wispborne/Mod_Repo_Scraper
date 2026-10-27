import 'package:mod_repo_scraper/bot/scraper/discord_reader.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/llm/extraction_store.dart';
import 'package:mod_repo_scraper/bot/scraper/qb/models/post_extraction.dart';
import 'package:mod_repo_scraper/catalog/discord_posts.dart';
import 'package:mod_repo_scraper/catalog/download_key.dart';
import 'package:test/test.dart';

const _thread = Channel(id: 'thread-1', name: 'Fresh Mod 1.2');
const _author = User(id: 'author', username: 'Author');
const _fan = User(id: 'fan', username: 'Fan');

Message _message(String id, User author, String content, int day,
        {Channel? thread = _thread, List<Attachment>? attachments}) =>
    Message(
      id: id,
      author: author,
      content: content,
      timestamp: DateTime.utc(2026, 1, day),
      parentThread: thread,
      attachments: attachments,
    );

const _signature = '?ex=6ae03df6&is=6adeec76&hm=d72cdf79';
const _zipUrl = 'https://cdn.discordapp.com/attachments/thread-1/555/FreshMod.zip$_signature';
const _zip = Attachment(id: '555', filename: 'FreshMod.zip', contentType: 'application/zip', size: 1000, url: _zipUrl);
const _picture = Attachment(
    id: '556',
    filename: 'icon.png',
    contentType: 'image/png',
    url: 'https://cdn.discordapp.com/attachments/thread-1/556/icon.png$_signature');
const _video = Attachment(
    id: '557',
    filename: 'trailer.mp4',
    contentType: 'video/mp4',
    url: 'https://cdn.discordapp.com/attachments/thread-1/557/trailer.mp4$_signature');

void main() {
  test('three messages by the author before a reply are all kept', () {
    final run = DiscordReader.openingRunOf([
      // Discord answers newest first; the run is read oldest first.
      _message('5', _fan, 'Thanks!', 5),
      _message('4', _author, 'Update 1.2', 4),
      _message('3', _author, 'Update 1.1', 3),
      _message('2', _author, 'Fresh Mod\nDownload below.', 2),
    ])!;

    expect(run.threadId, 'thread-1');
    expect(run.name, 'Fresh Mod 1.2');
    expect(run.author, 'Author');
    expect(run.messages.map((m) => m.id), ['2', '3', '4']);
  });

  test("a reply cuts the author's messages short", () {
    final run = DiscordReader.openingRunOf([
      _message('2', _author, 'Fresh Mod', 2),
      _message('3', _fan, 'Does it work with Nex?', 3),
      _message('4', _author, 'Yes, and here is a beta: https://example.com/beta.zip', 4),
    ])!;

    expect(run.messages.map((m) => m.id), ['2'],
        reason: "the author's answer to a question is not part of the announcement");
  });

  test('the run starts at the first message with text and stops after ten', () {
    final run = DiscordReader.openingRunOf([
      _message('1', _author, '   ', 1),
      for (var day = 2; day < 20; day++) _message('$day', _author, 'Part $day', day),
    ])!;

    expect(run.messages.first.id, '2');
    expect(run.messages, hasLength(DiscordThreadPost.maxMessages));
  });

  test('a message that is not in a thread is filed under its own id', () {
    final run = DiscordReader.openingRunOf([_message('77', _author, 'Lone Mod', 1, thread: null)])!;

    expect(run.threadId, '77');
    expect(run.messages.single.content, 'Lone Mod');
  });

  test('a thread with no text at all gives no run', () {
    expect(DiscordReader.openingRunOf([_message('1', _author, '', 1)]), isNull);
  });

  test('the old file, written by the site under message links, still reads', () {
    const file = DiscordPostsFile(
      threads: {
        't': DiscordThreadPost(threadId: 't', messages: [DiscordOpeningMessage(id: 'm', content: 'New')]),
      },
      legacyTexts: {'https://discord.com/channels/1/old/9': 'Old'},
    );
    expect(file.firstTextFor('https://discord.com/channels/1/t/m'), 'New');
    expect(file.firstTextFor('https://discord.com/channels/1/old/9'), 'Old');
    expect(file.firstTextFor('https://discord.com/channels/1/nothing/9'), isNull);
  });

  group('attached files', () {
    test('a file that is not a picture, video or sound is kept beside the pictures', () {
      final run = DiscordReader.openingRunOf([
        _message('2', _author, 'Fresh Mod', 2, attachments: const [_zip, _picture, _video]),
      ])!;
      final message = run.messages.single;

      expect(message.images.map((i) => i.filename), ['icon.png']);
      expect(message.files!.map((f) => f.filename), ['FreshMod.zip']);
      expect(message.files!.single.url, _zipUrl);
    });

    test('a message with no files saves no files field, so old entries keep their shape', () {
      final run = DiscordReader.openingRunOf([_message('2', _author, 'Fresh Mod', 2)])!;

      expect(run.messages.single.files, isNull);
      expect(run.toMap()['messages'][0], isNot(contains('files')));
    });

    test('a message of nothing but attachments starts the run', () {
      final run = DiscordReader.openingRunOf([
        _message('1', _author, '', 1),
        _message('2', _author, '', 2, attachments: const [_picture]),
        _message('3', _author, 'More shots', 3),
      ])!;

      expect(run.messages.map((m) => m.id), ['2', '3']);
      expect(run.firstText, 'More shots', reason: 'the site shows the first text in the run');
    });

    test('the LLM sees an attached file as a link named after it, flagged as a download', () {
      final run = DiscordReader.openingRunOf([
        _message('2', _author, 'Fresh Mod: https://example.com/page', 2, attachments: const [_zip]),
      ])!;
      final links = run.toSourcePost().posts.single.links;

      expect(links.map((l) => l.url), ['https://example.com/page', _zipUrl]);
      expect(links.last.text, 'FreshMod.zip');
      expect(links.last.isDownloadable, isTrue);
    });

    test("a new signature on the file does not change the thread's fingerprint", () {
      const resigned = 'https://cdn.discordapp.com/attachments/thread-1/555/FreshMod.zip?ex=1&is=2&hm=3';

      expect(LlmExtractionStore.withoutDiscordSignatures('- [1] $_zipUrl "FreshMod.zip"'),
          LlmExtractionStore.withoutDiscordSignatures('- [1] $resigned "FreshMod.zip"'));
      expect(downloadKey(_zipUrl), downloadKey(resigned));
      expect(downloadKey(_zipUrl), downloadKey(resigned.replaceFirst('cdn.discordapp.com', 'media.discordapp.net')));
    });
  });

  group('publishing an attached file', () {
    test('a file attached on Discord is never published', () {
      expect(isDiscordAttachmentDownload(LlmDownload(url: _zipUrl)), isTrue);
      expect(
          isDiscordAttachmentDownload(LlmDownload(
              url: 'https://example.com/page', resolvedDirectUrl: _zipUrl.replaceFirst('cdn.discordapp.com', 'media.discordapp.net'))),
          isTrue,
          reason: 'the file it leads to counts too');
      expect(
          isDiscordAttachmentDownload(LlmDownload(url: 'https://cdn.discordapp.com/attachments/other/1/x.zip$_signature')),
          isTrue,
          reason: 'whichever channel it was attached in');
    });

    test('an ordinary download is published', () {
      expect(isDiscordAttachmentDownload(LlmDownload(url: 'https://github.com/a/b/releases/download/1.0/b.zip')),
          isFalse);
    });
  });
}
