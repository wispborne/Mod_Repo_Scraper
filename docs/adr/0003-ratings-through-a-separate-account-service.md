# A separate account service for ratings and reviews

Players can sign in to Starmodder to rate and review mods. The site's pages and data remain static files, built twice a day. Any static host can serve them. A separate service handles signing in, sending ratings and reviews, and reading review text. It is a Cloudflare Worker with its own database at its own address. The scraper gets new reviews from the service. It checks each review with the local LLM and sends the result back. The service shows only approved reviews. The scraper calculates rating averages and writes them into the site's static files. Pages read the averages like any other site data.

The site reads review text and display names from the service. These are kept out of the site's files because those files are committed to a public git repo. A deleted review or name would remain in the repo's history. Averages contain no personal information, so they can be stored in the site's files.

The revamp plan said "no accounts, comments, ratings or endorsements". This decision replaces that restriction. The site spec also limits the site to fetching data from its own address. This decision allows an exception for signing in, sending ratings and reviews, and reading review text.

## Considered options

- **A Pages Function at the site's own address.** This is the simplest option to set up. It ties the site to Cloudflare, though. The site must be able to move to any static host.
- **A service on the home server.** Public traffic can reach it only through the VPS. Tinyauth protects every `*.wispborne.com` address there. The service would also go down whenever the home internet connection does.
- **Checking reviews in the service as they arrive.** This needs a paid or Cloudflare-hosted model. It also needs a separate set of review rules. The checks would happen in the service instead of the scraper, which lets you see each run and what it did.
- **Writing review text into the site's files.** This keeps the site fully static. Deleted reviews would remain in the public repo's git history. We also ruled out periodically rewriting that history because it would be too easy to break.

## Consequences

- A new review is public only after the scraper checks it. The player's own browser shows it immediately as awaiting approval.
- If the service is down, mod pages still load with their averages. Players cannot read reviews, sign in or send new ratings.
- The viewer lists every rejected review. A person can approve a review that was rejected by mistake.
