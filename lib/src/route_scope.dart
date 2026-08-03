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
/// is pushed onto the stack. Entries are immutable. They remain in
/// `RouteScope.entries` while their navigation flow is active; when
/// navigation returns to the root route, historical child entries are
/// cleared while the root entry is preserved for the next flow.
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
  /// Cleared when navigation returns to the root ("Reset al volver a home"
  /// — REQ-RS-012), so the route tree doesn't accumulate flows forever.
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

  /// Scope entries for the current route flow, in creation order
  /// (oldest first). Popped child routes are retained while the user
  /// remains away from root. Returning to root clears historical child
  /// entries but preserves the root entry for request tagging and tree
  /// reconstruction.
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
  /// When the stack is reduced to 0 or 1 entries (returned to root
  /// / home), clears historical child entries so a new navigation
  /// flow starts fresh while preserving the root entry — "Reset al
  /// volver a home" (REQ-RS-012).
  static void onPop(Route<dynamic> route) {
    final instance = _instance;
    if (instance == null) return;
    if (instance._stack.isNotEmpty) {
      instance._stack.removeLast();
    }
    // Reset when we've returned to root: wipe historical entries
    // so the next flow starts clean (REQ-RS-012 — "Reset al volver
    // a home"). The root entry (Home) is preserved in entries so
    // the route tree can build a proper hierarchy; only historical
    // children are removed.
    if (instance._stack.length <= 1) {
      final root = instance._stack.isNotEmpty ? instance._stack.first : null;
      instance._entries.clear();
      if (root != null) {
        instance._entries.add(root);
      }
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
