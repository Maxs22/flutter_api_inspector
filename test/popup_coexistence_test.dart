import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_inspector/flutter_api_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openInspector(WidgetTester tester) async {
  await tester.pump();
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    ApiTrace.enabled = true;
    ApiTrace.timeline.clear();
    ApiTrace.config = const ApiTraceConfig();
  });

  testWidgets('outside host action passes through without closing inspector',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(ApiTraceBootstrap(
      child: MaterialApp(
          home: Scaffold(
              body: Align(
        alignment: Alignment.bottomLeft,
        child: TextButton(onPressed: () => taps++, child: const Text('host')),
      ))),
    ));
    await tester.pump();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('host'));
    await tester.pump();
    expect(taps, 1);
    expect(find.text('Timeline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final popup in ['menu', 'sheet']) {
    testWidgets('host $popup action overlapping inspector returns result',
        (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(ApiTraceBootstrap(
          child: MaterialApp(
        navigatorKey: nav,
        home: const Scaffold(),
      )));
      await openInspector(tester);
      final Future<String?> result;
      if (popup == 'menu') {
        result = showMenu<String>(
          context: nav.currentContext!,
          position: const RelativeRect.fromLTRB(700, 500, 0, 0),
          items: const [
            PopupMenuItem(value: 'menu result', child: Text('host action'))
          ],
        );
      } else {
        result = showModalBottomSheet<String>(
          context: nav.currentContext!,
          builder: (context) => SizedBox(
              height: 540,
              child: Align(
                alignment: Alignment.topCenter,
                child: TextButton(
                    onPressed: () => Navigator.pop(context, 'sheet result'),
                    child: const Text('host action')),
              )),
        );
      }
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.tap(find.text('host action'));
      await tester.pumpAndSettle();
      expect(find.text('host action'), findsNothing);
      expect(await result, '$popup result');
      expect(find.text('Timeline'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('active and queued host snackbars survive opening',
      (tester) async {
    final messenger = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(ApiTraceBootstrap(
        child: MaterialApp(
      scaffoldMessengerKey: messenger,
      home: const Scaffold(),
    )));
    await tester.pump();
    final first = messenger.currentState!.showSnackBar(const SnackBar(
        duration: Duration(days: 1), content: Text('active host message')));
    final second = messenger.currentState!.showSnackBar(const SnackBar(
        duration: Duration(days: 1), content: Text('queued host message')));
    var firstClosed = false;
    var secondClosed = false;
    unawaited(first.closed.then((_) => firstClosed = true));
    unawaited(second.closed.then((_) => secondClosed = true));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(firstClosed, isFalse);
    expect(secondClosed, isFalse);
    expect(find.text('active host message'), findsOneWidget);
    messenger.currentState!.hideCurrentSnackBar();
    await tester.pumpAndSettle();
    expect(firstClosed, isTrue);
    expect(secondClosed, isFalse);
    expect(find.text('queued host message'), findsOneWidget);
    messenger.currentState!.removeCurrentSnackBar();
    await tester.pumpAndSettle();
  });

  for (final router in [false, true]) {
    testWidgets(
        'explicit wrapped ${router ? 'router' : 'navigator'} preserves state',
        (tester) async {
      final observer = ApiTraceNavigatorObserver();
      final nav = GlobalKey<NavigatorState>();
      final delegate = _RouterDelegate(nav, observer);
      Widget builder(BuildContext context, Widget? child) => ApiTraceHost(
            observer: observer,
            child: KeyedSubtree(
                key: const Key('existing builder'),
                child: Stack(
                  children: [
                    child!,
                    const IgnorePointer(child: Text('loading overlay'))
                  ],
                )),
          );
      await tester.pumpWidget(_AppWrapper(
          child: router
              ? MaterialApp.router(routerDelegate: delegate, builder: builder)
              : MaterialApp(
                  navigatorKey: nav,
                  navigatorObservers: [observer],
                  builder: builder,
                  home: const Scaffold())));
      await openInspector(tester);
      await tester.tap(find.text('Routes'));
      await tester.pumpAndSettle();
      final fabPosition = tester.getTopLeft(find.byType(FloatingActionButton));
      final popup = showDialog<bool>(
          context: nav.currentContext!,
          builder: (context) => AlertDialog(actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('wrapped accept')),
              ]));
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Routes'), findsNothing);
      expect(find.byKey(const Key('existing builder')), findsOneWidget);
      expect(find.text('loading overlay'), findsOneWidget);
      await tester.tap(find.text('wrapped accept'));
      await tester.pumpAndSettle();
      expect(await popup, isTrue);
      expect(find.text('Routes'), findsOneWidget);
      // The Routes tab remains selected (timeline's panel is not mounted).
      expect(find.byKey(const ValueKey('inspectorPanel')), findsNothing);
      expect(tester.getTopLeft(find.byType(FloatingActionButton)), fabPosition);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      // Host did not dispose a user-owned observer.
      observer.addListener(() {});
      observer.dispose();
    });
  }

  testWidgets(
      'popup suspension retains filters detail stack geometry and live records',
      (tester) async {
    final nav = GlobalKey<NavigatorState>();
    ApiTrace.timeline.append(_record('keep original'));
    await tester.pumpWidget(ApiTraceBootstrap(
        child: MaterialApp(
      navigatorKey: nav,
      home: const Scaffold(),
    )));
    await openInspector(tester);
    await tester.drag(find.byType(FloatingActionButton), const Offset(-90, 0));
    await tester.pumpAndSettle();
    final fabPosition = tester.getTopLeft(find.byType(FloatingActionButton));
    await tester.enterText(find.byType(TextField), 'keep');
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);
    final panelSize =
        tester.getSize(find.byKey(const ValueKey('inspectorPanel')));
    final firstPopup = showDialog<void>(
        context: nav.currentContext!,
        requestFocus: false,
        builder: (context) => AlertDialog(actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('dismiss'))
            ]));
    await tester.pumpAndSettle();
    expect(editable.focusNode.hasFocus, isFalse);
    expect(editable.focusNode.canRequestFocus, isFalse);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('dismiss'));
    await tester.pumpAndSettle();
    await firstPopup;
    expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'keep');
    expect(tester.getSize(find.byKey(const ValueKey('inspectorPanel'))),
        panelSize);
    // Short panels scroll controls and request cards together. Bring the
    // actual card into the viewport before sending the pointer gesture.
    await tester.ensureVisible(find.text('keep original'));
    await tester.pumpAndSettle();
    expect(find.text('keep original').hitTestable(), findsOneWidget);
    await tester.tap(find.text('keep original'));
    await tester.pumpAndSettle();
    expect(find.byType(ApiTraceDetailScreen), findsOneWidget);
    final secondPopup = showDialog<void>(
        context: nav.currentContext!,
        builder: (context) => AlertDialog(actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('dismiss'))
            ]));
    await tester.pumpAndSettle();
    expect(find.byType(ApiTraceDetailScreen), findsNothing);
    ApiTrace.timeline.append(_record('keep latest'));
    ApiTrace.timeline.append(_record('excluded'));
    await tester.pump();
    await tester.tap(find.text('dismiss'));
    await tester.pumpAndSettle();
    await secondPopup;
    expect(find.byType(ApiTraceDetailScreen), findsOneWidget);
    expect(tester.getTopLeft(find.byType(FloatingActionButton)), fabPosition);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'keep');
    expect(find.text('keep latest'), findsOneWidget);
    expect(find.text('excluded'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('host dialog action overlapping panel returns result',
      (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ApiTraceBootstrap(
        child: MaterialApp(
      navigatorKey: nav,
      home: const Scaffold(),
    )));
    await tester.pump();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    final result = showDialog<String>(
      context: nav.currentContext!,
      builder: (context) => AlertDialog(actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, 'accepted'),
            child: const Text('accept host')),
      ]),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('accept host'));
    await tester.pumpAndSettle();
    expect(find.text('accept host'), findsNothing);
    expect(await result, 'accepted');
    expect(find.text('Timeline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ApiTraceRecord _record(String name) => ApiTraceRecord(
      id: name,
      name: name,
      startedAt: DateTime(2026),
      completedAt: DateTime(2026).add(const Duration(milliseconds: 10)),
      method: 'GET',
      url: Uri.parse('https://example.test/$name'),
      statusCode: 200,
      duration: const Duration(milliseconds: 10),
      outcome: ApiTraceOutcome.success,
      capturedDetails: const {ApiTraceDetail.minimal},
      request: null,
      response: null,
      error: null,
      extra: const {},
    );

class _AppWrapper extends StatelessWidget {
  const _AppWrapper({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
        key: const Key('provider equivalent'),
        child: child,
      );
}

class _RouterDelegate extends RouterDelegate<Object>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
  _RouterDelegate(this.navigatorKey, this.observer);

  @override
  final GlobalKey<NavigatorState> navigatorKey;
  final ApiTraceNavigatorObserver observer;

  @override
  Widget build(BuildContext context) => Navigator(
        key: navigatorKey,
        observers: [observer],
        pages: const [MaterialPage<void>(child: Scaffold())],
        onDidRemovePage: (_) {},
      );

  @override
  Future<void> setNewRoutePath(Object configuration) async {}
}
