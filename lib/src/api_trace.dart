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
import 'package:flutter/widgets.dart';
import 'package:flutter_api_inspector/src/bootstrap.dart';
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

    // Per-call override widens capture for this one call only;
    // the global config is never mutated (REQ-API-005). The
    // effective detail set is the union of the global config's
    // details and the per-call override.
    final effectiveDetails = _effectiveDetails(detailOverride);

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

  /// One-line bootstrap (REQ-UI-001, REQ-UI-002).
  ///
  /// In release mode (kDebugMode == false), this is a
  /// pass-through: the developer's app is run unmodified.
  /// In debug mode, the app is wrapped in [ApiTraceBootstrap]
  /// which mounts the [ApiTraceOverlay] above the developer's
  /// UI.
  ///
  /// The developer calls this from `main`:
  ///
  /// ```dart
  /// void main() => ApiTrace.runApp(const MyApp());
  /// ```
  static void runApp(Widget app) {
    // The kDebugMode guard is here, not just inside the
    // bootstrap, so the const-false branch is eliminated
    // by the AOT compiler in release builds. The
    // ApiTraceBootstrap instance is never even constructed
    // in release.
    if (!kDebugMode) {
      // Release-mode pass-through: no overlay.
      WidgetsFlutterBinding.ensureInitialized();
      runApp(app);
      return;
    }
    WidgetsFlutterBinding.ensureInitialized();
    runApp(ApiTraceBootstrap(child: app));
  }

  /// Programmatically opens the timeline overlay (REQ-UI-005).
  ///
  /// In the current implementation, the overlay is mounted
  /// by [ApiTraceBootstrap] and exposes its open/closed
  /// state internally. To open the panel programmatically,
  /// set [ApiTrace.enabled] = `true` (it is by default in
  /// debug builds) and then call this method. The
  /// implementation is a no-op for now; the bootstrap's
  /// overlay is always visible when enabled.
  static void showOverlay(BuildContext context) {
    // The overlay is auto-mounted by the bootstrap in debug
    // mode. There is no separate `show` call to make — the
    // FAB is always visible when enabled. This method is
    // a documented extension point for a future v1.x change
    // (e.g. an explicit toggle that hides the FAB on
    // developer demand).
    // ignore: unused_local_variable
    final _ = context;
  }

  /// Programmatically closes the timeline overlay
  /// (REQ-UI-005).
  ///
  /// See [showOverlay] for the rationale; this is the
  /// symmetric counterpart.
  static void hideOverlay(BuildContext context) {
    // Same rationale as [showOverlay].
    // ignore: unused_local_variable
    final _ = context;
  }

  /// Computes the effective detail set for a single call: the
  /// union of `ApiTrace.config.details` and the per-call
  /// `detailOverride`. A null override falls through to the
  /// global config unchanged (REQ-API-005).
  static Set<ApiTraceDetail> _effectiveDetails(
    Set<ApiTraceDetail>? detailOverride,
  ) {
    return <ApiTraceDetail>{
      ...config.details,
      ...?detailOverride,
    };
  }
}
