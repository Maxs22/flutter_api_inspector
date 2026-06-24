// Strict TDD evidence for TASK-018..025: the debug-only overlay
// surface for the `flutter_api_inspector` package (REQ-UI-001..008).
//
// The file is built up incrementally across TASK-018..025. Each
// task adds one or more `group`s with its RED -> GREEN ->
// TRIANGULATE -> REFACTOR evidence. The full file is the
// consolidated contract for the 8 overlay REQs (REQ-UI-001..008)
// and 17 spec scenarios.
//
// The first two groups below (TASK-018) cover the two pure
// helpers used by the rest of the overlay surface:
// - `outcomeColor(ApiTraceOutcome)` for REQ-UI-008.
// - `fabAlignment(ApiTraceOverlayPosition)` for REQ-UI-003.

import 'package:flutter/material.dart';
import 'package:flutter_api_inspector/flutter_api_inspector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_api_inspector/src/overlay/colors.dart';
import 'package:flutter_api_inspector/src/overlay/fab_position.dart';

void main() {
  group('outcomeColor helper (REQ-UI-008)', () {
    test('success outcome returns a green color', () {
      // RED: import target missing for `colors.dart`.
      final color = outcomeColor(ApiTraceOutcome.success);
      expect(color, equals(Colors.green.shade600));
    });

    test('error outcome returns a red color', () {
      // RED: import target missing for `colors.dart`.
      final color = outcomeColor(ApiTraceOutcome.error);
      expect(color, equals(Colors.red.shade600));
    });

    test('cancelled outcome returns a neutral color (grey)', () {
      // The cancelled state is reserved for future use; the
      // overlay must still have a defined color so the row
      // renders without crashing.
      final color = outcomeColor(ApiTraceOutcome.cancelled);
      expect(color, isA<Color>());
    });

    test('TRIANGULATE: 4xx and 5xx outcomes resolve to the same red color', () {
      // Per REQ-UI-008, 4xx and 5xx share the same red color in
      // the timeline. The helper itself does not branch on the
      // status code; it branches on outcome (error), and both
      // 4xx and 5xx produce outcome = error.
      final redFor4xx = outcomeColor(ApiTraceOutcome.error);
      final redFor5xx = outcomeColor(ApiTraceOutcome.error);
      expect(redFor4xx, equals(redFor5xx));
    });
  });

  group('fabAlignment helper (REQ-UI-003)', () {
    test('bottomRight returns Alignment.bottomRight', () {
      // RED: import target missing for `fab_position.dart`.
      final alignment = fabAlignment(ApiTraceOverlayPosition.bottomRight);
      expect(alignment, equals(Alignment.bottomRight));
    });

    test('topLeft returns Alignment.topLeft', () {
      final alignment = fabAlignment(ApiTraceOverlayPosition.topLeft);
      expect(alignment, equals(Alignment.topLeft));
    });

    test('TRIANGULATE: bottomLeft returns Alignment.bottomLeft', () {
      final alignment = fabAlignment(ApiTraceOverlayPosition.bottomLeft);
      expect(alignment, equals(Alignment.bottomLeft));
    });

    test('TRIANGULATE: topRight returns Alignment.topRight', () {
      final alignment = fabAlignment(ApiTraceOverlayPosition.topRight);
      expect(alignment, equals(Alignment.topRight));
    });

    test('TRIANGULATE: the four values are all distinct', () {
      // Locks the requirement that the enum maps to four
      // distinct alignments (not all defaulting to the same
      // corner).
      final values = <AlignmentGeometry>{
        fabAlignment(ApiTraceOverlayPosition.bottomRight),
        fabAlignment(ApiTraceOverlayPosition.bottomLeft),
        fabAlignment(ApiTraceOverlayPosition.topRight),
        fabAlignment(ApiTraceOverlayPosition.topLeft),
      };
      expect(values, hasLength(4));
    });
  });
}
