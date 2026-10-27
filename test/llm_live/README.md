# Live-model tests

These run the real LLM against real forum posts and check what it pulls out.
Every other test in this repo feeds the extractor a canned answer; these are the
only ones that check the **prompt** rather than the code around it.

## Running them

They are skipped by `dart test`. To run them:

```bash
dart test test/llm_live --tags llm --run-skipped
```

They need a model server on `llm_base_url` serving `llm_model` — the same two
settings the real runs use, read from `config.properties`. Override either
without touching that file:

```bash
LLM_BASE_URL=http://localhost:8080/v1/chat/completions LLM_MODEL=my-model dart test test/llm_live --tags llm --run-skipped
```

If the server isn't there, or doesn't offer that model, each test skips itself
and says which of the two it was. Nothing fails.

Expect a few minutes: one thread is one call, and a 30B-class model takes about
20 seconds over a 5,000-token post.

## When one fails

**Read the failure message first.** Every check prints everything the model
said — the mods it named, their roles, their downloads, their versions and
their requirements. That is usually enough to see what went wrong without
running it again by hand.

**Then run it again.** The model is not deterministic, even at temperature 0:
a different build of llama.cpp, a different quantisation, or a different batch
size will change an answer. A check that fails once and passes twice is noise.
A check that fails most times is the prompt asking to be tightened.

**Tighten the prompt, not the test.** The checks here are written to be
loose about wording and strict about facts: names are compared on letters and
digits only, and a download is checked by the bit of its address that says
which mod it is. If a check is failing on wording, loosen that one check. If it
is failing on a fact — the wrong number of mods, a download under the wrong
mod, the game version reported as the mod's own — that is a real miss, and the
fix goes in `lib/bot/scraper/qb/llm/prompt.dart`.

**Changing the prompt means a re-read of everything.** `ExtractionPrompt.promptVersion`
is part of the cache key, so bumping it makes the next run read all ~1,000
stored topics again. Bump it anyway — a prompt change that doesn't reach the
stored topics isn't a fix.

## The saved posts

`posts/<topic id>.json` are real `detail.json` files, copied out of a real
scrape and stripped of the local image paths and the scrape timestamp. They are
kept as they came so the tests are about what authors actually write, not about
posts written to be easy.

| Topic | Why it is here |
| --- | --- |
| 9175 | Nexerelin. One mod, plainly written. The control: if this one goes wrong, something big is broken. Also checks the mod's own version is not the game version, and that `needs` is read off the requirements line. |
| 25868 | MagicLib. One mod, and the post names exactly one requirement — a model asked what a mod needs will happily add the rest of the usual libraries. The post also writes `MagicRender … (aka "SpriteRenderManager")`, another name for one *part* of the library, which must not become a nickname for MagicLib. |
| 36165 | People's Commons. "Requires LazyLib 3.0.0 and MagicLib 1.5.6. Optional: Nexerelin, Combat Chatter." The two optional mods must be in `optionalNeeds` and absent from `needs`. Required mods must be absent from `optionalNeeds`. |
| 34161 | Hartley's Miscellaneous Mods. Four mods, each with a name, a paragraph and a download, all in one post. |
| 35651 | Computica's Faction Forks. Seven mods, and every download is a badge image inside a link with no words of its own, in the author's *second* post. The first post also lists forks that are not out yet, which must not become mods. |
| 21968 | Yunru Mods. A library plus five add-ons that each name it, and a paragraph per add-on for `descriptionAnchors` to point at. One pack is "Formerly known as the Pirate Collection", so that old name must land in that pack's `nicknames` and no other mod's. |
| 9583 | Tiandong Heavy Industries. A spoiler holds a long changelog covering several versions. "1.2.1" first appears inside the 1.2.1a notes, before its own heading. The model must give each entry's first and last words, and the extracted notes must come from under that entry's heading. The two downloads are the first two links, followed by a dozen links to other mods. This also checks for wrong link numbers. |
| 27785 | Customizable Star Systems. One sentence answers two save questions — safe to add, and safe to remove — and the model once copied the whole sentence into both fields. |
| 36143 | Extra Systems Reloaded. A single-mod thread with a focused "WHAT DOES THIS MOD DO?" introduction. Extract that passage for an author-written listing summary with summaries both on and off, while also returning an independent generated summary when enabled. |
| 35155 | QBMBAMM, a mod manager. A program made for Starsector but run beside it, not loaded into it: `isMod` must be true, so the thread is kept, and its one entry must be `isTool`, so TriOS never tries to install it as a mod. The prompt used to call tools non-mods. |
| 33489 | Draconis Fleet. The credits list a composer, an artist and a playtester, each with "Support him here!" beside their links. Those support somebody else, so `supportLinks` must not take them — only links that support the mod's own author count. |
| 10982 | GraphicsLib. The author's donate link is a picture button with no words of its own and none around it, on a host no rule recognises. It must still be kept as a support link, and given a `label`, since that label is the only name the button will have. The check against Draconis must not cost this one. |
| 34645 | A question thread. Not a mod release at all — `isMod` must be false. |
| 28428 | AI Tweaks. "Improvements focused on ship AI and AI-assisted player support" is what the mod does in the game. It is not a statement about AI tools, so `aiUse` must be empty. |
| 25905 | AI Portraits of AI Cores. The title is about AI cores, which is game AI. The post also says the portraits were generated with Stable Diffusion, which is AI use. `aiUse` must hold portraits and nothing else. |
| 18751 | Arma Armatura. One credits paragraph names five uses: optional portraits made with DALL·E 3 and edited, voice lines and illustrations made with ElevenLabs, and LLM help with writing and code. It also says every sprite is human work, so sprites must not be listed. |
| 31982 | Nightcross Armory. "This mod contains zero AI generated content." `usesAi` must be false with no uses. That is a statement, not an unknown. |
| 19830 | Persean Chronicles. Two AI uses, each on its own line starting with "- ": portraits and illustrations, both edited by hand. The model joins the two lines without the "- " marks, so this checks the quote is still found in the post. |
| 22826 | Junk Yard Dogs. Its credits line names the AI tool, and a separate section is headed "Optional AI generated JYD Portraits". The portraits must be marked optional even when the quote is the credits line. |
| 33509 | Halo Dynamics, an English translation. AI helped with the translation only, and the post names DeepL, ChatGPT and DeepSeek. Translation must be the only area, and it must not be marked as generated. |
| 36167 | Astral Ascension Renewed. "Claude Code built this anyway." The quote names no amount, but it says the tool made the whole mod, so the code's extent must be "all". |
| 36176 | Slay the Sector. A long AI disclaimer, over 1,000 characters, that goes through the mod part by part. AI wrote most of the code. The banner on the forum post was AI art, but "Nothing in the mod itself uses AI art", so code must be the only area. |

## The saved Discord threads

`discord/<thread id>.json` are real threads as `discord-posts.json` holds them:
the name, the author, and the author's opening run of messages. They were read
back from a recording of Discord's own answers, so they are what authors really
post. Discord announcements are much shorter than forum posts, and the prompt
was written against the forum, so these check it reads them too.

| Thread | Why it is here |
| --- | --- |
| 1255421874075336824 | Adjustable S-Mods. One plain announcement: one mod, one download, a requirements line and "Not safe to remove". The Discord control. |
| 1257247685723820112 | Retrofitted Bridge. The announcement, then two later messages by the author announcing v0.0.2 and what it changed. Those later messages are the mod's changelog and version. |
| 1247514078101114911 | Gamma Wars. One faction mod and its "UNGP Rule Addon", each with its own download. The add-on must not become a second main mod. |
| 1271590391065477143 | All the Domain Drones+. Two independent mods in one announcement, "Vanilla" and "New Drones", each with its own download. Both must be `main`, and each download must sit under its own mod. |
| 1359352557348065311 | Galactic Constellate. One mod offered as two builds, one for 0.98 and one for 0.97. That is one main mod, not two. The post also says "Safe to add mid-save but cannot be removed", which is one answer for each of two save questions. |
| 1447000749992312953 | Eridani Combine. The announcement links the BoxUtil build it needs. BoxUtil is a mod of its own, so it must be a requirement, not a second main mod, and its zip must not be offered as Eridani's download. |
| 1403520779907498095 | Wide Horizons. The announcement was edited up to 1.3.0g, and the messages after it are older 1.2.2 patch notes. The version is 1.3.0g: the newest message is not the newest version. Also says 1.3.x is not save-compatible with 1.2.x. |
| 1203417843732058202 | Hiver Swarm. The announcement, then one short message per release, ending with "v1.1.7 - Save compatible". The current version and the update note both come from that last message. Also keeps the author's Ko-fi link. |
| 1355300468968001586 | TriOS. A launcher, so a tool, with a download for Windows, Linux and macOS. That is one entry with three downloads, not three mods. |
| 1321884585096777840 | Library of Ruina Portrait Pack. One pack, plus an optional "Distortions" pack as a separate download, which must not be added to the main pack's downloads. |
| 1203053249377079297 | The channel's pinned "Example Mod" template, with a made-up download. It is not a mod. The model currently says it is: on two runs it listed "Example Mod" with its fake download. The site's page for it comes from the Discord reader, not the LLM, so the real fix is for the reader to skip this thread. |

To add one, take the thread's entry out of `qb_data/discord-posts.json` as it
is. Pick threads that are hard in a way that matters.

To add a forum post, copy `qb_data/mods/<id>/detail.json` into `posts/`, drop the
`scrapedAt` field and any `localPath` on the images, and write a test that says
what the post plainly says. Pick threads that are hard in a way that matters —
one that already reads correctly proves nothing.
