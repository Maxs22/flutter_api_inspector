// Example app for the flutter_api_inspector package.
//
// This app demonstrates manual API instrumentation via [ApiTrace.call]
// across TWO screens, so the overlay's "Routes" tab has more than one
// group to show (TASK-RS-010, route-scoped-network-inspector).
//
//   * **Home screen** (`/home`) — has a stub call button and a button
//     that navigates to the Detail screen.
//   * **Detail screen** (`/detail`) — has its own stub call button and
//     (debug-only) a real call to `https://httpbin.org/get`.
//
// Both screens tag their `ApiTrace.call` with the active [RouteScope]
// (`routeScopeId` + `routeName` in `extra`), the same convention the
// package's own `TracedDioInterceptor` / `TracedHttpOverrides` use
// internally. This is the documented pattern for apps that use manual
// instrumentation (per `openspec/AGENTS.md` rule 7 — no auto-interceptor
// in this example) but still want their calls grouped by screen in the
// "Routes" tab: read `RouteScope.current` at the call site and forward
// it through `extra`.
//
// The app is wrapped with [ApiTrace.runApp], which auto-injects
// [RouteScopeObserver] into the `MaterialApp`'s `navigatorObservers`
// (debug-only), so both screens' visits are tracked automatically —
// no extra setup needed beyond naming the routes.
//
// Run: `flutter run` from the `example/` directory.

import 'dart:io' show HttpClient;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_api_inspector/flutter_api_inspector.dart';

void main() => ApiTrace.runApp(_buildExampleApp());

/// Builds the root [MaterialApp] of the example.
///
/// Pass the [MaterialApp] directly to [ApiTrace.runApp] so the package can
/// inject [RouteScopeObserver] into this app's navigator and show named route
/// groups (`/home`, `/detail`) in the overlay's Routes tab.
MaterialApp _buildExampleApp() {
  return MaterialApp(
    title: 'flutter_api_inspector example',
    theme: ThemeData(
      colorSchemeSeed: Colors.indigo,
      useMaterial3: true,
    ),
    initialRoute: '/home',
    routes: <String, WidgetBuilder>{
      '/home': (_) => const _HomeScreen(),
      '/detail': (_) => const _DetailScreen(),
    },
  );
}

/// Builds the `extra` map that tags an `ApiTrace.call` with the route
/// active at dispatch time — the manual-instrumentation equivalent of
/// what `TracedDioInterceptor` / `TracedHttpOverrides` do automatically.
/// Returns an empty map if route-scope tracking is inactive (e.g. a
/// release build, where [RouteScope.current] is always null).
Map<String, Object?> _routeScopeExtra() {
  final scope = RouteScope.current;
  return <String, Object?>{
    if (scope != null) 'routeScopeId': scope.scopeId,
    if (scope != null) 'routeName': scope.routeName,
  };
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  Future<void> _runStubCall(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final id = await ApiTrace.call(
      'home.stub',
      method: 'GET',
      url: Uri.parse('https://example.com/home/stub'),
      extra: _routeScopeExtra(),
      execute: () async {
        return const ApiTraceResponse(statusCode: 200);
      },
    );
    messenger.showSnackBar(
      SnackBar(content: Text('Home stub call recorded: id=$id')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Tap a button to record an API call, then open the '
                'debug-only overlay (FAB) and check the "Routes" tab.',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              key: const Key('home-stub-button'),
              icon: const Icon(Icons.bug_report),
              label: const Text('Run stub call'),
              onPressed: () => _runStubCall(context),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              key: const Key('go-to-detail-button'),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Go to Detail screen'),
              onPressed: () => Navigator.of(context).pushNamed('/detail'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailScreen extends StatelessWidget {
  const _DetailScreen();

  Future<void> _runStubCall(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final id = await ApiTrace.call(
      'detail.orders',
      method: 'GET',
      url: Uri.parse('https://example.com/detail/orders'),
      extra: _routeScopeExtra(),
      execute: () async {
        return const ApiTraceResponse(statusCode: 200);
      },
    );
    messenger.showSnackBar(
      SnackBar(content: Text('Detail stub call recorded: id=$id')),
    );
  }

  Future<void> _runRealCall(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final id = await ApiTrace.call(
      'detail.httpbin.get',
      method: 'GET',
      url: Uri.parse('https://httpbin.org/get'),
      // Widen the capture to {headers, response} so the overlay
      // shows the response body and headers for this one call only.
      detailOverride: const <ApiTraceDetail>{
        ApiTraceDetail.headers,
        ApiTraceDetail.response,
      },
      extra: _routeScopeExtra(),
      execute: () async {
        // Use dart:io's HttpClient directly — no package:http,
        // no package:dio (per AGENTS.md rule 7).
        final client = HttpClient();
        try {
          final request = await client.getUrl(
            Uri.parse('https://httpbin.org/get'),
          );
          final response = await request.close();
          // Drain the response body so the connection is released
          // back to the pool. We don't surface the body in the
          // captured response (the package truncates to the
          // configured maxResponseBodyBytes); the example just
          // wants the status code.
          await response.drain<void>();
          return ApiTraceResponse(
            statusCode: response.statusCode,
          );
        } finally {
          client.close(force: true);
        }
      },
    );
    messenger.showSnackBar(
      SnackBar(content: Text('Detail real call recorded: id=$id')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'This screen\'s calls show up under a separate '
                '"Detail" group in the Routes tab.',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              key: const Key('detail-stub-button'),
              icon: const Icon(Icons.bug_report),
              label: const Text('Run stub call'),
              onPressed: () => _runStubCall(context),
            ),
            const SizedBox(height: 12),
            // The Real button is hidden in release builds. The
            // kDebugMode gate keeps the example deterministic
            // offline (per the task brief: "gated by kDebugMode").
            if (kDebugMode) ...<Widget>[
              ElevatedButton.icon(
                key: const Key('detail-real-button'),
                icon: const Icon(Icons.cloud),
                label: const Text('Run real call to httpbin'),
                onPressed: () => _runRealCall(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
