// One row in the timeline list (REQ-UI-005, REQ-UI-008).
//
// `TimelineRow` is a `StatelessWidget` that renders a single
// `ApiTraceRecord` as a tappable list row. The row shows the
// record's `name`, HTTP `method`, `statusCode` (or `—` for
// thrown exceptions where statusCode is null), and `duration`,
// tinted with the outcome color (green for success, red for
// error; per REQ-UI-008, 4xx and 5xx share the same red).
//
// The whole row is tappable; tapping it fires the `onTap`
// callback (typically: open the read-only detail screen).
//
// The row is a thin presentation widget; the filtering and
// newest-first ordering are the panel's responsibility, not
// this row's.

import 'package:flutter/material.dart';

import 'package:flutter_api_inspector/src/model/api_trace_record.dart';
import 'package:flutter_api_inspector/src/outcome.dart';
import 'package:flutter_api_inspector/src/overlay/colors.dart';

/// A single row in the timeline list.
class TimelineRow extends StatelessWidget {
  /// Creates a `TimelineRow`.
  ///
  /// [record] is the captured `ApiTraceRecord` to render.
  /// [onTap] is the callback fired when the row is tapped.
  const TimelineRow({
    super.key,
    required this.record,
    required this.onTap,
  });

  /// The record to render. Read-only; the row does not mutate
  /// the record.
  final ApiTraceRecord record;

  /// Fired when the row is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = outcomeColor(record.outcome);

    final iconData = switch (record.outcome) {
      ApiTraceOutcome.success => Icons.check_circle,
      ApiTraceOutcome.error => Icons.error,
      ApiTraceOutcome.cancelled => Icons.cancel,
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: <Widget>[
            Icon(iconData, color: tint, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    record.name,
                    style: TextStyle(
                      color: tint,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${record.method}  ${record.statusCode ?? '—'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDuration(record.duration),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// Formats a `Duration` for the row's trailing column.
  /// Examples: `50 ms`, `1.2 s`, `3.45 s`.
  static String _formatDuration(Duration d) {
    if (d.inMilliseconds < 1000) {
      return '${d.inMilliseconds} ms';
    }
    final seconds = d.inMilliseconds / 1000.0;
    return '${seconds.toStringAsFixed(2)} s';
  }
}
