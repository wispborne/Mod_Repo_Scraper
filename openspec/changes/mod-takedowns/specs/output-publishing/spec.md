## ADDED Requirements

### Requirement: Publishing includes the takedown list
A publish SHALL copy `<qb_data_path>/takedowns.json` to the root of the published repo, or write an empty list there when the local file is missing and the check below permits publishing. This makes the list public. Before copying, the publish SHALL compare the list in the freshly fetched clone with the local one. A missing local file SHALL count as an empty list for this check. If a published entry is missing locally, the publish SHALL check whether a `restoreTakedown` job removed it, using `<qb_data_path>/takedowns-restored.json`. If no such job removed it, the publish SHALL fail, name the missing entries, and push nothing. This prevents a lost or replaced `qb_data` from publishing taken-down mods again. A recorded restore SHALL be cleared at a later publish only when the freshly fetched list already omits that entry, before the local list is copied over it.

#### Scenario: The list is published
- **WHEN** a publish runs and `takedowns.json` has the entry for `diable-avionics-tidal-fork`
- **THEN** the published repo's `takedowns.json` has that entry after the push

#### Scenario: A lost list stops the publish
- **WHEN** the published `takedowns.json` has an entry, the local list does not, and no restore removed it
- **THEN** the publish fails, names the entry, and nothing is committed or pushed

#### Scenario: A missing local file stops the publish
- **WHEN** the published `takedowns.json` has entries, `<qb_data_path>/takedowns.json` does not exist, and no recorded restore accounts for those entries
- **THEN** the publish fails, names the entries, and nothing is committed or pushed

#### Scenario: A restore is published
- **WHEN** a `restoreTakedown` job removed an entry and recorded it, and a publish runs
- **THEN** the publish goes ahead, and the published list no longer has the entry

### Requirement: The cron publish runs the same check
Production publishes with `tool/update-mod-repo.sh`, not with `PublishService`. The check and the copy SHALL be one function, used by `PublishService` and by a `mod_repo_scraper --publish-takedowns <clone folder>` step. The script SHALL run that step after it copies the outputs into the clone and before it commits. When the step fails, the script SHALL stop without committing or pushing.

#### Scenario: Cron finds a lost list
- **WHEN** the cron script runs on a host whose `qb_data` has no `takedowns.json`, the published list has entries, and no recorded restore accounts for those entries
- **THEN** the `--publish-takedowns` step exits with an error naming the entries, and the script commits and pushes nothing

#### Scenario: Cron publishes the list
- **WHEN** the cron script runs and the local list has every published entry
- **THEN** the clone's `takedowns.json` is replaced by the local list, and it is committed with the other files
