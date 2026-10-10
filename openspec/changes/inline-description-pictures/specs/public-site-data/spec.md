## MODIFIED Requirements

### Requirement: The description is the author's own post, kept formatted
Where a mod has a forum thread, its description SHALL be taken from that thread's post
and published as `descriptionHtml`: a rebuilt piece of HTML holding only paragraphs,
line breaks, lists, headings, quotes, code, emphasis, links and pictures. Anything that
can run and anything that can style the page SHALL be left out. Pictures are the only
thing in it that loads from another host. Each picture SHALL be kept in the place the
post put it, as an `<img>` carrying only an `http` or `https` address, its alt text, the
width and height the post gave it (whole numbers only), `loading="lazy"` and
`referrerpolicy="no-referrer"`. A picture with any other kind of address SHALL be left
out. Every picture SHALL be kept, badges and donation buttons included. The forum's
smileys SHALL still be left out. Links SHALL carry `rel="nofollow noopener"`. A link
whose only content is a picture SHALL be kept. Bare web addresses SHALL be turned into
links. Picture tags SHALL NOT count toward the length at which a long post is cut short.
Where the mod has no forum post, the merged description SHALL be used, and failing that
the AI paragraph, labelled as AI. `description` SHALL keep holding the same words as
plain text, with no pictures.

#### Scenario: A mod on both the forum and Discord
- **WHEN** a mod has a forum post and a Discord announcement
- **THEN** the description is the forum post, not the Discord announcement

#### Scenario: A post carries a script
- **WHEN** the post holds a `<script>` or a `<style>`, or an `<img>` with an `onerror` or `style` attribute
- **THEN** no script, no style and no extra attribute appear in `descriptionHtml`

#### Scenario: A picture between two paragraphs
- **WHEN** a post has a paragraph, a screenshot, then another paragraph
- **THEN** `descriptionHtml` has the picture between the two paragraphs, with its address and nothing that can run

#### Scenario: A download link that is only a badge
- **WHEN** a post's download link holds nothing but a shields.io badge picture
- **THEN** `descriptionHtml` keeps the link with the badge inside it

#### Scenario: A picture with an address that is not a web address
- **WHEN** a post holds an `<img>` whose address starts `javascript:` or `data:`
- **THEN** that picture is left out

#### Scenario: A very long post
- **WHEN** a post runs to tens of thousands of characters
- **THEN** the published description is cut off at a whole block and marked as cut short

#### Scenario: A post with many pictures and few words
- **WHEN** a short post holds forty pictures
- **THEN** the description is not cut short, because picture tags do not count toward the length

### Requirement: The gallery holds screenshots, not badges
A mod's gallery SHALL publish every picture from its posts and announcements, once
each, except the forum's own furniture (smileys, theme graphics and avatars hosted on
the forum), which SHALL never be published. A picture SHALL be marked `small: true`
when it is hosted by a donation or badge service, when its address says it is a
button, badge, avatar, icon or logo, or when the post says it is under 200 pixels wide.
Where a picture's size is not given, nothing SHALL be assumed. The field SHALL only be
written when it is true. A mod with no pictures SHALL be published with no gallery
rather than an empty one.

#### Scenario: A post with a donation button
- **WHEN** a post holds a "Buy me a coffee" button and one screenshot
- **THEN** both are published, and only the button is marked `small: true`

#### Scenario: A forum smiley
- **WHEN** a post holds a picture from the forum's `Smileys` folder
- **THEN** it is not in the gallery at all

#### Scenario: A picture with no size
- **WHEN** a post gives no width for a picture on an ordinary image host
- **THEN** it is published without the `small` field
