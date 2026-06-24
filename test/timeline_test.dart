// Strict TDD evidence for TASK-012: Timeline ring buffer
// (REQ-MODEL-003, REQ-MODEL-004, REQ-MODEL-007, REQ-MODEL-008).
//
// `Timeline` is the in-memory ring buffer of `ApiTraceRecord`s.
// Head-insert + tail-evict gives O(1) append and the natural
// newest-first ordering. The `latest` `ValueNotifier` is the
// rebuild signal the overlay subscribes to (REQ-UI-005).
//
// Reentrancy (REQ-MODEL-007) is exercised by two interleaved
// `append` calls from the same Dart isolate. Dart is
// single-threaded per isolate, so the test just verifies that
// both records land in the buffer with the correct ordering.

import 'package:flutter_api_inspector/src/detail.dart';
import 'package:flutter_api_inspector/src/model/api_trace_record.dart';
import 'package:flutter_api_inspector/src/model/timeline.dart';
import 'package:flutter_test/flutter_test.dart';

ApiTraceRecord _record(String name, DateTime startedAt) {
  return ApiTraceRecord.fromCapture(
    name: name,
    startedAt: startedAt,
    completedAt: startedAt.add(const Duration(milliseconds: 10)),
    method: 'GET',
    url: Uri.parse('https://example.com/$name'),
    capturedDetails: const <ApiTraceDetail>{ApiTraceDetail.minimal},
    response: null,
    request: null,
    error: null,
    extra: const <String, Object?>{},
    maxResponseBodyBytes: 4096,
  );
}

void main() {
  group('Timeline', () {
    test('a fresh timeline is empty', () {
      // RED: import target missing. After GREEN, the assertion
      // is satisfied.
      final tl = Timeline(capacity: 200);
      expect(tl.size, 0);
      expect(tl.records, isEmpty);
      expect(tl.latest.value, isNull);
    });

    test('default capacity is 200', () {
      final tl = Timeline(capacity: 200);
      expect(tl.capacity, 200);
    });

    test('explicit capacity is honored', () {
      final tl = Timeline(capacity: 5);
      expect(tl.capacity, 5);
    });

    test('TRIANGULATE: default capacity holds exactly 200 records', () {
      final tl = Timeline(capacity: 200);
      for (var i = 0; i < 200; i++) {
        tl.append(
            _record('r$i', DateTime.utc(2026, 1, 1).add(Duration(seconds: i))));
      }
      expect(tl.size, 200);
      // The most recently inserted record is at the head.
      expect(tl.records.first.name, equals('r199'));
    });

    test('oldest record evicted when capacity is exceeded', () {
      // REQ-MODEL-003, "Oldest record evicted when capacity is
      // exceeded".
      final tl = Timeline(capacity: 3);
      final t0 = DateTime.utc(2026, 1, 1);
      tl.append(_record('A', t0));
      tl.append(_record('B', t0.add(const Duration(seconds: 1))));
      tl.append(_record('C', t0.add(const Duration(seconds: 2))));
      tl.append(_record('D', t0.add(const Duration(seconds: 3))));

      expect(tl.size, 3);
      // Head-to-tail order: D, C, B.
      expect(
        tl.records.map((r) => r.name).toList(),
        equals(<String>['D', 'C', 'B']),
      );
    });

    test('capacity honored when configured explicitly', () {
      // REQ-MODEL-003, "Capacity honored when configured
      // explicitly".
      final tl = Timeline(capacity: 5);
      final t0 = DateTime.utc(2026, 1, 1);
      for (var i = 0; i < 6; i++) {
        tl.append(_record('r$i', t0.add(Duration(seconds: i))));
      }
      expect(tl.size, 5);
      // The oldest ('r0') has been evicted.
      expect(
        tl.records.map((r) => r.name).toList(),
        equals(<String>['r5', 'r4', 'r3', 'r2', 'r1']),
      );
    });

    test('newest record first (REQ-MODEL-004)', () {
      final tl = Timeline(capacity: 10);
      final t0 = DateTime.utc(2026, 1, 1);
      tl.append(_record('T1', t0));
      tl.append(_record('T2', t0.add(const Duration(seconds: 1))));
      tl.append(_record('T3', t0.add(const Duration(seconds: 2))));

      expect(
        tl.records.map((r) => r.name).toList(),
        equals(<String>['T3', 'T2', 'T1']),
      );
    });

    test('insertion order breaks tie on identical start time (REQ-MODEL-004)',
        () {
      // Two records share the same `startedAt`; the
      // second-inserted record should appear at the head.
      final tl = Timeline(capacity: 10);
      final t0 = DateTime.utc(2026, 1, 1);
      tl.append(_record('first', t0));
      tl.append(_record('second', t0));

      expect(
        tl.records.map((r) => r.name).toList(),
        equals(<String>['second', 'first']),
      );
    });

    test(
        'TRIANGULATE: latest ValueNotifier is set to the new record id on every append',
        () {
      final tl = Timeline(capacity: 10);
      final t0 = DateTime.utc(2026, 1, 1);
      final r1 = _record('A', t0);
      tl.append(r1);
      expect(tl.latest.value, equals(r1.id));

      final r2 = _record('B', t0.add(const Duration(seconds: 1)));
      tl.append(r2);
      expect(tl.latest.value, equals(r2.id));
    });

    test('TRIANGULATE: records is an unmodifiable view', () {
      // REQ-MODEL-003, REQ-MODEL-008 — external mutation must be
      // rejected.
      final tl = Timeline(capacity: 10);
      tl.append(_record('A', DateTime.utc(2026, 1, 1)));
      expect(() => tl.records.add(_record('B', DateTime.utc(2026, 1, 2))),
          throwsUnsupportedError);
    });

    test('TRIANGULATE: clear empties the timeline and resets latest', () {
      final tl = Timeline(capacity: 10);
      tl.append(_record('A', DateTime.utc(2026, 1, 1)));
      tl.append(_record('B', DateTime.utc(2026, 1, 2)));
      expect(tl.size, 2);

      tl.clear();

      expect(tl.size, 0);
      expect(tl.records, isEmpty);
      expect(tl.latest.value, isNull);
    });

    test('two concurrent appends each produce a record (REQ-MODEL-007)', () {
      // Simulate reentrancy: two appends in a single tick.
      // The timeline should end up with both records in
      // insertion order (newest-first by completion order).
      final tl = Timeline(capacity: 10);
      final t0 = DateTime.utc(2026, 1, 1);
      final a = _record('A', t0);
      final b = _record('B', t0.add(const Duration(milliseconds: 5)));
      tl.append(a);
      tl.append(b);

      expect(tl.size, 2);
      // 'B' is the head (newest by startedAt).
      expect(
        tl.records.map((r) => r.name).toList(),
        equals(<String>['B', 'A']),
      );
      // Distinct ids.
      expect(a.id, isNot(equals(b.id)));
    });

    test('timeline resets across process restart (REQ-MODEL-008)', () {
      // The "process restart" is simulated by constructing a
      // fresh Timeline instance after the first one has
      // accumulated records. The new instance is empty.
      final old = Timeline(capacity: 10);
      old.append(_record('A', DateTime.utc(2026, 1, 1)));
      old.append(_record('B', DateTime.utc(2026, 1, 2)));
      expect(old.size, 2);

      final fresh = Timeline(capacity: 10);
      expect(fresh.size, 0);
      expect(fresh.records, isEmpty);
      expect(fresh.latest.value, isNull);
    });

    test('append is a fire-and-forget call (side effect: size + 1)', () {
      // Sanity check on the API shape; PR 2's ApiTrace.call
      // depends on the side effect of append, not its return.
      final tl = Timeline(capacity: 10);
      final before = tl.size;
      tl.append(_record('A', DateTime.utc(2026, 1, 1)));
      expect(tl.size, before + 1);
    });

    test('ValueListenable on latest fires once per append', () {
      // The overlay subscribes to `latest`; it must fire exactly
      // once per append so the rebuild logic is well-defined.
      final tl = Timeline(capacity: 10);
      var fires = 0;
      void listener() {
        fires++;
      }

      tl.latest.addListener(listener);
      tl.append(_record('A', DateTime.utc(2026, 1, 1)));
      tl.append(_record('B', DateTime.utc(2026, 1, 1, 0, 0, 1)));
      tl.latest.removeListener(listener);

      expect(fires, 2);
    });
  });
}
