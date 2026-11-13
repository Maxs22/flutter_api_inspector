import 'package:flutter/material.dart';
import 'package:flutter_api_inspector/flutter_api_inspector.dart';
import 'package:flutter_api_inspector/src/overlay/route_endpoint_panel.dart';
import 'package:flutter_api_inspector/src/overlay/timeline_panel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('endpoint navigation uses line icon and still goes back',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                        builder: (_) => const RouteEndpointPanel(
                            routeName: '/detail', records: []))),
                child: const Text('Open endpoints')))));
    await tester.tap(find.text('Open endpoints'));
    await tester.pumpAndSettle();
    for (final icon in tester.widgetList<Icon>(find.byType(Icon))) {
      expect(icon.icon?.fontFamily, 'InspectorIcons');
    }
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open endpoints'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('inspector typography is scoped away from host text',
      (tester) async {
    ApiTrace.enabled = true;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(fontFamily: 'HostTypeface'),
      home: const Scaffold(
          body: Stack(children: [
        Text('Host content'),
        ApiTraceOverlay(config: ApiTraceConfig(), records: []),
      ])),
    ));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(
        Theme.of(tester.element(find.text('Host content')))
            .textTheme
            .bodyMedium
            ?.fontFamily,
        'HostTypeface');
    expect(
        Theme.of(tester.element(find.text('API calls')))
            .textTheme
            .bodyMedium
            ?.fontFamily,
        'packages/flutter_api_inspector/InspectorSans');
    expect(tester.takeException(), isNull);
  });
  testWidgets('launcher and panel use bundled line icons', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Column(children: [
      ApiTraceFab(
          onPressed: () {}, config: const ApiTraceConfig(), recordCount: 0),
      Expanded(child: TimelinePanel(records: const [], onTap: (_) {})),
    ]))));
    final icons = tester.widgetList<Icon>(find.byType(Icon));
    expect(icons, isNotEmpty);
    for (final icon in icons) {
      expect(icon.icon?.fontFamily, 'InspectorIcons');
      expect(icon.icon?.fontPackage, 'flutter_api_inspector');
    }
    expect(tester.takeException(), isNull);
  });
}
