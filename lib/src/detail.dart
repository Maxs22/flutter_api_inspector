/// The level of detail captured for a single API call.
///
/// Ordered from least to most detail. The default `ApiTraceConfig`
/// uses `{ApiTraceDetail.minimal}` only — no body, no headers — per
/// the privacy-conscious default (REQ-MODEL-005).
///
/// See `openspec/changes/flutter_api_inspector-mvp/specs/instrumentation-api.md`
/// (REQ-API-004) and `design.md` for the locked semantics.
library;

enum ApiTraceDetail {
  /// Only the metadata needed to understand what happened:
  /// method, url, status code, and duration. No body, no headers.
  minimal,

  /// Adds request and response headers. Bodies are still not captured.
  headers,

  /// Adds the parsed request body (JSON, form-data summary, etc.).
  request,

  /// Adds the parsed response body, truncated to
  /// `ApiTraceConfig.maxResponseBodyBytes` (default 4 KB).
  response,

  /// Everything above: headers, request body, and response body
  /// (truncated). Binary bodies remain truncated.
  full,
}
