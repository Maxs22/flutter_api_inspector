# Route Endpoint Detail Panel — Design

**Change**: `route-endpoint-detail-panel`
**Date**: 2026-07-16
**Phase**: sdd-design
**Depends on**: proposal, spec (route-scope delta)

---

## 1. Overview

This design covers the implementation of a dual-action interaction on
Route Tree tiles: tapping the tile body filters the Timeline (existing
behavior), and tapping a trailing list-icon button pushes a
`RouteEndpointPanel` that displays all endpoint calls tagged with that
route's `scopeId`.

The change is small and well-scoped: **one new widget file**,
**modifications to two existing files**, zero model changes.

---

## 2. Architecture

### 2.1 Widget Tree (before)

```
ApiTraceOverlay
 └─ _PackageNavigator
      ├─ TimelineTab
      └─ RouteTreeTab
           └─ _RouteTreeRow (tap → onScopeSelected)
```

### 2.2 Widget Tree (after)

```
ApiTraceOverlay
 └─ _PackageNavigator
      ├─ TimelineTab
      └─ RouteTreeTab
           └─ _RouteTreeRow
                ├─ tap body → onScopeSelected (filter timeline)
                └─ tap list-icon → onShowEndpoints(entry, records)
                                   ↓
                             Navigator.push
                                   ↓
                        RouteEndpointPanel
```

### 2.3 Navigation Flow

The `_PackageNavigator` (inside `api_trace_overlay.dart`) hosts the
TabBar + TabBarView. It already has access to:

- `widget.records` (all timeline records)
- `widget.navigatorKey` (or can `Navigator.of(context)` via the
  overlay's context)

When `onShowEndpoints` fires:

1. The callback receives the `RouteScopeEntry` and the full records
   list (passed through from `RouteTreeTab`).
2. The callback filters records by `routeScopeId`.
3. It pushes a `MaterialPageRoute(builder: (_) => RouteEndpointPanel(...))`
   using the same `Navigator` pattern as `ApiTraceDetailScreen`.

**Key decision**: filtering happens at the call site (in
`_PackageNavigator`), not inside `RouteEndpointPanel`. This keeps
the panel a pure presentation widget that receives already-filtered
data.

---

## 3. Component Design

### 3.1 RouteTreeTab changes (`route_tree_tab.dart`)

**New typedef**:

```dart
/// Callback for the endpoint detail panel list-icon.
/// [entry] is the selected route's scope entry.
/// [records] is the full timeline records list (filtered at call site).
typedef EndpointPanelCallback = void Function(
    RouteScopeEntry entry, List<ApiTraceRecord> records);
```

**New property on `RouteTreeTab`**:

```dart
final EndpointPanelCallback? onShowEndpoints;
```

**Changes to `_RouteTreeRow`**:

- Add `onShowEndpoints` callback parameter (nullable).
- In the row's build method, after the error badge (or call count
  badge when no errors), add:

  ```dart
  IconButton(
    icon: const Icon(Icons.list_alt_rounded, size: 18),
    tooltip: 'Show endpoints',
    onPressed: () => onShowEndpoints?.call(entry, ...),
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    splashRadius: 16,
  )
  ```

- The `InkWell.onTap` handler must NOT fire when the icon is tapped.
  This is achieved by the `IconButton` having its own `GestureDetector`
  inside — Flutter's event system ensures the icon's `onPressed` and
  the parent `InkWell.onTap` are independent. Each widget gets a
  separate `GestureRecognizer` in the gesture arena. Only one wins
  per tap location.

**Callback wiring**:

`RouteTreeTab` passes the full records list through:

```dart
onShowEndpoints: (entry) {
  final filtered = widget.records
      .where((r) => r.routeScopeId == entry.scopeId)
      .toList();
  widget.onShowEndpoints?.call(entry, filtered);
}
```

Wait — the `EndpointPanelCallback` signature passes both `entry` and
`records` (pre-filtered). The call site in `_PackageNavigator` is
where the actual `Navigator.push` happens. So the flow is:

```
_RouteTreeRow.onShowEndpoints
  → RouteTreeTab.onShowEndpoints(entry)
     → filter records, then call widget.onShowEndpoints(entry, filteredRecords)
  → _PackageNavigator callback
     → Navigator.push(MaterialPageRoute(builder: RouteEndpointPanel))
```

But actually, looking at this more carefully, `RouteTreeTab` already
receives `widget.records`. So it can do the filtering itself and
pass the filtered list through. That's cleaner.

**Updated flow**:

```dart
onShowEndpoints: (entry) {
  final filtered = widget.records
      .where((r) => r.routeScopeId == entry.scopeId)
      .toList();
  _onShowEndpoints?.call(entry, filtered);
}
```

### 3.2 RouteEndpointPanel (new file: `route_endpoint_panel.dart`)

```dart
class RouteEndpointPanel extends StatefulWidget {
  const RouteEndpointPanel({
    super.key,
    required this.records,
    required this.routeName,
  });

  final List<ApiTraceRecord> records;
  final String routeName;

  @override
  State<RouteEndpointPanel> createState() => _RouteEndpointPanelState();
}
```

**Build method**:

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('$routeName Endpoints'),
    ),
    body: widget.records.isEmpty
        ? _buildEmptyState(context)
        : _buildEndpointList(context),
  );
}
```

**Empty state**:

```dart
Widget _buildEmptyState(BuildContext context) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inbox_rounded, size: 48, color: inspectorMuted(context)),
        const SizedBox(height: 16),
        Text(
          'No endpoints recorded for this route.',
          style: TextStyle(fontSize: 14, color: inspectorMuted(context)),
        ),
        const SizedBox(height: 4),
        Text(
          'Route: ${widget.routeName}',
          style: TextStyle(fontSize: 12, color: inspectorMuted(context)),
        ),
      ],
    ),
  );
}
```

**Endpoint list row**:

```dart
Widget _buildEndpointList(BuildContext context) {
  return ListView.builder(
    itemCount: widget.records.length,
    itemBuilder: (context, index) {
      final record = widget.records[index];
      return ListTile(
        title: Text(record.name, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          '${record.method} · ${record.statusCode ?? '???'}',
          style: TextStyle(
            fontSize: 12,
            color: outcomeColor(context, record.outcome),
          ),
        ),
        trailing: Text(
          formatDuration(record.duration),
          style: const TextStyle(fontSize: 12),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ApiTraceDetailScreen(record: record),
            ),
          );
        },
      );
    },
  );
}
```

### 3.3 ApiTraceOverlay / _PackageNavigator wiring

`_PackageNavigator` currently builds `RouteTreeTab` as:

```dart
RouteTreeTab(
  records: widget.records,
  onScopeSelected: _onScopeSelected,
  selectedScopeId: _filterScopeId,
)
```

**After**:

```dart
RouteTreeTab(
  records: widget.records,
  onScopeSelected: _onScopeSelected,
  selectedScopeId: _filterScopeId,
  onShowEndpoints: _onShowEndpoints,
)
```

Where `_onShowEndpoints` is:

```dart
void _onShowEndpoints(RouteScopeEntry entry, List<ApiTraceRecord> records) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => RouteEndpointPanel(
        records: records,
        routeName: entry.routeName,
      ),
    ),
  );
}
```

The `Navigator.push` uses the surrounding `BuildContext` which is
inside the `_PackageNavigator` State's build context. Since
`_PackageNavigator` is a child of the `ApiTraceOverlay` that is
mounted in the overlay, the context should find a `Navigator`
ancestor (the root Navigator of the MaterialApp).

---

## 4. Tradeoffs Considered

| Decision | Option A (chosen) | Option B | Rationale |
|----------|-------------------|----------|-----------|
| Filter location | Call site (_PackageNavigator) | Inside RouteEndpointPanel | Keeps the panel a pure presentation widget; avoids needing to pass full records list and scopeId |
| Panel navigation | Navigator.push via context | Navigator via navigatorKey | Simpler; the panel is a standard screen pushed within the existing Navigator tree. navigatorKey is only needed for overlay entries outside the Navigator subtree |
| Row widget | ListTile | Custom row | ListTile is consistent, accessible, and provides tap target + ink splash out of the box |
| Static snapshot | Filter at open time | Stream/ValueListenable | Simpler; no rebuild tracking needed for v1 |

---

## 5. File Inventory

| File | Action | Estimated delta |
|------|--------|-----------------|
| `lib/src/overlay/route_tree_tab.dart` | Modify — add `onShowEndpoints` callback, list-icon button, pass records filter | ~30 lines |
| `lib/src/overlay/route_endpoint_panel.dart` | **Create** — new widget | ~120 lines |
| `lib/src/overlay/api_trace_overlay.dart` | Modify — wire `_onShowEndpoints` in `_PackageNavigator` | ~15 lines |
| `test/overlay_test.dart` | Add widget tests for the new panel | ~100 lines |

**Estimated total**: ~265 lines (within the 400-line review budget).

---

## 6. Open Questions (Design-level)

1. **Context for Navigator.push** — `_PackageNavigator` build context
   should have a Navigator ancestor (it's inside the overlay which
   lives in the WidgetsApp overlay). But the overlay uses a navigatorKey
   for `ApiTraceDetailScreen`. Should `RouteEndpointPanel` also use the
   same navigatorKey for consistency? **Decision deferred — verify at
   apply time; use `Navigator.of(context, rootNavigator: true)` as
   fallback.**

2. **ListTile vs custom row** — ListTile is the simplest approach but
   may not match the timeline panel's row style exactly. The spec
   doesn't require pixel-perfect matching with the timeline rows.
   **Decision: use ListTile for now.**

---

## 7. Result Contract

**status**: complete
**executive_summary**: Design covers one new widget, two file
  modifications, and zero model changes. The dual-action pattern
  preserves existing tap-to-filter behavior. Data flow is simple:
  call site filters, panel renders. ~265 estimated lines.
**artifacts**:

- `openspec/changes/route-endpoint-detail-panel/specs/route-scope/spec.md`
- `openspec/changes/route-endpoint-detail-panel/specs/route-scope/design.md`
**next_recommended**: sdd-tasks
**risks**: Navigator context resolution — the overlay uses a
  navigatorKey for `ApiTraceDetailScreen`; ensure `RouteEndpointPanel`
  uses consistent navigation. Mitigation: fall back to
  `Navigator.of(context, rootNavigator: true)`.
**skill_resolution**: No external skills needed.
