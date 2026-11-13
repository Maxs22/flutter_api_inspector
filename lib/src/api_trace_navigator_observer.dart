import 'dart:collection';

import 'package:flutter/widgets.dart';

/// Gives host popup routes priority over an [ApiTraceHost].
///
/// Own one stable instance alongside the actual Navigator, add it to that
/// Navigator's observers, and dispose it after the host is unmounted. This
/// observer is independent of RouteScopeObserver and does not capture routes.
class ApiTraceNavigatorObserver extends NavigatorObserver with ChangeNotifier {
  final Set<PopupRoute<dynamic>> _popups = HashSet.identity();
  bool _disposed = false;

  /// Whether a popup is entering, active, or still animating out.
  bool get hasActivePopup => _popups.isNotEmpty;

  void _track(Route<dynamic>? route) {
    if (_disposed || route is! PopupRoute<dynamic> || !_popups.add(route)) {
      return;
    }
    notifyListeners();
    // `popped` completes before the reverse transition. Keep the inspector
    // suspended until the overlay entries have actually been removed.
    route.completed.then((_) {
      if (_disposed) return;
      if (_popups.remove(route)) notifyListeners();
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _track(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _track(newRoute);
    // oldRoute remains tracked through its own completed future, just as on
    // pop/remove. This also handles overlapping popup transitions.
  }

  @override
  void dispose() {
    _disposed = true;
    _popups.clear();
    super.dispose();
  }
}
