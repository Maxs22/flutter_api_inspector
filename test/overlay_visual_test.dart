import 'package:flutter/material.dart';
import 'package:flutter_api_inspector/flutter_api_inspector.dart';
import 'package:flutter_api_inspector/src/overlay/timeline_panel.dart';
import 'package:flutter_api_inspector/src/overlay/timeline_row.dart';
import 'package:flutter_test/flutter_test.dart';

ApiTraceRecord _record(int status, String method) => ApiTraceRecord(
      id: 'visual-$status',
      name: 'A comfortably readable request',
      startedAt: DateTime(2026),
      completedAt: DateTime(2026).add(const Duration(milliseconds: 84)),
      method: method,
      url: Uri.parse('https://example.com/v1/users/24?include=profile'),
      statusCode: status,
      duration: const Duration(milliseconds: 84),
      outcome: status >= 400 ? ApiTraceOutcome.error : ApiTraceOutcome.success,
      capturedDetails: const {ApiTraceDetail.minimal},
      request: null,
      response: null,
      error: null,
      extra: const {},
    );

Widget _host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: ThemeData(colorSchemeSeed: Colors.teal, brightness: brightness),
      home: Scaffold(body: Align(alignment: Alignment.topLeft, child: child)),
    );

double _contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return ((x > y ? x : y) + 0.05) / ((x > y ? y : x) + 0.05);
}

void main() {
  testWidgets('Breathing Room request cards stack metadata at narrow widths',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(SizedBox(
      width: 296,
      child: TimelineRow(record: _record(200, 'GET'), onTap: () => taps++),
    )));
    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(find.text('200')).dy,
        greaterThan(tester.getBottomLeft(find.textContaining('/v1/users')).dy));
    expect(tester.getSize(find.byType(TimelineRow)).height,
        greaterThanOrEqualTo(120));
    final card = tester.widget<Material>(find.descendant(
        of: find.byType(TimelineRow), matching: find.byType(Material)));
    expect((card.shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(16));
    await tester.tap(find.byType(TimelineRow));
    expect(taps, 1);
  });

  testWidgets(
      'Breathing Room search and filter controls have comfortable targets',
      (tester) async {
    await tester.pumpWidget(_host(SizedBox(
      width: 320,
      height: 600,
      child: TimelinePanel(records: [_record(200, 'GET')], onTap: (_) {}),
    )));
    expect(tester.getSize(find.byType(TextField)).height,
        greaterThanOrEqualTo(48));
    expect(tester.getSize(find.widgetWithText(FilterChip, 'All')).height,
        greaterThanOrEqualTo(44));
    await tester.tap(find.widgetWithText(FilterChip, 'Errors'));
    await tester.pumpAndSettle();
    expect(find.byType(TimelineRow), findsNothing);
    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.pumpAndSettle();
    expect(find.byType(TimelineRow), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'short panel keeps filters, requests and header actions reachable',
      (tester) async {
    var opened = 0;
    var cleared = 0;
    var closed = 0;
    List<ApiTraceRecord>? exported;
    final records = [_record(200, 'GET')];
    await tester.pumpWidget(_host(SizedBox(
      width: 296,
      height: 180,
      child: TimelinePanel(
        records: records,
        onTap: (_) => opened++,
        onClear: () => cleared++,
        onClose: () => closed++,
        onExport: (value) => exported = value,
      ),
    )));
    final viewport = find.byType(CustomScrollView);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Export as cURL'));
    await tester.tap(find.byTooltip('Clear timeline'));
    expect(exported, records);
    expect(cleared, 1);
    await tester.drag(viewport, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilterChip, 'Errors').hitTestable(),
        findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'Errors'));
    await tester.pumpAndSettle();
    expect(find.byType(TimelineRow), findsNothing);
    expect(
        find.widgetWithText(FilterChip, 'All').hitTestable(), findsOneWidget);
    await tester.tap(find.widgetWithText(FilterChip, 'All'));
    await tester.pumpAndSettle();
    await tester.drag(viewport, const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(find.text(records.single.name).hitTestable(), findsOneWidget);
    await tester.tap(find.text(records.single.name));
    expect(opened, 1);
    await tester.drag(viewport, const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close panel').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Close panel'));
    expect(closed, 1);
    expect(records, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        'Breathing Room small badges contrast against actual $brightness fill',
        (tester) async {
      for (final status in [200, 302, 404, 500]) {
        await tester.pumpWidget(_host(
          TimelineRow(record: _record(status, 'POST'), onTap: () {}),
          brightness: brightness,
        ));
        for (final label in ['POST', '$status']) {
          final text = find.text(label);
          final badge = tester.widget<Container>(find
              .ancestor(
                of: text,
                matching: find.byWidgetPredicate(
                    (w) => w is Container && w.decoration is BoxDecoration),
              )
              .first);
          final material = tester.widget<Material>(
              find.ancestor(of: text, matching: find.byType(Material)).first);
          final fill = Color.alphaBlend(
              (badge.decoration! as BoxDecoration).color!, material.color!);
          expect(_contrast(tester.widget<Text>(text).style!.color!, fill),
              greaterThanOrEqualTo(4.5),
              reason: '$label in $brightness');
        }
      }
    });
  }
}
