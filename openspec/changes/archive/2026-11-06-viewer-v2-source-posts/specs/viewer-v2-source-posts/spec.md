## ADDED Requirements

### Requirement: Source posts list
The Source posts page SHALL list forum topics and Discord threads together, with search, filters, sorting and paging kept in the address. The data quality numbers (no download found, no LLM answer, placeholder posts) SHALL be shown at the top, each opening the list with its filter. Each row SHALL show what happened to the post in a few words. While the manager is on, posts SHALL have tick boxes that keep their selection across pages and reloads in the tab. The per-post jobs SHALL act on the selected posts after a confirmation that says in one sentence what will happen. A job that works only on forum topics SHALL say how many of the ticked posts it will act on. With the manager off, there SHALL be no tick boxes and no job buttons.

#### Scenario: Ticking across pages
- **WHEN** the user ticks two topics on page 1 and one thread on page 2, then presses Re-run LLM and confirms
- **THEN** one `extractLlm` job is sent with the two topic ids and the thread id

#### Scenario: A data quality number
- **WHEN** the user presses "No LLM answer" at the top
- **THEN** the list shows only posts with no LLM answer, and the address says so

### Requirement: Source post page
Each forum topic and Discord thread SHALL have a page with breadcrumbs, a one-line statement of what happened to the post, the LLM's mods with their downloads and extras, the rules' downloads, the pictures grouped by post with their AI descriptions, the posts in sandboxed frames, the warning when the published bundle is behind with its Rebuild button, the per-post job buttons, a link to its history, a Take down button that adds pending changes, and raw JSON at the end. The forum topic's history SHALL be its own page under the post.

#### Scenario: A Discord thread
- **WHEN** the user opens `#/posts/discord/<id>`
- **THEN** the page shows the thread's messages, attached files, the LLM's answer, what happened to it, and Re-run LLM

#### Scenario: Searching a forum address
- **WHEN** the user pastes a forum topic address into the search box
- **THEN** the new viewer opens that topic's source post page
