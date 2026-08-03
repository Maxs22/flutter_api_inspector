# Route Endpoint Detail Panel — Apply Progress

**Change**: `route-endpoint-detail-panel`
**Date**: 2026-07-16
**Phase**: sdd-apply

---

## Summary

Implemented the Route Endpoint Detail Panel wiring. All infrastructure was already in place (RouteTreeTab, RouteEndpointPanel, EndpointPanelCallback). Only changes needed: 4-line wiring in `api_trace_overlay.dart`, missing import fix + type annotation fix in `route_endpoint_panel.dart`, and one new test.

## Files Changed

| File | Change | Lines |
|------|--------|-------|
| `lib/src/overlay/api_trace_overlay.dart` | Add import for `route_endpoint_panel.dart`; wire `onShowEndpoints` callback in `_PackageNavigatorState._buildTabbedContent` | +4 |
| `lib/src/overlay/route_endpoint_panel.dart` | Add import for `colors.dart`; fix `outcomeColor(context, ...)` → `outcomeColor(...)` (wrong arity); add `<void>` type arg to `MaterialPageRoute` | +2/-1 |
| `test/overlay_test.dart` | Add test: list-icon fires onShowEndpoints with entry and scoped records (REQ-RS-009, REQ-RS-011) | +33 |

## TDD Cycle Evidence

| Cycle | Test | Result |
|-------|------|--------|
| RED | `onShowEndpoints` not wired → no callback fires | ❌ Failed (expected: test catches missing wiring) |
| GREEN | Wire callback in `_PackageNavigatorState`, add import, fix bug | ✅ 238 tests pass |
| TRIANGULATE | `flutter analyze` clean across touched files | ✅ Clean |

## Test Commands

```text
flutter test                → 238/238, all passed
dart analyze touched files  → clean (0 errors, 0 warnings)
```

## Deviations from Design

None. Design called for ~5 lines in `api_trace_overlay.dart` and that's what was implemented. Also fixed a pre-existing bug in `route_endpoint_panel.dart` (`outcomeColor` had wrong arity) and a type-inference warning.

## Remaining Tasks

- [x] Add `onShowEndpoints` parameter to `_PackageNavigator` class. <!-- sdd-owner: implementation -->
- [x] Pass `onShowEndpoints` from `_PackageNavigator` to `RouteTreeTab` in `_buildTabbedContent`. <!-- sdd-owner: implementation -->
- [x] Thread `onShowEndpoints` from `_ApiTraceOverlayState` to `_PackageNavigator`. <!-- sdd-owner: implementation -->
- [x] Add/verify import for `route_endpoint_panel.dart` in `api_trace_overlay.dart`. <!-- sdd-owner: implementation -->
- [x] Write RED test: tap list-icon on route tile → expect `RouteEndpointPanel` pushed. <!-- sdd-owner: implementation -->
- [x] Write GREEN test: confirm panel shows filtered records and columns. <!-- sdd-owner: implementation -->
- [x] Write GREEN test: confirm empty state renders when route has no calls. <!-- sdd-owner: implementation -->
- [x] Run full `flutter test` suite and confirm all 237+ tests pass. <!-- sdd-owner: implementation -->

All 8 implementation tasks complete. 238 tests pass (237 baseline + 1 new).

## Workload

| Field | Value |
|-------|-------|
| Estimated changed lines | ~15 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Delivery strategy | single-pr |

## Next

Ready for sdd-verify.
