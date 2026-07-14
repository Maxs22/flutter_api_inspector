// NavigatorObserver that feeds route transitions into RouteScope.
//
// Attach to the host MaterialApp's `navigatorObservers` to
// automatically track push/pop/replace and tag HTTP requests
// with the active screen's scope ID.
//
// The observer is auto-injected by `ApiTrace.runApp` via
// `BootstrapMaterialAppHarness`. Developers using
// `MaterialApp.router` should add it to their router's
// `observers` list manually.
//
// (REQ-RS-002)

import 'package:flutter/widgets.dart';
import 'package:flutter_api_inspector/src/route_scope.dart';

/// [NavigatorObserver] that calls [RouteScope.onPush],
/// [RouteScope.onPop], and [RouteScope.onReplace] on every
/// route transition.
///
/// No-op in release builds (delegates to [RouteScope] which
/// is itself a no-op when `kDebugMode == false`).
class RouteScopeObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    RouteScope.onPush(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    RouteScope.onPop(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      RouteScope.onReplace(newRoute);
    }
  }
}
