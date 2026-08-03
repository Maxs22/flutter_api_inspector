# Exploration: Route Endpoint Detail Panel

**Change**: `route-endpoint-detail-panel`
**Date**: 2026-07-15
**Phase**: sdd-explore

---

## 1. Domain Summary

### What Exists

- `RouteScope` / `RouteScopeObserver` — Navigator observer that tracks route
  transitions, assigns each route a unique `scopeId`, and tags every
  `ApiTraceRecord` with the active `routeScopeId` at dispatch time.
- **Routes tab** — Tree view of navigation routes with aggregate counters
  (total calls, errors per route). Tapping a route filters the Timeline.
- `ApiTraceRecord.extra['routeScopeId']` — the link between a record and its
  route scope, accessible via `ApiTraceRecordScope.routeScopeId` extension.

### What Is Desired

When the user taps a route in the Routes tab, a **detail panel** should
display the **complete list of endpoints** invoked within that route scope:

- HTTP method (GET, POST, …)
- Status code (200, 404, …)
- Duration (formatted)
- Endpoint name / label

This is **not** the aggregate counter — it is the full list of individual
`ApiTraceRecord`s scoped to that route.

---

## 2. Actors

| Actor | Role |
|-------|------|
| `RouteScopeObserver` | Captures route transitions, assigns `scopeId`, maintains route tree |
| `ApiTrace` / `ApiTraceTimeline` | Collects every HTTP trace; each record carries `routeScopeId` |
| `RouteTreeTab` / `_RouteTreeRow` | Renders the route hierarchy with call/error counters |
| `_PackageNavigator` | Hosts tabs (Timeline + Routes), pushes detail screen |
| **NEW: RouteEndpointPanel** | Detail panel to show per-route endpoint list |

---

## 3. Key Files

| File | Change | Reason |
|------|--------|--------|
| `lib/src/overlay/route_tree_tab.dart` | **Modify** | Add secondary action to open detail panel |
| `lib/src/overlay/route_endpoint_panel.dart` | **Create** | New widget: endpoint list per route scope |
| `lib/src/overlay/api_trace_overlay.dart` | **Modify** | Wire the new panel into `_PackageNavigator` |
| `lib/src/model/api_trace_record.dart` | **Inspect** — no change needed | Records already carry `routeScopeId` via extra map |

Files that do **not** need changes:

- `route_scope.dart` — no new accessors needed; filtering is done through
  the existing records list and the `routeScopeId` key
- `route_scope_observer.dart` — no changes to tracking logic
- `api_trace.dart` / `config.dart` — no API surface changes needed

---

## 4. Integration Points

### 4.1 Querying Records by `routeScopeId`

The detail panel needs filtered records. **Option A (recommended):**
filter the existing `records` list by `routeScopeId`:

```dart
final records = widget.records
    .where((r) => r.routeScopeId == selectedScopeId)
    .toList();
```

This is a simple O(n) scan — acceptable for typical <1000 records.
The records list is already available from the parent `_PackageNavigator`.

### 4.2 Display Columns

| Column | Source | Notes |
|--------|--------|-------|
| Name | `record.name` | Developer-supplied label |
| Method | `record.method` | GET, POST, PUT, … |
| Status | `record.statusCode` | Colour-coded (green/red) via existing `outcomeColor` |
| Duration | `record.duration` | Formatted via existing `formatDuration` |
| Relative time | `record.startedAt` | Relative to scope entry (existing pattern from TimelinePanel) |

### 4.3 Panel Type

The existing overlay uses a `MaterialPageRoute` push for the detail screen
(`ApiTraceDetailScreen`). The endpoint panel should follow the same pattern
to maintain consistency: push a new screen via the existing `_navKey`.

### 4.4 Interaction Model

Currently tapping a route row fires `onScopeSelected` which **filters the
Timeline**. Two options:

- **A — Dual action (recommended):** Tap → filter (existing behaviour).
  Add a trailing icon button (`Icons.list_alt_rounded`) to open the
  endpoint detail panel. Preserves existing muscle memory.
- **B — Replace:** Tap → open endpoint panel. The filter action moves to
  a long-press or a secondary toggle. Breaking change.

---

## 5. Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Retrofit conflict** — existing `onTap` filters Timeline | Medium | Dual-action pattern preserves existing behaviour; new icon for panel |
| **Performance** — large record sets (>1000) slow panel open | Low | `ListView.builder` — already used in TimelinePanel |
| **Overflow on small screens** | Low | Scrollable list; existing panel pattern handles this |
| **Rebuilds on record changes** | Low | Filter produces a new list; `ListView.builder` diffs efficiently |

---

## 6. Non-Goals

- ❌ Editing/deleting records from the endpoint panel
- ❌ Exporting the endpoint list
- ❌ Grouping by host/domain within a route
- ❌ Real-time streaming (user reopens to see new records)
- ❌ Nested route expansion inside the panel (route tree handles hierarchy)
- ❌ Request/response body details (existing Timeline detail screen)

---

## 7. Open Questions for Proposal

1. **Interaction model:** dual-action (tap=filter, icon=panel) or replace
   (tap=panel)?
2. **Empty state:** what to show when a route has zero endpoints?
3. **Column set:** just name/method/status/duration, or also include
   relative timestamp and response size?

---

## 8. Result Contract

**status**: complete
**executive_summary**: Exploration confirms the change is well-scoped.
~2 files modified, 1 file created. Core data already exists
(records tagged with `routeScopeId`). Main decisions needed:
interaction model and panel pattern. No blocking risks identified.
**artifacts**:

- `openspec/changes/route-endpoint-detail-panel/exploration.md`
**next_recommended**: sdd-proposal
**risks**: Retrofit conflict with existing tap-to-filter behaviour
  is the main risk. Mitigation: dual-action pattern.
**skill_resolution**: No external skills needed.
