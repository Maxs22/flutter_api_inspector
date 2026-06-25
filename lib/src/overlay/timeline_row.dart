// One row in the timeline list (REQ-UI-005, REQ-UI-008).
//
// `TimelineRow` is a `StatelessWidget` that renders a single
// `ApiTraceRecord` as a tappable list row. Visual layout
// (left-to-right):
//
//   [icon] [METHOD] Name                                [STATUS]  450ms
//          /url-path                                                 3s ago
//
// The whole row is tappable; tapping it fires the `onTap`
// callback (typically: open the read-only detail screen).
//
// The row is a thin presentation widget; the grouping and
// newest-first ordering are the panel's responsibility, not
// this row's.

import 'package:flutter/material.dart';

import 'package:flutter_api_inspector/src/model/api_trace_record.dart';
import 'package:flutter_api_inspector/src/outcome.dart';
import 'package:flutter_api_inspector/src/overlay/theme.dart';

/// A single row in the timeline list.
class TimelineRow extends StatelessWidget {
  /// Creates a `TimelineRow`.
  ///
  /// [record] is the captured `ApiTraceRecord` to render.
  /// [onTap] is the callback fired when the row is tapped.
  /// [now] is the reference time used to compute the
  /// "time-ago" label; if null, the row uses `DateTime.now()`.
  const TimelineRow({
    super.key,
    required this.record,
    required this.onTap,
    this.now,
  });

  /// The record to render. Read-only; the row does not mutate
  /// the record.
  final ApiTraceRecord record;

  /// Fired when the row is tapped.
  final VoidCallback onTap;

  /// Reference time for the "X ago" label. Tests pass a fixed
  /// value; production code leaves it null and uses now().
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final tint = switch (record.outcome) {
      ApiTraceOutcome.success => inspectorSuccess(context),
      ApiTraceOutcome.error => inspectorError(context),
      ApiTraceOutcome.cancelled => inspectorMuted(context),
    };

    final iconData = switch (record.outcome) {
      ApiTraceOutcome.success => Icons.check_circle_rounded,
      ApiTraceOutcome.error => Icons.error_rounded,
      ApiTraceOutcome.cancelled => Icons.cancel_rounded,
    };

    return Material(
      color: inspectorRowBackground(context),
      child: InkWell(
        onTap: onTap,
        onHover: null,
        splashColor: tint.withValues(alpha: 0.08),
        highlightColor: tint.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Icon(iconData, color: tint, size: 18),
              const SizedBox(width: 10),
              _MethodChip(method: record.method),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      record.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        height: 1.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _pathOf(record.url),
                      style: TextStyle(
                        fontSize: 11,
                        color: inspectorMuted(context),
                        fontFamily: 'monospace',
                        height: 1.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (record.statusCode != null)
                _StatusBadge(statusCode: record.statusCode!, tint: tint)
              else
                Text(
                  '—',
                  style: TextStyle(
                    color: inspectorMuted(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(width: 10),
              SizedBox(
                width: 56,
                child: Text(
                  _formatDuration(record.duration),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures()
                    ],
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 52,
                child: Text(
                  _timeAgo(record.completedAt, now ?? DateTime.now()),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 10,
                    color: inspectorMuted(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Extracts the path (and query) from a URL. Returns the
  /// full URL string as a fallback if the input is not a
  /// well-formed URI.
  static String _pathOf(Uri url) {
    final path = url.path.isEmpty ? url.toString() : url.path;
    if (url.hasQuery) return '$path?${url.query}';
    return path;
  }

  /// Formats a `Duration` for the row's trailing column.
  /// Examples: `50ms`, `1.2s`, `3.45s`. Trailing "ms"/"s" is
  /// kept short to maximize column density.
  static String _formatDuration(Duration d) {
    if (d.inMilliseconds < 1000) {
      return '${d.inMilliseconds}ms';
    }
    final seconds = d.inMilliseconds / 1000.0;
    return '${seconds.toStringAsFixed(2)}s';
  }

  /// Formats a `DateTime` as a relative "X ago" label.
  /// Examples: `3s ago`, `1m ago`, `2h ago`, `3d ago`.
  static String _timeAgo(DateTime t, DateTime now) {
    final diff = now.difference(t);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

/// Small pill chip showing the HTTP method (GET/POST/...).
/// Color-coded for quick visual scanning of the timeline.
class _MethodChip extends StatelessWidget {
  const _MethodChip({required this.method});

  final String method;

  @override
  Widget build(BuildContext context) {
    final color = _methodColor(method);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        method,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  static Color _methodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return const Color(0xFF2563EB); // blue-600
      case 'POST':
        return const Color(0xFF16A34A); // green-600
      case 'PUT':
      case 'PATCH':
        return const Color(0xFFEA580C); // orange-600
      case 'DELETE':
        return const Color(0xFFDC2626); // red-600
      case 'HEAD':
      case 'OPTIONS':
        return const Color(0xFF6B7280); // gray-500
      default:
        return const Color(0xFF4B5563); // gray-600
    }
  }
}

/// Small badge showing the HTTP status code, color-coded by
/// status class (2xx green, 3xx blue, 4xx orange, 5xx red).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.statusCode, required this.tint});

  final int statusCode;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(statusCode, tint);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$statusCode',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  static Color _statusColor(int code, Color fallback) {
    if (code < 200) return const Color(0xFF6B7280); // 1xx
    if (code < 300) return const Color(0xFF16A34A); // 2xx
    if (code < 400) return const Color(0xFF2563EB); // 3xx
    if (code < 500) return const Color(0xFFEA580C); // 4xx
    return const Color(0xFFDC2626); // 5xx
  }
}
