# Route Endpoint Detail Panel — Tasks

**Change**: `route-endpoint-detail-panel`
**Date**: 2026-07-16
**Phase**: sdd-tasks
**Depends on**: proposal, spec (route-scope delta), design

---

## Workload Forecast

| Metric | Value |
|--------|-------|
| Files created | 1 (route_endpoint_panel.dart) |
| Files modified | 2 (route_tree_tab.dart, api_trace_overlay.dart) |
| Test file(s) modified | 1 (overlay_test.dart) |
| Estimated changed lines | ~265 |
| Review budget | 400 (within budget) |
| Chained PRs required | No |

---

## Task List

### TASK-REP-001 — Add `EndpointPanelCallback` typedef to `route_tree_tab.dart`

**Description**: Add a new typedef for the endpoint panel callback
at the top of `route_tree_tab.dart`, alongside the existing
`ScopeSelectionCallback`.

**Definition**:

```dart
/// Callback fired when the user taps the list-icon to open the
/// endpoint detail panel for a route scope.
/// [entry] is the selected [RouteScopeEntry].
/// [records] is the pre-filtered list of [ApiTraceRecord]s whose
/// [routeScopeId] matches [entry.scopeId].
typedef EndpointPanelCallback = void Function(
    RouteScopeEntry entry, List<ApiTraceRecord> records);
```

**Test**: No dedicated test — the typedef is static and tested
through the widget integration tests (TASK-REP-005).

**Files**: `lib/src/overlay/route_tree_tab.dart`

---

### TASK-REP-002 — Add `onShowEndpoints` callback to `RouteTreeTab`

**Description**: Add a new `onShowEndpoints` nullable property of
type `EndpointPanelCallback?` to the `RouteTreeTab` widget class,
after the existing `onScopeSelected` property.

**Changes to `RouteTreeTab`**:

```dart
/// Called when the user taps the list-icon to open the endpoint
/// detail panel for a route.
final EndpointPanelCallback? onShowEndpoints;
```

**Test**: No dedicated unit test — verified in TASK-REP-005 widget
tests.

**Files**: `lib/src/overlay/route_tree_tab.dart`

---

### TASK-REP-003 — Add list-icon `IconButton` to `_RouteTreeRow`

**Description**: Add a trailing `IconButton` with
`Icons.list_alt_rounded` to the `_RouteTreeRow` widget. The icon
must have tooltip `"Show endpoints"`. Add `onShowEndpoints` callback
parameter to `_RouteTreeRow`. Wire the icon's `onPressed` to call
`onShowEndpoints` with the entry and a pre-filtered records list.

**Changes to `_RouteTreeRow`**:

```dart
// New constructor parameter:
required this.onShowEndpoints,

// In build(), after the error badge (or instead of SizedBox when
// there's no error):
if (onShowEndpoints != null)
  IconButton(
    icon: const Icon(Icons.list_alt_rounded, size: 18),
    tooltip: 'Show endpoints',
    onPressed: () => onShowEndpoints!(entry),
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    splashRadius: 16,
  ),
```

**Filter logic in `_RouteTreeRow.build`**: The row receives
`onShowEndpoints` as a `void Function(RouteScopeEntry)` callback
that internally filters records. The `_RouteTreeTabState.buildTreeNodes`
method creates the filtered list at tree-build time and passes it
as a closure.

**RED test** (before implementation):

```dart
test('REQ-REP-001/005: list-icon button renders on every route tile', () {
  // GIVEN a RouteTreeTab with 2 route entries
  // WHEN rendered
  // THEN each tile has an IconButton with Icons.list_alt_rounded
});
```

**Files**: `lib/src/overlay/route_tree_tab.dart`

---

### TASK-REP-004 — Create `RouteEndpointPanel` widget

**Description**: Create a new file `route_endpoint_panel.dart`
with the `RouteEndpointPanel` `StatefulWidget`.

**Widget requirements**:

1. Constructor receives `records` (`List<ApiTraceRecord>`) and
   `routeName` (`String`).
2. Builds a `Scaffold` with `AppBar(title: '$routeName Endpoints')`.
3. When `records` is empty, renders a centred empty state with
   `Icons.inbox_rounded`, `"No endpoints recorded for this route."`,
   and `"Route: $routeName"`.
4. When `records` is non-empty, renders a `ListView.builder` with
   `ListTile` rows showing name, method, status code (colour-coded),
   and duration.
5. Tapping a row pushes `ApiTraceDetailScreen` via
   `MaterialPageRoute`.
6. The entire widget tree is guarded by `kDebugMode` (returns
   `SizedBox.shrink()` in release mode).

**RED tests** (before implementation):

```dart
test('REQ-REP-002: panel renders all filtered records', () { ... });
test('REQ-REP-002: row tap opens ApiTraceDetailScreen', () { ... });
test('REQ-REP-004: empty state when records is empty', () { ... });
test('REQ-REP-006: RouteEndpointPanel not found in release', () { ... });
```

**Files**: `lib/src/overlay/route_endpoint_panel.dart` (new)

---

### TASK-REP-005 — Wire `onShowEndpoints` in `_PackageNavigator`

**Description**: In `api_trace_overlay.dart`, locate
`_PackageNavigator`'s build method where `RouteTreeTab` is
instantiated. Add the `onShowEndpoints` parameter that pushes a
`RouteEndpointPanel`.

**Implementation**:

```dart
// In _PackageNavigatorState, add method:
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

// In build(), pass to RouteTreeTab:
onShowEndpoints: _onShowEndpoints,
```

**Import**: Add import for `route_endpoint_panel.dart`.

**RED test**:

```dart
test('REQ-REP-001/005: dual-action integration',
     () { ... });
```

**Files**: `lib/src/overlay/api_trace_overlay.dart`

---

### TASK-REP-006 — Widget tests for the dual-action panel

**Description**: Add test scenarios covering the new requirements
in `test/overlay_test.dart`.

**Test scenarios** (see spec for exact Given/When/Then):

| Scenario | Requirement | Type |
|----------|-------------|------|
| Tap list-icon pushes RouteEndpointPanel | REQ-REP-001 | Widget |
| Tap (body) still filters the timeline | REQ-REP-001 | Widget |
| List-icon does not trigger filter | REQ-REP-001 | Widget |
| List-icon tooltip is present | REQ-REP-001 | Widget |
| Panel renders all filtered records | REQ-REP-002 | Widget |
| Row tap opens detail screen | REQ-REP-002 | Widget |
| Filter produces exact match | REQ-REP-003 | Unit |
| Filter with no matching records | REQ-REP-003 | Unit |
| Empty state rendered when records empty | REQ-REP-004 | Widget |
| Every route tile has the list-icon | REQ-REP-005 | Widget |
| Tapping list-icon fires onShowEndpoints | REQ-REP-005 | Widget |
| Tapping body fires onScopeSelected only | REQ-REP-005 | Widget |
| RouteEndpointPanel guarded in release | REQ-REP-006 | Widget |

**Files**: `test/overlay_test.dart`

---

### TASK-REP-007 — Validate with `flutter test` and `dart analyze`

**Description**: Run the full test suite and static analysis after
implementation to ensure no regressions.

```bash
flutter test
dart analyze
```

**Files**: No source changes.

---

## Implementation Order

```
TASK-REP-001 (typedef)
  → TASK-REP-002 (callback prop)
  → TASK-REP-004 (RouteEndpointPanel widget)
  → TASK-REP-003 (list-icon in _RouteTreeRow)
  → TASK-REP-005 (wire in _PackageNavigator)
  → TASK-REP-006 (tests)
  → TASK-REP-007 (validate)
```

Dependency: TASK-REP-001 and TASK-REP-002 can be done first as they
are additive. TASK-REP-004 can be parallelised with TASK-REP-003.
TASK-REP-005 depends on TASK-REP-004 existing. TASK-REP-006 depends
on all implementation tasks. TASK-REP-007 depends on everything.

---

## Risk Notes

- **Navigator context**: `_PackageNavigator`'s context is inside the
  overlay which lives in the `WidgetsApp` overlay. The root Navigator
  should be accessible. If not, use `widget.navigatorKey` to push.
- **IconButton tap vs InkWell tap**: Flutter's gesture arena resolves
  this correctly — the `IconButton` has its own `GestureRecognizer`
  and wins the arena for taps on the icon area. No manual
  `HitTestBehavior` override needed.
- **Release guard**: `RouteEndpointPanel` must check `kDebugMode` at
  build time, consistent with the existing overlay pattern.

---

## Result Contract

**status**: complete
**executive_summary**: 7 implementation tasks identified (~265
  estimated lines). Strict TDD with RED tests before each production
  code change. All within the 400-line review budget. Single PR.
**artifacts**:

- `openspec/changes/route-endpoint-detail-panel/specs/route-scope/spec.md`
- `openspec/changes/route-endpoint-detail-panel/specs/route-scope/design.md`
- `openspec/changes/route-endpoint-detail-panel/specs/route-scope/tasks.md`
**next_recommended**: sdd-apply
**risks**: None blocking. Navigator context resolution is the main
  risk — mitigated by using `Navigator.of(context, rootNavigator: true)`
  fallback.
**skill_resolution**: No external skills needed.
