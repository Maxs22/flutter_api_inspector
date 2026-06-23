// Internal id generator for `ApiTraceRecord.id` (REQ-MODEL-001).
//
// The proposal's acceptance criteria and design Q6 require no
// `package:uuid` dependency. We use `Random.secure()` and hex-encode
// 16 random bytes to 32 lowercase hex characters. Collision
// probability for N records is ~N²/2¹²⁹, which is negligible for the
// default 200-record ring buffer.
//
// Portability note: we avoid `Random.nextBytes` (added in Dart 3.6)
// and `package:convert`'s `base16Lowercase` (a separate dependency)
// to keep the implementation compatible with the package's SDK
// floor (`>=3.2.0`) and zero non-SDK dependencies.

import 'dart:math';

/// A lazily-initialised, cryptographically-secure RNG. Captured in a
/// top-level `final` so the function can be invoked without
/// allocation overhead per call.
final Random _rng = Random.secure();

/// The lowercase hex alphabet (0-9, a-f). Used to avoid pulling in
/// `package:convert` for a single 32-character id.
const String _hexAlphabet = '0123456789abcdef';

/// Returns a fresh id: 16 random bytes hex-encoded to 32 lowercase
/// hex characters.
///
/// Format contract: `^[0-9a-f]{32}$` — asserted by `test/id_test.dart`.
String generateId() {
  // Six bytes fit in 12 hex chars, so we encode 16 bytes in 8 pairs.
  // Using a single pass keeps the function branch-free and fast.
  final out = List<int>.filled(32, 0);
  for (var i = 0; i < 16; i++) {
    final byte = _rng.nextInt(256);
    out[i * 2] = _hexAlphabet.codeUnitAt(byte >> 4);
    out[i * 2 + 1] = _hexAlphabet.codeUnitAt(byte & 0x0f);
  }
  return String.fromCharCodes(out);
}
