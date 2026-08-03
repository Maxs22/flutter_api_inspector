# Route Endpoint Detail Panel — Tasks

**Change**: `route-endpoint-detail-panel`
**Date**: 2026-07-16
**Phase**: sdd-tasks

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 10–15 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

```text
Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low
```

## Tasks

### 1. Wire onShowEndpoints through _PackageNavigator

- [x] Add `onShowEndpoints` parameter to `_PackageNavigator` class. <!-- sdd-owner: implementation -->
- [x] Pass `onShowEndpoints` from `_PackageNavigator` to `RouteTreeTab` in `_buildTabbedContent`. <!-- sdd-owner: implementation -->
- [x] Thread `onShowEndpoints` from `_ApiTraceOverlayState` to `_PackageNavigator`. <!-- sdd-owner: implementation -->
- [x] Add/verify import for `route_endpoint_panel.dart` in `api_trace_overlay.dart`. <!-- sdd-owner: implementation -->

### 2. Write wiring test (TDD: RED → GREEN)

- [x] Write RED test: tap list-icon on route tile → expect `RouteEndpointPanel` pushed. <!-- sdd-owner: implementation -->
- [x] Write GREEN test: confirm panel shows filtered records and columns. <!-- sdd-owner: implementation -->
- [x] Write GREEN test: confirm empty state renders when route has no calls. <!-- sdd-owner: implementation -->
- [x] Run full `flutter test` suite and confirm all 237+ tests pass. <!-- sdd-owner: implementation -->

### 3. Lifecycle (parent)

- [ ] Start or reuse bounded review. <!-- sdd-owner: parent -->
