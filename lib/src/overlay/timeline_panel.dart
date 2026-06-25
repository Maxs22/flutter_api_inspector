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

import 'package:flutter_api_inspector/src/config.dart';
import 'package:flutter_api_inspector/src/model/api_trace_record.dart';
import 'package:flutter_api_inspector/src/outcome.dart';
import 'package:flutter_api_inspector/src/overlay/theme.dart';
import 'package:flutter_api_inspector/src/overlay/timeline_group_header.dart';
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
  /// (typically: navigate to the detail screen). [config] is
  /// the package config; the panel reads [ApiTraceConfig.flowGroupGap]
  /// to decide how to group consecutive records.
  const TimelinePanel({
    super.key,
    required this.records,
    required this.onTap,
    this.config = const ApiTraceConfig(),
  });

  /// The records to render. The panel treats this list as
  /// read-only.
  final List<ApiTraceRecord> records;

  /// Fired when a row is tapped.
  final void Function(ApiTraceRecord) onTap;

  /// The package config (used for the flow-group gap). Optional
  /// for backwards compatibility; the default value gives the
  /// same 2-second grouping as the package-wide default.
  final ApiTraceConfig config;

  @override
  State<TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends State<TimelinePanel> {
  /// The current outcome filter.
  _PanelFilter _filter = _PanelFilter.all;

  /// The current name substring query.
  String _query = '';

  /// Set of group indexes that the user has collapsed. The
  /// panel owns this state; the group headers are expanded by
  /// default.
  final Set<int> _collapsed = <int>{};

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilters(widget.records);

    // The panel is wrapped in a `LayoutBuilder` so we can
    // compute the available height and pass it explicitly to
    // the inner `Material`. Without this, the `Material`
    // collapses to its child's intrinsic size, the
    // `Expanded(ListView)` inside the `Column` gets zero
    // height, and the panel ends up showing only the header
    // and filter row with no scroll area for the records.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Material(
          color: inspectorPanelBackground(context),
          elevation: 12,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _buildHeader(context),
                _buildFilterRow(context),
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState(context)
                      : _buildGroupedList(filtered),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.bolt_rounded,
            size: 18,
            color: inspectorAccent(context),
          ),
          const SizedBox(width: 8),
          Text(
            'API calls',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.titleMedium?.color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: inspectorAccent(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${widget.records.length}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: inspectorAccent(context),
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Filter by name',
              hintStyle: TextStyle(
                fontSize: 12,
                color: inspectorMuted(context),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 16,
                color: inspectorMuted(context),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              filled: true,
              fillColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF111827)
                  : const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            style: const TextStyle(fontSize: 12),
            onChanged: (String v) {
              setState(() {
                _query = v;
              });
            },
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: <Widget>[
              _filterChip(
                context,
                label: 'All',
                value: _PanelFilter.all,
                icon: Icons.all_inclusive_rounded,
              ),
              _filterChip(
                context,
                label: 'Success',
                value: _PanelFilter.success,
                icon: Icons.check_circle_rounded,
                color: inspectorSuccess(context),
              ),
              _filterChip(
                context,
                label: 'Errors',
                value: _PanelFilter.error,
                icon: Icons.error_rounded,
                color: inspectorError(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
    BuildContext context, {
    required String label,
    required _PanelFilter value,
    required IconData icon,
    Color? color,
  }) {
    final selected = _filter == value;
    final tint = color ?? inspectorAccent(context);
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 14,
            color: selected
                ? tint
                : Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF6B7280),
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: tint.withValues(alpha: 0.12),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1F2937)
          : const Color(0xFFF3F4F6),
      side: BorderSide(
        color: selected ? tint.withValues(alpha: 0.4) : Colors.transparent,
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? tint : Theme.of(context).textTheme.bodyMedium?.color,
      ),
      onSelected: (bool _) {
        setState(() {
          _filter = value;
        });
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.inbox_rounded,
              size: 40,
              color: inspectorMuted(context),
            ),
            const SizedBox(height: 12),
            Text(
              'No API calls yet',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Make a call to see it here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: inspectorMuted(context),
              ),
            ),
          ],
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

  /// Builds the grouped list view. Records are grouped by
  /// [ApiTraceConfig.flowGroupGap] (a gap longer than the
  /// threshold starts a new group). Each group renders a
  /// [TimelineGroupHeader] followed by the rows. Rows are
  /// hidden when the user collapses a group.
  Widget _buildGroupedList(List<ApiTraceRecord> records) {
    final groups = _groupRecords(records, widget.config.flowGroupGap);
    final children = <Widget>[];
    for (var i = 0; i < groups.length; i++) {
      final g = groups[i];
      final expanded = !_collapsed.contains(i);
      children.add(TimelineGroupHeader(
        group: g,
        expanded: expanded,
        onToggle: () {
          setState(() {
            if (expanded) {
              _collapsed.add(i);
            } else {
              _collapsed.remove(i);
            }
          });
        },
      ));
      if (expanded) {
        for (final r in g.records) {
          children.add(TimelineRow(
            record: r,
            onTap: () => widget.onTap(r),
          ));
        }
      }
    }
    return ListView(children: children);
  }

  /// Splits [records] into a list of [TimelineGroup]s. Two
  /// consecutive records belong to the same group when the
  /// gap between the previous record's completion and the
  /// current record's start is shorter than [gap]. When
  /// [gap] is zero, every record is its own group (no
  /// grouping).
  static List<TimelineGroup> _groupRecords(
      List<ApiTraceRecord> records, Duration gap) {
    if (gap <= Duration.zero) {
      return records.map((r) => TimelineGroup(<ApiTraceRecord>[r])).toList();
    }
    final groups = <TimelineGroup>[];
    final current = <ApiTraceRecord>[];
    for (final r in records) {
      if (current.isEmpty) {
        current.add(r);
        continue;
      }
      final prev = current.last;
      final idle = r.startedAt.difference(prev.completedAt);
      if (idle > gap) {
        groups.add(TimelineGroup(List<ApiTraceRecord>.from(current)));
        current
          ..clear()
          ..add(r);
      } else {
        current.add(r);
      }
    }
    if (current.isNotEmpty) {
      groups.add(TimelineGroup(List<ApiTraceRecord>.from(current)));
    }
    return groups;
  }
}
