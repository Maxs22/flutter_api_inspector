// ---------------------------------------------------------------------------
// TracedHttpOverrides: transparent HTTP instrumentation for every
// `dart:io HttpClient` (and every `package:http` / `package:get` /
// `package:dio` Client that delegates to one) created inside the
// installed zone.
//
// Rationale: most Flutter HTTP stacks are layered on top of
// `dart:io HttpClient`. The `HttpOverrides` hook is the only built-in
// way to intercept that construction without modifying call sites.
// `package:http` constructs its default `Client` (= `IOClient`) via
// `HttpClient()`, and `package:get`'s `GetHttpClient` does the same
// for its `innerClient`; both go through this single chokepoint.
//
// Usage (mobile / desktop):
//
// ```dart
// import 'dart:io';
// import 'package:flutter_api_inspector/interceptor/http_overrides.dart';
//
// void main() {
//   HttpOverrides.global = TracedHttpOverrides();
//   runApp(const MyApp());
// }
// ```
//
// In release mode (`ApiTrace.enabled == false`) the wrapper is a
// pass-through: the inherited `openUrl` runs the call directly
// without creating a completer or appending to the timeline.
//
// Scope: this file uses `dart:io` and is therefore mobile/desktop
// only. Web builds must not import this file (the import will fail
// to resolve on the `dart:html` build target). For the bai app
// (and any other mobile/desktop Flutter app) this is fine.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_api_inspector/src/api_trace.dart';
import 'package:flutter_api_inspector/src/model/api_trace_response.dart';

/// [HttpOverrides] that returns a [TracedHttpClient] for every
/// `createHttpClient` call. Install once at process start:
///
/// ```dart
/// HttpOverrides.global = TracedHttpOverrides();
/// ```
///
/// The optional [nameFor] callback lets callers customize the
/// human-readable label that shows up in the inspector timeline
/// (default: `"<METHOD> <path>"`). The callback receives the HTTP
/// method and the requested [Uri].
class TracedHttpOverrides extends HttpOverrides {
  TracedHttpOverrides({this.nameFor});

  final String Function(String method, Uri url)? nameFor;

  /// Recursion guard. When [TracedHttpClient] builds its inner
  /// `HttpClient`, it must skip the override chain (otherwise the
  /// inner would be wrapped in another `TracedHttpClient` whose
  /// own inner would be wrapped in another… infinite recursion,
  /// Stack Overflow on the device). Setting [_bypass] = true
  /// around the inner construction makes this override return
  /// the raw `HttpClient` from `super.createHttpClient`.
  ///
  /// The guard is process-wide because `HttpOverrides` itself is
  /// process-wide (the static `HttpOverrides.global`). In Flutter
  /// this is safe: the UI thread is the only one constructing
  /// `HttpClient` instances during normal operation, and isolates
  /// use their own zone so they see their own override.
  static bool _bypass = false;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    if (_bypass) {
      return super.createHttpClient(context);
    }
    return TracedHttpClient._withNameFor(nameFor);
  }
}

/// Composition-style [HttpClient] implementation. Holds an inner
/// [HttpClient] and forwards every member to it. Only [openUrl]
/// (and the convenience URL helpers that delegate to it) does
/// the actual work of recording into the inspector timeline.
///
/// We use composition rather than inheritance because
/// `HttpClient` is an `abstract interface class` in modern Dart
/// and the concrete implementation lives in a private
/// `_HttpClient` class. Composition also means the user's
/// configuration (`connectionTimeout`, `idleTimeout`, etc.) is
/// applied directly to the inner client via the delegated
/// setters / getters.
class TracedHttpClient implements HttpClient {
  /// Public constructor used by callers that want a traced
  /// client without going through [TracedHttpOverrides]
  /// (e.g. tests, or an app that wires things manually).
  TracedHttpClient({String Function(String, Uri)? nameFor})
      : this._withNameFor(nameFor);

  /// Internal constructor used by [TracedHttpOverrides] to
  /// break the recursion: while constructing the inner
  /// `HttpClient`, [_bypass] is set so the override returns a
  /// raw client (not another traced one).
  TracedHttpClient._withNameFor(String Function(String, Uri)? nameFor)
      : _nameFor = nameFor,
        _inner = (() {
          TracedHttpOverrides._bypass = true;
          try {
            return HttpClient();
          } finally {
            TracedHttpOverrides._bypass = false;
          }
        })();

  final String Function(String, Uri)? _nameFor;
  final HttpClient _inner;

  String _label(String method, Uri url) =>
      _nameFor != null ? _nameFor(method, url) : '$method ${url.path}';

  // --- Traced URL helpers ---------------------------------------------------

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (!ApiTrace.enabled) {
      return _inner.openUrl(method, url);
    }
    final completer = Completer<HttpClientResponse>();
    // `ApiTrace.call` awaits `execute`, which awaits the
    // completer, which completes when the request body is closed.
    // The record's duration is measured from `openUrl` to
    // `close`. We fire-and-forget because the interceptor must
    // return the request synchronously to the caller.
    unawaited(
      ApiTrace.call(
        _label(method, url),
        method: method,
        url: url,
        execute: () async {
          final response = await completer.future;
          return _toApiTraceResponse(response);
        },
      ),
    );
    final request = await _inner.openUrl(method, url);
    return TracedHttpClientRequest._(request, completer);
  }

  // --- Configuration: pass through to inner client --------------------------

  @override
  Duration get idleTimeout => _inner.idleTimeout;

  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;

  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;

  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;

  @override
  bool get autoUncompress => _inner.autoUncompress;

  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  @override
  String? get userAgent => _inner.userAgent;

  @override
  set userAgent(String? value) => _inner.userAgent = value;

  // --- URL helpers: all delegate to openUrl (so they are traced) -----------

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      openUrl('GET', Uri(scheme: 'http', host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      openUrl('POST', Uri(scheme: 'http', host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      openUrl('PUT', Uri(scheme: 'http', host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      openUrl(
          'DELETE', Uri(scheme: 'http', host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      openUrl('PATCH', Uri(scheme: 'http', host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      openUrl('HEAD', Uri(scheme: 'http', host: host, port: port, path: path));

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  @override
  Future<HttpClientRequest> open(
          String method, String host, int port, String path) =>
      openUrl(method, Uri(scheme: 'http', host: host, port: port, path: path));

  // --- Auth, credentials, proxy: pass through ------------------------------

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) =>
      _inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) =>
      _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  set authenticate(
          Future<bool> Function(Uri url, String scheme, String? realm)? f) =>
      _inner.authenticate = f;

  @override
  set authenticateProxy(
          Future<bool> Function(
                  String host, int port, String scheme, String? realm)?
              f) =>
      _inner.authenticateProxy = f;

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  set badCertificateCallback(
          bool Function(X509Certificate cert, String host, int port)?
              callback) =>
      _inner.badCertificateCallback = callback;

  @override
  set connectionFactory(
          Future<ConnectionTask<Socket>> Function(
                  Uri url, String? proxyHost, int? proxyPort)?
              factory) =>
      _inner.connectionFactory = factory;

  @override
  set keyLog(void Function(String line)? callback) => _inner.keyLog = callback;
}

/// Composition-style [HttpClientRequest] implementation. Forwards
/// every member to an inner [HttpClientRequest]. Only [close]
/// completes the inspector's pending completer with the response
/// (status + duration).
class TracedHttpClientRequest implements HttpClientRequest {
  TracedHttpClientRequest._(this._inner, this._completer);

  final HttpClientRequest _inner;
  final Completer<HttpClientResponse> _completer;

  @override
  Future<HttpClientResponse> close() async {
    try {
      final response = await _inner.close();
      if (!_completer.isCompleted) {
        _completer.complete(response);
      }
      return response;
    } catch (e, st) {
      if (!_completer.isCompleted) {
        _completer.completeError(e, st);
      }
      rethrow;
    }
  }

  // --- Request writing: pass through ---------------------------------------

  @override
  void add(List<int> data) => _inner.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) => _inner.addStream(stream);

  @override
  Future<void> flush() => _inner.flush();

  @override
  void write(Object? object) => _inner.write(object);

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) =>
      _inner.writeAll(objects, separator);

  @override
  void writeCharCode(int charCode) => _inner.writeCharCode(charCode);

  @override
  void writeln([Object? object = '']) => _inner.writeln(object);

  // --- Configuration: pass through -----------------------------------------

  @override
  HttpHeaders get headers => _inner.headers;

  @override
  int get contentLength => _inner.contentLength;

  @override
  set contentLength(int value) => _inner.contentLength = value;

  @override
  bool get persistentConnection => _inner.persistentConnection;

  @override
  set persistentConnection(bool value) => _inner.persistentConnection = value;

  @override
  bool get followRedirects => _inner.followRedirects;

  @override
  set followRedirects(bool value) => _inner.followRedirects = value;

  @override
  int get maxRedirects => _inner.maxRedirects;

  @override
  set maxRedirects(int value) => _inner.maxRedirects = value;

  @override
  bool get bufferOutput => _inner.bufferOutput;

  @override
  set bufferOutput(bool value) => _inner.bufferOutput = value;

  @override
  Encoding get encoding => _inner.encoding;

  @override
  set encoding(Encoding value) => _inner.encoding = value;

  @override
  String get method => _inner.method;

  @override
  Uri get uri => _inner.uri;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) =>
      _inner.abort(exception, stackTrace);

  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;

  @override
  List<Cookie> get cookies => _inner.cookies;

  @override
  Future<HttpClientResponse> get done => _inner.done;
}

/// Builds an [ApiTraceResponse] from a [dart:io HttpClientResponse].
/// Captures status code and headers. Body capture is intentionally
/// NOT performed at this layer: the underlying `HttpClientResponse`
/// streams chunks and buffering arbitrary payloads in memory just
/// for the timeline is wasteful. Use `ApiTrace.call` directly at
/// the call site if body capture is required.
ApiTraceResponse _toApiTraceResponse(HttpClientResponse response) {
  // `HttpHeaders` is iterable and produces `MapEntry<String,
  // List<String>>`. The inspector's `ApiTraceResponse` expects
  // `Map<String, String>`, so we collapse to the first value of
  // each header (sufficient for status / content-type display).
  final collapsed = <String, String>{};
  response.headers.forEach((name, values) {
    if (values.isNotEmpty) collapsed[name] = values.first;
  });
  return ApiTraceResponse(
    statusCode: response.statusCode,
    responseHeaders: collapsed,
  );
}
