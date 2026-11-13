import 'package:flutter_api_inspector/src/overlay/icons.dart';
// One request card in the timeline list (REQ-UI-005, REQ-UI-008).
//
// `TimelineRow` is a `StatelessWidget` that renders a single
// `ApiTraceRecord` as a tappable card. The name and method lead,
// followed by the URL path and a wrapping line of status / timing
// metadata so narrow panels do not squeeze the request name away.
//
// The whole card is tappable; tapping it fires the `onTap`
// callback (typically: open the read-only detail screen).
// Grouping and newest-first ordering are the panel's responsibility,
// not this row's.
import 'package:flutter/material.dart';

import 'package:flutter_api_inspector/src/model/api_trace_record.dart';
import 'package:flutter_api_inspector/src/outcome.dart';
import 'package:flutter_api_inspector/src/overlay/theme.dart';

/// A single row in the timeline list.
class TimelineRow extends StatelessWidget {
  /// Creates a `TimelineRow`.
  ///
  /// [record] is the captured `ApiTraceRecord` to render.
  /// [onTap] opens the read-only detail screen.
  /// [now] is the reference time used to compute the
  /// "time-ago" label; if null, the row uses `DateTime.now()`.
  /// [relativeTimestamp] overrides the trailing timestamp with a
  /// relative offset (e.g. `+500ms`) when filtering by route scope.
  const TimelineRow({
    super.key,
    required this.record,
    required this.onTap,
    this.now,
    this.relativeTimestamp,
  });

  /// The record to render. Read-only; the row does not mutate it.
  final ApiTraceRecord record;

  /// Fired when the row is tapped.
  final VoidCallback onTap;

  /// Optional relative timestamp (e.g. `+500ms`) shown instead of
  /// the absolute "X ago" label when a route-scope filter is active.
  final String? relativeTimestamp;

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
      ApiTraceOutcome.success => InspectorIcons.checkCircle,
      ApiTraceOutcome.error => InspectorIcons.error,
      ApiTraceOutcome.cancelled => InspectorIcons.cancel,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Material(
        color: inspectorRowBackground(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(inspectorRadius),
          side: BorderSide(color: inspectorOutline(context), width: 0.7),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: tint.withValues(alpha: 0.08),
          highlightColor: tint.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        record.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontSize: 15, fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _MethodChip(method: record.method),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _pathOf(record.url),
                  style: TextStyle(
                      fontSize: 12,
                      color: inspectorMuted(context),
                      fontFamily:
                          'packages/flutter_api_inspector/InspectorMono',
                      height: 1.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(iconData, color: tint, size: 18),
                        const SizedBox(width: 6),
                        if (record.statusCode != null)
                          _StatusBadge(
                              statusCode: record.statusCode!, tint: tint)
                        else
                          Text('—',
                              style: TextStyle(color: inspectorMuted(context))),
                      ],
                    ),
                    Text(_formatDuration(record.duration),
                        style: TextStyle(
                            fontSize: 12,
                            color: inspectorMuted(context),
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ])),
                    Text(
                        relativeTimestamp ??
                            _timeAgo(record.completedAt, now ?? DateTime.now()),
                        style: TextStyle(
                            fontSize: 12,
                            color: inspectorMuted(context),
                            fontFamily: relativeTimestamp != null
                                ? 'packages/flutter_api_inspector/InspectorMono'
                                : null)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Extracts the path (and query) from a URL. Returns the
  /// full URL string as a fallback if the path is empty.
  static String _pathOf(Uri url) {
    final path = url.path.isEmpty ? url.toString() : url.path;
    if (url.hasQuery) return '$path?${url.query}';
    return path;
  }

  /// Formats a `Duration` for the card's metadata line.
  /// Examples: `50ms`, `1.20s`, `3.45s`.
  static String _formatDuration(Duration d) {
    if (d.inMilliseconds < 1000) {
      return '${d.inMilliseconds}ms';
    }
    final seconds = d.inMilliseconds / 1000.0;
    return '${seconds.toStringAsFixed(2)}s';
  }

  /// Formats a `DateTime` as a relative "X ago" label.
  /// Examples: `3s ago`, `1m ago`, `2h ago`, `3d ago`.
  /// Falls back to `"just now"` when [t] is in the future
  /// relative to [now] (negative difference — clock skew / NTP
  /// correction on devices and emulators).
  static String _timeAgo(DateTime t, DateTime now) {
    final diff = now.difference(t);
    if (diff.isNegative) return 'just now';
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
    final base = inspectorMethodColor(context, method);
    final fill = Color.alphaBlend(
        base.withValues(alpha: 0.12), inspectorRowBackground(context));
    final color = inspectorEnsureContrast(base, fill, minRatio: 4.5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(method,
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFamily: 'packages/flutter_api_inspector/InspectorMono',
              letterSpacing: 0.3)),
    );
  }
}

/// Small badge showing the HTTP status code, color-coded by
/// status class (2xx green, 3xx blue, 4xx orange, 5xx red).
/// Small text is contrast-adjusted against the actual tinted fill.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.statusCode, required this.tint});
  final int statusCode;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final base = _statusColor(statusCode, tint);
    final fill = Color.alphaBlend(
        base.withValues(alpha: 0.12), inspectorRowBackground(context));
    final color = inspectorEnsureContrast(base, fill, minRatio: 4.5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text('$statusCode',
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()])),
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
