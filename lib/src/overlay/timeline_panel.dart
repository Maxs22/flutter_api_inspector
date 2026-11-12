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
import 'package:flutter_api_inspector/src/route_scope.dart';

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
    this.onClear,
    this.onClose,
    this.onExport,
    this.scopeFilter,
    this.scopeEntry,
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

  /// Optional callback fired when the user taps the clear button
  /// in the panel header. When null, the clear button is hidden.
  final VoidCallback? onClear;

  /// Optional callback fired when the user taps the close (X)
  /// button in the panel header. When null, the close button is
  /// hidden (the overlay always passes it; standalone embeds may
  /// omit it).
  final VoidCallback? onClose;

  /// Optional callback fired when the user taps the export button.
  /// When null, the export button is hidden.
  /// The callback receives the list of records to export (filtered
  /// by scope if active, otherwise all records).
  final void Function(List<ApiTraceRecord>)? onExport;

  /// Optional filter predicate. When set, the timeline shows only
  /// records for which this predicate returns true (REQ-RS-005).
  final bool Function(ApiTraceRecord)? scopeFilter;

  /// When [scopeFilter] is set, the route-scope entry that the
  /// filter corresponds to. Used to render relative timestamps
  /// (`+500ms`) relative to this entry's [RouteScopeEntry.enteredAt]
  /// (REQ-RS-006).
  final RouteScopeEntry? scopeEntry;

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

  /// Formats a [Duration] as a relative timestamp for the route-scope
  /// filtered timeline (REQ-RS-006). Examples: `+50ms`, `+2.3s`, `+1m05s`.
  static String _formatRelativeTime(Duration delta) {
    if (delta.inMilliseconds < 1000) {
      return '+${delta.inMilliseconds}ms';
    }
    if (delta.inSeconds < 60) {
      final whole = delta.inSeconds;
      final tenths = (delta.inMilliseconds % 1000) ~/ 100;
      return '+$whole.${tenths}s';
    }
    final minutes = delta.inMinutes;
    final seconds = delta.inSeconds % 60;
    return '+${minutes}m${seconds.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _applyFilters(widget.records);

    // Controls and records share a viewport: even a short panel or a
    // wrapped filter row leaves every action and request reachable.
    return CustomScrollView(
      slivers: <Widget>[
        SliverToBoxAdapter(child: _buildHeader(context, filtered.length)),
        SliverToBoxAdapter(child: _buildFilterRow(context)),
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(context),
          )
        else
          SliverList.list(children: _buildGroupedList(filtered)),
        const SliverPadding(padding: EdgeInsets.only(bottom: 8)),
      ],
    );
  }

  /// [shownCount] is the number of records currently visible after
  /// the outcome filter and the name query are applied — the badge
  /// must reflect what the list shows, not the timeline total.
  Widget _buildHeader(BuildContext context, int shownCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: inspectorAccent(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.bolt_rounded,
              size: 16,
              color: inspectorAccent(context),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
              child: Text(
            'API calls',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: Theme.of(context).textTheme.titleMedium?.color,
            ),
          )),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: inspectorAccent(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: inspectorAccent(context).withValues(alpha: 0.18),
              ),
            ),
            child: Text(
              '$shownCount',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: inspectorBadgeText(context, inspectorAccent(context)),
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ),
          const Spacer(),
          if (widget.onExport != null)
            IconButton(
              onPressed: () => widget.onExport!(_applyFilters(widget.records)),
              icon: const Icon(Icons.file_download_rounded),
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              tooltip: 'Export as cURL',
              color: inspectorMuted(context),
            ),
          if (widget.onClear != null)
            IconButton(
              onPressed: widget.onClear,
              icon: const Icon(Icons.delete_sweep_rounded),
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              tooltip: 'Clear timeline',
              color: inspectorMuted(context),
            ),
          if (widget.onClose != null)
            IconButton(
              onPressed: widget.onClose,
              icon: const Icon(Icons.close_rounded),
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              tooltip: 'Close panel',
              color: inspectorMuted(context),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              filled: true,
              fillColor: inspectorPanelBackground(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: inspectorOutline(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: inspectorOutline(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: inspectorAccent(context), width: 1.2),
              ),
            ),
            style: const TextStyle(fontSize: 12),
            onChanged: (String v) {
              setState(() {
                _query = v;
              });
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
    final labelColor = inspectorBadgeText(context, tint);
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            icon,
            size: 14,
            color: selected ? labelColor : inspectorMuted(context),
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: Color.alphaBlend(
          tint.withValues(alpha: 0.12), inspectorPanelBackground(context)),
      backgroundColor: inspectorTintedSurface(context, alpha: 0.04),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(
        color:
            selected ? tint.withValues(alpha: 0.42) : inspectorOutline(context),
      ),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected
            ? labelColor
            : Theme.of(context).textTheme.bodyMedium?.color,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      onSelected: (bool _) {
        setState(() {
          _filter = value;
        });
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
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

  /// Applies the active filter + substring query + scope filter to a copy
  /// of [records]. The input list is never mutated.
  List<ApiTraceRecord> _applyFilters(List<ApiTraceRecord> records) {
    final query = _query.trim().toLowerCase();
    final scopeFilter = widget.scopeFilter;
    return records.where((ApiTraceRecord r) {
      if (scopeFilter != null && !scopeFilter(r)) return false;
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
  List<Widget> _buildGroupedList(List<ApiTraceRecord> records) {
    final groups = _groupRecords(records, widget.config.flowGroupGap);
    final children = <Widget>[];
    final scopeEntry = widget.scopeEntry;
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
            relativeTimestamp: scopeEntry != null
                ? _formatRelativeTime(
                    r.startedAt.difference(scopeEntry.enteredAt))
                : null,
          ));
        }
      }
    }
    return children;
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
