# Privacy Boundaries

WhatTheToken must never collect:

- prompts
- completions
- conversation content
- conversation URLs
- cookies
- auth headers
- bearer tokens
- provider session tokens
- browser request bodies

Allowed usage data:

- provider
- product
- surface
- model key when detectable
- event type
- count, utilization, request, token, or credit amount
- observed timestamp
- device identifier
- confidence level
- source/parser version
- sync/error status

Any future change to these boundaries requires an ADR.
