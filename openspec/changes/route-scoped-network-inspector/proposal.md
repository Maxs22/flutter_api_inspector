# Proposal: Route-Scoped Network Inspector

## Change ID

`route-scoped-network-inspector`

## Problem Statement

The current `flutter_api_inspector` shows a **flat, chronological timeline** of all HTTP calls across the entire app session. This creates two major pain points for QA and developers:

1. **No context for failures**: When a request fails on the Checkout screen, the developer sees it mixed with 50 other requests from Home, ProductDetail, Cart, etc. There's no way to know *which screen* triggered the call without manual correlation.

2. **QA reports lack actionable detail**: QA reports "API error on checkout" but developers must grep through 200+ log lines to reconstruct the flow. The bug report should say: "CheckoutScreen → POST /api/v1/orders (500) → GET /api/v1/payment-methods (timeout)".

## Proposed Solution

Add **route-scoped network inspection** by correlating each HTTP request with the Flutter route (screen) that was active when the request was made.

### Core Features

1. **RouteScope Service**: A singleton that tracks the current route stack via `NavigatorObserver`. Each screen visit gets a unique `scopeId`.
2. **Dio Interceptor Tagging**: Every intercepted request is tagged with `routeScopeId` and `routeName` at the moment of dispatch.
3. **HTTP Overrides Tagging**: Same tagging for `HttpOverrides`-based interception (non-Dio clients).
4. **Route Tree UI Panel**: New tab in the overlay showing a tree of visited screens. Tapping a screen shows only its network calls, with relative timestamps (e.g., `+234ms` from screen entry).
5. **Export per Screen**: Copy as cURL batch or export HAR filtered to a single route scope.

### Non-Goals (for this change)

- Merged timeline view (flattened chronological + route grouping) — future enhancement
- Database/Storage inspection — out of scope
- Request replay/mutation — out of scope
- Performance profiling (CPU/MEM) — out of scope

## Acceptance Criteria

| ID | Criterion | Verification |
|----|-----------|--------------|
| REQ-RS-001 | RouteScope tracks push/pop/replace and assigns unique `scopeId` per screen visit | Unit test: push A → push B → pop → push B again = 3 distinct scopeIds |
| REQ-RS-002 | Dio interceptor tags requests with current `routeScopeId` and `routeName` | Unit test: intercept request while on `/checkout` → extra contains scopeId + "checkout" |
| REQ-RS-003 | HttpOverrides interceptor tags requests the same way | Unit test: `HttpClient` request while on `/cart` → tagged correctly |
| REQ-RS-004 | Overlay shows "Route Tree" tab with hierarchical screen list | Widget test: navigate A→B→C → tree shows A > B > C |
| REQ-RS-005 | Tapping a route in tree shows only its network calls | Widget test: select B → timeline shows only B's calls |
| REQ-RS-006 | Timestamps shown as relative to route entry (`+Xms`) | Widget test: request at T+500ms from route entry → shows `+500ms` |
| REQ-RS-007 | "Copy as cURL batch" for selected route exports all its calls | Widget test: tap export → clipboard contains valid cURL for each call |
| REQ-RS-008 | `kDebugMode` guard: zero overhead in release builds | Build test: `flutter build apk --release` → no inspector code in output |

## Impact Assessment

| Area | Impact |
|------|--------|
| **API Surface** | New public class `RouteScope` (optional opt-in), new overlay tab. Existing API unchanged. |
| **Dependencies** | None new. Uses existing `dio`, `flutter` SDK. |
| **Performance** | O(1) per request tagging. RouteScope stack max depth ~50. Negligible. |
| **Binary Size** | ~5-8 KB additional (debug-only, tree-shaken in release). |
| **Migration** | Zero breaking changes. Users opt-in by wrapping app with `RouteScopeObserver`. |

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Route naming ambiguity (unnamed routes) | Medium | Low | Fallback to `Route.settings.name ?? runtimeType.toString()` |
| Multiple navigators (nested) | Low | Medium | Track per-navigator stack; expose `navigatorKey` in config |
| Memory leak if scopes not popped | Low | High | `NavigatorObserver.didPop` cleanup + max stack depth guard |
| Release build includes dead code | None | None | `kDebugMode` guards on all new classes |

## Proposed Tasks (High-Level)

1. **RouteScope Service** — singleton, stack management, unique IDs, NavigatorObserver integration
2. **Dio Interceptor Tagging** — extend `TracedDioInterceptor` to inject route scope extras
3. **HttpOverrides Tagging** — extend `TracedHttpOverrides` similarly
4. **Model Updates** — add `routeScopeId`, `routeName`, `relativeTimestampMs` to `ApiTraceRecord`
5. **Route Tree UI** — new overlay panel tab: virtualized tree, selection, relative timestamps
6. **Export per Route** — cURL batch + HAR filter
7. **Example App Integration** — demonstrate multi-screen flow in example/
8. **Tests** — unit + widget per acceptance criteria
9. **Docs** — README + inline docs

## Chained PR Strategy

This change is **medium-sized** (~8-12 tasks). Originally recommended
**2 chained PRs** (core engine, then UI), each targeted at < 400 lines
changed to protect review workload.

**Superseded 2026-07-14**: the actual diff came in well over that budget
(see `tasks.md` → PR Strategy and `verify-report.md` WARNING #1). The
team explicitly decided to ship as a **single PR** instead of re-splitting
or recording a size exception.

## Stack Decisions (Locked)

- Language: Dart 3.6+
- Framework: Flutter 3.27+
- Package manager: pub
- Testing: flutter_test (unit + widget)
- Debug surface: kDebugMode-guarded overlay

---

**Decision Requested**: Approve this proposal to proceed to `sdd-spec` phase?
