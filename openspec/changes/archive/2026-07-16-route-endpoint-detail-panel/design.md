# Route Endpoint Detail Panel — Design

**Change**: `route-endpoint-detail-panel`
**Date**: 2026-07-16
**Phase**: sdd-design

---

## Overview

Add a dual-action interaction to route tiles in the Routes tab:

- **Tap** (unchanged) — filters the Timeline to the route's scopeId.
- **List icon** — pushes a `MaterialPageRoute` to `RouteEndpointPanel` showing all endpoints for that route scope.

The panel widget already exists at `lib/src/overlay/route_endpoint_panel.dart`. The only work item is wiring the `onShowEndpoints` callback through `_PackageNavigator` into `_PackageNavigatorState._buildTabbedContent`.

---

## Data Flow

```
_RouteTreeRow (icon tap)
  → _RouteTreeTabState filter: widget.records.where(r.routeScopeId == entry.scopeId)
  → widget.onShowEndpoints!(entry, filtered)
  → _PackageNavigatorState callback (via _navKey push)
  → MaterialPageRoute(RouteEndpointPanel(records: filtered, routeName: entry.routeName))
  → RouteEndpointPanel renders ListView or empty state
  → Row tap → MaterialPageRoute(ApiTraceDetailScreen(record: record))
```

---

## Component Changes

| File | Change | Type |
|------|--------|------|
| `lib/src/overlay/route_tree_tab.dart` | ✅ Already done — `EndpointPanelCallback` typedef, `onShowEndpoints` param on both classes, icon + callback in `_buildTreeNodes` | No change needed |
| `lib/src/overlay/route_endpoint_panel.dart` | ✅ Already done — full widget with empty state, list, duration formatting, outcomeColor, detail screen navigation | No change needed |
| `lib/src/overlay/api_trace_overlay.dart` | **Add `onShowEndpoints` param to `_PackageNavigator`, wire it into `_PackageNavigatorState`** | ~5 lines |

---

## Detailed Changes (api_trace_overlay.dart)

### 1. Add `onShowEndpoints` parameter to `_PackageNavigator`

```dart
class _PackageNavigator extends StatefulWidget {
  const _PackageNavigator({
    ...
    this.onShowEndpoints,
  });

  final EndpointPanelCallback? onShowEndpoints;
```

### 2. Wire callback in `_buildTabbedContent`

In the `RouteTreeTab` instantiation:

```dart
_ : RouteTreeTab(
    records: widget.records,
    onScopeSelected: widget.onScopeSelected,
    selectedScopeId: widget.selectedScopeId,
    onShowEndpoints: widget.onShowEndpoints,  // ← add this
  )
```

### 3. Thread from `_ApiTraceOverlayState` to `_PackageNavigator`

In `_ApiTraceOverlayState.build`, pass `onShowEndpoints` through to `_PackageNavigator`. The callback pushes a `MaterialPageRoute<RouteEndpointPanel>` onto `_navKey`.

### 4. Import

Add import for `route_endpoint_panel.dart` if not already present.

---

## Existing File Analysis

### route_tree_tab.dart — Already complete

- `EndpointPanelCallback` typedef (line 23): `void Function(RouteScopeEntry, List<ApiTraceRecord>)`
- `RouteTreeTab.onShowEndpoints` (line 59): nullable callback
- `_RouteTreeTabState._buildTreeNodes` (line 190-198): filters records and invokes callback
- `_RouteTreeRow.onShowEndpoints` + `Icons.list_alt_rounded` (line 348-355): icon button with tooltip

### route_endpoint_panel.dart — Already complete

- `RouteEndpointPanel` widget (line 25): accepts filtered records + route name
- Empty state with icon, message, route name subtitle
- `ListView.builder` with Name, Method+Status (colored), Duration
- Row tap → `ApiTraceDetailScreen`
- `_formatDuration()` helper
- `kDebugMode` guard

---

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| `_navKey` conflict | Low | Same navigator key used for detail screen pushes — no conflict |
| RouteEndpointPanel import missing | Low | Add import if needed |
| Regression in Routes tab tap behavior | Low | Dual-action preserves existing tap; icon is a separate gesture |

---

## Result Contract

**status**: complete
**executive_summary**: Design confirms all infrastructure is in place. Only ~5 lines of wiring needed in api_trace_overlay.dart. No new widgets, no new models, no new tests needed for the existing components — only a wiring test.
**artifacts**:

- `openspec/changes/route-endpoint-detail-panel/design.md`
**next_recommended**: sdd-tasks
**risks**: Minimal — the work is a pure wiring change.
**skill_resolution**: none
