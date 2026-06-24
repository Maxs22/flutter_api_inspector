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
  /// the detail screen via `Navigator`.
  const ApiTraceOverlay({
    super.key,
    required this.config,
    required this.records,
    this.onRecordTap,
  });

  /// The package configuration.
  final ApiTraceConfig config;

  /// The records to render in the panel.
  final List<ApiTraceRecord> records;

  /// Optional callback for row taps. If null, the overlay
  /// pushes the detail screen via `Navigator`.
  final void Function(ApiTraceRecord)? onRecordTap;

  @override
  State<ApiTraceOverlay> createState() => _ApiTraceOverlayState();
}

class _ApiTraceOverlayState extends State<ApiTraceOverlay> {
  /// Open/closed state of the timeline panel.
  bool _open = false;

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
        // The panel, when open, takes the top half of the
        // screen. The SizedBox.fill + Align centers the
        // panel at the top.
        if (_open)
          Positioned.fill(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 500),
                child: TimelinePanel(
                  records: widget.records,
                  onTap: _handleRecordTap,
                ),
              ),
            ),
          ),
        // The FAB, positioned per the config.
        Positioned.fill(
          child: Align(
            alignment: fabAlignment(widget.config.overlayPosition),
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
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Handles a tap on a row in the panel. Either invokes the
  /// user-supplied `onRecordTap` callback, or pushes the
  /// detail screen via Navigator.
  void _handleRecordTap(ApiTraceRecord record) {
    final userCallback = widget.onRecordTap;
    if (userCallback != null) {
      userCallback(record);
      return;
    }
    // Default: push the detail screen via MaterialPageRoute.
    final navigator = Navigator.of(context, rootNavigator: false);
    navigator.push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext _) {
          return ApiTraceDetailScreen(record: record);
        },
      ),
    );
  }
}
