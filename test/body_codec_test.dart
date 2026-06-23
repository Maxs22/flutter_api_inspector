// Strict TDD evidence for TASK-011: body_codec.dart (REQ-MODEL-006).
//
// The body codec is the small, pure helper that truncates response
// bodies to `ApiTraceConfig.maxResponseBodyBytes` (default 4 KB).
// The contract is asserted directly here; `ApiTraceRecord.fromCapture`
// (TASK-010) calls into `bodyCodec.truncate` for the response body.

import 'package:flutter_api_inspector/src/body_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('bodyCodec.truncate', () {
    test('null body returns null', () {
      // RED: import target missing. After GREEN, the assertion
      // is satisfied.
      expect(truncate(null, 4096), isNull);
    });

    test('String body of length <= maxBytes is returned unchanged', () {
      const s = 'hello';
      final out = truncate(s, 4096);
      expect(out, equals('hello'));
    });

    test('String body of length > maxBytes is truncated to prefix', () {
      // 10 KB string -> 4 KB result.
      final s = 'a' * 10240;
      final out = truncate(s, 4096);
      expect(out, hasLength(4096));
    });

    test('TRIANGULATE: String body truncation honors configured limit', () {
      // 1024-byte string, limit 128 -> prefix of 128 chars.
      final s = 'a' * 1024;
      final out = truncate(s, 128);
      expect(out, hasLength(128));
    });

    test('TRIANGULATE: List<int> body is truncated by byte count', () {
      final bytes = List<int>.generate(2048, (i) => i % 256);
      final out = truncate(bytes, 512);
      expect(out, isA<List<int>>());
      expect((out as List<int>), hasLength(512));
    });

    test(
        'TRIANGULATE: List<int> body of length <= maxBytes is returned unchanged',
        () {
      final bytes = <int>[1, 2, 3, 4, 5];
      final out = truncate(bytes, 16);
      expect(out, equals(<int>[1, 2, 3, 4, 5]));
    });

    test('TRIANGULATE: non-String non-bytes body is stringified and truncated',
        () {
      // A Map gets toString'd to e.g. '{a: 1}' and truncated to
      // the configured maxBytes.
      final body = <String, int>{'a': 1, 'b': 2};
      final out = truncate(body, 4096);
      expect(out, isA<String>());
      expect((out as String).length, lessThanOrEqualTo(4096));
    });

    test('TRIANGULATE: truncation at exactly maxBytes preserves length', () {
      // Boundary: length == maxBytes is unchanged.
      final s = 'a' * 4096;
      final out = truncate(s, 4096);
      expect(out, hasLength(4096));
      expect(out, equals(s));
    });

    test('TRIANGULATE: zero maxBytes truncates to empty prefix', () {
      // Edge case: maxBytes == 0 yields an empty String / List.
      expect(truncate('hello', 0), equals(''));
      expect(truncate(<int>[1, 2, 3], 0), isEmpty);
    });
  });
}
