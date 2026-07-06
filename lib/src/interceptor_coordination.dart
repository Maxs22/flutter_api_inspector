// Internal coordination between the two automatic capture layers
// (`TracedHttpOverrides` and `TracedDioInterceptor`).
//
// On mobile/desktop, Dio's default adapter constructs its
// `HttpClient` through `HttpOverrides`, so a Dio request would be
// recorded TWICE when both layers are installed: once by
// `TracedDioInterceptor` and once by `TracedHttpOverrides`. This
// flag lets the Dio interceptor detect that the overrides layer is
// active and defer to it (see `TracedDioInterceptor.deferToHttpOverrides`).
//
// This file must stay free of `dart:io` imports: the Dio
// interceptor is usable on Flutter Web, where `dart:io` (and
// therefore `TracedHttpOverrides`) does not exist. The flag is only
// ever set from the `dart:io`-guarded overrides file, so on Web it
// stays `false` and the Dio interceptor always records.

/// Internal. Not exported from the package barrel.
abstract final class InterceptorCoordination {
  /// `true` once a [TracedHttpOverrides] instance has been
  /// constructed in this isolate. Read by `TracedDioInterceptor`
  /// to avoid double-recording Dio requests.
  static bool httpOverridesActive = false;
}
