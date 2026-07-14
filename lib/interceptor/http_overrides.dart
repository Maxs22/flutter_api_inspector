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
//   ApiTrace.runApp(const MyApp());
// }
// ```
//
// Body capture strategy: `_TracedHttpClientRequest.close()` eagerly
// buffers the full response body (via `await for`) before returning to
// the caller. The caller receives a `_ReplayHttpClientResponse` that
// streams the buffered chunks — transparent to GetConnect, http, Dio,
// and any other dart:io-backed client. Buffering is bounded by
// `ApiTrace.config.maxResponseBodyBytes` for capture; the replay
// buffer holds all bytes (acceptable for REST API payloads in debug
// mode). The `ApiTrace` record is completed synchronously before
// `close()` returns, so no microtask race between the inspector and
// the test assertion.
//
// Scope: this file uses `dart:io` and is therefore mobile/desktop
// only. Web builds must not import this file.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_api_inspector/src/api_trace.dart';
import 'package:flutter_api_inspector/src/detail.dart';
import 'package:flutter_api_inspector/src/interceptor_coordination.dart';
import 'package:flutter_api_inspector/src/model/api_trace_response.dart';
import 'package:flutter_api_inspector/src/route_scope.dart';

/// [HttpOverrides] that returns a [TracedHttpClient] for every
/// `createHttpClient` call. Install once at process start:
///
/// ```dart
/// HttpOverrides.global = TracedHttpOverrides();
/// ```
///
/// The optional [nameFor] callback lets callers customize the
/// human-readable label that shows up in the inspector timeline
/// (default: `"<METHOD> <path>"`).
class TracedHttpOverrides extends HttpOverrides {
  TracedHttpOverrides({this.nameFor}) {
    // Let TracedDioInterceptor know this layer is active so Dio
    // requests (which route through dart:io HttpClient on
    // mobile/desktop) are not recorded twice.
    InterceptorCoordination.httpOverridesActive = true;
  }

  final String Function(String method, Uri url)? nameFor;

  /// Recursion guard so the inner `HttpClient` inside [TracedHttpClient]
  /// doesn't get wrapped in another [TracedHttpClient].
  static bool _bypass = false;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    if (_bypass) {
      return super.createHttpClient(context);
    }
    return TracedHttpClient._withNameFor(nameFor);
  }
}

/// Composition-style [HttpClient]. Forwards every member to an inner
/// client; only [openUrl] instruments the call into the inspector.
class TracedHttpClient implements HttpClient {
  /// Public constructor for direct use (e.g. tests, manual wiring).
  TracedHttpClient({String Function(String, Uri)? nameFor})
      : this._withNameFor(nameFor);

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

  // --- Traced URL entry point -----------------------------------------------

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    if (!ApiTrace.enabled) {
      return _inner.openUrl(method, url);
    }
    final completer = Completer<ApiTraceResponse>();

    // Tag with the current route scope (REQ-RS-003).
    final scope = RouteScope.current;
    final taggedExtra = <String, Object?>{
      if (scope != null) 'routeScopeId': scope.scopeId,
      if (scope != null) 'routeName': scope.routeName,
    };

    unawaited(
      ApiTrace.call(
        _label(method, url),
        method: method,
        url: url,
        execute: () => completer.future,
        extra: taggedExtra,
      ),
    );
    final request = await _inner.openUrl(method, url);
    return _TracedHttpClientRequest(request, completer);
  }

  // --- Configuration: pass through ------------------------------------------

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

  // --- URL helpers: all delegate to openUrl ---------------------------------

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

  // --- Auth / proxy: pass through -------------------------------------------

  @override
  void addCredentials(
          Uri url, String realm, HttpClientCredentials credentials) =>
      _inner.addCredentials(url, realm, credentials);
  @override
  void addProxyCredentials(String host, int port, String realm,
          HttpClientCredentials credentials) =>
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

/// Composition-style [HttpClientRequest]. [close] is overridden to
/// eagerly buffer the response body so the inspector can capture it.
/// All other members forward to the inner request unchanged.
class _TracedHttpClientRequest implements HttpClientRequest {
  _TracedHttpClientRequest(this._inner, this._completer);

  final HttpClientRequest _inner;
  final Completer<ApiTraceResponse> _completer;

  /// Request-body bytes captured as the caller writes them, bounded
  /// by `ApiTrace.config.maxResponseBodyBytes` (the package's single
  /// body-capture cap). Only filled when the active detail set
  /// includes `request` or `full`.
  final List<int> _requestBodyBuffer = <int>[];

  bool get _wantRequestBody {
    final details = ApiTrace.config.details;
    return details.contains(ApiTraceDetail.request) ||
        details.contains(ApiTraceDetail.full);
  }

  void _captureRequestBytes(List<int> data) {
    if (!_wantRequestBody) return;
    final int remaining =
        ApiTrace.config.maxResponseBodyBytes - _requestBodyBuffer.length;
    if (remaining <= 0) return;
    _requestBodyBuffer
        .addAll(data.length <= remaining ? data : data.sublist(0, remaining));
  }

  /// Closes the request, buffers the full response body (if detail level
  /// includes `response`), completes the inspector completer, and returns
  /// a [_ReplayHttpClientResponse] so the caller can still read the body.
  @override
  Future<HttpClientResponse> close() async {
    try {
      // Collapse request headers before closing: the caller has
      // finished writing, so `_inner.headers` is final at this point.
      final requestHeaders = <String, String>{};
      _inner.headers.forEach((name, values) {
        if (values.isNotEmpty) requestHeaders[name] = values.first;
      });

      // Decode the request-body bytes captured by the write wrappers
      // (empty unless the detail set includes `request` / `full`).
      String? requestBody;
      if (_requestBodyBuffer.isNotEmpty) {
        try {
          final decoded = utf8.decode(_requestBodyBuffer, allowMalformed: true);
          if (decoded.isNotEmpty) requestBody = decoded;
        } catch (_) {}
      }

      final rawResponse = await _inner.close();

      // Collapse response headers once (used for both paths below).
      final responseHeaders = <String, String>{};
      rawResponse.headers.forEach((name, values) {
        if (values.isNotEmpty) responseHeaders[name] = values.first;
      });

      final details = ApiTrace.config.details;
      final captureBody = details.contains(ApiTraceDetail.response) ||
          details.contains(ApiTraceDetail.full);

      if (!captureBody) {
        // Complete without the response body; caller reads it from
        // the raw stream. `fromCapture` redacts headers / request
        // body further if the detail set doesn't include them.
        _completer.complete(ApiTraceResponse(
          statusCode: rawResponse.statusCode,
          requestHeaders: requestHeaders,
          responseHeaders: responseHeaders,
          requestBody: requestBody,
        ));
        return rawResponse;
      }

      // Eagerly buffer the full body for capture and replay.
      // Only REST-API payloads are expected in debug mode; large streaming
      // responses are an edge case the inspector does not optimise for.
      final int limit = ApiTrace.config.maxResponseBodyBytes;
      final captureBuffer = <int>[];
      final replayChunks = <List<int>>[];

      await for (final chunk in rawResponse) {
        replayChunks.add(chunk);
        final int remaining = limit - captureBuffer.length;
        if (remaining > 0) {
          captureBuffer.addAll(
              chunk.length <= remaining ? chunk : chunk.sublist(0, remaining));
        }
      }

      // Decode the captured bytes to a UTF-8 string.
      String? body;
      if (captureBuffer.isNotEmpty) {
        try {
          final decoded = utf8.decode(captureBuffer, allowMalformed: true);
          if (decoded.isNotEmpty) body = decoded;
        } catch (_) {}
      }

      // Complete BEFORE returning — ensures the record is in the timeline
      // before the next microtask the caller runs (no race condition).
      _completer.complete(ApiTraceResponse(
        statusCode: rawResponse.statusCode,
        requestHeaders: requestHeaders,
        responseHeaders: responseHeaders,
        requestBody: requestBody,
        responseBody: body,
      ));

      return _ReplayHttpClientResponse(rawResponse, replayChunks);
    } catch (e, st) {
      if (!_completer.isCompleted) {
        _completer.completeError(e, st);
      }
      rethrow;
    }
  }

  // --- Request writing: capture + forward -----------------------------------
  // Every body write funnels through [add] (the `write*` helpers are
  // implemented locally per the `IOSink` contract instead of
  // forwarding) so the capture buffer sees the same bytes the wire
  // does.

  @override
  void add(List<int> data) {
    _captureRequestBytes(data);
    _inner.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) {
    if (!_wantRequestBody) return _inner.addStream(stream);
    return _inner.addStream(stream.map((List<int> chunk) {
      _captureRequestBytes(chunk);
      return chunk;
    }));
  }

  @override
  Future<void> flush() => _inner.flush();

  @override
  void write(Object? object) {
    final string = '$object';
    if (string.isEmpty) return;
    add(encoding.encode(string));
  }

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {
    final iterator = objects.iterator;
    if (!iterator.moveNext()) return;
    if (separator.isEmpty) {
      do {
        write(iterator.current);
      } while (iterator.moveNext());
    } else {
      write(iterator.current);
      while (iterator.moveNext()) {
        write(separator);
        write(iterator.current);
      }
    }
  }

  @override
  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));

  @override
  void writeln([Object? object = '']) {
    write(object);
    write('\n');
  }

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

/// [HttpClientResponse] that replays pre-buffered body chunks.
/// All metadata (status code, headers, etc.) delegates to the original
/// response so the caller sees no difference.
class _ReplayHttpClientResponse extends StreamView<List<int>>
    implements HttpClientResponse {
  _ReplayHttpClientResponse(HttpClientResponse inner, List<List<int>> chunks)
      : _inner = inner,
        super(Stream.fromIterable(chunks));

  final HttpClientResponse _inner;

  @override
  int get statusCode => _inner.statusCode;
  @override
  String get reasonPhrase => _inner.reasonPhrase;
  @override
  int get contentLength => _inner.contentLength;
  @override
  bool get persistentConnection => _inner.persistentConnection;
  @override
  bool get isRedirect => _inner.isRedirect;
  @override
  List<RedirectInfo> get redirects => _inner.redirects;
  @override
  HttpHeaders get headers => _inner.headers;
  @override
  List<Cookie> get cookies => _inner.cookies;
  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;
  @override
  X509Certificate? get certificate => _inner.certificate;
  @override
  HttpClientResponseCompressionState get compressionState =>
      _inner.compressionState;
  @override
  Future<HttpClientResponse> redirect(
          [String? method, Uri? url, bool? followLoops]) =>
      _inner.redirect(method, url, followLoops);
  @override
  Future<Socket> detachSocket() => _inner.detachSocket();
}
