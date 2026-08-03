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
import 'package:flutter/material.dart'
    show MaterialPageRoute, RouteSettings, SizedBox;
// The interceptors are exported from the main barrel — a single
// import is the whole integration story, and this test file
// exercises it the same way a consumer app would.
import 'package:flutter_api_inspector/flutter_api_inspector.dart';
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

  group('TracedHttpOverrides — body capture (REQ-INTERCEPTOR-006)', () {
    test('response body is captured when the stream is drained', () async {
      final _ServerHandle h = await _startServer(
        status: 200,
        body: '{"ok":true}',
        headers: <String, String>{'content-type': 'application/json'},
      );
      addTearDown(h.shutdown);

      ApiTrace.config = const ApiTraceConfig(
        details: <ApiTraceDetail>{ApiTraceDetail.response},
      );

      final TracedHttpClient client = TracedHttpClient();
      final HttpClientRequest req =
          await client.openUrl('GET', h.baseUri.resolve('/data'));
      final HttpClientResponse res = await req.close();
      await res.drain<void>();
      client.close();

      final ApiTraceRecord r = ApiTrace.timeline.records.first;
      expect(r.response?.responseBody, equals('{"ok":true}'));
    });

    test('body is not captured when detail level is minimal only', () async {
      final _ServerHandle h = await _startServer(body: 'secret');
      addTearDown(h.shutdown);

      ApiTrace.config = const ApiTraceConfig(
        details: <ApiTraceDetail>{ApiTraceDetail.minimal},
      );

      final TracedHttpClient client = TracedHttpClient();
      final HttpClientRequest req =
          await client.openUrl('GET', h.baseUri.resolve('/private'));
      final HttpClientResponse res = await req.close();
      await res.drain<void>();
      client.close();

      final ApiTraceRecord r = ApiTrace.timeline.records.first;
      expect(r.response, isNull);
    });

    test('body is truncated to maxResponseBodyBytes', () async {
      final _ServerHandle h = await _startServer(body: 'abcde');
      addTearDown(h.shutdown);

      ApiTrace.config = const ApiTraceConfig(
        details: <ApiTraceDetail>{ApiTraceDetail.response},
        maxResponseBodyBytes: 3,
      );

      final TracedHttpClient client = TracedHttpClient();
      final HttpClientRequest req =
          await client.openUrl('GET', h.baseUri.resolve('/big'));
      final HttpClientResponse res = await req.close();
      await res.drain<void>();
      client.close();

      final ApiTraceRecord r = ApiTrace.timeline.records.first;
      expect(r.response?.responseBody, equals('abc'));
    });
  });

  group('TracedHttpOverrides — request body capture', () {
    test('POST body lands on the record when details include request',
        () async {
      final _ServerHandle h = await _startServer();
      addTearDown(h.shutdown);

      ApiTrace.config = const ApiTraceConfig(
        details: <ApiTraceDetail>{ApiTraceDetail.full},
      );

      final TracedHttpClient client = TracedHttpClient();
      final HttpClientRequest req =
          await client.openUrl('POST', h.baseUri.resolve('/orders'));
      req.headers.contentType = ContentType.json;
      req.write('{"qty":3}');
      final HttpClientResponse res = await req.close();
      await res.drain<void>();
      client.close();

      expect(ApiTrace.timeline.size, 1);
      final ApiTraceRecord r = ApiTrace.timeline.records.first;
      expect(r.request, isNotNull);
      expect(r.request!.body, equals('{"qty":3}'));
      // The envelope the interceptor delivered carries it too.
      expect(r.response?.requestBody, equals('{"qty":3}'));
    });

    test('request body is NOT captured under the default detail set', () async {
      // Default config: {minimal, response} — request stays opt-in.
      final _ServerHandle h = await _startServer();
      addTearDown(h.shutdown);

      final TracedHttpClient client = TracedHttpClient();
      final HttpClientRequest req =
          await client.openUrl('POST', h.baseUri.resolve('/orders'));
      req.write('{"qty":3}');
      final HttpClientResponse res = await req.close();
      await res.drain<void>();
      client.close();

      final ApiTraceRecord r = ApiTrace.timeline.records.first;
      expect(r.request?.body, isNull);
      expect(r.response?.requestBody, isNull);
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

  group('TracedHttpOverrides — route-scope tagging (REQ-RS-003, TASK-RS-004)',
      () {
    setUp(() {
      RouteScope.dispose();
      RouteScope.init();
    });

    tearDown(() {
      RouteScope.dispose();
    });

    test(
        'route A active: the resulting ApiTraceRecord is tagged with '
        'routeScopeId/routeName (spec scenario: HttpClient request '
        'tagged with route scope)', () async {
      // RED: with the tagging block removed from `openUrl`, the
      // record's routeScopeId/routeName getters return null.
      RouteScope.onPush(MaterialPageRoute<void>(
        builder: (_) => const SizedBox.shrink(),
        settings: const RouteSettings(name: 'A'),
      ));

      final _ServerHandle h = await _startServer();
      addTearDown(h.shutdown);

      final TracedHttpClient client = TracedHttpClient();
      final HttpClientRequest req =
          await client.openUrl('GET', h.baseUri.resolve('/scoped'));
      final HttpClientResponse res = await req.close();
      await res.drain<void>();
      client.close();

      final ApiTraceRecord r = ApiTrace.timeline.records.first;
      expect(r.routeScopeId, equals(1));
      expect(r.routeName, equals('A'));
    });

    test(
        'TRIANGULATE: after a push to B (scopeId 2), the record is '
        'tagged with scopeId 2 / "B"', () async {
      RouteScope.onPush(MaterialPageRoute<void>(
        builder: (_) => const SizedBox.shrink(),
        settings: const RouteSettings(name: 'A'),
      ));
      RouteScope.onPush(MaterialPageRoute<void>(
        builder: (_) => const SizedBox.shrink(),
        settings: const RouteSettings(name: 'B'),
      ));

      final _ServerHandle h = await _startServer();
      addTearDown(h.shutdown);

      final TracedHttpClient client = TracedHttpClient();
      final HttpClientRequest req =
          await client.openUrl('GET', h.baseUri.resolve('/scoped'));
      final HttpClientResponse res = await req.close();
      await res.drain<void>();
      client.close();

      final ApiTraceRecord r = ApiTrace.timeline.records.first;
      expect(r.routeScopeId, equals(2));
      expect(r.routeName, equals('B'));
    });

    test(
        'no RouteScope active (release-mode style): no crash and no '
        'routeScopeId/routeName on the record', () async {
      // Edge case (Risks table / REQ-RS-008): with RouteScope
      // disposed, openUrl must not throw and must simply omit the
      // scope tags.
      RouteScope.dispose();

      final _ServerHandle h = await _startServer();
      addTearDown(h.shutdown);

      final TracedHttpClient client = TracedHttpClient();
      final HttpClientRequest req =
          await client.openUrl('GET', h.baseUri.resolve('/unscoped'));
      final HttpClientResponse res = await req.close();
      await res.drain<void>();
      client.close();

      final ApiTraceRecord r = ApiTrace.timeline.records.first;
      expect(r.routeScopeId, isNull);
      expect(r.routeName, isNull);
    });
  });
}
