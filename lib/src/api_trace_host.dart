import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'api_trace.dart';
import 'api_trace_navigator_observer.dart';
import 'overlay/api_trace_overlay.dart';

/// Mounts the inspector inside the actual app's builder, alongside its Navigator.
///
/// Supply the same stable [observer] to the actual Navigator's observers list.
/// Keep existing builder wrappers inside [child]. Popup routes suspend the
/// entire inspector without discarding its open panel, filters or detail stack.
/// This widget never disposes the caller-owned observer.
class ApiTraceHost extends StatefulWidget {
  const ApiTraceHost({
    super.key,
    required this.observer,
    required this.child,
    this.enabled = true,
  });

  final ApiTraceNavigatorObserver observer;
  final Widget child;
  final bool enabled;

  @override
  State<ApiTraceHost> createState() => _ApiTraceHostState();
}

class _ApiTraceHostState extends State<ApiTraceHost> {
  bool _ready = false;
  bool _updatePending = false;

  @override
  void initState() {
    super.initState();
    widget.observer.addListener(_changed);
    _changed();
  }

  void _changed() {
    if (_updatePending) return;
    _updatePending = true;
    // Navigator notifies observers while building as well as from event
    // callbacks. Defer the host rebuild rather than marking an ancestor dirty.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePending = false;
      if (mounted) setState(() => _ready = true);
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void didUpdateWidget(ApiTraceHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.observer != widget.observer) {
      oldWidget.observer.removeListener(_changed);
      widget.observer.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.observer.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if ((!kDebugMode && !ApiTrace.forceEnabled) || !widget.enabled) {
      return widget.child;
    }
    return Stack(children: [
      widget.child,
      if (_ready)
        ListenableBuilder(
          listenable: ApiTrace.timeline.latest,
          builder: (context, _) => !ApiTrace.enabled
              ? const SizedBox.shrink()
              : Offstage(
                  offstage: widget.observer.hasActivePopup,
                  child: TickerMode(
                    enabled: !widget.observer.hasActivePopup,
                    child: ExcludeFocus(
                      excluding: widget.observer.hasActivePopup,
                      child: ApiTraceOverlay(
                        config: ApiTrace.config,
                        records: ApiTrace.timeline.records,
                        navigatorKey: ApiTrace.navigatorKey,
                      ),
                    ),
                  ),
                ),
        ),
    ]);
  }
}
