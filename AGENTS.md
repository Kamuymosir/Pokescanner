# AGENTS.md

## Cursor Cloud specific instructions

### Overview

PokeScanner Pro is a **single-file, client-side web app** (`pokescanner.html`) with no build step, no package manager, and no server-side dependencies. All code (HTML/CSS/JS) lives in one file.

### Running the app

```
python3 -m http.server 8080 --directory /workspace
```

Then open `http://localhost:8080/pokescanner.html` in Chrome. No build or install step is required.

### External APIs

- **Anthropic Claude API** — powers the Scan tab (AI card identification). Requires an API key entered in the UI.
- **Pokémon TCG API** (`api.pokemontcg.io`) — powers Pokédex search/pricing. No key needed for basic use.
- **TCG Price Lookup API** — optional, for Japanese card prices.

### Lint / Test / Build

There is no linter, test suite, or build system in this repo. The app is a standalone HTML file. Validation is done by opening it in a browser and verifying features work.

### Key caveats

- CDN dependencies (Leaflet, Chart.js) require internet access.
- All user data is stored in `localStorage` — no database.
- The `.gitignore` references Python/Node patterns but no such code exists in the repo.
