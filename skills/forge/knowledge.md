# Forge Knowledge Base

Lessons learned from past dev-test cycles. Auto-updated by the Learner agent.

Format: each lesson has a `[date,apply_count]` prefix — date = first seen, apply_count = times this category was both injected into Planner AND cited as applied. Categories have keyword hints in parentheses for selective injection.

## NestJS / Backend (nestjs, backend, api, controller, middleware, cors)
- [2026-04-28,0] Use `setGlobalPrefix()` and keep controller decorators prefix-free; never mix prefixed and unprefixed routes
- [2026-04-28,0] Register CORS middleware as the first global middleware before any route groups
- [2026-04-28,0] Place refresh/token endpoints in public route group; they validate refresh tokens, not access tokens

## RBAC / Auth (auth, rbac, permission, role, guard, access control)
- [2026-04-28,0] Menu visibility should check OR of all relevant permissions, not just the primary action permission
- [2026-04-28,0] Add route-level guards + redirect for unauthorized access; menu filtering is UX, not security
- [2026-04-28,0] When adding a mid-level role, verify it in backend RBAC, frontend route guard, and menu visibility consistently
- [2026-04-28,0] Use dedicated UserID field in refresh token claims, never derive identity from Subject

## Data / API Design (data, api, crud, validation, status, transaction)
- [2026-04-28,0] Rejection must be atomic: reset approval + reset data + unlock in one transaction
- [2026-04-28,0] Re-approval should transition all draft items to submitted in the same transaction
- [2026-04-28,0] Add role-dependent flag to export DTO; filter sensitive columns at backend, not frontend
- [2026-04-28,0] Define valid status transition maps; reject no-op or invalid transitions with clear errors
- [2026-04-28,0] For scope-constrained CRUD, use a shared validation helper across all methods
- [2026-04-28,0] API endpoints that redirect on validation failure cause silent errors with axios (302 → HTML → JSON parse error); use POST + JSON error responses for API flows

## Database / ORM (database, orm, gorm, prisma, sql, migration, unique)
- [2026-04-28,0] Empty string collides on UNIQUE index but SQL NULLs don't — use nullable types for optional unique columns
- [2026-04-28,0] Create DB-agnostic `isUniqueConstraintViolation()` helper checking all engine error patterns; wrap into domain message
- [2026-04-28,0] When changing parent_id, traverse ancestor chain to detect circular references before allowing the update

## Frontend / React (react, frontend, ui, antd, component, calendar, picker)
- [2026-04-28,0] Guard calendar click handler when modal/drawer is open; return early to prevent double-trigger
- [2026-04-28,0] Place `dayjs.locale()` before `createRoot/render` to avoid locale flash on first paint
- [2026-04-28,0] For rejected approval steps, find reject record and map to step index with `status="error"`
- [2026-04-28,0] Use RangePicker + weekday filter + preview tags instead of per-day toggle for batch date selection
- [2026-04-28,0] When adding a new color-coded visual category, always add the corresponding legend item; users cannot infer new color semantics without it

## Frontend / API Integration (api, fetch, axios, frontend, backend, endpoint, redirect)
- [2026-04-28,0] Probe backend API at runtime for feature detection instead of hard-coding visibility from frontend config; if API returns 404/403, hide the feature
- [2026-04-28,0] Maintain fallback algorithm consistency across frontend and backend; verify both produce identical results when enhanced data is unavailable
- [2026-04-28,0] Health endpoints must never double as config endpoints; leads to credential leakage and coupling monitoring with feature detection

## Hyperframes / Video (video, tts, audio, hyperframes, composition, clip)
- [2026-04-28,0] Chinese TTS via espeak fails for zh locale; use direct phoneme-based synthesis with sentence-boundary splitting to stay under phoneme limits
- [2026-04-28,0] Overlapping clip elements need different track indices; same-track overlapping clips cause lint errors
- [2026-04-28,0] `<audio>` elements must have `id` attributes or they render silent
- [2026-04-28,0] GSAP overlapping tweens on same property: use `overwrite: "auto"` or stagger timing

## Feishu Bot Development (feishu, bot, lark, card, message, callback)
- [2026-04-28,0] Embed session_id, permission_id, action in card button values as JSON for routing on callback
- [2026-04-28,0] Skip non-text message types silently; only extract text from `msg_type == "text"`
- [2026-04-28,0] Chunk long output at natural boundaries (paragraphs > newlines > spaces > bytes); card limit ~28KB

## Claude Code Integration (claude, subprocess, stream-json, permission, integration)
- [2026-04-28,0] Stream-json subprocess: `claude -p --output-format stream-json --input-format stream-json --replay-user-messages`
- [2026-04-28,0] ChangeWorkDir requires stopping and restarting the process; conversation context is NOT preserved
- [2026-04-28,0] Permission flow: parse `permission_request` → build card with approve/reject → card callback → send `permission_response` to stdin

## Docker / K8s Deployment (docker, k8s, deployment, container, healthcheck, security)
- [2026-04-28,0] Dockerfile: create user BEFORE chown; `adduser` must precede `mkdir && chown`
- [2026-04-28,0] K8s `readOnlyRootFilesystem: true` requires explicit `/tmp` emptyDir volume mount
- [2026-04-28,0] Non-root Docker user needs ownership of all writable directories; verify with `ls -la`
- [2026-04-28,0] Stateful in-memory sessions require single-replica K8s deployment; scale with persistence or sticky routing first

## Backend Patterns (backend, pattern, cache, constructor, nil, feature flag)
- [2026-04-28,0] Accept optional services as nil-able constructor params with graceful fallback; nil = simpler but correct behavior, non-nil = enhanced behavior
- [2026-04-28,0] Decouple feature availability from auth mode: use per-feature `IsConfigured()` checks instead of piggybacking on unrelated mode flags
- [2026-04-28,0] Return stale cache on external API failure rather than erroring; provide fresh > stale > fallback degradation chain
- [2026-04-28,0] When adding constructor parameters in Go, immediately grep all call sites and pass nil for existing tests to preserve original behavior

## OAuth / Multi-Flow Auth (oauth, auth, jssdk, csrf, callback, login, token)
- [2026-04-28,0] JSSDK and server-side OAuth flows need separate code-exchange endpoints with different CSRF requirements; merging them breaks JSSDK or weakens CSRF
- [2026-04-28,0] Auth callback pages must handle multiple auth flow response formats with priority ordering: check URL token params first, then fall back to code exchange

## UX / Color Semantics (ux, color, semantic, visual, design, legend)
- [2026-04-28,0] Use semantically distinct colors for different UI states; shared colors prevent users from distinguishing them

## SDK Migration / Vendoring (sdk, vendor, migration, interface, dependency)
- [2026-04-28,0] Vendor+Patch only the problematic sub-package when an SDK has a localized gap; don't fork the entire SDK or wait for upstream
- [2026-04-28,0] Keep your own interface types and write conversion functions from new SDK types; test only the thin conversion layer

## Wave Efficiency (workflow, planning, waves, tasks, decomposition)
- [2026-04-28,3] Prefer fewer waves: each wave costs 2 agent invocations + handoff + integration test. Complexity sum ≤ 15 should always be 1 wave
- [2026-04-28,2] Never create single-task waves — merge into adjacent waves
- [2026-04-28,2] Batch independent small tasks together rather than splitting into separate waves
- [2026-04-28,1] Maximum 3 waves; if grouping requires more, merge related tasks to stay within the limit
- [2026-05-12,0] Verification-only tasks (no code changes) should not be standalone subtasks — merge as an acceptance criterion into the most related task, or include in Wave 1 as a quick check
