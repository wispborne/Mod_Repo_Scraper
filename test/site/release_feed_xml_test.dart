import 'package:mod_repo_scraper/site/models/mod_release.dart';
import 'package:mod_repo_scraper/site/release_feed_xml.dart';
import 'package:test/test.dart';

/// The release feed as a file a reader can subscribe to. Modders and server
/// admins live in feed readers, so this is the thing most likely to bring
/// somebody back without them having to remember to visit.
void main() {
  ModRelease release({
    String modId = 'nexerelin',
    String modName = 'Nexerelin',
    String seenOn = '2026-08-14',
    String? oldVersion = '0.12.1e',
    String newVersion = '0.12.2',
    String? notes,
  }) =>
      ModRelease(
        modId: modId,
        modName: modName,
        seenOn: seenOn,
        oldVersion: oldVersion,
        newVersion: newVersion,
        changelogNotes: notes,
      );

  ModReleaseFeed feedOf(List<ModRelease> releases) => ModReleaseFeed(
        generatedAt: DateTime.utc(2026, 8, 19, 4, 12, 33),
        releases: releases,
      );

  test('is an Atom feed a reader can open', () {
    final xml = buildReleaseFeedXml(feedOf([release()]));

    expect(xml, startsWith('<?xml version="1.0" encoding="utf-8"?>'));
    expect(xml, contains('<feed xmlns="http://www.w3.org/2005/Atom">'));
    expect(xml, contains('<updated>2026-08-19T04:12:33Z</updated>'));
    expect(xml, contains('</feed>'));
  });

  test('it names an author, which every feed has to', () {
    // A feed without one is turned away by validators and shown as authorless
    // by some readers.
    expect(buildReleaseFeedXml(feedOf([release()])),
        contains('<author><name>Starmodder</name></author>'));
  });

  test('every link is relative, so the feed works from any folder', () {
    final xml = buildReleaseFeedXml(feedOf([release()]));

    expect(xml, contains('href="updates.xml"'));
    expect(xml, contains('href="index.html#/mods/nexerelin"'));
    // The namespace is a web address; nothing a reader follows is.
    expect(xml, isNot(contains('href="http')));
  });

  test('one entry per release, named for the mod and its new version', () {
    final xml = buildReleaseFeedXml(feedOf([release()]));

    expect(xml, contains('<title>Nexerelin 0.12.2</title>'));
    expect(xml, contains('<updated>2026-08-14T00:00:00Z</updated>'));
    expect(xml, contains('Nexerelin went from 0.12.1e to 0.12.2.'));
  });

  test('a first release does not claim to have come from somewhere', () {
    final xml = buildReleaseFeedXml(feedOf([release(oldVersion: null)]));

    expect(xml, contains('Nexerelin is now at 0.12.2.'));
    expect(xml, isNot(contains('went from')));
  });

  test('the notes the author wrote are the body of the entry', () {
    final xml = buildReleaseFeedXml(feedOf([release(notes: 'Fixed a crash.')]));

    expect(xml, contains('Fixed a crash.'));
  });

  test('an entry keeps the same name forever, so it is never shown twice', () {
    final xml = buildReleaseFeedXml(feedOf([release()]));

    expect(xml, contains('<id>tag:starmodder,2026:release/nexerelin/0.12.2</id>'));
  });

  test('anything that would break the file is escaped', () {
    final xml = buildReleaseFeedXml(feedOf([
      release(modName: 'Ships & <b>Guns</b>', notes: 'Fixed "a" < b & c'),
    ]));

    expect(xml, contains('Ships &amp; &lt;b&gt;Guns&lt;/b&gt;'));
    expect(xml, contains('Fixed "a" &lt; b &amp; c'));
    expect(xml, isNot(contains('<b>')));
  });

  test('only the newest releases are carried, so the file cannot run away', () {
    final many = [
      for (var i = 0; i < maxFeedEntries + 40; i++)
        release(modId: 'mod$i', modName: 'Mod $i'),
    ];

    final xml = buildReleaseFeedXml(feedOf(many));

    expect('<entry>'.allMatches(xml).length, maxFeedEntries);
    expect(xml, contains('<title>Mod 0 0.12.2</title>'));
    expect(xml, isNot(contains('<title>Mod ${maxFeedEntries + 39} 0.12.2</title>')));
  });

  test('an empty feed is still a feed, not a broken file', () {
    final xml = buildReleaseFeedXml(feedOf([]));

    expect(xml, contains('<feed xmlns="http://www.w3.org/2005/Atom">'));
    expect(xml, isNot(contains('<entry>')));
    expect(xml, contains('</feed>'));
  });
}
