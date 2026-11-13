import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_api_inspector/flutter_api_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

DialogRoute<void> popup(BuildContext context, String name) => DialogRoute<void>(
      context: context,
      builder: (_) => AlertDialog(content: Text(name)),
    );

void main() {
  testWidgets('overlapping popups remain suspended through reverse completion',
      (tester) async {
    ApiTrace.enabled = true;
    final observer = ApiTraceNavigatorObserver();
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      navigatorObservers: [observer],
      builder: (_, child) => ApiTraceHost(observer: observer, child: child!),
      home: const Scaffold(),
    ));
    await tester.pump();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    final first = popup(nav.currentContext!, 'first popup');
    final second = popup(nav.currentContext!, 'second popup');
    unawaited(nav.currentState!.push(first));
    await tester.pumpAndSettle();
    unawaited(nav.currentState!.push(second));
    await tester.pumpAndSettle();
    expect(observer.hasActivePopup, isTrue);
    expect(find.byType(FloatingActionButton), findsNothing);
    nav.currentState!.pop();
    await tester.pump();
    expect(observer.hasActivePopup, isTrue);
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.pumpAndSettle();
    expect(observer.hasActivePopup, isTrue);
    nav.currentState!.pop();
    await tester.pump();
    expect(observer.hasActivePopup, isTrue);
    expect(find.byType(FloatingActionButton), findsNothing);
    await tester.pumpAndSettle();
    expect(observer.hasActivePopup, isFalse);
    expect(find.text('Timeline'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    observer.dispose();
  });

  testWidgets('remove and replace track popup identities independently',
      (tester) async {
    ApiTrace.enabled = true;
    final observer = ApiTraceNavigatorObserver();
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      navigatorObservers: [observer],
      builder: (_, child) => ApiTraceHost(observer: observer, child: child!),
      home: const Scaffold(),
    ));
    await tester.pump();
    final first = popup(nav.currentContext!, 'removed');
    final top = popup(nav.currentContext!, 'top');
    unawaited(nav.currentState!.push(first));
    await tester.pumpAndSettle();
    unawaited(nav.currentState!.push(top));
    await tester.pumpAndSettle();
    nav.currentState!.removeRoute(first);
    await tester.pumpAndSettle();
    expect(observer.hasActivePopup, isTrue);
    final replacement = popup(nav.currentContext!, 'replacement');
    nav.currentState!.replace(oldRoute: top, newRoute: replacement);
    await tester.pumpAndSettle();
    expect(observer.hasActivePopup, isTrue);
    expect(find.byType(FloatingActionButton), findsNothing);
    nav.currentState!.replace(
        oldRoute: replacement,
        newRoute: MaterialPageRoute<void>(builder: (_) => const Scaffold()));
    await tester.pumpAndSettle();
    expect(observer.hasActivePopup, isFalse);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    observer.dispose();
  });

  testWidgets('disposal while popup active never notifies disposed listeners',
      (tester) async {
    final observer = ApiTraceNavigatorObserver();
    final nav = GlobalKey<NavigatorState>();
    var notifications = 0;
    observer.addListener(() => notifications++);
    await tester.pumpWidget(MaterialApp(
        navigatorKey: nav,
        navigatorObservers: [observer],
        home: const Scaffold()));
    unawaited(nav.currentState!.push(popup(nav.currentContext!, 'disposing')));
    await tester.pumpAndSettle();
    expect(notifications, 1);
    observer.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(notifications, 1);
    expect(tester.takeException(), isNull);
  });
}
