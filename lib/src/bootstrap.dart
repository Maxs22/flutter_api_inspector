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

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_api_inspector/src/api_trace.dart';
import 'package:flutter_api_inspector/src/overlay/api_trace_overlay.dart';

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
    if (!kDebugMode) {
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

    if (child is MaterialApp) {
      final materialApp = child as MaterialApp;
      return _BootstrapMaterialAppHarness(
        materialApp: materialApp,
        enabled: ApiTrace.enabled,
      );
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: <Widget>[
          child,
          ValueListenableBuilder<String?>(
            valueListenable: ApiTrace.timeline.latest,
            builder: (BuildContext context, String? _, Widget? __) {
              if (!ApiTrace.enabled) {
                return const SizedBox.shrink();
              }
              return _OverlayHarness(
                child: ApiTraceOverlay(
                  config: ApiTrace.config,
                  records: ApiTrace.timeline.records,
                  navigatorKey: ApiTrace.navigatorKey,
                ),
              );
            },
          ),
        ],
      ),
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
class _BootstrapMaterialAppHarness extends StatelessWidget {
  const _BootstrapMaterialAppHarness({
    required this.materialApp,
    required this.enabled,
  });

  final MaterialApp materialApp;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Rebuild a MaterialApp that mirrors the developer's
    // configuration but uses `builder` to inject the
    // ApiTraceOverlay into the MaterialApp's Navigator
    // subtree. We only forward the fields that are
    // commonly used; for the rare cases not covered
    // (e.g. custom routes / navigatorKey), the developer
    // is expected to use `ApiTrace.runApp` instead of
    // mounting the bootstrap manually.
    return MaterialApp(
      key: materialApp.key,
      // Pass a GlobalKey so the ApiTraceOverlay (mounted as a
      // sibling of the child in the builder below) can push
      // routes into the MaterialApp's Navigator even though
      // Navigator.of(overlayContext) would fail (the overlay
      // is outside the Navigator subtree).
      navigatorKey: materialApp.navigatorKey ?? ApiTrace.navigatorKey,
      home: materialApp.home,
      title: materialApp.title,
      theme: materialApp.theme,
      darkTheme: materialApp.darkTheme,
      themeMode: materialApp.themeMode,
      color: materialApp.color,
      builder: (BuildContext context, Widget? child) {
        // The child's tree is the MaterialApp's content;
        // we wrap it in a Stack with the overlay on top.
        // The overlay is INSIDE the MaterialApp's Navigator
        // subtree, so `Navigator.of(context)` finds the
        // MaterialApp's root Navigator when pushing the
        // detail screen.
        return Stack(
          children: <Widget>[
            if (child != null) child,
            if (enabled)
              ValueListenableBuilder<String?>(
                valueListenable: ApiTrace.timeline.latest,
                builder: (BuildContext context, String? _, Widget? __) {
                  if (!ApiTrace.enabled) {
                    return const SizedBox.shrink();
                  }
                  return ApiTraceOverlay(
                    config: ApiTrace.config,
                    records: ApiTrace.timeline.records,
                    navigatorKey: ApiTrace.navigatorKey,
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

/// Wraps the overlay subtree in a `Material` + `Localizations`
/// harness so the overlay's Material widgets (FilterChip,
/// TextField, etc.) can find a `MaterialLocalizations`
/// ancestor even when the developer's child does not provide
/// one (e.g. a bare `Scaffold` in a test).
class _OverlayHarness extends StatelessWidget {
  const _OverlayHarness({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Localizations(
        locale: const Locale('en', 'US'),
        delegates: const <LocalizationsDelegate<dynamic>>[
          DefaultMaterialLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: child,
      ),
    );
  }
}
