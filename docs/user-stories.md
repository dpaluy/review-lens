# ReviewLens AI User Stories

Source of truth: `docs/prd.md`.

Note: `AGENTS.md` and `docs/design-brief.md` still mention GetApp/G2, while the PRD currently specifies Trustpilot with a manual import fallback. These stories follow the PRD because it is explicitly the product spec of record. Resolve that conflict before implementation work that depends on platform naming.

## Prioritization Principle

Prioritize the demo path, not platform breadth or architecture polish. The hiring criteria are a deployed product, grounded answers with evidence, visible guardrails, and committed AI transcripts.

## P0 - Must Ship

### 1. Start URL Ingestion

As an analyst, I want to paste a supported Trustpilot review URL so that I can start building a review corpus without manual setup.

Acceptance criteria:
- Validate the submitted host.
- Reject unsupported URLs.
- Create a `Product`.
- Create an `IngestionRun`.
- Redirect to the product status page.

### 2. Probe Public Review Content

As an analyst, I want the app to probe and fetch public review content so that I know whether the source has enough usable raw reviews.

Acceptance criteria:
- Fetch only whitelisted hosts.
- Enforce redirect, timeout, and response-size limits.
- Record fetch metadata.
- Report whether the corpus is blocked, thin, viable, or strong.

### 3. Parse Raw User Reviews

As an analyst, I want reviews parsed into normalized records so that analysis is based on raw user-written reviews, not platform AI summaries.

Acceptance criteria:
- Store review body, rating, source URL, and visible metadata.
- Exclude platform-generated AI summaries from the Q&A corpus.
- Deduplicate by external review ID or content hash.
- Skip empty review bodies.
- Import at least 20 usable reviews or mark the corpus thin.

### 4. Manual Import Fallback

As an analyst, I want manual paste import as a fallback so that the demo does not fail if scraping is blocked or thin.

Acceptance criteria:
- Let the user enter product name, source URL, and pasted review blocks.
- Normalize pasted reviews into the same `reviews` table.
- Clearly mark the product source as manual import.

### 5. Ingestion Progress and Failure State

As an analyst, I want to see ingestion progress and failure details so that I can trust what happened.

Acceptance criteria:
- Show platform, source URL, and current status.
- Show pages attempted, reviews found, reviews imported, and reviews skipped.
- Show parser warnings.
- Show explicit failure messages.
- Never show only a blank spinner.

### 6. Corpus Summary

As an analyst, I want a corpus summary so that I can judge whether the data is complete enough to ask questions.

Acceptance criteria:
- Show imported review count.
- Show average rating and rating distribution.
- Show sentiment distribution.
- Show date range when available.
- Show field extraction coverage.
- Show parser warnings.
- Show sample reviews.

### 7. Batch Review Summaries

As an analyst, I want batch summaries of reviews so that repeated pain points, praise, objections, feature requests, and quotes are extracted.

Acceptance criteria:
- Summarize reviews in batches.
- Extract pain points, praised features, feature requests, buyer objections, sentiment patterns, and representative quotes.
- Store structured summaries in `insight_batches`.
- Preserve supporting review IDs.

### 8. Grounded Review Q&A

As an analyst, I want to ask questions about the ingested corpus so that I can extract strategic review insights quickly.

Acceptance criteria:
- Answer questions about pain points, praise, objections, feature requests, sentiment, and quotes.
- Use only the current product ingested reviews and summaries.
- Do not browse, infer from outside knowledge, or answer from another corpus.

### 9. Evidence on Every Answer

As an analyst, I want every answer to include evidence so that I can verify the AI did not invent claims.

Acceptance criteria:
- Display answer text.
- Display confidence.
- Display supporting review IDs.
- Display limitations.

### 10. Guardrail Refusals

As a reviewer of the hiring exercise, I want out-of-scope questions refused so that guardrails are obvious.

Acceptance criteria:
- Refuse questions about other platforms.
- Refuse competitor comparisons.
- Refuse current events, weather, revenue, market facts, and generic world knowledge.
- Refuse claims not present in the corpus.
- Use explicit, graceful refusal copy.

### 11. Public Deployment

As a reviewer of the hiring exercise, I want the app deployed publicly so that I can evaluate the working product.

Acceptance criteria:
- Deploy the Rails app.
- Configure PostgreSQL.
- Run the background worker.
- Document setup, tradeoffs, and demo path in the README.

### 12. AI Transcript Evidence

As a reviewer of the hiring exercise, I want AI transcripts committed so that I can see the real AI-assisted workflow.

Acceptance criteria:
- Create `/ai-transcripts`.
- Include useful implementation and decision-making sessions.
- Include dead ends and failed scraper attempts when relevant.
- Redact secrets.

## P1 - Should Ship

### 13. Suggested Good Questions

As an analyst, I want suggested good questions so that I can quickly discover the intended workflow.

Acceptance criteria:
- Provide prompts for pain points, praise, objections, feature requests, and negative quotes.
- Let prompts populate or submit through the same chat path as typed questions.

### 14. Suggested Blocked Questions

As an analyst, I want suggested blocked-question buttons so that guardrails are visible in the demo.

Acceptance criteria:
- Provide buttons for known out-of-scope questions.
- Demonstrate refusal behavior through the real Q&A path.

### 15. Saved Chat History

As an analyst, I want saved chat history per product so that I can revisit prior questions and answers.

Acceptance criteria:
- Store user messages.
- Store assistant messages.
- Store answer metadata such as confidence, supporting review IDs, limitations, and blocked category.
- Display prior messages on the product page.

### 16. Prominent Parser Warnings

As an analyst, I want parser warnings surfaced prominently so that thin or partial data is not hidden.

Acceptance criteria:
- Show warnings in the progress view.
- Show warnings in the corpus summary.
- Mark thin corpora clearly.

### 17. PRD-Aligned Service Boundaries

As an engineer/reviewer, I want service boundaries to match the PRD so that the app is maintainable under time pressure.

Acceptance criteria:
- Separate adapter, ingestion, AI, and review-analysis responsibilities.
- Keep controllers from parsing, importing, or calling AI directly.
- Cover behavior with focused service tests where risk justifies it.

## P2 - Nice To Have

### 18. Summary Table Filtering

As an analyst, I want better review filtering in the summary table so that I can inspect negative or high-signal reviews faster.

Acceptance criteria:
- Filter visible sample reviews by sentiment or rating.
- Do not change the underlying corpus or answer scope.

### 19. Richer Quote Display

As an analyst, I want richer quote display so that representative evidence is easier to reuse.

Acceptance criteria:
- Show quote text with review ID, rating, and sentiment.
- Keep quote source traceable to a stored review.

### 20. Expanded Fixture Coverage

As an engineer, I want more scraper fixture coverage so that adapter changes are safer.

Acceptance criteria:
- Add saved HTML fixtures for known parser cases.
- Test thin corpus, blocked page, and viable corpus outcomes.

## Explicit Non-Priorities

Do not prioritize:
- Auth.
- Teams or workspaces.
- Scheduled crawls.
- Multi-platform expansion.
- Embeddings or vector databases.
- Generic ingestion abstractions.
- Competitor benchmarking.
- Browser extension work.

These are opportunity-cost traps for the submitted product.
