// Route-scope tracking service.
//
// `RouteScope` is a singleton that tracks the route-stack state
// via `NavigatorObserver` callbacks. Every route push/pop/replace
// creates a `RouteScopeEntry` with a unique `scopeId`, enabling
// downstream interception code (Dio interceptor, HttpOverrides) to
// tag each HTTP request with the screen that was active at dispatch
// time.
//
// Use:
//
// ```dart
// RouteScope.init();              // called once by ApiTrace.runApp
// RouteScope.onPush(route);       // called by RouteScopeObserver
// RouteScope.current;             // active route scope entry
// RouteScope.entries;             // all entries this session
// ```
//
// All public methods are no-ops in release builds
// (REQ-RS-001, REQ-RS-008).

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Metadata for a single route-scope entry. Created when a route
/// is pushed onto the stack. Entries are immutable and live in
/// the `RouteScope.entries` list for the entire session (they are
/// never removed — only the stack position changes on pop).
class RouteScopeEntry {
  /// Creates a route-scope entry.
  const RouteScopeEntry({
    required this.scopeId,
    required this.routeName,
    this.navigatorRoute,
    required this.enteredAt,
    this.parentScopeId,
  });

  /// Unique, monotonically increasing scope ID per session.
  final int scopeId;

  /// Derived from `Route.settings.name ?? route.runtimeType.toString()`.
  final String routeName;

  /// The `MaterialPageRoute`-style route path when available.
  final String? navigatorRoute;

  /// Wall-clock time when the route was pushed.
  final DateTime enteredAt;

  /// The `scopeId` of the route that was active before this push,
  /// enabling tree reconstruction. `null` for the first route.
  final int? parentScopeId;
}

/// Singleton that tracks the current route stack and exposes the
/// active scope for request tagging.
///
/// In release builds (`kDebugMode == false`), `init()` is a no-op
/// and all accessors return null / empty lists (REQ-RS-008).
class RouteScope {
  RouteScope._();

  static RouteScope? _instance;

  /// The live stack of scope entries (newest at the end).
  final List<RouteScopeEntry> _stack = <RouteScopeEntry>[];

  /// All scope entries created this session, in creation order.
  /// Never shrinks — entries from popped routes remain available
  /// for the Route Tree UI.
  final List<RouteScopeEntry> _entries = <RouteScopeEntry>[];

  /// Monotonically increasing counter for [RouteScopeEntry.scopeId].
  int _nextScopeId = 1;

  /// Initialize the singleton. Safe to call multiple times; only
  /// the first call in debug mode creates the instance.
  static void init() {
    if (!kDebugMode) return; // REQ-RS-008: no-op in release
    _instance ??= RouteScope._();
  }

  /// The active (topmost) scope entry, or `null` if no route has
  /// been pushed yet.
  static RouteScopeEntry? get current => _instance?._stack.lastOrNull;

  /// All scope entries tracked this session, in creation order
  /// (oldest first). Never shrinks — popped routes are retained.
  static List<RouteScopeEntry> get entries => _instance != null
      ? List<RouteScopeEntry>.unmodifiable(_instance!._entries)
      : const <RouteScopeEntry>[];

  /// Number of scope entries tracked so far.
  static int get count => _instance?._entries.length ?? 0;

  /// Called by [RouteScopeObserver.didPush].
  static void onPush(Route<dynamic> route) {
    final instance = _instance;
    if (instance == null) return;
    final parentId = instance._stack.lastOrNull?.scopeId;
    final entry = RouteScopeEntry(
      scopeId: instance._nextScopeId++,
      routeName: _resolveRouteName(route),
      navigatorRoute: route.settings.name,
      enteredAt: DateTime.now(),
      parentScopeId: parentId,
    );
    instance._stack.add(entry);
    instance._entries.add(entry);
  }

  /// Called by [RouteScopeObserver.didPop].
  static void onPop(Route<dynamic> route) {
    final instance = _instance;
    if (instance == null) return;
    if (instance._stack.isNotEmpty) {
      instance._stack.removeLast();
    }
  }

  /// Called by [RouteScopeObserver.didReplace].
  static void onReplace(Route<dynamic> route) {
    final instance = _instance;
    if (instance == null) return;
    final parentId = instance._stack.length > 1
        ? instance._stack[instance._stack.length - 2].scopeId
        : null;
    final entry = RouteScopeEntry(
      scopeId: instance._nextScopeId++,
      routeName: _resolveRouteName(route),
      navigatorRoute: route.settings.name,
      enteredAt: DateTime.now(),
      parentScopeId: parentId,
    );
    if (instance._stack.isNotEmpty) {
      instance._stack[instance._stack.length - 1] = entry;
    } else {
      instance._stack.add(entry);
    }
    instance._entries.add(entry);
  }

  /// Dispose the singleton. Called by [ApiTrace.dispose].
  static void dispose() {
    _instance = null;
  }

  /// Resolve a human-readable name for a route.
  static String _resolveRouteName(Route<dynamic> route) {
    return route.settings.name ?? route.runtimeType.toString();
  }
}
