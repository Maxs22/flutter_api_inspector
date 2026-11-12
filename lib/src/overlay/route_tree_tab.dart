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

/// Callback fired when the user taps the list-icon to open the endpoint
/// detail panel for a route scope.
/// [entry] is the selected [RouteScopeEntry].
/// [records] is the pre-filtered list of [ApiTraceRecord]s whose
/// [routeScopeId] matches [entry.scopeId].
typedef EndpointPanelCallback = void Function(
    RouteScopeEntry entry, List<ApiTraceRecord> records);

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
    this.onShowEndpoints,
  });

  /// All records from the timeline.
  final List<ApiTraceRecord> records;

  /// Called when a route is tapped (null = clear filter).
  final ScopeSelectionCallback onScopeSelected;

  /// Currently selected scope ID (null = no filter).
  final int? selectedScopeId;

  /// Called when the user taps the list-icon to open the endpoint
  /// detail panel for a route.
  final EndpointPanelCallback? onShowEndpoints;

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
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
      child: Row(
        children: <Widget>[
          Text(
            'Routes',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const Spacer(),
          if (hasFilter)
            TextButton.icon(
              onPressed: () => widget.onScopeSelected(null),
              icon: const Icon(Icons.clear_all_rounded, size: 18),
              label: const Text('Clear', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(44, 44),
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
    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final isLast = i == entries.length - 1;
      final isSelected = widget.selectedScopeId == entry.scopeId;
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
        isLastChild: isLast,
        totalCalls: stats.total,
        errorCount: stats.errors,
        onTap: () => widget.onScopeSelected(
          isSelected ? null : entry,
        ),
        onShowEndpoints: widget.onShowEndpoints != null
            ? () {
                final filtered = widget.records
                    .where((r) => r.routeScopeId == entry.scopeId)
                    .toList();
                widget.onShowEndpoints!(entry, filtered);
              }
            : null,
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
    required this.isLastChild,
    required this.totalCalls,
    required this.errorCount,
    required this.onTap,
    this.onShowEndpoints,
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
  final bool isLastChild;
  final int totalCalls;
  final int errorCount;
  final VoidCallback onTap;
  final VoidCallback? onShowEndpoints;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Text/icon emphasis reacts to either the tap-to-filter
    // selection OR the live current route; the stronger background
    // tint stays reserved for the tap-to-filter selection only.
    final highlighted = isSelected || isActive;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.0 + depth * 8.0, 6, 16, 6),
      child: Material(
        color: isSelected
            ? inspectorTintedSurface(context, alpha: 0.12)
            : inspectorTintedSurface(
                context,
                alpha: highlighted ? 0.06 : 0.0,
              ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(inspectorRadius),
          side: BorderSide(
            color: isSelected
                ? inspectorAccent(context)
                : inspectorOutline(context),
            width: isSelected ? 1.5 : 0.7,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
            child: Row(
              children: <Widget>[
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
                Icon(
                  highlighted
                      ? Icons.screen_search_desktop_rounded
                      : Icons.screen_rotation_alt_rounded,
                  size: 16,
                  color: highlighted
                      ? inspectorAccent(context)
                      : inspectorMuted(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.routeName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          highlighted ? FontWeight.w700 : FontWeight.w500,
                      color: highlighted
                          ? inspectorBadgeText(
                              context, inspectorAccent(context))
                          : theme.textTheme.bodyLarge?.color,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 6),
                if (totalCalls > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: inspectorMuted(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: inspectorMuted(context).withValues(alpha: 0.16),
                      ),
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
                if (onShowEndpoints != null)
                  Tooltip(
                    message: 'View endpoints',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onShowEndpoints,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.list_alt_rounded,
                          size: 16,
                          color: inspectorMuted(context),
                        ),
                      ),
                    ),
                  ),
                if (errorCount > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: inspectorError(context).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: inspectorError(context).withValues(alpha: 0.18),
                      ),
                    ),
                    child: Text(
                      '!$errorCount',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: inspectorBadgeText(
                            context, inspectorError(context),
                            alpha: 0.15),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
