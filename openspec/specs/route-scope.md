# Route-Scoped Network Inspector — Specification

## Purpose

The current `flutter_api_inspector` presents a flat chronological
timeline of all HTTP calls across the entire app session. This spec
defines a **route-scoping layer** that correlates each request with
the Flutter route (screen) that was active at dispatch time, and a
**Route Tree UI** that lets testers browse calls grouped by screen
and export them per group.

## Requirements

### REQ-RS-001 — RouteScope service

A `RouteScope` singleton MUST track the route stack via
`NavigatorObserver` callbacks:

- `didPush` → creates a new scope entry with a unique `scopeId`,
  the route name, and a timestamp.
- `didPop` → marks the current scope as ended (does not destroy it;
  the record stays available for browsing).
- `didReplace` → replaces the top scope entry with a new one
  (new `scopeId`, new route name, new timestamp).
- Each scope entry MUST carry:
  - `scopeId`: a monotonically increasing `int` unique per session.
  - `routeName`: derived from `Route.settings.name ?? route.runtimeType.toString()`.
  - `navigatorRoute`: the `MaterialPageRoute`-style path when available.
  - `enteredAt`: `DateTime` when the route was pushed.
  - `parentScopeId`: the `scopeId` of the route that was active before
    this push, enabling tree reconstruction.

**TDD contract**: `flutter test` MUST record RED → GREEN →
TRIANGULATE → REFACTOR evidence.

#### Scenario: Push creates a scope entry

- GIVEN a `RouteScope` connected to a `NavigatorObserver`
- WHEN `didPush` is called with route A
- THEN `RouteScope.current.scopeId == 1`
- AND `RouteScope.current.routeName == "A"`
- AND `RouteScope.current.parentScopeId` is null (first route)

#### Scenario: Push after push creates a child scope

- GIVEN route A is active
- WHEN `didPush` is called with route B
- THEN `RouteScope.current.scopeId == 2`
- AND `RouteScope.current.parentScopeId == 1`
- AND `RouteScope.current.routeName == "B"`

#### Scenario: Pop restores the parent scope

- GIVEN A → B active stack
- WHEN `didPop` is called for B
- THEN `RouteScope.current.scopeId == 1`
- AND `RouteScope.current.routeName == "A"`

#### Scenario: Replace creates a new scope at current depth

- GIVEN A → B active stack
- WHEN `didReplace` is called replacing B with C
- THEN `RouteScope.current.scopeId == 3`
- AND `RouteScope.current.routeName == "C"`
- AND `RouteScope.current.parentScopeId == 1`

#### Scenario: Scope IDs are monotonically increasing

- GIVEN 5 route transitions (push/pop/replace)
- WHEN all scope IDs are collected
- THEN they are strictly increasing (no reuse)

### REQ-RS-002 — Dio interceptor tags requests with route scope

`TracedDioInterceptor` MUST inject the current route scope into
every intercepted request's `RequestOptions.extra` map:

- `routeScopeId` (int) — the `scopeId` of the active scope at
  dispatch time.
- `routeName` (String) — the route name at dispatch time.

**TDD contract**: `flutter test` MUST record RED → GREEN →
TRIANGULATE → REFACTOR evidence.

#### Scenario: Dio request tagged with route scope

- GIVEN route A is active (scopeId = 1)
- WHEN a Dio request is intercepted
- THEN `options.extra['routeScopeId'] == 1`
- AND `options.extra['routeName'] == "A"`

#### Scenario: Dio request tagged after push

- GIVEN A → B active (scopeId = 2)
- WHEN a Dio request is intercepted
- THEN `options.extra['routeScopeId'] == 2`
- AND `options.extra['routeName'] == "B"`

#### Scenario: Dio request tagged after pop (back to A)

- GIVEN A → B → pop to A (scopeId = 1)
- WHEN a Dio request is intercepted
- THEN `options.extra['routeScopeId'] == 1`
- AND `options.extra['routeName'] == "A"`

### REQ-RS-003 — HttpOverrides tags requests with route scope

`TracedHttpOverrides` / `TracedHttpClient` MUST inject the current
route scope into every request's metadata (stored in the record's
`extra` map):

- `routeScopeId` (int) — the `scopeId` of the active scope.
- `routeName` (String) — the route name.

**TDD contract**: `flutter test` MUST record RED → GREEN →
TRIANGULATE → REFACTOR evidence.

#### Scenario: HttpClient request tagged with route scope

- GIVEN route A is active
- WHEN an `HttpClient` request is made via `TracedHttpOverrides`
- THEN the resulting `ApiTraceRecord.extra['routeScopeId'] == 1`
- AND `ApiTraceRecord.extra['routeName'] == "A"`

### REQ-RS-004 — Model: ApiTraceRecord gains scope fields

`ApiTraceRecord` MUST NOT add new top-level fields (to avoid a
breaking change). Instead, scope data is stored in the existing
`extra` map under well-known keys:

- `routeScopeId` (int)
- `routeName` (String)

New read-only convenience accessors MAY be added:

- `int? get routeScopeId => extra['routeScopeId'] as int?`
- `String? get routeName => extra['routeName'] as String?`

**TDD contract**: `flutter test` MUST record RED → GREEN →
TRIANGULATE → REFACTOR evidence.

#### Scenario: Route scope data accessible via convenience getters

- GIVEN a record captured with route A active
- WHEN `record.routeScopeId` and `record.routeName` are accessed
- THEN `record.routeScopeId == 1`
- AND `record.routeName == "A"`

#### Scenario: Legacy records (no scope) return null

- GIVEN a record captured before RouteScope was active
- WHEN `record.routeScopeId` is accessed
- THEN it returns null (not throws)

### REQ-RS-005 — Route Tree UI panel

The overlay MUST gain a new tab (next to "Timeline") labeled
"Routes". This tab shows a hierarchical tree of visited routes:

- Each row shows: route name, call count (for that scope),
  failed call count, duration since entry.
- Tapping a row FILTERS the main timeline to show only records
  whose `routeScopeId` matches that scope.
- The tree structure reflects the parent-child relationship:
  - Indentation for depth.
  - Expandable/collapsible children.
- Active route is highlighted.
- A "clear" button resets the filter back to "All routes".

**TDD contract**: `flutter test` widget tests.

#### Scenario: Route tree shows visited routes

- GIVEN the overlay is open and 3 routes were visited (A→B→C)
- WHEN the "Routes" tab is selected
- THEN the tree shows 3 entries: A, B, C
- AND they are indented by depth: A (depth 0), B (depth 1), C (depth 2)

#### Scenario: Tapping a route filters the timeline

- GIVEN the timeline has 10 records across routes A (4) and B (6)
- WHEN route A is tapped in the tree
- THEN the timeline shows exactly 4 records (only route A's calls)

#### Scenario: Active route is highlighted

- GIVEN the current route is B
- WHEN the "Routes" tab is selected
- THEN route B's row has a distinct visual style (e.g. bold + accent color)

#### Scenario: Clear resets filter

- GIVEN route A is selected (filter active)
- WHEN "clear" is tapped
- THEN the timeline shows all records again

### REQ-RS-006 — Relative timestamps in route context

When the timeline is filtered to a specific route scope, each
record's timestamp MUST be shown relative to the route's
`enteredAt` time:

- Format: `+123ms`, `+2.4s`, `+1m05s`.
- The absolute timestamp remains visible on tap (in the detail
  screen).

**TDD contract**: widget test.

#### Scenario: Relative timestamp shown when filtered

- GIVEN route A entered at T=0, and a request completed at T=500ms
- WHEN the timeline is filtered to route A
- THEN the row shows `+500ms`

#### Scenario: Absolute timestamp when unfiltered

- GIVEN the timeline shows all routes (no filter)
- WHEN a record is displayed
- THEN it shows the absolute `HH:mm:ss` timestamp as before

### REQ-RS-007 — Export per route

When a route scope filter is active, the "Share" / "Copy as cURL"
buttons MUST export ONLY the filtered subset. The export includes:

- A header comment: `// Route: <routeName> (scopeId: <id>)`
- One cURL command per record in chronological order.

**TDD contract**: widget test.

#### Scenario: Export respects route filter

- GIVEN route A is selected (4 calls visible)
- WHEN "Copy as cURL" is tapped
- THEN the clipboard contains exactly 4 cURL commands
- AND the first line is `// Route: A (scopeId: 1)`

### REQ-RS-008 — kDebugMode guard

All new code (RouteScope, tagging, Route Tree UI) MUST be guarded
by `kDebugMode` at the same level as the existing overlay. The
`RouteScope` singleton MUST be a no-op (no tracking, no tagging) in
release builds.

**TDD contract**: verify with `flutter build apk --release` that
the new symbols are tree-shaken.

#### Scenario: RouteScope is no-op in release mode

- GIVEN `kDebugMode == false`
- WHEN `RouteScope` methods are called
- THEN they return immediately without tracking state

## Out of scope

- Merged timeline (chronological + route grouping in one view).
- Request replay / mutation.
- Database inspection.
- Performance profiling.
- Persistent scope history across app restarts.
- Multi-window support.
