## MODIFIED Requirements

### Requirement: Snapshots leave out the post text
A bundle snapshot SHALL NOT contain any post's HTML — the first post's or a follow-up post's. Each detail SHALL instead carry a short fingerprint of the first post's text, and each `extraPosts` entry SHALL carry a fingerprint in place of its own HTML, so a post that changed can be reported as changed without the text being kept. Fingerprints SHALL be computed the same way for the first post and for follow-up posts. A snapshot is therefore not a bundle and MUST NOT be published, served, or read as one.

#### Scenario: The post text is not kept
- **WHEN** a snapshot is read back
- **THEN** no post HTML is in it — first post or extra post — and each carries a fingerprint of the text it had instead

#### Scenario: A changed post is still noticed
- **WHEN** a topic's post text changes between two runs
- **THEN** the two snapshots' fingerprints for that topic differ

#### Scenario: A changed follow-up post is still noticed
- **WHEN** a topic's second post changes between two runs and its first post does not
- **THEN** the two snapshots differ in that extra post's fingerprint, and the first post's fingerprint is the same in both

#### Scenario: A snapshot is small enough to keep many of
- **WHEN** a snapshot of the full bundle is written
- **THEN** it is a fraction of the size of the published bundle, in the same range as a merge snapshot
