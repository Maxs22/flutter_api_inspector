// Strict TDD evidence for TASK-008: id generator (no package:uuid).
//
// The id generator powers `ApiTraceRecord.id` (REQ-MODEL-001). The
// proposal's acceptance criteria and design Q6 require no
// `package:uuid` dependency; we use `Random.secure()` and hex-encode
// 16 random bytes to 32 lowercase hex characters. The 10,000-collision
// test documents the negligible-collision contract (collision
// probability is N²/2¹²⁹ for N records).

import 'package:flutter_api_inspector/src/id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generateId', () {
    test('returns a non-empty string', () {
      final id = generateId();
      expect(id, isNotEmpty);
    });

    test('returns exactly 32 lowercase hex characters', () {
      // 16 random bytes -> 32 hex chars. Format is part of the
      // contract; downstream code may parse the id as hex.
      final id = generateId();
      expect(id, hasLength(32));
      expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('10,000 generations produce 10,000 unique ids', () {
      // Documents the negligible-collision contract. With 128 bits
      // of entropy, the expected number of collisions in 10,000
      // ids is ~10⁸/2¹²⁹ ≈ 0.0.
      final ids = <String>{};
      for (var i = 0; i < 10000; i++) {
        ids.add(generateId());
      }
      expect(ids, hasLength(10000));
    });

    test('two consecutive calls produce different ids', () {
      // A simple uniqueness check; the 10,000-generation test is
      // the rigorous version.
      expect(generateId(), isNot(equals(generateId())));
    });
  });
}
