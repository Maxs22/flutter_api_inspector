# Route-Scoped Network Inspector — Design

## Overview

This design adds a `RouteScope` layer that correlates every HTTP
request with the Flutter screen that was active at dispatch time.
The correlation is stored in the existing `ApiTraceRecord.extra`
map, so the model stays backward-compatible. A new "Routes" tab in
the overlay lets testers browse a hierarchical tree of visited
screens and filter the timeline to a single screen's calls.

## Module Layout

```
lib/src/
  route_scope.dart              ← RouteScope service + RouteScopeEntry
  route_scope_observer.dart     ← NavigatorObserver implementation

lib/src/overlay/
  route_tree_tab.dart           ← Route tree panel widget
```

Changes to existing files:

```
lib/src/model/api_trace_record.dart   ← convenience getters (no breaking change)
lib/src/interceptor/dio_interceptor.dart   ← tag requests
lib/interceptor/http_overrides.dart        ← tag requests
lib/src/overlay/api_trace_overlay.dart     ← add "Routes" tab
lib/src/overlay/timeline_panel.dart        ← filter by routeScopeId
```

## 1. RouteScope Service (`route_scope.dart`)

### Data model

```dart
class RouteScopeEntry {
  final int scopeId;
  final String routeName;
  final String? navigatorRoute;
  final DateTime enteredAt;
  final int? parentScopeId;

  const RouteScopeEntry({
    required this.scopeId,
    required this.routeName,
    this.navigatorRoute,
    required this.enteredAt,
    this.parentScopeId,
  });
}
```

### Singleton API

```dart
class RouteScope {
  static RouteScope? _instance;

  /// The active (topmost) scope entry, or null if no route has been pushed.
  static RouteScopeEntry? get current => _instance?._current;

  /// All scope entries tracked this session, oldest first.
  static List<RouteScopeEntry> get entries => ...;

  /// Whether route tracking is active (kDebugMode).
  static bool get isActive => _instance != null;

  /// Initialize with a NavigatorObserver-compatible callback.
  /// Called once by ApiTrace.runApp.
  static void init() { ... }  // creates _instance in debug mode only

  /// Called by RouteScopeObserver.
  static void onPush(Route<dynamic> route) { ... }
  static void onPop(Route<dynamic> route) { ... }
  static void onReplace(Route<dynamic> route) { ... }

  /// Release resources (called by ApiTrace.dispose).
  static void dispose() { _instance = null; }
}
```

### State machine

```
Stack depth 0: _stack = [] → current = null
  push(A)    → _stack = [A(id=1)]                 → current = A
  push(B)    → _stack = [A(id=1), B(id=2)]         → current = B (parent=1)
  pop(B)     → _stack = [A(id=1)]                  → current = A
  replace(C) → _stack = [A(id=1), C(id=3)]         → current = C (parent=1)
  push(D)    → _stack = [A(id=1), C(id=3), D(id=4)] → current = D (parent=3)
  pop(D)     → _stack = [A(id=1), C(id=3)]         → current = C
  pop(C)     → _stack = [A(id=1)]                  → current = A
  pop(A)     → _stack = []                         → current = null
```

`scopeId` is a monotonically increasing counter. Entries are NEVER
removed from the `entries` list — only their position on the stack
changes. This way the Route Tree UI can always render the full
session history.

### kDebugMode guard

```dart
static void init() {
  if (!kDebugMode) return;  // no-op in release
  _instance ??= RouteScope._();
}
```

All public methods check `_instance != null` before operating.

## 2. NavigatorObserver (`route_scope_observer.dart`)

```dart
class RouteScopeObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    RouteScope.onPush(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    RouteScope.onPop(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) RouteScope.onReplace(newRoute);
  }
}
```

### Integration in ApiTrace.runApp

`ApiTrace.runApp` already wraps the developer's `MaterialApp`. The
observer is injected into that wrapped app:

```dart
// Inside BootstrapMaterialAppHarness
MaterialApp(
  navigatorObservers: [
    ...config.navigatorObservers ?? [],
    if (kDebugMode) RouteScopeObserver(),
  ],
  ...
)
```

For `MaterialApp.router` users, we document that they should add
`RouteScopeObserver()` to their router's `observers` list, OR we
auto-inject it when using `ApiTrace.runApp` with a router.

**Decision**: Auto-inject via the harness. The developer doesn't
need to do anything extra. When `ApiTrace.runApp` is used, the
observer is always added.

## 3. Dio Interceptor Tagging

In `TracedDioInterceptor.onRequest`:

```dart
@override
void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
  final scope = RouteScope.current;
  if (scope != null) {
    options.extra['routeScopeId'] = scope.scopeId;
    options.extra['routeName'] = scope.routeName;
  }
  // ... existing logic
}
```

When the interceptor later builds the `ApiTraceRecord`, the extra
map is forwarded directly (already supported — `options.extra` is
passed as `record.extra`).

## 4. HttpOverrides Tagging

In `TracedHttpClient` (inside `http_overrides.dart`), when a request
is closed and the record is about to be created:

```dart
final scope = RouteScope.current;
final extra = <String, Object?>{
  if (scope != null) 'routeScopeId': scope.scopeId,
  if (scope != null) 'routeName': scope.routeName,
};
// Merge into the record's extra map
```

## 5. Model Convenience Getters

In `api_trace_record.dart`:

```dart
extension ApiTraceRecordScope on ApiTraceRecord {
  int? get routeScopeId => extra['routeScopeId'] as int?;
  String? get routeName => extra['routeName'] as String?;
}
```

This is an extension, not a class change — zero breaking change.
The `extra` map already exists and is forwarded through.

## 6. Route Tree UI (`route_tree_tab.dart`)

### Widget hierarchy

```
RouteTreeTab
├── AppBar-style header: "Routes" + clear filter button
├── RouteTreeView (ListView.builder)
│   ├── RouteTreeRow (per scope entry)
│   │   ├── Indent spacer (depth * 16px)
│   │   ├── Expand/collapse chevron (if has children)
│   │   ├── Route name label
│   │   ├── Call count badge (total calls for this scope)
│   │   ├── Error count badge (red, if > 0)
│   │   └── Highlight bar (active route)
│   └── ...
```

### Filter integration

When a route row is tapped:

1. `RouteTreeTab` sets a `selectedScopeId` state variable.
2. The parent overlay passes this as a filter predicate to the
   timeline panel: `(record) => record.routeScopeId == selectedScopeId`.
3. Timeline panel re-renders with only matching records.
4. Relative timestamps are computed: `record.startedAt.difference(scope.enteredAt)`.
5. Tapping "clear" or tapping the same route again sets
   `selectedScopeId = null` (show all).

### Relative timestamp formatting

```dart
String formatRelativeTime(Duration delta) {
  if (delta.inMilliseconds < 1000) return '+${delta.inMilliseconds}ms';
  if (delta.inSeconds < 60) return '+${delta.inSeconds}.${delta.inMilliseconds % 1000 ~/ 100}s';
  final minutes = delta.inMinutes;
  final seconds = delta.inSeconds % 60;
  return '+${minutes}m${seconds.toString().padLeft(2, '0')}s';
}
```

## 7. Integration Wiring

### ApiTrace.runApp changes

In `bootstrap.dart` (or wherever the `MaterialApp` wrapper lives):

```dart
// Inside the wrapped app builder
if (kDebugMode) {
  RouteScope.init();
  // Add RouteScopeObserver to navigatorObservers
}
```

### Overlay tab bar changes

In `api_trace_overlay.dart`:

```dart
enum OverlayTab { timeline, routes }

// Tab bar now has two tabs
TabBar(
  tabs: [
    Tab(text: 'Timeline'),
    Tab(text: 'Routes'),
  ],
)

// TabBarView
TabBarView(
  children: [
    TimelinePanel(...),
    RouteTreeTab(...),
  ],
)
```

## 8. Export per Route

When `RouteTreeTab` has an active `selectedScopeId`, the existing
"Copy as cURL" button in the detail screen / timeline header
receives the filtered record list instead of the full timeline.

No new export logic — just filter the existing records and pass
them to the existing cURL formatter.

## 9. kDebugMode Guard Summary

| Component | Guard |
|-----------|-------|
| `RouteScope` singleton | `kDebugMode` in `init()` |
| `RouteScopeObserver` | Added only when `kDebugMode` in harness |
| Dio interceptor tagging | Null-check on `RouteScope.current` (returns null in release) |
| HttpOverrides tagging | Same null-check |
| `RouteTreeTab` widget | Rendered only when `kDebugMode` (same as overlay) |

## Trade-offs

| Decision | Rationale |
|----------|-----------|
| Scope data in `extra` map, not new fields | Zero breaking change; backward-compatible with existing stored records |
| Extension getters instead of class fields | No migration needed; works on records created before this feature |
| `RouteScopeObserver` auto-injected in harness | Zero-config for the 90% case; `MaterialApp.router` users add manually |
| Entries never deleted from `entries` list | Tree UI needs full session history even after pop |
| Relative timestamps only in filtered mode | Absolute timestamps are default; relative adds context when scoped |

## Open Questions

1. **Performance**: Route tree with 100+ entries — is `ListView.builder`
   sufficient, or do we need `SliverList`? → `ListView.builder` is fine;
   each row is cheap.
2. **Route naming**: `Route.settings.name` is often null in real apps.
   The fallback to `runtimeType` produces names like
   `_MaterialPageRoute`. → Document that developers should name their
   routes for best results. Add a `RouteScope.nameProvider` override
   for custom naming strategies.
3. **Nested Navigators**: Apps with bottom tabs + inner navigation
   create multiple navigator stacks. → v1 tracks only the primary
   navigator (the one `NavigatorObserver` receives from the harness).
   Nested navigator tracking is v2.
