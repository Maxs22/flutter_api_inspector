// Strict TDD evidence for TASK-006: ApiTraceDetail enum (REQ-API-004).
//
// The enum shape (five values, ordered from least to most detail) is
// locked by REQ-API-004 and the design's `ApiTraceDetail` enum
// section. The default `ApiTraceConfig.details == {ApiTraceDetail.minimal}`
// invariant (REQ-MODEL-005) depends on `ApiTraceDetail.minimal`
// existing with the expected index.

import 'package:flutter_api_inspector/src/detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiTraceDetail', () {
    test('has exactly five values', () {
      // Pinned by REQ-API-004: minimal, headers, request, response, full.
      expect(ApiTraceDetail.values, hasLength(5));
    });

    test('values are minimal, headers, request, response, full (in order)', () {
      // Pinned by REQ-API-004: ordered from least to most detail.
      expect(
        ApiTraceDetail.values,
        equals(<ApiTraceDetail>[
          ApiTraceDetail.minimal,
          ApiTraceDetail.headers,
          ApiTraceDetail.request,
          ApiTraceDetail.response,
          ApiTraceDetail.full,
        ]),
      );
    });

    test('full is at index 4 and minimal is at index 0', () {
      // The order is part of the contract; do not rely on iteration
      // order in downstream code.
      expect(ApiTraceDetail.full.index, 4);
      expect(ApiTraceDetail.minimal.index, 0);
    });
  });
}
