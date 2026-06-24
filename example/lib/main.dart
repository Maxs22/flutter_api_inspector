// Example app for the flutter_api_inspector package.
//
// This app demonstrates manual API instrumentation via [ApiTrace.call].
// Two buttons are exposed:
//
//   * **Run stub call** — synchronous, returns a fake [ApiTraceResponse]
//     with `statusCode == 200`. Works offline and is deterministic in
//     both debug and release builds.
//   * **Run real call to httpbin** — one real call to
//     `https://httpbin.org/get` using `dart:io`'s [HttpClient]
//     directly (no `package:http`, no `package:dio`). The button is
//     gated by [kDebugMode] and is hidden in release builds so the
//     example is deterministic offline.
//
// The app is wrapped with [ApiTrace.runApp] so the debug-only
// overlay (floating action button + timeline panel + detail screen)
// mounts automatically under [kDebugMode].
//
// Run: `flutter run` from the `example/` directory.

import 'dart:io' show HttpClient;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_api_inspector/flutter_api_inspector.dart';

void main() => ApiTrace.runApp(const ExampleApp());

/// The root [MaterialApp] of the example.
///
/// The home screen ([_ExampleHome]) exposes the two trace buttons.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_api_inspector example',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const _ExampleHome(),
    );
  }
}

class _ExampleHome extends StatelessWidget {
  const _ExampleHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_api_inspector example'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Tap a button to record an API call.\n'
                'The debug-only overlay (FAB) appears automatically in debug builds.',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              key: const Key('stub-button'),
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
                key: const Key('real-button'),
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

  Future<void> _runStubCall(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final id = await ApiTrace.call(
      'stub',
      method: 'GET',
      url: Uri.parse('https://example.com/stub'),
      // The default config (details: {ApiTraceDetail.minimal}) applies,
      // so request and response are nulled by the privacy default.
      // The id is returned so the call site can correlate logs.
      execute: () async {
        return const ApiTraceResponse(statusCode: 200);
      },
    );
    messenger.showSnackBar(
      SnackBar(content: Text('Stub call recorded: id=$id')),
    );
  }

  Future<void> _runRealCall(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final id = await ApiTrace.call(
      'httpbin.get',
      method: 'GET',
      url: Uri.parse('https://httpbin.org/get'),
      // Widen the capture to {headers, response} so the overlay
      // shows the response body and headers for this one call only.
      detailOverride: const <ApiTraceDetail>{
        ApiTraceDetail.headers,
        ApiTraceDetail.response,
      },
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
      SnackBar(content: Text('Real call recorded: id=$id')),
    );
  }
}
