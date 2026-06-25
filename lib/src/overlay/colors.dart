// Maps `ApiTraceOutcome` to a `Color` for the timeline row
// tint (REQ-UI-008).
//
// The success color is `Colors.green.shade600` and the error
// color is `Colors.red.shade600` (per the design's resolved Q5:
// the outcome colors are fixed; the panel / detail screen use
// the user's `ThemeData` for everything else). 4xx and 5xx share
// the same red — they both resolve to `ApiTraceOutcome.error`,
// so this helper needs only one branch per outcome value, not
// per status code.
//
// `cancelled` is reserved for future use (v1 never produces it);
// it gets a neutral grey so a hypothetical row does not crash
// the render.

import 'package:flutter/material.dart';

import 'package:flutter_api_inspector/src/outcome.dart';

/// Resolves the row-tint color for a given [outcome]. Kept
/// for backwards compatibility; new code should use the
/// theme-aware helpers in `theme.dart` instead.
///
/// - `success` -> `Color(0xFF16A34A)` (Tailwind green-600).
/// - `error` -> `Color(0xFFDC2626)` (Tailwind red-600; 4xx and
///   5xx share the same red).
/// - `cancelled` -> `Color(0xFF6B7280)` (Tailwind gray-500;
///   reserved; never produced in v1).
Color outcomeColor(ApiTraceOutcome outcome) {
  switch (outcome) {
    case ApiTraceOutcome.success:
      return const Color(0xFF16A34A);
    case ApiTraceOutcome.error:
      return const Color(0xFFDC2626);
    case ApiTraceOutcome.cancelled:
      return const Color(0xFF6B7280);
  }
}
