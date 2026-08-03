// Tests for the `TracedDioInterceptor` opt-in adapter in
// `lib/interceptor/dio_interceptor.dart`. The interceptor is a
// drop-in `package:dio` Interceptor that records every request /
// response / error into the inspector timeline. The tests use a
// mock `HttpClientAdapter` to drive the dio lifecycle without
// touching the network.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart'
    show MaterialPageRoute, RouteSettings, SizedBox;
import 'package:flutter_api_inspector/flutter_api_inspector.dart';
import 'package:flutter_api_inspector/src/interceptor_coordination.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal `HttpClientAdapter` mock: returns a canned
/// [ResponseBody] for every `fetch` and remembers every
/// [RequestOptions] it sees so tests can introspect the call
/// shape (method, path, headers, etc.).
class _MockAdapter implements HttpClientAdapter {
  _MockAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions options) _handler;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() {
    ApiTrace.enabled = kDebugMode;
    ApiTrace.config = const ApiTraceConfig();
    ApiTrace.timeline.clear();
  });

  group('TracedDioInterceptor — happy path (REQ-INTERCEPTOR-001)', () {
    test('onRequest starts a pending record; onResponse completes it',
        () async {
      // RED: a 200 GET /user must produce exactly one record in
      // the timeline, with the correct method, path, status, and
      // headers. The default `ApiTraceConfig()` does not capture
      // headers (privacy-conscious default), so we widen the
      // detail set for this test only.
      //
      // Note on the recorded name: `TracedDioInterceptor` uses
      // `options.path`, which in dio 5.x is the full URL the
      // caller passed (no further resolution). Users who want
      // a path-only label supply a `nameFor` callback.
      ApiTrace.config = const ApiTraceConfig(
        details: <ApiTraceDetail>{ApiTraceDetail.full},
      );
      final adapter = _MockAdapter(
        (RequestOptions req) async => ResponseBody.fromString(
          '{"ok":true}',
          200,
          headers: <String, List<String>>{
            'content-type': <String>['application/json'],
          },
        ),
      );
      final dio = Dio(BaseOptions())
        ..httpClientAdapter = adapter
        ..interceptors.add(const TracedDioInterceptor());

      await dio.get<dynamic>('https://api.example.com/user');

      // GREEN: one record, with the expected shape.
      expect(ApiTrace.timeline.size, 1);
      final ApiTraceRecord r = ApiTrace.timeline.records.first;
      expect(r.method, equals('GET'));
      expect(r.name, equals('GET /user'));
      expect(r.statusCode, equals(200));
      expect(r.outcome, equals(ApiTraceOutcome.success));
      expect(
        r.response?.responseHeaders['content-type'],
        equals('application/json'),
      );
    });

    test('TRIANGULATE: POST with body produces a record with the same fields',
        () async {
      final adapter = _MockAdapter(
        (RequestOptions req) async => ResponseBody.fromString('created', 201),
      );
      final dio = Dio(BaseOptions())
        ..httpClientAdapter = adapter
        ..interceptors.add(const TracedDioInterceptor());

      await dio.post<dynamic>(
        'https://api.example.com/user',
        data: <String, dynamic>{'name': 'Max'},
      );

      expect(ApiTrace.timeline.size, 1);
      final ApiTraceRecord r = ApiTrace.timeline.records.first;
      expect(r.method, equals('POST'));
      expect(r.name, equals('POST /user'));
      expect(r.statusCode, equals(201));
    });

    test('TRIANGULATE: nameFor callback overrides the default label', () async {
      // The `nameFor` parameter lets callers customise the
      // timeline label (per-file/per-feature routing).
      final adapter = _MockAdapter(
        (RequestOptions req) async => ResponseBody.fromString('ok', 200),
      );
      final dio = Dio(BaseOptions())
        ..httpClientAdapter = adapter
        ..interceptors.add(
          TracedDioInterceptor(
            nameFor: (RequestOptions req) => 'CUSTOM ${req.method}',
          ),
        );

      await dio.get<dynamic>('https://api.example.com/user');

      expect(
        ApiTrace.timeline.records.first.name,
        equals('CUSTOM GET'),
      );
    });
  });

  group('TracedDioInterceptor — error path (REQ-INTERCEPTOR-002)', () {
    test('5xx response is recorded as an error outcome', () async {
      // Dio's default `validateStatus` throws on 5xx, which
      // short-circuits the interceptor and prevents the
      // response from completing the pending record. For the
      // 5xx path to flow through the interceptor (and produce
      // a record with statusCode 500), we set validateStatus
      // to accept everything and let the inspector's
      // status-code rule (REQ-API-007) promote the record to
      // an error outcome.
      final adapter = _MockAdapter(
        (RequestOptions req) async => ResponseBody.fromString(
          'boom',
          500,
        ),
      );
      final dio = Dio(
        BaseOptions(validateStatus: (int? status) => true),
      )
        ..httpClientAdapter = adapter
        ..interceptors.add(const TracedDioInterceptor());

      await dio.get<dynamic>('https://api.example.com/fail');

      expect(ApiTrace.timeline.size, 1);
      final ApiTraceRecord r = ApiTrace.timeline.records.first;
      expect(r.statusCode, equals(500));
      expect(r.outcome, equals(ApiTraceOutcome.error));
    });

    test('thrown DioException is recorded as an error without status code',
        () async {
      final adapter = _MockAdapter((RequestOptions req) async {
        throw DioException(
          requestOptions: req,
          type: DioExceptionType.connectionTimeout,
          message: 'timeout',
        );
      });
      final dio = Dio(BaseOptions())
        ..httpClientAdapter = adapter
        ..interceptors.add(const TracedDioInterceptor());

      // Swallow the rethrown exception; the interceptor's job
      // is to record, not to swallow.
      try {
        await dio.get<dynamic>('https://api.example.com/timeout');
      } on DioException {
        // Expected.
      }

      expect(ApiTrace.timeline.size, 1);
      final ApiTraceRecord r = ApiTrace.timeline.records.first;
      expect(r.statusCode, isNull);
      expect(r.outcome, equals(ApiTraceOutcome.error));
    });
  });

  group('TracedDioInterceptor — opt-in short-circuit', () {
    test('ApiTrace.enabled == false: no record is created', () async {
      ApiTrace.enabled = false;
      final adapter = _MockAdapter(
        (RequestOptions req) async => ResponseBody.fromString('ok', 200),
      );
      final dio = Dio(BaseOptions())
        ..httpClientAdapter = adapter
        ..interceptors.add(const TracedDioInterceptor());

      await dio.get<dynamic>('https://api.example.com/user');

      expect(ApiTrace.timeline.size, 0);
    });
  });

  group('TracedDioInterceptor — _collapseHeaders helper', () {
    // Smoke test: ensure the headers from a typical dio
    // ResponseHeaders map (Map<String, List<String>>) collapse
    // to the first value. The header helper is internal; we
    // exercise it indirectly via the recorded record.
    test('multi-value headers collapse to first value', () async {
      ApiTrace.config = const ApiTraceConfig(
        details: <ApiTraceDetail>{ApiTraceDetail.full},
      );
      final adapter = _MockAdapter(
        (RequestOptions req) async => ResponseBody.fromString(
          'ok',
          200,
          headers: <String, List<String>>{
            'set-cookie': <String>[
              'a=1',
              'b=2',
            ],
          },
        ),
      );
      final dio = Dio(BaseOptions())
        ..httpClientAdapter = adapter
        ..interceptors.add(const TracedDioInterceptor());

      await dio.get<dynamic>('https://api.example.com/user');

      final ApiTraceRecord r = ApiTrace.timeline.records.first;
      expect(r.response?.responseHeaders['set-cookie'], equals('a=1'));
    });
  });

  group('TracedDioInterceptor — request capture & dedup', () {
    tearDown(() {
      InterceptorCoordination.httpOverridesActive = false;
    });

    test('captures request body and headers on the record', () async {
      ApiTrace.config = const ApiTraceConfig(
        details: <ApiTraceDetail>{ApiTraceDetail.full},
      );
      final adapter = _MockAdapter(
        (RequestOptions req) async => ResponseBody.fromString('ok', 200),
      );
      final dio = Dio(BaseOptions())
        ..httpClientAdapter = adapter
        ..interceptors.add(const TracedDioInterceptor());

      await dio.post<dynamic>(
        'https://api.example.com/orders',
        data: <String, Object?>{'qty': 3},
        options: Options(headers: <String, Object?>{'x-team': 'bai'}),
      );

      final ApiTraceRecord r = ApiTrace.timeline.records.first;
      expect(r.request, isNotNull);
      expect('${r.request!.body}', contains('"qty": 3'));
      expect(r.request!.headers['x-team'], equals('bai'));
    });

    test('defers to TracedHttpOverrides when the overrides layer is active',
        () async {
      // Dio's default adapter routes through dart:io HttpClient,
      // so with TracedHttpOverrides installed the call is already
      // recorded there; recording here too would duplicate it.
      InterceptorCoordination.httpOverridesActive = true;
      final adapter = _MockAdapter(
        (RequestOptions req) async => ResponseBody.fromString('ok', 200),
      );
      final dio = Dio(BaseOptions())
        ..httpClientAdapter = adapter
        ..interceptors.add(const TracedDioInterceptor());

      await dio.get<dynamic>('https://api.example.com/user');

      expect(ApiTrace.timeline.size, 0);
    });

    test('deferToHttpOverrides: false records even when overrides are active',
        () async {
      // Escape hatch for custom adapters (mocks, http2) that
      // bypass dart:io — the overrides layer never sees those.
      InterceptorCoordination.httpOverridesActive = true;
      final adapter = _MockAdapter(
        (RequestOptions req) async => ResponseBody.fromString('ok', 200),
      );
      final dio = Dio(BaseOptions())
        ..httpClientAdapter = adapter
        ..interceptors
            .add(const TracedDioInterceptor(deferToHttpOverrides: false));

      await dio.get<dynamic>('https://api.example.com/user');

      expect(ApiTrace.timeline.size, 1);
    });
  });

  group('TracedDioInterceptor — route-scope tagging (REQ-RS-002, TASK-RS-003)',
      () {
    setUp(() {
      RouteScope.dispose();
      RouteScope.init();
    });

    tearDown(() {
      RouteScope.dispose();
    });

    Future<ApiTraceRecord> doGet() async {
      final adapter = _MockAdapter(
        (RequestOptions req) async => ResponseBody.fromString('ok', 200),
      );
      final dio = Dio(BaseOptions())
        ..httpClientAdapter = adapter
        ..interceptors.add(const TracedDioInterceptor());
      await dio.get<dynamic>('https://api.example.com/user');
      return ApiTrace.timeline.records.first;
    }

    test(
        'route A active (scopeId 1): options.extra and the record are '
        'tagged (spec scenario: Dio request tagged with route scope)',
        () async {
      // RED: with the tagging lines removed from `onRequest`,
      // `options.extra` stays empty and the record's
      // `routeScopeId`/`routeName` getters return null.
      RouteScope.onPush(MaterialPageRoute<void>(
        builder: (_) => const SizedBox.shrink(),
        settings: const RouteSettings(name: 'A'),
      ));

      final adapter = _MockAdapter(
        (RequestOptions req) async => ResponseBody.fromString('ok', 200),
      );
      final dio = Dio(BaseOptions())
        ..httpClientAdapter = adapter
        ..interceptors.add(const TracedDioInterceptor());
      await dio.get<dynamic>('https://api.example.com/user');

      // The spec scenario asserts options.extra directly.
      expect(adapter.requests.first.extra['routeScopeId'], equals(1));
      expect(adapter.requests.first.extra['routeName'], equals('A'));

      // TASK-RS-003 acceptance: "Values are forwarded to the
      // record's extra map on completion."
      final ApiTraceRecord r = ApiTrace.timeline.records.first;
      expect(r.routeScopeId, equals(1));
      expect(r.routeName, equals('A'));
    });

    test(
        'TRIANGULATE: after a push to B (scopeId 2), the request is '
        'tagged with scopeId 2 / "B"', () async {
      RouteScope.onPush(MaterialPageRoute<void>(
        builder: (_) => const SizedBox.shrink(),
        settings: const RouteSettings(name: 'A'),
      ));
      RouteScope.onPush(MaterialPageRoute<void>(
        builder: (_) => const SizedBox.shrink(),
        settings: const RouteSettings(name: 'B'),
      ));

      final r = await doGet();
      expect(r.routeScopeId, equals(2));
      expect(r.routeName, equals('B'));
    });

    test(
        'TRIANGULATE: after popping back to A, the request is tagged '
        'with scopeId 1 / "A" (spec scenario: tagged after pop)', () async {
      final routeA = MaterialPageRoute<void>(
        builder: (_) => const SizedBox.shrink(),
        settings: const RouteSettings(name: 'A'),
      );
      final routeB = MaterialPageRoute<void>(
        builder: (_) => const SizedBox.shrink(),
        settings: const RouteSettings(name: 'B'),
      );
      RouteScope.onPush(routeA);
      RouteScope.onPush(routeB);
      RouteScope.onPop(routeB);

      final r = await doGet();
      expect(r.routeScopeId, equals(1));
      expect(r.routeName, equals('A'));
    });

    test(
        'no RouteScope active (release-mode style): no crash and no '
        'routeScopeId/routeName on the record', () async {
      // Edge case (Risks table / REQ-RS-008): with RouteScope
      // disposed (no active singleton, as in a release build),
      // the interceptor must not throw and must simply omit the
      // scope tags.
      RouteScope.dispose();

      final r = await doGet();
      expect(r.routeScopeId, isNull);
      expect(r.routeName, isNull);
    });
  });
}
