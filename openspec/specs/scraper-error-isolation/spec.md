# scraper-error-isolation Specification

## Purpose
Define per-item error isolation requirements for the QB scraper pipeline so that a single malformed topic, post, or URL does not crash an entire scraping run. Errors SHALL be caught at the narrowest practical boundary, logged with identifying context, and allow remaining work to continue.

## Requirements

### Requirement: QB scraper engine per-topic error isolation
The QB scraper engine SHALL catch and log exceptions during per-topic processing so that one topic failure does not crash the entire scraping job.

#### Scenario: Topic processing throws in pipelined batch
- **WHEN** `_processTopicDetail` throws for a single topic
- **THEN** the system SHALL log a warning with the topic ID, skip that topic, and continue processing remaining topics

#### Scenario: Awaiting pending futures with failures
- **WHEN** one or more futures in the pending batch have failed
- **THEN** the system SHALL catch each failure individually, log warnings, and continue draining the remaining futures

### Requirement: QB mod index scraper per-post error isolation
The QB mod index scraper SHALL catch and log exceptions during per-post category extraction so that one malformed post does not break the entire category map.

#### Scenario: Malformed category post
- **WHEN** `_extractTopicCategoriesFromPost` throws for a single post
- **THEN** the system SHALL log a warning with the post index, skip that post's categories, and continue processing remaining posts

### Requirement: Error logging with context
All per-item error catches in the QB package SHALL log at warning level with sufficient context to identify and diagnose the failed item.

#### Scenario: Error log includes identifying context
- **WHEN** a per-item exception is caught and logged
- **THEN** the log message SHALL include at minimum: the item identifier (topic ID, URL, or post index) and the exception message
