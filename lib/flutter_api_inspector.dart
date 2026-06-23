/// Public barrel for the `flutter_api_inspector` package.
///
/// Consumers should import this single file:
///
/// ```dart
/// import 'package:flutter_api_inspector/flutter_api_inspector.dart';
/// ```
///
/// The barrel is the only public file in `lib/`. All implementation
/// lives under `lib/src/` and is re-exported here. The barrel is
/// extended across the chained PRs:
///
/// - PR 1 (skeleton + model) — `ApiTraceDetail`, `ApiTraceOutcome`,
///   `ApiTraceRequest`, `ApiTraceResponse`, `ApiTraceRecord`.
/// - PR 2 (instrumentation API) — `ApiTrace`, `ApiTraceConfig`,
///   `ApiTraceOverlayPosition`, `ApiTraceOverlayLabel`.
/// - PR 3 (overlay UI) — `ApiTraceOverlay`, `ApiTraceBootstrap`,
///   `ApiTraceDetailScreen`.
/// - PR 4 (example + acceptance) — no new public symbols.
///
/// Internals (`Timeline`, id generator, body codec) are NOT re-exported.
library flutter_api_inspector;

// --- Model layer (PR 1) -----------------------------------------------------
export 'src/detail.dart' show ApiTraceDetail;
export 'src/model/api_trace_record.dart' show ApiTraceRecord;
export 'src/model/api_trace_request.dart' show ApiTraceRequest;
export 'src/model/api_trace_response.dart' show ApiTraceResponse;
export 'src/outcome.dart' show ApiTraceOutcome;
