// Strict TDD evidence for TASK-RS-001: RouteScope service +
// RouteScopeEntry model (REQ-RS-001).
//
// `RouteScope` is a singleton that tracks the route stack via
// `onPush` / `onPop` / `onReplace`, called by `RouteScopeObserver`
// (see `route_scope_observer_test.dart` for the NavigatorObserver
// wiring). Each transition creates a `RouteScopeEntry` with a
// monotonically increasing `scopeId`, enabling downstream
// interceptors (Dio, HttpOverrides) to tag HTTP requests with the
// screen that was active at dispatch time.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_api_inspector/src/route_scope.dart';

/// Builds a lightweight [Route] for feeding directly into
/// `RouteScope.onPush` / `onPop` / `onReplace`. `RouteScope` only
/// reads `route.settings.name` and `route.runtimeType`, so a
/// `MaterialPageRoute` that is never mounted in a Navigator is
/// sufficient — no `pumpWidget` needed for these unit tests.
Route<void> _route(String? name) {
  return MaterialPageRoute<void>(
    builder: (_) => const SizedBox.shrink(),
    settings: name != null ? RouteSettings(name: name) : null,
  );
}

void main() {
  setUp(() {
    // Fresh singleton per test: dispose then re-init so `scopeId`
    // starts at 1 and `_entries` / `_stack` are empty. `init()` is
    // safe to call multiple times (guarded by kDebugMode, which is
    // always true under `flutter test`).
    RouteScope.dispose();
    RouteScope.init();
  });

  group('RouteScope.onPush (REQ-RS-001)', () {
    test('push creates a scope entry with scopeId 1 and no parent', () {
      // RED: commenting out the body of `RouteScope.onPush` makes
      // `RouteScope.current` stay null and this assertion fails.
      RouteScope.onPush(_route('A'));
      expect(RouteScope.current, isNotNull);
      expect(RouteScope.current!.scopeId, equals(1));
      expect(RouteScope.current!.routeName, equals('A'));
      expect(RouteScope.current!.parentScopeId, isNull);
    });

    test('push after push creates a child scope (scopeId 2, parent 1)', () {
      RouteScope.onPush(_route('A'));
      RouteScope.onPush(_route('B'));
      expect(RouteScope.current!.scopeId, equals(2));
      expect(RouteScope.current!.parentScopeId, equals(1));
      expect(RouteScope.current!.routeName, equals('B'));
    });

    test(
        'TRIANGULATE: a third push is a grandchild scope '
        '(scopeId 3, parent 2)', () {
      RouteScope.onPush(_route('A'));
      RouteScope.onPush(_route('B'));
      RouteScope.onPush(_route('C'));
      expect(RouteScope.current!.scopeId, equals(3));
      expect(RouteScope.current!.parentScopeId, equals(2));
      expect(RouteScope.current!.routeName, equals('C'));
    });
  });

  group('RouteScope.onPop (REQ-RS-001)', () {
    test('pop restores the parent scope when not returning to root', () {
      RouteScope.onPush(_route('A'));
      RouteScope.onPush(_route('B'));
      RouteScope.onPush(_route('C'));
      RouteScope.onPop(_route('C'));
      expect(RouteScope.current!.scopeId, equals(2));
      expect(RouteScope.current!.routeName, equals('B'));
    });

    test(
        'TRIANGULATE: pop-to-root clears historical children but keeps root '
        '(REQ-RS-012)', () {
      RouteScope.onPush(_route('A'));
      RouteScope.onPush(_route('B'));
      RouteScope.onPop(_route('B'));
      // Stack preserved for HTTP tagging.
      expect(RouteScope.current, isNotNull);
      expect(RouteScope.current!.routeName, equals('A'));
      // Historical child entries are cleared, but the root entry remains
      // so the route tree can build the next flow under home.
      expect(RouteScope.entries.map((e) => e.routeName), equals(<String>['A']));
    });

    test('pop on an empty stack does not crash (edge case)', () {
      // A `didPop` can fire without a matching push (e.g. a route
      // that existed before `RouteScope.init()` ran). Must be a
      // no-op, not a RangeError from `removeLast()` on an empty list.
      expect(() => RouteScope.onPop(_route('ghost')), returnsNormally);
      expect(RouteScope.current, isNull);
    });
  });

  group('RouteScope.onReplace (REQ-RS-001)', () {
    test('replace creates a new scope entry at the current depth', () {
      RouteScope.onPush(_route('A'));
      RouteScope.onPush(_route('B'));
      RouteScope.onReplace(_route('C'));
      expect(RouteScope.current!.scopeId, equals(3));
      expect(RouteScope.current!.routeName, equals('C'));
      expect(RouteScope.current!.parentScopeId, equals(1));
    });

    test(
        'TRIANGULATE: replace at the root (single entry) keeps '
        'parent null', () {
      RouteScope.onPush(_route('A'));
      RouteScope.onReplace(_route('A2'));
      expect(RouteScope.current!.routeName, equals('A2'));
      expect(RouteScope.current!.parentScopeId, isNull);
    });
  });

  group('RouteScope.entries (REQ-RS-001)', () {
    test(
        'entries never shrinks while mid-stack: popped scopes remain '
        'available until returning to root', () {
      RouteScope.onPush(_route('A'));
      RouteScope.onPush(_route('B'));
      RouteScope.onPush(_route('C'));
      RouteScope.onPop(_route('C'));
      // C is popped but entries should still have 3 entries
      expect(RouteScope.entries.length, equals(3));
      expect(
        RouteScope.entries.map((e) => e.routeName),
        equals(<String>['A', 'B', 'C']),
      );
    });

    test('TRIANGULATE: a fresh RouteScope has no entries', () {
      expect(RouteScope.entries, isEmpty);
      expect(RouteScope.current, isNull);
    });

    test(
        'scope IDs remain monotonically increasing after pop-to-root reset '
        '(root entry is preserved)', () {
      RouteScope.onPush(_route('A')); // id 1, entries=[A]
      RouteScope.onPush(_route('B')); // id 2, entries=[A,B]
      RouteScope.onPop(_route('B')); // stack=[A] → entries=[A]
      RouteScope.onReplace(_route('A2')); // id 3, entries=[A,A2]
      RouteScope.onPush(_route('D')); // id 4, entries=[A,A2,D]
      final ids = RouteScope.entries.map((e) => e.scopeId).toList();
      expect(ids, equals(<int>[1, 3, 4]));
      for (var i = 1; i < ids.length; i++) {
        expect(ids[i], greaterThan(ids[i - 1]));
      }
    });
  });

  group('RouteScope route naming fallback (design.md Open Question 2)', () {
    test('unnamed route falls back to route.runtimeType.toString()', () {
      // GIVEN a route with no `RouteSettings.name` (the common
      // case for a `MaterialPageRoute` pushed without a name).
      final route = _route(null);
      RouteScope.onPush(route);
      expect(
          RouteScope.current!.routeName, equals(route.runtimeType.toString()));
      // Locks the concrete fallback shape so a future refactor
      // that stops falling back to runtimeType is caught.
      expect(RouteScope.current!.routeName, contains('MaterialPageRoute'));
    });
  });

  group('RouteScope.dispose', () {
    test('dispose resets current to null and entries to empty', () {
      RouteScope.onPush(_route('A'));
      RouteScope.dispose();
      expect(RouteScope.current, isNull);
      expect(RouteScope.entries, isEmpty);
    });
  });

  group('RouteScope kDebugMode guard (REQ-RS-008)', () {
    test('init() consults kDebugMode before creating the singleton', () {
      // `kReleaseMode`/`kDebugMode` are compile-time constants and
      // cannot be flipped at runtime inside `flutter test` (see
      // `test/overlay_test.dart`'s "Overlay widget absent under
      // kReleaseMode" for the same documented limitation). The
      // in-process contract we CAN verify is that `init()`
      // consults `kDebugMode` before creating the singleton.
      final src = File('lib/src/route_scope.dart').readAsStringSync();
      expect(
        src,
        contains('if (!kDebugMode) return;'),
        reason: 'RouteScope.init() must no-op in release builds '
            '(REQ-RS-008) so route tracking never runs in production.',
      );
    });
  });
}
