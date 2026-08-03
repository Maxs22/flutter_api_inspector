// Centralized theme tokens for the inspector overlay.
//
// Every token derives from the HOST app's `ColorScheme`, so the
// overlay inherits the app's visual identity (Material 3 tonal
// surfaces carry the app's primary tint) instead of shipping a
// fixed palette. Two guarantees:
//
// 1. App colors: surfaces come from the scheme's tonal surface
//    roles (`surfaceContainer*`), text/icons from `onSurface*`
//    roles — pairs the scheme already guarantees legible.
// 2. Contrast: any color NOT paired with its surface by the
//    scheme (the app's `primary` used as accent, the semantic
//    success/error hues, HTTP-method hues) is passed through
//    [inspectorEnsureContrast], which nudges it toward
//    black/white until it reaches a minimum WCAG contrast
//    ratio against the panel background. A pastel-yellow
//    `primary` on a white panel stays readable.

import 'package:flutter/material.dart';

/// The accent color used by the inspector overlay when no theme
/// is available. Deep purple, matching Flutter's default seed.
const Color _inspectorAccent = Color(0xFF6750A4);

/// Radius for cards / chips / containers in the overlay.
const double inspectorRadius = 10.0;

/// Spacing unit. All paddings and gaps are multiples of this.
const double inspectorSpacing = 8.0;

/// WCAG contrast ratio between [a] and [b] (1.0 – 21.0).
double _contrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double hi = la > lb ? la : lb;
  final double lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Returns [fg] if it already reaches [minRatio] against [bg];
/// otherwise nudges it toward black (on light backgrounds) or
/// white (on dark backgrounds) just enough to reach the ratio.
///
/// 3.0 is the WCAG minimum for large text / UI components —
/// enough for badges, icons, and accent chips. Pass 4.5 for
/// body-size text.
Color inspectorEnsureContrast(
  Color fg,
  Color bg, {
  double minRatio = 3.0,
}) {
  if (_contrastRatio(fg, bg) >= minRatio) return fg;
  final Color target =
      bg.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  for (double t = 0.1; t < 1.0; t += 0.1) {
    final Color adjusted = Color.lerp(fg, target, t)!;
    if (_contrastRatio(adjusted, bg) >= minRatio) return adjusted;
  }
  return target;
}

/// The overlay accent: the host app's `colorScheme.primary`,
/// contrast-guaranteed against the panel background.
Color inspectorAccent(BuildContext context) => inspectorEnsureContrast(
      Theme.of(context).colorScheme.primary,
      inspectorPanelBackground(context),
    );

/// Semantic success green. The hue is fixed (green means success
/// regardless of the app's palette) but the shade adapts to
/// brightness and is contrast-guaranteed against the panel.
Color inspectorSuccess(BuildContext context) => inspectorEnsureContrast(
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF4ADE80) // green-400
          : const Color(0xFF16A34A), // green-600
      inspectorPanelBackground(context),
    );

/// Semantic error red. Same policy as [inspectorSuccess].
Color inspectorError(BuildContext context) => inspectorEnsureContrast(
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFF87171) // red-400
          : const Color(0xFFDC2626), // red-600
      inspectorPanelBackground(context),
    );

/// De-emphasized text / icons. `onSurfaceVariant` is the
/// scheme's own "muted but legible on surface" role.
Color inspectorMuted(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;

/// The floating panel's background: a tonal surface from the
/// app's scheme, so it carries the app's primary tint.
Color inspectorPanelBackground(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHigh;

Color inspectorGroupHeaderBackground(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHighest;

Color inspectorRowBackground(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHigh;

Color inspectorRowHoverBackground(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHighest;

/// Fill for text fields and unselected chips inside the panel.
Color inspectorFieldFill(BuildContext context) =>
    Theme.of(context).colorScheme.surfaceContainerHighest;

/// Inset background for code blocks / key-value tables in the
/// detail screen: the panel background darkened (or lightened)
/// with a touch of `onSurface`, so it reads as recessed in both
/// brightnesses while keeping the app's tint.
Color inspectorCodeBlockBackground(BuildContext context) => Color.alphaBlend(
      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
      inspectorPanelBackground(context),
    );

/// Hue for an HTTP method chip (GET blue, POST green, DELETE
/// red, ...). The hue is fixed by convention; the shade adapts
/// to brightness and the result is contrast-guaranteed against
/// the row background.
Color inspectorMethodColor(BuildContext context, String method) {
  final bool dark = Theme.of(context).brightness == Brightness.dark;
  final Color base = switch (method.toUpperCase()) {
    'GET' => dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
    'POST' => dark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
    'PUT' ||
    'PATCH' =>
      dark ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
    'DELETE' => dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
    _ => Theme.of(context).colorScheme.onSurfaceVariant,
  };
  return inspectorEnsureContrast(base, inspectorRowBackground(context));
}

/// Default accent for places where the theme isn't available
/// (e.g. tests that render widgets in isolation).
Color get inspectorDefaultAccent => _inspectorAccent;
