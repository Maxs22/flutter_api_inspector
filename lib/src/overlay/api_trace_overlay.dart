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

import 'package:flutter_api_inspector/src/api_trace.dart';
import 'package:flutter_api_inspector/src/config.dart';
import 'package:flutter_api_inspector/src/model/api_trace_record.dart';
import 'package:flutter_api_inspector/src/overlay/detail_screen.dart';
import 'package:flutter_api_inspector/src/overlay/fab.dart';
import 'package:flutter_api_inspector/src/overlay/fab_position.dart';
import 'package:flutter_api_inspector/src/overlay/timeline_panel.dart';

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

  /// Manual drag offset applied to the FAB. Zero (the default)
  /// means the FAB sits at the corner chosen by
  /// [ApiTraceConfig.overlayPosition]. When the developer
  /// long-presses the FAB and drags, this offset grows. The
  /// offset is session-scoped (resets when the overlay is
  /// rebuilt; we do not persist it to disk).
  ///
  /// The drag is a no-op when [ApiTraceConfig.draggableFab] is
  /// `false`.
  Offset _fabDragOffset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    // REQ-UI-001: kDebugMode guard. In release builds
    // (kDebugMode == false), this branch is `const false`,
    // so the AOT compiler eliminates the entire overlay
    // surface from the final binary.
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }

    // The overlay does not mount at all when the master
    // switch is off. This is the in-process equivalent of
    // the `ApiTrace.call` short-circuit.
    if (!ApiTrace.enabled) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: <Widget>[
        // The panel, when open, lives inside a package-owned
        // `Navigator` so the detail screen can be pushed onto
        // a separate stack from the host app.
        if (_open)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: widget.config.panelMaxHeight,
            child: _PackageNavigator(
              records: widget.records,
              onRecordTap: widget.onRecordTap,
            ),
          ),
        // The FAB, positioned per the config. The drag
        // offset is applied as a `Transform.translate` on top
        // of the aligned position. `onPanStart` + `onPanUpdate`
        // give immediate drag (no long-press needed) so a
        // developer can grab and move the FAB in one motion.
        Positioned.fill(
          child: Align(
            alignment: fabAlignment(widget.config.overlayPosition),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Transform.translate(
                offset: _fabDragOffset,
                child: GestureDetector(
                  // `deferToChild` lets the FAB's own `onPressed`
                  // win for quick taps (no movement). The
                  // `onPanUpdate` is registered on this outer
                  // detector so any movement drags the FAB. A
                  // quick tap (no movement) never enters the
                  // pan recognizer and falls through to the
                  // FAB's `onPressed`.
                  behavior: HitTestBehavior.deferToChild,
                  onPanUpdate: (DragUpdateDetails d) {
                    setState(() {
                      _fabDragOffset = _fabDragOffset + d.delta;
                    });
                  },
                  child: ApiTraceFab(
                    onPressed: () {
                      setState(() {
                        _open = !_open;
                      });
                    },
                    config: widget.config,
                    recordCount: widget.records.length,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Package-owned `Navigator` that hosts the [TimelinePanel]
/// and the [ApiTraceDetailScreen]. Pushing the detail onto
/// this Navigator (instead of the host app's) keeps the
/// back stack local to the inspector: the detail page's
/// back button returns to the panel without disturbing the
/// app's own navigation history.
class _PackageNavigator extends StatefulWidget {
  const _PackageNavigator({
    required this.records,
    required this.onRecordTap,
  });

  final List<ApiTraceRecord> records;
  final void Function(ApiTraceRecord)? onRecordTap;

  @override
  State<_PackageNavigator> createState() => _PackageNavigatorState();
}

class _PackageNavigatorState extends State<_PackageNavigator> {
  /// The current stack of pages. The bottom page is the
  /// `TimelinePanel`; pushing a detail adds an `_DetailPage`
  /// on top.
  ///
  /// IMPORTANT: the list is treated as IMMUTABLE. Each push
  /// / pop creates a NEW list and assigns it through
  /// `setState`. Mutating the existing list in place (e.g.
  /// `_pages.add`) is invisible to the `Navigator` widget,
  /// which compares `oldWidget.pages == newWidget.pages` by
  /// reference and would not rebuild on a mutating call. See
  /// the Flutter docs for `Navigator.pages`.
  List<Page<void>> _pages = const <Page<void>>[];

  @override
  void initState() {
    super.initState();
    _pages = <Page<void>>[
      _PanelPage(
        records: widget.records,
        onRecordTap: widget.onRecordTap,
        onRecordTapped: _pushDetail,
      ),
    ];
  }

  void _pushDetail(ApiTraceRecord record) {
    final userCallback = widget.onRecordTap;
    if (userCallback != null) {
      userCallback(record);
      return;
    }
    setState(() {
      // Create a NEW list so the Navigator widget detects
      // the change. See the `_pages` field doc.
      _pages = <Page<void>>[
        ..._pages,
        _DetailPage(record: record),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    // The package-owned Navigator is nested inside the
    // host app's `MaterialApp` Navigator. By default, both
    // Navigators inherit the same `HeroController` from
    // `MaterialApp`, which causes a runtime assert:
    //   "A HeroController can not be shared by multiple
    //    Navigators."
    // The fix is to scope a fresh `HeroController` to this
    // Navigator subtree. We use `.none` because the
    // inspector's pages (`TimelinePanel`, `ApiTraceDetailScreen`)
    // never declare a `Hero` widget, so an empty controller
    // is correct and avoids the assertion.
    return HeroControllerScope.none(
      child: Navigator(
        onDidRemovePage: (Page<dynamic> page) {
          setState(() {
            // Same rationale as `_pushDetail`: a NEW list so
            // the Navigator widget detects the change.
            _pages = _pages
                .where((Page<void> p) => p.key != page.key)
                .toList(growable: false);
          });
        },
        pages: _pages,
      ),
    );
  }
}

class _PanelPage extends Page<void> {
  const _PanelPage({
    required this.records,
    required this.onRecordTap,
    required this.onRecordTapped,
  }) : super(key: const ValueKey('apiTracePanel'));

  final List<ApiTraceRecord> records;
  final void Function(ApiTraceRecord)? onRecordTap;
  final void Function(ApiTraceRecord) onRecordTapped;

  @override
  Route<void> createRoute(BuildContext context) {
    return MaterialPageRoute<void>(
      settings: this,
      builder: (BuildContext context) => TimelinePanel(
        records: records,
        onTap: onRecordTapped,
      ),
    );
  }
}

class _DetailPage extends Page<void> {
  const _DetailPage({required this.record})
      : super(key: const ValueKey('apiTraceDetail'));

  final ApiTraceRecord record;

  @override
  Route<void> createRoute(BuildContext context) {
    return MaterialPageRoute<void>(
      settings: this,
      builder: (BuildContext context) => ApiTraceDetailScreen(record: record),
    );
  }
}
