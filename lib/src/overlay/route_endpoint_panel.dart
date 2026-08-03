// Endpoint detail panel for a single route scope (REQ-REP-002,
// REQ-REP-004, REQ-REP-006).
//
// Shows the list of individual endpoint calls tagged with a specific
// route's scopeId. Pushed via MaterialPageRoute from the list-icon
// button in _RouteTreeRow.
//
// Guarded by kDebugMode: the build method returns SizedBox.shrink()
// in release mode so the widget tree is tree-shaken from release
// binaries (same pattern as ApiTraceOverlay).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_api_inspector/src/model/api_trace_record.dart';
import 'package:flutter_api_inspector/src/overlay/colors.dart';
import 'package:flutter_api_inspector/src/overlay/detail_screen.dart';
import 'package:flutter_api_inspector/src/overlay/theme.dart';

/// Panel that shows all endpoint calls for a single route scope.
///
/// [records] is the pre-filtered list of [ApiTraceRecord]s whose
/// [routeScopeId] matches the selected route's scopeId.
/// [routeName] is the display name of the selected route, shown as
/// the panel title.
class RouteEndpointPanel extends StatefulWidget {
  /// Creates a `RouteEndpointPanel`.
  const RouteEndpointPanel({
    super.key,
    required this.records,
    required this.routeName,
  });

  /// Pre-filtered records for this route scope.
  final List<ApiTraceRecord> records;

  /// Display name of the route, shown in the app bar title.
  final String routeName;

  @override
  State<RouteEndpointPanel> createState() => _RouteEndpointPanelState();
}

class _RouteEndpointPanelState extends State<RouteEndpointPanel> {
  late final List<ApiTraceRecord> _records;

  @override
  void initState() {
    super.initState();
    _records = List<ApiTraceRecord>.unmodifiable(widget.records);
  }

  @override
  Widget build(BuildContext context) {
    // Guard: in release mode (kDebugMode == false) the Dart AOT
    // compiler can tree-shake the entire panel surface.
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.routeName} Endpoints'),
      ),
      body: _records.isEmpty ? _buildEmptyState(context) : _buildList(context),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.inbox_rounded, size: 48, color: inspectorMuted(context)),
          const SizedBox(height: 16),
          Text(
            'No endpoints recorded for this route.',
            style: TextStyle(
              fontSize: 14,
              color: inspectorMuted(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Route: ${widget.routeName}',
            style: TextStyle(
              fontSize: 12,
              color: inspectorMuted(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return ListView.builder(
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final record = _records[index];
        return ListTile(
          title: Text(record.name, style: const TextStyle(fontSize: 13)),
          subtitle: Text(
            '${record.method} \u00b7 ${record.statusCode ?? '???'}',
            style: TextStyle(
              fontSize: 12,
              color: outcomeColor(record.outcome),
            ),
          ),
          trailing: Text(
            _formatDuration(record.duration),
            style: const TextStyle(fontSize: 12),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => ApiTraceDetailScreen(record: record),
              ),
            );
          },
        );
      },
    );
  }

  /// Format a Duration into a human-readable string like `230ms` or
  /// `1.4s`.
  String _formatDuration(Duration d) {
    if (d.inMilliseconds < 1000) {
      return '${d.inMilliseconds}ms';
    }
    if (d.inSeconds < 10) {
      final ms = d.inMilliseconds % 1000;
      return '${d.inSeconds}.${(ms ~/ 100)}s';
    }
    return '${d.inSeconds}s';
  }
}
