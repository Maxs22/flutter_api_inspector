// The captured representation of a response that participated in an
// `ApiTraceRecord` (REQ-MODEL-001).
//
// `ApiTraceResponse` is an immutable value object. By default the
// header maps are empty and the bodies are null (the
// privacy-conscious default — see REQ-MODEL-005). The
// `ApiTraceRecord.fromCapture` factory constructs the redacted form
// based on the captured detail set and the
// `ApiTraceConfig.maxResponseBodyBytes` truncation limit
// (REQ-MODEL-006).

library;

/// Sentinel value used by [ApiTraceResponse.copyWith] to detect an
/// "argument not passed" condition when the field is nullable.
const Object _undefined = Object();

/// Immutable, captured response payload.
final class ApiTraceResponse {
  /// HTTP status code (e.g. `200`, `404`, `503`). Required: every
  /// successful or HTTP-error record has a status code. A thrown
  /// exception path leaves the `ApiTraceResponse` null at the
  /// `ApiTraceRecord` level, so `statusCode` is not optional in this
  /// type.
  final int statusCode;

  /// HTTP request headers (echoed for the detail view), captured
  /// only when `ApiTraceDetail.headers` is in the captured detail
  /// set. Empty by default.
  final Map<String, String> requestHeaders;

  /// HTTP response headers, captured only when
  /// `ApiTraceDetail.headers` is in the captured detail set. Empty
  /// by default.
  final Map<String, String> responseHeaders;

  /// HTTP request body, captured only when `ApiTraceDetail.request`
  /// or `ApiTraceDetail.full` is in the captured detail set. Null
  /// by default.
  final Object? requestBody;

  /// HTTP response body, captured only when `ApiTraceDetail.response`
  /// or `ApiTraceDetail.full` is in the captured detail set. Truncated
  /// to `ApiTraceConfig.maxResponseBodyBytes` (default 4 KB) by
  /// `body_codec.dart`. Null by default.
  final Object? responseBody;

  const ApiTraceResponse({
    required this.statusCode,
    this.requestHeaders = const <String, String>{},
    this.responseHeaders = const <String, String>{},
    this.requestBody,
    this.responseBody,
  });

  /// Returns a copy of this response with the given fields replaced.
  ///
  /// Pass `requestHeaders: const <String, String>{}` (or
  /// `responseHeaders: const <String, String>{}`) to redact the
  /// respective header map. Pass `responseBody: null` to clear the
  /// body; pass a non-null value to truncate / replace it
  /// (`body_codec.dart` provides the truncation helper).
  ApiTraceResponse copyWith({
    int? statusCode,
    Map<String, String>? requestHeaders,
    Map<String, String>? responseHeaders,
    Object? requestBody = _undefined,
    Object? responseBody = _undefined,
  }) {
    return ApiTraceResponse(
      statusCode: statusCode ?? this.statusCode,
      requestHeaders: requestHeaders ?? this.requestHeaders,
      responseHeaders: responseHeaders ?? this.responseHeaders,
      requestBody:
          identical(requestBody, _undefined) ? this.requestBody : requestBody,
      responseBody: identical(responseBody, _undefined)
          ? this.responseBody
          : responseBody,
    );
  }
}
