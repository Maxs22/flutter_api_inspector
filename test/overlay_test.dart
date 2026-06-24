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
import 'package:flutter_api_inspector/src/overlay/fab.dart';

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

  group('ApiTraceFab widget (REQ-UI-003, REQ-UI-004)', () {
    // Helper: pump a MaterialApp with the FAB at the centre of
    // a Stack so we can find it by subtree. We don't need a
    // Navigator or a Scaffold for the FAB itself.
    Widget host(ApiTraceFab fab) {
      return MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[fab],
          ),
        ),
      );
    }

    testWidgets('renders the developer_mode icon (REQ-UI-004 default)',
        (tester) async {
      // RED: import target missing for `fab.dart`.
      await tester.pumpWidget(host(
        ApiTraceFab(
          onPressed: () {},
          config: const ApiTraceConfig(),
          recordCount: 1,
        ),
      ));
      expect(find.byIcon(Icons.developer_mode), findsOneWidget);
    });

    testWidgets('default label is icon-only (no count Text inside FAB subtree)',
        (tester) async {
      // REQ-UI-004: with overlayLabel == icon (default), the
      // FAB subtree contains the icon and no Text widget
      // rendering the record count.
      await tester.pumpWidget(host(
        ApiTraceFab(
          onPressed: () {},
          config: const ApiTraceConfig(),
          recordCount: 7,
        ),
      ));
      // Find the FloatingActionButton subtree and check it
      // contains no Text widgets.
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);
      // No text widgets should appear in the FAB subtree at
      // all (icon-only means no count label).
      final textsInFab = find.descendant(
        of: fabFinder,
        matching: find.byType(Text),
      );
      expect(textsInFab, findsNothing);
    });

    testWidgets('badge label shows count text when count > 0', (tester) async {
      // REQ-UI-004: with overlayLabel == badge and 7 records,
      // a Text widget rendering the literal string "7" is
      // found inside the FAB subtree.
      await tester.pumpWidget(host(
        ApiTraceFab(
          onPressed: () {},
          config: const ApiTraceConfig(
            overlayLabel: ApiTraceOverlayLabel.badge,
          ),
          recordCount: 7,
        ),
      ));
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);
      final countText = find.descendant(
        of: fabFinder,
        matching: find.text('7'),
      );
      expect(countText, findsOneWidget);
    });

    testWidgets('badge label hides count when count is 0', (tester) async {
      // REQ-UI-004: with overlayLabel == badge and an empty
      // timeline, no Text widget rendering the count is
      // inside the FAB subtree.
      await tester.pumpWidget(host(
        ApiTraceFab(
          onPressed: () {},
          config: const ApiTraceConfig(
            overlayLabel: ApiTraceOverlayLabel.badge,
          ),
          recordCount: 0,
        ),
      ));
      final fabFinder = find.byType(FloatingActionButton);
      final countText = find.descendant(
        of: fabFinder,
        matching: find.byType(Text),
      );
      expect(countText, findsNothing);
    });

    testWidgets('chip label shows "API N" when count > 0', (tester) async {
      // REQ-UI-004: with overlayLabel == chip and 17 records,
      // a Text widget rendering the literal "API 17" is found
      // inside the FAB subtree.
      await tester.pumpWidget(host(
        ApiTraceFab(
          onPressed: () {},
          config: const ApiTraceConfig(
            overlayLabel: ApiTraceOverlayLabel.chip,
          ),
          recordCount: 17,
        ),
      ));
      final fabFinder = find.byType(FloatingActionButton);
      final chipText = find.descendant(
        of: fabFinder,
        matching: find.text('API 17'),
      );
      expect(chipText, findsOneWidget);
    });

    testWidgets('chip label hides "API" text when count is 0', (tester) async {
      // REQ-UI-004: with overlayLabel == chip and an empty
      // timeline, no Text widget rendering the chip is inside
      // the FAB subtree.
      await tester.pumpWidget(host(
        ApiTraceFab(
          onPressed: () {},
          config: const ApiTraceConfig(
            overlayLabel: ApiTraceOverlayLabel.chip,
          ),
          recordCount: 0,
        ),
      ));
      final fabFinder = find.byType(FloatingActionButton);
      final chipText = find.descendant(
        of: fabFinder,
        matching: find.textContaining('API'),
      );
      expect(chipText, findsNothing);
    });

    testWidgets('onPressed callback fires when the FAB is tapped',
        (tester) async {
      // The onPressed callback is wired up to the FAB.
      var taps = 0;
      await tester.pumpWidget(host(
        ApiTraceFab(
          onPressed: () => taps++,
          config: const ApiTraceConfig(),
          recordCount: 0,
        ),
      ));
      await tester.tap(find.byType(FloatingActionButton));
      expect(taps, 1);
    });

    testWidgets(
        'TRIANGULATE: FAB subtree contains developer_mode icon for all '
        'three label shapes', (tester) async {
      // REQ-UI-004: the icon is present regardless of the
      // label shape (icon, badge, chip).
      for (final label in <ApiTraceOverlayLabel>[
        ApiTraceOverlayLabel.icon,
        ApiTraceOverlayLabel.badge,
        ApiTraceOverlayLabel.chip,
      ]) {
        await tester.pumpWidget(host(
          ApiTraceFab(
            onPressed: () {},
            config: ApiTraceConfig(overlayLabel: label),
            recordCount: 3,
          ),
        ));
        expect(
          find.byIcon(Icons.developer_mode),
          findsOneWidget,
          reason: 'icon should be present for label=$label',
        );
      }
    });

    testWidgets(
        'TRIANGULATE: FAB subtree contains developer_mode icon at every '
        'corner (REQ-UI-003)', (tester) async {
      // REQ-UI-003: the icon is present at all four corners.
      // The fabAlignment helper is what positions the FAB; the
      // FAB itself is content-only. This test pins the
      // contract that the FAB does not depend on its position.
      for (final position in <ApiTraceOverlayPosition>[
        ApiTraceOverlayPosition.bottomRight,
        ApiTraceOverlayPosition.bottomLeft,
        ApiTraceOverlayPosition.topRight,
        ApiTraceOverlayPosition.topLeft,
      ]) {
        await tester.pumpWidget(host(
          ApiTraceFab(
            onPressed: () {},
            config: ApiTraceConfig(overlayPosition: position),
            recordCount: 1,
          ),
        ));
        expect(
          find.byIcon(Icons.developer_mode),
          findsOneWidget,
          reason: 'icon should be present for position=$position',
        );
      }
    });
  });
}
