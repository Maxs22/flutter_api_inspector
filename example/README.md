# flutter_api_inspector example

Example app demonstrating all three integration options:

- **Option A** — Automatic capture via `TracedHttpOverrides`
- **Option B** — Manual instrumentation via `ApiTrace.call()`
- **Option C** — Dio interceptor via `TracedDioInterceptor`

## Run

```bash
cd example
flutter run
```

The debug-only overlay (FAB + timeline panel) appears automatically
in debug builds. Tap the FAB (⚡) to open the timeline.
