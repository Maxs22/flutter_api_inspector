// Group header for the timeline panel.
//
// A "group" is a sequence of consecutive records whose
// start-to-start gap is shorter than `ApiTraceConfig.flowGroupGap`.
// The header summarizes the group: a count, the total
// duration, the outcome tint, and the group's start
// timestamp. The header is collapsible so a developer can
// hide a long burst while keeping the FAB list scannable.

import 'package:flutter/material.dart';

import 'package:flutter_api_inspector/src/model/api_trace_record.dart';
import 'package:flutter_api_inspector/src/outcome.dart';
import 'package:flutter_api_inspector/src/overlay/theme.dart';

/// The header strip rendered above each group of related
/// records in [TimelinePanel]. The user can tap the header
/// to collapse / expand the group.
class TimelineGroupHeader extends StatefulWidget {
  /// Creates a `TimelineGroupHeader`.
  ///
  /// [group] is the group to render. The widget does NOT own
  /// the group; it only reads it.
  /// [expanded] is the initial expansion state.
  /// [onToggle] is fired when the user taps the header.
  const TimelineGroupHeader({
    super.key,
    required this.group,
    required this.expanded,
    required this.onToggle,
  });

  /// The group this header represents.
  final TimelineGroup group;

  /// Initial expansion state. The parent owns the persistent
  /// state.
  final bool expanded;

  /// Fired when the user taps the header.
  final VoidCallback onToggle;

  @override
  State<TimelineGroupHeader> createState() => _TimelineGroupHeaderState();
}

class _TimelineGroupHeaderState extends State<TimelineGroupHeader> {
  @override
  Widget build(BuildContext context) {
    final g = widget.group;
    final count = g.records.length;
    final allOk = g.records
        .every((ApiTraceRecord r) => r.outcome == ApiTraceOutcome.success);
    final anyError =
        g.records.any((ApiTraceRecord r) => r.outcome == ApiTraceOutcome.error);
    final tint = allOk
        ? inspectorSuccess(context)
        : (anyError ? inspectorError(context) : inspectorMuted(context));

    return Material(
      color: inspectorGroupHeaderBackground(context),
      child: InkWell(
        onTap: widget.onToggle,
        splashColor: tint.withValues(alpha: 0.08),
        highlightColor: tint.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: <Widget>[
              AnimatedRotation(
                turns: widget.expanded ? 0 : -0.25,
                duration: const Duration(milliseconds: 150),
                child: Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: inspectorMuted(context),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                allOk
                    ? Icons.check_circle_rounded
                    : (anyError ? Icons.error_rounded : Icons.bolt_rounded),
                size: 14,
                color: tint,
              ),
              const SizedBox(width: 6),
              Text(
                '$count ${count == 1 ? 'call' : 'calls'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 10),
              _stat(
                context,
                icon: Icons.schedule_rounded,
                text: _formatDuration(g.totalDuration),
                color: inspectorMuted(context),
              ),
              const Spacer(),
              _stat(
                context,
                icon: Icons.access_time_rounded,
                text: _formatTime(g.startedAt),
                color: inspectorMuted(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context,
      {required IconData icon, required String text, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  static String _formatDuration(Duration d) {
    if (d.inMilliseconds < 1000) return '${d.inMilliseconds}ms';
    if (d.inSeconds < 60) {
      return '${(d.inMilliseconds / 1000.0).toStringAsFixed(2)}s';
    }
    return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
  }

  static String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

/// A group of consecutive [ApiTraceRecord]s that belong to
/// the same logical "flow" (per `ApiTraceConfig.flowGroupGap`).
class TimelineGroup {
  /// Creates a `TimelineGroup`.
  ///
  /// [records] is the list of records in the group. The list
  /// is newest-first (the timeline is head-insert-only, so the
  /// first element is the most recent). The group is owned by
  /// the panel; the header only reads from it.
  TimelineGroup(this.records)
      : startedAt = records.last.startedAt,
        completedAt = records.first.completedAt,
        totalDuration =
            records.first.completedAt.difference(records.last.startedAt);

  /// The records in the group, newest-first.
  final List<ApiTraceRecord> records;

  /// The earliest start time among the group's records (when
  /// the flow began — the oldest record's start).
  final DateTime startedAt;

  /// The latest completion time among the group's records (when
  /// the flow ended — the newest record's end).
  final DateTime completedAt;

  /// The wall-clock duration of the whole flow
  /// (from the oldest record's start to the newest record's
  /// end). Always non-negative because the timeline is
  /// head-insert-only, so `records.first` is always newer
  /// than `records.last`.
  final Duration totalDuration;
}
