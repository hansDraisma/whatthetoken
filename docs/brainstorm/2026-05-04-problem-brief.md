# Multi-Provider AI Usage Tracker — Problem Brief

*Brief prepared 2026-05-04 for soliciting a second opinion from another LLM.*

---

## TL;DR

We're designing a real consumer/prosumer product that shows developers how much of their **AI subscription quotas** are left across the products they use, in near-real-time, on multiple devices. Wedge: "stop getting throttled mid-task." Differentiation from existing single-provider tools: covers Claude + ChatGPT + Gemini in one place. Major architectural constraint: **only Anthropic exposes a (semi-stable, undocumented) usage endpoint; OpenAI and Google publish no quota API at all for their consumer subscriptions in 2026**, so the data has to be collected by riding along on the user's own browser session. We want a sanity check on this architecture and on which surfaces (web, browser extension, Mac, iOS, IDE) to ship at v1.

---

## 1. Goal & wedge

**Pain we are addressing:** Developers who pay for multiple AI subscriptions (typical stack: Claude Max + Claude Code + ChatGPT Plus/Pro + Gemini Advanced) currently have no single place to see how close they are to hitting subscription quotas. They check the in-app indicator inside each product separately, often only after they've been throttled or downgraded mid-task. Existing tools either cover one provider (e.g. `bramveen1/claude-usage-widget`) or focus on developer API spend rather than subscription quotas.

**Wedge sentence:** *"Stop getting throttled, across the AI tools you actually use."*

**Target user:** Working software engineer / product builder who pays out-of-pocket or through their employer for two or more of: Claude Max, ChatGPT Plus or Pro, Gemini Advanced. Heavy daily usage (multiple coding sessions, deep research, agent flows). Cares about uninterrupted flow.

**Out of scope at launch:** API spend tracking (Admin-key dashboards across OpenAI/Anthropic/Gemini/Mistral). May ship as a secondary tab post-v1.

---

## 2. Provider scope at v1

| Provider | Subscription tier(s) | Why included |
|---|---|---|
| Anthropic Claude (Max / Pro) | Claude Max | The single biggest source of throttling pain for this audience. |
| Claude Code (CLI) | Same OAuth/sub as Claude Max | Same auth as above; included almost for free. |
| OpenAI ChatGPT (Plus / Pro / Business) | All ChatGPT consumer tiers | Most-used non-Claude assistant in this segment. |
| Google Gemini Advanced (Google AI Pro / Ultra) | All Google AI subscriptions | Rapidly growing; closes the "big three" picture. |

**Explicitly excluded at v1:** Cursor Pro, GitHub Copilot, Perplexity Pro, Mistral Le Chat, Windsurf, v0/Lovable/Bolt, Grok. Likely v1.x candidates: Cursor, Copilot Business.

---

## 3. Hard constraints from the product owner

1. **Frictionless onboarding.** No manual token paste, no CLI bootstrapping. Install → sign in → done.
2. **Near-real-time updates.** ≥ 1 minute polling cadence; manual refresh button.
3. **Stable.** Minimize web scraping. Prefer public APIs where they exist.
4. **Multi-surface from the start (or close to it).** Web dashboard, Chrome extension, Mac app/widget, iPhone app + WidgetKit widget. IDE plugins and other surfaces post-v1.
5. **Real product (not a personal tool).** Hosted backend, multi-tenant, auth, payments-eventually, support burden.

The conflict in this list: constraint #1 + #2 + #3 + the provider scope of §2 is **unsatisfiable given 2026 reality**. ChatGPT Plus and Gemini Advanced have *no* public quota API of any kind. So "stable + public API" must be relaxed for those two providers; the question is *how*.

---

## 4. Per-provider data-availability reality (2026)

### Anthropic Claude Max / Code
- **Endpoint:** `GET https://api.anthropic.com/api/oauth/usage`
- **Auth:** OAuth bearer token issued to Claude Code, stored in macOS Keychain (entry: `Claude Code-credentials`). Linux/Windows users paste it.
- **Status:** Undocumented but used by Anthropic's own client (Claude Code), so de facto stable.
- **Returns:** `five_hour.utilization`, `seven_day.utilization`, per-model breakdown (`seven_day_opus`, `seven_day_sonnet`), `extra_usage` credits.
- **Verdict:** ✅ Cleanest path. Real numbers, not estimates.

### OpenAI ChatGPT Plus / Pro / Business
- **No quota API exists.** Confirmed via OpenAI Help Center and OpenAI Developer Community threads. Limits are *dynamic* (vary with system load, e.g. "160 GPT-5.2 messages per 3h" — the `160` itself can shift).
- The only place quota appears is `Settings → Usage Limits` inside the ChatGPT UI.
- **Existing extensions in production** (Chatterclock, DeepMeter, ChatGPT Usage Tracker & Queue, ChatGPT Toolbox, ChatGPT Usage Limit Tracker) mostly do **client-side message counting**: observe outbound chat messages from the user's browser, increment per-model counters, apply published limits, compute remaining. They don't reverse-engineer internal endpoints (which exist but are unstable).
- **Verdict:** ⚠️ Chrome-extension-as-client-side-message-counter is the only stable path. Numbers are estimates, not authoritative.

### Google Gemini Advanced
- Same situation as ChatGPT. No public quota API. Limits visible only inside `gemini.google.com`.
- Fewer prior-art extensions than for ChatGPT, but the same client-side observation pattern applies.
- **Verdict:** ⚠️ Chrome extension required. Same caveat re: estimates.

### Alternative ingestion paths considered & rejected

| Alternative | Why rejected |
|---|---|
| Server-side cookie auth (backend logs in as user) | Auth-security nightmare; consumer trust unacceptable. |
| Native daemon reads Chrome's encrypted cookie DB | Requires Full Disk Access; flagged as malware by AV; breaks with Chrome 127+ App-Bound Encryption. |
| Headless-browser automation on a server | Captcha/2FA breaks; account-level fraud detection; fragile. |
| iOS Safari extension instead of Chrome on desktop | Most users hit ChatGPT/Gemini via native iOS apps, not Safari. iOS Safari extensions also limited. Doesn't substitute for Chrome ingestion. |
| OAuth scope from OpenAI/Google for read-my-quota | Doesn't exist. |
| Provider partnership | Not realistic for an indie product at launch. |
| Local proxy (route browser traffic through us) | Setup nightmare; trust and certificate-handling issues. |

---

## 5. Proposed architecture (Path 2)

### Components

```
                    ┌────────────────────────────────────────┐
                    │              Hosted backend             │
                    │   Postgres + auth + Realtime + REST     │
                    │   (Supabase or self-hosted equivalent)  │
                    └───────────▲──────────────────▲──────────┘
                                │ push usage         │ subscribe / fetch
                                │ (per-provider,     │
                                │  per-window state) │
              ┌─────────────────┴───┐         ┌──────┴──────────────┐
              │                     │         │                     │
   ┌──────────┴───────────┐  ┌──────┴──────┐  ┌────────────┐  ┌─────┴─────────┐
   │  Mac menubar /       │  │  Chrome     │  │ Web         │  │  iOS app +    │
   │  Tauri helper        │  │  extension  │  │ dashboard   │  │  WidgetKit    │
   │                      │  │             │  │             │  │               │
   │ - Keychain → OAuth   │  │ - Observes  │  │ - Auth      │  │ - Pairs to    │
   │   token              │  │   chats on  │  │ - Settings  │  │   account     │
   │ - Polls Anthropic    │  │   chatgpt   │  │ - Graphs    │  │ - Push notifs │
   │   /api/oauth/usage   │  │   .com,     │  │             │  │ - Home-screen │
   │ - Pushes to backend  │  │   gemini    │  │             │  │   widgets     │
   │ - Optional notifs    │  │   .google,  │  │             │  │               │
   │                      │  │   claude.ai │  │             │  │               │
   │                      │  │ - Counts    │  │             │  │               │
   │                      │  │   sends per │  │             │  │               │
   │                      │  │   model;    │  │             │  │               │
   │                      │  │   maintains │  │             │  │               │
   │                      │  │   rolling   │  │             │  │               │
   │                      │  │   windows   │  │             │  │               │
   │                      │  │ - Pushes to │  │             │  │               │
   │                      │  │   backend   │  │             │  │               │
   └──────────────────────┘  └─────────────┘  └─────────────┘  └───────────────┘
```

### Ingestion split

- **Anthropic** → ingested by either the Mac helper (preferred, has Keychain access) **or** the Chrome extension on `claude.ai` if user doesn't install desktop helper. Real numbers.
- **ChatGPT Plus/Pro** → Chrome extension only. Client-side message counts on `chatgpt.com`. Estimated numbers.
- **Gemini Advanced** → Chrome extension only. Client-side message counts on `gemini.google.com`. Estimated numbers.

### Why Chrome extension rather than a desktop ingestor for OpenAI/Google

- Only a real browser session (with user's already-stored cookies, 2FA, account-switcher state) can authenticate to ChatGPT/Gemini.
- Extensions can run service workers (`chrome.alarms`) to poll/refresh in the background even with no tab open, so long as Chrome itself is running.
- This is the same architectural pattern used by 1Password, Grammarly, LastPass: ride the user's session, stay transparent, push to backend.

### Phone-only viewing when laptop is off

- Phone shows last-known state with a timestamp. Acceptable because the wedge ("don't get throttled mid-task") only matters when the user is actually at a computer, at which point at least one ingestor is alive.
- If desired later: a "morning sync" trigger via Apple Push could nudge the laptop's helper to refresh before the user starts work.

### Auth & pairing

- Web dashboard is the auth root. Email + magic link or OAuth to start.
- Chrome extension and Mac helper sign in with the web account once.
- iPhone app pairs by 6-digit code (bramveen1 pattern), no separate password.
- All ingestors push to a single per-account inbox row.

---

## 6. Surfaces — proposed v1 vs later

| Surface | v1 must-have? | Notes |
|---|---|---|
| Chrome extension (ingestor + popover UI) | ✅ Required | Without it there's no ChatGPT/Gemini story. |
| Web dashboard (auth, settings, full graphs) | ✅ Required | Comes mostly for free as the backend's auth surface. |
| Mac menubar / Tauri tray app | ✅ Recommended | Best path for Anthropic ingestion + a great Mac-native experience. |
| iOS app + WidgetKit widgets + push | ⚖️ Recommended | High delight; high build cost; App Store review burden. |
| Android app | ❌ Post-v1 | Smaller fraction of target audience. |
| Windows / Linux desktop apps (Tauri ports) | ❌ Post-v1 | Tauri makes this cheap — but Anthropic ingestion needs token paste on those (no Keychain equivalent). |
| Firefox / Edge / Safari extension ports | ❌ Post-v1 | WebExtensions API is mostly portable; sequence after Chrome stabilises. |
| VSCode / JetBrains / Cursor IDE plugin (status bar) | ❌ v1.x | Cool but post-validation. |
| Apple Watch / Raycast / Alfred / menubar widgets | ❌ v2+ | Long tail. |

---

## 7. Open product / business questions

1. **Trust model.** Chrome Web Store has a credibility problem in the AI extension space (16 malicious extensions caught in 2026 stealing ChatGPT session tokens). Should the Chrome extension be open-source from day one to earn install trust? Auditable minimal permissions?
2. **Monetisation.** Free with paid tier? Paid only? Likely freemium: free for one provider, paid ($X/mo) for multi-provider + iOS widgets + push. Pricing unsettled.
3. **Number reliability.** For OpenAI/Google, our numbers are estimates. How do we communicate that without undermining trust? "Estimated quota — based on observed sends" badge?
4. **Multi-device chats.** A user who chats with ChatGPT from their phone *and* their laptop will be undercounted (extension only sees laptop). Acceptable for v1?
5. **Provider takedown risk.** OpenAI/Google could break this (intentionally or not) by scrambling DOM, changing the model selector, or actively detecting our extension. Mitigation: the extension is open-source community-maintained; rapid release cadence.
6. **Anthropic OAuth endpoint risk.** Undocumented; could change. Mitigation: monitor the endpoint, have a "stale data" UI state, fall back to message counting on `claude.ai` (matching the pattern we'd already have for OpenAI/Google).
7. **Latency expectations.** ≤ 1 min cadence is target. What does "real-time" mean for an estimated number — should the UI distinguish "just observed a send (counter +1)" from "polled provider just now"?
8. **Onboarding sequence.** Web first, or Chrome ext first? If Chrome ext first, account creation flow lives inside the extension popup — different UX. If web first, the user has to install the extension *after* signing up, creating a drop-off.
9. **Backend vendor.** Supabase is the obvious choice (auth + Postgres + Realtime + cheap). Is there a reason to prefer a self-hosted Postgres + Cloudflare Workers stack instead?
10. **Legal / ToS.** Are we exposed by piggybacking on user sessions to ChatGPT/Gemini? Existing Chrome Web Store extensions doing the same thing suggest no, but worth a real legal read before launch.

---

## 8. What we'd love a second-opinion LLM to weigh in on

Please critique any/all of the following. Disagreement is welcome — we want this brief stress-tested.

1. **Is there actually a better ingestion path for ChatGPT Plus / Gemini Advanced quotas in 2026 that we're missing?** Especially: any official OpenAI / Google product surface that exposes consumer-tier quota data we haven't found?
2. **Is the wedge ("stop getting throttled across N AI tools") strong enough on its own, or should the v1 also bundle API-spend tracking from day one to widen the audience?**
3. **Should the Chrome extension count messages locally (our current proposal) or attempt to read providers' internal `/settings/usage_limits`-style endpoints?** Trade-off: stability vs. accuracy.
4. **Surface prioritisation.** Given a small team and a quarter-long v1 window, which of {web, Chrome ext, Mac menubar, iOS app + widget} should be cut from v1?
5. **Trust posture.** Is open-sourcing the Chrome extension a meaningful trust signal in this category, or is it just a cost we'd take on for marginal benefit?
6. **Is Supabase the right backend, or is this a case where a more bespoke stack (e.g. Cloudflare Workers + D1 + Durable Objects) buys us more than it costs?**
7. **TAM check.** Roughly how many devs pay for ≥ 2 of {Claude Max, ChatGPT Plus/Pro, Gemini Advanced} simultaneously? Is this segment large enough to be a venture-scale business, or is it more naturally a $100k/year indie product?
8. **Competitive landscape.** Beyond `bramveen1/claude-usage-widget` and the per-product Chrome extensions enumerated above, what's the closest commercial competitor we should be aware of?
9. **Provider-takedown risk.** What's the realistic likelihood that OpenAI or Google ships an in-house quota dashboard within 12 months that obviates much of our value prop?

---

## 9. What's *not* in this brief (intentionally)

- Detailed UI mockups (will come in design phase).
- Pricing model.
- Marketing positioning / brand.
- Specific notification rules (when to push, thresholds).
- Data retention / privacy policy.
- Backend schema.

These are deliberately downstream — locking them in before validating the architecture would be premature.
