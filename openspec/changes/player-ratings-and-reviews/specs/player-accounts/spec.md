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
An account SHALL be shown on the site under the player's chosen display name. A new or changed name SHALL be checked by the review check job before it is shown; until then, the site SHALL show "Unnamed player" to everyone but the player. The site SHALL NOT show which providers an account signs in with, and SHALL NOT show any name, email address or id from a provider.

#### Scenario: A name awaiting approval
- **WHEN** a player changes their display name
- **THEN** other readers see "Unnamed player" on that player's reviews until the name has been checked
- **AND** the player sees their new name, marked as "Pending"

#### Scenario: A rejected name
- **WHEN** the check rejects a display name
- **THEN** the name is never shown and the player is asked to pick another

### Requirement: Deleting an account deletes all its data
A player SHALL be able to delete their account. Deletion SHALL remove its sign-ins, display name, ratings, reviews and reports from the account service immediately. The averages on the site SHALL drop the deleted ratings at the next site build.

#### Scenario: Deleting an account removes its reviews immediately
- **WHEN** a player deletes their account
- **THEN** their reviews are no longer served on any mod page
- **AND** the next site build calculates averages without their ratings and leaves them out of `ratings-export.json`

### Requirement: Personal data stays out of the public repo
Display names, report text, review text that is waiting or rejected, account ids, and anything from a sign-in provider SHALL NOT be written into any file the scraper publishes. Ratings and approved review text SHALL be published only under a player code: a hash of the account's id with a secret only the account service holds, the same on every mod. The rating export SHALL contain no account ids or display names.

#### Scenario: Published ratings carry codes, not names
- **WHEN** a site build runs with rated and reviewed mods
- **THEN** `ratings-export.json` holds each rating under a player code, and no published file holds a display name, an account id or an unapproved review

#### Scenario: One player, one code
- **WHEN** one account rates three mods
- **THEN** all three ratings in `ratings-export.json` carry the same player code

### Requirement: The service asks only for the permissions it needs
The account service SHALL ask Discord only for `identify`, GitHub for no extra permission, and Google only for `openid`. It SHALL NOT ask for or store an email address. A session SHALL last 90 days.

#### Scenario: No email address
- **WHEN** a player signs in with Google
- **THEN** the service stores Google's id for them and nothing else from Google

### Requirement: Display names follow rules
A display name SHALL be 3 to 32 characters of letters, digits, spaces and `. _ -`. Names SHALL be unique, ignoring capitals. A name that matches an author credited on any mod, by the rules takedowns use for author names, SHALL be refused unless the account is a verified author of that author's mods. Until a name is approved, other readers SHALL see "Unnamed player".

#### Scenario: Posing as an author
- **WHEN** a player who is not a verified author of Histidine's mods picks the name "histidine"
- **THEN** the name is refused

#### Scenario: A name already taken
- **WHEN** a player picks "Fleet Admiral" and another account is already "fleet admiral"
- **THEN** the name is refused

### Requirement: Delete old rejected text and resolved reports
Rejected review text SHALL be deleted 30 days after it was rejected. Its scores SHALL stay. A report SHALL be deleted once its review is dealt with in the viewer, or when the review is deleted. The account service SHALL keep no IP addresses and no request logs of its own.

#### Scenario: An old rejection
- **WHEN** a review was rejected 31 days ago and nobody approved it
- **THEN** its text is gone and its scores still count

### Requirement: Limits per account
An account SHALL be able to send at most 30 ratings or reviews an hour, 10 reports an hour and 3 display name changes a day. The service SHALL refuse requests over these limits and tell the player when to try again.

#### Scenario: Too many ratings
- **WHEN** an account sends its 31st rating within an hour
- **THEN** the rating is refused and the player is told when they can rate again

### Requirement: The service's data is copied privately every day
The first site build each day SHALL download a full copy of the account service's data to `qb_data/ratings-backup/`, keeping the newest 14 copies. The copies SHALL never be published. A failed copy SHALL be logged and SHALL NOT fail the build.

#### Scenario: Two weeks of copies
- **WHEN** a copy is saved and 14 copies already exist
- **THEN** the oldest copy is deleted

### Requirement: The account service accepts only the site's own pages and the scraper
The account service SHALL answer browser requests only from Starmodder's own address, and from `localhost` while developing. The calls that list waiting reviews, receive verdicts, receive the id map, export ratings and make the daily copy SHALL require the scraper's token. The service SHALL limit how often one account can send ratings, reviews and reports.

#### Scenario: Another site cannot use a player's session
- **WHEN** a page on another site sends a rating to the account service with a player's cookie
- **THEN** the service refuses it

#### Scenario: The scraper's calls need the token
- **WHEN** a request asks for the waiting reviews without the scraper's token
- **THEN** the service refuses it and shows nothing

### Requirement: The site has a privacy page
Starmodder SHALL have a privacy page at `privacy/`, built from `site/index.html` like the install guide. It SHALL explain what the account service stores, why, for how long, and how to delete it. It SHALL say that approved reviews and all ratings are published under a player code, that a deleted review's older copies stay in the published repo's history, and that a deleted account is gone from the private copies within 14 days. The sign-in screen, the review box and About SHALL link to it.

#### Scenario: Linked from sign-in
- **WHEN** a player opens the sign-in choices
- **THEN** a link to the privacy page is shown beside them
