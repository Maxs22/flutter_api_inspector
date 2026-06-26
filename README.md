# flutter_api_inspector

[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.16.0-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.2.0-blue.svg)](https://dart.dev)

Manual API instrumentation and a debug-only in-app overlay timeline for
Flutter. Developers call `ApiTrace.call(name, …, execute: …)` at the
call site; the package records each call into an in-memory ring buffer
and renders a floating action button plus panel that lists calls in
chronological order with status, duration, and (optionally) request /
response fields. The overlay is guarded by `kDebugMode` and tree-shaken
from `flutter build --release` binaries.

## Why

When an endpoint misbehaves (wrong status, slow response, unexpected
body, missing header), Flutter developers waste time sprinkling
`print` calls, rebuilding, and reading scrolling console output. There
is no in-app visualization that shows "the last N calls, in order,
with the bodies I care about" — and no way to do that without either
taking over the networking layer or leaving the app.

`flutter_api_inspector` fills that gap with **manual instrumentation**
at the call site (you stay in control of what is traced) and a
**debug-only in-app overlay** (no extra tooling, no MITM certs, no
global network mutation). The overlay is opt-out via
`ApiTrace.enabled` and is guaranteed to be tree-shaken from release
binaries.

## Quickstart

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_api_inspector: ^0.1.0
```

Wrap your `runApp` call:

```dart
import 'package:flutter_api_inspector/flutter_api_inspector.dart';

void main() => ApiTrace.runApp(const MyApp());
```

Instrument the calls you care about:

```dart
final response = await ApiTrace.call(
  'listOrders',
  method: 'GET',
  url: Uri.parse('https://api.example.com/orders'),
  execute: () async {
    final res = await http.get(Uri.parse('https://api.example.com/orders'));
    return ApiTraceResponse(statusCode: res.statusCode, responseBody: res.body);
  },
);
```

In debug builds, tap the floating action button to open the timeline.
Release builds (`flutter build --release`) compile the overlay out.

## Public API surface

```dart
// Master switch + global config.
ApiTrace.enabled;             // bool, defaults to kDebugMode
ApiTrace.config;              // ApiTraceConfig, mutable
ApiTrace.timeline;            // in-memory ring buffer (Timeline)

// Capture one call.
Future<String?> ApiTrace.call(
  String name, {
  required String method,
  required Uri url,
  required Future<ApiTraceResponse> Function() execute,
  Set<ApiTraceDetail>? detailOverride,
  Map<String, Object?>? extra,
});

// Programmatic overlay control.
ApiTrace.showOverlay(BuildContext context);
ApiTrace.hideOverlay(BuildContext context);

// One-line bootstrap.
ApiTrace.runApp(Widget app);
```

The overlay itself (`ApiTraceOverlay`) mounts automatically when
`ApiTrace.runApp` is used. The default `ApiTraceConfig` captures only
URL, method, status, and duration — bodies and headers are opt-in via
`detailOverride` (per-call) or `ApiTrace.config.details` (global).

## Configuration

All fields are optional — `const ApiTraceConfig()` gives the package
defaults.

```dart
ApiTrace.config = const ApiTraceConfig(
  // Which fields to capture on every call (privacy-conscious default).
  details: {ApiTraceDetail.minimal},

  // Overlay position: bottomRight | bottomLeft | topRight | topLeft.
  overlayPosition: ApiTraceOverlayPosition.bottomRight,

  // FAB label: icon (default) | badge (count) | chip (text + count).
  overlayLabel: ApiTraceOverlayLabel.icon,

  // Whether the FAB can be dragged around the screen. Default true.
  draggableFab: true,

  // Gap between two calls before the panel starts a new flow group.
  // Set to Duration.zero to disable grouping.
  flowGroupGap: Duration(seconds: 2),

  // Timeline panel height range (logical pixels).
  panelMaxHeight: 600,
  panelMinHeight: 120,

  // Max bytes stored per response body (truncated beyond this).
  maxResponseBodyBytes: 4096,

  // Ring buffer capacity (oldest record evicted when full).
  timelineCapacity: 200,
);
```

## Dio auto-tracing (optional)

If your project already uses [dio](https://pub.dev/packages/dio), you
can add `TracedDioInterceptor` to record every request automatically —
no manual `ApiTrace.call(...)` needed for those calls:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_api_inspector/interceptor/dio_interceptor.dart';

final dio = Dio()..interceptors.add(TracedDioInterceptor());
```

`TracedDioInterceptor` is an opt-in adapter shipped in
`lib/interceptor/dio_interceptor.dart`. It is **not** exported from the
main barrel, but because it lives under `lib/`, `dio` is a declared
dependency of this package — meaning it will be pulled into your project
transitively even if you use a different HTTP client. A dedicated
`flutter_api_inspector_dio` package is planned for v0.2 to eliminate
this overhead for non-Dio users.

## Limitations

- **Debug-only.** The overlay is guarded by `kDebugMode` and is
  tree-shaken from `flutter build --release` builds. The
  instrumentation API still works in release mode (records are stored),
  but the visualization is gone.
- **In-memory only.** The timeline ring buffer is reset on every app
  restart. There is no disk persistence, no file export, and no
  clipboard copy in v1.
- **Visualization only.** Tapping a call opens a read-only detail view.
  There is no cURL export, no re-run, and no replay.
- **Single overlay per app.** Multi-window / multi-tab is out of scope
  for v1. Flutter web is also out of scope for v1.

## License

MIT — see [LICENSE](LICENSE).
