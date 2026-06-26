# Assignment Evidence Checklist

Use this checklist before submitting ReviewLens AI. It is intentionally
docs-only so it can be updated without colliding with app implementation
branches.

## Deployment

- Public URL: `https://app.cairnfoundry.com`
- GitHub repository URL: `https://github.com/dpaluy/review-lens`
- Demo data source: `https://www.trustpilot.com/review/quickbooks.intuit.com`
- Primary path works from a fresh browser session.
- Background worker is running in production.
- PostgreSQL-backed persistence survives a page refresh.

## Demo Flow

Follow the PRD success path:

1. Paste the supported review-platform URL or use manual import fallback.
2. Start ingestion.
3. Show ingestion status and final captured-review summary.
4. Ask a pain-point question grounded in the ingested reviews.
5. Ask for representative quotes or evidence.
6. Ask an out-of-scope question.
7. Show the explicit refusal.
8. Briefly explain architecture, tradeoffs, and why the answer is constrained to
   the current review corpus.

## Transcript Checklist

- `ai-transcripts/` exists in the repository.
- Real AI-assistant sessions are committed before submission.
- Secrets and account-specific private data are redacted.
- Failed scraper attempts are included when they affected product direction.
- Implementation tradeoff sessions are included when they explain scope choices.
- Any summaries are clearly labeled as summaries, not verbatim transcripts.
- No fake transcripts are created to fill the folder.

## Guardrail Demo Questions

These should be refused because they require data outside the current ingested
review corpus:

- `How do G2 reviews compare?`
- `What is the current weather?`
- `Is this better than Zapier?`
- `What are the latest sales numbers?`
- `What do Amazon reviews say?`

## Verification Before Submission

Run the configured project checks that match the final implementation branch:

```bash
bin/rails test
bin/rails test:system
bin/rubocop
bin/brakeman
bin/bundler-audit
bin/importmap audit
bin/ci
```

Then verify the evidence artifacts:

```bash
git status --short
find ai-transcripts -maxdepth 2 -type f -print
```

Do not ship with only scaffolding in `ai-transcripts/` if real build sessions are
available. Scaffolding proves the submission path exists, not that the AI-native
process evidence has been supplied.
