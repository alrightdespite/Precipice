# AnalyticsService

## Mission

Fires structured analytics events to an external endpoint or Roblox's built-in analytics. Wraps all event firing so services call `AnalyticsService.track(event, props)` rather than direct API calls.

## Key rules

- Events are fire-and-forget; failures are logged but never block gameplay
- PII: never log UserId in event properties visible to analytics dashboard (use anonymized sessionId)
- Enabled/disabled via GameConfig flag; off by default in development

## Phase

Phase 7 (deferred).
