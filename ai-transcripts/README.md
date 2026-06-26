# AI Transcripts

This folder contains real AI-assistant transcripts from building ReviewLens AI.
Commit sessions that show product decisions, scraper experiments, implementation
tradeoffs, debugging, and failed attempts when they explain why the final app was
built the way it was.

Redact secrets before committing anything here. Remove API keys, credentials,
tokens, private URLs, personal account details, and any unrelated confidential
customer data. Keep enough surrounding context for a reviewer to understand the
decision or failure.

Failed scraper attempts and abandoned implementation paths are useful evidence.
They show the assignment process, especially where review-site constraints,
guardrails, or scope decisions changed the build.

Reviewers should treat this folder as process evidence, not generated app data.
Files here are not fake transcripts and should not be invented after the fact.
If a session is summarized instead of exported verbatim, label it clearly and
include the date, tool, scope, and what changed because of the session.

## Layout

Transcripts are copied verbatim from each assistant's local store, grouped by
the tool that produced them. Nothing is merged or edited for content.

```
ai-transcripts/
  claude/   Claude Code sessions (projects-ReviewLens, projects-ReviewLens-ui)
  codex/    Codex rollout files (sessions/ + archived_sessions/), including
            every worktree run (e.g. .codex/worktrees/<hash>/ReviewLens)
  pi/       pi-coding-agent sessions (projects-ReviewLens, worktrees-80b8,
            projects-ReviewLens-chore-ui-chat)
```

Worktree transcripts are included on purpose: parallel branches of the work
happened there and they contain real decisions, failed scraper attempts, and
design tradeoffs worth keeping as evidence.

All files are raw exports (`.jsonl`, plus one `.meta.json`). Secrets were
redacted to `****` after copy, preserving key names and hosts so context stays
readable. Redaction covered OpenAI keys, Rails master key, production database
passwords, registry/Spaces tokens, and auth tokens. Validate any line you cite
against the tool's native export if exact fidelity matters.
