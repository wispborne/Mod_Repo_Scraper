# Readers add third-party catalogs in their own browser

Some sites and servers publish Starsector mods that Starmodder will not list. Starmodder does not read NexusMods because it does a poor job of removing mods that break copyright. Corvus Freeport is another source Starmodder will not read. It is a Discord server with about 10,000 members. It posts unofficial builds, modified versions and fixes for other people's mods. It is accused of sharing mods without permission.

A reader can still choose to see such mods. A **third-party catalog** is one JSON file in Starmodder's format. Someone other than Starmodder publishes it. A reader adds its address in their own browser. Only that reader sees its mods. Starmodder's build never reads a third-party catalog. The published files contain no information about these catalogs. Starmodder does not check, store or approve these catalogs.

The site requirements allow it to read data only from its own address. ADR 0003 added an exception for the account service. This decision adds a second exception. The site reads files from addresses readers enter.

## The format

- Each catalog is one file, no larger than 5 MB. Its fields are `schemaVersion`, `name`, `generatedAt` and `mods`.
- Field names match those in `PublicMod` and `mod-catalog-extras.json`. The site, future versions of TriOS and anyone reading our files can use the same names.
- Each mod needs an `id` that no other mod in its catalog uses. It also needs `name`, `authors`, and at least one of a download, a forum address or a Discord address. Everything else is optional.
- Descriptions allow a few Markdown features. The site converts them to a fixed set of tags. The site shows any HTML in a description as text.
- A third-party id is not a permanent id. Owners are asked to keep ids unchanged. The site cannot stop owners from changing them.
- Only the site reads catalogs for now. The format is designed for TriOS to read later without changes.

## How the site shows them

- Third-party mods appear with ours in Browse, search, favorites, the "From" filter and Home's "Recently added". They are left out of "Recent updates", Reports and the release feed. Starmodder has no record of their version changes.
- Every card and page shows a label with the catalog's name and the server it was read from. The server name cannot be faked. The reader can rename the catalog.
- A third-party mod is never combined with one of ours. A catalog does not link its mods to our permanent ids. The "same name" panel lists the third-party mod on both pages. It is labelled as from a third-party catalog. The browser needs a JavaScript copy of `sameNameKey`. It must match the Dart version.
- A Discord attachment is never offered as a download. Its address stops working within about a day. The site shows the mod's Discord button instead. It says the reader may need to join that server.
- The rule against naming Nexus Mods applies only to text written by Starmodder. A catalog's owner supplies its name and links. The site shows them unchanged.

## How a reader adds one

- The "Third-party catalogs" section of Settings appears only after the reader visits `#/settings/catalogs`. It then stays visible in that browser. The feature is not mentioned anywhere else on the site. There is no page for catalog owners yet.
- When a reader adds a catalog, a box shows its name, address and mod count. A warning says its mods are not checked. They may include unofficial versions of other people's mods. Nothing is read from the catalog until the box opens. Nothing is saved until the reader agrees.
- Opening a link never adds a catalog. If a reader opens a shared link without having added the mod's catalog, the page says the catalog has not been added. It shows the catalog's address. The reader can add it in Settings.
- The browser stores the list. It reads each catalog once per visit. If it cannot read a catalog, it skips it and shows a message. A favorite third-party mod is stored by catalog address and id.

## Takedown requests

Third-party mods appear on Starmodder's pages. Authors' takedown requests apply to them too. The browser reads the published takedown list and hides a third-party mod when:

- a credited author matches an author on the list. The same rules apply as for our catalog.
- its name matches a removed mod's name under the same-name rule. This sometimes hides an unrelated mod with the same name. We accept this because an unofficial build almost always keeps the original's name.
- its catalog address and mod id match an entry on the list. This is a new type of entry. It is added only when an author requests removal of a specific listing. It also applies to mods that were never in our catalog. Changing the id makes the mod visible again. For this reason, most removals rely on name matching.

## Options considered

- **A list of approved catalogs that every reader sees.** Rejected: Starmodder would then include those sources. We stopped reading Nexus to avoid this.
- **Reading NexusMods or Corvus in our own build.** Rejected for the same reason. Reading Corvus also requires its admins to add a bot.
- **Showing a catalog's copy of a mod on our mod's page.** Rejected: an unofficial patch would appear on the page of an author who did not approve it.
- **Letting the browser match third-party mods to ours by name and author.** Rejected: a wrong match would hide or mix up a mod.

## Consequences

- Nobody publishes a third-party catalog yet. Owners, such as the Corvus admins, are expected to publish their own. If Starmodder built one, it would still be Starmodder's catalog at a different address.
- A shared link to a third-party mod works only for readers who added its catalog. Other readers do not see the mod. They see only a message and the catalog's address.
