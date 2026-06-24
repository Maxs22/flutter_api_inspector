// The read-only detail screen shown when a row in the timeline
// is tapped (REQ-UI-007).
//
// `ApiTraceDetailScreen` is a `StatelessWidget` designed to be
// pushed via `Navigator.of(context).push(MaterialPageRoute<bool>(
// builder: (_) => ApiTraceDetailScreen(record: record)))` (per
// the design's resolved Q3: the route is a `MaterialPageRoute`
// for slide-in consistency).
//
// The screen renders every captured field in a scrollable
// `ListView`: name, method, url, statusCode, duration,
// startedAt, completedAt, captured details, request (if not
// null), response (if not null), error (if not null), extra.
// There are NO action buttons — no "Copy as cURL", no
// "Re-run", no "Export" (REQ-UI-007 out-of-scope list, locked
// at proposal time).
//
// The screen respects `Theme.of(context)` (per design.md
// resolved Q5). Outcome coloring is NOT applied to the detail
// screen's background; the outcome is rendered as a status
// badge so the developer can see at a glance whether the call
// succeeded.

import 'package:flutter/material.dart';

import 'package:flutter_api_inspector/src/model/api_trace_record.dart';
import 'package:flutter_api_inspector/src/outcome.dart';
import 'package:flutter_api_inspector/src/overlay/colors.dart';

/// The read-only detail screen for a single `ApiTraceRecord`.
class ApiTraceDetailScreen extends StatelessWidget {
  /// Creates the detail screen for [record].
  const ApiTraceDetailScreen({super.key, required this.record});

  /// The record to display.
  final ApiTraceRecord record;

  @override
  Widget build(BuildContext context) {
    final tint = outcomeColor(record.outcome);
    return Scaffold(
      appBar: AppBar(
        title: Text(record.name),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _StatusBadge(outcome: record.outcome, tint: tint),
          const SizedBox(height: 16),
          const _Section('Overview'),
          _Field('Name', record.name),
          _Field('Method', record.method),
          _Field('URL', record.url.toString()),
          _Field('Status', record.statusCode?.toString() ?? '—'),
          _Field('Duration', _formatDuration(record.duration)),
          _Field('Started at', record.startedAt.toIso8601String()),
          _Field('Completed at', record.completedAt.toIso8601String()),
          _Field('Captured details',
              record.capturedDetails.map((d) => d.name).toList().join(', ')),
          if (record.request != null) ...<Widget>[
            const SizedBox(height: 8),
            const _Section('Request'),
            if (record.request!.headers.isNotEmpty)
              _Field('Headers', _formatMap(record.request!.headers)),
            if (record.request!.body != null)
              _Field('Body', _formatBody(record.request!.body)),
          ],
          if (record.response != null) ...<Widget>[
            const SizedBox(height: 8),
            const _Section('Response'),
            _Field('Status', record.response!.statusCode.toString()),
            if (record.response!.requestHeaders.isNotEmpty)
              _Field('Request headers',
                  _formatMap(record.response!.requestHeaders)),
            if (record.response!.responseHeaders.isNotEmpty)
              _Field('Response headers',
                  _formatMap(record.response!.responseHeaders)),
            if (record.response!.requestBody != null)
              _Field('Request body', _formatBody(record.response!.requestBody)),
            if (record.response!.responseBody != null)
              _Field(
                  'Response body', _formatBody(record.response!.responseBody)),
          ],
          if (record.error != null) ...<Widget>[
            const SizedBox(height: 8),
            const _Section('Error'),
            _Field('Type', record.error.runtimeType.toString()),
            _Field('Message', record.error.toString()),
          ],
          if (record.extra.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            const _Section('Extra'),
            _Field('Tags', _formatMap(record.extra)),
          ],
        ],
      ),
    );
  }

  static String _formatDuration(Duration d) {
    if (d.inMilliseconds < 1000) {
      return '${d.inMilliseconds} ms';
    }
    final seconds = d.inMilliseconds / 1000.0;
    return '${seconds.toStringAsFixed(2)} s';
  }

  static String _formatMap(Map<Object?, Object?> m) {
    return m.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }

  static String _formatBody(Object? body) {
    if (body is String) return body;
    return body.toString();
  }
}

/// A simple section header.
class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// A `label: value` row.
class _Field extends StatelessWidget {
  const _Field(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

/// A coloured badge that surfaces the outcome at the top of the
/// detail screen. Not a "button" — read-only visualisation.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.outcome, required this.tint});
  final ApiTraceOutcome outcome;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final label = switch (outcome) {
      ApiTraceOutcome.success => 'Success',
      ApiTraceOutcome.error => 'Error',
      ApiTraceOutcome.cancelled => 'Cancelled',
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tint),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: tint,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
