# Design Brief — ReviewLens AI

## What this is
An analyst tool, not a chatbot. The hero is **trust in the data**: the user must believe the ingested review corpus is accurate and complete *before* they ask questions, and every AI answer must show its evidence. Design should read like a focused data/analytics tool (think Linear / Stripe dashboard density), not a consumer chat app.

## Design principles
1. **Evidence over chrome.** Numbers, counts, coverage, and source IDs are the content. No decorative hero art.
2. **Never a blank spinner.** Every async state shows what's happening and what's been found so far. Blank spinners read as "fragile prototype."
3. **Refusals are a feature.** The scope guard must be visually obvious and demoable, not hidden.
4. **One column, scannable.** Analyst reads top-to-bottom: did it ingest? is it complete? what's in it? now I ask.

## Screens (two routes)

### Route A — New Corpus (`/products/new`)
Single centered card, max-width ~640px.
- **Page title:** "Analyze a review corpus"
- **URL input** (full width), labeled "Review platform URL"
- **Import mode** — segmented control / tabs: `URL scrape` · `Paste reviews` · `CSV upload`. Default = URL scrape. Paste/CSV reveal a textarea / file drop below.
- **Sample helper** under the input, muted text + clickable chip: `Try: getapp.com/.../integromat`
- **Primary CTA:** `Ingest Reviews` (full width, high emphasis)
- Keep it sparse. This is a one-decision screen.

### Route B — Product page (`/products/:id`)
One scrolling column (max-width ~960px) with **four stacked sections that unlock by state**. Sections that aren't ready yet appear disabled/greyed with a short status line — never hidden entirely, so the user understands the pipeline.

**Section 1 — Ingestion status** (visible immediately)
- Horizontal **stepper / pipeline**: `pending → fetching → parsing → summarizing → ready` (and a `failed` terminal state in a warning color). Active step animated, completed steps checked.
- Live counters as they fill in: Platform · Source URL · Pages attempted · Reviews found · Reviews imported.
- **Parser warnings** in an inline, non-alarming notice block (amber, not red) — these are expected, not errors.
- `failed` state: red banner with the error reason + a "Try manual import" CTA. Failures must look handled, not crashed.

**Section 2 — Corpus summary** (unlocks at `ready`) — *this is the trust gate, give it the most polish*
- **Stat cards row** (responsive grid, ~4 across desktop): Reviews imported · Average rating · Positive/Neutral/Negative split · Date range. Big number, small label.
- **Rating distribution**: simple horizontal bar rows (5→1 stars). No fancy charts — bars beat pie charts here.
- **Field coverage table** — two columns (Field, Coverage %), right-aligned numbers, with a subtle inline bar or color cue per row (e.g. green ≥80%, amber 40–79%, grey <40%). Conveys completeness at a glance.
- Source platform + source URL shown as metadata chips.

**Section 3 — Sample reviews** (unlocks at `ready`)
- Dense table: `Rating | Title | Excerpt | Source`. Rating as stars or numeric badge, excerpt truncated with ellipsis. ~10 rows, scannable. This is proof the corpus is real.

**Section 4 — Ask the reviews** (unlocks at `ready`)
- Plain review Q&A input only. Do not show canned suggested-prompt chips around the input.
- **Chat transcript**: user question (right/neutral) and assistant answer (left). Each **assistant answer is a structured card**, not a plain bubble:
  - Answer body (markdown)
  - **Confidence** badge (low/medium/high)
  - **Supporting review IDs** as small clickable chips
  - **Limitations** line in muted text
- **Guardrail / refusal state** is a distinct visual treatment — bordered card, lock/shield icon, calm neutral color (not error red): "I can only answer from the reviews ingested for this product on GetApp." Must be instantly recognizable as a deliberate decline.
- **"Try a blocked question" row** — small ghost buttons that fire out-of-scope questions: "How do G2 reviews compare?" · "Current weather?" · "Better than Zapier?". Makes the guardrail demoable in the Loom.

## Component inventory to deliver
Status stepper · stat card · rating-distribution bar · coverage table row · review table · suggested-prompt chip · question bubble · **answer card** (the most important component — confidence + ID chips + limitations) · refusal card · warning/error banners · empty + loading states for each section.

## Key states — design all of them
- Loading per section (skeletons, not spinners)
- Empty corpus / zero reviews found
- Ingestion failed
- Q&A: thinking, answered, refused, error
- Thin corpus warning (e.g. <15 reviews) — a soft notice on the summary

## Visual direction
Clean, neutral, high-legibility. System or a single grotesk typeface. One accent color for primary actions; reserve amber for warnings and a distinct neutral for refusals. Generous use of monospace for IDs, counts, and source URLs to reinforce the "data tool" feel. Light mode is enough for the demo.

## Out of scope (don't design)
Auth/login, user accounts, multi-platform switcher, settings, charts beyond simple bars, mobile-first layouts (desktop-first is fine; just don't break on tablet).

## Deliverable
Figma: Route A, Route B in all four states (status / summary+reviews / Q&A answered / Q&A refused), plus the component inventory. Desktop frames at 1280px; ensure graceful reflow down to ~768px.
