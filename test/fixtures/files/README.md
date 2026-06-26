# Review HTML Fixtures

These fixtures are hand-authored, Trustpilot-like HTML pages for parser,
probe, and fixture-classification tests. They are intentionally static and
must not require live scraping or network access.

- `trustpilot_viable_corpus.html`: reusable parser-facing corpus with 20 raw
  user review cards. Expected classification: `viable`.
- `trustpilot_thin_corpus.html`: reusable parser-facing corpus with 5 raw user
  review cards. Expected classification: `thin`.
- `trustpilot_blocked_captcha.html`: CAPTCHA-like blocked page with no review
  cards. Expected classification: `blocked`.

The corpus fixtures include Trustpilot-like selectors used by the local
adapter, plus `data-review-card="true"` markers for lightweight fixture-count
checks. Keep the text synthetic, product-realistic, and deterministic.
