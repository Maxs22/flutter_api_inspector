// Contract test for the public barrel: a project that imports ONLY
// `package:flutter_api_inspector/flutter_api_inspector.dart` must
// reach the full public surface — including both automatic
// interceptors. This file deliberately has NO sub-path imports.

import 'dart:io' show HttpOverrides;

import 'package:dio/dio.dart' show Interceptor;
import 'package:flutter_api_inspector/flutter_api_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('barrel exposes TracedDioInterceptor', () {
    expect(const TracedDioInterceptor(), isA<Interceptor>());
  });

  test('barrel exposes TracedHttpOverrides and TracedHttpClient', () {
    // On the VM (this test) the conditional export resolves to the
    // real dart:io implementation.
    expect(TracedHttpOverrides(), isA<HttpOverrides>());
    expect(TracedHttpClient(), isNotNull);
  });

  test('barrel exposes the core API surface', () {
    expect(ApiTrace.config, isA<ApiTraceConfig>());
    expect(const ApiTraceResponse(statusCode: 200), isA<ApiTraceResponse>());
    expect(ApiTraceDetail.values, isNotEmpty);
    expect(ApiTraceOutcome.values, isNotEmpty);
  });

  test('barrel exposes forceEnabled on ApiTrace', () {
    expect(ApiTrace.forceEnabled, isFalse);
    ApiTrace.forceEnabled = true;
    expect(ApiTrace.forceEnabled, isTrue);
    expect(ApiTrace.enabled, isTrue);
    ApiTrace.forceEnabled = false;
  });
}
