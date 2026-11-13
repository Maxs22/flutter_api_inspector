/// Public barrel for the `flutter_api_inspector` package.
///
/// Consumers should import this single file:
///
/// ```dart
/// import 'package:flutter_api_inspector/flutter_api_inspector.dart';
/// ```
///
/// The barrel re-exports the full public surface — model, API,
/// overlay, AND the two automatic interceptors — so one import is
/// all a project needs.
///
/// The package targets mobile / desktop (Flutter Web is a
/// non-goal: the browser's own DevTools Network tab already covers
/// web). `TracedHttpOverrides` is `dart:io`-based accordingly.
///
/// The per-file imports (`interceptor/http_overrides.dart`,
/// `interceptor/dio_interceptor.dart`) keep working for backwards
/// compatibility.
///
/// Internals (`Timeline`, id generator, body codec) are NOT re-exported.
library;

// --- Model layer (PR 1) -----------------------------------------------------
export 'src/detail.dart' show ApiTraceDetail;
export 'src/model/api_trace_record.dart'
    show ApiTraceRecord, ApiTraceRecordScope;
export 'src/model/api_trace_request.dart' show ApiTraceRequest;
export 'src/model/api_trace_response.dart' show ApiTraceResponse;
export 'src/outcome.dart' show ApiTraceOutcome;

// --- Instrumentation API (PR 2) ---------------------------------------------
export 'src/api_trace.dart' show ApiTrace;
export 'src/config.dart'
    show ApiTraceConfig, ApiTraceOverlayLabel, ApiTraceOverlayPosition;

// --- Overlay UI (PR 3) ------------------------------------------------------
export 'src/bootstrap.dart' show ApiTraceBootstrap;
export 'src/api_trace_host.dart' show ApiTraceHost;
export 'src/api_trace_navigator_observer.dart' show ApiTraceNavigatorObserver;
export 'src/overlay/api_trace_overlay.dart' show ApiTraceOverlay;
export 'src/overlay/detail_screen.dart' show ApiTraceDetailScreen;
export 'src/overlay/fab.dart' show ApiTraceFab;

// --- Route-scoped network inspector (route-scoped-network-inspector) -------
// `RouteScopeObserver` MUST be public: `MaterialApp.router` users add it to
// their router's `observers` list manually (design.md section 2); it cannot
// be auto-injected for router-based apps the way `BootstrapMaterialAppHarness`
// does for `MaterialApp`.
export 'src/route_scope.dart' show RouteScope, RouteScopeEntry;
export 'src/route_scope_observer.dart' show RouteScopeObserver;

// --- Automatic interceptors -------------------------------------------------
export 'interceptor/dio_interceptor.dart' show TracedDioInterceptor;
export 'interceptor/http_overrides.dart'
    show TracedHttpOverrides, TracedHttpClient;
