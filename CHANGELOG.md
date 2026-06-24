# Changelog

All notable changes to `flutter_api_inspector` are documented in this
file. The format follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

## 0.1.0 — 2026-06-23

### Added

- Initial MVP release of `flutter_api_inspector`.
- `ApiTrace.call(name, method, url, execute, detailOverride, extra)` —
  manual API capture with a privacy-conscious default
  (`{ApiTraceDetail.minimal}` only).
- `ApiTrace.enabled` master switch (defaults to `kDebugMode` at first
  read; mutable thereafter).
- `ApiTrace.config` global configuration with `details`,
  `maxResponseBodyBytes` (4 KB default), `timelineCapacity` (200
  default), `overlayPosition` (4 values), and `overlayLabel` (3 values).
- `ApiTrace.timeline` — in-memory ring buffer with newest-first
  ordering and silent eviction at capacity.
- `ApiTrace.runApp(Widget app)` — one-line bootstrap that mounts the
  overlay in debug mode and passes through to `runApp` in release.
- `ApiTrace.showOverlay` / `ApiTrace.hideOverlay` — programmatic
  overlay control.
- `ApiTraceOverlay` widget with a configurable floating action button
  (position and label shape) and a panel that lists the timeline in
  chronological order with filter chips (success-only, error-only,
  name substring).
- `ApiTraceDetailScreen` — read-only detail view (no cURL export, no
  re-run, no export).
- `kDebugMode` guard at four call sites so the overlay is tree-shaken
  from `flutter build --release` binaries.
- Zero new third-party dependencies (only `flutter` and `flutter_test`).
- Strict TDD: every behavior-shipping change has RED → GREEN →
  TRIANGULATE → REFACTOR evidence recorded in
  `openspec/changes/flutter_api_inspector-mvp/apply-progress.md`.

### Non-goals (explicit, in scope of v1 exclusion)

- No auto-interceptor (no `http.Client` wrap, no Dio shim).
- No disk persistence (no `shared_preferences`, no SQLite, no file
  export).
- No cURL export, no re-run, no replay.
- No network mocking, rewriting, or blocking.
- No multi-window / multi-tab support.
- No Flutter web support in v1.
- No regex / field-query search.
- No telemetry, no analytics, no auto-upload.
