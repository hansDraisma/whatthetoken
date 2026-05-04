# AI Consumption Pain Research

Date: 2026-05-04

## Summary

The main developer pain is no longer just "how many messages do I have left?" It is:

> Developers cannot predict whether their next coding session, agent run, model choice, or parallel workflow will exhaust a subscription, trigger overage, force downgrade, or make them wait for a reset.

Modern AI developer products use different consumption models:

- rolling five-hour windows
- daily quotas
- weekly quotas
- monthly premium request pools
- token-based credit drawdown
- model multipliers
- shared subscription pools across products
- optional pay-as-you-go fallback
- hidden or dynamic guardrails

The product should therefore become a consumption command center, not a simple message counter.

## Source-Backed Findings

### Claude And Claude Code

Anthropic states that Claude Pro and Max usage is shared across Claude and Claude Code. Claude Code warns about remaining capacity, and when limits are reached users must wait, upgrade, enable extra usage, or switch to pay-as-you-go API credits.

Relevant source:

- Anthropic Help Center: `Using Claude Code with your Pro or Max plan`
- URL: https://support.anthropic.com/en/articles/11145838-using-claude-code-with-your-pro-or-max-plan

Important product implications:

- Claude and Claude Code must be shown as separate products but linked to the same shared quota pool.
- The UI must warn: "Claude web activity also consumes Claude Code quota."
- The Mac app should detect whether Claude Code is using subscription auth or `ANTHROPIC_API_KEY`, because Anthropic warns that an API key environment variable routes usage to API billing instead of the subscription.
- Claude Code is a high-value first ingestor because it already has local CLI signals and explicit status commands.

Pain pattern:

- Shared pool surprise.
- Five-hour reset planning.
- Confusion between subscription quota and API credit fallback.
- Need to know whether a large coding sprint should wait, downgrade model, or continue with extra usage.

### OpenAI Codex

OpenAI Codex is included with ChatGPT plans, but Codex consumption has moved toward token-based credit rates. OpenAI says usage varies based on model, task size, number of instances, automations, and fast mode. OpenAI also says Codex usage can be monitored in Codex Settings -> Usage.

Relevant sources:

- OpenAI Help Center: `Using Codex with your ChatGPT plan`
- URL: https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan
- OpenAI Help Center: `Codex rate card`
- URL: https://help.openai.com/en/articles/20001106-codex-rate-card
- OpenAI Help Center: `Using Credits for Flexible Usage in ChatGPT`
- URL: https://help.openai.com/en/articles/12642688-using-credits-for-flexible-usage-in-chatgpt-freegopluspro-sora

Important product implications:

- Codex should be first-class and separate from ChatGPT.
- The product must track usage by surface: CLI, IDE, app, web/cloud, GitHub review.
- Message counts alone are insufficient for Codex because token use and task complexity drive credit consumption.
- The Mac app should start by observing local Codex CLI runs, then later integrate richer Codex usage if a stable local or web-accessible source exists.
- The product should show "included usage" vs "paid credits" separately.

Pain pattern:

- Hard to predict cost of large repo tasks.
- Parallel agents and fast mode can burn credits quickly.
- Subscription and credit balances coexist.
- A prompt is not a stable unit of cost.

### ChatGPT

OpenAI publishes ChatGPT usage limits, but the product also has dynamic plan behavior and guardrails. Plus/Go users currently have published GPT-5.3 windows, Thinking has weekly limits, and Pro/Business are described as unlimited subject to abuse guardrails. Credits currently cover Codex and Sora add-on use, not generic ChatGPT text usage.

Relevant sources:

- OpenAI Help Center: `GPT-5.3 and GPT-5.5 in ChatGPT`
- URL: https://help.openai.com/en/articles/11909943-gpt-53-and-gpt-55-in-chatgpt
- OpenAI Help Center: `About ChatGPT Pro tiers`
- URL: https://help.openai.com/en/articles/9793128-about-chatgpt-pro-tiers

Important product implications:

- ChatGPT is still important, but it is not the first developer-first ingestion target.
- Browser-based ChatGPT tracking should be clearly labeled `estimated`.
- The product should track per-model windows and weekly Thinking limits separately.
- Pro "unlimited with guardrails" should not be represented as a normal quota.

Pain pattern:

- Model-specific limits.
- Automatic model switching/downgrade.
- Weekly advanced model limits.
- Guardrail restrictions that are not predictable from public quota docs.

### Cursor

Cursor's pricing and usage are tied to agent usage, model selection, and API-priced consumption. Cursor publishes that daily Agent users typically need more than the base included amount, and power users can reach much higher monthly consumption. Cursor's model choice affects how quickly included usage is consumed.

Relevant source:

- Cursor docs: `Models & Pricing`
- URL: https://docs.cursor.com/account/rate-limits

Important product implications:

- Cursor is a high-priority v1.1 product for developer-first positioning.
- The product should capture model choice and agent mode, not just prompt count.
- The Mac app may be able to observe local Cursor state/logs later, but this needs a separate feasibility spike.

Pain pattern:

- Users do not know how expensive a chosen model/workflow will be before starting.
- Heavy agent users exceed base included usage.
- Model mix matters.

### GitHub Copilot

GitHub Copilot has premium requests with model multipliers. GitHub states that Copilot is moving from request-based billing to usage-based billing starting June 1, 2026. Current premium-request behavior includes monthly reset, feature-specific consumption, and model multipliers. Copilot CLI, IDE chat, cloud agent, code review, third-party agents, and OpenAI Codex integration can all consume premium requests.

Relevant source:

- GitHub Docs: `Requests in GitHub Copilot`
- URL: https://docs.github.com/en/copilot/concepts/billing/copilot-requests

Important product implications:

- Copilot is a strong v1.1/v2 candidate because it has many consumption surfaces and is widely used by teams.
- The data model must support monthly resets, model multipliers, and product-specific SKUs.
- Copilot should be modeled as provider `github`, product `github_copilot`, with surfaces `ide`, `cli`, `cloud_agent`, and `code_review`.

Pain pattern:

- Monthly premium request pool is consumed differently depending on feature and model.
- Users may not realize code review, cloud agent, CLI, and third-party agents draw from the same or related budget.
- The June 2026 billing shift increases the need for visibility.

### Gemini And Gemini CLI

Gemini Apps publish plan-specific limits for prompts, Deep Research, images, agents, and other features, but Google warns that limits may change. Gemini CLI has separate quotas depending on authentication method: Google login, Gemini API key, Vertex AI, or paid Gemini Code Assist subscription.

Relevant sources:

- Google Help: `Gemini Apps limits and upgrades for Google AI subscribers`
- URL: https://support.google.com/gemini/answer/16275805
- Gemini CLI docs: `Quotas and Pricing`
- URL: https://google-gemini.github.io/gemini-cli/docs/quota-and-pricing.html

Important product implications:

- Gemini web should be estimated via browser extension.
- Gemini CLI should be treated separately from Gemini web because its quota depends on auth mode.
- The product needs to show "which account path am I using?" for CLI tools.

Pain pattern:

- Limits vary by feature.
- Published limits can change.
- CLI quota depends on authentication path.
- Daily limits and per-minute limits both matter.

### Windsurf

Windsurf moved to quota-based usage in March 2026. It uses daily and weekly allowances based on token usage, with model-dependent cost. Users can buy extra usage after hitting included quota, and Windsurf provides advice like using free models, avoiding long sessions, and choosing a single frontier model to benefit from caching.

Relevant source:

- Windsurf Docs: `Quota-Based Usage`
- URL: https://docs.windsurf.com/windsurf/accounts/quota

Important product implications:

- Windsurf is not v1, but it validates the broader category: developer tools are moving toward token-aware budget systems.
- The core model should support daily and weekly budgets simultaneously.
- The UI should eventually recommend behavior changes, not just report remaining quota.

Pain pattern:

- Daily and weekly budgets coexist.
- Token usage, context size, model choice, and speed mode change consumption.
- Extra usage can prevent interruption but increases spend.

## Consumption Model Matrix

| Product | Main pain | Quota model | Best tracking path |
|---|---|---|---|
| Claude Code | Shared Claude pool, five-hour reset, API fallback confusion | shared subscription usage + optional API credits | Mac local/Keychain/status + provider usage endpoint |
| Codex | token-based credits, task-size variance, parallel agents | included usage + credits + token rate card | Mac local CLI observation first, web usage later |
| ChatGPT | model windows, weekly Thinking, dynamic guardrails | rolling windows + weekly limits + guardrails | Chrome extension estimate |
| Cursor | model-dependent agent spend | included API-priced usage + overage | local/app feasibility spike |
| GitHub Copilot | premium requests, model multipliers, billing shift | monthly pool, feature SKUs, usage-based billing soon | GitHub/Copilot surfaces later |
| Gemini web | feature-specific daily limits | daily prompts/features, changing limits | Chrome extension estimate |
| Gemini CLI | auth-dependent quotas | daily and per-minute limits by auth path | local CLI observation/config detection |
| Windsurf | daily/weekly token budgets | daily + weekly token-based quota | local/app feasibility spike later |

## Product Requirements Derived From Research

### 1. Product Must Track Budgets, Not Just Messages

The core domain model must support:

- message counts
- token or credit usage
- request pools
- model multipliers
- daily windows
- rolling windows
- weekly windows
- monthly reset pools
- paid overage / extra usage
- shared quota pools across products

### 2. Product Must Distinguish Product From Surface

Examples:

- OpenAI Codex CLI
- OpenAI Codex cloud agent
- OpenAI Codex GitHub review
- OpenAI ChatGPT web
- Anthropic Claude Code CLI
- Anthropic Claude web

The user should never see an ambiguous single number called "OpenAI usage."

### 3. Product Must Explain What Consumed The Budget

The UI should show consumption drivers:

- model selected
- surface used
- feature used
- window affected
- whether the action used subscription quota or paid credits
- whether another product shares the same pool

### 4. Product Must Warn Before Expensive Work

For developer workflows, the killer feature is not only "remaining quota." It is:

> You are about to start a large agent run that may consume a lot of today's/this week's budget.

Possible v1.1 feature:

- "Session risk" indicator before or during a Codex/Claude Code run.
- "Large repo + Opus/Fast mode may burn quota quickly."
- "You are low on Claude 5-hour window; use Sonnet or wait 42 minutes."

### 5. Product Must Track Shared Pools

Examples:

- Claude web and Claude Code share usage.
- ChatGPT plan and Codex plan may coexist with credits.
- Copilot IDE/CLI/cloud/code-review all use related premium request or future credit systems.

The UI needs pool cards:

- Pool: `Claude Pro/Max shared usage`
- Products drawing from it: `Claude`, `Claude Code`
- Current consumers: `Mac`, `Web`, `CLI`

### 6. Product Must Support Uncertainty

Some data will be authoritative, some observed, some estimated, some stale.

The confidence model is not optional. It is the trust model.

## Recommended Solution Shape

### V1 Product

Build a Mac-first developer quota monitor:

- SwiftUI menu bar app.
- Claude Code local ingestor first.
- Codex local ingestor later, only after a metadata and redaction review identifies a safe signal.
- Shared TypeScript or documented core data contract for the web/extension layer.
- Provider/product/surface taxonomy.
- Confidence labels and freshness.
- Pool-aware cards.
- No prompt or response collection.

The first meaningful screen should answer:

1. Which tools are safe to use right now?
2. Which quota pool is low?
3. When does it reset?
4. What caused the usage?
5. Is this number verified, observed, estimated, or stale?

### V1.1 Product

- Add browser extension for ChatGPT and Gemini estimated counters.
- Add Gemini CLI.
- Add Cursor feasibility.
- Add sync/web dashboard.

### V2 Product

- GitHub Copilot and Copilot CLI/cloud agent.
- Windsurf/Cursor richer integrations.
- iOS widgets.
- Paid sync/history/alerts.
- Team view if individual usage proves strong.

## Revised Priority

1. Claude Code
2. Codex CLI
3. Mac SwiftUI status surface
4. ChatGPT browser estimate
5. Gemini browser estimate
6. Gemini CLI
7. Cursor
8. GitHub Copilot
9. Windsurf

The top two can be swapped depending on feasibility. If Codex exposes cleaner local usage state than Claude Code, start with Codex. If Claude's usage endpoint is faster to validate, start with Claude Code.

## Open Feasibility Questions

1. Where does Codex CLI store local auth and usage/session metadata?
2. Does Codex expose a stable local command, config file, log, or SQLite store that can be read without sensitive content?
3. Can Claude Code `/status` or the Anthropic usage endpoint be queried without collecting credentials beyond Keychain-local access?
4. Can the Mac app detect `ANTHROPIC_API_KEY` and warn that usage may be billed as API usage?
5. Can Cursor expose quota data locally or only through its dashboard?
6. Can Copilot usage be accessed through GitHub APIs for individual users, or only organization/admin contexts?

## Sources

- Anthropic Help Center: https://support.anthropic.com/en/articles/11145838-using-claude-code-with-your-pro-or-max-plan
- Anthropic Max usage: https://support.anthropic.com/en/articles/11014257-about-claude-s-max-plan-usage
- OpenAI Codex with ChatGPT plan: https://help.openai.com/en/articles/11369540-using-codex-with-your-chatgpt-plan
- OpenAI Codex rate card: https://help.openai.com/en/articles/20001106-codex-rate-card
- OpenAI flexible credits: https://help.openai.com/en/articles/12642688-using-credits-for-flexible-usage-in-chatgpt-freegopluspro-sora
- OpenAI ChatGPT model limits: https://help.openai.com/en/articles/11909943-gpt-53-and-gpt-55-in-chatgpt
- OpenAI Pro tiers: https://help.openai.com/en/articles/9793128-about-chatgpt-pro-tiers
- Cursor pricing/limits: https://docs.cursor.com/account/rate-limits
- GitHub Copilot requests: https://docs.github.com/en/copilot/concepts/billing/copilot-requests
- Gemini Apps limits: https://support.google.com/gemini/answer/16275805
- Gemini CLI quotas: https://google-gemini.github.io/gemini-cli/docs/quota-and-pricing.html
- Windsurf quota-based usage: https://docs.windsurf.com/windsurf/accounts/quota
