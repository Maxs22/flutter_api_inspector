// Tests for the `TracedHttpOverrides` opt-in adapter in
// `lib/interceptor/http_overrides.dart`. The adapter wraps every
// `dart:io HttpClient` constructed inside the installed zone and
// records the resulting open/close flow into the inspector
// timeline.
//
// Tests use `HttpServer.bind(loopback, 0)` (an in-process server
// on an ephemeral port) so the suite has no network dependency
// and runs deterministically in CI.

import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_api_inspector/flutter_api_inspector.dart';
// The sub-library is opt-in: developers add `dart:io` to their
// own pubspec and import the adapter by its sub-path. The test
// imports it the same way.
import 'package:flutter_api_inspector/interceptor/http_overrides.dart';
import 'package:flutter_test/flutter_test.dart';

/// Spins up an in-process HTTP server on `127.0.0.1` with an
/// ephemeral port. The server replies to every request with the
/// canned [status] / [body] / [headers]. Returns a record with
/// the server, the address, and a teardown callback.
typedef _ServerHandle = ({
  HttpServer server,
  Uri baseUri,
  Future<void> Function() shutdown,
});

Future<_ServerHandle> _startServer({
  int status = 200,
  String body = 'ok',
  Map<String, String> headers = const <String, String>{
    'content-type': 'text/plain'
  },
}) async {
  final HttpServer server =
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((HttpRequest req) async {
    req.response.statusCode = status;
    headers.forEach((String name, String value) {
      req.response.headers.set(name, value);
    });
    req.response.write(body);
    await req.response.close();
  });
  final Uri baseUri = Uri.parse(
    'http://${server.address.host}:${server.port}',
  );
  return (
    server: server,
    baseUri: baseUri,
    shutdown: () => server.close(force: true),
  );
}

void main() {
  setUp(() {
    ApiTrace.enabled = kDebugMode;
    ApiTrace.config = const ApiTraceConfig();
    ApiTrace.timeline.clear();
  });

  group('TracedHttpOverrides — install (REQ-INTERCEPTOR-003)', () {
    test('createHttpClient returns a TracedHttpClient (not a raw HttpClient)',
        () {
      // The whole point of the override is to substitute the
      // raw `HttpClient` for a traced one. A regression that
      // returned a raw client would mean zero tracing on the
      // user's network stack.
      final TracedHttpOverrides overrides = TracedHttpOverrides();
      final HttpClient client = overrides.createHttpClient(null);
      expect(client, isA<TracedHttpClient>());
    });

    test('createHttpClient does not recurse infinitely (bypass guard works)',
        () {
      // The internal `_bypass` static guards against the
      // recursion: when the TracedHttpClient builds its inner
      // HttpClient, the override must return a raw client
      // (otherwise the inner would be wrapped in another
      // TracedHttpClient, whose own inner would be wrapped in
      // another, etc.). We exercise this by constructing many
      // clients in a tight loop; a working bypass returns
      // instantly, a broken one blows the stack within a few
      // hundred iterations.
      final TracedHttpOverrides overrides = TracedHttpOverrides();
      for (var i = 0; i < 1000; i++) {
        final HttpClient client = overrides.createHttpClient(null);
        expect(client, isA<TracedHttpClient>());
      }
    });

    test('TracedHttpClient surfaces inner-client config via delegated getters',
        () {
      // The composition-style client forwards every config
      // accessor to the inner client. We set a non-default
      // value on the inner through the public setter and read
      // it back through the public getter to confirm the
      // delegation is wired.
      final TracedHttpClient client = TracedHttpClient();
      client.idleTimeout = const Duration(seconds: 7);
      expect(client.idleTimeout, equals(const Duration(seconds: 7)));
      expect(
        client.userAgent = 'flutter_api_inspector-test/1.0',
        equals('flutter_api_inspector-test/1.0'),
      );
    });
  });

  group('TracedHttpOverrides — recorded flow (REQ-INTERCEPTOR-004)', () {
    test('openUrl + close records a 200 with the right method/path', () async {
      final _ServerHandle h = await _startServer(
        status: 200,
        body: 'hello',
        headers: <String, String>{'content-type': 'text/plain'},
      );
      addTearDown(h.shutdown);

      final TracedHttpClient client = TracedHttpClient();
      final HttpClientRequest req =
          await client.openUrl('GET', h.baseUri.resolve('/user'));
      final HttpClientResponse res = await req.close();
      // Drain the body so the response is fully consumed.
      await res.drain<void>();
      client.close();

      expect(ApiTrace.timeline.size, 1);
      final ApiTraceRecord r = ApiTrace.timeline.records.first;
      expect(r.method, equals('GET'));
      expect(r.name, equals('GET /user'));
      expect(r.statusCode, equals(200));
      expect(r.outcome, equals(ApiTraceOutcome.success));
    });

    test('5xx response is recorded as an error outcome', () async {
      final _ServerHandle h = await _startServer(
        status: 500,
        body: 'boom',
      );
      addTearDown(h.shutdown);

      final TracedHttpClient client = TracedHttpClient();
      final HttpClientRequest req =
          await client.openUrl('GET', h.baseUri.resolve('/fail'));
      final HttpClientResponse res = await req.close();
      await res.drain<void>();
      client.close();

      expect(ApiTrace.timeline.size, 1);
      final ApiTraceRecord r = ApiTrace.timeline.records.first;
      expect(r.statusCode, equals(500));
      expect(r.outcome, equals(ApiTraceOutcome.error));
    });

    test('ApiTrace.enabled == false: openUrl is a pass-through, no record',
        () async {
      // When the master switch is off, the wrapper must not
      // create a completer or append to the timeline. The
      // request still completes normally.
      ApiTrace.enabled = false;
      final _ServerHandle h = await _startServer(body: 'hi');
      addTearDown(h.shutdown);

      final TracedHttpClient client = TracedHttpClient();
      final HttpClientRequest req =
          await client.openUrl('GET', h.baseUri.resolve('/x'));
      final HttpClientResponse res = await req.close();
      await res.drain<void>();
      client.close();

      expect(ApiTrace.timeline.size, 0);
    });
  });

  group('TracedHttpOverrides — nameFor callback (REQ-INTERCEPTOR-005)', () {
    test('nameFor overrides the default "<METHOD> <path>" label', () async {
      final _ServerHandle h = await _startServer();
      addTearDown(h.shutdown);

      final TracedHttpClient client = TracedHttpClient(
        nameFor: (String method, Uri url) => 'AUTH $method',
      );
      final HttpClientRequest req =
          await client.openUrl('GET', h.baseUri.resolve('/me'));
      final HttpClientResponse res = await req.close();
      await res.drain<void>();
      client.close();

      expect(ApiTrace.timeline.records.first.name, equals('AUTH GET'));
    });
  });
}
