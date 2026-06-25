// Centralized theme tokens for the inspector overlay. The
// overlay is a debug-only surface so we keep the design
// simple but polished: Material 3 color roles, consistent
// radius + spacing, and a purple accent that matches the
// default `FloatingActionButton` background the user already
// configures in their app.

import 'package:flutter/material.dart';

/// The accent color used by the inspector overlay. Defaults
/// to a deep purple that matches Flutter's default seed. The
/// user can override by setting their own `ThemeData` color
/// scheme; the overlay reads `colorScheme.primary` whenever
/// it needs an accent.
const Color _inspectorAccent = Color(0xFF6750A4);

/// Radius for cards / chips / containers in the overlay.
const double inspectorRadius = 10.0;

/// Spacing unit. All paddings and gaps are multiples of this.
const double inspectorSpacing = 8.0;

/// Returns a color for a `Row`'s status icon, the
/// `Group`'s success/error tint, and similar places. Uses
/// the theme's color scheme when available, otherwise a
/// hard-coded fallback so tests can render the overlay
/// without a full `MaterialApp`.
Color inspectorAccent(BuildContext context) =>
    Theme.of(context).colorScheme.primary;

Color inspectorSuccess(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF4ADE80) // green-400
        : const Color(0xFF16A34A); // green-600

Color inspectorError(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF87171) // red-400
        : const Color(0xFFDC2626); // red-600

Color inspectorMuted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF6B7280) // gray-500
        : const Color(0xFF9CA3AF); // gray-400

Color inspectorPanelBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1F2937) // gray-800
        : Colors.white;

Color inspectorGroupHeaderBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF374151) // gray-700
        : const Color(0xFFF3F4F6); // gray-100

Color inspectorRowBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF111827) // gray-900
        : Colors.white;

Color inspectorRowHoverBackground(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1F2937) // gray-800
        : const Color(0xFFF9FAFB); // gray-50

/// Default accent for places where the theme isn't available
/// (e.g. tests that render widgets in isolation).
Color get inspectorDefaultAccent => _inspectorAccent;
