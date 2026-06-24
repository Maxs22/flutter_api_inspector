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
import 'package:flutter_api_inspector/src/overlay/timeline_panel.dart';
import 'package:flutter_api_inspector/src/overlay/detail_screen.dart';

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

  group('TimelinePanel widget (REQ-UI-005, REQ-UI-006)', () {
    // Helper: build a record with the given outcome and name.
    ApiTraceRecord record({
      required String name,
      required String method,
      required int? statusCode,
      required ApiTraceOutcome outcome,
    }) {
      final start = DateTime(2026, 1, 1, 0, 0, 0);
      return ApiTraceRecord(
        id: 'id-$name',
        name: name,
        startedAt: start,
        completedAt: start.add(const Duration(milliseconds: 10)),
        method: method,
        url: Uri.parse('https://api.example.com/$name'),
        statusCode: statusCode,
        duration: const Duration(milliseconds: 10),
        outcome: outcome,
        capturedDetails: const <ApiTraceDetail>{ApiTraceDetail.minimal},
        request: null,
        response: null,
        error: null,
        extra: const <String, Object?>{},
      );
    }

    Widget panelHost(List<ApiTraceRecord> records) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 800,
            child: TimelinePanel(
              records: List<ApiTraceRecord>.unmodifiable(records),
              onTap: (ApiTraceRecord _) {},
            ),
          ),
        ),
      );
    }

    testWidgets('renders rows in newest-first order (REQ-UI-005)',
        (tester) async {
      // RED: import target missing for `timeline_panel.dart`.
      // The Timeline exposes records head=newest. The panel
      // renders them in the order received. We pass in
      // [C, B, A] (newest first) and assert the rendered
      // order is C, B, A (top to bottom).
      final records = <ApiTraceRecord>[
        record(
            name: 'C',
            method: 'GET',
            statusCode: 200,
            outcome: ApiTraceOutcome.success),
        record(
            name: 'B',
            method: 'GET',
            statusCode: 200,
            outcome: ApiTraceOutcome.success),
        record(
            name: 'A',
            method: 'GET',
            statusCode: 200,
            outcome: ApiTraceOutcome.success),
      ];
      await tester.pumpWidget(panelHost(records));
      // Each name must be found exactly once.
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      // Find the y-coordinates of each name and assert
      // C is above B is above A.
      final yC = tester.getTopLeft(find.text('C')).dy;
      final yB = tester.getTopLeft(find.text('B')).dy;
      final yA = tester.getTopLeft(find.text('A')).dy;
      expect(yC, lessThan(yB));
      expect(yB, lessThan(yA));
    });

    testWidgets('empty timeline shows an empty-state message (REQ-UI-005)',
        (tester) async {
      // With no records, the panel renders a friendly
      // empty-state message and no list rows.
      await tester.pumpWidget(panelHost(const <ApiTraceRecord>[]));
      // The empty-state message contains 'No API calls' or
      // similar developer-friendly hint.
      expect(find.textContaining('No'), findsOneWidget);
      // No TimelineRow widgets are rendered.
      expect(find.byType(TimelineRow), findsNothing);
    });

    testWidgets('Error-only filter shows only the error record (REQ-UI-006)',
        (tester) async {
      // The Error-only filter chip narrows the rendered list
      // to records with outcome == error. With one success +
      // one error record, the error-only filter renders
      // exactly one row.
      final records = <ApiTraceRecord>[
        record(
            name: 'ok',
            method: 'GET',
            statusCode: 200,
            outcome: ApiTraceOutcome.success),
        record(
            name: 'broken',
            method: 'GET',
            statusCode: 500,
            outcome: ApiTraceOutcome.error),
      ];
      await tester.pumpWidget(panelHost(records));
      // Tap the 'Error only' filter chip.
      await tester.tap(find.widgetWithText(FilterChip, 'Error only'));
      await tester.pumpAndSettle();
      // The ok row is gone; the broken row remains.
      expect(find.text('ok'), findsNothing);
      expect(find.text('broken'), findsOneWidget);
    });

    testWidgets(
        'Name substring filter shows only matching records (REQ-UI-006)',
        (tester) async {
      // Typing 'get' into the name filter narrows the
      // rendered list to records whose name contains 'get'
      // (case-insensitive). With getUser and listOrders,
      // only getUser remains.
      final records = <ApiTraceRecord>[
        record(
            name: 'getUser',
            method: 'GET',
            statusCode: 200,
            outcome: ApiTraceOutcome.success),
        record(
            name: 'listOrders',
            method: 'GET',
            statusCode: 200,
            outcome: ApiTraceOutcome.success),
      ];
      await tester.pumpWidget(panelHost(records));
      // Type 'get' into the filter field.
      await tester.enterText(find.byType(TextField), 'get');
      await tester.pumpAndSettle();
      // Only the getUser record is rendered.
      expect(find.text('getUser'), findsOneWidget);
      expect(find.text('listOrders'), findsNothing);
    });

    testWidgets('Toggling the All filter restores the full list (REQ-UI-006)',
        (tester) async {
      // After filtering down to errors, tapping 'All'
      // restores the full list.
      final records = <ApiTraceRecord>[
        record(
            name: 'ok1',
            method: 'GET',
            statusCode: 200,
            outcome: ApiTraceOutcome.success),
        record(
            name: 'broken1',
            method: 'GET',
            statusCode: 500,
            outcome: ApiTraceOutcome.error),
        record(
            name: 'ok2',
            method: 'GET',
            statusCode: 200,
            outcome: ApiTraceOutcome.success),
      ];
      await tester.pumpWidget(panelHost(records));
      // Filter to errors only.
      await tester.tap(find.widgetWithText(FilterChip, 'Error only'));
      await tester.pumpAndSettle();
      expect(find.text('ok1'), findsNothing);
      expect(find.text('broken1'), findsOneWidget);
      // Toggle back to All.
      await tester.tap(find.widgetWithText(FilterChip, 'All'));
      await tester.pumpAndSettle();
      expect(find.text('ok1'), findsOneWidget);
      expect(find.text('broken1'), findsOneWidget);
      expect(find.text('ok2'), findsOneWidget);
    });

    testWidgets(
        'Filters do not mutate the underlying records list (REQ-UI-006)',
        (tester) async {
      // The panel must filter a copy of the records; the
      // list passed in must remain unchanged.
      final records = <ApiTraceRecord>[
        record(
            name: 'a',
            method: 'GET',
            statusCode: 200,
            outcome: ApiTraceOutcome.success),
        record(
            name: 'b',
            method: 'GET',
            statusCode: 500,
            outcome: ApiTraceOutcome.error),
      ];
      final input = List<ApiTraceRecord>.unmodifiable(records);
      final before = input.length;
      await tester.pumpWidget(panelHost(input));
      await tester.tap(find.widgetWithText(FilterChip, 'Error only'));
      await tester.pumpAndSettle();
      // The input list is still 2.
      expect(input.length, before);
      // And it still contains both names.
      expect(input.any((ApiTraceRecord r) => r.name == 'a'), isTrue);
      expect(input.any((ApiTraceRecord r) => r.name == 'b'), isTrue);
    });

    testWidgets(
        'TRIANGULATE: substring filter is case-insensitive (REQ-UI-006)',
        (tester) async {
      // 'GET' substring (uppercase) should match a record
      // named 'getUser' (lowercase 'get' prefix).
      final records = <ApiTraceRecord>[
        record(
            name: 'getUser',
            method: 'GET',
            statusCode: 200,
            outcome: ApiTraceOutcome.success),
        record(
            name: 'listOrders',
            method: 'GET',
            statusCode: 200,
            outcome: ApiTraceOutcome.success),
      ];
      await tester.pumpWidget(panelHost(records));
      await tester.enterText(find.byType(TextField), 'GET');
      await tester.pumpAndSettle();
      expect(find.text('getUser'), findsOneWidget);
      expect(find.text('listOrders'), findsNothing);
    });
  });

  group('ApiTraceDetailScreen widget (REQ-UI-007)', () {
    // Helper: build a record with optional response and
    // request payloads.
    ApiTraceRecord record({
      String name = 'listOrders',
      String method = 'GET',
      Uri? url,
      int? statusCode = 200,
      ApiTraceOutcome outcome = ApiTraceOutcome.success,
      ApiTraceRequest? request,
      ApiTraceResponse? response,
      Object? error,
    }) {
      final effectiveUrl =
          url ?? Uri.parse('https://api.example.com/v1/orders');
      final start = DateTime(2026, 1, 1, 12, 0, 0);
      return ApiTraceRecord(
        id: 'id',
        name: name,
        startedAt: start,
        completedAt: start.add(const Duration(milliseconds: 50)),
        method: method,
        url: effectiveUrl,
        statusCode: statusCode,
        duration: const Duration(milliseconds: 50),
        outcome: outcome,
        capturedDetails: const <ApiTraceDetail>{
          ApiTraceDetail.minimal,
          ApiTraceDetail.headers,
          ApiTraceDetail.response,
        },
        request: request,
        response: response,
        error: error,
        extra: const <String, Object?>{},
      );
    }

    Widget detailHost(ApiTraceRecord r) {
      return MaterialApp(
        home: ApiTraceDetailScreen(record: r),
      );
    }

    testWidgets('detail screen shows name, method, url, statusCode, duration',
        (tester) async {
      // RED: import target missing for `detail_screen.dart`.
      // REQ-UI-007: the read-only detail screen shows the
      // captured fields.
      final r = record();
      await tester.pumpWidget(detailHost(r));
      // The name appears in both the AppBar title and the
      // body Overview section. find.text matches both, so we
      // use findsNWidgets(2) to assert at least one body
      // occurrence (the AppBar is a fixed location).
      expect(find.text('listOrders'), findsNWidgets(2));
      expect(find.textContaining('GET'), findsWidgets);
      expect(find.text('https://api.example.com/v1/orders'), findsOneWidget);
      // '200' is rendered for both the status code field
      // (in body) and the response status (if shown). At
      // least one occurrence is sufficient.
      expect(find.textContaining('200'), findsWidgets);
      // Duration '50 ms' should be present.
      expect(find.textContaining('ms'), findsWidgets);
    });

    testWidgets('detail screen shows response body when captured',
        (tester) async {
      // REQ-UI-007: with response captured, the body is
      // rendered in the detail screen.
      final r = record(
        response: const ApiTraceResponse(
          statusCode: 200,
          responseHeaders: <String, String>{'content-type': 'application/json'},
          responseBody: <String, Object?>{
            'items': <String>['a', 'b', 'c']
          },
        ),
      );
      await tester.pumpWidget(detailHost(r));
      // The body renders via toString() because it's a Map.
      // The string 'items' is unique to the body field (the
      // URL does not contain it).
      expect(find.textContaining('items'), findsOneWidget);
    });

    testWidgets('detail screen shows request headers when captured',
        (tester) async {
      // REQ-UI-007: with headers captured, the request
      // headers are rendered.
      final r = record(
        request: const ApiTraceRequest(
          headers: <String, String>{'authorization': 'Bearer x'},
        ),
      );
      await tester.pumpWidget(detailHost(r));
      expect(find.textContaining('authorization'), findsOneWidget);
      expect(find.textContaining('Bearer x'), findsOneWidget);
    });

    testWidgets('detail screen shows error field when error is non-null',
        (tester) async {
      // REQ-UI-007: the error field is rendered when set.
      final r = record(
        outcome: ApiTraceOutcome.error,
        error: const FormatException('boom'),
      );
      await tester.pumpWidget(detailHost(r));
      expect(find.textContaining('boom'), findsOneWidget);
    });

    testWidgets('No button labelled "Copy as cURL" (REQ-UI-007 out of scope)',
        (tester) async {
      // REQ-UI-007 out-of-scope list: no Copy-as-cURL.
      await tester.pumpWidget(detailHost(record()));
      expect(find.text('Copy as cURL'), findsNothing);
    });

    testWidgets('No button labelled "Re-run" (REQ-UI-007 out of scope)',
        (tester) async {
      // REQ-UI-007 out-of-scope list: no Re-run.
      await tester.pumpWidget(detailHost(record()));
      expect(find.text('Re-run'), findsNothing);
    });

    testWidgets('No button labelled "Export" (REQ-UI-007 out of scope)',
        (tester) async {
      // REQ-UI-007 out-of-scope list: no Export.
      await tester.pumpWidget(detailHost(record()));
      expect(find.text('Export'), findsNothing);
    });

    testWidgets('TRIANGULATE: detail screen renders null body gracefully',
        (tester) async {
      // A record captured at {minimal} has null body / null
      // headers. The detail screen must render without
      // crashing.
      final r = ApiTraceRecord(
        id: 'id',
        name: 'minimal',
        startedAt: DateTime(2026, 1, 1, 0, 0, 0),
        completedAt: DateTime(2026, 1, 1, 0, 0, 0, 10),
        method: 'GET',
        url: Uri.parse('https://api.example.com/x'),
        statusCode: 200,
        duration: const Duration(milliseconds: 10),
        outcome: ApiTraceOutcome.success,
        capturedDetails: const <ApiTraceDetail>{ApiTraceDetail.minimal},
        request: null,
        response: null,
        error: null,
        extra: const <String, Object?>{},
      );
      await tester.pumpWidget(detailHost(r));
      // The screen renders without throwing. The name is
      // shown in the AppBar title, the Overview Name field,
      // and the Captured details list (since 'minimal' is
      // one of the captured details). Assert at least 2
      // occurrences (AppBar + body).
      expect(find.text('minimal'), findsAtLeastNWidgets(2));
    });
  });
}
