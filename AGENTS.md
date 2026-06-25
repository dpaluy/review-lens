# AGENTS.md

Shared instructions for any coding agent (human or AI) working in this repo.

The product spec of record is `docs/prd.md`. Read it before making non-trivial
decisions. This file is a quick-reference companion, not a replacement.

## Project

**ReviewLens AI** — a review intelligence portal. An analyst pastes one B2B
software-review platform URL (GetApp primary, G2 smoke-test, manual import
fallback), the app ingests the public review corpus into PostgreSQL, then lets
the analyst ask grounded questions answered *only* from the ingested reviews,
with supporting review IDs and explicit refusals for out-of-scope questions.

This is a hiring exercise. Three explicit review criteria: (1) deployed product,
(2) evidence-grounded answers with guardrails, (3) committed AI transcripts under
`/ai-transcripts`. Do not optimize for generic chatbot behavior.

## Stack — do not deviate without a reason

- Rails 8.1.x monolith, Ruby 4.0.5 (`.ruby-version`).
- PostgreSQL only (primary + Solid Queue / Solid Cache / Solid Cable as separate
  DBs in production). No Redis.
- Hotwire/Turbo + Stimulus, ERB views, Tailwind CSS, Importmap JS.
- Active Job via Solid Queue. Two processes: `web` (bin/rails server) and
  `worker` (bin/jobs).
- OpenAI for AI calls, using **Structured Outputs** for schema-bound JSON. RubyLLM
- Deploy: Kamal + DigitalOcean, Docker. `config/deploy.yml`, `.kamal/secrets`.

Hard "no" list from the PRD: no React, no Next, no LangChain, no full vector DB
unless everything else is done, no multi-platform, no user accounts, no scheduled
crawls, no auth.

## Commands

```bash
bin/setup            # bundle install + db:prepare (+ optional --reset)
bin/dev              # web (puma) + tailwind watcher via foreman, PORT default 3000

bin/rails test                 # minitest, parallelized
bin/rails test:system          # capybara + selenium-webdriver
bin/rails db:test:prepare      # run before tests in CI
bin/rails db:prepare           # create + migrate dev DB

bin/rubocop          # Omakase style (rubocop-rails-omakase), use -f github for CI
bin/brakeman         # static security scan
bin/bundler-audit   # gem CVE audit (config in config/bundler-audit.yml)
bin/importmap audit  # JS dependency audit
bin/ci               # local CI runner helper
```

CI (`.github/workflows/ci.yml`) runs four jobs: `scan_ruby`, `scan_js`, `lint`,
`test`, `system-test`. Postgres is provided as a service with
`DATABASE_URL=postgres://postgres:postgres@localhost:5432`. Keep all five green.

### Env vars (production)

`RAILS_MASTER_KEY`, `DATABASE_URL`, `OPENAI_API_KEY`, `OPENAI_MODEL`,
`RAILS_ENV=production`. Secrets never go in code; use credentials/`.kamal/secrets`.

## Architecture

Keep service boundaries as specified in `docs/prd.md` section 13. Do not flatten
them into controllers/models.

```
app/services/
  review_platforms/
    detector.rb            # url -> adapter; raises UnsupportedPlatform
    base_adapter.rb        # contract below
    getapp_adapter.rb      # primary
    g2_adapter.rb          # smoke-test only, do not fight anti-bot
    manual_adapter.rb      # fallback, insurance policy, build early

  ingestion/
    fetcher.rb             # whitelisted hosts, 2 redirects max, 10s timeout, 5MB cap
    parser_result.rb
    importer.rb            # dedup by external_review_id else content_hash; truncate 5000 chars
    summary_builder.rb     # count, avg rating, histogram, sentiment, field coverage, warnings

  ai/
    json_client.rb         # OpenAI structured-outputs wrapper
    schemas.rb             # BATCH_SUMMARY, SCOPE_GUARD, ANSWER
    prompts.rb

  review_analysis/
    batch_summarizer.rb    # BATCH_SIZE 30 reviews per insight batch
    scope_guard.rb         # prompt-driven + cheap regex pre-filter (regex not the sole guard)
    context_builder.rb     # summary + batch insights + keyword-matched reviews (cap 50)
    question_answerer.rb   # guard -> context -> answer; refuse if guard denies
```

### Adapter contract (every platform adapter implements)

`valid_url?(url)`, `external_id(url)`, `canonical_url(url)`,
`fetch_pages(url)`, `parse_reviews(page_html)`, `parse_product_metadata(page_html)`.

Normalized review hash: `external_review_id`, `content_hash`, `source_url`,
`rating`, `sentiment`, `title`, `body`, `reviewer_label`, `reviewer_role`,
`reviewer_company_size`, `review_date`, `raw_payload`.

### Fetcher hard constraints

Whitelisted hosts only: `getapp.com` / `www.getapp.com`, `g2.com` /
`www.g2.com`. Max 2 redirects, redirect host must stay whitelisted, 10s timeout,
5MB max response. Store fetch metadata, not full HTML forever. Never bypass
login, paywall, CAPTCHA, or bot blocks. If G2 blocks, stop — do not fight it;
ship only the adapter that passes its smoke test.

### Ingestion flow

`POST /products` -> detect platform, validate URL, create `Product` ->
create `IngestionRun` -> enqueue `IngestionJob` -> redirect to product show.

`IngestReviewsJob`: `fetching` -> `parsing` -> import -> summary ->
`summarizing` -> batch summarize -> `ready`. On any failure: `product.status =
failed`, `ingestion_run.status = failed`. Status is a string enum:
`pending fetching parsing summarizing ready failed`.

## Data model (PostgreSQL)

`products`, `ingestion_runs`, `reviews`, `insight_batches`, `chat_messages`.
Full column lists and indexes are in `docs/prd.md` section 12. Implement status
enums as string enums. Key uniqueness:
`reviews [product_id, external_review_id]` (where not null) and
`reviews [product_id, content_hash]`.

Current state: no migrations, no schema, no models beyond `ApplicationRecord`.
Models to create: `Product`, `IngestionRun`, `Review`, `InsightBatch`,
`ChatMessage`.

## Routes

```ruby
root "products#new"
resources :products, only: [:new, :create, :show] do
  resources :chat_messages, only: [:create]
end
```

## Guardrails — non-negotiable

The Q&A system answers **only** from the ingested review corpus for the current
product/platform. Disallowed: other review platforms, competitor comparisons,
general world knowledge, current events, weather, market facts, advice not
grounded in the corpus, anything requiring external browsing.

The guardrail must be **primarily system-prompt driven** (per the assignment),
with a cheap regex pre-filter as backup only. Refusal copy must be explicit and
graceful, naming the current platform. Suggested "try blocked questions" buttons
are part of the UI so the guardrail is obvious in the demo.

Required guardrail demo questions must all be refused:
`How do G2 reviews compare?`, `What is the current weather?`,
`Is this better than Zapier?`, `What are the latest sales numbers?`,
`What do Amazon reviews say?`.

## AI design — three calls

1. **Batch summarization** — 30 reviews/batch -> structured themes (pain points,
   praised features, feature requests, buyer objections, notable quotes) with
   supporting review IDs. Stored in `insight_batches`.
2. **Scope guard** — `{allowed, blocked_category, reason, safe_rewritten_question}`.
3. **Answer generation** — `{answer_markdown, confidence, supporting_review_ids, limitations}`.

Use OpenAI Structured Outputs so the app can parse responses reliably.

## Testing rules

- Test saved HTML fixtures, never live scraping. Fixtures under
  `test/fixtures/files/` (e.g. `getapp_make.html`, `g2_notion.html`).
- Minitest. Default to TDD.
- Build the scrape probe (`script/scrape_probe.rb`) to record fixtures before
  writing adapters.

## Conventions

- Ruby styling: Omakase (`bin/rubocop`). Match existing style, don't introduce a
  house config.
- No secrets in code. Use Rails credentials and `.kamal/secrets` (gitignored).
- Keep it boring: simple services, plain ERB, no premature abstraction. The PRD
  explicitly warns against scope creep toward a "generic data ingestion platform."
- Commit real AI sessions to `/ai-transcripts/` (including dead ends and failed
  scraper attempts). Redact secrets only. Mention this in the README.

## When in doubt

Read `docs/prd.md`. It is opinionated on purpose; follow it unless you have a
concrete reason to diverge, and state that reason in the PR or commit.
