# flutter_api_inspector

[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.27.0-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.6.0-blue.svg)](https://dart.dev)

Debug-only in-app overlay that intercepts HTTP traffic and shows a
live timeline with status codes, durations, and response bodies —
without leaving the app, without proxy certificates, and without
modifying a single API call.

The overlay is guarded by `kDebugMode` and tree-shaken from
`flutter build --release` binaries automatically.

## Why

When an endpoint misbehaves (wrong status, slow response, unexpected
body), Flutter developers waste time sprinkling `debugPrint` calls,
rebuilding, and reading scrolling console output. There is no in-app
visualization that shows "the last N calls, in order, with the bodies
I care about."

`flutter_api_inspector` fills that gap with a floating action button
that opens a timeline panel inside your running debug app.

## Quickstart

Add the dependency:

```yaml
dependencies:
  flutter_api_inspector: ^0.1.0
```

### Option A — Automatic capture (recommended)

Install `TracedHttpOverrides` once in `main()`. It intercepts every
`dart:io HttpClient` constructed anywhere in the process — this covers
`GetConnect`, `package:http`, `Dio`, and any other client that uses
`dart:io` under the hood:

```dart
import 'dart:io';
import 'package:flutter_api_inspector/flutter_api_inspector.dart';

void main() {
  HttpOverrides.global = TracedHttpOverrides();
  ApiTrace.runApp(const MyApp());
}
```

One import covers everything — overlay, manual API, and both
interceptors. The package targets mobile / desktop, where there is
no browser console; on Flutter Web use the browser's own DevTools
Network tab instead.

That's it. Every HTTP call your app makes will appear in the overlay
with its URL, method, status code, duration, and response body.

### Option B — Manual instrumentation

Wrap individual calls with `ApiTrace.call(...)` for fine-grained
control over what is captured and what label appears in the timeline:

```dart
import 'package:flutter_api_inspector/flutter_api_inspector.dart';

await ApiTrace.call(
  'POST authenticator/v2',
  method: 'POST',
  url: Uri.parse('$baseUrl/pxauth/authenticator/v2'),
  execute: () async {
    final res = await post(url, body, contentType: 'application/json');
    return ApiTraceResponse(
      statusCode: res.statusCode ?? 0,
      responseBody: res.bodyString,
    );
  },
);
```

### Option C — Dio interceptor

If you use [Dio](https://pub.dev/packages/dio) and want per-instance
control, add `TracedDioInterceptor` instead of (or alongside)
`TracedHttpOverrides`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_api_inspector/flutter_api_inspector.dart';

final dio = Dio()..interceptors.add(TracedDioInterceptor());
```

Installing both is safe: on mobile/desktop Dio routes through
`dart:io HttpClient`, so `TracedDioInterceptor` detects that
`TracedHttpOverrides` is active and defers to it automatically —
each call is recorded exactly once. If your Dio instance uses a
custom `HttpClientAdapter` that bypasses `dart:io` (mocks, http2),
pass `TracedDioInterceptor(deferToHttpOverrides: false)` so the
interceptor records those requests itself.

> **Note:** Both interceptors are exported from the main barrel
> (`flutter_api_inspector.dart`). `dio` is a transitive dependency
> of this package regardless of which interceptor you use. If you
> only need `TracedHttpOverrides` and want to avoid pulling in
> `dio`, import directly from
> `package:flutter_api_inspector/interceptor/http_overrides.dart`.

## Public API surface

```dart
// Master switch + global config.
ApiTrace.enabled;            // bool, defaults to kDebugMode
ApiTrace.config;             // ApiTraceConfig, mutable
ApiTrace.timeline;           // in-memory ring buffer (Timeline)

// Capture one call manually.
Future<String?> ApiTrace.call(
  String name, {
  required String method,
  required Uri url,
  required Future<ApiTraceResponse> Function() execute,
  Set<ApiTraceDetail>? detailOverride,
  Map<String, Object?>? extra,
});

// One-line bootstrap.
ApiTrace.runApp(Widget app);
```

## Configuration

All fields are optional — `const ApiTraceConfig()` gives the package
defaults:

```dart
ApiTrace.config = const ApiTraceConfig(
  // Which fields to capture on every call.
  // Default: {minimal, response} — captures status/duration/url
  // plus the response body so failed calls are immediately readable.
  details: {ApiTraceDetail.minimal, ApiTraceDetail.response},

  // Overlay FAB position: bottomRight | bottomLeft | topRight | topLeft.
  overlayPosition: ApiTraceOverlayPosition.bottomRight,

  // FAB label: icon (default) | badge (count) | chip (text + count).
  overlayLabel: ApiTraceOverlayLabel.icon,

  // Whether the FAB can be dragged around the screen. Default true.
  draggableFab: true,

  // Gap between two calls before the panel groups them separately.
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

### Detail levels

| Value | Captures |
|-------|----------|
| `minimal` | URL, method, status code, duration (always on) |
| `response` | Response body (truncated to `maxResponseBodyBytes`) |
| `request` | Request body |
| `headers` | Request + response headers |
| `full` | Everything above |

## `TracedHttpOverrides` — how it works

`TracedHttpOverrides` replaces `HttpClient.createHttpClient` globally
(via `HttpOverrides.global`). Every `HttpClient` created anywhere in
the process — including inside `GetConnect`, `package:http`, and Dio's
default adapter — goes through `TracedHttpClient`.

When a request is closed, the wrapper:

1. Captures the request body bytes as the caller writes them (only
   when the detail set includes `request` or `full`, capped at
   `maxResponseBodyBytes`).
2. Reads the full response body into memory (up to `maxResponseBodyBytes`
   for the inspector; the complete body is replayed transparently to the
   caller).
3. Completes the `ApiTrace` record with status code, request/response
   headers, and decoded bodies.
4. Returns a `_ReplayHttpClientResponse` so the caller receives every
   byte unchanged.

The interception is transparent: `GetConnect`, `http`, and Dio see no
difference in the response they receive.

**Limitations of `TracedHttpOverrides`:**

- Mobile and desktop only (`dart:io`). Flutter Web uses `XMLHttpRequest`;
  install `TracedHttpOverrides` conditionally with `!kIsWeb`.
- Eagerly buffers the full response before returning it to the caller.
  This is a non-issue for REST API payloads; avoid it for large file
  downloads in debug mode.
- Dio with a custom `HttpClientAdapter` (e.g. mocks) bypasses
  `dart:io` entirely — use `TracedDioInterceptor` in that case.

## Limitations

- **Debug-only.** The overlay is tree-shaken from release builds.
  `ApiTrace.call` in release mode is a no-op when `ApiTrace.enabled`
  is false (the default in release).
- **In-memory only.** The ring buffer resets on every app restart.
  No disk persistence, no file export in v1.
- **Read-only detail view.** No cURL export, no re-run, no replay in v1.
- **No Flutter Web support.** Web is intentionally out of scope: the
  browser's DevTools Network tab already covers it. This package
  exists for mobile / desktop, where there is no console. The
  pubspec declares `platforms:` accordingly, so pub.dev shows web
  as unsupported.
- **Single overlay per app.** Multi-window is out of scope for v1.

## License

MIT — see [LICENSE](LICENSE).
