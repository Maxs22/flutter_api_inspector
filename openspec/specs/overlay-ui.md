# Overlay UI Specification

## Purpose

The `flutter_api_inspector` overlay is a debug-only in-app surface
that exposes the API call timeline to the developer. It is a
single `ApiTraceOverlay` widget that mounts itself in the
`WidgetsApp` overlay stack when `ApiTrace.enabled` is true AND
`kDebugMode` is true (per `openspec/AGENTS.md` rule 6). The
overlay consists of a floating action button (FAB) at a
configurable position with a configurable label shape, a panel
that lists the timeline in newest-first order with filter chips,
and a read-only detail screen that opens on tap. The overlay MUST
tree-shake out of `flutter build --release` binaries so it has
zero presence in release widget trees and zero `ApiTraceOverlay`
references in the release symbol table. All testable behavior in
this file is verifiable with `flutter test` widget tests against
`package:flutter_test`.

## Requirements

### Requirement: REQ-UI-001 — kDebugMode guard placement

The `ApiTraceOverlay` widget MUST only mount or render inside a
build guarded by `kDebugMode` from
`package:flutter/foundation.dart`. A release build
(`flutter build --release`) MUST NOT instantiate the widget or
import the overlay module into the final binary's tree-shaking
output (per `openspec/AGENTS.md` rule 6).

**TDD contract**: `flutter test` MUST record a RED → GREEN →
TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the
test(s) satisfying this requirement. The release-build smoke
test (binary size delta, symbol-table absence, no
`ApiTraceOverlay` in the widget tree) is captured separately in
`apply-progress.md` and `verify-report.md`, not in `flutter test`.

#### Scenario: Overlay widget absent under kReleaseMode

- GIVEN `kReleaseMode` is `true` (i.e. `kDebugMode` is `false`)
  for the test run
- WHEN the test pumps a `MaterialApp` with the package bootstrap
- THEN no `ApiTraceOverlay` widget is found in the widget tree
- AND no floating action button from the package is found

### Requirement: REQ-UI-002 — Overlay auto-mount in WidgetsApp overlay

The `ApiTraceOverlay` widget MUST mount automatically as part of
the package bootstrap; consumers MUST NOT need to wrap their app
in any scaffold or insert the widget manually. The widget MUST
live in the `WidgetsApp` overlay stack so it floats above the
developer's own UI.

**TDD contract**: `flutter test` MUST record a RED → GREEN →
TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the
test(s) satisfying this requirement.

#### Scenario: Overlay present under kDebugMode

- GIVEN `kDebugMode` is `true` and `ApiTrace.enabled` is `true`
- WHEN the test pumps a `MaterialApp` with the package bootstrap
- THEN exactly one `ApiTraceOverlay` widget is found in the tree
- AND the widget is mounted in an `Overlay` above the
  developer's `Scaffold` body

#### Scenario: Overlay absent when ApiTrace.enabled is false

- GIVEN `kDebugMode` is `true` and `ApiTrace.enabled` is `false`
- WHEN the test pumps a `MaterialApp` with the package bootstrap
- THEN no `ApiTraceOverlay` widget is found in the tree
- AND no FAB from the package is found

### Requirement: REQ-UI-003 — Configurable FAB position

The floating action button MUST render at the position configured
by `ApiTrace.config.overlayPosition`. The four allowed values
are `bottomRight` (default), `bottomLeft`, `topRight`, and
`topLeft` (locked answer to open question #3).

**TDD contract**: `flutter test` MUST record a RED → GREEN →
TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the
test(s) satisfying this requirement.

#### Scenario: FAB at bottomRight by default

- GIVEN `ApiTrace.config.overlayPosition == bottomRight` (the
  default)
- WHEN the test pumps a `MaterialApp` with the package bootstrap
- THEN the FAB's alignment within the overlay is
  `Alignment.bottomRight`

#### Scenario: FAB at topLeft after config change

- GIVEN `ApiTrace.config.overlayPosition` is set to `topLeft`
- WHEN the test pumps a `MaterialApp` with the package bootstrap
- THEN the FAB's alignment within the overlay is
  `Alignment.topLeft`

### Requirement: REQ-UI-004 — Configurable FAB label shape

The floating action button MUST render with the label shape
configured by `ApiTrace.config.overlayLabel`. The three allowed
values are `icon` (icon-only, default), `badge` (icon plus a
numeric badge of the current record count, hidden when count is
zero), and `chip` (icon plus a short text label of the current
record count, hidden when count is zero) — locked answer to open
question #3.

**TDD contract**: `flutter test` MUST record a RED → GREEN →
TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the
test(s) satisfying this requirement.

#### Scenario: Icon-only FAB by default

- GIVEN `ApiTrace.config.overlayLabel == icon` (the default) and
  the timeline has at least one record
- WHEN the test pumps a `MaterialApp` with the package bootstrap
- THEN the FAB subtree contains the FAB icon
- AND no `Text` widget rendering the record count is found
  inside the FAB subtree

#### Scenario: Badge FAB shows count when > 0

- GIVEN `ApiTrace.config.overlayLabel == badge` and the timeline
  has 7 records
- WHEN the test pumps a `MaterialApp` with the package bootstrap
- THEN a `Text` widget rendering the literal string "7" is found
  inside the FAB subtree

#### Scenario: Badge FAB hides count when count is 0

- GIVEN `ApiTrace.config.overlayLabel == badge` and the timeline
  is empty
- WHEN the test pumps a `MaterialApp` with the package bootstrap
- THEN no count `Text` widget is found inside the FAB subtree

### Requirement: REQ-UI-005 — Panel renders chronological timeline

Tapping the FAB MUST open a panel that lists every record in the
timeline, ordered newest-first (descending by `startedAt`). Each
row MUST show at least: the developer-supplied `name`, the HTTP
`method`, the `statusCode` (or a placeholder when null), and the
`duration`.

**TDD contract**: `flutter test` MUST record a RED → GREEN →
TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the
test(s) satisfying this requirement.

#### Scenario: Newest-first ordering

- GIVEN three recorded calls in the order A, B, C
- WHEN the developer taps the FAB and the panel opens
- THEN the list shows them in the order C, B, A
- AND each row's text contains the row's `name`, `method`,
  `statusCode`, and `duration`

#### Scenario: Empty timeline shows empty state

- GIVEN the timeline is empty
- WHEN the developer taps the FAB and the panel opens
- THEN a friendly empty-state message is shown
- AND no list rows are rendered

### Requirement: REQ-UI-006 — Filter chips narrow the timeline view

The panel MUST expose filter chips for at least: success-only,
error-only, and a free-text name substring filter. Activating a
filter chip MUST narrow the rendered list to the matching subset
without mutating the underlying timeline.

**TDD contract**: `flutter test` MUST record a RED → GREEN →
TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the
test(s) satisfying this requirement.

#### Scenario: Error-only filter

- GIVEN a timeline with one success record and one error record
- WHEN the developer activates the "errors only" filter chip
- THEN the rendered list contains exactly one row
- AND that row is the error record

#### Scenario: Name substring filter

- GIVEN a timeline with records named `getUser` and `listOrders`
- WHEN the developer types `get` into the name filter field and
  the filter is applied
- THEN the rendered list contains exactly one row
- AND that row is the `getUser` record

#### Scenario: Underlying timeline is not mutated by filters

- GIVEN a timeline with two records and the "errors only" filter
  is active
- WHEN the developer deactivates the filter
- THEN the rendered list returns to the full two rows
- AND the timeline size is still 2

### Requirement: REQ-UI-007 — Tap-to-detail opens read-only screen

Tapping a row in the panel MUST open a read-only detail screen
that shows every captured field for that record. The detail
screen MUST NOT expose any "copy as cURL", "re-run", or "export"
action in v1 (visualization only, per the locked product
decision).

**TDD contract**: `flutter test` MUST record a RED → GREEN →
TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the
test(s) satisfying this requirement.

#### Scenario: Detail screen shows captured fields

- GIVEN a timeline with one record captured at `headers` and
  `response` detail levels
- WHEN the developer taps that record's row
- THEN the detail screen shows the record's `name`, `method`,
  `url`, `statusCode`, `duration`, request headers, and
  response body
- AND no button labelled "Copy as cURL" is found
- AND no button labelled "Re-run" is found
- AND no button labelled "Export" is found

### Requirement: REQ-UI-008 — Error calls render red, success green

Records with `outcome == ApiTraceOutcome.error` MUST render in
red, and records with `outcome == ApiTraceOutcome.success` MUST
render in green, in both the list view and the detail view. The
green/red distinction MUST NOT differentiate 4xx from 5xx (per
the locked answer to open question #4).

**TDD contract**: `flutter test` MUST record a RED → GREEN →
TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the
test(s) satisfying this requirement.

#### Scenario: Success row is green

- GIVEN a record with `outcome == ApiTraceOutcome.success`
- WHEN the developer views the timeline list
- THEN that row's text color resolves to a green hue
- AND the row's status `Icon` (if any) is tinted green

#### Scenario: Error row is red

- GIVEN a record with `outcome == ApiTraceOutcome.error`
- WHEN the developer views the timeline list
- THEN that row's text color resolves to a red hue
- AND the row's status `Icon` (if any) is tinted red

#### Scenario: 4xx and 5xx share the same red color

- GIVEN two records, one with `statusCode = 404` and one with
  `statusCode = 503`
- WHEN the developer views the timeline list
- THEN both rows have the same red color
- AND there is no visual difference between 4xx and 5xx rows
  beyond the text content

## Out of scope

- Re-running a captured call.
- Copying a captured call as a cURL string.
- Exporting the timeline to a file or to the clipboard.
- Regex or field-specific search.
- Web platform support (per the proposal's non-goals).
- A `ApiTraceScaffold` escape-hatch widget.
- A user-customizable theme for the overlay colors.
- Animations beyond the default Material motion.
- A golden test for pixel-exact FAB position (alignment is asserted
  in tests; pixel snapshots are out of scope for v1).
