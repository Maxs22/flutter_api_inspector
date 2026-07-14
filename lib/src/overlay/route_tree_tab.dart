// Route Tree tab for the inspector overlay (REQ-RS-005, REQ-RS-006).
//
// Shows a hierarchical tree of visited routes. Tapping a route
// filters the main timeline to show only calls made while that
// screen was active, with relative timestamps.

import 'package:flutter/material.dart';

import 'package:flutter_api_inspector/src/model/api_trace_record.dart';
import 'package:flutter_api_inspector/src/outcome.dart';
import 'package:flutter_api_inspector/src/overlay/theme.dart';
import 'package:flutter_api_inspector/src/route_scope.dart';

/// Callback fired when the user selects a route scope to filter by.
/// [RouteScopeEntry] is the selected scope, or `null` to clear the filter.
typedef ScopeSelectionCallback = void Function(RouteScopeEntry? entry);

/// Tab widget that shows the hierarchical route tree.
///
/// Builds the tree from [RouteScope.entries], computes per-scope
/// call statistics from [records], and fires [onScopeSelected] when
/// the user taps a route row.
class RouteTreeTab extends StatefulWidget {
  /// Creates a `RouteTreeTab`.
  ///
  /// [records] is the full timeline record list (used to compute
  /// per-scope call counts and error counts).
  /// [onScopeSelected] is called when the user taps a route row
  /// (passes the selected [RouteScopeEntry], or `null` to clear).
  /// [selectedScopeId] is the currently active scope filter, or
  /// `null` if no filter is active.
  const RouteTreeTab({
    super.key,
    required this.records,
    required this.onScopeSelected,
    this.selectedScopeId,
  });

  /// All records from the timeline.
  final List<ApiTraceRecord> records;

  /// Called when a route is tapped (null = clear filter).
  final ScopeSelectionCallback onScopeSelected;

  /// Currently selected scope ID (null = no filter).
  final int? selectedScopeId;

  @override
  State<RouteTreeTab> createState() => _RouteTreeTabState();
}

class _RouteTreeTabState extends State<RouteTreeTab> {
  /// Set of scope IDs that are expanded in the tree.
  final Set<int> _expanded = <int>{};

  /// Pre-computed call count per scope ID.
  late final Map<int?, _ScopeStats> _stats;

  @override
  void initState() {
    super.initState();
    _stats = _computeStats(widget.records);
    // Auto-expand all by default.
    for (final e in RouteScope.entries) {
      _expanded.add(e.scopeId);
    }
  }

  @override
  void didUpdateWidget(RouteTreeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.records != widget.records) {
      _stats = _computeStats(widget.records);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = RouteScope.entries;
    if (entries.isEmpty) {
      return Center(
        child: Text(
          'No routes tracked yet.\nNavigate through the app to populate this list.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: inspectorMuted(context),
          ),
        ),
      );
    }

    // Build a tree from the flat list. Root entries have no parent.
    final roots = <RouteScopeEntry>[];
    final childrenOf = <int, List<RouteScopeEntry>>{};
    for (final e in entries) {
      if (e.parentScopeId == null) {
        roots.add(e);
      } else {
        childrenOf
            .putIfAbsent(e.parentScopeId!, () => <RouteScopeEntry>[])
            .add(e);
      }
    }

    return Column(
      children: <Widget>[
        // Header
        _buildHeader(context),
        // Tree list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 8),
            children: _buildTreeNodes(context, roots, childrenOf, 0),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final hasFilter = widget.selectedScopeId != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: <Widget>[
          Text(
            'Routes',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const Spacer(),
          if (hasFilter)
            TextButton.icon(
              onPressed: () => widget.onScopeSelected(null),
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Clear', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildTreeNodes(
    BuildContext context,
    List<RouteScopeEntry> entries,
    Map<int, List<RouteScopeEntry>> childrenOf,
    int depth,
  ) {
    final widgets = <Widget>[];
    final currentScopeId = RouteScope.current?.scopeId;
    for (final entry in entries) {
      final isSelected = widget.selectedScopeId == entry.scopeId;
      // The live route the app is currently on (REQ-RS-005 "Active
      // route is highlighted"), independent of any tap-to-filter
      // selection above.
      final isActive = currentScopeId == entry.scopeId;
      final children = childrenOf[entry.scopeId] ?? <RouteScopeEntry>[];
      final hasChildren = children.isNotEmpty;
      final isExpanded = _expanded.contains(entry.scopeId);
      final stats =
          _stats[entry.scopeId] ?? const _ScopeStats(total: 0, errors: 0);

      widgets.add(_RouteTreeRow(
        entry: entry,
        depth: depth,
        isSelected: isSelected,
        isActive: isActive,
        isExpanded: isExpanded,
        hasChildren: hasChildren,
        totalCalls: stats.total,
        errorCount: stats.errors,
        onTap: () => widget.onScopeSelected(
          isSelected ? null : entry,
        ),
        onToggle: hasChildren
            ? () {
                setState(() {
                  if (isExpanded) {
                    _expanded.remove(entry.scopeId);
                  } else {
                    _expanded.add(entry.scopeId);
                  }
                });
              }
            : null,
      ));

      if (isExpanded && hasChildren) {
        widgets.addAll(
          _buildTreeNodes(context, children, childrenOf, depth + 1),
        );
      }
    }
    return widgets;
  }

  /// Pre-compute call counts per scope ID from the records list.
  Map<int?, _ScopeStats> _computeStats(List<ApiTraceRecord> records) {
    final stats = <int?, _ScopeStats>{};
    for (final r in records) {
      final scopeId = r.routeScopeId;
      final s = stats.putIfAbsent(
          scopeId, () => const _ScopeStats(total: 0, errors: 0));
      stats[scopeId] = _ScopeStats(
        total: s.total + 1,
        errors: s.errors + (r.outcome == ApiTraceOutcome.error ? 1 : 0),
      );
    }
    return stats;
  }
}

/// Statistics for a single scope.
class _ScopeStats {
  const _ScopeStats({required this.total, required this.errors});
  final int total;
  final int errors;
}

/// A single row in the route tree.
class _RouteTreeRow extends StatelessWidget {
  const _RouteTreeRow({
    required this.entry,
    required this.depth,
    required this.isSelected,
    required this.isActive,
    required this.isExpanded,
    required this.hasChildren,
    required this.totalCalls,
    required this.errorCount,
    required this.onTap,
    this.onToggle,
  });

  final RouteScopeEntry entry;
  final int depth;
  final bool isSelected;

  /// Whether this entry is the app's LIVE current route
  /// (`RouteScope.current`), independent of [isSelected] (the
  /// tap-to-filter state). Drives the "Active route is highlighted"
  /// scenario (REQ-RS-005) even when no filter is active.
  final bool isActive;
  final bool isExpanded;
  final bool hasChildren;
  final int totalCalls;
  final int errorCount;
  final VoidCallback onTap;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Text/icon emphasis reacts to either the tap-to-filter
    // selection OR the live current route; the stronger background
    // tint stays reserved for the tap-to-filter selection only.
    final highlighted = isSelected || isActive;

    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16.0 + depth * 20.0,
            right: 16,
            top: 8,
            bottom: 8,
          ),
          child: Row(
            children: <Widget>[
              // Expand/collapse chevron for parents
              if (hasChildren)
                GestureDetector(
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      isExpanded
                          ? Icons.expand_more_rounded
                          : Icons.chevron_right_rounded,
                      size: 18,
                      color: inspectorMuted(context),
                    ),
                  ),
                )
              else
                const SizedBox(width: 22),
              const SizedBox(width: 4),
              // Route icon
              Icon(
                highlighted
                    ? Icons.screen_search_desktop_rounded
                    : Icons.screen_rotation_alt_rounded,
                size: 16,
                color: highlighted
                    ? theme.colorScheme.primary
                    : inspectorMuted(context),
              ),
              const SizedBox(width: 8),
              // Route name
              Expanded(
                child: Text(
                  entry.routeName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
                    color: highlighted
                        ? theme.colorScheme.primary
                        : theme.textTheme.bodyLarge?.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 6),
              // Call count badge
              if (totalCalls > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: inspectorMuted(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$totalCalls',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: inspectorMuted(context),
                    ),
                  ),
                ),
              // Error badge
              if (errorCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: inspectorError(context).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '!$errorCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: inspectorError(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
