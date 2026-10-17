import 'package:mod_repo_scraper/bot/scraper/discord_reader.dart';
import 'package:mod_repo_scraper/catalog/discord_posts.dart';
import 'package:test/test.dart';

const _thread = Channel(id: 'thread-1', name: 'Fresh Mod 1.2');
const _author = User(id: 'author', username: 'Author');
const _fan = User(id: 'fan', username: 'Fan');

Message _message(String id, User author, String content, int day, {Channel? thread = _thread}) => Message(
      id: id,
      author: author,
      content: content,
      timestamp: DateTime.utc(2026, 1, day),
      parentThread: thread,
    );

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
}
