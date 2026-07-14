# Verify Report: route-scoped-network-inspector

Date: 2026-07-14
Verifier: sdd-verify (independent re-verification, no trust in prior claims)

## Verdict: GREEN-WITH-MINOR

All 8 spec requirements (REQ-RS-001..008) have real, passing, non-vacuous test
coverage. flutter analyze is clean in both the package and example/.
flutter test is 100 percent green (237/237). The 5 bugfixes and the export gap
claimed in apply-progress are present in the current working tree. The
chained-PR size budget documented in tasks.md (<=400 lines per PR) is
not realistic given the actual diff, this is the most significant
finding and should be resolved before/at archive, but it does not block
functional correctness.

## Build/Test Evidence

- flutter analyze (repo root): No issues found (ran in 85.1s)
- flutter analyze (example/): No issues found (ran in 1.7s)
- flutter test (repo root): 237/237 passed, 0 failures.

## Spec Compliance Matrix

| Req | Scenario | Covering test | Status |
|---|---|---|---|
| REQ-RS-001 | Push creates scope entry | route_scope_test.dart: "push creates a scope entry with scopeId 1 and no parent" | PASS |
| REQ-RS-001 | Push after push creates child scope | same file: "push after push creates a child scope" | PASS |
| REQ-RS-001 | Pop restores parent | "pop restores the parent scope" | PASS |
| REQ-RS-001 | Replace creates new scope at same depth | "replace creates a new scope entry at the current depth" | PASS |
| REQ-RS-001 | Scope IDs monotonically increasing | "scope IDs are monotonically increasing across 5 transitions" | PASS |
| REQ-RS-001 | navigatorRoute field correctness | none found | GAP (WARNING): field is set (route.settings.name) but no test asserts its value anywhere in test/ |
| REQ-RS-002 | Dio request tagged (route A, scopeId 1) | dio_interceptor_test.dart: "route A active (scopeId 1)..." | PASS |
| REQ-RS-002 | Dio request tagged after push (scopeId 2) | same file, next test | PASS |
| REQ-RS-002 | Dio request tagged after pop (back to A) | same file, pop-then-request test | PASS |
| REQ-RS-002 | No RouteScope: no crash, no tag | same file: "no RouteScope active (release-mode style)" | PASS |
| REQ-RS-003 | HttpClient request tagged with route scope | http_overrides_test.dart: "route A active..." | PASS |
| REQ-RS-003 | Tagged after push (scopeId 2) | same file | PASS |
| REQ-RS-003 | No RouteScope: no crash | same file | PASS |
| REQ-RS-004 | Convenience getters return scope data | api_trace_record_test.dart: "routeScopeId and routeName are accessible..." | PASS |
| REQ-RS-004 | Legacy records return null, no throw | same file: "legacy records (no scope data) return null without throwing" | PASS |
| REQ-RS-005 | Route tree shows visited routes, indented by depth | overlay_test.dart RouteTreeTab group, asserts dx ordering A less than B less than C | PASS |
| REQ-RS-005 | Tapping a route filters the timeline | overlay_test.dart: onScopeSelected test plus TimelinePanel scope-filter group | PASS |
| REQ-RS-005 | Active route highlighted | overlay_test.dart asserts FontWeight.w700 on B, not on A | PASS |
| REQ-RS-005 | Clear resets filter | overlay_test.dart: "the Clear button fires onScopeSelected(null)" | PASS |
| REQ-RS-006 | Relative timestamp shown when filtered | overlay_test.dart asserts literal text "+500ms" | PASS |
| REQ-RS-006 | Absolute timestamp when unfiltered | overlay_test.dart: "absolute timestamp remains when scopeEntry is null" | PASS |
| REQ-RS-007 | Export respects route filter, header format | overlay_test.dart full FAB to Routes to tap to Timeline to export to clipboard E2E test, asserts exactly 4 curl commands and header format | PASS |
| REQ-RS-008 | kDebugMode guard, RouteScope no-op in release | route_scope.dart guard line + string-matched test + release APK libapp.so string-grep (TASK-RS-006, not independently re-run this pass) | PASS (indirect) |

## Bugfix / Gap Confirmation (cross-checked against current working tree, not just claims)

1. Missing extra: forward in Dio interceptor. Confirmed fixed: dio_interceptor.dart passes extra: options.extra to ApiTrace.call.
2. Missing active route highlight in Route Tree UI. Confirmed fixed: route_tree_tab.dart has an isActive flag (currentScopeId == entry.scopeId) independent of isSelected, with a passing test.
3. Missing public barrel exports. Confirmed fixed: flutter_api_inspector.dart exports RouteScope, RouteScopeEntry, RouteScopeObserver, and ApiTraceRecordScope.
4. Panel-height regression. The LayoutBuilder-wrapping fix is present in timeline_panel.dart (documented inline) and all pre-existing overlay tests still pass (237/237 total, no regressions observed).
5. Bracket-mismatch compile error and broken runtime cast in export handler. Could NOT be independently re-verified against the original bug text: the engram apply-progress topic_key was upserted (revisions: 3) and only the latest revision (covering TASK-RS-006/010) is retrievable; detail for these two earlier bugs was overwritten by the upsert. Indirect confirmation: flutter analyze is clean (would catch a bracket-mismatch) and all 237 tests pass (would catch a broken cast in the export handler); no residual defect found in current code.

## Findings

### CRITICAL

None. Analyze is clean, all tests pass, all 8 REQs have real covering tests, all claimed fixes are present in the code.

### WARNING

1. Chained-PR size budget in tasks.md is unrealistic vs. the actual diff. tasks.md states "PR 1 (TASK-RS-001 to 006) less than 400 lines" and "PR 2 (TASK-RS-007 to 010) less than 400 lines". Since HEAD == main on this branch (nothing committed yet), git diff --stat main...HEAD returns nothing; the real diff was measured against the working tree (tracked git diff --stat plus untracked new-file line counts):
   - PR1-scoped files (route_scope.dart, route_scope_observer.dart, their tests, dio/http interceptor changes, model changes, barrel changes, bootstrap changes): approximately 880 lines, roughly 2.2x the stated budget.
   - PR2-scoped files (route_tree_tab.dart, api_trace_overlay.dart changes, timeline_panel.dart changes, overlay_test.dart additions, example/main.dart, config.dart): approximately 1260 lines, roughly 3.2x the stated budget.
   - The Review Workload Guard forecast from sdd-tasks understated the real review burden significantly. Since nothing is committed yet this is fixable: split PR1/PR2 further into smaller chained slices, or explicitly record a size:exception approved by a maintainer. Recommend resolving before sdd-archive closes the change.

2. REQ-RS-001's navigatorRoute field has zero test coverage. The field is populated correctly (navigatorRoute: route.settings.name) but no test anywhere in test/ asserts its value. Low risk but a genuine coverage gap against the requirement's explicit field list.

3. RouteScope release behavior diverges from the overlay's release behavior when ApiTrace.forceEnabled is used. RouteScope.init() is gated by a hard, unconditional "if (!kDebugMode) return;" (per REQ-RS-008, verified via the release APK string-grep in TASK-RS-006). The overlay itself, and BootstrapMaterialAppHarness's RouteScopeObserver injection, are gated by the broader ApiTrace.enabled (kDebugMode OR forceEnabled). Net effect: in a release build with ApiTrace.forceEnabled = true, the overlay and the Routes tab UI will render, but the Route Tree will be permanently empty ("No routes tracked yet") because RouteScope._instance never gets created. This is spec-compliant (REQ-RS-008 requires the unconditional no-op, and this is what makes the TASK-RS-006 AOT tree-shaking proof valid) but it is an undocumented behavioral inconsistency that will confuse QA testers using forceEnabled release builds. Worth a one-line doc note.

4. Apply-progress audit trail is incomplete for 2 of the 5 claimed bugfixes. The engram apply-progress topic_key was upserted 3 times; only the final revision is retrievable, and it covers TASK-RS-006/010 only. The "bracket-mismatch compile error" and "broken runtime cast in an export handler" bugs mentioned in the verify task brief are not documented anywhere retrievable now. This does not affect current code correctness (analyze/tests are clean) but is a process gap: engram-only mode loses artifact history on upsert, unlike file-based/hybrid mode.

5. CHANGELOG.md still marks this feature "Added (in progress)" under the 0.3.0 heading, even though all 10 tasks are complete and verified. Should be updated to a normal Added entry (dropping "in progress") as part of archive.

### SUGGESTION

1. TASK-RS-006's release-build verification (APK build plus libapp.so string-grep) was not independently re-run by this verify pass (356s build time already documented, with a sound positive-control methodology). Consider re-running it periodically (e.g. in CI on release tags) rather than treating the one-time manual verification as permanent proof.
2. openspec/AGENTS.md rule 7 ("no auto-interceptor in the example") is stale relative to the shipped TracedDioInterceptor/TracedHttpOverrides public API. Already flagged in apply-progress as a follow-up doc cleanup; still open.

## Task Completion Cross-Check

All 10 tasks (TASK-RS-001..010) in tasks.md are marked [x] and each has concrete test/build evidence written inline. Independent inspection confirms the code matches every acceptance bullet listed, with the two coverage gaps noted above (WARNING #2, and the audit-trail gap in WARNING #4).

## Recommendation

GREEN-WITH-MINOR: ready for sdd-archive, contingent on the team's judgment on WARNING #1 (PR-size budget). Functionally the change is complete, correct, and fully tested; nothing here is a CRITICAL blocker. Before or during archive:
- Either re-forecast/re-split the chained PRs to match the real diff size, or record an explicit size:exception.
- Update CHANGELOG.md to drop "(in progress)".
- Optionally add a navigatorRoute assertion and a forceEnabled doc note (low priority, non-blocking).
