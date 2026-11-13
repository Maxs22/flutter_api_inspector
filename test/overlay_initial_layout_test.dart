import 'package:flutter/material.dart';
import 'package:flutter_api_inspector/flutter_api_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('default launcher follows corner after initial small layout',
      (tester) async {
    ApiTrace.enabled = true;
    final size = ValueNotifier(const Size(64, 64));
    addTearDown(size.dispose);
    const viewport = Key('viewport');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: ValueListenableBuilder<Size>(
        valueListenable: size,
        builder: (_, value, __) => Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            key: viewport,
            width: value.width,
            height: value.height,
            child: const ApiTraceOverlay(
              config: ApiTraceConfig(),
              records: [],
            ),
          ),
        ),
      ),
    )));
    size.value = const Size(400, 500);
    await tester.pumpAndSettle();
    final origin = tester.getTopLeft(find.byKey(viewport));
    expect(tester.getTopLeft(find.byType(FloatingActionButton)) - origin,
        const Offset(328, 428));
    await tester.pump();
    expect(tester.getTopLeft(find.byType(FloatingActionButton)) - origin,
        const Offset(328, 428));
    expect(tester.takeException(), isNull);
  });
}
