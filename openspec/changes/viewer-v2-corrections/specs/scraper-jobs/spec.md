## ADDED Requirements

### Requirement: Saving several corrections as one job
A `saveCorrections` request SHALL carry a list of corrections: take down a mod, take down a person, restore a takedown entry, join two author names as one person, mark two author names as different people, remove a name from a person, choose the name a person is published under, and match a dependency name to a mod, to none of our mods, or forget its saved answer. The job SHALL apply them in order and check the results with the same rules as the single-correction jobs before writing anything. If any correction is refused, the job SHALL fail, write nothing, and name every refused correction and explain why it was refused. Otherwise it SHALL save the files that changed, merge `ModRepo.json` again, rebuild the bundle, catalog and website once, and publish when `publishAfter` is set. It SHALL make no network call other than the publish, and no LLM call.

#### Scenario: Three kinds at once
- **WHEN** a `saveCorrections` job carries a takedown, an author pair and a dependency name match
- **THEN** all three files are saved and the outputs are rebuilt once

#### Scenario: One refused
- **WHEN** one of three corrections takes down a mod id that does not exist
- **THEN** the job fails naming that correction, and none of the three files changes
