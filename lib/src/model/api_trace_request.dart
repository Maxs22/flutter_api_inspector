// The captured representation of a request that participated in an
// `ApiTraceRecord` (REQ-MODEL-001).
//
// `ApiTraceRequest` is an immutable value object. By default both
// fields are empty/null (the privacy-conscious default — see
// REQ-MODEL-005). The factory in `ApiTraceRecord.fromCapture`
// constructs the redacted form based on the captured detail set.

library;

/// Sentinel value used by [ApiTraceRequest.copyWith] to detect an
/// "argument not passed" condition when the field is nullable.
const Object _undefined = Object();

/// Immutable, captured request payload.
final class ApiTraceRequest {
  /// HTTP request headers, captured only when
  /// `ApiTraceDetail.headers` is in the captured detail set.
  ///
  /// Empty by default. Treat as read-only.
  final Map<String, String> headers;

  /// HTTP request body, captured only when `ApiTraceDetail.request`
  /// or `ApiTraceDetail.full` is in the captured detail set. The
  /// developer is responsible for providing a parsed
  /// representation (a `String`, a `Map<String, Object?>`, etc.);
  /// the package does not parse raw bytes.
  ///
  /// `null` by default. The package does not serialize / parse;
  /// the developer returns an `Object?` from the `execute` callback.
  final Object? body;

  const ApiTraceRequest({
    this.headers = const <String, String>{},
    this.body,
  });

  /// Returns a copy of this request with the given fields replaced.
  ///
  /// Pass `headers: const <String, String>{}` to redact headers
  /// (used by the privacy-conscious `fromCapture` factory). Pass
  /// `body: null` explicitly to redact the body.
  ApiTraceRequest copyWith({
    Map<String, String>? headers,
    Object? body = _undefined,
  }) {
    return ApiTraceRequest(
      headers: headers ?? this.headers,
      body: identical(body, _undefined) ? this.body : body,
    );
  }
}
