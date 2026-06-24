// Configuration for the `flutter_api_inspector` package.
//
// This file declares three public symbols:
// - `ApiTraceOverlayPosition` (4 values; default `bottomRight`).
// - `ApiTraceOverlayLabel` (3 values; default `icon`).
// - `ApiTraceConfig` (immutable; `const` constructor; the five
//   locked defaults from the proposal Q2/Q3/Q5).
//
// The mutable global is `ApiTrace.config` (a settable `static late`
// field on the `ApiTrace` class). The config object itself is
// immutable; to change a field, callers do
// `ApiTrace.config = ApiTraceConfig(details: ...)` (copy-with
// pattern). This keeps the API explicit and avoids surprising the
// developer with in-place mutation.
//
// See `openspec/changes/flutter_api_inspector-mvp/specs/instrumentation-api.md`
// (REQ-API-003, REQ-API-004) and `design.md` for the locked
// semantics and the type definitions.

import 'package:flutter_api_inspector/src/detail.dart';

/// Where the floating action button renders inside the overlay.
///
/// The four values map to the four corners of the screen. The
/// default is `bottomRight` (per REQ-API-003, proposal Q3).
enum ApiTraceOverlayPosition {
  /// Bottom-right corner. Default.
  bottomRight,

  /// Bottom-left corner.
  bottomLeft,

  /// Top-right corner.
  topRight,

  /// Top-left corner.
  topLeft,
}

/// How the floating action button labels itself.
///
/// The default is `icon` (icon-only FAB). The other two values add
/// a count indicator: `badge` (numeric badge) and `chip` (text
/// label). The count is hidden when the timeline is empty
/// (REQ-UI-004, proposal Q3).
enum ApiTraceOverlayLabel {
  /// Icon-only FAB. The default. No count is shown.
  icon,

  /// Icon plus a numeric badge of the current record count.
  /// Hidden when the count is zero.
  badge,

  /// Icon plus a short text label of the current record count
  /// (e.g. "API 17"). Hidden when the count is zero.
  chip,
}

/// Immutable configuration for the package.
///
/// All fields have the locked defaults from
/// `openspec/changes/flutter_api_inspector-mvp/proposal.md` and
/// `design.md`. The `const` constructor makes the default instance
/// (`const ApiTraceConfig()`) a compile-time constant.
///
/// Per REQ-API-004, the default `details` is the singleton
/// `{ApiTraceDetail.minimal}` — privacy-conscious, no body, no
/// headers.
final class ApiTraceConfig {
  /// The set of detail levels active for every call by default.
  /// Per-call `detailOverride` on `ApiTrace.call(...)` widens this
  /// set for that one call (REQ-API-005).
  final Set<ApiTraceDetail> details;

  /// The maximum number of response-body bytes (or characters for
  /// `String` bodies) stored on a captured record. Beyond this
  /// limit, the body is truncated (REQ-MODEL-006). Default 4 KB.
  final int maxResponseBodyBytes;

  /// The capacity of the in-memory ring buffer. When the buffer
  /// is full, the oldest record is evicted silently
  /// (REQ-MODEL-003). Default 200.
  final int timelineCapacity;

  /// Where the floating action button renders. Default
  /// `ApiTraceOverlayPosition.bottomRight` (REQ-UI-003).
  final ApiTraceOverlayPosition overlayPosition;

  /// How the floating action button labels itself. Default
  /// `ApiTraceOverlayLabel.icon` (REQ-UI-004).
  final ApiTraceOverlayLabel overlayLabel;

  /// `const` constructor with the five locked defaults. Any
  /// combination of fields can be overridden at the call site;
  /// omitting all arguments yields the package-wide default.
  const ApiTraceConfig({
    this.details = const <ApiTraceDetail>{ApiTraceDetail.minimal},
    this.maxResponseBodyBytes = 4 * 1024,
    this.timelineCapacity = 200,
    this.overlayPosition = ApiTraceOverlayPosition.bottomRight,
    this.overlayLabel = ApiTraceOverlayLabel.icon,
  });
}
