## MODIFIED Requirements

### Requirement: Server-side search, filter, and pagination
List endpoints SHALL accept query parameters for text search, filters, sorting, and pagination, and SHALL return only the requested page of results. A `pageSize` of 0 SHALL mean "every matching row, on one page", and SHALL be given only when a caller asks for it — the built-in answer stays a page at a time. A `pageSize` above the server's cap SHALL be capped, and one that cannot be read as a number SHALL fall back to the built-in page size. The server MUST NOT expose an endpoint that returns `forum-data-bundle.json` or all per-topic details in a single response.

#### Scenario: Paged topic search
- **WHEN** the client requests the topic list with a search term and page number
- **THEN** the response contains only the matching rows for that page plus the total match count

#### Scenario: Everything on one page
- **WHEN** the client asks a list endpoint for `pageSize=0`
- **THEN** every matching row comes back in one response, with `page` and `pageSize` both 0 so the caller knows there is nothing left to page through

#### Scenario: An unreadable or enormous page size
- **WHEN** the client asks for a `pageSize` that is negative, not a number, or larger than the cap
- **THEN** the server uses the built-in page size for the first two and the cap for the third, and never fails the request

## ADDED Requirements

### Requirement: Every list lets the reader choose how many rows a page holds
Every paged list in the viewer SHALL offer a choice of rows per page — including all of them on one page — next to its page buttons. The choice SHALL be one setting for the whole site, remembered in the browser between views and across reloads. With every row on one page, the page buttons SHALL NOT be drawn, and the row SHALL say how many rows are being shown rather than which page of how many.

#### Scenario: Reading a long list in one go
- **WHEN** the user picks "all on one page" on the ModRepo list
- **THEN** every matching mod is shown, no page buttons are drawn, and the row says how many there are

#### Scenario: The choice sticks
- **WHEN** the user picks 250 rows on one list and then opens another list, or reloads the page
- **THEN** that list also shows 250 rows a page

#### Scenario: Changing the size goes back to the first page
- **WHEN** the user is on page 4 and changes the rows per page
- **THEN** the list reloads at the first page, so the rows on screen are the ones the new setting describes
