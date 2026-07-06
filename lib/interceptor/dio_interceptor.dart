// ---------------------------------------------------------------------------
// TracedDioInterceptor: drop-in `package:dio` interceptor that
// records every request / response / error into the inspector
// timeline.
//
// This file is in the package source so that users get a tested,
// maintained implementation. It is exported from the main barrel
// (single-import story); the direct sub-path import keeps working:
//
// ```dart
// import 'package:dio/dio.dart';
// import 'package:flutter_api_inspector/flutter_api_inspector.dart';
//
// final dio = Dio(BaseOptions(...))
//   ..interceptors.add(TracedDioInterceptor());
// ```
//
// The package's own `pubspec.yaml` currently declares `dio` as a
// regular dependency (a separate `flutter_api_inspector_dio`
// package is planned for v0.2 to remove it from the public
// dependency graph — see the pubspec note).
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:flutter_api_inspector/src/api_trace.dart';
import 'package:flutter_api_inspector/src/interceptor_coordination.dart';
import 'package:flutter_api_inspector/src/model/api_trace_response.dart';

/// `dio` [Interceptor] that records every request into the
/// inspector timeline. The interceptor hooks the three `dio`
/// lifecycle callbacks:
///
/// - `onRequest`: starts a pending record (via [ApiTrace.call])
///   and stashes a [Completer] on the request `extra` map.
/// - `onResponse`: completes the stashed completer with the
///   final [Response], which causes the pending record to be
///   appended to the timeline with status + duration.
/// - `onError`: completes the completer with the [DioException]
///   so the record carries the failure.
class TracedDioInterceptor extends Interceptor {
  /// Creates the interceptor. The optional [nameFor] callback
  /// lets callers customize the timeline label (default:
  /// `"<METHOD> <path>"`). The callback receives the [RequestOptions]
  /// so the caller can use headers, query parameters, etc.
  const TracedDioInterceptor({this.nameFor, this.deferToHttpOverrides = true});

  final String Function(RequestOptions options)? nameFor;

  /// When `true` (the default) and a `TracedHttpOverrides` has been
  /// installed in this isolate, this interceptor records nothing:
  /// Dio's default adapter routes through `dart:io HttpClient`, so
  /// the overrides layer already captures the call and recording
  /// here would produce a duplicate timeline entry.
  ///
  /// Set to `false` when Dio uses a custom [HttpClientAdapter]
  /// (mocks, http2) that bypasses `dart:io` — in that case the
  /// overrides layer never sees the request and this interceptor
  /// must record it.
  final bool deferToHttpOverrides;

  String _label(RequestOptions options) =>
      nameFor != null ? nameFor!(options) : '${options.method} ${options.uri.path}';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (!ApiTrace.enabled ||
        (deferToHttpOverrides && InterceptorCoordination.httpOverridesActive)) {
      // Either tracing is off, or TracedHttpOverrides is installed
      // and will record this request at the dart:io layer —
      // recording here too would duplicate the timeline entry.
      handler.next(options);
      return;
    }
    final completer = Completer<Response<dynamic>>();
    options.extra['_apiTraceCompleter'] = completer;
    // Snapshot request data at request time: `options.data` and
    // `options.headers` may be mutated by later interceptors, and
    // the record must reflect what this request carried.
    final requestBody = _encodeBody(options.data);
    final requestHeaders = <String, String>{
      for (final MapEntry<String, dynamic> e in options.headers.entries)
        e.key: '${e.value}',
    };
    // Fire-and-forget: ApiTrace.call resolves when the completer
    // completes (i.e. when onResponse or onError fires). We do
    // not await it because the interceptor must return
    // synchronously to `handler.next(options)`.
    unawaited(
      ApiTrace.call(
        _label(options),
        method: options.method,
        url: options.uri,
        execute: () async {
          final response = await completer.future;
          return ApiTraceResponse(
            statusCode: response.statusCode ?? 0,
            requestHeaders: requestHeaders,
            responseHeaders: _collapseHeaders(response.headers.map),
            requestBody: requestBody,
            responseBody: _encodeBody(response.data),
          );
        },
      ),
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final completer = response.requestOptions.extra.remove(
      '_apiTraceCompleter',
    ) as Completer<Response<dynamic>>?;
    if (completer != null && !completer.isCompleted) {
      completer.complete(response);
    }
    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    final completer = err.requestOptions.extra.remove(
      '_apiTraceCompleter',
    ) as Completer<Response<dynamic>>?;
    if (completer != null && !completer.isCompleted) {
      final serverResponse = err.response;
      if (serverResponse != null) {
        // Server returned 4xx/5xx — complete normally so the body is
        // captured. _deriveOutcome marks the record ERROR via statusCode.
        completer.complete(serverResponse);
      } else {
        // Network error, timeout, cancel — no body; record the exception.
        completer.completeError(err, err.stackTrace);
      }
    }
    handler.next(err);
  }
}

/// Collapse `dio`'s `Map<String, List<String>>` headers to
/// `Map<String, String>` for the inspector. Takes the first
/// value of each header (sufficient for status / content-type
/// display).
Map<String, String> _collapseHeaders(Map<String, List<String>> raw) {
  final out = <String, String>{};
  raw.forEach((name, values) {
    if (values.isNotEmpty) out[name] = values.first;
  });
  return out;
}

/// Encode a Dio response body to a readable string.
/// Maps and Lists (parsed JSON) are pretty-printed; Strings
/// are returned as-is; null stays null.
String? _encodeBody(Object? data) {
  if (data == null) return null;
  if (data is String) return data;
  try {
    return const JsonEncoder.withIndent('  ').convert(data);
  } catch (_) {
    return data.toString();
  }
}
