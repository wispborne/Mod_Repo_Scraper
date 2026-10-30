## ADDED Requirements

### Requirement: Players sign in with Discord, GitHub or Google
Starmodder SHALL let a player sign in with Discord, GitHub or Google. Signing in SHALL be handled by the account service, which SHALL send the player back to the page they started from. A player who is not signed in SHALL be able to read everything on the site, including reviews.

#### Scenario: Signing in from a mod page
- **WHEN** a player on a mod's page signs in with GitHub
- **THEN** they come back to the same mod's page, signed in

#### Scenario: Reading without an account
- **WHEN** a player who is not signed in opens a mod's page
- **THEN** they see the mod's averages and its approved reviews

### Requirement: One account can have several sign-ins
A signed-in player SHALL be able to link another provider's sign-in to their account. Each sign-in SHALL belong to one account only. Linking a sign-in that already belongs to another account SHALL be refused, with a message explaining that it is already linked to another account. There SHALL be no minimum account age.

#### Scenario: Linking Discord to an account made with Google
- **WHEN** a player signed in with Google links their Discord sign-in
- **THEN** signing in with either one opens the same account, with the same ratings

#### Scenario: A sign-in already in use
- **WHEN** a player tries to link a GitHub sign-in that another account already uses
- **THEN** the link is refused and both accounts are unchanged

### Requirement: Players choose their display name
An account SHALL be shown on the site under the player's chosen display name. A new or changed name SHALL be checked by the review check job before it is shown; until then, the site SHALL show a placeholder name to everyone but the player. The site SHALL NOT show which providers an account signs in with, and SHALL NOT show any name, email address or id from a provider.

#### Scenario: A name awaiting approval
- **WHEN** a player changes their display name
- **THEN** other readers see the placeholder name on that player's reviews until the name has been checked
- **AND** the player sees their new name, marked as "Pending"

#### Scenario: A rejected name
- **WHEN** the check rejects a display name
- **THEN** the name is never shown and the player is asked to pick another

### Requirement: Deleting an account deletes all its data
A player SHALL be able to delete their account. Deletion SHALL remove its sign-ins, display name, ratings, reviews and reports from the account service immediately. The averages on the site SHALL drop the deleted ratings at the next site build.

#### Scenario: Deleting an account removes its reviews immediately
- **WHEN** a player deletes their account
- **THEN** their reviews are no longer served on any mod page
- **AND** the next site build calculates averages without their ratings

### Requirement: Personal data stays out of the public repo
Display names, review text, report text and anything from a sign-in provider SHALL NOT be written into any file the scraper publishes. Only averages and counts SHALL be published.

#### Scenario: Published ratings contain only averages and counts
- **WHEN** a site build runs with rated and reviewed mods
- **THEN** `mods.json` and every `mods/<id>.json` hold rating averages and counts, and no display name or review text

### Requirement: The account service accepts only the site's own pages and the scraper
The account service SHALL answer browser requests only from Starmodder's own address, and from `localhost` while developing. The calls that list waiting reviews, receive verdicts and receive the id map SHALL require the scraper's token. The service SHALL limit how often one account can send ratings, reviews and reports.

#### Scenario: Another site cannot use a player's session
- **WHEN** a page on another site sends a rating to the account service with a player's cookie
- **THEN** the service refuses it

#### Scenario: The scraper's calls need the token
- **WHEN** a request asks for the waiting reviews without the scraper's token
- **THEN** the service refuses it and shows nothing

### Requirement: The site has a privacy page
Starmodder SHALL have a privacy page explaining what the account service stores, why, for how long, and how to delete it. The sign-in screen SHALL link to it.

#### Scenario: Linked from sign-in
- **WHEN** a player opens the sign-in choices
- **THEN** a link to the privacy page is shown beside them
