// The `ApiTrace` static class — the developer-facing entry point
// for the `flutter_api_inspector` package.
//
// This file is built up incrementally across TASK-014, TASK-015,
// TASK-016, and TASK-017. TASK-014 ships the happy-path async
// signature, the `execute` await, the timeline growth, and the
// returned record id. TASK-015 layers in the `enabled` short-
// circuit and the `kDebugMode` default. TASK-016 layers in the
// per-call `detailOverride`. TASK-017 layers in the error-capture
// branches (thrown exceptions and 4xx/5xx) and the reentrancy
// contract.
//
// The class is `abstract final` with a private constructor so it
// cannot be instantiated. All public surface is on the `static`
// fields and methods.
//
// See `openspec/changes/flutter_api_inspector-mvp/specs/instrumentation-api.md`
// (REQ-API-001..009) and `design.md` for the locked semantics.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_api_inspector/src/config.dart';
import 'package:flutter_api_inspector/src/detail.dart';
import 'package:flutter_api_inspector/src/model/api_trace_record.dart';
import 'package:flutter_api_inspector/src/model/api_trace_request.dart';
import 'package:flutter_api_inspector/src/model/api_trace_response.dart';
import 'package:flutter_api_inspector/src/model/timeline.dart';

/// The single developer-facing entry point for the package.
///
/// `ApiTrace` is an `abstract final` class with a private
/// constructor. All public surface is on the `static` fields and
/// methods. The class is intentionally tiny: a `config`, an
/// `enabled` switch, a `timeline`, and a `call` method.
///
/// See `openspec/changes/flutter_api_inspector-mvp/specs/instrumentation-api.md`
/// for the locked REQ-API contracts.
abstract final class ApiTrace {
  ApiTrace._();

  /// Mutable global configuration. The default is the const
  /// `ApiTraceConfig()` instance (REQ-API-003, REQ-API-004).
  /// Reassignment is the only way to change capture behavior
  /// app-wide; the config object itself is immutable.
  static ApiTraceConfig config = const ApiTraceConfig();

  /// Master switch. When `false`, `call` is a no-op that
  /// returns `null` without invoking the `execute` callback
  /// or appending to the timeline (REQ-API-002). Initialised
  /// to `kDebugMode` on first read (REQ-API-006): in debug
  /// builds the overlay is on by default; in release builds
  /// it is off. The field is mutable; assigning `false`
  /// explicitly is the documented opt-out.
  static bool enabled = kDebugMode;

  /// The in-memory ring buffer of `ApiTraceRecord`s. Initialised
  /// with the default `ApiTraceConfig.timelineCapacity` (200,
  /// REQ-MODEL-003). The reference cannot be reassigned (final
  /// `static`), but `append` and `clear` mutate the contents.
  static final Timeline timeline =
      Timeline(capacity: const ApiTraceConfig().timelineCapacity);

  /// Captures one API call. The `execute` callback is awaited
  /// exactly once. Returns the new record's `id`, or `null` if
  /// the call was short-circuited by `enabled == false`
  /// (REQ-API-002, added by TASK-015).
  ///
  /// The `detailOverride` parameter widens the captured detail
  /// set for this one call only; the global config is never
  /// mutated (REQ-API-005, added by TASK-016).
  ///
  /// Thrown exceptions and 4xx/5xx responses produce a record
  /// with `outcome == ApiTraceOutcome.error` (REQ-API-007,
  /// added by TASK-017).
  ///
  /// Two concurrent (or nested) `ApiTrace.call(...)` invocations
  /// each produce exactly one record (REQ-API-009, REQ-MODEL-007,
  /// added by TASK-017).
  static Future<String?> call(
    String name, {
    required String method,
    required Uri url,
    required Future<ApiTraceResponse> Function() execute,
    Set<ApiTraceDetail>? detailOverride,
    Map<String, Object?>? extra,
  }) async {
    // Master switch short-circuit (REQ-API-002). When the
    // overlay is disabled, call is a no-op: it returns null
    // without invoking execute() or appending to the timeline.
    if (!enabled) {
      return null;
    }

    final startedAt = DateTime.now();
    ApiTraceResponse? response;
    ApiTraceRequest? request;
    Object? error;
    try {
      response = await execute();
    } catch (e) {
      // TASK-017: capture the thrown error. For TASK-014 the
      // happy path never throws, so this branch is unreachable
      // in the RED/GREEN cycle; TASK-017 adds the
      // rethrow-vs-capture decision (we capture, do not rethrow,
      // because the API contract is that `call` resolves with
      // the record id even on error).
      error = e;
    }
    final completedAt = DateTime.now();

    // TASK-016: union `config.details` with `detailOverride`. For
    // TASK-014 the per-call override is ignored — the global
    // config is used as-is.
    final effectiveDetails = <ApiTraceDetail>{
      ...config.details,
      ...?detailOverride,
    };

    final record = ApiTraceRecord.fromCapture(
      name: name,
      startedAt: startedAt,
      completedAt: completedAt,
      method: method,
      url: url,
      capturedDetails: effectiveDetails,
      response: response,
      request: request,
      error: error,
      extra: extra ?? const <String, Object?>{},
      maxResponseBodyBytes: config.maxResponseBodyBytes,
    );

    timeline.append(record);
    return record.id;
  }
}
