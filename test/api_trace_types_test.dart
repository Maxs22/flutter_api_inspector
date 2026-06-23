// Strict TDD evidence for TASK-009: ApiTraceRequest and
// ApiTraceResponse (REQ-MODEL-001).
//
// Both types are immutable value objects used by `ApiTraceRecord`
// (TASK-010) and the `ApiTrace.call` execute callback (PR 2). They
// expose `const` constructors and `copyWith` helpers so the
// privacy-conscious `fromCapture` factory can redact fields
// (set them to `const {}` or `null`) without losing other fields.

import 'package:flutter_api_inspector/src/model/api_trace_request.dart';
import 'package:flutter_api_inspector/src/model/api_trace_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiTraceRequest', () {
    test('defaults to empty headers and null body', () {
      const r = ApiTraceRequest();
      expect(r.headers, isEmpty);
      expect(r.body, isNull);
    });

    test('stores headers and body', () {
      const r = ApiTraceRequest(
        headers: <String, String>{'authorization': 'Bearer x'},
        body: <String, Object?>{'q': 'orders'},
      );
      expect(r.headers, equals(<String, String>{'authorization': 'Bearer x'}));
      expect(r.body, equals(<String, Object?>{'q': 'orders'}));
    });

    test('copyWith overrides headers and preserves body', () {
      const r = ApiTraceRequest(
        headers: <String, String>{'a': '1'},
        body: 'original',
      );
      final r2 = r.copyWith(headers: const <String, String>{});
      expect(r2.headers, isEmpty);
      expect(r2.body, equals('original'));
    });

    test('copyWith overrides body and preserves headers', () {
      const r = ApiTraceRequest(
        headers: <String, String>{'a': '1'},
        body: 'original',
      );
      final r2 = r.copyWith(body: 'updated');
      expect(r2.headers, equals(<String, String>{'a': '1'}));
      expect(r2.body, equals('updated'));
    });

    test('copyWith with body: null clears the body', () {
      // The sentinel pattern lets copyWith distinguish
      // "argument omitted" from "argument is null".
      const r = ApiTraceRequest(body: 'orig');
      final r2 = r.copyWith(body: null);
      expect(r2.body, isNull);
    });
  });

  group('ApiTraceResponse', () {
    test('defaults to empty headers and null bodies', () {
      const r = ApiTraceResponse(statusCode: 200);
      expect(r.statusCode, 200);
      expect(r.requestHeaders, isEmpty);
      expect(r.responseHeaders, isEmpty);
      expect(r.requestBody, isNull);
      expect(r.responseBody, isNull);
    });

    test('stores status code, headers, and bodies', () {
      const r = ApiTraceResponse(
        statusCode: 201,
        requestHeaders: <String, String>{'content-type': 'application/json'},
        responseHeaders: <String, String>{'x-rate-limit-remaining': '99'},
        requestBody: 'req-body',
        responseBody: 'resp-body',
      );
      expect(r.statusCode, 201);
      expect(r.requestHeaders,
          equals(<String, String>{'content-type': 'application/json'}));
      expect(r.responseHeaders,
          equals(<String, String>{'x-rate-limit-remaining': '99'}));
      expect(r.requestBody, equals('req-body'));
      expect(r.responseBody, equals('resp-body'));
    });

    test('copyWith with no args returns a value-equal copy', () {
      const r = ApiTraceResponse(statusCode: 200, responseBody: 'ok');
      final r2 = r.copyWith();
      expect(r2.statusCode, 200);
      expect(r2.responseBody, equals('ok'));
    });

    test('copyWith overrides responseBody and preserves other fields', () {
      const r = ApiTraceResponse(
        statusCode: 200,
        requestHeaders: <String, String>{'a': '1'},
        responseHeaders: <String, String>{'b': '2'},
        requestBody: 'req',
        responseBody: 'orig',
      );
      final r2 = r.copyWith(responseBody: 'truncated');
      expect(r2.statusCode, 200);
      expect(r2.requestHeaders, equals(<String, String>{'a': '1'}));
      expect(r2.responseHeaders, equals(<String, String>{'b': '2'}));
      expect(r2.requestBody, equals('req'));
      expect(r2.responseBody, equals('truncated'));
    });

    test('copyWith with responseBody: null clears the response body', () {
      const r = ApiTraceResponse(statusCode: 200, responseBody: 'orig');
      final r2 = r.copyWith(responseBody: null);
      expect(r2.responseBody, isNull);
      expect(r2.statusCode, 200);
    });
  });
}
