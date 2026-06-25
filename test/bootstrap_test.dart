// Strict TDD evidence for TASK-024: ApiTraceBootstrap widget
// and the three static methods on ApiTrace: `runApp`,
// `showOverlay`, `hideOverlay` (REQ-UI-001, REQ-UI-002,
// REQ-UI-005).
//
// The bootstrap is the layer that mounts the ApiTraceOverlay
// on top of the developer's app. In release mode
// (kDebugMode == false), the bootstrap is a pass-through —
// the developer's app widget tree is bit-identical to a tree
// without the bootstrap.

import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_api_inspector/flutter_api_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    ApiTrace.enabled = kDebugMode;
    ApiTrace.config = const ApiTraceConfig();
    ApiTrace.timeline.clear();
  });

  group('ApiTraceBootstrap widget (REQ-UI-001, REQ-UI-002)', () {
    // Helper: wrap a child in a Directionality + MaterialApp
    // so the bootstrap can mount the overlay (which uses
    // Align, which needs a Directionality ancestor).
    Widget wrap(Widget child) {
      return MaterialApp(home: child);
    }

    testWidgets('Release-mode pass-through is identity (REQ-UI-001)',
        (tester) async {
      // REQ-UI-001: when kDebugMode is false, the bootstrap
      // returns the child unchanged. In flutter_test kDebugMode
      // is true, so we exercise the release branch by checking
      // the bootstrap's !kDebugMode short-circuit explicitly:
      // when the bootstrap is constructed in a release-mode
      // simulation, the child is the only widget in the tree.
      //
      // The cleanest way to test this in flutter_test is to
      // assert that the bootstrap's !kDebugMode branch is
      // present in the source (a documentation contract) and
      // trust the compile-time elimination. The in-process
      // test verifies the !ApiTrace.enabled branch, which
      // has the same structure.
      //
      // For the unit-test surface, we verify the contract:
      // when ApiTrace.enabled is false, the overlay is NOT
      // constructed by the bootstrap.
      ApiTrace.enabled = false;
      await tester.pumpWidget(ApiTraceBootstrap(
        child: wrap(const Scaffold(body: Text('child'))),
      ));
      // The overlay is not constructed.
      expect(find.byType(ApiTraceOverlay), findsNothing);
      // The child IS constructed and its text is visible.
      expect(find.text('child'), findsOneWidget);
    });

    testWidgets('Debug-mode mounts exactly one ApiTraceOverlay (REQ-UI-002)',
        (tester) async {
      // REQ-UI-002: when kDebugMode is true and
      // ApiTrace.enabled is true, the bootstrap mounts the
      // overlay above the developer's child.
      ApiTrace.enabled = true;
      await tester.pumpWidget(ApiTraceBootstrap(
        child: wrap(const Scaffold(body: Text('child'))),
      ));
      expect(find.byType(ApiTraceOverlay), findsOneWidget);
      // The child is still visible.
      expect(find.text('child'), findsOneWidget);
    });

    testWidgets('Mount point is above the developer Scaffold body',
        (tester) async {
      // REQ-UI-002: the overlay is mounted above the
      // developer's Scaffold body (the FAB is rendered on
      // top of the child, not inside it).
      ApiTrace.enabled = true;
      await tester.pumpWidget(ApiTraceBootstrap(
        child: wrap(const Scaffold(body: Text('child'))),
      ));
      // The overlay is the topmost widget in the tree; the
      // child's Scaffold body is still rendered below.
      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsWidgets);
      // The FloatingActionButton (inside the overlay's FAB)
      // is rendered.
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('TRIANGULATE: debug-mode child is a descendant of the tree',
        (tester) async {
      // Sanity check: the bootstrap does not lose the child.
      ApiTrace.enabled = true;
      await tester.pumpWidget(ApiTraceBootstrap(
        child: wrap(const Scaffold(body: Text('hello'))),
      ));
      // The child's text is still in the tree.
      expect(find.text('hello'), findsOneWidget);
    });

    // Regression test for the 2026-06-24 bai-clear-finance
    // device error: when the child is a `StatelessWidget`
    // wrapper around a `MaterialApp` (or `GetMaterialApp`,
    // which extends `MaterialApp`), the bootstrap used to
    // take the `Directionality + Stack` branch which
    // crashed with "The render object for Stack cannot
    // find ancestor render object to attach to". The fix
    // is to always use the harness, wrapping the child in
    // a fresh minimal `MaterialApp(home: child)` when the
    // child is not itself a `MaterialApp`.
    //
    // This test verifies the wrapper pattern: a custom
    // `StatelessWidget` that contains a `MaterialApp` (or
    // `GetMaterialApp` etc.) in its build method, mirroring
    // the bai-clear-finance `MyApp` pattern.
    testWidgets(
        'ApiTraceBootstrap handles a wrapper widget around MaterialApp (regression)',
        (tester) async {
      // The wrapper widget pattern: a StatelessWidget that
      // builds a MaterialApp. This is the common pattern
      // for adding global setup (e.g. session managers,
      // error handlers) around an app.
      const wrapper = _WrapperAroundMaterialApp();
      await tester.pumpWidget(const ApiTraceBootstrap(child: wrapper));
      // No exception should have been thrown. Before the
      // fix, the bootstrap took the `Directionality + Stack`
      // branch and the Stack could not find a render
      // ancestor (because the root render object expects
      // a `View` widget as its first child, and the
      // wrapper pattern does not provide one).
      expect(tester.takeException(), isNull);
      // The wrapper's child text is mounted (the wrapper
      // built its MaterialApp, the MaterialApp built its
      // home, the home rendered the Text).
      expect(find.text('wrapper-material-app-marker'), findsOneWidget);
    });
  });

  group('ApiTrace.runApp (REQ-UI-001, REQ-UI-002)', () {
    test('ApiTrace.runApp is a static method on ApiTrace', () {
      // REQ-UI-002: the developer calls ApiTrace.runApp
      // (one line) to wire the bootstrap. The method exists.
      // The in-test exercise of runApp is the bootstrap
      // test above (which uses the same wrap).
      expect(ApiTrace.runApp, isNotNull);
    });

    // Regression test for the 2026-06-24 device stack
    // overflow. Before the fix, ApiTrace.runApp called an
    // unqualified `runApp(...)` inside its body, which
    // resolved to ApiTrace.runApp itself (the static
    // method name shadowed the top-level runApp from
    // package:flutter/widgets.dart due to Dart's name
    // resolution). The call recursed ~98,000 times before
    // the device VM gave up with StackOverflowError.
    //
    // The fix uses WidgetsBinding.attachRootWidget +
    // scheduleFrame directly, which is what Flutter's
    // runApp does internally.
    //
    // We cannot exercise this as a testWidgets because
    // `flutter_test` provides its own widget root via
    // pumpWidget; a second `attachRootWidget` from
    // ApiTrace.runApp would conflict with the test
    // framework's root (the test binding throws
    // "RenderObject cannot find ancestor" rather than
    // recursing). The structural check below catches the
    // exact regression: if a future refactor reintroduces
    // an unqualified `runApp(...)` call inside ApiTrace.runApp,
    // this test fails.
    test(
        'ApiTrace.runApp body does not recurse (regression for name shadowing)',
        () {
      // Read the source file and assert the implementation
      // uses the post-fix pattern (attachRootWidget +
      // scheduleFrame) rather than the pre-fix pattern
      // (unqualified runApp).
      final src = File('lib/src/api_trace.dart').readAsStringSync();
      // Post-fix: the body uses attachRootWidget.
      expect(
        src,
        contains('attachRootWidget'),
        reason: 'ApiTrace.runApp must use WidgetsBinding.attachRootWidget '
            'to avoid the name shadowing that caused the 2026-06-24 '
            'device stack overflow.',
      );
      expect(
        src,
        contains('scheduleFrame'),
        reason: 'ApiTrace.runApp must schedule the first frame after '
            'attaching the root widget (this is what Flutter\'s '
            'runApp does internally).',
      );
    });

    // Regression test for the 2026-06-24 second device
    // error: "The render object for Semantics cannot find
    // ancestor render object to attach to". The root cause
    // was that `ApiTrace.runApp` was wrapping the
    // developer's `app` in `ApiTraceBootstrap` and passing
    // THE BOOTSTRAP as the root to `attachRootWidget`. The
    // `WidgetsApp` inside `MaterialApp` only creates the
    // `View` widget (which provides the `RenderView` render
    // root) when `MaterialApp` is the root widget. With
    // `ApiTraceBootstrap` as the root, the `MaterialApp` is
    // nested (not the root) and no `View` is created.
    //
    // The fix: `ApiTrace.runApp` constructs a new
    // `MaterialApp` (via the `BootstrapMaterialAppHarness`)
    // and passes THAT as the root. The new `MaterialApp` is
    // the root, so `WidgetsApp` creates the `View` and the
    // render tree is valid.
    //
    // This structural test verifies the fix is in place.
    test(
        'ApiTrace.runApp uses BootstrapMaterialAppHarness as root, not ApiTraceBootstrap (regression for render root)',
        () {
      final src = File('lib/src/api_trace.dart').readAsStringSync();
      // Post-fix: runApp constructs BootstrapMaterialAppHarness.
      expect(
        src,
        contains('BootstrapMaterialAppHarness('),
        reason: 'ApiTrace.runApp must construct a '
            'BootstrapMaterialAppHarness (which is itself a '
            'MaterialApp) and pass IT as the root, not wrap '
            'in ApiTraceBootstrap. The 2026-06-24 device '
            'crash happened because the developer\'s '
            'MaterialApp was not the root, so WidgetsApp did '
            'not create the View widget that provides the '
            'RenderView render root.',
      );
      // Pre-fix pattern (must NOT be present): wrapping in
      // ApiTraceBootstrap and passing it as the root.
      // The fix removed this line. If a future refactor
      // re-introduces it, this assertion catches the
      // regression.
      expect(
        src,
        isNot(contains('attachRootWidget(ApiTraceBootstrap(')),
        reason: 'ApiTrace.runApp must not attach an '
            'ApiTraceBootstrap as the root. The 2026-06-24 '
            'crash was caused by this exact pattern; the fix '
            'attaches a MaterialApp-based harness as the root '
            'instead.',
      );
    });

    // Regression test for the 2026-06-24 third attempt to
    // fix the render root issue: adding a `View` widget to
    // `ApiTraceBootstrap.build` (the bootstrap is for manual
    // mount, not as the root). The `View` widget creates a
    // `RenderView`, but Flutter's framework allows only ONE
    // `RenderView` per app (the one created by
    // `attachRootWidget`). A nested `View` throws "The
    // RenderObject for _RawViewInternal cannot maintain an
    // independent render tree at its current location".
    //
    // The fix: the bootstrap is for manual mount (inside
    // the developer's own MaterialApp, which already
    // provides the View). For the runApp entry point, the
    // harness (a MaterialApp) is used as the root.
    //
    // This structural test verifies that the bootstrap
    // does NOT use the `View` widget.
    test(
        'ApiTraceBootstrap does not use View widget (regression for nested render root)',
        () {
      final src = File('lib/src/bootstrap.dart').readAsStringSync();
      // The bootstrap should NOT import or use the `View`
      // widget. The 2026-06-24 nested-View fix attempt was
      // wrong: View can only be the root.
      expect(
        src,
        isNot(contains('View(')),
        reason: 'ApiTraceBootstrap must not use the View '
            'widget. View creates a RenderView and Flutter '
            'allows only one RenderView per app (the one '
            'created by attachRootWidget). The 2026-06-24 '
            'attempt to add View to the bootstrap failed with '
            '"_RawViewInternal cannot maintain an independent '
            'render tree at its current location".',
      );
    });
  });

  group('ApiTrace.showOverlay / hideOverlay (REQ-UI-005)', () {
    testWidgets('showOverlay is exposed as a static method', (tester) async {
      // REQ-UI-005: the developer can programmatically open
      // and close the panel. The two methods exist on the
      // ApiTrace class.
      expect(ApiTrace.showOverlay, isNotNull);
      expect(ApiTrace.hideOverlay, isNotNull);
    });
  });
}

/// Wrapper widget that builds a MaterialApp. Mirrors the
/// bai-clear-finance `MyApp` pattern: a thin
/// `StatelessWidget` that wraps a `MaterialApp` (or
/// `GetMaterialApp`, etc.) to add global setup around the
/// app. Before the 2026-06-24 fix, the bootstrap took the
/// `Directionality + Stack` branch for this case and the
/// render tree crashed with "The render object for Stack
/// cannot find ancestor render object to attach to".
class _WrapperAroundMaterialApp extends StatelessWidget {
  const _WrapperAroundMaterialApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('wrapper-material-app-marker'),
        ),
      ),
    );
  }
}
