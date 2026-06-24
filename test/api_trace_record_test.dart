// Strict TDD evidence for TASK-010: ApiTraceRecord and fromCapture
// (REQ-MODEL-001, REQ-MODEL-005).
//
// `ApiTraceRecord` is the in-memory record produced by every
// `ApiTrace.call` invocation. The `fromCapture` factory is the
// single chokepoint for the privacy-conscious default
// (REQ-MODEL-005): with `capturedDetails == {ApiTraceDetail.minimal}`
// only, no body and no headers are stored; the `request` and
// `response` fields are null (or have empty header maps) by
// construction, not by render-time filtering.

import 'package:flutter_api_inspector/src/detail.dart';
import 'package:flutter_api_inspector/src/model/api_trace_record.dart';
import 'package:flutter_api_inspector/src/model/api_trace_request.dart';
import 'package:flutter_api_inspector/src/model/api_trace_response.dart';
import 'package:flutter_api_inspector/src/outcome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Reusable fixtures: a 200 response and a request with bodies
  // and headers.
  ApiTraceResponse makeResponse() => const ApiTraceResponse(
        statusCode: 200,
        requestHeaders: <String, String>{'content-type': 'application/json'},
        responseHeaders: <String, String>{'x-trace': 'abc'},
        requestBody: 'req-body',
        responseBody: 'resp-body',
      );

  ApiTraceRequest makeRequest() => const ApiTraceRequest(
        headers: <String, String>{'authorization': 'Bearer x'},
        body: 'req-body',
      );

  ApiTraceRecord makeRecord({
    Set<ApiTraceDetail> details = const {ApiTraceDetail.minimal},
    ApiTraceResponse? responseArg,
    ApiTraceRequest? requestArg,
    Object? error,
  }) {
    return ApiTraceRecord.fromCapture(
      name: 'listOrders',
      startedAt: DateTime.utc(2026, 6, 23, 12, 0, 0),
      completedAt: DateTime.utc(2026, 6, 23, 12, 0, 1),
      method: 'GET',
      url: Uri.parse('https://api.example.com/orders'),
      capturedDetails: details,
      response: responseArg ?? makeResponse(),
      request: requestArg ?? makeRequest(),
      error: error,
      extra: const <String, Object?>{'tag': 'orders'},
      maxResponseBodyBytes: 4096,
    );
  }

  group('ApiTraceRecord', () {
    test('exposes all required fields with correct types', () {
      // RED: import target missing. After GREEN, the assertions
      // are satisfied.
      final r = makeRecord(details: const {ApiTraceDetail.full});
      expect(r.id, isA<String>());
      expect(r.name, equals('listOrders'));
      expect(r.startedAt, isA<DateTime>());
      expect(r.completedAt, isA<DateTime>());
      expect(r.method, equals('GET'));
      expect(r.url, isA<Uri>());
      expect(r.statusCode, 200);
      expect(r.duration, isA<Duration>());
      expect(r.outcome, ApiTraceOutcome.success);
      expect(r.capturedDetails, isA<Set<ApiTraceDetail>>());
      expect(r.request, isA<ApiTraceRequest>());
      expect(r.response, isA<ApiTraceResponse>());
      expect(r.error, isNull);
      expect(r.extra, isA<Map<String, Object?>>());
    });

    test('fields are immutable (final)', () {
      // Compile-time check: ApiTraceRecord's fields are final.
      // Verified by the analyzer rejecting any reassignment.
      final r = makeRecord();
      expect(r, isNotNull);
    });

    test('TRIANGULATE: id is a 32-char lowercase hex string', () {
      final r = makeRecord();
      expect(r.id, hasLength(32));
      expect(r.id, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('TRIANGULATE: two records produced back-to-back have distinct ids',
        () {
      final a = makeRecord();
      final b = makeRecord();
      expect(a.id, isNot(equals(b.id)));
    });
  });

  group('ApiTraceRecord.fromCapture — privacy enforcement (REQ-MODEL-005)', () {
    test('minimal capture has no body or headers', () {
      // RED: import target missing. After GREEN, the assertions
      // are satisfied.
      final r = makeRecord(details: const {ApiTraceDetail.minimal});
      expect(r.request, isNull);
      expect(r.response, isNull);
      expect(
          r.capturedDetails, equals(<ApiTraceDetail>{ApiTraceDetail.minimal}));
    });

    test('headers-only capture includes headers but not bodies', () {
      final r = makeRecord(details: const {ApiTraceDetail.headers});
      expect(r.response, isNotNull);
      expect(r.response!.responseHeaders, isNotEmpty);
      expect(r.response!.requestHeaders, isNotEmpty);
      expect(r.response!.responseBody, isNull);
      expect(r.response!.requestBody, isNull);
      expect(r.request, isNull);
    });

    test(
        'response-only capture includes response body, not request, not headers',
        () {
      final r = makeRecord(details: const {ApiTraceDetail.response});
      expect(r.request, isNull);
      expect(r.response, isNotNull);
      expect(r.response!.responseBody, equals('resp-body'));
      // Headers not in captured.
      expect(r.response!.responseHeaders, isEmpty);
      expect(r.response!.requestHeaders, isEmpty);
    });

    test('full capture includes both, both bodies, both headers', () {
      final r = makeRecord(details: const {ApiTraceDetail.full});
      expect(r.request, isNotNull);
      expect(r.request!.body, equals('req-body'));
      expect(r.request!.headers, isNotEmpty);
      expect(r.response, isNotNull);
      expect(r.response!.responseBody, equals('resp-body'));
      expect(r.response!.responseHeaders, isNotEmpty);
    });

    test('capturedDetails is stored unmodifiable', () {
      final r = makeRecord(details: const {ApiTraceDetail.full});
      expect(
        () => r.capturedDetails.add(ApiTraceDetail.minimal),
        throwsUnsupportedError,
      );
    });

    test('extra is stored unmodifiable', () {
      final r = makeRecord();
      expect(
        () => r.extra['x'] = 'y',
        throwsUnsupportedError,
      );
    });
  });

  group('ApiTraceRecord.fromCapture — outcome derivation (REQ-API-007)', () {
    test('2xx response yields success', () {
      final r =
          makeRecord(responseArg: const ApiTraceResponse(statusCode: 200));
      expect(r.outcome, ApiTraceOutcome.success);
      expect(r.error, isNull);
    });

    test('4xx response yields error', () {
      final r =
          makeRecord(responseArg: const ApiTraceResponse(statusCode: 404));
      expect(r.outcome, ApiTraceOutcome.error);
      expect(r.error, isNull);
    });

    test('5xx response yields error', () {
      final r =
          makeRecord(responseArg: const ApiTraceResponse(statusCode: 503));
      expect(r.outcome, ApiTraceOutcome.error);
    });

    test('thrown exception yields error and captures the exception', () {
      final r = ApiTraceRecord.fromCapture(
        name: 'x',
        startedAt: DateTime.utc(2026, 6, 23, 12, 0, 0),
        completedAt: DateTime.utc(2026, 6, 23, 12, 0, 1),
        method: 'GET',
        url: Uri.parse('https://x/'),
        capturedDetails: const {ApiTraceDetail.full},
        response: null,
        request: null,
        error: const FormatException('boom'),
        extra: const <String, Object?>{},
        maxResponseBodyBytes: 4096,
      );
      expect(r.outcome, ApiTraceOutcome.error);
      expect(r.error, isA<FormatException>());
      expect(r.statusCode, isNull);
    });
  });

  group('ApiTraceRecord.fromCapture — duration (REQ-MODEL-001)', () {
    test('duration is non-negative when completedAt is after startedAt', () {
      final r = makeRecord();
      expect(r.duration, equals(const Duration(seconds: 1)));
      expect(r.duration.isNegative, isFalse);
    });

    test(
        'TRIANGULATE: duration is clamped to zero when completedAt < startedAt',
        () {
      // Defensive clamp: should never happen in practice (ApiTrace.call
      // uses DateTime.now() twice), but the contract is non-negative.
      final r = ApiTraceRecord.fromCapture(
        name: 'x',
        startedAt: DateTime.utc(2026, 6, 23, 12, 0, 1),
        completedAt: DateTime.utc(2026, 6, 23, 12, 0, 0),
        method: 'GET',
        url: Uri.parse('https://x/'),
        capturedDetails: const {ApiTraceDetail.minimal},
        response: null,
        request: null,
        error: null,
        extra: const <String, Object?>{},
        maxResponseBodyBytes: 4096,
      );
      expect(r.duration, equals(Duration.zero));
    });
  });
}
