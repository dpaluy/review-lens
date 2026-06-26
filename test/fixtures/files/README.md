# Review HTML Fixtures

These fixtures are hand-authored Trustpilot-like pages for parser and ingestion
tests. They are intentionally static so Track A can proceed without live
scraping.

- `trustpilot_viable_corpus.html`: parser-facing page with 20 raw user-written
  review cards. Expected classification: `viable`.
- `trustpilot_thin_corpus.html`: parser-facing page with 5 raw user-written
  review cards. Expected classification: `thin`.
- `trustpilot_blocked_captcha.html`: blocked response with CAPTCHA-like copy and
  no review corpus. Expected classification: `blocked`.
