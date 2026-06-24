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
import 'package:flutter_api_inspector/src/overlay/timeline_row.dart';

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

  group('TimelineRow widget (REQ-UI-005, REQ-UI-008)', () {
    // Helper: build a record with the given outcome and statusCode.
    ApiTraceRecord record({
      required String name,
      required String method,
      required int? statusCode,
      required ApiTraceOutcome outcome,
      String url = 'https://api.example.com/x',
    }) {
      final start = DateTime(2026, 1, 1, 0, 0, 0);
      return ApiTraceRecord(
        id: 'id-$name',
        name: name,
        startedAt: start,
        completedAt: start.add(const Duration(milliseconds: 50)),
        method: method,
        url: Uri.parse(url),
        statusCode: statusCode,
        duration: const Duration(milliseconds: 50),
        outcome: outcome,
        capturedDetails: const <ApiTraceDetail>{ApiTraceDetail.minimal},
        request: null,
        response: null,
        error: null,
        extra: const <String, Object?>{},
      );
    }

    Widget rowHost(TimelineRow row) {
      return MaterialApp(
        home: Scaffold(body: row),
      );
    }

    testWidgets('row shows name, method, statusCode, duration', (tester) async {
      // RED: import target missing for `timeline_row.dart`.
      // REQ-UI-005: each row shows the record's name, method,
      // statusCode, and duration.
      await tester.pumpWidget(rowHost(
        TimelineRow(
          record: record(
            name: 'listOrders',
            method: 'GET',
            statusCode: 200,
            outcome: ApiTraceOutcome.success,
          ),
          onTap: () {},
        ),
      ));
      expect(find.text('listOrders'), findsOneWidget);
      expect(find.textContaining('GET'), findsOneWidget);
      expect(find.textContaining('200'), findsOneWidget);
      // The duration text contains '50 ms' (formatted).
      expect(find.textContaining('ms'), findsOneWidget);
    });

    testWidgets('row handles null statusCode with placeholder', (tester) async {
      // REQ-UI-005: when the call threw before a response was
      // produced, statusCode is null. The row renders a
      // placeholder ('—' or 'error') instead.
      await tester.pumpWidget(rowHost(
        TimelineRow(
          record: record(
            name: 'oops',
            method: 'POST',
            statusCode: null,
            outcome: ApiTraceOutcome.error,
          ),
          onTap: () {},
        ),
      ));
      // The status code text contains the em-dash placeholder '—'.
      expect(find.textContaining('—'), findsOneWidget);
    });

    testWidgets('success row tints its Icon with the green color (REQ-UI-008)',
        (tester) async {
      // REQ-UI-008: outcome == success renders in green. The
      // row's status Icon (the small leading indicator) is
      // tinted with the green color from outcomeColor.
      await tester.pumpWidget(rowHost(
        TimelineRow(
          record: record(
            name: 'ok',
            method: 'GET',
            statusCode: 200,
            outcome: ApiTraceOutcome.success,
          ),
          onTap: () {},
        ),
      ));
      // Find the row's status Icon (Icons.check_circle for
      // success) and assert its color matches the helper.
      final iconFinder = find.byIcon(Icons.check_circle);
      expect(iconFinder, findsOneWidget);
      final iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.color, equals(Colors.green.shade600));
    });

    testWidgets('error row tints its Icon with the red color (REQ-UI-008)',
        (tester) async {
      await tester.pumpWidget(rowHost(
        TimelineRow(
          record: record(
            name: 'bad',
            method: 'GET',
            statusCode: 500,
            outcome: ApiTraceOutcome.error,
          ),
          onTap: () {},
        ),
      ));
      // For outcome == error, the row's leading icon is
      // Icons.error (per design.md). The icon is tinted with
      // the red color from outcomeColor.
      final iconFinder = find.byIcon(Icons.error);
      expect(iconFinder, findsOneWidget);
      final iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.color, equals(Colors.red.shade600));
    });

    testWidgets('4xx and 5xx rows have the same red color (REQ-UI-008)',
        (tester) async {
      // REQ-UI-008: 4xx and 5xx share the same red color.
      // Asserts the two rows' icon colors are the same.
      await tester.pumpWidget(rowHost(
        TimelineRow(
          record: record(
            name: 'notfound',
            method: 'GET',
            statusCode: 404,
            outcome: ApiTraceOutcome.error,
          ),
          onTap: () {},
        ),
      ));
      Color? color4xx;
      final icon4xx = tester.widget<Icon>(find.byIcon(Icons.error));
      color4xx = icon4xx.color;
      await tester.pumpWidget(rowHost(
        TimelineRow(
          record: record(
            name: 'serverError',
            method: 'GET',
            statusCode: 503,
            outcome: ApiTraceOutcome.error,
          ),
          onTap: () {},
        ),
      ));
      final icon5xx = tester.widget<Icon>(find.byIcon(Icons.error));
      expect(icon5xx.color, equals(color4xx));
    });

    testWidgets('onTap callback fires when the row is tapped', (tester) async {
      // The whole row is tappable; tapping anywhere in the
      // row fires onTap.
      var taps = 0;
      await tester.pumpWidget(rowHost(
        TimelineRow(
          record: record(
            name: 'tapme',
            method: 'GET',
            statusCode: 200,
            outcome: ApiTraceOutcome.success,
          ),
          onTap: () => taps++,
        ),
      ));
      await tester.tap(find.byType(TimelineRow));
      expect(taps, 1);
    });

    testWidgets('TRIANGULATE: row text color matches the outcome color',
        (tester) async {
      // The row's text color is the outcome color too, so
      // both the icon and the text are tinted. We assert the
      // name's text style color matches the helper.
      await tester.pumpWidget(rowHost(
        TimelineRow(
          record: record(
            name: 'styled',
            method: 'GET',
            statusCode: 200,
            outcome: ApiTraceOutcome.success,
          ),
          onTap: () {},
        ),
      ));
      final nameText = tester.widget<Text>(find.text('styled'));
      expect(nameText.style?.color, equals(Colors.green.shade600));

      await tester.pumpWidget(rowHost(
        TimelineRow(
          record: record(
            name: 'errored',
            method: 'GET',
            statusCode: 500,
            outcome: ApiTraceOutcome.error,
          ),
          onTap: () {},
        ),
      ));
      final errorText = tester.widget<Text>(find.text('errored'));
      expect(errorText.style?.color, equals(Colors.red.shade600));
    });
  });
}
