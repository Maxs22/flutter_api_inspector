// Strict TDD evidence for TASK-013: ApiTraceConfig +
// ApiTraceOverlayPosition + ApiTraceOverlayLabel (REQ-API-003,
// REQ-API-004).
//
// The three public symbols in `lib/src/config.dart` are:
// - `ApiTraceOverlayPosition` (4 values: bottomRight default,
//   bottomLeft, topRight, topLeft).
// - `ApiTraceOverlayLabel` (3 values: icon default, badge, chip).
// - `ApiTraceConfig` (immutable; `const` constructor; the five
//   locked defaults from the proposal Q2/Q3/Q5).
//
// REQ-API-003: configurable overlay position and label.
// REQ-API-004: default detail set is minimal only (the other
//   three config defaults — timelineCapacity 200,
//   maxResponseBodyBytes 4 KB, overlay position/label — are
//   asserted by the same `ApiTraceConfig()` test).

import 'package:flutter_api_inspector/src/config.dart';
import 'package:flutter_api_inspector/src/detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiTraceOverlayPosition (REQ-API-003)', () {
    test('has exactly four values', () {
      // RED: import target missing. After GREEN, the assertion holds.
      expect(ApiTraceOverlayPosition.values, hasLength(4));
    });

    test('values are bottomRight, bottomLeft, topRight, topLeft (in order)',
        () {
      // Locks the enum ordering so a future addition does not
      // silently break `ApiTraceConfig.overlayPosition` defaulting.
      expect(ApiTraceOverlayPosition.values, <ApiTraceOverlayPosition>[
        ApiTraceOverlayPosition.bottomRight,
        ApiTraceOverlayPosition.bottomLeft,
        ApiTraceOverlayPosition.topRight,
        ApiTraceOverlayPosition.topLeft,
      ]);
    });

    test('bottomRight is at index 0', () {
      expect(ApiTraceOverlayPosition.bottomRight.index, 0);
    });
  });

  group('ApiTraceOverlayLabel (REQ-API-003)', () {
    test('has exactly three values', () {
      expect(ApiTraceOverlayLabel.values, hasLength(3));
    });

    test('values are icon, badge, chip (in order)', () {
      expect(ApiTraceOverlayLabel.values, <ApiTraceOverlayLabel>[
        ApiTraceOverlayLabel.icon,
        ApiTraceOverlayLabel.badge,
        ApiTraceOverlayLabel.chip,
      ]);
    });

    test('icon is at index 0', () {
      expect(ApiTraceOverlayLabel.icon.index, 0);
    });
  });

  group('ApiTraceConfig defaults (REQ-API-004)', () {
    test('default details is {ApiTraceDetail.minimal} only', () {
      // Privacy-conscious default: no body, no headers.
      const c = ApiTraceConfig();
      expect(c.details, equals(<ApiTraceDetail>{ApiTraceDetail.minimal}));
    });

    test('default timelineCapacity is 200', () {
      // Per proposal Q2: ring buffer default size.
      const c = ApiTraceConfig();
      expect(c.timelineCapacity, 200);
    });

    test('default maxResponseBodyBytes is 4096 (4 KB)', () {
      // Per proposal Q5: response body capture size limit.
      const c = ApiTraceConfig();
      expect(c.maxResponseBodyBytes, 4 * 1024);
    });

    test('default overlayPosition is bottomRight', () {
      // Per proposal Q3: FAB position.
      const c = ApiTraceConfig();
      expect(c.overlayPosition, ApiTraceOverlayPosition.bottomRight);
    });

    test('default overlayLabel is icon', () {
      // Per proposal Q3: FAB label shape (icon-only by default).
      const c = ApiTraceConfig();
      expect(c.overlayLabel, ApiTraceOverlayLabel.icon);
    });
  });

  group('ApiTraceConfig — constructor overrides', () {
    test('all fields can be overridden at construction time', () {
      const c = ApiTraceConfig(
        details: <ApiTraceDetail>{ApiTraceDetail.minimal, ApiTraceDetail.full},
        maxResponseBodyBytes: 128,
        timelineCapacity: 5,
        overlayPosition: ApiTraceOverlayPosition.topLeft,
        overlayLabel: ApiTraceOverlayLabel.chip,
      );
      expect(
          c.details,
          equals(
              <ApiTraceDetail>{ApiTraceDetail.minimal, ApiTraceDetail.full}));
      expect(c.maxResponseBodyBytes, 128);
      expect(c.timelineCapacity, 5);
      expect(c.overlayPosition, ApiTraceOverlayPosition.topLeft);
      expect(c.overlayLabel, ApiTraceOverlayLabel.chip);
    });

    test('fields are final (immutable)', () {
      // Compile-time check: the analyzer rejects any reassignment
      // of a `final` field. This test pins the immutability
      // contract that design.md and the spec require.
      const c = ApiTraceConfig();
      expect(c, isNotNull);
    });

    test('default config is a compile-time const', () {
      // Asserts that `const ApiTraceConfig()` is a valid
      // compile-time constant (the package's recommended pattern
      // for the default).
      const c1 = ApiTraceConfig();
      const c2 = ApiTraceConfig();
      expect(identical(c1, c2), isTrue,
          reason: 'const constructor must canonicalise to one instance');
    });
  });
}
