# Design — `flutter_api_inspector-mvp`

- **Change**: `flutter_api_inspector-mvp`
- **Date**: 2026-06-23
- **Phase**: `sdd-design`
- **Artifact store**: OpenSpec in repo (`openspec/changes/flutter_api_inspector-mvp/`)
- **Status**: design — ready for `sdd-tasks` to break into implementation tasks
- **Inputs**: `proposal.md` (locked), `specs/instrumentation-api.md` (9 REQ / 21 scenarios), `specs/overlay-ui.md` (8 REQ / 17 scenarios), `specs/timeline-model.md` (8 REQ / 14 scenarios)

---

## Purpose

`flutter_api_inspector-mvp` ships a manual, code-local API-trace SDK and a
debug-only in-app overlay for Flutter. Developers call `ApiTrace.call(name,
…, execute: …)` at the call site; the SDK records an `ApiTraceRecord` into an
in-memory ring buffer; a debug-only overlay (floating action button plus
panel) renders the timeline and a read-only detail view. The overlay is
guarded by `kDebugMode` and tree-shaken from release builds, so the
package has zero production-runtime cost. The design is derived directly
from the 25 numbered `REQ-*` items in the three delta spec files; every
section below cites the REQ(s) it satisfies.

## Goals and non-goals

### Goals (driven by spec + proposal)

- **Manual instrumentation only** — `ApiTrace.call(name, …, execute: …)`
  is the single capture entry point. `AGENTS.md` rule 7, REQ-API-001,
  REQ-API-002.
- **Privacy-conscious default** — `ApiTraceConfig.details` defaults to
  `{ApiTraceDetail.minimal}`; no body, no headers captured at default.
  REQ-API-004, REQ-MODEL-005.
- **Debug-only overlay** — `kDebugMode` guards mount and build;
  `flutter build --release` tree-shakes the overlay surface. REQ-UI-001,
  `AGENTS.md` rule 6.
- **In-memory ring buffer** with capacity `ApiTraceConfig.timelineCapacity`
  (default 200), silent eviction, newest-first ordering. REQ-MODEL-003,
  REQ-MODEL-004, REQ-MODEL-008.
- **Configurable FAB** — position (4 values) and label shape (3 values).
  REQ-API-003, REQ-UI-003, REQ-UI-004.
- **Error/Success coloring** — red for both thrown exceptions and 4xx/5xx,
  green for 2xx/3xx. REQ-API-007, REQ-UI-008.
- **Tap-to-detail read-only screen** — visualization only; no cURL, no
  re-run, no export. REQ-UI-007.
- **Reentrancy** — concurrent / nested `ApiTrace.call` invocations each
  produce a distinct record; no synchronization primitives.
  REQ-API-009, REQ-MODEL-007.
- **Zero new dependencies** beyond `flutter` and `flutter_test`
  (`openspec/AGENTS.md` rule 10, proposal acceptance criteria).

### Non-goals (mirror of `proposal.md` + technical)

- **No auto-interceptor** — no `http.Client` override, no `package:dio`
  shim, no platform-channel proxy. `AGENTS.md` rule 7.
- **No disk persistence in v1** — no `shared_preferences`, no SQLite, no
  file export, no clipboard. REQ-MODEL-008.
- **No cURL export, no re-run, no replay** — read-only visualization.
  REQ-UI-007 out-of-scope list.
- **No network mocking, no rewriting, no blocking.**
- **No multi-window / multi-tab support** — single per-app FAB and
  timeline.
- **No Flutter web support in v1** — iOS, Android, macOS, Windows,
  Linux only.
- **No regex / field-query search** — only the three filter chips
  (success / error / name substring) in REQ-UI-006.
- **No telemetry, no analytics, no auto-upload.**
- **Technical non-goals (added by this design)**:
  - **No `Isolate`s, no `Stream`s, no `BroadcastStream`s in v1.** The
    timeline is a plain `List<ApiTraceRecord>` and the rebuild signal is
    a `ValueListenable<ApiTraceRecord?>`. This keeps the surface
    minimal, makes reentrancy trivial, and removes the entire category
    of "did I close my subscription" bugs.
  - **No `package:uuid`, no `package:collection`, no `package:http`.**
    Ids use `Random.secure().nextBytes(16)`; lists use `dart:core`.
  - **No `print`, no `developer.log`** — the package is visualization-
    only. `AGENTS.md` rule 7 + proposal acceptance criteria.
  - **No `ApiTraceScaffold`** — out of scope per spec; the integration
    surface is the `ApiTrace.runApp(...)` helper (see
    *Overlay bootstrap path*).

## Architecture overview

```
+-------------------------+          +-------------------------+
|      Developer code     |          |    WidgetsApp / Mat'l   |
|                         |          |     (user's app)        |
|  await ApiTrace.call(   |          |                         |
|    name: ...,           |          |   ApiTrace.runApp(      |
|    execute: () async => |          |     MyApp() )           |
|      http.get(...)      |          |       |                 |
|  )                      |          |       v                 |
+----------+--------------+          |  ApiTraceBootstrap      |
           |                         |  (if kDebugMode)        |
           |  await execute()        |       |                 |
           v                         |       v                 |
+-------------------------+          |  MaterialApp.builder    |
|  ApiTrace.call          |          |  wraps in Stack         |
|  - guard: !enabled?     |          |       |                 |
|  - new ApiTraceRecord   |          |       v                 |
|  - Timeline.append(rec) |          |  ApiTraceOverlay        |
|  - return id            |          |  - FAB                  |
+----+-----------------+--+          |  - panel                |
     |                 |             |  - detail screen        |
     |                 |             +-----+-------------------+
     |  +ValueListenable<ApiTraceRecord?>
     |                 |                   |
     v                 v                   v
+----+----+    +-------+-------+    +------+----------+
|  Result |    |  Timeline     |    |  ApiTraceOverlay |
|  Future |    |  (ring buffer)|    |  (rebuilds when  |
|  <id>   |    |  List<Record> |    |   timeline       |
+---------+    +-------+-------+    |   changes)       |
                                     +------------------+
```

Call path (one `ApiTrace.call(...)`):

1. `ApiTrace.call` is invoked from developer code with `name`, `method`,
   `url`, `execute`, optional `detailOverride`, optional `extra`.
2. The `enabled` short-circuit returns `Future.value(null)` if false.
3. The `startedAt` is captured; `execute()` is awaited exactly once.
4. On resolution, an `ApiTraceResponse` is in hand (or an exception).
5. The `completedAt`, `duration`, `outcome` are derived.
6. `ApiTraceRecord.fromCapture(...)` builds the record, applying the
   privacy-conscious default to drop body / header fields the captured
   detail set does not include.
7. The record is appended to the `Timeline` (ring buffer evicts oldest
   when over capacity; insertion is O(1) at the head).
8. The `_latest` `ValueNotifier` is set to the new record's id,
   triggering the overlay to rebuild.
9. The `Future<String?>` returned to the caller resolves with the new
   record's `id`.

This sequence is verified end-to-end by REQ-API-001, REQ-API-005,
REQ-API-007, REQ-API-008, REQ-MODEL-001, REQ-MODEL-003, REQ-MODEL-004.

## Module layout

The package follows the standard `lib/` + `test/` + `example/` layout
from `AGENTS.md` rule 10. One type per file where it clarifies ownership;
the `model/`, `overlay/`, and `widget/` directories group related types.

```
lib/
  flutter_api_inspector.dart          # barrel: public surface
  src/
    api_trace.dart                    # static ApiTrace class (call, enabled, config)
    config.dart                       # ApiTraceConfig, ApiTraceOverlayPosition, ApiTraceOverlayLabel
    detail.dart                       # ApiTraceDetail enum
    outcome.dart                      # ApiTraceOutcome enum
    bootstrap.dart                    # ApiTrace.runApp + ApiTraceBootstrap widget
    id.dart                           # id generation (Random.secure, no package:uuid)
    body_codec.dart                   # response body truncation (UTF-8 / JSON / bytes)
    model/
      api_trace_record.dart           # ApiTraceRecord (immutable, with fromCapture factory)
      api_trace_request.dart          # ApiTraceRequest
      api_trace_response.dart         # ApiTraceResponse
      timeline.dart                   # Timeline (ring buffer + ValueListenable signal)
    overlay/
      api_trace_overlay.dart          # ApiTraceOverlay widget (top of overlay stack)
      fab.dart                        # ApiTraceFab widget (configurable position + label)
      fab_position.dart               # overlayPosition -> AlignmentGeometry
      timeline_panel.dart             # TimelinePanel widget (list + filter chips)
      timeline_row.dart               # TimelineRow widget (one record in the list)
      detail_screen.dart              # ApiTraceDetailScreen widget (read-only)
      colors.dart                     # green/red outcome color resolver

test/
  api_trace_test.dart                 # REQ-API-001, 002, 005, 006, 007, 008, 009
  config_test.dart                    # REQ-API-003, 004
  detail_test.dart                    # REQ-API-004 (enum shape)
  outcome_test.dart                   # REQ-MODEL-002 (enum shape)
  timeline_test.dart                  # REQ-MODEL-003, 004, 005, 006, 007, 008
  api_trace_record_test.dart          # REQ-MODEL-001, 005
  body_codec_test.dart                # REQ-MODEL-006
  overlay_test.dart                   # REQ-UI-001, 002, 003, 004, 005, 006, 007, 008
  bootstrap_test.dart                 # REQ-UI-001, 002
  id_test.dart                        # shape, uniqueness, no collisions in 1k

example/
  main.dart                           # MaterialApp + ApiTrace.runApp + stub + 1 real call
  pubspec.yaml                        # path: ../ (local)
```

One file per type keeps imports explicit and lets `sdd-tasks` create
one RED test file per type. The `lib/src/` tree is private to the
package; only `lib/flutter_api_inspector.dart` is public.

## Public surface

The `lib/flutter_api_inspector.dart` barrel re-exports the symbols below.
The names and shapes are locked by the three spec files; this section
cross-references each public symbol to the REQ(s) that pin it.

### Static class — `ApiTrace` (`lib/src/api_trace.dart`)

| Member | Type | Source REQ |
| --- | --- | --- |
| `ApiTrace.enabled` | `static bool` (late-initialized to `kDebugMode`, mutable) | REQ-API-002, REQ-API-006 |
| `ApiTrace.config` | `static ApiTraceConfig` (default instance, mutable) | REQ-API-003, REQ-API-004 |
| `ApiTrace.timeline` | `static Timeline` (the in-memory ring buffer) | REQ-MODEL-003, REQ-MODEL-008 |
| `ApiTrace.call(String name, {required String method, required Uri url, required Future<ApiTraceResponse> Function() execute, Set<ApiTraceDetail>? detailOverride, Map<String, Object?>? extra})` | `static Future<String?>` | REQ-API-001, REQ-API-002, REQ-API-005, REQ-API-007, REQ-API-008, REQ-API-009 |
| `ApiTrace.showOverlay(BuildContext context)` | `static void` (programmatic open) | REQ-UI-002, REQ-UI-005 |
| `ApiTrace.hideOverlay(BuildContext context)` | `static void` (programmatic close) | REQ-UI-002 |
| `ApiTrace.runApp(Widget app)` | `static void` (one-line bootstrap) | REQ-UI-001, REQ-UI-002 |

The `ApiTrace` class is `abstract final` with a private `_()` constructor
to prevent instantiation.

### `ApiTraceConfig` (`lib/src/config.dart`)

| Field | Type | Default | Source REQ |
| --- | --- | --- | --- |
| `details` | `Set<ApiTraceDetail>` | `{ApiTraceDetail.minimal}` | REQ-API-004, REQ-API-005, REQ-MODEL-005 |
| `maxResponseBodyBytes` | `int` | `4 * 1024` (4 KB) | REQ-API-004, REQ-MODEL-006 |
| `timelineCapacity` | `int` | `200` | REQ-API-004, REQ-MODEL-003 |
| `overlayPosition` | `ApiTraceOverlayPosition` | `ApiTraceOverlayPosition.bottomRight` | REQ-API-003, REQ-UI-003 |
| `overlayLabel` | `ApiTraceOverlayLabel` | `ApiTraceOverlayLabel.icon` | REQ-API-003, REQ-UI-004 |

The class is `final` and immutable. Mutable global state is exposed via
`ApiTrace.config` (a settable `static` field), not by mutating the
config object in place — this keeps the API explicit and avoids
surprising the developer.

### `ApiTraceDetail` enum (`lib/src/detail.dart`)

Five values, ordered from least to most detail: `minimal`, `headers`,
`request`, `response`, `full`. Pinned by REQ-API-004 and the spec's
"captured detail set" semantics.

### `ApiTraceOverlayPosition` enum (`lib/src/config.dart`)

Four values: `bottomRight` (default), `bottomLeft`, `topRight`, `topLeft`.
REQ-API-003, REQ-UI-003.

### `ApiTraceOverlayLabel` enum (`lib/src/config.dart`)

Three values: `icon` (default), `badge` (count when > 0), `chip` (text
"API N" when > 0). REQ-API-003, REQ-UI-004.

### `ApiTraceOutcome` enum (`lib/src/outcome.dart`)

Three values: `success`, `error`, `cancelled`. REQ-MODEL-002.
`cancelled` is reserved for future use; v1 never produces it but the
enum shape is fixed.

### `ApiTraceRecord` (`lib/src/model/api_trace_record.dart`)

Immutable value object. Constructed exclusively via the
`ApiTraceRecord.fromCapture(...)` factory; the public constructor is
`const` for tests and equals/hashCode, but the factory enforces
privacy defaults. REQ-MODEL-001, REQ-MODEL-005.

| Field | Type | Notes |
| --- | --- | --- |
| `id` | `String` | 32 hex chars from `Random.secure().nextBytes(16)` |
| `name` | `String` | developer-supplied |
| `startedAt` | `DateTime` | captured before `await execute()` |
| `completedAt` | `DateTime` | captured after `await execute()` |
| `method` | `String` | e.g. `"GET"` |
| `url` | `Uri` | request URL |
| `statusCode` | `int?` | null when error thrown before response |
| `duration` | `Duration` | `completedAt - startedAt`, non-negative |
| `outcome` | `ApiTraceOutcome` | derived (see *Error capture*) |
| `capturedDetails` | `Set<ApiTraceDetail>` | merged global + override |
| `request` | `ApiTraceRequest?` | null if `request` not in captured |
| `response` | `ApiTraceResponse?` | null if `response`/`full` not in captured |
| `error` | `Object?` | thrown exception / null |
| `extra` | `Map<String, Object?>` | developer-supplied tags |

`==` and `hashCode` are by identity (records are short-lived; the
timeline never searches by record). This is implementation-defined
behaviour and is not part of the contract.

### `ApiTraceRequest` (`lib/src/model/api_trace_request.dart`)

| Field | Type |
| --- | --- |
| `headers` | `Map<String, String>` (immutable; empty when `headers` not in captured) |
| `body` | `Object?` (null when `request`/`full` not in captured) |

### `ApiTraceResponse` (`lib/src/model/api_trace_response.dart`)

| Field | Type |
| --- | --- |
| `statusCode` | `int` |
| `requestHeaders` | `Map<String, String>` (empty when `headers` not in captured) |
| `responseHeaders` | `Map<String, String>` (empty when `headers` not in captured) |
| `requestBody` | `Object?` (null when `request`/`full` not in captured) |
| `responseBody` | `Object?` (null when `response`/`full` not in captured; truncated to `maxResponseBodyBytes`) |

### `ApiTraceOverlay` widget (`lib/src/overlay/api_trace_overlay.dart`)

Public so tests can `find.byType(ApiTraceOverlay)` (REQ-UI-002). The
class itself is a `StatelessWidget` whose `build` short-circuits to
`SizedBox.shrink()` when `!kDebugMode` (REQ-UI-001).

### `ApiTraceBootstrap` widget (`lib/src/bootstrap.dart`)

A `StatelessWidget` that wraps the developer's app. It is invisible in
release mode (entire `build` short-circuits) and mounts
`ApiTraceOverlay` in debug mode. Users invoke it via
`ApiTrace.runApp(app)`.

## Type definitions

Below are the locked Dart signatures (no surprises; everything is
immutable; every type has a `const` constructor where possible).

```dart
// lib/src/api_trace.dart
abstract final class ApiTrace {
  ApiTrace._();

  static late bool enabled = kDebugMode; // REQ-API-006
  static late ApiTraceConfig config = const ApiTraceConfig(); // REQ-API-004
  static final Timeline timeline = Timeline(config: config); // REQ-MODEL-003

  static Future<String?> call(
    String name, {
    required String method,
    required Uri url,
    required Future<ApiTraceResponse> Function() execute,
    Set<ApiTraceDetail>? detailOverride, // REQ-API-005
    Map<String, Object?>? extra, // optional developer tags
  });

  static void showOverlay(BuildContext context);
  static void hideOverlay(BuildContext context);
  static void runApp(Widget app); // REQ-UI-001, 002
}

// lib/src/config.dart
enum ApiTraceOverlayPosition { bottomRight, bottomLeft, topRight, topLeft }
enum ApiTraceOverlayLabel    { icon, badge, chip }

final class ApiTraceConfig {
  final Set<ApiTraceDetail> details;
  final int maxResponseBodyBytes;
  final int timelineCapacity;
  final ApiTraceOverlayPosition overlayPosition;
  final ApiTraceOverlayLabel    overlayLabel;

  const ApiTraceConfig({
    this.details = const {ApiTraceDetail.minimal},
    this.maxResponseBodyBytes = 4 * 1024,
    this.timelineCapacity = 200,
    this.overlayPosition = ApiTraceOverlayPosition.bottomRight,
    this.overlayLabel = ApiTraceOverlayLabel.icon,
  });
}

// lib/src/detail.dart
enum ApiTraceDetail { minimal, headers, request, response, full }

// lib/src/outcome.dart
enum ApiTraceOutcome { success, error, cancelled }

// lib/src/model/api_trace_record.dart
final class ApiTraceRecord {
  final String id;
  final String name;
  final DateTime startedAt;
  final DateTime completedAt;
  final String method;
  final Uri url;
  final int? statusCode;
  final Duration duration;
  final ApiTraceOutcome outcome;
  final Set<ApiTraceDetail> capturedDetails;
  final ApiTraceRequest?  request;
  final ApiTraceResponse? response;
  final Object? error;
  final Map<String, Object?> extra;

  const ApiTraceRecord({ /* see above */ });

  /// Privacy-conscious factory. Nulls out body / header fields whose
  /// detail level is not in [capturedDetails]. REQ-MODEL-005.
  factory ApiTraceRecord.fromCapture({ /* ... */ });
}

// lib/src/model/api_trace_request.dart
final class ApiTraceRequest {
  final Map<String, String> headers; // immutable
  final Object? body;
  const ApiTraceRequest({this.headers = const {}, this.body});
}

// lib/src/model/api_trace_response.dart
final class ApiTraceResponse {
  final int statusCode;
  final Map<String, String> requestHeaders;
  final Map<String, String> responseHeaders;
  final Object? requestBody;
  final Object? responseBody;
  const ApiTraceResponse({
    required this.statusCode,
    this.requestHeaders = const {},
    this.responseHeaders = const {},
    this.requestBody,
    this.responseBody,
  });
}

// lib/src/model/timeline.dart
final class Timeline {
  Timeline({required ApiTraceConfig config, int? capacity})
      : _capacity = capacity ?? config.timelineCapacity;

  final int _capacity;
  final List<ApiTraceRecord> _records = []; // head = newest
  final ValueNotifier<String?> latest = ValueNotifier<String?>(null);

  int get size => _records.length;
  List<ApiTraceRecord> get records => UnmodifiableListView(_records);

  void append(ApiTraceRecord r); // REQ-MODEL-003, 004
  void clear();                  // REQ-MODEL-008 (test-only)
}

// lib/src/overlay/api_trace_overlay.dart
class ApiTraceOverlay extends StatelessWidget {
  const ApiTraceOverlay({super.key});
  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink(); // REQ-UI-001
    // ... Stack with ApiTraceFab and (when open) TimelinePanel/DetailScreen
  }
}

// lib/src/bootstrap.dart
class ApiTraceBootstrap extends StatelessWidget {
  const ApiTraceBootstrap({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child; // REQ-UI-001 tree-shake
    // ... wraps child with MaterialApp.builder-style overlay
  }
}
```

The `child` field in `ApiTraceBootstrap` is the developer's own
`MaterialApp` (or any `Widget`); the bootstrap is a thin pass-through in
release mode.

## State and data flow

There are three independent states: **the static config**, **the
timeline ring buffer**, and **the overlay's open/closed state**. They
are deliberately decoupled so the API layer can be unit-tested without
a `BuildContext`.

### Static config

- `ApiTrace.config` is a settable `static late` field initialized to
  `const ApiTraceConfig()`. REQ-API-004.
- `ApiTrace.enabled` is a settable `static late` field initialized to
  `kDebugMode` at first read. REQ-API-006.
- A change to `ApiTrace.config` does not retroactively re-process past
  records; it only affects subsequent `ApiTrace.call(...)` invocations
  and the overlay's FAB position / label rendering (via `ValueListenable`
  on the config).

### Timeline ring buffer

- Owned by `ApiTrace.timeline` (a `Timeline` instance). REQ-MODEL-003,
  REQ-MODEL-008.
- `_records` is a `List<ApiTraceRecord>` with `head = newest`. Append
  is `_records.insert(0, r)` followed by `if (_records.length > _capacity) _records.removeLast();`. This preserves newest-first ordering with the natural insertion-order tie-breaker required by REQ-MODEL-004 (the later-inserted record is at the head, so it appears first when iterated head-to-tail).
- The `latest` `ValueNotifier<String?>` is set to the new record's id
  on every append. The overlay subscribes to it and rebuilds.
- No `Stream`, no `Completer`, no `Lock`/`Mutex`. Single-isolate,
  single-threaded; `append` is synchronous and atomic from the event
  loop's perspective. REQ-API-009, REQ-MODEL-007.

### Overlay open/closed state

- The overlay is always mounted in debug mode (REQ-UI-002).
- The FAB is always rendered. Tapping it toggles an internal
  `_open` `ValueNotifier<bool>` on the `ApiTraceBootstrap` widget.
- When `_open` is true, a `TimelinePanel` is rendered above the
  developer's UI; otherwise only the FAB is shown.
- Tapping a row in the panel pushes a `Navigator` route for the
  `ApiTraceDetailScreen` (read-only). The Navigator uses the
  developer's nearest `Navigator` via `Navigator.of(context)`.

### End-to-end flow for one call

1. `ApiTrace.call(name: "listOrders", method: "GET", url: …, execute: …)`.
2. `if (!ApiTrace.enabled) return Future.value(null);` — REQ-API-002.
3. `final startedAt = DateTime.now();`
4. `ApiTraceResponse? response; Object? error; StackTrace? st;`
5. `try { response = await execute(); } catch (e, s) { error = e; st = s; }`
6. `final completedAt = DateTime.now();`
7. `final effectiveDetails = {…ApiTrace.config.details, …?detailOverride};`
8. `final record = ApiTraceRecord.fromCapture(…, capturedDetails: effectiveDetails, config: ApiTrace.config);`
9. `ApiTrace.timeline.append(record);` — updates `_records` and `latest`.
10. `return record.id;` — REQ-API-008.

The overlay (subscribed to `timeline.latest`) rebuilds and shows the
new record at the top of the panel.

## Concurrency model

**Dart is single-threaded per isolate**, and the package does not
introduce `Isolate`s. The only meaningful concurrency hazard is
**reentrancy**: a `ApiTrace.call` invocation awaits `execute()`, and
during that await another `ApiTrace.call` may be invoked (directly or
transitively, e.g. an HTTP client that calls the inspector before
issuing the real request).

The reentrancy strategy is **"no synchronization, list-as-ring-buffer"**:

- Each `ApiTrace.call(...)` invocation owns a `startedAt`, a local
  `response` / `error` / `st`, and a single `Future<String?>` return.
- The only `await` is `await execute()`. After that await resolves (or
  rethrows), the call site **synchronously** builds the record and
  calls `Timeline.append(record)`. No other `await` happens between the
  record construction and the append.
- Two overlapping calls each build their own record independently;
  both `append`s happen on the event loop without preemption. The
  timeline ends up with two records in completion order.
- The id is generated via `Random.secure().nextBytes(16)` *per call*,
  so two calls cannot collide. The id is generated **before**
  `execute()` is awaited to ensure it is available even if the test
  asserts on it during the await.
- REQ-MODEL-004's tie-breaker ("later insertion wins") is satisfied by
  the head-insert ordering: the second-completed record is inserted at
  index 0, so it appears before the first-completed record in any
  head-to-tail iteration.
- No `Zone`, no `Completer` chain, no `Lock`, no `Stream` broadcast, no
  `Isolate.run`. The reentrancy scenario in REQ-API-009 is satisfied
  by the natural single-threaded event-loop semantics.

This is verified by `test/api_trace_test.dart` scenarios
`Two concurrent calls` and `Reentrant call` (REQ-API-009,
REQ-MODEL-007).

## kDebugMode guard and tree-shake strategy

`kDebugMode` from `package:flutter/foundation.dart` is a `const bool`
that is `true` in `flutter test` and `flutter build --debug`, and
`false` in `flutter build --profile` and `flutter build --release`. The
Dart AOT compiler tree-shakes any branch whose condition is
`const false`, so the entire overlay surface can be guarded by a
single `if (kDebugMode)` block in the right place.

The guards are placed at **four** call sites, each verified by a
distinct test:

1. **`ApiTraceOverlay.build`** — `if (!kDebugMode) return const SizedBox.shrink();`
   ensures the widget does not even attempt to render in release.
   REQ-UI-001.

2. **`ApiTraceBootstrap.build`** — `if (!kDebugMode) return child;`
   means the bootstrap is a pass-through in release, so the
   `ApiTraceOverlay` widget is never even instantiated. REQ-UI-001,
   REQ-UI-002.

3. **`ApiTrace.runApp`** — `if (!kDebugMode) { runApp(app); return; }`
   means the helper is a pass-through in release; no
   `ApiTraceBootstrap` is ever constructed. The `runFrameCallback`
   that subscribes to `ApiTrace.timeline.latest` is unreachable.
   REQ-UI-001.

4. **`ApiTrace.call`** — the `enabled` short-circuit returns
   `Future.value(null)` *before* any work. In release, `enabled` is
   `false` (because `kDebugMode` is `false`), so every `ApiTrace.call`
   is a `Future.value(null)` microtask. The body of `call` (the
   `try { await execute() } catch …` block, the `ApiTraceRecord.fromCapture`,
   the `timeline.append`) is reachable only when `enabled` is `true`,
   which is when `kDebugMode` is `true`, which is when the user is
   in debug. This is the cleanest possible "no overhead in release"
   contract.

5. **The `ApiTrace.enabled` late initializer** — `static late bool
   enabled = kDebugMode;` evaluates `kDebugMode` once at first read.
   In release, the read happens in the bootstrap and the assignment
   is a `const false`, so the `enabled` check is branch-predicted as
   always false.

The release-build smoke test (binary size delta ≤ 5 KB, no
`ApiTraceOverlay` string in the symbol table, no FAB in the release
widget tree) is captured **out-of-band** in `apply-progress.md` and
`verify-report.md`, not in `flutter test`, per REQ-UI-001 and the
proposal's success metric #3. The `flutter test` widget test for
REQ-UI-001 (RELEASE) uses `debugDefaultTargetPlatformOverride` plus
`kReleaseMode` to simulate release-mode behavior in-process; the
actual `flutter build --release` is run by `sdd-apply` against the
`example/` app on a host with the right SDKs.

## Privacy-conscious default enforcement

The privacy contract (REQ-MODEL-005) is enforced **at construction
time** in `ApiTraceRecord.fromCapture`, not lazily at render time. The
choice is deliberate:

- **Why construction-time, not render-time**: a render-time check
  (e.g. "if `!request` in capturedDetails, hide the section") is
  fragile — it depends on the render path being correct, and a future
  developer adding a new render path could leak data. A
  construction-time check makes the leak impossible by construction:
  the field is `null` in memory, so it cannot be rendered.
- **Why a factory, not a `Map`**: a factory gives us a single chokepoint
  for the null-out logic and lets us keep the record's `final` fields
  truly final. A `Map<String, Object?>` would lose the type information
  the spec requires (REQ-MODEL-001).

The factory logic:

```dart
factory ApiTraceRecord.fromCapture({
  required String name,
  required DateTime startedAt,
  required DateTime completedAt,
  required String method,
  required Uri url,
  required ApiTraceConfig config,
  required Set<ApiTraceDetail> capturedDetails,
  required ApiTraceResponse? response,
  required Object? error,
  required Map<String, Object?> extra,
}) {
  // Truncate body to maxResponseBodyBytes if response/full in captured.
  final keepHeaders  = capturedDetails.contains(ApiTraceDetail.headers);
  final keepRequest  = capturedDetails.contains(ApiTraceDetail.request) ||
                        capturedDetails.contains(ApiTraceDetail.full);
  final keepResponse = capturedDetails.contains(ApiTraceDetail.response) ||
                        capturedDetails.contains(ApiTraceDetail.full);

  final truncatedResponse = (response == null || !keepResponse)
      ? null
      : response.copyWith(
          responseBody: bodyCodec.truncate(response.responseBody, config.maxResponseBodyBytes),
        );

  final redactedResponse = (truncatedResponse == null || !keepHeaders)
      ? truncatedResponse
      : truncatedResponse.copyWith(
          requestHeaders: const {},
          responseHeaders: const {},
        );

  final redactedRequest = !keepRequest
      ? null
      : ApiTraceRequest(
          headers: keepHeaders ? (request?.headers ?? const {}) : const {},
          body:    keepRequest  ? (request?.body) : null,
        );

  return ApiTraceRecord(
    id: id.generate(),
    name: name,
    startedAt: startedAt,
    completedAt: completedAt,
    method: method,
    url: url,
    statusCode: response?.statusCode,
    duration: completedAt.difference(startedAt),
    outcome: deriveOutcome(response: response, error: error), // see Error capture
    capturedDetails: capturedDetails,
    request: redactedRequest,
    response: redactedResponse,
    error: error,
    extra: extra,
  );
}
```

This is the single source of truth for privacy. Any future render path
that reads `record.request` or `record.response` will see `null` when
the field is not captured. REQ-MODEL-005 is satisfied by construction,
not by convention.

## Overlay bootstrap path

The package exposes a single one-line bootstrap:

```dart
// In the developer's main():
void main() {
  ApiTrace.runApp(const MyApp());
}
```

`ApiTrace.runApp` is implemented as:

```dart
static void runApp(Widget app) {
  if (!kDebugMode) {
    // release-mode pass-through: zero overhead, no overlay.
    WidgetsFlutterBinding.ensureInitialized();
    FlutterBindingWrap.runApp(app);
    return;
  }
  WidgetsFlutterBinding.ensureInitialized();
  FlutterBindingWrap.runApp(ApiTraceBootstrap(child: app));
}
```

(Where `FlutterBindingWrap.runApp` is the existing
`runApp` from `package:flutter/widgets.dart` — it is referenced
indirectly to make the pass-through obvious in code review.)

`ApiTraceBootstrap` is a `StatelessWidget` that:

1. In `build`, returns `child` unchanged in release mode (so the
   widget tree in release is bit-identical to the user's own app).
2. In debug mode, wraps `child` with a `Builder` that injects an
   `Overlay` above the developer's UI and inserts an
   `OverlayEntry` containing the `ApiTraceOverlay` widget.

The `Overlay` insertion is the standard pattern from Flutter's own
`WidgetsApp.builder` (the official hook for adding an overlay above
the developer's content). The `ApiTraceOverlay` is wrapped in a
`Positioned.fill` so it fills the screen; the FAB inside it is
positioned with `Align(alignment: fabAlignment(config.overlayPosition))`.

The "auto-mount" contract (REQ-UI-002) is satisfied: the developer
calls one function (`ApiTrace.runApp`), and the overlay is mounted.
There is no `Scaffold` to wrap, no `MaterialApp` subclass to extend,
no `Overlay.of(context).insert(...)` boilerplate to write.

The test for REQ-UI-002 pumps `ApiTrace.runApp(MaterialApp(home: …))`
and `find.byType(ApiTraceOverlay)` returns exactly one match.

## Configuration surface

`ApiTraceConfig` is an immutable value class. The mutable global is
`ApiTrace.config` itself; reassigning it is the only way to change
capture behavior app-wide. Per-call `detailOverride` takes precedence
over the global config.

### Precedence (REQ-API-005)

```
effectiveDetails = config.details ∪ (detailOverride ?? {})
```

A null `detailOverride` falls back to the global `config.details`
unchanged. A non-null `detailOverride` is **unioned** with the global
config — the override widens capture; it never narrows. This is
intentional: a per-call override of `{ApiTraceDetail.response}` against
a global `{ApiTraceDetail.minimal, ApiTraceDetail.headers}` yields
`{minimal, headers, response}`.

### Reading order (caller's perspective)

1. `ApiTrace.enabled` (master switch) — if `false`, `ApiTrace.call`
   short-circuits.
2. `ApiTrace.config.details` (global defaults).
3. `detailOverride` per call (widen only).
4. The union is the **captured detail set** for that record.
5. `ApiTrace.config.maxResponseBodyBytes` is the truncation limit.
6. `ApiTrace.config.timelineCapacity` is the ring buffer size.
7. `ApiTrace.config.overlayPosition` and `ApiTrace.config.overlayLabel`
   affect the FAB rendering only — they do **not** affect capture.

### Mutability rules

- `ApiTrace.config` is a settable `static late` field. Reassignment is
  the only way to change config app-wide.
- `ApiTraceConfig` itself is immutable; fields are `final`. To change a
  single field, callers do `ApiTrace.config = ApiTraceConfig(details:
  …)` (copy-with pattern).
- `ApiTrace.timeline` is a `static final Timeline` — the ring buffer
  instance cannot be replaced, only appended to. This prevents the
  developer from accidentally losing all records by reassigning the
  reference.

## Error capture

Error capture is the bridge between `ApiTrace.call` and the
`ApiTraceRecord.outcome` field. The logic lives in a private
`deriveOutcome` function in `lib/src/api_trace.dart`:

```dart
ApiTraceOutcome deriveOutcome({
  required ApiTraceResponse? response,
  required Object? error,
}) {
  if (error != null) return ApiTraceOutcome.error;
  final code = response?.statusCode ?? 0;
  if (code >= 400 && code < 600) return ApiTraceOutcome.error;
  return ApiTraceOutcome.success;
}
```

Rules (REQ-API-007):

- **Thrown exception** in `execute` → `outcome = error`, `error`
  field captures the exception object (typically an `Object`; tests
  use `FormatException`).
- **HTTP 4xx** (`400–499`) → `outcome = error`, `response.statusCode`
  preserved, `error` field null.
- **HTTP 5xx** (`500–599`) → `outcome = error`, same as above.
- **HTTP 1xx, 2xx, 3xx** → `outcome = success`, `error` field null.
- **HTTP 0 / null** (response missing) → treated as `success` if no
  exception was thrown; this case is rare in practice (it means the
  developer returned a null `ApiTraceResponse` from `execute` without
  throwing) and the contract is "no exception, no 4xx/5xx, so success".
- **`cancelled`** is reserved for future use; v1 never produces it.

The UI colors the row red when `outcome == error` and green when
`outcome == success`. 4xx and 5xx share the same red; this is verified
by REQ-UI-008's `4xx and 5xx share the same red color` scenario.

When the `error` field is set, the `response` field is still populated
(if the developer returned one before throwing) — but in practice, an
exception means no `ApiTraceResponse` was returned, so `response` is
null. The `ApiTraceResponse` constructor requires `statusCode`, so a
null response implies the developer never reached the `return
ApiTraceResponse(...)` line. The `statusCode` field on the record is
`response?.statusCode` and is null in that case.

## Testability

Every REQ has at least one test scenario. The mapping below tells
`sdd-tasks` which test file to create and which REQ(s) it satisfies.
The test names match the scenario names from the specs (one test per
scenario, plus triangulation tests).

### Unit tests (`test/`)

| Test file | Scenarios covered | REQ(s) |
| --- | --- | --- |
| `api_trace_test.dart` | Execute callback awaited once; Recorded response matches execute return value; Disabled call returns null; Disabled call never invokes execute; Per-call override unions with global; Per-call override does not mutate global config; Null override uses global; enabled is true at first read in debug; Thrown exception captured as error; 4xx response captured as error; 5xx response captured as error; 2xx response captured as success; Returned id matches recorded record; Reentrant call produces two distinct records; Two concurrent calls each produce a record | REQ-API-001, REQ-API-002, REQ-API-005, REQ-API-006, REQ-API-007, REQ-API-008, REQ-API-009, REQ-MODEL-007 |
| `config_test.dart` | Default overlay position is bottom-right; Default overlay label is icon; overlayPosition enum has exactly four values; overlayLabel enum has exactly three values; Default config details contain only minimal; Default config timeline capacity is 200; Default config max response body bytes is 4 KB | REQ-API-003, REQ-API-004 |
| `detail_test.dart` | ApiTraceDetail enum shape (5 values) | REQ-API-004 |
| `outcome_test.dart` | Enum has exactly three cases | REQ-MODEL-002 |
| `timeline_test.dart` | Default capacity holds exactly 200 records; Oldest record evicted when capacity is exceeded; Capacity honored when configured explicitly; Newest record first; Insertion order breaks tie on identical start time; Two concurrent calls each produce a record; Timeline resets across process restart | REQ-MODEL-003, REQ-MODEL-004, REQ-MODEL-007, REQ-MODEL-008 |
| `api_trace_record_test.dart` | Record exposes all required fields with correct types; Record fields are immutable; Minimal capture has no body or headers; Headers-only capture includes headers but not bodies | REQ-MODEL-001, REQ-MODEL-005 |
| `body_codec_test.dart` | Response body truncated to default 4 KB; Response body truncation honors configured limit | REQ-MODEL-006 |
| `id_test.dart` | 32-hex-char id; no collisions in 1k generations; secure RNG | (helper) |

### Widget tests (`test/`)

| Test file | Scenarios covered | REQ(s) |
| --- | --- | --- |
| `overlay_test.dart` | Overlay widget absent under kReleaseMode; Overlay present under kDebugMode; Overlay absent when ApiTrace.enabled is false; FAB at bottomRight by default; FAB at topLeft after config change; Icon-only FAB by default; Badge FAB shows count when > 0; Badge FAB hides count when count is 0; Newest-first ordering; Empty timeline shows empty state; Error-only filter; Name substring filter; Underlying timeline is not mutated by filters; Detail screen shows captured fields (no Copy as cURL / Re-run / Export); Success row is green; Error row is red; 4xx and 5xx share the same red color | REQ-UI-001, REQ-UI-002, REQ-UI-003, REQ-UI-004, REQ-UI-005, REQ-UI-006, REQ-UI-007, REQ-UI-008 |
| `bootstrap_test.dart` | Release-mode pass-through is identity; Debug-mode mounts exactly one `ApiTraceOverlay`; Mount point is above the developer's `Scaffold` body | REQ-UI-001, REQ-UI-002 |

### Testability rules

- All tests use `flutter_test`. No `integration_test` (not required
  for v1, per `openspec/config.yaml`).
- Widget tests use `WidgetTester` and `pumpWidget`. The bootstrap is
  invoked as `await tester.pumpWidget(ApiTraceBootstrap(child:
  MaterialApp(home: ...)))`.
- Unit tests reset `ApiTrace.timeline` (via a `clear()` method gated by
  `@visibleForTesting`) in `setUp` so tests do not leak records
  between cases.
- The release-mode simulation test (`test/overlay_test.dart`,
  `Overlay widget absent under kReleaseMode`) uses
  `kReleaseMode = true` in a `setUp` / `tearDown` block plus
  `tester.pumpWidget` — this exercises the `kDebugMode` branch
  in-process without requiring an actual release build.
- The actual `flutter build --release` smoke test (binary size delta,
  symbol-table absence) is out-of-band and is captured in
  `apply-progress.md` by `sdd-apply` and verified in `verify-report.md`
  by `sdd-verify`.

## File-by-file map

| File | Exports / types | REQ(s) satisfied |
| --- | --- | --- |
| `lib/flutter_api_inspector.dart` | re-exports the public surface | (barrel) |
| `lib/src/api_trace.dart` | `ApiTrace` (static), `deriveOutcome` private | REQ-API-001, REQ-API-002, REQ-API-005, REQ-API-006, REQ-API-007, REQ-API-008, REQ-API-009 |
| `lib/src/config.dart` | `ApiTraceConfig`, `ApiTraceOverlayPosition`, `ApiTraceOverlayLabel` | REQ-API-003, REQ-API-004 |
| `lib/src/detail.dart` | `ApiTraceDetail` | REQ-API-004 |
| `lib/src/outcome.dart` | `ApiTraceOutcome` | REQ-MODEL-002 |
| `lib/src/bootstrap.dart` | `ApiTraceBootstrap` widget | REQ-UI-001, REQ-UI-002 |
| `lib/src/id.dart` | `id.generate()` private | (helper) |
| `lib/src/body_codec.dart` | `bodyCodec.truncate(...)` private | REQ-MODEL-006 |
| `lib/src/model/api_trace_record.dart` | `ApiTraceRecord` (+ `fromCapture` factory) | REQ-MODEL-001, REQ-MODEL-005 |
| `lib/src/model/api_trace_request.dart` | `ApiTraceRequest` | REQ-MODEL-001, REQ-MODEL-005 |
| `lib/src/model/api_trace_response.dart` | `ApiTraceResponse` | REQ-MODEL-001, REQ-MODEL-005, REQ-MODEL-006 |
| `lib/src/model/timeline.dart` | `Timeline` | REQ-MODEL-003, REQ-MODEL-004, REQ-MODEL-007, REQ-MODEL-008 |
| `lib/src/overlay/api_trace_overlay.dart` | `ApiTraceOverlay` widget | REQ-UI-001, REQ-UI-002, REQ-UI-005, REQ-UI-007 |
| `lib/src/overlay/fab.dart` | `ApiTraceFab` widget | REQ-UI-003, REQ-UI-004 |
| `lib/src/overlay/fab_position.dart` | `fabAlignment(...)` private | REQ-UI-003 |
| `lib/src/overlay/timeline_panel.dart` | `TimelinePanel` widget | REQ-UI-005, REQ-UI-006 |
| `lib/src/overlay/timeline_row.dart` | `TimelineRow` widget | REQ-UI-005, REQ-UI-008 |
| `lib/src/overlay/detail_screen.dart` | `ApiTraceDetailScreen` widget | REQ-UI-007 |
| `lib/src/overlay/colors.dart` | `outcomeColor(...)` private | REQ-UI-008 |
| `test/api_trace_test.dart` | unit tests | REQ-API-001, 002, 005, 006, 007, 008, 009; REQ-MODEL-007 |
| `test/config_test.dart` | unit tests | REQ-API-003, 004 |
| `test/detail_test.dart` | unit tests | REQ-API-004 |
| `test/outcome_test.dart` | unit tests | REQ-MODEL-002 |
| `test/timeline_test.dart` | unit tests | REQ-MODEL-003, 004, 007, 008 |
| `test/api_trace_record_test.dart` | unit tests | REQ-MODEL-001, 005 |
| `test/body_codec_test.dart` | unit tests | REQ-MODEL-006 |
| `test/id_test.dart` | unit tests | (helper) |
| `test/overlay_test.dart` | widget tests | REQ-UI-001, 002, 003, 004, 005, 006, 007, 008 |
| `test/bootstrap_test.dart` | widget tests | REQ-UI-001, 002 |
| `example/main.dart` | `runApp(ApiTrace.runApp(MyApp()))` + one `ApiTrace.call(...)` against a stub and one against `httpbin.org/get` | (smoke) |
| `example/pubspec.yaml` | local path: `../`; `flutter: { sdk: flutter }` | (smoke) |

## Affected areas

This phase does not modify any files outside
`openspec/changes/flutter_api_inspector-mvp/`. The package code,
`pubspec.yaml`, `test/`, `example/`, `README.md`, `CHANGELOG.md`, and
`LICENSE` are owned by `sdd-tasks` and `sdd-apply`, not by this
design phase. The design's affected areas are exactly the files
listed in *File-by-file map* and the `openspec/changes/
flutter_api_inspector-mvp/design.md` artifact itself.

For traceability, the mirror of the proposal's affected areas:

- `pubspec.yaml` (new) — owned by `sdd-tasks` / `sdd-apply`. This
  design recommends `name: flutter_api_inspector`,
  `description: …`, `version: 0.1.0`, `flutter: ">=3.16.0"`,
  `dart: ">=3.2.0"`, `dependencies: { flutter: { sdk: flutter } }`,
  `dev_dependencies: { flutter_test: { sdk: flutter } }`. No third-
  party packages.
- `lib/` (new) — package source, as mapped above.
- `test/` (new) — strict TDD test files, as mapped above.
- `example/` (new) — stub + one real call to `https://httpbin.org/get`
  (or `https://jsonplaceholder.typicode.com/todos/1`), gated by a
  "Run real call" button so the offline test suite skips it.
- `README.md`, `CHANGELOG.md`, `LICENSE` (new) — pub.dev surface,
  owned by `sdd-apply`. LICENSE is MIT (per locked answer to
  proposal open question #8).
- `openspec/specs/{instrumentation-api,overlay-ui,timeline-model}/spec.md`
  (canonical) — owned by `sdd-archive` (copy from delta to canonical).
- `openspec/changes/flutter_api_inspector-mvp/{design,tasks,apply-progress,verify-report,sync-report,archive-report}.md`
  — owned by the corresponding SDD phases.

## Open technical questions

These are implementation-level questions that `sdd-tasks` should
either resolve from the spec or raise to the user before `sdd-apply`.
None of them change the spec contract; they are choices between
equally valid implementations.

1. **FAB icon choice.** The spec says "icon-only FAB" but does not
   pick the icon. Candidates: `Icons.api`, `Icons.developer_mode`,
   `Icons.bug_report`, `Icons.list_alt`, `Icons.terminal`.
   **Recommendation**: `Icons.developer_mode` (semantically
   "developer surface") on a circular 40-px FAB. **Action**: pick in
   `sdd-tasks`.

2. **Body parser strategy for JSON vs text.** The spec says
   `responseBody` is "a parsed representation of the prefix". When the
   developer returns a `String` (e.g. raw HTTP body), should the
   package try to `jsonDecode` it for the detail view?
   **Recommendation**: do **not** parse — the developer is responsible
   for returning an `Object?` body (already parsed or already a
   `String`); the package only truncates. The detail view renders the
   body via `defaultTextStyle` for `String` and via `toString()` for
   everything else. **Action**: confirm in `sdd-tasks`.

3. **Detail-screen route shape.** Tapping a row pushes a route via
   the developer's nearest `Navigator`. Should the route use
   `MaterialPageRoute` (Material design, slide-in) or a custom
   overlay-modal (more debug-tool-ish)?
   **Recommendation**: `MaterialPageRoute` (consistent with the rest
   of the user's app). **Action**: confirm in `sdd-tasks`.

4. **FAB visibility for zero records.** The spec says
   "icon-only FAB" but does not say whether the FAB is visible when
   the timeline is empty. The proposal says "FAB activation: auto-
   shown when kDebugMode is true", which implies always visible.
   **Recommendation**: always visible. **Action**: confirm in
   `sdd-tasks`.

5. **Theme handling.** The overlay uses `Theme.of(context)` for the
   panel and detail screen, but the FAB color is a fixed `ColorScheme.
   primary` / `secondary`. Should the overlay respect the user's
   `ThemeData` or use a fixed `ColorScheme`?
   **Recommendation**: respect the user's `ThemeData` for the panel
   and detail screen; the FAB uses `Theme.of(context).colorScheme.
   primary`; the green/red outcome colors are fixed
   (`Colors.green.shade600` / `Colors.red.shade600`). **Action**:
   confirm in `sdd-tasks`.

6. **Id generation collision space.** `Random.secure().nextBytes(16)`
   gives 16 random bytes = 128 bits. Collision probability for N
   records is ~N²/2¹²⁹, which is negligible for the default 200-
   record ring buffer. **Action**: no decision needed; documented in
   `test/id_test.dart` (10k generations, zero collisions).

7. **`ApiTraceScaffold` escape hatch.** The spec marks it out-of-scope
   for v1. Should the design reserve a name for it so a future change
   can add it without renaming? **Recommendation**: do not reserve;
   the package is v1. **Action**: no decision needed.

8. **Release-build smoke test environment.** The proposal's success
   metric #3 requires `flutter build --release` with binary size
   delta ≤ 5 KB. The host running `sdd-apply` and `sdd-verify` must
   have an Android SDK or Xcode toolchain. **Action**: if the host
   does not, `sdd-verify` records this as a deferred gate and the
   apply phase records the build command for a follow-up
   environment.

## Result Contract

```yaml
status: complete
executive_summary: >-
  SDD design written for flutter_api_inspector-mvp. The design derives
  the technical blueprint directly from the 25 numbered REQ-* items in
  the three delta spec files and is structured to give sdd-tasks a
  one-to-one file-to-REQs map. Module layout is one type per file
  under lib/src/ with a model/ overlay/ and bootstrap split; public
  surface is the minimal ApiTrace static class plus immutable
  ApiTraceConfig / ApiTraceRecord / ApiTraceRequest / ApiTraceResponse
  / ApiTraceOutcome / ApiTraceDetail / ApiTraceOverlayPosition /
  ApiTraceOverlayLabel. The overlay bootstrap is a single
  ApiTrace.runApp(Widget) call guarded by if (kDebugMode), and the
  privacy-conscious default is enforced at ApiTraceRecord construction
  time (not at render time) via a fromCapture factory. Reentrancy is
  handled by the natural single-isolate event-loop semantics: each
  ApiTrace.call owns a local record, the timeline is a plain
  List<ApiTraceRecord> with head-insert, and there are no Streams,
  Isolates, Completers, or synchronization primitives. No code,
  pubspec.yaml, lib/, test/, or example/ was created in this phase.
artifacts:
  - openspec/changes/flutter_api_inspector-mvp/design.md
next_recommended: sdd-tasks # after user review
risks:
  - "Eight open technical questions are listed (FAB icon, body parser
    strategy, detail-screen route shape, FAB visibility for empty
    timeline, theme handling, id generation collision space,
    ApiTraceScaffold naming, release-build smoke test environment).
    None change the spec contract; sdd-tasks resolves them with
    documented defaults or surfaces them to the user."
  - "No pubspec.yaml exists yet. The lib/src/, test/, and example/
    layouts in this design cannot be exercised until sdd-tasks /
    sdd-apply. The release-build smoke test (binary size delta <=
    5 KB, no ApiTraceOverlay in the symbol table) requires an
    Android SDK or Xcode toolchain and may be deferred to a
    follow-up environment."
  - "The kDebugMode tree-shake strategy depends on the Dart AOT
    compiler removing const-false branches. This is the documented
    behavior of flutter build --release and is verified by the
    release-build smoke test, not by flutter test."
  - "The reentrancy design assumes a single Dart isolate. If a
    future change introduces an Isolate, the timeline ring buffer
    will need synchronization; this design explicitly does not
    add it (single-isolate per the spec)."
  - "The privacy-conscious default is enforced in
    ApiTraceRecord.fromCapture. Any future code path that constructs
    ApiTraceRecord directly (e.g. a hypothetical migration
    constructor) MUST go through fromCapture to maintain the
    privacy contract; this is documented in the file's doc
    comment."
  - "The widget tree in release mode is intended to be bit-identical
    to the developer's own app (ApiTraceBootstrap.build returns
    child unchanged when !kDebugMode). The release-build smoke
    test verifies this by comparing the widget tree of
    `ApiTrace.runApp(App())` vs `runApp(App())`."
  - "The sdd-design agent file is minimal (no design format is
    prescribed). The design format used here (Purpose / Goals /
    Architecture / Module / Public surface / Type defs / State /
    Concurrency / kDebugMode / Privacy / Bootstrap / Configuration /
    Error capture / Testability / File map / Affected areas /
    Open questions / Result contract) was derived from the task
    brief and from the spec's REQ-by-REQ traceability requirement."
skill_resolution: paths-injected
```
