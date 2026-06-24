// Maps `ApiTraceOverlayPosition` to a Flutter `AlignmentGeometry`
// for the FAB inside the overlay (REQ-UI-003).
//
// The four enum values map to the four corners of the screen
// (the locked answer to proposal Q3). The function returns an
// `AlignmentGeometry` (not a concrete `Alignment`) so callers can
// use the value in `Align(alignment: …)` and in
// `FloatingActionButtonLocation` computations without losing
// precision.

import 'package:flutter/material.dart';

import 'package:flutter_api_inspector/src/config.dart';

/// Resolves the alignment for a given FAB [position].
///
/// - `bottomRight` -> `Alignment.bottomRight` (REQ-UI-003 default).
/// - `bottomLeft`  -> `Alignment.bottomLeft`.
/// - `topRight`    -> `Alignment.topRight`.
/// - `topLeft`     -> `Alignment.topLeft`.
AlignmentGeometry fabAlignment(ApiTraceOverlayPosition position) {
  switch (position) {
    case ApiTraceOverlayPosition.bottomRight:
      return Alignment.bottomRight;
    case ApiTraceOverlayPosition.bottomLeft:
      return Alignment.bottomLeft;
    case ApiTraceOverlayPosition.topRight:
      return Alignment.topRight;
    case ApiTraceOverlayPosition.topLeft:
      return Alignment.topLeft;
  }
}
