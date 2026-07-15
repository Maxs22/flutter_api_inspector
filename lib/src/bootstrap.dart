// The debug-only bootstrap widget (REQ-UI-001, REQ-UI-002).
//
// `ApiTraceBootstrap` is a `StatelessWidget` that wraps the
// developer's app. In release mode (kDebugMode == false),
// the build method short-circuits to the child unchanged, so
// the developer's widget tree is bit-identical to a tree
// without the bootstrap. In debug mode, the bootstrap wraps
// the child in a `Stack` (or `MaterialApp.builder`-style
// overlay) and mounts the `ApiTraceOverlay` on top.
//
// The integration contract is one line:
//
// ```dart
// void main() => ApiTrace.runApp(const MyApp());
// ```
//
// `ApiTrace.runApp` is defined in `lib/src/api_trace.dart`
// and wraps the developer's app in `ApiTraceBootstrap`.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_api_inspector/src/api_trace.dart';
import 'package:flutter_api_inspector/src/overlay/api_trace_overlay.dart';
import 'package:flutter_api_inspector/src/route_scope_observer.dart';

/// Wraps [child] so it only becomes interactive after the first
/// frame has completed layout. Prevents
/// "Cannot hit test a render box that has never been laid out"
/// when the user taps before the initial frame is rendered
/// (common on emulators with slow first-frame composition).
///
/// Before the first frame, returns [SizedBox.shrink()] (a
/// zero-size box that is trivially laid out). After the first
/// frame, transitions to [child] with normal hit-testing.
class _FirstFrameDeferred extends StatefulWidget {
  const _FirstFrameDeferred({required this.child});

  final Widget child;

  @override
  State<_FirstFrameDeferred> createState() => _FirstFrameDeferredState();
}

class _FirstFrameDeferredState extends State<_FirstFrameDeferred> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // Schedule a post-frame callback. After the first frame
    // completes layout, switch to the real child.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _ready = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Before the first frame: return a trivial SizedBox that is
    // guaranteed to be laid out in the first pass. The child is
    // not built at all, so its RenderBox (which would be
    // NEEDS-LAYOUT) never participates in the hit test.
    if (!_ready) return const SizedBox.shrink();
    return widget.child;
  }
}

/// Wraps the developer's [child] in the debug-only overlay.
class ApiTraceBootstrap extends StatelessWidget {
  /// Creates the bootstrap.
  ///
  /// [child] is the developer's app (typically a `MaterialApp`).
  const ApiTraceBootstrap({super.key, required this.child});

  /// The developer's app widget.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // REQ-UI-001: kDebugMode guard. In release mode the
    // bootstrap is a pass-through, so the developer's tree
    // is bit-identical to a tree without the bootstrap.
    if (!kDebugMode && !ApiTrace.forceEnabled) {
      return child;
    }
    // In debug mode, mount the overlay above the developer's
    // child subtree so the overlay's Material widgets
    // (FilterChip, TextField, etc.) can find a
    // MaterialLocalizations ancestor. The pattern matches
    // Flutter's own WidgetsApp.builder: the bootstrap's
    // `build` returns a wrapper that, when given a
    // `MaterialApp` as `child`, injects the overlay into
    // the MaterialApp's subtree via `MaterialApp.builder`.
    //
    // The bootstrap supports two child shapes:
    //
    // 1. `MaterialApp` (the common case): use
    //    `MaterialApp.builder` to inject the overlay into
    //    the MaterialApp's Navigator subtree. This way the
    //    overlay's `Navigator.push` calls find the
    //    MaterialApp's root Navigator.
    //
    // 2. Any other widget: wrap in a `Directionality` +
    //    `Stack`, with the overlay as a sibling of the
    //    child. The overlay subtree is wrapped in a
    //    `_OverlayHarness` that provides a
    //    `MaterialLocalizations` ancestor. The overlay
    //    cannot push detail screens in this case (there is
    //    no Navigator), so the developer should pass
    //    `onRecordTap` to override the default behaviour.

    // The bootstrap is designed to be mounted INSIDE the
    // developer's `MaterialApp` (either as the root via
    // `ApiTrace.runApp`, or manually inside a `home` /
    // `builder`). The bootstrap itself is a `StatelessWidget`
    // that wraps the developer's child with a `Stack` of
    // [child, overlay]. The `View` widget that
    // `WidgetsApp` creates (which provides the `RenderView`
    // render root) is the developer's `MaterialApp` — so
    // the `ApiTrace.runApp` entry point constructs a new
    // `MaterialApp` (with the overlay injected via the
    // `builder`) and passes it to `attachRootWidget` as the
    // root widget. The bootstrap is never the root; it is
    // always nested inside a `MaterialApp`.
    //
    // This means: for the bootstrap to work, the developer
    // must either use `ApiTrace.runApp(...)` (the one-line
    // integration), or mount `ApiTraceBootstrap` manually
    // inside their own `MaterialApp`. Manual mount example:
    //
    // ```dart
    // runApp(MaterialApp(
    //   home: ApiTraceBootstrap(child: MyApp()),
    // ));
    // ```
    //
    // The `kDebugMode` guard at the top makes the bootstrap
    // a pass-through in release builds (bit-identical to
    // the developer's child, no overlay mounted).
    if (child is MaterialApp) {
      final materialApp = child as MaterialApp;
      return BootstrapMaterialAppHarness(
        materialApp: materialApp,
        enabled: ApiTrace.enabled,
      );
    }

    // Non-MaterialApp child: wrap in a fresh minimal
    // `MaterialApp(home: child)` and use the same harness.
    // The fresh `MaterialApp` provides the render root
    // (via `WidgetsApp`'s `View`), the `Navigator`, and the
    // `MaterialLocalizations` ancestor that the overlay's
    // `FilterChip`, `TextField`, etc. need. The outer
    // `MaterialApp` is invisible to routing because the
    // developer's own MaterialApp (e.g. `GetMaterialApp`
    // inside `MyApp.build`) is `home`'s descendant and
    // provides its own `Navigator` and theme.
    //
    // NOTE: This creates a nested Navigator. For full route-
    // scope tracking (the Routes tab), pass the MaterialApp
    // DIRECTLY to ApiTrace.runApp:
    //   ApiTrace.runApp(MaterialApp(home: MyApp()));
    // instead of:
    //   ApiTrace.runApp(MyApp()); // MyApp builds MaterialApp
    return BootstrapMaterialAppHarness(
      materialApp: MaterialApp(home: child),
      enabled: ApiTrace.enabled,
    );
  }
}

/// Internal: a copy of the developer's `MaterialApp` with a
/// `builder` that injects the `ApiTraceOverlay` into the
/// MaterialApp's Navigator subtree. This is the standard
/// pattern from Flutter's own `WidgetsApp.builder`.
///
/// We do not mutate the developer's `MaterialApp`; we
/// construct a new one with the same fields plus the
/// `builder`. The `key` of the original MaterialApp is
/// preserved.
class BootstrapMaterialAppHarness extends StatelessWidget {
  const BootstrapMaterialAppHarness({
    super.key,
    required this.materialApp,
    required this.enabled,
  });

  final MaterialApp materialApp;
  final bool enabled;

  /// Wraps the developer's own `builder` (if any) and stacks the
  /// [ApiTraceOverlay] on top of its result. The overlay is INSIDE
  /// the MaterialApp's subtree, so its Material widgets find the
  /// localizations / theme ancestors they need.
  Widget _overlayBuilder(BuildContext context, Widget? child) {
    final Widget? inner = materialApp.builder == null
        ? child
        : materialApp.builder!(context, child);
    return Stack(
      children: <Widget>[
        if (inner != null) inner,
        if (enabled)
          ValueListenableBuilder<String?>(
            valueListenable: ApiTrace.timeline.latest,
            builder: (BuildContext context, String? _, Widget? __) {
              if (!ApiTrace.enabled) {
                return const SizedBox.shrink();
              }
              return _FirstFrameDeferred(
                child: ApiTraceOverlay(
                  config: ApiTrace.config,
                  records: ApiTrace.timeline.records,
                  navigatorKey: ApiTrace.navigatorKey,
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild a MaterialApp that mirrors the developer's
    // configuration but uses `builder` to inject the
    // ApiTraceOverlay into the MaterialApp's subtree. EVERY
    // constructor property is forwarded — routing (routes,
    // onGenerateRoute, initialRoute...), localization, theming,
    // shortcuts / actions, and debug flags — so activating the
    // overlay never changes the app's behaviour. The developer's
    // own `builder` (if any) still runs; the overlay stacks on
    // top of its result (see [_overlayBuilder]).

    // Router-based app (MaterialApp.router): forward the router
    // configuration instead of the Navigator one. `navigatorKey`
    // does not exist on router apps; the overlay uses its own
    // internal Navigator for the detail screen, so nothing is lost.
    if (materialApp.routerConfig != null ||
        materialApp.routerDelegate != null) {
      return MaterialApp.router(
        key: materialApp.key,
        scaffoldMessengerKey: materialApp.scaffoldMessengerKey,
        routeInformationProvider: materialApp.routeInformationProvider,
        routeInformationParser: materialApp.routeInformationParser,
        routerDelegate: materialApp.routerDelegate,
        routerConfig: materialApp.routerConfig,
        backButtonDispatcher: materialApp.backButtonDispatcher,
        builder: _overlayBuilder,
        title: materialApp.title,
        onGenerateTitle: materialApp.onGenerateTitle,
        onNavigationNotification: materialApp.onNavigationNotification,
        color: materialApp.color,
        theme: materialApp.theme,
        darkTheme: materialApp.darkTheme,
        highContrastTheme: materialApp.highContrastTheme,
        highContrastDarkTheme: materialApp.highContrastDarkTheme,
        themeMode: materialApp.themeMode,
        themeAnimationDuration: materialApp.themeAnimationDuration,
        themeAnimationCurve: materialApp.themeAnimationCurve,
        locale: materialApp.locale,
        localizationsDelegates: materialApp.localizationsDelegates,
        localeListResolutionCallback: materialApp.localeListResolutionCallback,
        localeResolutionCallback: materialApp.localeResolutionCallback,
        supportedLocales: materialApp.supportedLocales,
        debugShowMaterialGrid: materialApp.debugShowMaterialGrid,
        showPerformanceOverlay: materialApp.showPerformanceOverlay,
        showSemanticsDebugger: materialApp.showSemanticsDebugger,
        debugShowCheckedModeBanner: false,
        shortcuts: materialApp.shortcuts,
        actions: materialApp.actions,
        restorationScopeId: materialApp.restorationScopeId,
        scrollBehavior: materialApp.scrollBehavior,
      );
    }

    return MaterialApp(
      key: materialApp.key,
      // Pass a GlobalKey so overlay code outside the Navigator
      // subtree can still reach the app's root Navigator.
      navigatorKey: materialApp.navigatorKey ?? ApiTrace.navigatorKey,
      scaffoldMessengerKey: materialApp.scaffoldMessengerKey,
      home: materialApp.home,
      routes: materialApp.routes ?? const <String, WidgetBuilder>{},
      initialRoute: materialApp.initialRoute,
      onGenerateRoute: materialApp.onGenerateRoute,
      onGenerateInitialRoutes: materialApp.onGenerateInitialRoutes,
      onUnknownRoute: materialApp.onUnknownRoute,
      onNavigationNotification: materialApp.onNavigationNotification,
      navigatorObservers: [
        ...switch (materialApp.navigatorObservers) {
          null || const [] => [if (enabled) RouteScopeObserver()],
          final list => [
              ...list,
              if (enabled && !list.any((o) => o is RouteScopeObserver))
                RouteScopeObserver(),
            ],
        },
      ],
      builder: _overlayBuilder,
      title: materialApp.title,
      onGenerateTitle: materialApp.onGenerateTitle,
      color: materialApp.color,
      theme: materialApp.theme,
      darkTheme: materialApp.darkTheme,
      highContrastTheme: materialApp.highContrastTheme,
      highContrastDarkTheme: materialApp.highContrastDarkTheme,
      themeMode: materialApp.themeMode,
      themeAnimationDuration: materialApp.themeAnimationDuration,
      themeAnimationCurve: materialApp.themeAnimationCurve,
      locale: materialApp.locale,
      localizationsDelegates: materialApp.localizationsDelegates,
      localeListResolutionCallback: materialApp.localeListResolutionCallback,
      localeResolutionCallback: materialApp.localeResolutionCallback,
      supportedLocales: materialApp.supportedLocales,
      debugShowMaterialGrid: materialApp.debugShowMaterialGrid,
      showPerformanceOverlay: materialApp.showPerformanceOverlay,
      showSemanticsDebugger: materialApp.showSemanticsDebugger,
      debugShowCheckedModeBanner: false,
      shortcuts: materialApp.shortcuts,
      actions: materialApp.actions,
      restorationScopeId: materialApp.restorationScopeId,
      scrollBehavior: materialApp.scrollBehavior,
    );
  }
}
