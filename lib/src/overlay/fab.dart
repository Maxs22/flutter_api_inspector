import 'package:flutter_api_inspector/src/overlay/icons.dart';
// The debug-only floating action button that the developer taps
// to open the API timeline panel (REQ-UI-003, REQ-UI-004).
//
// `ApiTraceFab` is a thin wrapper around `FloatingActionButton`
// that:
// - Renders `InspectorIcons.bolt` as the icon — the same bolt the
//   panel header uses, so FAB and panel share one identity.
//   Colors come from the host scheme's primaryContainer /
//   onPrimaryContainer pair (contrast-guaranteed by design), and
//   an error-colored dot appears when the timeline holds errors.
// - Renders one of three label shapes per `config.overlayLabel`:
//   `icon` (icon-only, default), `badge` (icon + numeric
//   badge), `chip` (icon + "API N" text).
// - The label text is hidden when `recordCount == 0` (per the
//   design's resolved Q4: the FAB is always visible, but the
//   count chip is hidden on an empty timeline).
// - Uses a rounded 56-px launcher for a comfortable touch target.
// - Uses the developer's `Theme.of(context).colorScheme.primary`
//   for the foreground / background (per design.md resolved Q5).
//
// The FAB does NOT take a `BuildContext`-based position argument:
// positioning is the caller's responsibility (the overlay wraps
// the FAB in an `Align(alignment: fabAlignment(config.overlayPosition))`).
// This keeps `ApiTraceFab` decoupled from its host layout — it can
// be reused in tests, in a custom overlay, or in a focused
// `OverlayEntry`.

import 'package:flutter/material.dart';

import 'package:flutter_api_inspector/src/config.dart';
import 'package:flutter_api_inspector/src/overlay/theme.dart';

/// The debug-only floating action button.
class ApiTraceFab extends StatelessWidget {
  /// Creates an `ApiTraceFab`.
  ///
  /// [onPressed] is the callback fired when the FAB is tapped
  /// (typically: open the panel).
  /// [config] controls the label shape (REQ-UI-004) and is the
  /// source of truth for everything that varies per app config.
  /// [recordCount] is the current timeline size; the badge / chip
  /// label is hidden when this is zero.
  const ApiTraceFab({
    super.key,
    required this.onPressed,
    required this.config,
    required this.recordCount,
    this.errorCount = 0,
  });

  /// Tap callback. Typically opens the timeline panel.
  final VoidCallback onPressed;

  /// The package configuration. Drives the label shape
  /// (`config.overlayLabel`).
  final ApiTraceConfig config;

  /// The current number of records in the timeline. Used by the
  /// `badge` and `chip` label shapes; hidden when zero.
  final int recordCount;

  /// Number of error records in the timeline. When positive, a
  /// small error-colored dot renders on the FAB so failures are
  /// visible at a glance without opening the panel.
  final int errorCount;

  /// The FAB icon: the same bolt used by the panel header, so
  /// the FAB and the panel read as one surface.
  static const IconData _icon = InspectorIcons.bolt;

  @override
  Widget build(BuildContext context) {
    // Explicit container pair from the host scheme: the two
    // roles are a contrast-guaranteed pair by definition, so the
    // FAB adopts the app's colors and stays legible on any theme.
    final scheme = Theme.of(context).colorScheme;

    Widget child = _buildLabel();
    if (errorCount > 0) {
      child = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          child,
          Positioned(
            left: -9,
            top: -7,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: inspectorEnsureContrast(
                  scheme.error,
                  scheme.primaryContainer,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: scheme.primaryContainer, width: 1.5),
              ),
            ),
          ),
        ],
      );
    }

    return FloatingActionButton(
      onPressed: onPressed,
      heroTag: 'flutter_api_inspector.fab',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 3,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: child,
    );
  }

  /// Renders the FAB's child widget: the icon alone, the icon
  /// plus a badge, or the icon plus a chip.
  Widget _buildLabel() {
    switch (config.overlayLabel) {
      case ApiTraceOverlayLabel.icon:
        return const Icon(_icon);
      case ApiTraceOverlayLabel.badge:
        if (recordCount <= 0) {
          return const Icon(_icon);
        }
        return _BadgeIcon(icon: const Icon(_icon), count: recordCount);
      case ApiTraceOverlayLabel.chip:
        if (recordCount <= 0) {
          return const Icon(_icon);
        }
        return _ChipLabel(icon: const Icon(_icon), count: recordCount);
    }
  }
}

/// Icon plus a numeric badge of the current record count.
///
/// Implemented as a `Stack` so the badge sits on the upper-right
/// corner of the icon. The Stack is the simplest way to
/// overlay two children of a `FloatingActionButton` (which
/// expects a single `Widget` for `child`).
class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon, required this.count});

  final Widget icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: <Widget>[
        icon,
        Positioned(
          right: -8,
          top: -8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              // onPrimaryContainer/primaryContainer is a
              // scheme-guaranteed contrast pair — the badge stays
              // legible on the FAB whatever the app's palette.
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primaryContainer,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Icon plus a short text label of the current record count
/// (e.g. "API 17"). Wrapped in a `FittedBox` so the label fits
/// inside the FAB even when the count grows.
class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.icon, required this.count});

  final Widget icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          icon,
          const SizedBox(width: 6),
          Text(
            'API $count',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
