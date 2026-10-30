## ADDED Requirements

### Requirement: A rating scores five criteria
A rating SHALL give each of Stability, Balance, Vanilla Friendliness, Fun and Polish a whole number from 1 to 5, or N/A. A rating SHALL score at least one criterion. There SHALL be no overall score anywhere on the site or in the published files.

#### Scenario: A portrait pack
- **WHEN** a player rates a portrait pack with Balance set to N/A
- **THEN** the rating is saved, and Balance gets no score from it

#### Scenario: All N/A
- **WHEN** a player sends a rating with every criterion set to N/A
- **THEN** it is refused

### Requirement: A rating is for one version
A rating SHALL record the mod version the player picked. The picker SHALL default to the mod's current version and SHALL offer the mod's earlier releases. A mod with no known version SHALL have no version choices. Its ratings SHALL be stored with no version. One account SHALL have at most one rating per mod per version. Rating the same version again SHALL replace the earlier rating.

#### Scenario: Rating again after an update
- **WHEN** a player who rated version 1.2 rates the mod again after 1.3 comes out, leaving the version on 1.3
- **THEN** they have two ratings: one for 1.2 and one for 1.3

#### Scenario: Changing a rating
- **WHEN** a player rates version 1.3 a second time
- **THEN** the new scores replace their earlier 1.3 rating

### Requirement: Ratings for older versions count less
When calculating a mod's averages, a rating SHALL count fully while its version is the mod's current version, when the mod has no known releases, or when its version is not in the mod's release history. Once the mod has a release newer than the rating's version, the rating's weight SHALL halve every 3 months, counted from the date of the first newer release.

#### Scenario: A week after a patch
- **WHEN** a rating is for 1.2 and the mod released 1.2.1 seven days ago
- **THEN** the rating counts at nearly full weight

#### Scenario: After two years
- **WHEN** a rating is for a version replaced 24 months ago
- **THEN** it counts at 1/256 of a current rating

### Requirement: Averages are published with the mod
Each site build SHALL calculate, for every mod and criterion, the weighted average of the scores and the number of players who scored it. Both SHALL be written to `mods.json` and to the mod's `mods/<id>.json`, for criteria with at least one score. A mod with no ratings SHALL have no ratings field. Ratings from blocked accounts and ratings marked abusive SHALL NOT count.

#### Scenario: An unrated mod
- **WHEN** a mod has no ratings
- **THEN** its record in `mods.json` has no `ratings` field

#### Scenario: A blocked account
- **WHEN** an account is blocked in the viewer
- **THEN** the next site build calculates every average without its ratings

### Requirement: The mod page shows all five criteria
A mod's page SHALL show, for each criterion, its average and how many players scored it, or "Not rated" if it has no scores. It SHALL offer a signed-in player a way to rate the mod.

#### Scenario: A mod with some ratings
- **WHEN** a mod has 6 Stability scores averaging 4.2 and no Balance scores
- **THEN** its page shows Stability 4.2 from 6 players, and Balance as "Not rated"

### Requirement: Browse can sort and filter by a criterion
Browse SHALL offer a sort by each criterion, highest first. Mods with fewer than 3 players scoring that criterion SHALL come after the mods with 3 or more, and mods with none SHALL come last. Browse SHALL offer, for each criterion, a filter for "at least N". The filter SHALL keep mods with no scores for that criterion, unless the reader turns on "Hide mods with no ratings".

#### Scenario: One 5 does not beat forty 4.8s
- **WHEN** Browse is sorted by Stability, one mod has one Stability score of 5 and another has forty averaging 4.8
- **THEN** the mod with forty comes first

#### Scenario: New mods stay in the list
- **WHEN** a reader filters for Stability at least 4
- **THEN** mods with Stability 4 or more are shown, and so are mods with no Stability scores

#### Scenario: Hiding unrated mods
- **WHEN** the reader also turns on "Hide mods with no ratings"
- **THEN** only mods with a Stability average of 4 or more are shown

### Requirement: Cards show the criterion in use
A card or row SHALL show no ratings by default. While Browse is sorted or filtered by a criterion, each card and row SHALL show that criterion's average and player count.

#### Scenario: Sorted by Fun
- **WHEN** Browse is sorted by Fun
- **THEN** each card shows its Fun average and count, and no other criterion

### Requirement: Ratings move with mods and are kept when hidden
Ratings SHALL be stored under the permanent id the player rated. When that id moves to the mod it was joined into, its ratings SHALL count for that mod. A Collection page, a taken-down mod and a mod whose author opted out SHALL show no ratings and offer no way to rate. Their ratings SHALL be kept, and SHALL count again if the mod is restored or the opt-out is removed.

#### Scenario: Two pages joined
- **WHEN** a mod's Discord page is joined into its forum page and its old id moves
- **THEN** the forum page's averages include the ratings given on the Discord page

#### Scenario: Restoring a taken-down mod
- **WHEN** a taken-down mod is restored
- **THEN** its page shows the ratings it had before

### Requirement: Authors can opt out
The viewer SHALL keep an opt-out list of permanent ids, saved and published like the takedown list. A mod on the list SHALL say on its page that its author opted out of ratings.

#### Scenario: Opting out
- **WHEN** a mod's id is added to the opt-out list and the site is built
- **THEN** its page says the author opted out of ratings, and shows no averages and no reviews
