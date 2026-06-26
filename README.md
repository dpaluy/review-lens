# ReviewLens AI

ReviewLens AI is a Rails review-intelligence portal for a hiring exercise. It
ingests B2B software reviews, summarizes the captured review set, and answers
analyst questions only from the ingested reviews with supporting review IDs.

The point is not to be a general chatbot. The point is to prove grounded review
Q&A, visible guardrails, deployment, and reviewable AI-process evidence.

## Live Demo

- Production URL: https://app.cairnfoundry.com
- Demo source URL: `https://www.trustpilot.com/review/quickbooks.intuit.com`
- Manual fallback sample: [`public/samples/reviews.csv`](public/samples/reviews.csv)
- Assignment evidence: [`docs/assignment-evidence.md`](docs/assignment-evidence.md)
- AI transcripts: [`ai-transcripts/`](ai-transcripts/)
- Scrapping POC: https://github.com/dpaluy/reviewlens-prototype

## What It Does

| Area | Implementation |
| --- | --- |
| Review ingestion | Trustpilot URL ingestion plus CSV manual import fallback |
| Persistence | PostgreSQL models for products, ingestion runs, reviews, insight batches, conversations, and chat messages |
| Summarization | Batch review summaries with pain points, praise, feature requests, objections, sentiment patterns, quotes, and supporting review IDs |
| Q&A | Product-scoped chat on `/products/:id`, backed by review context only |
| Guardrails | Deterministic prefilter, structured LLM scope guard, fail-closed refusal path, and answer-generation prompt constraints |
| Evidence | Committed transcript exports under `ai-transcripts/` |

## Reviewer Demo Flow

1. Open the production URL or run locally.
2. Paste the Trustpilot demo URL, or switch to manual import and upload
   [`public/samples/reviews.csv`](public/samples/reviews.csv).
3. Wait for ingestion to reach `ready`.
4. Ask a grounded question, for example:

   ```text
   What are the biggest pain points reviewers mention?
   ```

5. Show that the answer includes supporting review IDs.
6. Ask an out-of-scope question, for example:

   ```text
   How do G2 reviews compare?
   ```

7. Show the explicit refusal.

Required blocked demo questions are listed in [`docs/assignment-evidence.md`](docs/assignment-evidence.md).

## My comments

### Guard Implementation

The guard has two layers. First,
[`ReviewAnalysis::ScopeGuard`](app/services/review_analysis/scope_guard.rb) catches obvious out-of-scope prompts deterministically, like other platforms, competitors, weather, sales numbers, and external review sources.

Second, ambiguous prompts go through a structured LLM classification with `allowed`, `blocked_category`, `reason`, and `safe_rewritten_question`. If the guard fails, it fails closed.

Answer generation is separately constrained in [`ReviewAnalysis::QuestionAnswerer`](app/services/review_analysis/question_answerer.rb):
answer only from supplied review context, use supplied review IDs, no outside knowledge, no competitors, and no browsing. Supporting IDs are intersected with the actual context, so the model cannot cite reviews it was not given.

### Design Decisions and Tradeoffs

The app is intentionally a boring Rails monolith: Hotwire, PostgreSQL, Active Job, Solid Queue, no React, no vector DB, and no LangChain. That kept the surface area small and let the build focus on the assignment risks: grounded answers, visible guardrails, deployment, and transcript evidence.

The biggest tradeoff is retrieval simplicity. 
[`ReviewAnalysis::ContextBuilder`](app/services/review_analysis/context_builder.rb) uses product summary, insight batches, and keyword-matched reviews capped at 50.
That is not a perfect RAG system, but it is transparent, testable, and enough for an exercise.

Manual import is a real fallback instead of fighting anti-bot scraping. That is the right product decision because the assignment rewards grounded review analysis, not scraping heroics.

### Pros/Cons

The piece I am proud of is that the guardrail is demoable, not hidden. The app stores refusal metadata, supporting review IDs, and committed AI transcripts, so the reviewer can see evidence instead of trusting a claim.

What I would do differently: run background jobs as a separate production process instead of running Solid Queue inside Puma. For the demo, in-Puma jobs simplified deployment. For production, a separate worker gives clearer scaling, isolation, and failure visibility.

## Guardrail Design

The Q&A boundary is enforced in layers:

1. [`ReviewAnalysis::ScopeGuard`](app/services/review_analysis/scope_guard.rb) blocks obvious out-of-scope prompts before spending an LLM call. Examples include other review platforms, external review sources, competitor comparisons, weather, current events, and sales numbers.
2. Ambiguous prompts go through a structured RubyLLM guard response:
   `allowed`, `blocked_category`, `reason`, and `safe_rewritten_question`.
3. If the guard raises, it fails closed and returns a refusal. 
4. [`ReviewAnalysis::QuestionAnswerer`](app/services/review_analysis/question_answerer.rb) separately constrains answer generation to supplied review context only. It strips user-visible metadata labels and intersects model-provided supporting IDs with the reviews actually included in context.
5. [`ReviewAnalysis::ContextBuilder`](app/services/review_analysis/context_builder.rb) supplies product summary, insight batches, and keyword-matched reviews capped at 50 reviews.

This is intentionally simpler than a full vector retrieval system. For this assignment, transparent grounded behavior matters more than building a generic RAG platform.

## Architecture

ReviewLens is a Rails 8.1 monolith using:

- Ruby 4.0.5
- PostgreSQL
- Hotwire, Turbo, Stimulus, ERB, and Tailwind CSS
- RubyLLM with OpenAI-compatible structured responses
- Active Job with Solid Queue
- Solid Cache and Solid Cable
- Kamal deployment to DigitalOcean

Important paths:

```text
app/controllers/products_controller.rb
app/controllers/chat_messages_controller.rb
app/jobs/ingest_reviews_job.rb
app/jobs/ingest_manual_reviews_job.rb
app/jobs/product_conversation_response_job.rb
app/services/ingestion/
app/services/review_platforms/
app/services/review_analysis/
```

## Local Setup

Install dependencies and prepare the database:

```bash
bin/setup
```

Set AI provider access. `OPENAI_MODEL` is optional, but setting it explicitly is
recommended when testing:

```bash
export RAILS_MASTER_KEY=...
export OPENAI_API_KEY=...
export OPENAI_MODEL=gpt-4o-mini
```

Start the web app and Tailwind watcher:

```bash
bin/dev
```

In a second terminal, run Solid Queue workers when you want jobs processed
outside the web process:

```bash
bin/jobs
```

Then open:

```text
http://localhost:3000
```

If your shell picks up the wrong Ruby, run commands through your Ruby version
manager, for example:

```bash
mise exec -- bin/rails test
```

## Verification

Run the focused and full checks before submission:

```bash
bin/rails test
bin/rails test:system
bin/rubocop
bin/brakeman
bin/bundler-audit
bin/importmap audit
bin/ci
```

Useful manual checks:

```bash
find ai-transcripts -maxdepth 3 -type f -print
git status --short
```

## Environment Variables

| Variable | Required | Notes |
| --- | --- | --- |
| `OPENAI_API_KEY` | Yes for AI features | Used by RubyLLM unless credentials provide `open_ai.api_key` |
| `OPENAI_MODEL` | No | Overrides the default model configured in `config/initializers/ruby_llm.rb` |
| `DATABASE_URL` | Production | PostgreSQL connection string |
| `RAILS_MASTER_KEY` | Production | Required for encrypted credentials |
| `JOB_CONCURRENCY` | No | Controls Solid Queue worker process count |

## Deployment

Deployment is configured in [`config/deploy.yml`](config/deploy.yml) for Kamal
and DigitalOcean.

Current demo topology runs Solid Queue inside Puma with
`SOLID_QUEUE_IN_PUMA=true`. That reduces deployment moving parts for the hiring
exercise, but it is a deliberate shortcut. For a production system, the next
step is a separate worker process so ingestion and AI calls can scale and fail
independently from web requests.

## Limitations

| Limitation | Current Approach | Production Follow-up |
| --- | --- | --- |
| Review-site blocking | Trustpilot fetch failures are handled and manual import is the supported fallback | Add more robust import options, not bot bypassing |
| Retrieval | Keyword-matched reviews plus insight batches | Add embeddings only after core guardrails and evidence flows are solid |
| Worker topology | Solid Queue can run in Puma for demo deployment | Run separate worker service |
| Scope | One public review platform plus manual import | Add platforms only when each adapter has saved fixtures and clear guard coverage |

## Transcript Evidence

The `ai-transcripts/` directory is part of the submission. It contains real
assistant sessions, including failed scraper attempts and implementation
tradeoffs. Secrets should be redacted, but the folder should remain reviewable
because the assignment asks for AI-native process evidence.
