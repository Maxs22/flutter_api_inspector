// ---------------------------------------------------------------------------
// TracedDioInterceptor: drop-in `package:dio` interceptor that
// records every request / response / error into the inspector
// timeline.
//
// This file is in the package source so that users get a tested,
// maintained implementation. It is NOT exported from the main
// barrel because adding `package:dio` as a runtime dep of the
// inspector would force every user to pull in `dio`. Users who
// want this interceptor add `dio` to their own `pubspec.yaml`
// and import it directly:
//
// ```dart
// import 'package:dio/dio.dart';
// import 'package:flutter_api_inspector/interceptor/dio_interceptor.dart';
//
// final dio = Dio(BaseOptions(...))
//   ..interceptors.add(TracedDioInterceptor());
// ```
//
// The package's own `pubspec.yaml` declares `dio` as a
// `dev_dependency` so the file is type-checked and tested
// without polluting the public dependency graph.
// ---------------------------------------------------------------------------

import 'dart:async';

// `package:dio` is a dev_dependency of this package (see
// pubspec.yaml justification). Users of `TracedDioInterceptor`
// add `dio` to their own `pubspec.yaml`; this opt-in adapter
// file is the only place in the package source that
// references `package:dio`, so the rule
// `depend_on_referenced_packages` is intentionally suppressed.
// ignore: depend_on_referenced_packages
import 'package:dio/dio.dart';

import 'package:flutter_api_inspector/src/api_trace.dart';
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
  const TracedDioInterceptor({this.nameFor});

  final String Function(RequestOptions options)? nameFor;

  String _label(RequestOptions options) =>
      nameFor != null ? nameFor!(options) : '${options.method} ${options.path}';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (!ApiTrace.enabled) {
      handler.next(options);
      return;
    }
    final completer = Completer<Response<dynamic>>();
    options.extra['_apiTraceCompleter'] = completer;
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
            responseHeaders: _collapseHeaders(response.headers.map),
            responseBody: response.data?.toString(),
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
      completer.completeError(err, err.stackTrace);
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
