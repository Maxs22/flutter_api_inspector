// The read-only detail screen shown when a row in the timeline
// is tapped (REQ-UI-007).
//
// `ApiTraceDetailScreen` is a `StatelessWidget` pushed onto
// the package-owned `Navigator` (see `api_trace_overlay.dart`)
// so the back button returns to the panel without disturbing
// the host app's navigation stack.
//
// The screen renders every captured field in a scrollable
// `ListView`: name, method, url, query parameters,
// statusCode, duration, timestamps, captured details, request
// (headers + body), response (status + headers + body),
// error, extra. There are NO action buttons — no "Copy as
// cURL", no "Re-run", no "Export" (REQ-UI-007 out-of-scope
// list, locked at proposal time).
//
// The screen respects `Theme.of(context)` (per design.md
// resolved Q5). Outcome coloring is rendered as a status
// badge so the developer can see at a glance whether the
// call succeeded.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_api_inspector/src/model/api_trace_record.dart';
import 'package:flutter_api_inspector/src/outcome.dart';
import 'package:flutter_api_inspector/src/overlay/colors.dart';
import 'package:flutter_api_inspector/src/overlay/theme.dart';

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
      backgroundColor: inspectorPanelBackground(context),
      appBar: AppBar(
        title: Text(record.name, overflow: TextOverflow.ellipsis),
        backgroundColor: inspectorPanelBackground(context),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          // Status badge at the top, prominent.
          _StatusBadge(outcome: record.outcome, tint: tint),
          const SizedBox(height: 16),

          // Overview section.
          _Section(context, 'Overview'),
          _Field(context, 'Name', record.name),
          _Field(context, 'Method', record.method),
          _Field(context, 'Status', record.statusCode?.toString() ?? '—'),
          _Field(context, 'Duration', _formatDuration(record.duration)),
          _Field(
            context,
            'Started',
            _formatTimestamp(record.startedAt),
          ),
          _Field(
            context,
            'Completed',
            _formatTimestamp(record.completedAt),
          ),
          _Field(
            context,
            'Captured',
            record.capturedDetails.map((d) => d.name).toList().join(', '),
          ),

          // URL with query parameters as a separate list.
          _Section(context, 'URL'),
          _CopyableText(context, record.url.toString()),
          if (record.url.queryParameters.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            _ParametersTable(
              parameters: record.url.queryParameters,
            ),
          ],

          // Request section.
          if (record.request != null) ...<Widget>[
            _Section(context, 'Request'),
            if (record.request!.headers.isNotEmpty)
              _HeadersTable(headers: record.request!.headers),
            if (record.request!.body != null) ...<Widget>[
              const SizedBox(height: 6),
              _CodeBlock(text: _formatBody(record.request!.body)),
            ],
          ],

          // Response section.
          if (record.response != null) ...<Widget>[
            _Section(context, 'Response'),
            _Field(
              context,
              'Status',
              record.response!.statusCode.toString(),
            ),
            if (record.response!.responseHeaders.isNotEmpty)
              _HeadersTable(headers: record.response!.responseHeaders),
            if (record.response!.requestHeaders.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(
                  'Request headers',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: inspectorMuted(context),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _HeadersTable(headers: record.response!.requestHeaders),
            ],
            if (record.response!.responseBody != null) ...<Widget>[
              const SizedBox(height: 6),
              _CodeBlock(text: _formatBody(record.response!.responseBody)),
            ],
          ],

          // Error section.
          if (record.error != null) ...<Widget>[
            _Section(context, 'Error'),
            _Field(context, 'Type', record.error.runtimeType.toString()),
            _CodeBlock(text: record.error.toString()),
          ],

          // Extra tags.
          if (record.extra.isNotEmpty) ...<Widget>[
            _Section(context, 'Extra'),
            _CodeBlock(text: _formatMap(record.extra)),
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

  static String _formatTimestamp(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}.'
      '${t.millisecond.toString().padLeft(3, '0')}';

  static String _formatMap(Map<Object?, Object?> m) {
    return m.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }

  static String _formatBody(Object? body) {
    if (body is String) return body;
    return body.toString();
  }
}

// ---------------------------------------------------------------------------
// Internal widgets: Section, Field, CopyableText, ParametersTable,
// HeadersTable, CodeBlock.
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section(this.context, this.title);
  final BuildContext context;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
          color: inspectorAccent(context),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.context, this.label, this.value);
  final BuildContext context;
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
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: inspectorMuted(context),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontFamily: 'monospace',
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyableText extends StatelessWidget {
  const _CopyableText(this.context, this.text);
  final BuildContext context;
  final String text;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copied to clipboard'),
              duration: Duration(seconds: 1),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: SelectableText(
                text,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontFamily: 'monospace',
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.content_copy_rounded,
              size: 12,
              color: inspectorMuted(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParametersTable extends StatelessWidget {
  const _ParametersTable({required this.parameters});
  final Map<String, String> parameters;

  @override
  Widget build(BuildContext context) {
    final entries = parameters.entries.toList(growable: false);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF111827)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < entries.length; i++) ...<Widget>[
            if (i > 0)
              Divider(height: 1, color: Theme.of(context).dividerColor),
            _ParamRow(
              key: ValueKey(entries[i].key),
              name: entries[i].key,
              value: entries[i].value,
              isLast: i == entries.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _ParamRow extends StatelessWidget {
  const _ParamRow({
    super.key,
    required this.name,
    required this.value,
    required this.isLast,
  });

  final String name;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: inspectorAccent(context),
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '=',
            style: TextStyle(
              fontSize: 11,
              color: inspectorMuted(context),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontFamily: 'monospace',
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadersTable extends StatelessWidget {
  const _HeadersTable({required this.headers});
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF111827)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < headers.length; i++) ...<Widget>[
            if (i > 0)
              Divider(height: 1, color: Theme.of(context).dividerColor),
            _HeaderRow(
              key: ValueKey(headers.keys.elementAt(i)),
              name: headers.keys.elementAt(i),
              value: headers.values.elementAt(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    super.key,
    required this.name,
    required this.value,
  });

  final String name;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: inspectorAccent(context),
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontFamily: 'monospace',
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF111827)
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: SelectableText(
        text,
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).textTheme.bodyLarge?.color,
          fontFamily: 'monospace',
          height: 1.4,
        ),
      ),
    );
  }
}

/// A prominent badge at the top of the detail screen
/// showing the call's outcome (success / error / cancelled).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.outcome, required this.tint});

  final ApiTraceOutcome outcome;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final label = switch (outcome) {
      ApiTraceOutcome.success => 'SUCCESS',
      ApiTraceOutcome.error => 'ERROR',
      ApiTraceOutcome.cancelled => 'CANCELLED',
    };
    final icon = switch (outcome) {
      ApiTraceOutcome.success => Icons.check_circle_rounded,
      ApiTraceOutcome.error => Icons.error_rounded,
      ApiTraceOutcome.cancelled => Icons.cancel_rounded,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tint.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: tint, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: tint,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
