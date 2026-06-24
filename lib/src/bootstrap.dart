// The debug-only bootstrap widget (REQ-UI-001, REQ-UI-002).
//
// `ApiTraceBootstrap` is a `StatelessWidget` that wraps the
// developer's app. In release mode (kDebugMode == false),
// the build method short-circuits to the child unchanged, so
// the developer's widget tree is bit-identical to a tree
// without the bootstrap. In debug mode, the bootstrap wraps
// the child in a `Stack` (or `MaterialApp.builder`-style
// overlay) and mounts the `ApiTraceOverlay` on top.
//
// The integration contract is one line:
//
// ```dart
// void main() => ApiTrace.runApp(const MyApp());
// ```
//
// `ApiTrace.runApp` is defined in `lib/src/api_trace.dart`
// and wraps the developer's app in `ApiTraceBootstrap`.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_api_inspector/src/api_trace.dart';
import 'package:flutter_api_inspector/src/overlay/api_trace_overlay.dart';

/// Wraps the developer's [child] in the debug-only overlay.
class ApiTraceBootstrap extends StatelessWidget {
  /// Creates the bootstrap.
  ///
  /// [child] is the developer's app (typically a `MaterialApp`).
  const ApiTraceBootstrap({super.key, required this.child});

  /// The developer's app widget.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // REQ-UI-001: kDebugMode guard. In release mode the
    // bootstrap is a pass-through, so the developer's tree
    // is bit-identical to a tree without the bootstrap.
    if (!kDebugMode) {
      return child;
    }
    // In debug mode, wrap the child in a Builder that mounts
    // the overlay on top. The overlay itself short-circuits
    // when ApiTrace.enabled is false, so this is the
    // single layer that observes the master switch.
    //
    // We wrap the Stack in a Directionality(textDirection:
    // TextDirection.ltr) so the Stack (and the overlay's
    // Align) can find a Directionality ancestor. In
    // production, the developer's MaterialApp / CupertinoApp
    // provides this; the explicit Directionality is a
    // defence-in-depth measure that also makes the overlay
    // work in tests that don't wrap in a MaterialApp.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: <Widget>[
          child,
          ValueListenableBuilder<String?>(
            valueListenable: ApiTrace.timeline.latest,
            builder: (BuildContext context, String? _, Widget? __) {
              if (!ApiTrace.enabled) {
                return const SizedBox.shrink();
              }
              return ApiTraceOverlay(
                config: ApiTrace.config,
                records: ApiTrace.timeline.records,
              );
            },
          ),
        ],
      ),
    );
  }
}
