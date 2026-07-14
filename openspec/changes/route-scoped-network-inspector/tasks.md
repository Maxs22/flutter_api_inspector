# Tasks: Route-Scoped Network Inspector

## PR Strategy

~~Originally planned as 2 chained PRs (< 400 lines each).~~ **Superseded
2026-07-14** (post sdd-verify, see `verify-report.md` WARNING #1): the
actual diff measured ~880 lines for the PR1-scoped files and ~1260 lines
for the PR2-scoped files — 2.2x–3.2x over the stated budget. Since
nothing was committed yet at that point, the team decided (explicit
choice, not a silent size:exception) to ship this change as a **single
PR** covering TASK-RS-001 → TASK-RS-010 instead of re-splitting or
recording an exception.

| PR | Tasks | Focus |
|----|-------|-------|
| PR 1 (single) | TASK-RS-001 → TASK-RS-010 | Full route-scoped network inspector: RouteScope engine, Dio/HttpOverrides tagging, model getters, Route Tree UI, timeline filter, export-per-route, example demo |

---

## [x] TASK-RS-001 — RouteScope service + RouteScopeEntry model

**File**: `lib/src/route_scope.dart` (new)

**Acceptance**:

- `RouteScope.init()` creates singleton, guarded by `kDebugMode`.
- `RouteScope.onPush(route)` creates `RouteScopeEntry` with unique `scopeId`,
  `routeName`, `enteredAt`, `parentScopeId`.
- `RouteScope.onPop(route)` removes top of stack, restores parent.
- `RouteScope.onReplace(route)` replaces top entry.
- `RouteScope.current` returns active entry or null.
- `RouteScope.entries` returns all entries ever created.
- `scopeId` increments monotonically per session.
- Release build: `RouteScope.init()` is a no-op, `current` is always null.

**TDD**: RED → GREEN → TRIANGULATE → REFACTOR.

**Test evidence**: `test/route_scope_test.dart` (14 tests). Genuine RED
demonstrated by temporarily disabling `onPush`'s body — 8 tests failed
for the right reason — then restored to GREEN.

---

## [x] TASK-RS-002 — RouteScopeObserver (NavigatorObserver)

**File**: `lib/src/route_scope_observer.dart` (new)

**Acceptance**:

- `RouteScopeObserver` implements `NavigatorObserver`.
- `didPush` calls `RouteScope.onPush`.
- `didPop` calls `RouteScope.onPop`.
- `didReplace` calls `RouteScope.onReplace`.

**Integration in harness**:

- `BootstrapMaterialAppHarness` adds `RouteScopeObserver()` to
  `navigatorObservers` when `kDebugMode`.

**TDD**: RED → GREEN → TRIANGULATE → REFACTOR.

**Test evidence**: `test/route_scope_observer_test.dart` (5 tests,
including a nested-navigator TRIANGULATE case). Genuine RED demonstrated
by disabling `didPush`'s forwarding call — 4 tests failed for the right
reason — then restored to GREEN.

---

## [x] TASK-RS-003 — Dio interceptor route-scope tagging

**File**: `lib/src/interceptor/dio_interceptor.dart` (modify)

**Acceptance**:

- `TracedDioInterceptor.onRequest` injects `routeScopeId` and `routeName`
  into `options.extra` when `RouteScope.current` is non-null.
- Values are forwarded to the record's `extra` map on completion.
- No crash when `RouteScope.current` is null (release mode).

**TDD**: RED → GREEN → TRIANGULATE → REFACTOR.

**Test evidence**: `test/interceptor/dio_interceptor_test.dart` new group
"route-scope tagging" (4 tests). **Bugfix found via TDD**: the acceptance
bullet "Values are forwarded to the record's extra map on completion"
was NOT true in the pre-existing implementation — `onRequest` tagged
`options.extra` but never passed `extra:` to `ApiTrace.call`, so
`record.routeScopeId`/`routeName` were always null. Wrote the record-level
assertion first (RED, confirmed failing for the right reason), then fixed
`dio_interceptor.dart` to pass `extra: options.extra` to `ApiTrace.call`
(GREEN). Also exported `RouteScope`, `RouteScopeEntry`, `RouteScopeObserver`,
and the `ApiTraceRecordScope` extension from the public barrel
(`lib/flutter_api_inspector.dart`) — they were implemented but never
exported, which would have made `MaterialApp.router` manual wiring and
`record.routeScopeId` reads impossible for real consumers.

---

## [x] TASK-RS-004 — HttpOverrides route-scope tagging

**File**: `lib/interceptor/http_overrides.dart` (modify)

**Acceptance**:

- `TracedHttpClient` injects `routeScopeId` and `routeName` into the
  record's `extra` map when `RouteScope.current` is non-null.
- No crash when `RouteScope.current` is null (release mode).

**TDD**: RED → GREEN → TRIANGULATE → REFACTOR.

**Test evidence**: `test/interceptor/http_overrides_test.dart` new group
"route-scope tagging" (3 tests). This path was already wired correctly
(`openUrl` already passed `extra: taggedExtra` to `ApiTrace.call`).
Genuine RED demonstrated by disabling the tagging block — 2 tests
failed for the right reason — then restored to GREEN.

---

## [x] TASK-RS-005 — Model convenience getters

**File**: `lib/src/model/api_trace_record.dart` (modify)

**Acceptance**:

- Extension `ApiTraceRecordScope` adds `routeScopeId` (nullable int) and
  `routeName` (nullable String) getters.
- Legacy records (no scope data in `extra`) return null without throwing.
- Zero breaking changes to `ApiTraceRecord` class.

**TDD**: RED → GREEN → TRIANGULATE → REFACTOR.

**Test evidence**: `test/api_trace_record_test.dart` new group
"ApiTraceRecordScope extension" (3 tests). Genuine RED demonstrated by
making both getters unconditionally return null — 2 tests failed for
the right reason — then restored to GREEN.

---

## [x] TASK-RS-006 — Release-build kDebugMode verification

**Acceptance**:

- `flutter build apk --release` succeeds.
- Verified that new symbols (`RouteScope`, `RouteScopeObserver`,
  `routeScopeId` extra keys) do not appear in the release binary
  (tree-shaken via kDebugMode).

**TDD**: Build test only (no unit test needed — verify with build output).

**Verification evidence**: `flutter build apk --release` from `example/`
succeeded (356s, produced `app-release.apk`, 43.4MB, arm64-v8a +
armeabi-v7a + x86_64). Extracted `libapp.so` for all three ABIs from the
APK and grepped the raw binary for `routeScopeId`, `RouteScope`,
`RouteScopeObserver`, `RouteScopeEntry`, `parentScopeId`, and
`navigatorRoute` — **zero occurrences in any of the three architectures**.
A positive control (`grep -c "ApiTrace"` / `"flutter_api_inspector"` on
the same binary, both present) confirms the search methodology itself is
valid, i.e. this is a real absence, not a tooling false negative. This
holds even though `RouteScope`/`RouteScopeObserver` are public exported
API and `example/lib/main.dart` calls `RouteScope.current` directly
(`_routeScopeExtra()`): Dart's AOT whole-program type-flow analysis
proves `RouteScope._instance` stays `null` forever once `init()`'s
`if (!kDebugMode) return;` const-folds to always-return in a release
build, so every downstream branch and string literal gated behind
"if scope != null" becomes unreachable and is eliminated.

---

## [x] TASK-RS-007 — Route Tree UI tab

**File**: `lib/src/overlay/route_tree_tab.dart` (new)

**Acceptance**:

- New "Routes" tab in overlay next to "Timeline".
- Hierarchical tree of visited routes (indented by depth).
- Each row shows: route name, call count, error count, active highlight.
- Expandable/collapsible children.
- Tapping a route filters the timeline panel to that route's calls.
- Filtering shows relative timestamps (`+Xms`).
- "Clear" button resets to show all records.
- Works within the existing overlay theme.

**TDD**: Widget tests for tree rendering, filter activation, clear.

**Test evidence**: `test/overlay_test.dart` new group "RouteTreeTab
widget" (6 tests). **Bugfix found via TDD**: the "active highlight"
acceptance bullet was not implemented — `_RouteTreeRow` only bolded a
row when it matched the tap-to-filter `selectedScopeId`, with no
concept of "the live `RouteScope.current` route" shown distinctly
when no filter is active. Wrote the RED test first (confirmed failing
for the right reason), then added an `isActive` flag (`RouteScope
.current?.scopeId == entry.scopeId`) to `_RouteTreeRow` so the current
route is bold/accented independent of the filter selection (GREEN).

---

## [x] TASK-RS-008 — Timeline panel filter integration

**File**: `lib/src/overlay/timeline_panel.dart` (modify)

**Acceptance**:

- `TimelinePanel` accepts optional `scopeFilter` predicate.
- When set, only records matching the predicate are shown.
- Timestamps switch to relative format when filter is active.
- Existing behavior (no filter, absolute timestamps) preserved when
  scopeFilter is null.

**TDD**: Widget test for filtered + unfiltered rendering.

**Test evidence**: `test/overlay_test.dart` new group "TimelinePanel
scope filter" (4 tests). Genuine RED demonstrated by disabling the
`scopeFilter` predicate check inside `_applyFilters` — the narrowing
test failed for the right reason — then restored to GREEN.

---

## [x] TASK-RS-009 — Export respects route filter

_Outside the batch's originally assigned TASK-RS-001..008 range, but
included per the orchestrator's suggested `overlay_test.dart` test
layout (explicitly named "export-per-route header line format"). The
implementation already existed in `api_trace_overlay.dart`; wrote the
missing test coverage the same way as the other tasks._

**Acceptance**:

- When a route scope filter is active, "Copy as cURL" exports only
  the filtered records.
- Export includes `// Route: <name> (scopeId: <id>)` header.
- Unfiltered export is unchanged.

**TDD**: Widget test verifying clipboard content with filter active.

**Test evidence**: `test/overlay_test.dart` new group "Export per
route" (1 integration test: FAB -> Routes tab -> tap route -> Timeline
tab -> export icon -> clipboard assertions). Genuine RED demonstrated
by mangling the header format in `_exportFilteredRecords` — the header
assertion failed for the right reason (filtering itself was already
correct) — then restored to GREEN.

---

## [x] TASK-RS-010 — Example app: multi-screen demo

**File**: `example/lib/main.dart` (modify)

**Acceptance**:

- Example app has at least 2 screens (Home, Detail).
- Each screen makes distinct API calls.
- Navigating between screens shows route tree with separate groups.
- Route names are visible in the Routes tab.

**TDD**: Not required (example is documentation, not a testable library).

**Implementation notes**: Rebuilt `main.dart` around named routes
(`initialRoute: '/home'`, `routes: {'/home': ..., '/detail': ...}`) so
`RouteScope.current.routeName` resolves to `/home` / `/detail` instead of
falling back to `route.runtimeType.toString()`. Home has a stub call +
a "Go to Detail screen" button (`Navigator.pushNamed('/detail')`).
Detail has its own stub call plus the pre-existing `kDebugMode`-gated
real httpbin call. Per `openspec/AGENTS.md` rule 7 (manual instrumentation
only in the example, no auto-interceptor), both screens tag their
`ApiTrace.call` via a small `_routeScopeExtra()` helper that reads
`RouteScope.current` and forwards `routeScopeId`/`routeName` through
`extra` — the same convention `TracedDioInterceptor`/`TracedHttpOverrides`
use internally, now documented as the pattern for manual-instrumentation
consumers. `flutter analyze` on `example/` is clean.
