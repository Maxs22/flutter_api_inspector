// The in-memory record produced by every `ApiTrace.call` invocation.
//
// `ApiTraceRecord` is an immutable value object (REQ-MODEL-001). It
// is constructed exclusively via the `fromCapture` factory, which
// enforces the privacy-conscious default (REQ-MODEL-005): with
// `capturedDetails == {ApiTraceDetail.minimal}` only, no body and no
// headers are stored; the `request` and `response` fields are null
// (or have empty header maps) by construction, not by render-time
// filtering.
//
// See `openspec/changes/flutter_api_inspector-mvp/specs/timeline-model.md`
// (REQ-MODEL-001, REQ-MODEL-005) and `design.md` for the locked
// semantics and the factory pseudocode.

import 'package:flutter_api_inspector/src/detail.dart';
import 'package:flutter_api_inspector/src/id.dart';
import 'package:flutter_api_inspector/src/model/api_trace_request.dart';
import 'package:flutter_api_inspector/src/model/api_trace_response.dart';
import 'package:flutter_api_inspector/src/outcome.dart';

/// Immutable, captured API call record.
final class ApiTraceRecord {
  /// 32 lowercase hex characters from `Random.secure().nextBytes(16)`
  /// (see `id.dart`).
  final String id;

  /// Developer-supplied label, e.g. `'listOrders'`.
  final String name;

  /// Wall-clock time captured before `await execute()`.
  final DateTime startedAt;

  /// Wall-clock time captured after `await execute()` resolved (or
  /// rethrew).
  final DateTime completedAt;

  /// HTTP method, e.g. `'GET'`, `'POST'`.
  final String method;

  /// Request URL.
  final Uri url;

  /// HTTP status code. `null` when the `execute` callback threw
  /// before producing an `ApiTraceResponse`.
  final int? statusCode;

  /// `completedAt - startedAt`, clamped to non-negative. See
  /// `fromCapture` for the clamp.
  final Duration duration;

  /// Derived outcome (REQ-API-007).
  final ApiTraceOutcome outcome;

  /// The set of detail levels active for this call. Stored as an
  /// unmodifiable view of the merged global + per-call set.
  final Set<ApiTraceDetail> capturedDetails;

  /// Captured request payload. `null` unless
  /// `ApiTraceDetail.request` or `ApiTraceDetail.full` was active
  /// for this call (REQ-MODEL-005).
  final ApiTraceRequest? request;

  /// Captured response payload. `null` unless
  /// `ApiTraceDetail.response` or `ApiTraceDetail.full` was active
  /// for this call. `responseBody` is truncated to
  /// `maxResponseBodyBytes` by `fromCapture` (REQ-MODEL-006).
  final ApiTraceResponse? response;

  /// The thrown exception, if any (REQ-API-007). `null` when the
  /// `execute` callback returned normally.
  final Object? error;

  /// Developer-supplied tags / metadata. Stored as an unmodifiable
  /// view of the passed map.
  final Map<String, Object?> extra;

  /// `const` constructor. Used by `fromCapture` and (rarely) by
  /// tests. Production code should always go through
  /// `fromCapture` so the privacy contract is preserved.
  const ApiTraceRecord({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.completedAt,
    required this.method,
    required this.url,
    required this.statusCode,
    required this.duration,
    required this.outcome,
    required this.capturedDetails,
    required this.request,
    required this.response,
    required this.error,
    required this.extra,
  });

  /// Privacy-conscious factory. The single chokepoint for the
  /// privacy contract (REQ-MODEL-005).
  ///
  /// Behaviour:
  /// - `request` is `null` unless `capturedDetails` contains
  ///   `ApiTraceDetail.request` or `ApiTraceDetail.full`.
  /// - `response` is `null` unless `capturedDetails` contains
  ///   `ApiTraceDetail.response` or `ApiTraceDetail.full`.
  /// - When `response` is kept and the response set is active, the
  ///   `responseBody` is truncated to `maxResponseBodyBytes`
  ///   (REQ-MODEL-006). String bodies are truncated by character
  ///   count; byte-list bodies by byte count; other types are
  ///   stringified and truncated.
  /// - When `capturedDetails` does not contain
  ///   `ApiTraceDetail.headers`, the `requestHeaders` and
  ///   `responseHeaders` maps are set to `const {}`.
  /// - `outcome` is derived from `response.statusCode` and `error`
  ///   (REQ-API-007).
  /// - `duration` is `completedAt - startedAt`, clamped to
  ///   `Duration.zero` when the difference is negative.
  /// - `capturedDetails` and `extra` are stored as unmodifiable
  ///   views so downstream code cannot mutate them.
  factory ApiTraceRecord.fromCapture({
    required String name,
    required DateTime startedAt,
    required DateTime completedAt,
    required String method,
    required Uri url,
    required Set<ApiTraceDetail> capturedDetails,
    required ApiTraceResponse? response,
    required ApiTraceRequest? request,
    required Object? error,
    required Map<String, Object?> extra,
    required int maxResponseBodyBytes,
  }) {
    // `full` implies every other detail level (the proposal
    // defines it as "everything above"). `headers` implies the
    // response object (with the bodies redacted), so the
    // `response.responseHeaders` / `response.requestHeaders` are
    // observable on the record. `request` and `response` are the
    // body-bearing levels.
    final keepHeaders = capturedDetails.contains(ApiTraceDetail.headers) ||
        capturedDetails.contains(ApiTraceDetail.full);
    final keepRequestObject =
        capturedDetails.contains(ApiTraceDetail.request) ||
            capturedDetails.contains(ApiTraceDetail.full);
    final keepResponseObject =
        capturedDetails.contains(ApiTraceDetail.response) ||
            capturedDetails.contains(ApiTraceDetail.headers) ||
            capturedDetails.contains(ApiTraceDetail.full);
    final keepRequestBody = keepRequestObject;
    final keepResponseBody = keepResponseObject &&
        (capturedDetails.contains(ApiTraceDetail.response) ||
            capturedDetails.contains(ApiTraceDetail.full));

    // Redact the request per the captured detail set.
    final ApiTraceRequest? redactedRequest;
    if (keepRequestObject && request != null) {
      final withEmptyBody =
          keepRequestBody ? request : request.copyWith(body: null);
      redactedRequest = keepHeaders
          ? withEmptyBody
          : withEmptyBody.copyWith(headers: const <String, String>{});
    } else {
      redactedRequest = null;
    }

    // Redact the response per the captured detail set; truncate
    // the body if the response set is active.
    final ApiTraceResponse? redactedResponse;
    if (keepResponseObject && response != null) {
      final bodyForStorage = keepResponseBody
          ? _truncateBody(response.responseBody, maxResponseBodyBytes)
          : null;
      final withBody = response.copyWith(
        responseBody: bodyForStorage,
        requestBody: keepRequestBody ? response.requestBody : null,
      );
      redactedResponse = keepHeaders
          ? withBody
          : withBody.copyWith(
              requestHeaders: const <String, String>{},
              responseHeaders: const <String, String>{},
            );
    } else {
      redactedResponse = null;
    }

    final outcome = _deriveOutcome(response: response, error: error);

    final rawDuration = completedAt.difference(startedAt);
    final duration = rawDuration.isNegative ? Duration.zero : rawDuration;

    return ApiTraceRecord(
      id: generateId(),
      name: name,
      startedAt: startedAt,
      completedAt: completedAt,
      method: method,
      url: url,
      statusCode: response?.statusCode,
      duration: duration,
      outcome: outcome,
      capturedDetails: Set.unmodifiable(capturedDetails),
      request: redactedRequest,
      response: redactedResponse,
      error: error,
      extra: Map.unmodifiable(extra),
    );
  }
}

/// Derives the outcome of a single API call from the response and
/// the thrown error (if any). See REQ-API-007.
///
/// - Thrown exception -> `error`.
/// - 4xx / 5xx status code -> `error`.
/// - Otherwise -> `success` (1xx, 2xx, 3xx, or null response with
///   no exception).
///
/// `cancelled` is reserved for future use; v1 never produces it.
ApiTraceOutcome _deriveOutcome({
  required ApiTraceResponse? response,
  required Object? error,
}) {
  if (error != null) return ApiTraceOutcome.error;
  final code = response?.statusCode ?? 0;
  if (code >= 400 && code < 600) return ApiTraceOutcome.error;
  return ApiTraceOutcome.success;
}

/// Truncates the response body to `maxBytes`. The full bodyCodec
/// lives in `body_codec.dart` (TASK-011); this inline helper keeps
/// `fromCapture` self-contained for PR 1 and is replaced by a call
/// to `bodyCodec.truncate` in the TASK-011 refactor.
///
/// Format contract (kept stable for TASK-011 to assert):
/// - `null` body -> `null`.
/// - `String` body -> prefix of length `min(body.length, maxBytes)`.
/// - `List<int>` body -> prefix of length `min(bytes.length, maxBytes)`.
/// - Other -> `Object.toString()` then prefix-truncated.
Object? _truncateBody(Object? body, int maxBytes) {
  if (body == null) return null;
  if (body is String) {
    return body.length <= maxBytes ? body : body.substring(0, maxBytes);
  }
  if (body is List<int>) {
    return body.length <= maxBytes ? body : body.sublist(0, maxBytes);
  }
  final s = body.toString();
  return s.length <= maxBytes ? s : s.substring(0, maxBytes);
}
