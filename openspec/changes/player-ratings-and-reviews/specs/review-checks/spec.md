## ADDED Requirements

### Requirement: Reviews and names are checked every hour
The viewer server SHALL start a `checkReviews` job at the interval set by `ratings_check_minutes` (default 60). The job SHALL fetch reviews and display names awaiting checks from the account service, check each with the LLM, and send the verdicts back. A run that found nothing to check SHALL NOT be saved to the run history.

#### Scenario: Nothing waiting
- **WHEN** the hourly job finds no waiting reviews and no waiting names
- **THEN** it ends without adding a run to the history

### Requirement: The job runs only while the LLM server is idle
Before it starts, and again before each review or name, the job SHALL read the LLM server's request log at `ratings_llm_activity_url`. A request with no finish time that started less than `llm_timeout_seconds` ago SHALL count as busy. When the server is busy, the job SHALL stop and leave the rest waiting until its next run. When `ratings_llm_activity_url` is empty, the job SHALL NOT run.

#### Scenario: A coding session is using the model
- **WHEN** the request log shows a request started two minutes ago with no finish time
- **THEN** the job checks nothing and ends

#### Scenario: A scrape starts mid-job
- **WHEN** the job has checked three reviews and a scrape run's request appears in the log
- **THEN** the job stops before the fourth review, and the rest wait for the next run

#### Scenario: A request that never finished
- **WHEN** the only unfinished request in the log started an hour ago and `llm_timeout_seconds` is 900
- **THEN** the job counts the server as idle

#### Scenario: Not set up
- **WHEN** `ratings_llm_activity_url` is empty
- **THEN** the job does not run, and the reviews wait

### Requirement: Each review receives one of four verdicts
Each review SHALL get one verdict: approved; rating kept with no text, for a bug report or a review with no meaningful content; rejected, for insults, slurs, spam, links or a review about another mod; or abusive, when the scores are part of the abuse. A rejected review's scores SHALL still count; an abusive review's scores SHALL NOT. An answer from the LLM that cannot be read SHALL leave the review waiting. A player whose review was not approved SHALL see why on the mod's page.

#### Scenario: A bug report
- **WHEN** a review says only "crashes on load with Nexerelin"
- **THEN** the rating counts, the text is not shown, and the player is told bug reports belong in the mod's thread

#### Scenario: An unreadable answer
- **WHEN** the LLM answers with something that is not one of the four verdicts
- **THEN** the review stays waiting for the next run

### Requirement: The job counts against the LLM limits
The job's calls SHALL go through the same LLM client, endpoint cost rules and concurrency limit as post reading, and SHALL count against `llm_max_topics`.

#### Scenario: Limit reached
- **WHEN** a run reaches `llm_max_topics` calls
- **THEN** it stops and the rest wait

### Requirement: The viewer has a Reviews page
The viewer SHALL have a Reviews page under Corrections. It SHALL list waiting, rejected and reported reviews and names, and SHALL show how long the oldest review or name has been waiting. From it, the user SHALL be able to approve or hide a review, approve or reject a name, block or unblock an account, mark an account as a mod's author, and add or remove a mod from the opt-out list. Each change SHALL be sent to the account service immediately. Blocking SHALL also remove the account's ratings from the averages at the next site build.

#### Scenario: A wrong rejection
- **WHEN** the user approves a rejected review on the Reviews page
- **THEN** the review is served on the mod's page immediately

#### Scenario: A long wait
- **WHEN** the oldest waiting review was sent 30 hours ago
- **THEN** the Reviews page says it has waited 30 hours

### Requirement: The id map is sent after each site build
After each site build, the scraper SHALL send the account service the moved ids, the Collection ids, the taken-down ids, the opted-out ids and each mod's verified authors. The service SHALL serve reviews for a moved id under the mod it moved to, and SHALL NOT serve reviews for a Collection, taken-down or opted-out id. A failure to send the id map SHALL be logged and SHALL NOT fail the build.

#### Scenario: A failed send
- **WHEN** the account service does not answer after a site build
- **THEN** the build still succeeds, and the log says the id map was not sent
