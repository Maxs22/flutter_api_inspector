# Route Endpoint Detail Panel — Proposal

**Change**: `route-endpoint-detail-panel`
**Date**: 2026-07-15
**Phase**: sdd-proposal

---

## Problem Statement

The Routes tab currently shows a tree of navigated routes with visit
counters, but tapping a route only filters the Timeline. There is no
dedicated surface to inspect **which API endpoints were called within a
given route's scope**. Developers debugging network issues per-screen must
manually correlate route visits with timeline entries, which is tedious
and error-prone.

Without this panel, the RouteScope/Routes tab infrastructure is
underutilised: the `routeScopeId` tagging exists but lacks a clear UX for
consumption.

---

## Solution Overview

Add a **dual-action interaction** to route tiles in the Routes tab:

1. **Tap** (unchanged) — filters the Timeline to show only calls for that
   route's `routeScopeId`.
2. **Tap the list icon** — pushes a `MaterialPageRoute` to a detail panel
   showing all endpoints tagged with that route's `routeScopeId`.

### Detail Panel Columns

| Column | Source | Notes |
|--------|--------|-------|
| Name | `record.name` | Developer-supplied label |
| Method | `record.method` | GET, POST, PUT… |
| Status | `record.statusCode` | Colour-coded via `outcomeColor()` |
| Duration | `record.duration` | Formatted, e.g. `230ms` |

### Empty State

When no endpoints were recorded under the route scope, the panel displays
a friendly message with a neutral icon and the route name as subtitle.

### Data Flow

```
Route tile (tap list icon)
  → Look up routeScopeId from RouteScopeEntry
  → Filter widget.records where r.routeScopeId == selectedScopeId
  → Push RouteEndpointPanel(records: filtered, routeName: …)
```

---

## Scope

### In Scope

- Dual-action on route tile (tap = Timeline filter; list icon = endpoint
  panel)
- Endpoint detail panel with Name, Method, Status, Duration columns
- Status code coloured via existing `outcomeColor()` utility
- Empty state with friendly messaging
- `MaterialPageRoute` push (consistent with `ApiTraceDetailScreen`)
- Static snapshot of endpoint data at panel open time

### Out of Scope (v1)

- Child-route endpoint aggregation (exact `routeScopeId` match only)
- Real-time streaming / auto-refresh of endpoint list
- Search or filter within the panel
- Pagination or load-more (standard `ListView` is sufficient)
- Endpoint detail preview inline (tap row → existing `ApiTraceDetailScreen`)
- Sorting or column reordering
- Export or share of endpoint list

---

## Success Metrics

| Metric | Target | How to measure |
|--------|--------|----------------|
| Completion | Feature shipped without regressions | All test scenarios pass |
| Consistency | Panel navigates via `MaterialPageRoute` | Visual inspection matches `ApiTraceDetailScreen` pattern |
| Data accuracy | 100% of route-tagged calls appear | Manual audit against Timeline filter results |
| Empty state | Friendly empty state rendered when no calls exist | Manual test with fresh route with no API calls |
| Colour correctness | Status column uses same colours as Timeline | Visual comparison with existing `outcomeColor` usage |

---

## Impact Analysis

### Components Touched

| Component | Change |
|-----------|--------|
| `route_tree_tab.dart` | Add list-icon button alongside existing tap handler |
| `route_endpoint_panel.dart` | **New file**: panel layout, list, empty state |
| `api_trace_overlay.dart` | Wire `_PackageNavigator` to push the new panel |
| `outcomeColor` / formatting utils | Already exist — no change |

### Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Performance with large endpoint lists | Low | `ListView.builder` handles virtualisation natively |
| Icon clarity | Medium | Use `Icons.list_alt_rounded` with tooltip |
| Duplication with Timeline filter | Low | Dual-action is explicit: tap vs icon |
| `routeScopeId` mismatch | Low | Existing tests verify tagging |

### Rollback

- **Simple**: remove the list icon from route tiles and delete
  `route_endpoint_panel.dart`.
- **No migration**: no schema changes; `routeScopeId` is already on every
  record.

---

## Open Questions (Deferred)

1. **Child-route aggregation** — parent route showing children's endpoints?
   Deferred; v1 uses exact `routeScopeId` match only.
2. **Auto-refresh** — static snapshot in v1; add if users report staleness.
3. **Search/filter** — not needed for v1 unless lists exceed ~100 routinely.
4. **Dark mode** — automatic via existing theme inheritance.

---

## Result Contract

**status**: complete
**executive_summary**: Proposal defines a focused, low-risk extension to
  the Routes tab. Dual-action pattern preserves existing behaviour.
  One new widget, two small modifications. Core data infrastructure
  already in place.
**artifacts**:

- `openspec/changes/route-endpoint-detail-panel/proposal.md`
**next_recommended**: sdd-spec
**risks**: Icon clarity is the main UX risk — mitigated by tooltip.
**skill_resolution**: No external skills needed.
