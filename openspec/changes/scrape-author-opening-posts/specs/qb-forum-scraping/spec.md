## MODIFIED Requirements

### Requirement: QB mod detail model
The system SHALL define a `QbModDetail` data class with fields: topicId, title, category, gameVersion, author, authorTitle, authorPostCount, authorAvatarPath, postDate, lastEditDate, contentHtml, images (List<ImageRef>), links (List<LinkRef>), extraPosts (List<QbForumPost>), scrapedAt, isPlaceholderDetail. `ImageRef` SHALL have: originalUrl, localPath, alt. `LinkRef` SHALL have: url, text, isExternal. `QbForumPost` SHALL have: contentHtml, images (List<ImageRef>), links (List<LinkRef>), postDate, lastEditDate. The first post's data SHALL remain in the existing flat fields; `extraPosts` SHALL hold only follow-up posts and SHALL default to an empty list, so detail files written before the field existed deserialize unchanged.

#### Scenario: Serialize mod detail to JSON
- **WHEN** a `QbModDetail` is serialized
- **THEN** nested `ImageRef`, `LinkRef`, and `QbForumPost` lists SHALL be included inline with camelCase keys

#### Scenario: Old detail file without the field
- **WHEN** a detail JSON written before `extraPosts` existed is deserialized
- **THEN** `extraPosts` SHALL be an empty list and every other field SHALL read as before

### Requirement: Topic scraper
The system SHALL scrape individual topic pages to extract the thread author's opening run of posts, producing `QbModDetail` objects. The opening run is the first post plus each directly following post whose author equals the first post's author, stopping at the first post by any other author, capped at 10 follow-up posts. The first post SHALL fill the existing flat fields exactly as before; each follow-up post SHALL become an `extraPosts` entry with its own content HTML, images, links, post date, and last-edit date, extracted by the same rules as the first post's.

#### Scenario: Extract OP content
- **WHEN** a topic page is fetched
- **THEN** the system SHALL extract `div.post div.inner` innerHTML as content HTML

#### Scenario: Reserved second post is kept
- **WHEN** the second post on the page is by the same author as the first (for example a "Downloads" post holding the thread's download links)
- **THEN** it SHALL be stored as an `extraPosts` entry with its own HTML, images, links, and dates, and the first post's fields SHALL be unaffected

#### Scenario: Another author's reply stops the run
- **WHEN** the second post is by a different author and the third is by the thread author again
- **THEN** `extraPosts` SHALL be empty — only consecutive same-author posts from the top are kept

#### Scenario: Follow-up post cap
- **WHEN** the author's opening run exceeds 10 follow-up posts
- **THEN** only the first 10 follow-up posts SHALL be kept

#### Scenario: Resolve lazy-loaded images
- **WHEN** `<img>` tags have `src` containing `loading.gif`
- **THEN** the system SHALL check `data-imageurl`, `data-src`, `data-original` attributes; if absent and `alt` matches a URL pattern, use `alt`

#### Scenario: Extract title
- **WHEN** parsing a topic page
- **THEN** title SHALL come from `#top_subject`, stripping "Topic:" prefix and "(Read N times)" suffix

#### Scenario: Extract author info
- **WHEN** parsing the first post
- **THEN** author name from `div.poster h4 a`, rank from first `ul li`, post count from "Posts:" li, avatar from `img.avatar`

#### Scenario: Extract images and links
- **WHEN** processing content HTML (first post or a follow-up post)
- **THEN** images SHALL be extracted via regex (skipping smileys, icons, data: URIs); links SHALL be extracted via regex (skipping spoiler ranges, # anchors, javascript: hrefs), with HTML-decoded hrefs

#### Scenario: Board-3 quality gate
- **WHEN** a topic is from board 3 with no external file-hosting links (excluding forum, Nexus, YouTube) across the whole opening run
- **THEN** it SHALL be skipped
