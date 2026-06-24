// The timeline list panel shown above the developer's UI when
// the FAB is tapped (REQ-UI-005, REQ-UI-006).
//
// `TimelinePanel` is a stateful widget that:
// - Renders a `TextField` for the name substring filter.
// - Renders three `FilterChip`s: *All* (no outcome filter),
//   *Success only*, *Error only*.
// - Renders the list of records (newest first by construction
//   — the timeline is head-insert-only; the panel does NOT
//   reverse the list).
// - Filters narrow the rendered list without mutating the
//   underlying `records` list (the panel owns its own state).
// - When the list is empty (either truly empty or filtered
//   down to nothing), renders a developer-friendly empty-state
//   message.
//
// The panel does NOT push the detail screen; the parent
// (the `ApiTraceOverlay`) supplies the `onTap` callback
// which performs the navigation.

import 'package:flutter/material.dart';

import 'package:flutter_api_inspector/src/model/api_trace_record.dart';
import 'package:flutter_api_inspector/src/outcome.dart';
import 'package:flutter_api_inspector/src/overlay/timeline_row.dart';

/// The three filter modes the panel supports.
enum _PanelFilter {
  /// No outcome filter; show every record (subject to the
  /// name substring filter).
  all,

  /// Show only records with `outcome == ApiTraceOutcome.success`.
  success,

  /// Show only records with `outcome == ApiTraceOutcome.error`.
  error,
}

/// The timeline list panel.
class TimelinePanel extends StatefulWidget {
  /// Creates a `TimelinePanel`.
  ///
  /// [records] is the unmodifiable list of records to render
  /// (typically `ApiTrace.timeline.records`). The list is NOT
  /// mutated by the panel; the panel owns its own state.
  /// [onTap] is the callback fired when a row is tapped
  /// (typically: navigate to the detail screen).
  const TimelinePanel({
    super.key,
    required this.records,
    required this.onTap,
  });

  /// The records to render. The panel treats this list as
  /// read-only.
  final List<ApiTraceRecord> records;

  /// Fired when a row is tapped.
  final void Function(ApiTraceRecord) onTap;

  @override
  State<TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends State<TimelinePanel> {
  /// The current outcome filter.
  _PanelFilter _filter = _PanelFilter.all;

  /// The current name substring query.
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilters(widget.records);

    return Material(
      elevation: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeader(),
          const Divider(height: 1),
          _buildFilterRow(),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (BuildContext context, int i) {
                      final ApiTraceRecord r = filtered[i];
                      return TimelineRow(
                        record: r,
                        onTap: () => widget.onTap(r),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Text(
        'API calls',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Filter by name',
              prefixIcon: Icon(Icons.search, size: 18),
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (String v) {
              setState(() {
                _query = v;
              });
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              _filterChip('All', _PanelFilter.all),
              _filterChip('Success only', _PanelFilter.success),
              _filterChip('Error only', _PanelFilter.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _PanelFilter value) {
    return FilterChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (bool _) {
        setState(() {
          _filter = value;
        });
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'No API calls to show.\nMake a call to see it here.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  /// Applies the active filter + substring query to a copy
  /// of [records]. The input list is never mutated.
  List<ApiTraceRecord> _applyFilters(List<ApiTraceRecord> records) {
    final query = _query.trim().toLowerCase();
    return records.where((ApiTraceRecord r) {
      if (_filter == _PanelFilter.success &&
          r.outcome != ApiTraceOutcome.success) {
        return false;
      }
      if (_filter == _PanelFilter.error && r.outcome != ApiTraceOutcome.error) {
        return false;
      }
      if (query.isNotEmpty && !r.name.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }
}
