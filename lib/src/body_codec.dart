// The body codec is the small, pure helper that truncates response
// bodies to `ApiTraceConfig.maxResponseBodyBytes` (default 4 KB,
// REQ-MODEL-006).
//
// `truncate` is the single entry point used by
// `ApiTraceRecord.fromCapture` (TASK-010) and (later) the render
// layer for displaying large bodies. The function is pure and
// total: it never throws, never mutates its inputs, and always
// returns a value that satisfies the `Object?` contract.

library;

/// Truncates a response body to at most `maxBytes` bytes/chars.
///
/// The contract is asserted by `test/body_codec_test.dart`:
/// - `null` -> `null`.
/// - `String` of length `<= maxBytes` -> unchanged; otherwise the
///   prefix of length `maxBytes`.
/// - `List<int>` of length `<= maxBytes` -> unchanged; otherwise
///   the prefix sublist of length `maxBytes`.
/// - Any other type -> `Object.toString()` then prefix-truncated.
/// - Boundary: `length == maxBytes` is unchanged.
/// - Boundary: `maxBytes == 0` returns `''` for strings and
///   `<int>[]` for byte lists.
///
/// Note: the package does not parse raw bytes; the developer is
/// responsible for returning a parsed representation (a `String`, a
/// `Map<String, Object?>`, a `List<int>`, etc.) from the `execute`
/// callback. The codec only truncates the prefix and never
/// attempts to decode.
Object? truncate(Object? body, int maxBytes) {
  if (body == null) return null;
  if (body is String) {
    return body.length <= maxBytes ? body : body.substring(0, maxBytes);
  }
  if (body is List<int>) {
    return body.length <= maxBytes ? body : body.sublist(0, maxBytes);
  }
  final s = body.toString();
  return s.length <= maxBytes ? s : s.substring(0, maxBytes);
}
