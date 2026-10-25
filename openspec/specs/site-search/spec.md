# site-search Specification

## Purpose
How the public website decides which mods match what a reader typed, on the browse page and in the top-bar suggestion box.
## Requirements
### Requirement: Each mod has a list of search terms

The site SHALL build, once per mod, a list of the things a search can match: the thread title, the tidied display name, the display name broken into its words, the display name with its spaces taken out, the first letters of those words joined as an acronym, every credited author, every other name those authors go by (from `otherAuthorNames`), each person's name with its spaces taken out, every category, the summary, the game version, and the mod version. Every term SHALL be stored already cleaned up, by the same clean-up a typed search goes through.

#### Scenario: An acronym finds a mod

- **WHEN** a reader types "swp" and a mod's display name is "Ship/Weapon Pack"
- **THEN** the mod matches, because "swp" is the acronym of its name's words

#### Scenario: A version finds a mod

- **WHEN** a reader types "0.98" and a mod's game version is "0.98a-RC8"
- **THEN** the mod matches

#### Scenario: A name typed without its spaces

- **WHEN** a reader types `shipweapon` or `consolecommands`
- **THEN** "Ship/Weapon Pack" or "Console Commands" is found

#### Scenario: A person typed without punctuation

- **WHEN** a reader types `darkrevenant` or `Dark.Revenant`
- **THEN** the mods crediting Dark.Revenant are found

#### Scenario: A term must sit inside one fact

- **WHEN** a typed word only appears by running the end of one fact into the start of another (for example, `nexerelincampaign`, from Nexerelin's name and its category "Campaign and exploration")
- **THEN** the mod does not match, because each fact is checked on its own

### Requirement: A typed term matches by substring

Within a comma group, what the reader typed SHALL be split into words at the spaces left after clean-up. Every plain word SHALL match for the group to match. Each word SHALL match by appearing anywhere inside at least one of the mod's search terms, and the words MAY be found in different terms and in any order. A typed word that clean-up turns into several words (for example `seeker-unidentified`) SHALL count as those separate words.

#### Scenario: Part of a word is enough

- **WHEN** a reader types "nex"
- **THEN** every mod with "nex" inside any of its search terms matches, including one named "Nexerelin"

#### Scenario: Words in any order

- **WHEN** a reader types `contact seeker` or `battlestar portrait`
- **THEN** "Seeker - Unidentified Contact" or "Battlestar Galactica - Portrait Pack" is found

#### Scenario: Words from different facts

- **WHEN** a reader types `kadur timid`
- **THEN** the Kadur Remnant credited to Timid is listed first, because "kadur" is in its name and "timid" is its author

#### Scenario: Every word has to match

- **WHEN** a reader types `seeker nexerelin`
- **THEN** no mod is found, because no mod answers both words

### Requirement: Commas mean any of these

The search SHALL split what the reader typed on commas that are outside double quotes. A mod SHALL be listed when it matches **any** comma group that has at least one plain word. Groups that are empty after clean-up SHALL be ignored, and typing nothing SHALL list every mod.

#### Scenario: Two terms widen the list

- **WHEN** a reader types "faction, portrait"
- **THEN** the list holds every mod matching "faction" and every mod matching "portrait"

#### Scenario: Only a comma typed

- **WHEN** the search box holds only "," or spaces
- **THEN** every mod is listed

### Requirement: A leading minus leaves mods out

A word, a quoted phrase or a field term with "-" directly in front of it SHALL be a minus word. A minus word SHALL leave out every mod it matches.

- Inside a comma group that also has plain words, minus words narrow that group only: `pirate -junk` lists mods matching "pirate" that do not match "junk".
- A comma group made only of minus words SHALL take the mods it matches out of the whole list, even when another group let them in.
- When only minus words are typed, the list SHALL be every mod except the removed ones.
- A minus inside a word, such as the one in `hall-a`, is not a minus word.
- A minus on its own SHALL be ignored.
- Minus words SHALL never be guessed at with close spellings.

#### Scenario: Mixing keep and leave out

- **WHEN** a reader types "faction, -portrait"
- **THEN** mods matching "faction" are listed, except any that also match "portrait"

#### Scenario: Leaving out inside one group

- **WHEN** a reader types `seeker -author:tartiflette`
- **THEN** the Seeker mods not credited to Tartiflette are listed, and the ones credited to Tartiflette are not

#### Scenario: Only leaving out

- **WHEN** a reader types "-portrait"
- **THEN** every mod is listed except those matching "portrait"

#### Scenario: A bare minus does nothing

- **WHEN** a reader types "-" on its own
- **THEN** it is ignored and does not empty the list

#### Scenario: A dash inside a word is not a minus

- **WHEN** a reader types `va11 hall-a`
- **THEN** "Va11 Hall-A Portrait Pack" is found

### Requirement: A plus joins terms that must all match

A "+" SHALL mean the same as a space, so every word around it must match. This keeps old links and old habits working. The help panel SHALL NOT offer the plus, since a space already does the same job. A plus with nothing either side of it SHALL be ignored rather than emptying the list.

#### Scenario: Two terms that must both match

- **WHEN** a reader types `hartley + tithes`
- **THEN** only "Useful.Tithes" is listed, the same as for `hartley tithes`

#### Scenario: A plus in a mod's name

- **WHEN** a reader types `starsector+`
- **THEN** "Starsector+" is listed first

#### Scenario: A bare plus does nothing

- **WHEN** a reader types "+" on its own
- **THEN** it is ignored and every mod is listed

### Requirement: A term can ask about one field by name

A word written as `key:value` SHALL be matched against that field alone. The value runs to the next space unless it is in double quotes, as in `author:"dark revenant"`. The value and the field's values SHALL both be cleaned up, and the field matches when the value appears inside any one of them.

The keys SHALL be `name`, `author`, `category`, `version`, `gameversion`, `modversion`, `source`, `url` and `summary`. The plurals `authors`, `categories` and `sources` SHALL be accepted as well. Keys SHALL be read ignoring capitals.

A key the site does not know SHALL fall through to an ordinary search of the whole word, so a mod whose name carries a colon can still be found. A key with nothing after the colon SHALL do the same.

#### Scenario: Asking about one field

- **WHEN** a reader types "author:Wisp"
- **THEN** only mods crediting that person are listed, and not mods that merely mention the word elsewhere

#### Scenario: Punctuation in a field value does not matter

- **WHEN** a reader types `author:dark.revenant`, `author:"Dark Revenant"` or `author:DARK.REVENANT`
- **THEN** each lists exactly the mods crediting Dark.Revenant

#### Scenario: A field a mod's own file holds is not offered

- **WHEN** a field is not carried in the published list file, such as a mod's full description
- **THEN** it is not one of the keys, because the browse page never fetches that file and the search would quietly match nothing

#### Scenario: An unknown key is just words

- **WHEN** a reader types `re: mepgear`, where "re" is not a key the site knows
- **THEN** it is searched as the words "re" and "mepgear", and "Re: mepgear´s bullships" is found

#### Scenario: Fields join up with the rest

- **WHEN** a reader types "category:libraries magic, -source:discord" or "category:libraries, -source:forum"
- **THEN** the field terms take part in the comma, space and minus rules exactly as plain words do

### Requirement: The browse page and the suggestion box search the same way

The browse page's search and the top-bar suggestion box SHALL use the same shared search. A query that finds a mod in one finds it in the other, and the two agree on the order. The suggestion box SHALL show the first few mods from that same order.

- The suggestion box SHALL suggest nothing when no plain word has been typed, or when what is typed cleans up to fewer than two characters.
- The box's list of matching people SHALL be built in the shared search module, from credited authors whose cleaned-up name, or whose name with its spaces taken out, holds every plain word typed. It SHALL list nobody under the same two-character limit as the mods.
- People SHALL be listed by name, never by how many mods they have.

#### Scenario: An acronym suggests a mod

- **WHEN** a reader types "swp" into the top-bar box
- **THEN** "Ship/Weapon Pack" appears among the suggestions

#### Scenario: The better answer is suggested first

- **WHEN** one mod's name is exactly what was typed and another merely holds it somewhere
- **THEN** the exact one is suggested above the other, by the same score the browse page sorts on

#### Scenario: Commas work in the top bar

- **WHEN** a reader types `nexerelin, lazylib` into the top-bar box
- **THEN** both mods are suggested

#### Scenario: Only minus words suggest nothing

- **WHEN** a reader types `-portrait` into the top-bar box
- **THEN** no mods are suggested, because there is nothing to suggest for

#### Scenario: People are matched the same way

- **WHEN** a reader types `dark revenant` or `sir hartley`
- **THEN** Dark.Revenant or SirHartley is offered as a person

### Requirement: The hint says what commas do

The line under the browse page's search box SHALL say, in plain English, that every word must match in any order, that commas list mods matching any of the groups, and that a minus in front of a word leaves mods out.

#### Scenario: Reading the hint

- **WHEN** a reader looks under the search box
- **THEN** the hint explains words, the comma and the minus with an example of each

### Requirement: A panel says what the search understands

Every search box on the site SHALL offer a panel listing what the search understands. It SHALL open with a line naming what it looks at. Then it SHALL have one line each for:

- words in any order
- exact phrases in quotes
- commas
- the minus
- acronyms
- versions
- close spellings
- field search

Each line SHALL be a short name in bold, then how it works, with the letters to type shown as typed. The panel SHALL describe only what the search actually does. It must never offer a way of searching the site does not have, and it SHALL NOT offer the plus.

#### Scenario: The panel is up under the pointer

- **WHEN** a reader rests the pointer anywhere on a search box
- **THEN** the panel appears below it, and stays up while the pointer moves down into the panel to read it

#### Scenario: The panel is up while the box is in use

- **WHEN** a reader puts the cursor in a search box
- **THEN** the panel appears below it and stays there while they type, so it can be read while the search is being written

#### Scenario: It goes when the box is done with

- **WHEN** the reader clicks off the search box
- **THEN** the panel goes away

#### Scenario: A marked button anyone can find

- **WHEN** a reader points at or presses the "?" beside a search box
- **THEN** the panel appears, so somebody with no pointer or no keyboard can still reach it

#### Scenario: The box at the top gives way to the suggestions

- **WHEN** a reader types into the search box in the bar at the top
- **THEN** the panel goes and the suggested mods take that room, and clearing the box brings the panel back

### Requirement: One panel, built in one place

The panel SHALL be built by one shared piece of code used by every search box, so no two boxes can come to describe the search differently.

#### Scenario: The same panel everywhere

- **WHEN** the ways of searching change
- **THEN** they are edited once and every search box on the site says the same thing

### Requirement: A search can be sorted by how well each mod answers

Every word SHALL be scored, not merely matched, and the scores within a group SHALL be added. For one word, from best to worst:

1. a fact that is exactly the word
2. a fact that starts with it
3. a fact with a word inside it that starts with it
4. a fact that merely holds it somewhere

A match on a fact further from the mod's identity (a category, a version, the summary) SHALL score below the same kind of match on its name or the people credited. A field asked about by name SHALL score as well as the mod's own name does.

Each group SHALL also get a bonus:

- the largest bonus when all its plain words, in order, are exactly the mod's name, title or one of its nicknames (compared both with and without spaces)
- a smaller bonus when the name or title starts with them
- a smaller bonus still when they appear in order somewhere else inside the name or title

Where several comma groups let a mod in, the best-scoring group SHALL speak for it. Ties SHALL be broken by name.

#### Scenario: An exact answer beats a partial one

- **WHEN** a reader types the initials of one mod's name, which another mod merely contains
- **THEN** the mod whose initials are exactly that is listed first

#### Scenario: The exact name comes first

- **WHEN** a reader types `console commands`, `tolerant luddic majority` or `brighton federation`
- **THEN** the mod with exactly that name is listed above "Additional Console Commands", "More Tolerant Luddic Majority" or "The Brighton Federation"

#### Scenario: A name that starts with the search beats one that holds it later

- **WHEN** a reader types `qol`
- **THEN** "QoL Pack" is listed above "Dark QOL"

#### Scenario: The start of a word beats the middle of one

- **WHEN** a reader types `sector`
- **THEN** "Vayra's Sector" is listed above "Starsector+"

#### Scenario: The browse page offers Best match while searching

- **WHEN** a reader types into the browse page's search box
- **THEN** a "Best match" sort appears and is chosen for them, and the list is ordered by how well each mod answers

#### Scenario: Best match is not offered with an empty box

- **WHEN** the search box is empty
- **THEN** "Best match" is not among the sorts, and the list falls back to the usual order

#### Scenario: A sort chosen by hand is kept

- **WHEN** a reader picks another sort while searching and then types more
- **THEN** their sort is kept rather than being taken back to Best match

### Requirement: Typed text and mod facts are cleaned up the same way

Before anything is compared, both what the reader typed and every fact about a mod SHALL go through one shared clean-up:

- capitals become lowercase
- accents are taken off ("é" becomes "e")
- full-width letters become ordinary ones
- apostrophes are removed without leaving a gap. That covers `'`, `’`, `‘`, `´` and the backtick.
- every other character that is not a letter or a digit becomes a space. That includes dashes of every length, slashes, colons, brackets, plus signs and symbols such as ™.
- a dot stays only when it sits between two digits, so versions such as "0.98a" survive
- runs of spaces become one space, and spaces at either end are trimmed

Letters from any alphabet SHALL be kept, not only a to z, so a name written in another script can still be searched.

#### Scenario: Punctuation in a name does not hide it

- **WHEN** a reader types `seeker unidentified contact`
- **THEN** "Seeker - Unidentified Contact" is found and listed first

#### Scenario: Apostrophes are ignored

- **WHEN** a reader types `amazighs`, `amazigh's` or `amazigh’s ship`
- **THEN** "Amazigh's Ship Foundry" is found

#### Scenario: Accents are ignored

- **WHEN** a reader types `espanol`
- **THEN** "Starsector en Español" is found

#### Scenario: A version keeps its dots

- **WHEN** the text "0.98a-RC8" is cleaned up
- **THEN** it becomes "0.98a rc8", so a search for `0.98` still matches it

#### Scenario: Text that is nothing but punctuation

- **WHEN** a reader types only punctuation, such as `---`, `!!!` or `""`
- **THEN** there is nothing to look for and every mod is listed

### Requirement: Double quotes keep a phrase together

Text inside double quotes SHALL be one phrase. After clean-up, the phrase SHALL match only where it appears whole and in order inside a single fact about the mod. A quote with no closing mark SHALL run to the end of its comma group. Commas inside quotes SHALL be part of the phrase, not separators.

#### Scenario: A phrase in order

- **WHEN** a reader types `"unknown contact"`
- **THEN** "Seeker - Unknown Contact" is found and "Seeker - Unidentified Contact" is not

#### Scenario: A phrase out of order

- **WHEN** a reader types `"contact unknown"`
- **THEN** no mod is found

#### Scenario: A comma inside a phrase

- **WHEN** a reader types `"church quest, ship"`
- **THEN** "Knights Hospitaller - Unique Luddic Church Quest, Ship, Questline" is found

### Requirement: Common shorthand finds mods

People rarely type a mod's whole name. The search SHALL find a mod from the shorthand the community uses for it, in four ways:

- **The start of the name**, which plain matching already gives: `nex` finds Nexerelin.
- **Initials**: the first letter of each word of the name, with the little words kept or left out. `kol` finds The Knights of Ludd, `uaf` finds United Aurora Federation.
- **Word starts run together**: a typed word of three letters or more that can be built from the starts of words standing next to each other in the name, in order. Little words in between may be skipped. Either every piece is a single letter, or every piece except the last is two letters or more. `indevo` (Ind-ustrial Evo-lution) finds Industrial.Evolution, and `grandcol` finds Grand.Colonies. "f" + "action" is not a way anybody writes Fleet Action History, so `faction` does not find it.
- **Capitals inside a word** count as word breaks for initials, so `gl` finds GraphicsLib and `ml` finds MagicLib.

The other names the author's own post uses for a mod, published on its record as `nicknames`, SHALL be matched too. Where none of these gives the name away (`ssp` for Starsector+, `brdy` for Blackrock Drive Yards), a short hand-kept nickname table SHALL give it. The table is keyed by the mod's permanent id. A nickname from either place SHALL score as well as the mod's own name.

Word starts run together SHALL score below a match on the name itself. A typed word that is exactly a mod's initials SHALL score as well as a name that starts with the search.

#### Scenario: Word starts run together

- **WHEN** a reader types `indevo`
- **THEN** Industrial.Evolution is listed first

#### Scenario: Initials with a little word left out

- **WHEN** a reader types `kol`
- **THEN** The Knights of Ludd is listed first

#### Scenario: Capitals inside a name

- **WHEN** a reader types `gl`
- **THEN** GraphicsLib is listed first

#### Scenario: A nickname the author's post uses

- **WHEN** a mod's record carries `"nicknames": ["IndEvo"]` and a reader types `indevo`
- **THEN** that mod is listed first

#### Scenario: A nickname from the table

- **WHEN** a reader types `ssp` or `brdy`
- **THEN** Starsector+, or both Blackrock Drive Yards mods, are listed first

#### Scenario: A real name beats shorthand that spells the same letters

- **WHEN** a reader types `rat`
- **THEN** the mod called "RAT" is listed first, and Random Assortment of Things, whose initials those are, is listed after it

#### Scenario: Ordinary words are not read as shorthand

- **WHEN** a reader types `faction`
- **THEN** Fleet Action History is not listed

#### Scenario: Two letters are only ever a whole name's initials

- **WHEN** a reader types two letters, such as `ae`
- **THEN** a mod whose initials are exactly those letters is found, and no run of word starts is tried

### Requirement: Close spellings are found

A typed word SHALL also match a word of a mod's name, or a word of a credited person's name, that is spelled almost the same way. A swap of two letters next to each other SHALL count as one mistake. The rule SHALL apply only:

- to typed words of five letters or more
- to typed words with no digits in them
- when that word does not already match the mod's name or people exactly
- when the first letter is right. Almost every typo keeps it, and without this rule `faction` would be one letter away from "action".

A word of five to seven letters SHALL allow one mistake. A word of eight letters or more SHALL allow two. A typed word SHALL also count as close when it is that close to the start of a name word of the same length, so a half-typed word with a mistake in it is still found. A close match SHALL score below an exact match on the name or a person, but above a match that only appears in the summary.

#### Scenario: A missing letter

- **WHEN** a reader types `nexerlin`
- **THEN** Nexerelin is found

#### Scenario: Two letters swapped

- **WHEN** a reader types `tahaln`
- **THEN** Tahlan Shipworks is found

#### Scenario: A misspelt person

- **WHEN** a reader types `tartiflete`
- **THEN** the mods crediting Tartiflette are found

#### Scenario: A misspelling that is in somebody's summary

- **WHEN** a reader types `nexerellin`, which one mod's summary spells that way
- **THEN** Nexerelin is found and listed above the mod whose summary holds the misspelling

#### Scenario: The first letter has to be right

- **WHEN** a reader types `rexerelin`
- **THEN** nothing is found

#### Scenario: Short words are not guessed at

- **WHEN** a reader types a word of four letters or fewer that no mod holds
- **THEN** nothing is found, rather than a guess

#### Scenario: Common words bring in nothing extra

- **WHEN** a reader types a common word such as `portrait`, `pirate` or `faction`
- **THEN** every mod listed really holds that word, and no mod is let in by a close spelling

#### Scenario: A real near-miss is listed below the real names

- **WHEN** a reader types `collection`, which is two letters away from "Collective"
- **THEN** "Apex Design Collective" may be listed, but below every mod whose name really holds "collection"
