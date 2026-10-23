## ADDED Requirements

### Requirement: Publishing includes the takedown list
A publish SHALL copy `<qb_data_path>/takedowns.json` to the root of the published repo. This makes the list public. When there is no local list, a publish SHALL leave any published list in place. Before copying, the publish SHALL compare the two lists. If a published entry is missing locally, the publish SHALL check whether a `restoreTakedown` job removed it. If no such job removed it, the publish SHALL fail and name the missing entries. In that case, it SHALL push nothing. That stops a lost or replaced `qb_data` from putting taken-down mods back on the site.

#### Scenario: The list is published
- **WHEN** a publish runs and `takedowns.json` has the entry for `diable-avionics-tidal-fork`
- **THEN** the published repo's `takedowns.json` has that entry after the push

#### Scenario: A lost list stops the publish
- **WHEN** the published `takedowns.json` has an entry, the local list does not, and no restore removed it
- **THEN** the publish fails, names the entry, and nothing is committed or pushed
