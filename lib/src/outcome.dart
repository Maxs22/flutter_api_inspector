/// The outcome of a single API call.
///
/// The UI uses this enum to color the timeline row (REQ-UI-008):
/// success is green, error is red, 4xx and 5xx share the same red.
/// `cancelled` is reserved for future use; v1 never produces it.
///
/// See `openspec/changes/flutter_api_inspector-mvp/specs/timeline-model.md`
/// (REQ-MODEL-002) and `design.md` for the locked semantics.
library;

enum ApiTraceOutcome {
  /// The `execute` callback returned a response with a 1xx, 2xx, or
  /// 3xx status code, and no exception was thrown.
  success,

  /// Either the `execute` callback threw an exception, or the
  /// returned response has a 4xx or 5xx status code.
  error,

  /// Reserved for future use (e.g. a `Completer` cancel). v1 never
  /// produces this value.
  cancelled,
}
