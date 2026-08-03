// The in-memory ring buffer of `ApiTraceRecord`s.
//
// `Timeline` is owned by `ApiTrace.timeline` (PR 2). Storage is a
// true circular buffer: a fixed-size backing list plus a head index.
// `append` writes the new record at the slot before the current head
// (wrapping around) and, once the buffer is full, simply overwrites
// the oldest slot — O(1) per append with no element shifting. The
// public `records` list is a read-only view that maps index 0 to the
// newest record, preserving the newest-first ordering required by
// REQ-MODEL-004. The `latest` `ValueNotifier<String?>` is the rebuild
// signal the overlay subscribes to (REQ-UI-005).
//
// Concurrency model: Dart is single-threaded per isolate. Two
// interleaved `ApiTrace.call` invocations (one awaiting the
// `execute` callback while the other runs) both end with a
// synchronous `append` call from the event loop; the timeline
// ends up with the records in completion order, which is the
// contract REQ-MODEL-007 asserts.
//
// The list is exposed as an unmodifiable `List` view to prevent
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
  /// full, the oldest record is overwritten silently
  /// (REQ-MODEL-003).
  final int capacity;

  /// Fixed-size circular storage. `_head` is the index of the
  /// newest record; logical index `i` lives at
  /// `(_head + i) % capacity`. Slots beyond `_size` are unused.
  late final List<ApiTraceRecord?> _buffer =
      List<ApiTraceRecord?>.filled(capacity, null);

  /// Index of the newest record inside [_buffer].
  int _head = 0;

  /// Number of records currently stored (`<= capacity`).
  int _size = 0;

  /// Unmodifiable, newest-first view onto the circular buffer.
  /// Mutations must go through `append` (or `clear`) so the
  /// ordering invariant is preserved.
  late final List<ApiTraceRecord> records = _TimelineView(this);

  /// Rebuild signal: set to the id of the most-recently-appended
  /// record. The overlay subscribes to this notifier and rebuilds
  /// when it changes.
  final ValueNotifier<String?> latest = ValueNotifier<String?>(null);

  /// Constructs a timeline with the given [capacity]. The capacity
  /// is required and must be positive (asserted in debug builds).
  Timeline({required this.capacity})
      : assert(capacity > 0, 'capacity must be > 0');

  /// Current number of records. Alias for `records.length`.
  int get size => _size;

  /// Appends [r] as the newest record. If the buffer is at
  /// capacity, the oldest record is overwritten silently
  /// (REQ-MODEL-003). O(1) — no element shifting. The `latest`
  /// notifier is updated to `r.id` so subscribers (the overlay)
  /// can rebuild.
  void append(ApiTraceRecord r) {
    _head = (_head - 1 + capacity) % capacity;
    _buffer[_head] = r;
    if (_size < capacity) {
      _size++;
    }
    latest.value = r.id;
  }

  /// Empties the timeline. Resets `latest` to `null`. Used by
  /// tests and (later) by an optional `ApiTrace.reset()` helper.
  void clear() {
    _buffer.fillRange(0, capacity, null);
    _head = 0;
    _size = 0;
    latest.value = null;
  }
}

/// Read-only `List` view over a [Timeline]'s circular buffer.
/// Index 0 is the newest record. Any mutation attempt throws
/// [UnsupportedError] (all `ListBase` mutators funnel through
/// `length=` / `[]=`).
final class _TimelineView extends ListBase<ApiTraceRecord> {
  _TimelineView(this._timeline);

  final Timeline _timeline;

  @override
  int get length => _timeline._size;

  @override
  set length(int newLength) {
    throw UnsupportedError('Cannot modify an unmodifiable list');
  }

  @override
  ApiTraceRecord operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index', _timeline._size);
    return _timeline._buffer[(_timeline._head + index) % _timeline.capacity]!;
  }

  @override
  void operator []=(int index, ApiTraceRecord value) {
    throw UnsupportedError('Cannot modify an unmodifiable list');
  }
}
