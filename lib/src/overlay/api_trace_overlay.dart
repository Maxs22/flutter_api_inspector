// The debug-only in-app overlay (REQ-UI-001, REQ-UI-002,
// REQ-UI-005).
//
// `ApiTraceOverlay` is a `StatefulWidget` that mounts itself
// in the `WidgetsApp` overlay stack when `kDebugMode &&
// ApiTrace.enabled`. In release mode (kDebugMode == false),
// the build method short-circuits to `SizedBox.shrink()` so
// the Dart AOT compiler can tree-shake the entire overlay
// surface (per `openspec/AGENTS.md` rule 6).
//
// The overlay composes:
// - A `Stack` of [ApiTraceFab] (positioned via
//   `Align(alignment: fabAlignment(config.overlayPosition))`)
//   and the optional [TimelinePanel].
// - A `_open` `ValueNotifier<bool>` toggles the panel's
//   visibility (tapping the FAB opens / closes the panel).
// - When a row in the panel is tapped, the overlay pushes
//   `ApiTraceDetailScreen` via `MaterialPageRoute` (per
//   design.md resolved Q3).
//
// The overlay receives `records` and `onRecordTap` from the
// caller (the bootstrap wires these from `ApiTrace.timeline`).
// This keeps the overlay itself free of static-state reads
// and easy to test.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_api_inspector/src/api_trace.dart';
import 'package:flutter_api_inspector/src/config.dart';
import 'package:flutter_api_inspector/src/model/api_trace_record.dart';
import 'package:flutter_api_inspector/src/outcome.dart';
import 'package:flutter_api_inspector/src/overlay/detail_screen.dart';
import 'package:flutter_api_inspector/src/overlay/fab.dart';
import 'package:flutter_api_inspector/src/overlay/route_endpoint_panel.dart';
import 'package:flutter_api_inspector/src/overlay/route_tree_tab.dart';
import 'package:flutter_api_inspector/src/overlay/theme.dart';
import 'package:flutter_api_inspector/src/overlay/timeline_panel.dart';
import 'package:flutter_api_inspector/src/route_scope.dart';

/// The debug-only overlay that shows the FAB and the timeline
/// panel.
class ApiTraceOverlay extends StatefulWidget {
  /// Creates an `ApiTraceOverlay`.
  ///
  /// [config] is the package configuration (drives the FAB
  /// position and label shape). [records] is the list of
  /// records to render in the panel (typically
  /// `ApiTrace.timeline.records`). [onRecordTap] is the
  /// callback fired when a row is tapped; the default pushes
  /// the detail screen via `Navigator`. [navigatorKey] is the
  /// `GlobalKey<NavigatorState>` to use when the overlay is
  /// mounted outside the Navigator subtree (the common case
  /// via `ApiTraceBootstrap`). When null, falls back to
  /// `Navigator.of(context, rootNavigator: true)`.
  const ApiTraceOverlay({
    super.key,
    required this.config,
    required this.records,
    this.onRecordTap,
    this.navigatorKey,
  });

  /// The package configuration.
  final ApiTraceConfig config;

  /// The records to render in the panel.
  final List<ApiTraceRecord> records;

  /// Optional callback for row taps. If null, the overlay
  /// pushes the detail screen via `Navigator`.
  final void Function(ApiTraceRecord)? onRecordTap;

  /// Optional `GlobalKey<NavigatorState>` used to push the
  /// detail screen. When the overlay is mounted outside the
  /// Navigator subtree (e.g. as a sibling of the
  /// `MaterialApp.builder` child), `Navigator.of(context)`
  /// does not find an ancestor Navigator; this key is the
  /// escape hatch. The `ApiTraceBootstrap` always passes the
  /// shared `ApiTrace.navigatorKey`.
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<ApiTraceOverlay> createState() => _ApiTraceOverlayState();
}

class _ApiTraceOverlayState extends State<ApiTraceOverlay> {
  /// Open/closed state of the timeline panel.
  bool _open = false;

  /// Currently selected route-scope ID for timeline filtering.
  /// `null` means no filter (show all records).
  int? _selectedScopeId;

  /// The RouteScopeEntry corresponding to [_selectedScopeId], used
  /// for computing relative timestamps.
  RouteScopeEntry? _scopeEntry;

  /// Absolute position (left, top) of the FAB within the overlay
  /// Stack. `null` until the first layout — initialized from
  /// [ApiTraceConfig.overlayPosition] by [_initialFabPosition].
  /// Using absolute coordinates (instead of Transform.translate)
  /// guarantees the hit-test area always matches the visual position.
  Offset? _fabPosition;

  /// Current panel height. `null` means the panel has never
  /// been opened; the first open computes the default.
  double? _panelHeight;

  @override
  Widget build(BuildContext context) {
    // REQ-UI-001: kDebugMode guard. In release builds
    // (kDebugMode == false), this branch is `const false`,
    // so the AOT compiler eliminates the entire overlay
    // surface from the final binary (unless
    // [ApiTrace.forceEnabled] is true for tester builds).
    if (!kDebugMode && !ApiTrace.forceEnabled) {
      return const SizedBox.shrink();
    }

    // The overlay does not mount at all when the master
    // switch is off. This is the in-process equivalent of
    // the `ApiTrace.call` short-circuit.
    if (!ApiTrace.enabled) {
      return const SizedBox.shrink();
    }

    if (_open && _panelHeight == null) {
      _panelHeight = _computeDefaultPanelHeight(context);
    }

    return Stack(
      children: <Widget>[
        // Tap-outside-to-close scrim. Sits below the panel and
        // the FAB, above the developer's app. The faint tint
        // signals that the panel is dismissible.
        if (_open)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() {
                  _open = false;
                });
              },
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.05),
              ),
            ),
          ),
        if (_open)
          Positioned(
            top: MediaQuery.of(context).padding.top + kToolbarHeight,
            left: 12,
            right: 12,
            height: _panelHeight!,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: _PackageNavigator(
                    records: widget.records,
                    config: widget.config,
                    onRecordTap: widget.onRecordTap,
                    onClear: ApiTrace.timeline.clear,
                    onClose: () {
                      setState(() {
                        _open = false;
                      });
                    },
                    selectedScopeId: _selectedScopeId,
                    scopeEntry: _scopeEntry,
                    onScopeSelected: (RouteScopeEntry? entry) {
                      setState(() {
                        _selectedScopeId = entry?.scopeId;
                        _scopeEntry = entry;
                      });
                    },
                    onExport: _selectedScopeId != null
                        ? (records) => _exportFilteredRecords(records)
                        : null,
                  ),
                ),
                _PanelResizeHandle(
                  onDrag: (double delta) {
                    setState(() {
                      _panelHeight = (_panelHeight! + delta).clamp(
                        widget.config.panelMinHeight,
                        widget.config.panelMaxHeight,
                      );
                    });
                  },
                ),
              ],
            ),
          ),
        // FAB rendered via LayoutBuilder + Positioned so the
        // hit-test area always matches the visual position.
        // Transform.translate was dropped because the hit area
        // stayed at the original Align position after dragging.
        Positioned.fill(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              const double fabSlot = 56 + 32; // FAB (56) + padding (16*2)
              _fabPosition ??= _initialFabPosition(
                constraints,
                widget.config.overlayPosition,
                fabSlot,
              );
              final pos = _fabPosition!;
              return Stack(
                children: <Widget>[
                  Positioned(
                    left: pos.dx,
                    top: pos.dy,
                    child: GestureDetector(
                      onPanUpdate: widget.config.draggableFab
                          ? (DragUpdateDetails d) {
                              setState(() {
                                _fabPosition = Offset(
                                  (pos.dx + d.delta.dx)
                                      .clamp(0, constraints.maxWidth - fabSlot),
                                  (pos.dy + d.delta.dy).clamp(
                                      0, constraints.maxHeight - fabSlot),
                                );
                              });
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ApiTraceFab(
                          onPressed: () {
                            setState(() {
                              _open = !_open;
                            });
                          },
                          config: widget.config,
                          recordCount: widget.records.length,
                          errorCount: widget.records
                              .where((ApiTraceRecord r) =>
                                  r.outcome == ApiTraceOutcome.error)
                              .length,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void didUpdateWidget(ApiTraceOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.overlayPosition != widget.config.overlayPosition) {
      _fabPosition = null;
    }
  }

  static Offset _initialFabPosition(
    BoxConstraints c,
    ApiTraceOverlayPosition pos,
    double slot,
  ) {
    final maxX = (c.maxWidth - slot).clamp(0.0, double.infinity);
    final maxY = (c.maxHeight - slot).clamp(0.0, double.infinity);
    return switch (pos) {
      ApiTraceOverlayPosition.bottomRight => Offset(maxX, maxY),
      ApiTraceOverlayPosition.bottomLeft => Offset(0, maxY),
      ApiTraceOverlayPosition.topRight => Offset(maxX, 0),
      ApiTraceOverlayPosition.topLeft => Offset.zero,
    };
  }

  double _computeDefaultPanelHeight(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    final available = screenHeight - topInset;
    return (available * 0.6).clamp(
      widget.config.panelMinHeight,
      widget.config.panelMaxHeight,
    );
  }

  Future<void> _exportFilteredRecords(List<ApiTraceRecord> records) async {
    final scopeEntry = _scopeEntry;
    final scopeId = _selectedScopeId;
    final routeName = scopeEntry?.routeName ?? 'Unknown';

    final buffer = StringBuffer();
    buffer.writeln('// Route: $routeName (scopeId: $scopeId)');
    buffer.writeln();

    for (final record in records) {
      final curl = _recordToCurl(record);
      buffer.writeln(curl);
      buffer.writeln();
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
  }

  String _recordToCurl(ApiTraceRecord record) {
    final method = record.method;
    final url = record.url.toString();

    final buffer = StringBuffer();
    buffer.write('curl -X $method "$url"');

    if (record.request?.headers.isNotEmpty ?? false) {
      for (final entry in record.request!.headers.entries) {
        buffer.write(' -H "${entry.key}: ${entry.value}"');
      }
    }

    if (record.request?.body != null &&
        record.request!.body.toString().isNotEmpty) {
      buffer.write(
          ' -d \'${record.request!.body.toString().replaceAll('\'', '\\\'')}\'');
    }

    return buffer.toString();
  }
}

/// Tabbed content container that shows [TimelinePanel] or
/// [RouteTreeTab] and pushes the detail screen.
class _PackageNavigator extends StatefulWidget {
  const _PackageNavigator({
    required this.records,
    required this.config,
    required this.onRecordTap,
    required this.onClear,
    required this.onClose,
    this.selectedScopeId,
    this.scopeEntry,
    required this.onScopeSelected,
    this.onExport,
  });

  final List<ApiTraceRecord> records;
  final ApiTraceConfig config;
  final void Function(ApiTraceRecord)? onRecordTap;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final int? selectedScopeId;
  final RouteScopeEntry? scopeEntry;
  final void Function(RouteScopeEntry?) onScopeSelected;
  final void Function(List<ApiTraceRecord>)? onExport;

  @override
  State<_PackageNavigator> createState() => _PackageNavigatorState();
}

class _PackageNavigatorState extends State<_PackageNavigator> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  /// Active tab index (0 = Timeline, 1 = Routes).
  int _activeTab = 0;

  void _pushDetail(ApiTraceRecord record) {
    final userCallback = widget.onRecordTap;
    if (userCallback != null) {
      userCallback(record);
      return;
    }
    _navKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => ApiTraceDetailScreen(record: record),
      ),
    );
  }

  void _handleExport() {
    final onExport = widget.onExport;
    if (onExport == null) return;
    final scopeId = widget.selectedScopeId;
    final filtered = scopeId != null
        ? widget.records.where((r) => r.routeScopeId == scopeId).toList()
        : widget.records;
    onExport(filtered);
  }

  @override
  Widget build(BuildContext context) {
    // Scope a fresh HeroController so the nested Navigator does not
    // share the one from the host app's MaterialApp — sharing causes
    // a runtime assert ("A HeroController can not be shared by
    // multiple Navigators").
    return HeroControllerScope.none(
      child: Navigator(
        key: _navKey,
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => ListenableBuilder(
            listenable: ApiTrace.timeline.latest,
            builder: (_, __) => _buildTabbedContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildTabbedContent() {
    final theme = Theme.of(context);
    final tabColor = theme.textTheme.bodySmall?.color ?? Colors.grey;
    final activeColor = theme.colorScheme.primary;

    return Column(
      children: <Widget>[
        Container(
          color: inspectorGroupHeaderBackground(context),
          child: Row(
            children: <Widget>[
              _buildTabButton(
                label: 'Timeline',
                icon: Icons.list_rounded,
                selected: _activeTab == 0,
                activeColor: activeColor,
                inactiveColor: tabColor,
                onTap: () => setState(() => _activeTab = 0),
              ),
              _buildTabButton(
                label: 'Routes',
                icon: Icons.account_tree_rounded,
                selected: _activeTab == 1,
                activeColor: activeColor,
                inactiveColor: tabColor,
                onTap: () => setState(() => _activeTab = 1),
              ),
              const Spacer(),
              if (widget.selectedScopeId != null)
                IconButton(
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                  tooltip: 'Clear route filter',
                  onPressed: () => widget.onScopeSelected(null),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    foregroundColor: activeColor,
                  ),
                ),
              if (_activeTab == 0 && widget.onExport != null)
                IconButton(
                  icon: const Icon(Icons.file_download_rounded, size: 18),
                  tooltip: 'Export as cURL',
                  onPressed: _handleExport,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    foregroundColor: activeColor,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Material(
            color: inspectorPanelBackground(context),
            child: _activeTab == 0
                ? TimelinePanel(
                    key: const ValueKey('inspectorPanel'),
                    records: widget.records,
                    config: widget.config,
                    onTap: _pushDetail,
                    onClear: widget.onClear,
                    onClose: widget.onClose,
                    onExport: widget.onExport,
                    scopeFilter: widget.selectedScopeId != null
                        ? (ApiTraceRecord r) =>
                            r.routeScopeId == widget.selectedScopeId
                        : null,
                    scopeEntry: widget.scopeEntry,
                  )
                : RouteTreeTab(
                    records: widget.records,
                    onScopeSelected: widget.onScopeSelected,
                    selectedScopeId: widget.selectedScopeId,
                    onShowEndpoints:
                        (RouteScopeEntry entry, List<ApiTraceRecord> records) {
                      _navKey.currentState?.push(
                        MaterialPageRoute<void>(
                          builder: (_) => RouteEndpointPanel(
                            records: records,
                            routeName: entry.routeName,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool selected,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTap,
  }) {
    final color = selected ? activeColor : inactiveColor;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? activeColor : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Drag handle at the bottom of the timeline panel. The user
/// drags vertically to resize the panel between
/// [ApiTraceConfig.panelMinHeight] and [ApiTraceConfig.panelMaxHeight].
class _PanelResizeHandle extends StatelessWidget {
  const _PanelResizeHandle({required this.onDrag});

  /// Called with the vertical drag delta. A positive delta
  /// means the finger moved down (panel gets shorter); a
  /// negative delta means the finger moved up (panel gets
  /// taller).
  final void Function(double delta) onDrag;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (DragUpdateDetails d) {
        onDrag(d.delta.dy);
      },
      child: Container(
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: inspectorPanelBackground(context),
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
        ),
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: inspectorMuted(context),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
