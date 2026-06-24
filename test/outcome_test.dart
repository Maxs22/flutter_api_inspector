// Strict TDD evidence for TASK-007: ApiTraceOutcome enum (REQ-MODEL-002).
//
// The outcome enum is the bridge between `ApiTrace.call` and the
// `ApiTraceRecord.outcome` field. The UI colors a row red when
// `outcome == error` and green when `outcome == success`
// (REQ-UI-008). `cancelled` is reserved for future use; v1 never
// produces it.

import 'package:flutter_api_inspector/src/outcome.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiTraceOutcome', () {
    test('has exactly three cases', () {
      // Pinned by REQ-MODEL-002.
      expect(ApiTraceOutcome.values, hasLength(3));
    });

    test('cases are success, error, cancelled (in order)', () {
      // The first two are the active v1 outcomes; `cancelled` is
      // reserved for future use.
      expect(
        ApiTraceOutcome.values,
        equals(<ApiTraceOutcome>[
          ApiTraceOutcome.success,
          ApiTraceOutcome.error,
          ApiTraceOutcome.cancelled,
        ]),
      );
    });

    test('success is at index 0 and cancelled is at index 2', () {
      expect(ApiTraceOutcome.success.index, 0);
      expect(ApiTraceOutcome.error.index, 1);
      expect(ApiTraceOutcome.cancelled.index, 2);
    });
  });
}
