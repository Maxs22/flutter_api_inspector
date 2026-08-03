# Delta for Route-Scoped Network Inspector

## ADDED Requirements

### Requirement: REQ-RS-009 — Route endpoint detail panel

The overlay MUST provide a dedicated panel that lists every API endpoint (HTTP call) recorded under a specific route scope. Access to the panel MUST be through a secondary list-icon action (`Icons.list_alt_rounded`) on each route tile in the Routes tab.

The route tile MUST support dual-action interaction:

- **Tap** (unchanged) — filters the Timeline tab to show only records for that route's `routeScopeId`.
- **Tap the list icon** — pushes a `MaterialPageRoute` to the endpoint detail panel for that route scope.

The panel MUST display the following columns for each endpoint:

| Column | Source |
|--------|--------|
| Name | `record.name` — developer-supplied label |
| Method | `record.method` — GET, POST, PUT, DELETE, etc. |
| Status | `record.statusCode` — colour-coded via existing `outcomeColor()` utility |
| Duration | `record.duration` — formatted, e.g. `230ms` |

Tapping a row in the panel MUST navigate to the existing `ApiTraceDetailScreen` for that record (consistent with the Timeline tab behaviour).

The panel MUST show a static snapshot of the endpoint data at open time (no real-time streaming or auto-refresh in v1). Records MUST be filtered by exact `routeScopeId` match only — no child-route aggregation.

**TDD contract**: `flutter test` MUST record a RED → GREEN → TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the test(s) satisfying this requirement.

#### Scenario: List icon opens endpoint panel

- GIVEN the Routes tab is visible with at least one route entry that has recorded API calls
- WHEN the developer taps the list icon (`Icons.list_alt_rounded`) on that route tile
- THEN a `MaterialPageRoute` is pushed
- AND the pushed route is a `RouteEndpointPanel` widget
- AND the panel's records are filtered to `routeScopeId == selectedEntry.scopeId`

#### Scenario: Panel shows Name, Method, Status, Duration columns

- GIVEN a route scope with 3 recorded API calls
- WHEN the developer opens the endpoint panel for that route
- THEN each row shows the record's `name`, `method`, `statusCode`, and `duration`
- AND the status code is colour-coded via the existing `outcomeColor()` utility

#### Scenario: Status column uses same colours as Timeline

- GIVEN a route scope with one success call (200) and one error call (500)
- WHEN the developer opens the endpoint panel
- THEN the success row has green-tinted status text
- AND the error row has red-tinted status text
- AND `outcomeColor()` returns the same colour for matching outcomes in both Timeline and panel

#### Scenario: Tapping a panel row opens detail screen

- GIVEN the endpoint panel is open showing a list of records
- WHEN the developer taps a row
- THEN the existing `ApiTraceDetailScreen` for that record is pushed
- AND the detail screen shows the record's `name`, `method`, `url`, `statusCode`, duration, and response body

#### Scenario: Static snapshot at open time

- GIVEN the endpoint panel is open showing 3 records
- WHEN a new API call is recorded under the same route scope while the panel is open
- THEN the panel still shows exactly the original 3 records
- AND the developer must close and re-open the panel to see the new record

### Requirement: REQ-RS-010 — Route endpoint panel empty state

When a route scope has zero recorded API calls, the endpoint panel MUST display an empty state with:

- A neutral icon (e.g. `Icons.info_outline`)
- A friendly message indicating no endpoints were recorded for that route
- The route name as a subtitle

**TDD contract**: `flutter test` MUST record a RED → GREEN → TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the test(s) satisfying this requirement.

#### Scenario: Friendly empty state for route with no calls

- GIVEN a route scope with zero recorded API calls
- WHEN the developer opens the endpoint panel for that route
- THEN an empty state widget is rendered
- AND the empty state includes a neutral icon
- AND the empty state includes a text message indicating no endpoints were recorded
- AND the route name appears in the panel (e.g. in the title or subtitle)

### Requirement: REQ-RS-011 — Route tile list-icon affordance

Each route tile in the Routes tab MUST render a trailing list icon (`Icons.list_alt_rounded`) with a visible tooltip (e.g. "View endpoints") to indicate its purpose. The icon MUST be horizontally aligned within the tile and MUST NOT overlap with the existing call/error count badges or the route name text.

**TDD contract**: `flutter test` MUST record a RED → GREEN → TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the test(s) satisfying this requirement.

#### Scenario: List icon visible on route tile

- GIVEN the Routes tab is visible with at least one route entry
- WHEN the test inspects the route tile widget tree
- THEN a widget with `Icons.list_alt_rounded` is found
- AND the icon has a `Tooltip` with text "View endpoints"

#### Scenario: List icon is absent when route has no scopeId (defensive)

- GIVEN the Routes tab shows a route entry with a null scopeId
- WHEN the test inspects that tile's widget tree
- THEN no `Icons.list_alt_rounded` icon is rendered
- OR the icon is present but the panel shows the empty state
