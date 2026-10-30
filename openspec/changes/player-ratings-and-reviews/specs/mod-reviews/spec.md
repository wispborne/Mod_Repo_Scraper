## ADDED Requirements

### Requirement: A review is optional text with a rating
A player SHALL be able to add a review to a rating. A review SHALL be plain text of at most 1,000 characters. A review containing a link SHALL be refused when submitted. A rating SHALL be valid with no review.

#### Scenario: Too long
- **WHEN** a player sends a review of 1,200 characters
- **THEN** it is refused with a message stating the limit

#### Scenario: Rating only
- **WHEN** a player sends scores and no text
- **THEN** the rating is saved and counts, and there is no review to check

### Requirement: A review is shown only after it is approved
A review SHALL be shown to other readers only after approval. The player who wrote it SHALL see it on the mod's page immediately, marked as "Pending".

#### Scenario: A new review
- **WHEN** a player sends a review
- **THEN** they see it on the mod's page marked as "Pending", and other readers do not see it

### Requirement: Review text is read from the account service
A mod's page SHALL fetch its reviews from the account service only when `mods/<id>.json` says the mod has approved reviews, or when the reader is signed in. Review text SHALL NOT be written into any published file. When the service does not answer, the page SHALL show the averages and say that reviews could not be loaded.

#### Scenario: A mod with no reviews
- **WHEN** a reader who is not signed in opens a mod with no approved reviews
- **THEN** the page makes no request to the account service

#### Scenario: The service is down
- **WHEN** the account service does not answer
- **THEN** the page shows the averages and says the reviews could not be loaded

### Requirement: Reviews are ordered by version, then date
A mod's page SHALL show reviews for the current version first, newest first. Reviews for earlier versions SHALL be collapsed below them, grouped by version. Each review SHALL show the display name, the version, the date and the scores given with it. A review by a verified author of the mod SHALL be marked as the author's.

#### Scenario: After an update
- **WHEN** a mod moves from 1.2 to 1.3
- **THEN** its 1.3 reviews are listed first and its 1.2 reviews are collapsed under "Earlier versions"

### Requirement: Reporting a review does not hide it
A signed-in player SHALL be able to report a review once, with an optional reason. A report SHALL NOT hide the review. Reported reviews SHALL be listed in the viewer.

#### Scenario: Many reports
- **WHEN** ten players report the same review
- **THEN** the review stays up, and the viewer lists it with ten reports

### Requirement: Authorship can be verified three ways
An account SHALL count as a mod's author when its Discord sign-in is the author of the mod's Discord thread, when its GitHub sign-in owns the repository the mod's source code link points to, or when the viewer marks it as the mod's author.

#### Scenario: Through GitHub
- **WHEN** a mod's source code link is `github.com/example/coolmod` and a player signs in with the GitHub account `example`
- **THEN** that account counts as the mod's author
