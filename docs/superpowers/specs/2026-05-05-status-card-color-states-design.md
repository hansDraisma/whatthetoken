# Status Card Color States and Layout Redesign

Date: 2026-05-05
Status: Implemented

## Problem

The Mac app's status cards repeat "Anthropic / Claude Code" on every row, hide the window name in a subhead, render a flat blue progress bar regardless of state, and surface trust noise ("Verified by Mac connector / Undercount possible / Updated …") on every row. Users opening Claude's Settings → Usage screen see different numbers ("13% used") than ours ("87% remaining") without an obvious bridge between the two.

We want the screen to:

- Make the window name (Current session, Weekly · all models, …) the primary label per row.
- Lift the brand into a section header that appears once.
- Tint the progress bar by remaining capacity: green ≥30 %, orange 10–29 %, red <10 %.
- Display Claude's "X% used" alongside our "X% remaining" so cross-reference is instant.
- Replace the per-row trust noise with a single section line, plus a per-row exception badge that fires only when a row's `confidence` or `undercountRisk` diverges from the section default.

## User Outcome

A user glancing at the Mac app immediately sees how much capacity is left in each Claude Code window, in the same units Claude itself shows, with a color cue if a window is running low, almost empty, or empty. When a single row has a higher undercount risk or lower confidence than the rest, that row carries a small badge; otherwise the section is uniform and quiet.

## Goals

- Single section header with the brand and one trust line.
- Window name as the primary label per row.
- Hero metric as "X% remaining" (or unit-appropriate equivalent), tinted red only at the critical/empty threshold.
- "Y% used" echo on the same baseline as the hero, formatted to match Claude's wording exactly.
- Linear bar tinted green / orange / red by remaining capacity.
- Status under the bar: **Plenty left** / **Running low** / **Almost empty** / **Empty**.
- Red warning state keeps the count hero while capacity remains; true empty state replaces the count hero with a sentence ("Out of credits"). Rows without a meaningful denominator hide the bar.
- Per-row exception badge for divergent confidence or undercount risk.
- "Compare in Claude →" link in the section header that opens Claude's Settings → Usage page.

## Non-Goals

- No per-state CTAs ("Switch to Sonnet", "Top up credits"). Worth a follow-up spec.
- No background provider refresh, no persisted thresholds, no user-configurable colors. Reset hint copy refreshes in the UI every minute.
- No new data fields on `UsageSnapshot` or `ConnectorSource`. The redesign reads existing fields only.
- No change to provider-side logic or to `ClaudeConnectorService`.

## Design

### Section header

```
Anthropic · Claude Code                            Compare in Claude →
Verified by Mac connector · Updated 09:44
```

- Brand and trust line render once, derived from the first snapshot's `source` and `confidence` (validated to be uniform across the section before rendering — if not uniform, fall back to row badges and omit the section trust line). Updated time is formatted in the user's local timezone.
- "Compare in Claude →" opens `https://claude.ai/settings/usage` in the default browser.

### Row anatomy

```
Current session                              Resets in 3h 16m
87% remaining                                          13% used
████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ← bar tinted green
● Plenty left
```

- **Top line:** window name (left), reset hint (right). Reset hint uses Claude's two formats: relative ("Resets in 3h 16m") when reset is within 24 h, absolute ("Resets Wed 19:00") otherwise. Sub-minute resets show "Resets in <1m".
- **Hero line:** "X% remaining" hero (left), "Y% used" echo (right), same baseline. Hero only tints red at the critical threshold.
- **Bar:** linear progress, fill width = utilization, color from threshold.
- **Status:** dot + word, color from threshold.

### Threshold and word mapping

For utilization rows, threshold is computed from rounded utilization (`100 − round(utilization × 100)`) so the hero and echo percentages sum to 100. If utilization is unavailable, the display falls back to `remaining`.

| Remaining | Bar color | Status word | Hero tint |
|-----------|-----------|-------------|-----------|
| ≥30 %     | green     | Plenty left | none      |
| 10–29 %   | orange    | Running low | none      |
| >0 % and <10 % | red  | Almost empty | red      |
| 0 %       | red       | Empty       | red       |

For non-percentage units (`credits`, `tokens`, `requests`, `messages`), threshold uses `remaining / limit` when `limit` is set; otherwise the row is treated as healthy unless `remaining <= 0`, which forces the empty state.

### Empty-state hero

When state is actually empty (`remaining <= 0` or equivalent), the hero swaps from a count to a sentence:

| Unit                     | Empty hero string |
|--------------------------|-------------------|
| `utilization`            | "Out of capacity" |
| `credits`                | "Out of credits"  |
| `tokens`                 | "Out of tokens"   |
| `requests`               | "Out of requests" |
| `messages`               | "Out of messages" |
| other                    | "Empty"           |

When `limit` is unknown or zero for a non-percentage unit, the bar is hidden because a progress bar without a denominator is misleading.

### Per-row exception badge

A small amber badge appears next to the row name when the row's confidence is less trustworthy than verified or when the row's `undercountRisk` diverges from the section default:

- `Inferred` — when the row's `confidence` is not `verified`.
- `Undercount possible` / `Undercount likely` — when the row's `undercountRisk` differs from the section default.

Badges have a `title` tooltip that explains the divergence in one sentence. If a row's `staleReason` is set, it renders in muted text under the status, regardless of badge logic.

### Anthropic / Claude Code as the only section today

`StatusViewModel` currently holds a flat list of snapshots. The redesign assumes the section header reads from the section's first snapshot. If multi-provider sections land later, the same component renders one section per `(provider, product)` pair.

## Architecture

The redesign is a presentation-layer change. No new model types, no new services. The plan should:

1. Introduce a `StatusSectionDisplayModel` derived from a `[UsageSnapshot]`. It exposes:
   - `brandTitle`, `trustLine`, `compareURL`
   - `rows: [StatusRowDisplayModel]`
   - flags for whether the section trust line is uniform (and thus can be hoisted)
2. Rebuild `StatusCardDisplayModel` as `StatusRowDisplayModel`, exposing:
   - `name`, `resetHint`
   - `heroText`, `echoText`
   - `progressValue`, `state` (`.healthy`, `.low`, `.critical`, `.empty`)
   - `statusWord`, `heroTintsRed`
   - `badges: [RowBadge]` and `staleReason`
3. Replace `StatusCardView` with a `StatusSectionView` rendering the header plus an inner row layout (no nested cards; hairline dividers).
4. Centralize threshold logic, status word strings, empty-state hero strings, and reset-hint formatting in pure functions for unit testing.

## Testing

- Unit tests for threshold mapping at boundary values (0, 9.9, 10, 29.9, 30, 100).
- Unit tests for empty-state hero strings per unit, plus a red nonzero state that keeps its numeric hero.
- Unit tests for badge derivation: uniform section, divergent confidence, divergent undercount.
- Unit tests for reset-hint formatting at the 24 h boundary.
- Snapshot tests (or view-model assertions) for the four sample rows from the live Claude screen: 87 % / 27 % / 95 % / 0 credits, plus a synthetic 5 % remaining red warning row.

## Out of scope / follow-ups

- Per-state CTAs.
- Multi-section rendering (multi-provider).
- Configurable thresholds.
- Localization of status words.
