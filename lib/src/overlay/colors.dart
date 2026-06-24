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

/// Resolves the row-tint color for a given [outcome].
///
/// - `success` -> `Colors.green.shade600` (REQ-UI-008).
/// - `error` -> `Colors.red.shade600` (REQ-UI-008; 4xx and 5xx
///   share the same red).
/// - `cancelled` -> `Colors.grey` (reserved; never produced in
///   v1, but the helper must still return a valid `Color`).
Color outcomeColor(ApiTraceOutcome outcome) {
  switch (outcome) {
    case ApiTraceOutcome.success:
      return Colors.green.shade600;
    case ApiTraceOutcome.error:
      return Colors.red.shade600;
    case ApiTraceOutcome.cancelled:
      return Colors.grey;
  }
}
