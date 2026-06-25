// Tests for the `TracedDioInterceptor` opt-in adapter in
// `lib/interceptor/dio_interceptor.dart`. The interceptor is a
// drop-in `package:dio` Interceptor that records every request /
// response / error into the inspector timeline. The tests use a
// mock `HttpClientAdapter` to drive the dio lifecycle without
// touching the network.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_api_inspector/flutter_api_inspector.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_api_inspector/interceptor/dio_interceptor.dart';
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
      expect(r.name, equals('GET https://api.example.com/user'));
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
      expect(r.name, equals('POST https://api.example.com/user'));
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
}
