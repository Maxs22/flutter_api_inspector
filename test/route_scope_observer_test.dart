// Strict TDD evidence for TASK-RS-002: RouteScopeObserver
// (NavigatorObserver) (REQ-RS-001, REQ-RS-002).
//
// `RouteScopeObserver` is a `NavigatorObserver` that forwards
// `didPush` / `didPop` / `didReplace` callbacks into `RouteScope`.
// It is auto-injected by `BootstrapMaterialAppHarness` (see
// `test/bootstrap_test.dart` for the harness wiring); these tests
// exercise the observer directly against a real `Navigator` so the
// NavigatorObserver contract itself is proven, independent of the
// bootstrap.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_api_inspector/src/route_scope.dart';
import 'package:flutter_api_inspector/src/route_scope_observer.dart';

void main() {
  setUp(() {
    RouteScope.dispose();
    RouteScope.init();
  });

  /// Pumps a `MaterialApp` with `RouteScopeObserver` attached to its
  /// Navigator. The `home` route itself triggers one `didPush`
  /// (the initial route), so tests account for that baseline.
  Widget harness(GlobalKey<NavigatorState> navKey) {
    return MaterialApp(
      navigatorKey: navKey,
      navigatorObservers: <NavigatorObserver>[RouteScopeObserver()],
      home: const Scaffold(body: Text('home')),
    );
  }

  group('RouteScopeObserver.didPush (REQ-RS-002)', () {
    testWidgets('mounting the app tags RouteScope with the initial route',
        (tester) async {
      // RED: with didPush not forwarding to RouteScope.onPush, this
      // stays null.
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(harness(navKey));
      expect(RouteScope.current, isNotNull);
      expect(RouteScope.current!.scopeId, equals(1));
    });

    testWidgets('pushing a named route tags RouteScope.current with that name',
        (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(harness(navKey));
      final initialScopeId = RouteScope.current!.scopeId;

      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'Detail'),
        builder: (_) => const Scaffold(body: Text('detail')),
      )));
      await tester.pumpAndSettle();

      expect(RouteScope.current!.routeName, equals('Detail'));
      expect(RouteScope.current!.parentScopeId, equals(initialScopeId));
    });
  });

  group('RouteScopeObserver.didPop (REQ-RS-002)', () {
    testWidgets('popping a route restores the previous scope', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(harness(navKey));
      // Stack: [Home]
      final rootScopeId = RouteScope.current!.scopeId;

      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'A'),
        builder: (_) => const Scaffold(body: Text('a')),
      )));
      await tester.pumpAndSettle();
      // Stack: [Home, A]
      final scopeAId = RouteScope.current!.scopeId;

      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'B'),
        builder: (_) => const Scaffold(body: Text('b')),
      )));
      await tester.pumpAndSettle();
      expect(RouteScope.current!.routeName, equals('B'));

      // Pop B → back to A (stack size 2, no reset)
      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(RouteScope.current!.scopeId, equals(scopeAId));

      // Pop A → back to root → triggers reset (REQ-RS-012)
      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      // Stack preserved for HTTP tagging
      expect(RouteScope.current, isNotNull,
          reason: 'root entry preserved after reset');
      expect(RouteScope.current!.scopeId, equals(rootScopeId));
      // Historical entries cleared (only root remains)
      expect(RouteScope.entries.length, equals(1));
    });

    testWidgets(
        'REQ-RS-012: popping back to root clears historical entries '
        '(Reset al volver a home)', (tester) async {
      RouteScope.dispose();
      RouteScope.init();
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(harness(navKey));
      // After initial push: entries = [Home], stack = [Home]
      expect(RouteScope.entries.length, equals(1));
      expect(RouteScope.current, isNotNull);

      // Push Detail: entries = [Home, Detail], stack = [Home, Detail]
      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'Detail'),
        builder: (_) => const Scaffold(body: Text('detail')),
      )));
      await tester.pumpAndSettle();
      expect(RouteScope.entries.length, equals(2));

      // Push Another: entries = [Home, Detail, Another]
      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'Another'),
        builder: (_) => const Scaffold(body: Text('another')),
      )));
      await tester.pumpAndSettle();
      expect(RouteScope.entries.length, equals(3));

      // Pop Another → stack = [Home, Detail], entries still 3
      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(RouteScope.entries.length, equals(3));

      // Pop Detail → stack = [Home] (size 1) → RESET
      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      // Stack preserved: current is still the root route
      expect(RouteScope.current, isNotNull,
          reason: 'root stack entry preserved for HTTP tagging');
      expect(RouteScope.entries.length, equals(1),
          reason:
              'historical child entries are cleared after returning to root');

      // New push is a child of the root (fresh flow)
      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'NewScreen'),
        builder: (_) => const Scaffold(body: Text('new')),
      )));
      await tester.pumpAndSettle();
      expect(RouteScope.entries.length, equals(2));
      // The root entry (preserved from before reset) + NewScreen
    });
  });

  group('RouteScopeObserver.didReplace (REQ-RS-002)', () {
    testWidgets(
        'replacing the top route tags RouteScope.current with the '
        'replacement', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(harness(navKey));

      unawaited(navKey.currentState!.push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'B'),
        builder: (_) => const Scaffold(body: Text('b')),
      )));
      await tester.pumpAndSettle();
      final beforeReplaceId = RouteScope.current!.scopeId;

      unawaited(navKey.currentState!.pushReplacement(MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'C'),
        builder: (_) => const Scaffold(body: Text('c')),
      )));
      await tester.pumpAndSettle();

      expect(RouteScope.current!.routeName, equals('C'));
      expect(RouteScope.current!.scopeId, isNot(equals(beforeReplaceId)));
    });
  });

  group('RouteScopeObserver — nested navigators (design.md Open Question 3)',
      () {
    testWidgets(
        'TRIANGULATE: an inner (unobserved) Navigator push does not '
        'affect RouteScope — v1 tracks only the primary navigator',
        (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      final innerNavKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        navigatorObservers: <NavigatorObserver>[RouteScopeObserver()],
        home: Scaffold(
          body: Navigator(
            key: innerNavKey,
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (_) => const Text('inner-home'),
            ),
          ),
        ),
      ));
      final beforeScopeId = RouteScope.current?.scopeId;

      unawaited(innerNavKey.currentState!.push(MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'InnerDetail'),
        builder: (_) => const Text('inner-detail'),
      )));
      await tester.pumpAndSettle();

      // The primary navigator's scope is unaffected: the inner
      // Navigator has no RouteScopeObserver attached (matches
      // design.md's v1 scope: "Nested Navigator tracking is v2").
      expect(RouteScope.current?.scopeId, equals(beforeScopeId));
      expect(
        RouteScope.entries.any((e) => e.routeName == 'InnerDetail'),
        isFalse,
      );
    });
  });
}
