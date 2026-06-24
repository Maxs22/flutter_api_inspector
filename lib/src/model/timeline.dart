// The in-memory ring buffer of `ApiTraceRecord`s.
//
// `Timeline` is owned by `ApiTrace.timeline` (PR 2). It is a plain
// `List<ApiTraceRecord>` with head-insert + tail-evict semantics,
// which gives O(1) `append` and the natural newest-first ordering
// required by REQ-MODEL-004. The `latest` `ValueNotifier<String?>`
// is the rebuild signal the overlay subscribes to (REQ-UI-005).
//
// Concurrency model: Dart is single-threaded per isolate. Two
// interleaved `ApiTrace.call` invocations (one awaiting the
// `execute` callback while the other runs) both end with a
// synchronous `append` call from the event loop; the timeline
// ends up with the records in completion order, which is the
// contract REQ-MODEL-007 asserts.
//
// The list is exposed as an `UnmodifiableListView` to prevent
// external mutation that would corrupt the ordering invariant
// (REQ-MODEL-003, REQ-MODEL-008).

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_api_inspector/src/model/api_trace_record.dart';

/// In-memory ring buffer of API call records.
///
/// Constructed with an explicit `capacity` (the default is set by
/// the caller; `ApiTrace.timeline` uses `ApiTraceConfig.timelineCapacity`).
final class Timeline {
  /// The maximum number of records retained. When the buffer is
  /// full, the oldest record (at the tail) is evicted silently
  /// (REQ-MODEL-003).
  final int capacity;

  /// Head-to-tail storage (head = newest, tail = oldest). Exposed
  /// externally as an unmodifiable view.
  final List<ApiTraceRecord> _records = <ApiTraceRecord>[];

  /// Unmodifiable view onto `_records`. Mutations must go through
  /// `append` (or `clear`) so the ordering invariant is preserved.
  late final List<ApiTraceRecord> records = UnmodifiableListView(_records);

  /// Rebuild signal: set to the id of the most-recently-appended
  /// record. The overlay subscribes to this notifier and rebuilds
  /// when it changes.
  final ValueNotifier<String?> latest = ValueNotifier<String?>(null);

  /// Constructs a timeline with the given [capacity]. The capacity
  /// is required and must be positive; a non-positive value is
  /// normalised to 1 so the ring buffer always has at least one
  /// slot.
  Timeline({required this.capacity})
      : assert(capacity > 0, 'capacity must be > 0');

  /// Current number of records. Alias for `records.length`.
  int get size => _records.length;

  /// Appends [r] to the head of the buffer. If the buffer is at
  /// capacity, the oldest record (at the tail) is evicted silently
  /// (REQ-MODEL-003). The `latest` notifier is updated to `r.id`
  /// so subscribers (the overlay) can rebuild.
  void append(ApiTraceRecord r) {
    _records.insert(0, r);
    if (_records.length > capacity) {
      _records.removeLast();
    }
    latest.value = r.id;
  }

  /// Empties the timeline. Resets `latest` to `null`. Used by
  /// tests and (later) by an optional `ApiTrace.reset()` helper.
  void clear() {
    _records.clear();
    latest.value = null;
  }
}
