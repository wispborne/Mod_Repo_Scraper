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

**Changing the prompt costs a re-read of everything.** `ExtractionPrompt.promptVersion`
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
| 25868 | MagicLib. One mod, and the post names exactly one requirement — a model asked what a mod needs will happily add the rest of the usual libraries. |
| 34161 | Hartley's Miscellaneous Mods. Four mods, each with a name, a paragraph and a download, all in one post. |
| 35651 | Computica's Faction Forks. Seven mods, and every download is a badge image inside a link with no words of its own, in the author's *second* post. The first post also lists forks that are not out yet, which must not become mods. |
| 21968 | Yunru Mods. A library plus five add-ons that each name it, and a paragraph per add-on for `descriptionAnchors` to point at. |
| 34645 | A question thread. Not a mod release at all — `isMod` must be false. |

To add one, copy `qb_data/mods/<id>/detail.json` into `posts/`, drop the
`scrapedAt` field and any `localPath` on the images, and write a test that says
what the post plainly says. Pick threads that are hard in a way that matters —
one that already reads correctly proves nothing.
