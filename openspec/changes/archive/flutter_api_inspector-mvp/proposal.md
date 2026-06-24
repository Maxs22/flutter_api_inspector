# Proposal — `flutter_api_inspector-mvp`

- **Change**: `flutter_api_inspector-mvp`
- **Date**: 2026-06-23
- **Phase**: `sdd-proposal`
- **Status**: proposal — awaiting user review
- **Artifact store**: OpenSpec in repo (`openspec/changes/flutter_api_inspector-mvp/`)

---

## Problem statement

Flutter app developers have no lightweight, code-local way to inspect the API
traffic their app generates during development. Existing options each fail a
key dimension:

- **`dio` interceptors** — only cover `package:dio` users; invisible to
  `package:http`, `dart:io`, gRPC, and platform channels.
- **`http.Client` overrides / proxy shims** — global side effects, easy to
  forget in production, and they change app networking semantics.
- **Charles / Proxyman / Wireshark** — require OS-level setup, MITM cert
  installation, and a separate UI; high friction for the first 10 minutes of
  a new project.
- **`print` / `developer.log` calls** — unstructured, no timeline, no
  details, no way to surface headers or bodies cleanly.

The result: when an endpoint misbehaves (wrong status, slow response,
unexpected body, missing header), developers waste time sprinkling logs,
rebuilding, and reading scrolling console output. There is no in-app
visualization that shows "the last 20 calls, in order, with the bodies I
care about" — and no way to do that without either taking over the
networking layer or leaving the app.

`flutter_api_inspector` fills that gap with **manual instrumentation** at
the call site (developer stays in control of what is traced) and a
**debug-only in-app overlay** (no extra tooling, no certs, no global
network mutation). The overlay is opt-out via `ApiTrace.enabled` and
guaranteed to be tree-shaken from `flutter build --release` binaries.

## Target users

- **Solo Flutter app developers** shipping side projects and MVPs on iOS,
  Android, macOS, Windows, and Linux. They want first-class debug
  visibility without paying for a Charles seat or a Dio migration.
- **Small Flutter teams (2–5 devs)** sharing a single product codebase.
  They want consistent call tracing across teammates, with per-call and
  global config knobs so individual features can opt into richer capture
  (e.g. file upload screens) without leaking auth tokens into everyone
  else's traces.
- **Library authors and SDK maintainers** who build on top of
  `package:http` and want a non-invasive way to expose call diagnostics in
  debug builds for downstream app developers.

These are the personas the MVP must serve. The "platform team at a 200-dev
shop with a dedicated API gateway" persona is explicitly out of scope; that
audience has paid observability tools.

## Locked architecture (reference only — do not re-derive)

The architecture is already locked in `openspec/AGENTS.md` rules 6 and 7
and `openspec/config.yaml` → `stack`. This proposal references those
decisions; it does not re-litigate them.

- **Manual instrumentation API only.** Explicit `ApiTrace.call(name, url,
  params)` style. No auto-interceptor (no `http` client overrides, no Dio
  interceptors, no `package:dio` shim). See `openspec/AGENTS.md` rule 7.
- **Debug-only overlay.** Floating action button + overlay panel, guarded
  by `kDebugMode` from `package:flutter/foundation.dart`. A
  `flutter build --release` build must not include the overlay surface in
  the final binary tree-shaking pass. See `openspec/AGENTS.md` rule 6.
- **Chronological timeline visualization** with tap-to-detail per call.
  See `openspec/config.yaml` → `stack.debug_surface.visualization`.

Any phase that wants to introduce an auto-interceptor, a global
`http.Client` wrap, or release-mode overlay rendering must raise a risk
and stop, not silently amend the contract.

## User product decisions (captured this round)

| Decision | Choice | Why |
| --- | --- | --- |
| Detail level per call | **Configurable** — per-call and global config | Some screens (auth, file upload) need full bodies; the default should be privacy-conscious. |
| Default detail fields | URL + method + status + duration | Avoids leaking tokens, PII, or large payloads by accident. |
| Per-call override | Wins over global config | Lets a single call request richer capture (e.g. a multipart upload) without changing app-wide config. |
| Persistence | **In-memory only** for v1 | No disk write, no SQL, no encryption, no consent flow needed. The list resets on app kill. |
| FAB activation | Auto-shown when `kDebugMode` is true | Zero wrap-in cost. `ApiTrace.enabled = false` is the explicit opt-out. |
| `ApiTraceScaffold` wrap | **Not required** for v1 | Keep the integration surface to one boolean. |
| Actions on a call | **Visualization only** — no cURL copy, no re-run, no export | Stay focused; the lowest-friction timeline is also the easiest to ship. |
| Detail screen | Read-only | Matches the "visualization only" scope. |

These decisions are **locked at proposal time** and will be carried into
`specs/`, `design.md`, and `tasks.md` in the next phases.

## Public API surface (sketch — refined in sdd-spec)

The MVP surface is intentionally small. Names and signatures here are
proposals; sdd-spec will lock the exact contracts.

```dart
// lib/src/config.dart
enum ApiTraceDetail {
  /// Only the metadata needed to understand what happened.
  minimal, // method, url, status, duration
  /// Adds request/response headers.
  headers,
  /// Adds the parsed request body (JSON, form-data summary).
  request,
  /// Adds the parsed response body (truncated to N KB).
  response,
  /// Everything above, including raw bytes for binary responses.
  full,
}

class ApiTraceConfig {
  final Set<ApiTraceDetail> details;
  final int maxResponseBodyBytes;
  final int timelineCapacity;

  const ApiTraceConfig({
    this.details = const {ApiTraceDetail.minimal},
    this.maxResponseBodyBytes = 4 * 1024,
    this.timelineCapacity = 200,
  });

  static ApiTraceConfig global; // initialized by ApiTrace.init
}

// lib/src/api_trace.dart
class ApiTrace {
  /// Master switch. When false, [call] is a no-op and the overlay
  /// never renders. Defaults to kDebugMode at first read.
  static bool enabled;

  /// Global default config. Read on first [call] after [init].
  static ApiTraceConfig config;

  /// Capture one API call. Returns the recorded record id (or null if
  /// disabled), so call sites can correlate logs.
  ///
  /// `extra` carries fields the call site already has in scope (e.g.
  /// `tags: ['auth']`, `userId`). The function itself only knows about
  /// method, url, status, duration, request, and response.
  static Future<String?> call(
    String name, {
    required String method,
    required Uri url,
    required Future<ApiTraceResponse> Function() execute,
    Set<ApiTraceDetail>? detailOverride, // per-call override > global
    Map<String, Object?>? extra,
  });

  /// Open the timeline overlay programmatically. The FAB already does
  /// this; the explicit API is here for tests and custom triggers.
  static void showOverlay(BuildContext context);
}

class ApiTraceResponse {
  final int statusCode;
  final Duration duration;
  final Map<String, String> requestHeaders;
  final Map<String, String> responseHeaders;
  final Object? requestBody; // JSON, form summary, or null
  final Object? responseBody; // parsed, truncated to config.maxResponseBodyBytes
  final Object? error; // thrown exception, if any
}

// lib/src/model.dart
class ApiTraceRecord {
  final String id;            // uuid v4
  final String name;         // developer-supplied label
  final DateTime startedAt;
  final DateTime completedAt;
  final String method;
  final Uri url;
  final int? statusCode;
  final Duration duration;
  final ApiTraceOutcome outcome; // success | error | cancelled
  final Set<ApiTraceDetail> capturedDetails;
  final ApiTraceRequest? request;   // null if !request in captured
  final ApiTraceResponse? response; // null if !response in captured
  final Object? error;
  final Map<String, Object?> extra;
}
```

The **overlay widget** is a single `Widget` (`ApiTraceOverlay`) that the
package's own bootstrap mounts at the top of the `WidgetsApp` overlay
stack when `enabled && kDebugMode`. Users do not need to mount it
themselves; the FAB appears automatically. `ApiTraceScaffold` is a
documented escape hatch for app teams that want to control the overlay
host — but it is not part of the v1 contract.

## Data model (timeline)

The timeline is an in-memory ring buffer keyed by start time, descending
when rendered (newest first), with the following rules:

- Capacity is `ApiTraceConfig.timelineCapacity` (default 200). When full,
  the oldest record is evicted silently.
- Each record stores the **fields captured for that specific call**
  (derived from the merged global + per-call detail set), not the
  global default. This keeps memory bounded regardless of global config.
- The overlay exposes: list view (name, method, status, duration, age),
  filter chips (success / error / by name substring), and tap-to-detail.
- Detail screen is read-only: shows every captured field plus the raw
  bytes for the response if `ApiTraceDetail.full` was active.

## Success metrics

The MVP is done when the metrics below are met, in this order of
priority:

1. **Time-to-first-trace ≤ 2 minutes.** From `flutter pub add
   flutter_api_inspector` to a working `ApiTrace.call(...)` round-trip
   showing up in the overlay. Measured by the `example/` app smoke test.
2. **Install size delta ≤ 30 KB** (uncompressed Dart sources, excluding
   `flutter` itself). Measured by `flutter pub get` + `du -sh` of the
   `lib/` tree, recorded in `verify-report.md`.
3. **Zero release-build impact.** `flutter build --release` (Android
   APK) and `flutter build ios --release` (no-codesign) show no overlay
   widget in the widget tree, no `ApiTraceOverlay` string in the
   symbol table, and a binary size delta within noise (≤ 5 KB) versus
   a build with the package removed. Verified by a release-build smoke
   test in `apply-progress.md`.
4. **Strict TDD evidence.** Every shipped behavior has RED → GREEN →
   TRIANGULATE → REFACTOR evidence recorded in `apply-progress.md`
   (per `openspec/AGENTS.md` rule 4 and `openspec/config.yaml` →
   `strict_tdd: true`).
5. **Privacy-conscious default holds.** A trace recorded with the
   default `ApiTraceConfig` contains **no** request body, **no**
   response body, and **no** request/response headers. Verified by a
   contract test in `test/`.

## Non-goals (explicit, to prevent scope drift)

- **No auto-interceptor.** No Dio shim, no `http.Client` wrap, no
  platform-channel proxy. Manual instrumentation only.
- **No disk persistence in v1.** No shared_preferences, no SQLite, no
  file export, no copy-to-clipboard. The timeline is in-memory.
- **No cURL export, no re-run, no replay.** Tap on a call → read detail.
  Nothing else.
- **No network mocking or sandboxing.** This package inspects calls; it
  does not intercept, rewrite, or block them.
- **No multi-window / multi-tab support.** The overlay is a single
  per-app FAB. Web multi-tab is not in v1.
- **No web platform support in v1.** Mobile (iOS, Android), desktop
  (macOS, Windows, Linux). Flutter web is a possible follow-up change
  once the mobile/desktop MVP is published.
- **No in-overlay search beyond substring name filter.** No regex, no
  field-specific query language.
- **No telemetry, no analytics, no auto-upload.** The package is
  inspection-only and never phones home.

## Open questions (need user input before sdd-spec)

These are the only product decisions still unresolved. sdd-spec will
**stop and ask** if these remain open at the start of the phase.

1. **`ApiTrace.call` signature: sync or async?** The current sketch is
   `Future<String?> Function({...})` with an `execute` callback. The
   alternative is a sync `String? call(name, ...)` that the developer
   calls before and after the actual request, with a `finish(id, ...)`
   call. The async version is harder to misuse; the sync version is
   simpler and works with non-Future HTTP clients. **Recommendation:
   async with `execute` callback**, but the user should confirm.
2. **In-memory ring buffer default size.** The sketch uses 200. Is
   that the right default for a mobile debug session, or should it be
   smaller (50) / larger (500)? Recommendation: 200, configurable.
3. **FAB position and label.** Bottom-right vs bottom-left vs
   top-right; whether to show a count badge on the FAB; whether the
   FAB has a label (e.g. "API 17") or is icon-only. Recommendation:
   bottom-right, count badge when > 0 records, icon-only by default.
4. **Error highlighting in the timeline.** Should errored calls (thrown
   exceptions, 4xx, 5xx) get a color cue in the list view? If so, is
   that configurable, or is it the only state distinction? Recommendation:
   error / success are visually distinct; 4xx vs 5xx are not.
5. **Response body capture size limit.** The sketch uses 4 KB. Is that
   the right default for a debug tool? Too small and JSON inspection
   is painful; too large and a single large response blows the ring
   buffer's memory. Recommendation: 4 KB default, configurable.
6. **`ApiTrace.enabled` default at first read.** Should it default to
   `kDebugMode` (auto-on in debug, auto-off in release) or to `true`
   (developer must explicitly set `false`)? Recommendation:
   `kDebugMode` at first read, mutable afterward.
7. **Example app scope.** Should the MVP ship a `example/` app that
   exercises `ApiTrace.call` against a real endpoint (a public test
   API) or a stub? Recommendation: stub for offline reliability +
   one real call to a public test API (httpbin or equivalent) for
   smoke testing.
8. **License.** The repo does not yet have a `LICENSE` file. MIT vs
   BSD-3-Clause vs Apache-2.0. Recommendation: MIT (matches the
   Flutter team's preference and pub.dev convention for small utility
   packages), but the user should confirm.

## Acceptance criteria (what "done" means for the MVP)

The MVP is accepted when **all** of the following are true:

- [ ] `pubspec.yaml`, `lib/`, `test/`, `example/`, `README.md`,
  `CHANGELOG.md`, and `LICENSE` exist per the official pub.dev
  package layout (`openspec/AGENTS.md` rule 10).
- [ ] `flutter pub get` succeeds against the local path from
  `example/`.
- [ ] `flutter test` passes with 100% of the test files exercising
  real behavior (not smoke-only).
- [ ] `dart analyze` is clean (no warnings, no errors).
- [ ] `dart format --set-exit-if-changed .` is a no-op.
- [ ] A debug build of `example/` shows the FAB, captures a call
  recorded via `ApiTrace.call`, and renders the call in the timeline
  with all default fields.
- [ ] A release build of `example/` (`flutter build --release`) does
  **not** show the FAB, does **not** include `ApiTraceOverlay` in the
  widget tree, and the binary size delta vs. an untraced release
  build is ≤ 5 KB.
- [ ] `ApiTraceConfig(details: {ApiTraceDetail.minimal})` produces
  traces with no body and no headers — verified by a contract test.
- [ ] Per-call `detailOverride` widens the captured detail set for
  that one call only, leaving other calls on the global config —
  verified by a contract test.
- [ ] The ring buffer evicts the oldest record when capacity is
  reached — verified by a unit test.
- [ ] `ApiTrace.enabled = false` short-circuits `ApiTrace.call` to a
  no-op that returns `null` immediately — verified by a unit test.
- [ ] `apply-progress.md` contains RED / GREEN / TRIANGULATE /
  REFACTOR evidence for every shipped behavior (per strict TDD).
- [ ] `verify-report.md` is green with no CRITICAL or BLOCKED items.
- [ ] `pubspec.yaml` declares `flutter: ">=3.16.0"`, `dart: ">=3.2.0"`,
  Android `minSdkVersion 21`, iOS `deployment_target 12.0` (per
  `openspec/config.yaml` → `stack.minimum_runtime`).
- [ ] No new dependencies beyond `flutter` and `flutter_test`. No
  `package:dio`, no `package:http`, no `package:uuid` (use
  `Random.secure()` or a small inline generator).
- [ ] No `print`, no `developer.log`, no global state mutation
  outside of `ApiTrace.enabled` and `ApiTrace.config`.

## Affected areas

- `pubspec.yaml` (new) — created by `sdd-tasks` / `sdd-apply`, not by
  this proposal.
- `lib/` (new) — package source, owned by `sdd-apply`.
- `test/` (new) — strict TDD test files, owned by `sdd-apply`.
- `example/` (new) — minimal example app for pub.dev and for the
  debug-build / release-build smoke tests.
- `README.md`, `CHANGELOG.md`, `LICENSE` (new) — pub.dev surface,
  owned by `sdd-apply`.
- `openspec/specs/` — delta specs for instrumentation API, overlay
  UI, and timeline model. Owned by `sdd-spec`.
- `openspec/changes/flutter_api_inspector-mvp/{specs,design,tasks,apply-progress,verify-report,sync-report,archive-report}.md`
  — owned by the corresponding SDD phases.

## Rollback

The MVP is greenfield, so "rollback" means **do not publish**. If any
verify gate fails:

1. `sdd-apply` stops before marking any task complete.
2. `sdd-verify` records the failure in `verify-report.md` and blocks
   `sdd-archive`.
3. The change stays in `openspec/changes/flutter_api_inspector-mvp/`
   for revision; no commit is pushed to a remote (per
   `openspec/AGENTS.md` rule 5).
4. The example app, `lib/`, and `test/` are not deleted during a
   failed MVP — they remain as in-progress work. A follow-up change
   can pick them up.

There is no production blast radius because nothing ships to pub.dev
until `sdd-archive` runs (and the user manually triggers
`flutter pub publish` afterward — the agent never does this).

## Proposal question round (transparency)

The user-facing product decisions above (configurable detail, in-memory
persistence, auto-shown FAB, visualization-only actions) were captured
in the task prompt before this proposal was written. They constitute
the answered proposal question round for this change. The eight
**Open questions** in this document are the remaining gaps that
sdd-spec must resolve, in collaboration with the user, before
freezing the spec.

## Result Contract

```yaml
status: complete
executive_summary: >-
  Proposal for the flutter_api_inspector MVP locked. Manual instrumentation
  API + debug-only overlay + chronological timeline with configurable
  per-call and global detail capture, in-memory only, visualization-only
  actions. Eight open product questions flagged for sdd-spec to resolve
  with the user. No code, pubspec.yaml, or example/ created in this
  phase.
artifacts:
  - openspec/changes/flutter_api_inspector-mvp/proposal.md
next_recommended: sdd-spec # after user review and answers to the 8 open questions
risks:
  - "Open questions 1–8 must be resolved with the user before sdd-spec can lock the contracts; spec phase will stop and ask if any remain open."
  - "sdd-proposal in interactive mode normally pauses for a user proposal question round; this round was already answered inline in the task prompt. The 8 open questions above are the only remaining gaps."
  - "No pubspec.yaml exists yet, so flutter test / flutter build --release cannot be exercised until sdd-tasks / sdd-apply. Success metrics 1–3 must be re-validated at sdd-verify."
  - "A release-build smoke test (flutter build --release with binary size delta) is required by AGENTS.md rule 6; this is non-trivial on Windows without an Android SDK / Xcode toolchain and may need to be deferred to sdd-apply / sdd-verify on a host with the right SDKs."
  - "License choice (MIT vs BSD-3-Clause vs Apache-2.0) is still undecided and blocks the LICENSE file creation in sdd-apply."
skill_resolution: paths-injected # sdd-proposal agent file was loaded from C:/Users/Maxim/.pi/agent/npm/node_modules/gentle-pi/assets/agents/sdd-proposal.md
```
