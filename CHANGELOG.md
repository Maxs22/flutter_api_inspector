# Changelog

All notable changes to `flutter_api_inspector` are documented in this
file. The format follows [Keep a Changelog](https://keepachangelog.com/)
and the project adheres to [Semantic Versioning](https://semver.org/).

## Unreleased

### Fixed

- **Nonmodal inspector**: outside touches reach the app without closing the
  panel; close with X/FAB. Active and queued host SnackBars are preserved,
  superseding the 0.3.4 notification-clearing behavior.

### Changed

- **Breathing Room inspector**: roomier request and route cards, rounded
  touch controls, calmer detail sections, and readable semantic badges in
  light and dark host themes. Capture, configuration, and navigation are unchanged.

## 0.3.4 — 2026-08-06

### Fixed

- **Inspector modal isolation**: opening the overlay now clears any active
  host-app `SnackBar` so app notifications do not visually overlap the
  inspector panel.
- **Demo evidence**: regenerated the demo GIF/screenshots after the
  SnackBar overlap fix.

## 0.3.3 — 2026-08-06

### Changed

- **Overlay visual refresh**: modernized the inspector with a single
  rounded floating surface, softer shadows, pill tabs, compact timeline
  controls, and cleaner route/endpoint cards that avoid visible nested
  background layers.
- **Demo evidence**: refreshed the recorded demo GIF and added current
  Timeline, Routes, and Endpoint panel screenshots from the real example
  Android app.

## 0.3.2 — 2026-08-04

### Added

- **Demo GIF**: added a real `assets/demo.gif` recorded from the example
  app, showing Home/Detail calls, the FAB, Timeline, Routes, and the route
  endpoint panel.

### Fixed

- **pub.dev docs**: updated README examples and limitations to match
  version `0.3.2`, the current `panelMinHeight` default, route endpoint
  drill-down behavior, and the debug-only status of route tooling in
  force-enabled QA builds.
- **Example route scopes**: pass the example `MaterialApp` directly to
  `ApiTrace.runApp` so the Routes tab displays named `/home` and `/detail`
  groups in the visual demo.

## 0.3.1 — 2026-07-14

### Fixed

- **README**: the 0.3.0 README shipped without documenting the
  Route-Scoped Network Inspector feature at all, still pointed the
  Quickstart snippet at `^0.2.0`, and had a markdown indentation bug
  that made the entire "Release-mode testing" section render as raw
  text/code on pub.dev instead of a proper section. Added a full
  "Route-Scoped Network Inspector" section (Routes tab, `RouteScope`,
  `MaterialApp.router` wiring, manual-instrumentation tagging pattern),
  bumped the Quickstart version, fixed the indentation, and corrected
  the "no cURL export" limitation bullet (per-route export exists).

## 0.3.0 — 2026-07-14

### Added

- **Route-Scoped Network Inspector**: network calls are now grouped by
  the screen that triggered them. QA sees "CheckoutScreen → POST /orders
  (500) → GET /payment-methods (timeout)" instead of a flat timeline.

### Fixed

- **pub.dev score**: package description shortened to 166 chars (was
  187, over the 180-char limit). Score back to 160/160.

### Changed

- README now includes a demo GIF placeholder showing the FAB → Timeline
  → Detail flow.

## 0.2.1 — 2026-07-06

- Fix pub.dev score: shorten package description to ~100 characters
  (was too long for pub.dev's 180-char limit).

## 0.2.0 — 2026-07-06

### Added

- `ApiTrace.forceEnabled` flag: when set to `true` before
  `ApiTrace.runApp()`, the overlay works even in release builds.
  Useful for QA tester builds, custom flavors, or feature-flag-gated
  development modules. The three `kDebugMode` guards (`runApp`,
  `ApiTraceBootstrap`, `ApiTraceOverlay`) now use
  `!kDebugMode && !forceEnabled` so the harness and overlay are
  constructed when either debug mode or force-enabled is active.
- The overlay now adopts the HOST app's colors: every surface token
  derives from the app's `ColorScheme` (Material 3 tonal surface
  roles), so the panel carries the app's primary tint instead of a
  fixed grey palette.
- Contrast guarantee: accent, success/error, and HTTP-method colors
  pass through `inspectorEnsureContrast`, which nudges any
  low-contrast color toward black/white until it reaches WCAG 3.0
  against the panel background — a pastel primary stays readable.
- FAB polish: the icon is now the same bolt as the panel header,
  colors come from the scheme's `primaryContainer` /
  `onPrimaryContainer` pair, and a small error-colored dot appears
  when the timeline holds failed calls.
- Panel close affordances: tapping outside the panel (scrim) or the
  new X button in the header closes it.
- Single-import barrel: `flutter_api_inspector.dart` now exports
  `TracedDioInterceptor` and `TracedHttpOverrides` /
  `TracedHttpClient` too, so one import covers the whole package.
  The sub-path imports remain available. (The package targets
  mobile / desktop — web already has the browser Network tab.)

### Fixed

- `BootstrapMaterialAppHarness` always forces `debugShowCheckedModeBanner:
  false` so the debug-only overlay never adds an extra banner on top of
  the developer's own banner setting.
- `ApiTrace.runApp` crashed real apps on startup with "The render
  object for Semantics cannot find ancestor render object to attach
  to" + "No MediaQuery widget ancestor found": it called
  `attachRootWidget` without `binding.wrapWithDefaultView`, so no
  root `View` / `RenderView` was ever created (Flutter's own
  `runApp` has wrapped with the default View since 3.10). Both the
  debug and release paths now wrap correctly.
- `BootstrapMaterialAppHarness` now forwards EVERY `MaterialApp`
  constructor property (`routes`, `onGenerateRoute`, `initialRoute`,
  `onUnknownRoute`, localization, `scrollBehavior`, `shortcuts` /
  `actions`, debug flags, …) instead of a small subset, composes the
  developer's own `builder` with the overlay, and supports
  router-based apps (`MaterialApp.router`). Activating the overlay no
  longer breaks routes-based navigation or localization.
- Request bodies are now actually captured. `TracedHttpOverrides`
  buffers request bytes as they are written (capped at
  `maxResponseBodyBytes`) and `TracedDioInterceptor` snapshots
  `options.data` / `options.headers` at request time. `ApiTrace.call`
  lifts the request payload into `record.request` so the detail
  screen renders it (previously `record.request` was always null).
- Installing `TracedHttpOverrides` and `TracedDioInterceptor`
  together no longer records every Dio call twice: the Dio
  interceptor defers to the overrides layer automatically (opt out
  with `TracedDioInterceptor(deferToHttpOverrides: false)` for
  custom adapters that bypass `dart:io`).
- The timeline panel header badge now shows the FILTERED record
  count instead of the timeline total when an outcome filter or a
  name query is active.
- Doc comments in `detail.dart`, `config.dart`, and the example
  claimed the default detail set was `{minimal}`; the actual default
  is `{minimal, response}` (aligned with the README).

### Changed

- `Timeline` is now a true circular buffer: `append` is O(1) with no
  element shifting (was `List.insert(0, …)`, O(n) per append).
  `Timeline.records` remains an unmodifiable, newest-first `List`.
- Minimum Flutter bumped to 3.27 / Dart 3.6: the code already used
  `Color.withValues` (3.27+) and the theme now uses the
  `surfaceContainer*` scheme roles (3.22+); the previous `>=3.16`
  constraint was never accurate.

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
