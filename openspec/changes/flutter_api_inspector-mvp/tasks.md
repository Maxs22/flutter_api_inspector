# Tasks — `flutter_api_inspector-mvp`

- **Change**: `flutter_api_inspector-mvp`
- **Date**: 2026-06-23
- **Phase**: `sdd-tasks`
- **Artifact store**: OpenSpec in repo (`openspec/changes/flutter_api_inspector-mvp/`)
- **Status**: tasks — ready for `sdd-apply` (after delivery decision)
- **Inputs**: `proposal.md`, `specs/instrumentation-api.md` (9 REQ, 21 scenarios), `specs/overlay-ui.md` (8 REQ, 17 scenarios), `specs/timeline-model.md` (8 REQ, 14 scenarios), `design.md`
- **Source REQ count**: 25
- **Source scenario count**: 52
- **TDD mode**: `strict_tdd: true` per `openspec/config.yaml`. Every task records RED → GREEN → TRIANGULATE → REFACTOR evidence in `openspec/changes/flutter_api_inspector-mvp/apply-progress.md`.
- **Test command**: `flutter test` (per `openspec/config.yaml` → `rules.apply.test_command`)

This file is the contract that `sdd-apply` works against. Every task is `- [ ]` here; `sdd-apply` flips it to `- [x]` as it records the TDD cycle in `apply-progress.md`.

---

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines (additions + deletions) | **~2,900** (range 2,600 – 3,200) |
| 400-line budget risk | **High** |
| Chained PRs recommended | **Yes** |
| Suggested split | **PR 1 — Package skeleton + model layer** → **PR 2 — Instrumentation API** → **PR 3 — Overlay UI** → **PR 4 — Example app + acceptance evidence** |
| Delivery strategy | **ask-on-risk** (orchestrator should pause for user delivery decision before `sdd-apply` starts) |
| Chain strategy | **pending** (user to pick `stacked-to-main` vs `feature-branch-chain` vs `size-exception`; default recommendation is `feature-branch-chain` for a brand-new package) |

### Per-phase line estimate

| Phase | Tasks | Estimated lines | Cumulative |
| --- | --- | --- | --- |
| Phase A — Package skeleton | TASK-001 .. TASK-005 | ~210 | 210 |
| Phase B — Model layer | TASK-006 .. TASK-012 | ~720 | 930 |
| Phase C — Instrumentation API | TASK-013 .. TASK-017 | ~600 | 1,530 |
| Phase D — Overlay UI | TASK-018 .. TASK-025 | ~1,090 | 2,620 |
| Phase E — Example app | TASK-026 .. TASK-027 | ~120 | 2,740 |
| Phase F — Acceptance evidence | TASK-028 .. TASK-030 | ~180 | **~2,920** |

### Guard lines (must match `sdd-apply` gate)

```text
Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High
```

### Why chained PRs

- Total additions + deletions exceed the 400-line review budget by ~7×.
- Phases A → E are natural work units: each is self-contained, has clear
  start / finish / verification / rollback boundaries, and can ship
  independently.
- Splitting keeps each PR reviewable in <30 minutes; a single 2,900-line
  PR is hostile to code review and violates the
  `openspec/AGENTS.md` rule 4 + `openspec/config.yaml` →
  `rules.tasks.protect_review_workload` constraint.
- The work-unit split also maps to acceptance gates: each PR can be
  followed by an incremental `verify-report.md` partial pass.

### Recommended work-unit split (if chain strategy is `feature-branch-chain`)

1. **PR 1 — Package skeleton + model layer** (Phase A + B)
   - Branch: `feature/fai-skeleton-and-model` off `change/flutter_api_inspector-mvp`
   - Self-contained: no overlay, no API; just types + ring buffer + id.
   - Verification: `dart analyze` clean, `dart format --set-exit-if-changed` clean, `flutter test` green for `test/detail_test.dart`, `test/outcome_test.dart`, `test/id_test.dart`, `test/api_trace_record_test.dart`, `test/body_codec_test.dart`, `test/timeline_test.dart`.
   - Rollback: revert the commit; `lib/`, `test/`, and the meta files are removed in one revert.

2. **PR 2 — Instrumentation API** (Phase C)
   - Branch: `feature/fai-instrumentation-api` off PR 1
   - Self-contained: depends only on PR 1's model layer.
   - Verification: `flutter test` green for `test/config_test.dart` and `test/api_trace_test.dart`; REQ-API-001..009 satisfied.
   - Rollback: revert the commit; `lib/src/api_trace.dart`, `lib/src/config.dart`, and the test file are removed in one revert.

3. **PR 3 — Overlay UI** (Phase D)
   - Branch: `feature/fai-overlay-ui` off PR 2
   - Self-contained: depends on PR 1 (model) + PR 2 (API).
   - Verification: `flutter test` green for `test/overlay_test.dart` and `test/bootstrap_test.dart`; REQ-UI-001..008 satisfied at the `flutter test` level. The release-build smoke test (REQ-UI-001 out-of-band) is the only Phase F item.
   - Rollback: revert the commit; `lib/src/overlay/`, `lib/src/bootstrap.dart`, and the test files are removed in one revert.

4. **PR 4 — Example app + acceptance evidence** (Phase E + F)
   - Branch: `feature/fai-example-and-acceptance` off PR 3
   - Self-contained: depends on all three prior PRs.
   - Verification: `flutter pub get` succeeds for the example; `flutter test` is still green; the release-build smoke test is recorded in `apply-progress.md`; `verify-report.md` is green for success metrics 1–5.
   - Rollback: revert the commit; `example/`, the `apply-progress.md` updates, and the `verify-report.md` are removed in one revert.

---

## Open technical questions resolved (with documented defaults)

The 8 implementation-level questions from `design.md` are resolved here
so `sdd-apply` does not block on them. None of these change the spec
contract; they are choices between equally valid implementations.

| # | Question | Resolution | Source |
| --- | --- | --- | --- |
| 1 | FAB icon choice | `Icons.developer_mode` on a 40-px circular `FloatingActionButton` | design.md Q1 |
| 2 | Body parser strategy | Do **not** parse. The developer returns `Object?` (already parsed or already a `String`); the package only truncates. The detail view renders `String` via `Text` and any other type via `Text(...toString())`. | design.md Q2 |
| 3 | Detail-screen route shape | `MaterialPageRoute<bool>(builder: ...)` for slide-in consistency with the user's app | design.md Q3 |
| 4 | FAB visibility for zero records | Always visible (icon-only when `overlayLabel == icon`); the empty-timeline state is rendered inside the panel, not by hiding the FAB | design.md Q4 |
| 5 | Theme handling | The panel + detail screen use `Theme.of(context)`; the FAB uses `colorScheme.primary`; outcome colors are fixed `Colors.green.shade600` / `Colors.red.shade600` | design.md Q5 |
| 6 | Id generation collision space | `Random.secure().nextBytes(16)` → 32 hex chars. Documented as the chosen approach; `test/id_test.dart` asserts 10,000 generations with no collisions. | design.md Q6 |
| 7 | `ApiTraceScaffold` escape hatch | Not reserved. The package is v1. A future change can add it. | design.md Q7 |
| 8 | Release-build smoke test environment | See "Open technical questions to user" below. | design.md Q8 |

---

## Open technical questions to user

| # | Question | Why surfaced |
| --- | --- | --- |
| 8 | **Release-build smoke test environment** — where should `flutter build --release` be run for the binary-size-delta + symbol-table-absence + no-FAB-in-widget-tree checks (REQ-UI-001 out-of-band, proposal success metric #3)? | The repo host may not have an Android SDK or Xcode toolchain installed. `sdd-apply` records the build command and results in `apply-progress.md`, but the actual build may need to be deferred to a follow-up environment (a CI runner, a macOS dev host, or a `flutter-action` GitHub Action). The 5 KB size delta acceptance criterion is then verified at `sdd-verify` time, not at `sdd-apply` time. |

---

## Phase A — Package skeleton

These tasks create the public-package surface: the manifest, the lint
configuration, the pub.dev-facing docs, the barrel export, and a
`dart format` / `dart analyze` baseline. **No TDD cycle** for these
tasks — they are pure infrastructure with no behavior to test against
the spec (strict TDD applies to behavior, not to `pubspec.yaml`).

- [x] **TASK-001: Create `pubspec.yaml`**
  - **What**: Add the package manifest with metadata, runtime constraints, and the `flutter` / `flutter_test` dependencies. No third-party packages.
  - **Why**: Establishes the package identity (per `openspec/AGENTS.md` rule 10). Pins the runtime to `flutter >=3.16.0`, `dart >=3.2.0`, Android `minSdkVersion 21`, iOS `deployment_target 12.0` (per `openspec/config.yaml` → `stack.minimum_runtime`).
  - **Files**: `pubspec.yaml`
  - **Contents**:
    - `name: flutter_api_inspector`
    - `description: <one-line summary matching the proposal>`
    - `version: 0.1.0`
    - `environment: { sdk: ">=3.2.0 <4.0.0", flutter: ">=3.16.0" }`
    - `dependencies: { flutter: { sdk: flutter } }` only
    - `dev_dependencies: { flutter_test: { sdk: flutter } }` only
    - `flutter: { uses-material-icons: true }` (so `Icons.developer_mode` is available at runtime)
  - **Acceptance**: `flutter pub get` succeeds against the manifest; no `package:dio`, `package:http`, `package:uuid`, or `package:collection`.
  - **Workload estimate**: ~35 lines.

- [x] **TASK-002: Create `analysis_options.yaml` and `.gitignore`**
  - **What**: Add strict lint configuration that surfaces issues early, and a `.gitignore` that ignores `.dart_tool/`, `.packages`, `build/`, `pubspec.lock` (the package convention is to commit `pubspec.lock` only for apps, not libraries — confirm with the project policy in `openspec/AGENTS.md`).
  - **Why**: `dart analyze` is the primary lint/typecheck command (per `openspec/config.yaml` → `quality.lint`). A strict baseline catches bugs before `flutter test` runs. The `.gitignore` is needed because `flutter pub get` produces a `.dart_tool/` directory.
  - **Files**: `analysis_options.yaml`, `.gitignore`
  - **Contents**:
    - `analysis_options.yaml`: `include: package:flutter_lints/flutter.yaml` + project-specific tightenings (e.g. `prefer_const_constructors`, `prefer_final_locals`, `unnecessary_late`, `unnecessary_this`, `sort_child_properties_last`).
    - `.gitignore`: `.dart_tool/`, `.packages`, `build/`, `.idea/`, `.vscode/`, `*.iml`, `coverage/`, `.flutter-plugins`, `.flutter-plugins-dependencies`, `pubspec.lock` (library-package convention; confirm in `sdd-apply`).
  - **Acceptance**: `dart analyze` returns "No issues found" against an empty `lib/` and `test/`.
  - **Workload estimate**: ~45 lines.

- [x] **TASK-003: Create `README.md`, `CHANGELOG.md`, and `LICENSE` (MIT)**
  - **What**: Add the pub.dev-facing documentation. `README.md` explains what the package is, shows a 10-line `ApiTrace.call` example, links to `example/`, and documents the four guard call sites + the `enabled` opt-out. `CHANGELOG.md` starts at `0.1.0` with the MVP notes. `LICENSE` is the full MIT text.
  - **Why**: Required by `openspec/AGENTS.md` rule 10 and pub.dev conventions. The MIT license resolves the proposal's open question #8 (locked: MIT per the user's proposal answer round).
  - **Files**: `README.md`, `CHANGELOG.md`, `LICENSE`
  - **Acceptance**:
    - `README.md` mentions `ApiTrace.call(name, …, execute: …)`, `ApiTrace.enabled`, `ApiTrace.config`, `ApiTrace.runApp`, and the `kDebugMode` tree-shake contract.
    - `CHANGELOG.md` has a `## 0.1.0` section dated `2026-06-23`.
    - `LICENSE` is the standard MIT text with copyright `2026, the flutter_api_inspector authors`.
  - **Workload estimate**: ~115 lines.

- [x] **TASK-004: Create `lib/flutter_api_inspector.dart` barrel export**
  - **What**: Add the public barrel that re-exports the public surface. The barrel is the only public file in `lib/`; everything else lives under `lib/src/`.
  - **Why**: A single import surface (`package:flutter_api_inspector/flutter_api_inspector.dart`) is the pub.dev convention. The barrel is the only file the consumer ever imports.
  - **Files**: `lib/flutter_api_inspector.dart`
  - **Contents**: re-export `ApiTrace`, `ApiTraceConfig`, `ApiTraceDetail`, `ApiTraceOverlayPosition`, `ApiTraceOverlayLabel`, `ApiTraceOutcome`, `ApiTraceRecord`, `ApiTraceRequest`, `ApiTraceResponse`, `ApiTraceOverlay`, `ApiTraceBootstrap`, `ApiTraceDetailScreen`. (No re-export of internals like `Timeline`, `id`, `bodyCodec`.)
  - **TDD evidence contract**: not applicable for the barrel (no behavior to test). Coverage: `dart analyze` clean after the barrel is added.
  - **Acceptance**: `dart analyze` clean; the barrel compiles against the empty `lib/src/` (with stub `export` lines temporarily pointing to placeholder paths that the Phase B + C + D tasks will create).
  - **Workload estimate**: ~20 lines.

- [x] **TASK-005: Run `dart format` and `dart analyze` baseline (expect clean)**
  - **What**: After TASK-001..004 land, run `dart format --set-exit-if-changed .` and `dart analyze` and confirm both are no-ops. Record the output in `apply-progress.md`.
  - **Why**: Establishes the lint/format baseline so subsequent tasks can be diffed against it. Per `openspec/config.yaml` → `quality.lint_commands` and `quality.format_commands`, both are required to be clean before `verify-report.md` can be green.
  - **Files**: (no production changes) → outputs are recorded in `openspec/changes/flutter_api_inspector-mvp/apply-progress.md`.
  - **Acceptance**:
    - `dart format --set-exit-if-changed .` exits 0 (no formatting changes).
    - `dart analyze` exits 0 with "No issues found".
  - **Workload estimate**: ~5 lines of recorded output; no code change.

---

## Phase B — Model layer

These tasks create the in-memory data model: enums, immutable types,
the id generator, the body codec, the `fromCapture` factory that
enforces the privacy default, and the timeline ring buffer. Every
task follows RED → GREEN → TRIANGULATE → REFACTOR.

- [x] **TASK-006: Implement `ApiTraceDetail` enum (REQ-API-004)**
  - **What**: Create `lib/src/detail.dart` with `enum ApiTraceDetail { minimal, headers, request, response, full }` and `test/detail_test.dart` asserting the enum shape and ordering.
  - **Why**: REQ-API-004 requires the default `details` set to be `{ApiTraceDetail.minimal}` only; the enum shape must be locked before the config or record types can be built.
  - **Files**: `lib/src/detail.dart`, `test/detail_test.dart`
  - **TDD evidence contract**:
    - **RED**: `test/detail_test.dart` `'ApiTraceDetail has exactly five values'` — fails (no such type).
    - **GREEN**: declare the enum with five values.
    - **TRIANGULATE**: add `'default ordering is minimal < headers < request < response < full'` (or `'index of full is 4'`).
    - **REFACTOR**: extract the assertion of `ApiTraceDetail.values` into a top-level helper if the test file has more than one enum assertion.
  - **Acceptance**: `test/detail_test.dart` passes; `dart analyze` clean.
  - **Workload estimate**: ~35 lines.

- [x] **TASK-007: Implement `ApiTraceOutcome` enum (REQ-MODEL-002)**
  - **What**: Create `lib/src/outcome.dart` with `enum ApiTraceOutcome { success, error, cancelled }` and `test/outcome_test.dart` asserting the three-case shape.
  - **Why**: REQ-MODEL-002 requires the three-state outcome. `cancelled` is reserved for future use; v1 never produces it, but the enum shape is locked.
  - **Files**: `lib/src/outcome.dart`, `test/outcome_test.dart`
  - **TDD evidence contract**:
    - **RED**: `test/outcome_test.dart` `'ApiTraceOutcome has exactly three cases'`.
    - **GREEN**: declare the enum.
    - **TRIANGULATE**: add `'cancelled is the third case'`.
    - **REFACTOR**: no refactor expected.
  - **Acceptance**: `test/outcome_test.dart` passes; `dart analyze` clean.
  - **Workload estimate**: ~25 lines.

- [x] **TASK-008: Implement `id.dart` id generator (no `package:uuid`)**
  - **What**: Create `lib/src/id.dart` exporting a single top-level function `String generateId()` that returns 32 hex characters from `Random.secure().nextBytes(16)`. Add `test/id_test.dart` asserting the format and uniqueness.
  - **Why**: Helper for `ApiTraceRecord.id` (REQ-MODEL-001). Per the proposal acceptance criteria and `design.md` Q6, the package must not depend on `package:uuid`.
  - **Files**: `lib/src/id.dart`, `test/id_test.dart`
  - **TDD evidence contract**:
    - **RED**: `test/id_test.dart` `'generateId returns 32 hex chars'` — fails.
    - **GREEN**: implement `generateId`.
    - **TRIANGULATE**: add `'10000 generations produce no duplicates'`.
    - **REFACTOR**: confirm the function is `const`-compatible (e.g. uses a `static final` RNG or a `Random.secure()` instance captured in a top-level `final`).
  - **Acceptance**: `test/id_test.dart` passes; 10,000 generations produce 10,000 unique ids; format is exactly 32 lowercase hex chars.
  - **Workload estimate**: ~55 lines.

- [x] **TASK-009: Implement `ApiTraceRequest` and `ApiTraceResponse` types (REQ-MODEL-001)**
  - **What**: Create `lib/src/model/api_trace_request.dart` (`ApiTraceRequest { Map<String,String> headers; Object? body; }`) and `lib/src/model/api_trace_response.dart` (`ApiTraceResponse { int statusCode; Map<String,String> requestHeaders; Map<String,String> responseHeaders; Object? requestBody; Object? responseBody; }`). Both are `final` classes with `const` constructors and `copyWith` helpers (used by the `fromCapture` factory in TASK-010).
  - **Why**: REQ-MODEL-001 requires the schema. The `copyWith` helpers are needed by TASK-010 to redact fields without losing other fields.
  - **Files**: `lib/src/model/api_trace_request.dart`, `lib/src/model/api_trace_response.dart`, `test/api_trace_types_test.dart`
  - **TDD evidence contract**:
    - **RED**: `test/api_trace_types_test.dart` `'ApiTraceRequest defaults to empty headers and null body'` and `'ApiTraceResponse defaults to empty headers and null bodies'`.
    - **GREEN**: declare the types with `const` constructors and `final` fields.
    - **TRIANGULATE**: add `'copyWith returns a new instance with overridden fields'`.
    - **REFACTOR**: extract `copyWith` into a private helper if both classes have near-identical implementations.
  - **Acceptance**: `test/api_trace_types_test.dart` passes; `dart analyze` clean; `==` and `hashCode` not required (per design.md, records are identity-compared).
  - **Workload estimate**: ~100 lines.

- [x] **TASK-010: Implement `ApiTraceRecord` and `fromCapture` factory (REQ-MODEL-001, REQ-MODEL-005)**
  - **What**: Create `lib/src/model/api_trace_record.dart` with the immutable `ApiTraceRecord` (all `final` fields per the design) and a `factory ApiTraceRecord.fromCapture({...})` that nulls out `request` / `response` body and header fields whose detail level is not in the captured detail set. The factory is the single chokepoint for the privacy default (per `design.md` → *Privacy-conscious default enforcement*).
  - **Why**: REQ-MODEL-001 requires the schema; REQ-MODEL-005 requires the privacy default (`{minimal}` capture → no body, no headers).
  - **Files**: `lib/src/model/api_trace_record.dart`, `test/api_trace_record_test.dart`
  - **TDD evidence contract**:
    - **RED**: `test/api_trace_record_test.dart` `'Record exposes all required fields with correct types'` and `'Minimal capture has no body or headers'`.
    - **GREEN**: declare `ApiTraceRecord` with `const` constructor; declare `fromCapture` with the redact logic (per design.md's pseudocode).
    - **TRIANGULATE**: add `'Headers-only capture includes headers but not bodies'`, `'fromCapture generates a unique id per call'`, `'fromCapture clamps duration to non-negative'`.
    - **REFACTOR**: extract the redact logic into a private `_redact({...})` helper if the factory body exceeds 30 lines.
  - **Acceptance**:
    - `test/api_trace_record_test.dart` passes all of the above.
    - With `capturedDetails == {ApiTraceDetail.minimal}` and an `execute` callback returning an `ApiTraceResponse` with bodies and headers, the resulting `ApiTraceRecord.request == null` and `ApiTraceRecord.response == null` (privacy default enforced at construction time).
    - With `capturedDetails == {ApiTraceDetail.headers}`, the resulting `ApiTraceRecord.response.responseHeaders.isNotEmpty` and `ApiTraceRecord.response.responseBody == null`.
    - `dart analyze` clean.
  - **Workload estimate**: ~180 lines.

- [x] **TASK-011: Implement `body_codec.dart` (REQ-MODEL-006)**
  - **What**: Create `lib/src/body_codec.dart` exporting `truncateResponseBody(Object? body, int maxBytes)` (or a top-level `bodyCodec` namespace). For `String` bodies, the function returns the prefix of length `min(body.length, maxBytes)`. For `List<int>` bodies (bytes), it returns the prefix of length `min(bytes.length, maxBytes)`. For any other type, it serializes via `Object.toString()` and truncates.
  - **Why**: REQ-MODEL-006 requires response body truncation at `maxResponseBodyBytes` (default 4 KB). The codec is a small, pure helper — easy to unit-test independently of the API.
  - **Files**: `lib/src/body_codec.dart`, `test/body_codec_test.dart`
  - **TDD evidence contract**:
    - **RED**: `test/body_codec_test.dart` `'String body truncated to maxBytes'` (e.g. 10 KB string → 4 KB result), `'List<int> body truncated to maxBytes'`, `'body of length <= maxBytes is unchanged'`, `'truncation honors configured limit'`.
    - **GREEN**: implement the codec.
    - **TRIANGULATE**: add `'null body returns null'`, `'non-string non-bytes body is stringified and truncated'`.
    - **REFACTOR**: split into `truncateString`, `truncateBytes`, `truncateObject` private helpers if the public function exceeds 20 lines.
  - **Acceptance**:
    - `test/body_codec_test.dart` passes.
    - The function is pure (no side effects, no global state).
    - `dart analyze` clean.
  - **Workload estimate**: ~95 lines.

- [x] **TASK-012: Implement `Timeline` ring buffer (REQ-MODEL-003, REQ-MODEL-004, REQ-MODEL-007, REQ-MODEL-008)**
  - **What**: Create `lib/src/model/timeline.dart` with the `Timeline` class: `final int capacity; final List<ApiTraceRecord> records; final ValueNotifier<String?> latest;` plus `void append(ApiTraceRecord r)` and `@visibleForTesting void clear()`. `append` is `_records.insert(0, r); if (_records.length > capacity) _records.removeLast(); latest.value = r.id;`. The list is exposed via `UnmodifiableListView` to prevent external mutation.
  - **Why**: REQ-MODEL-003 requires capacity-based eviction; REQ-MODEL-004 requires newest-first ordering with insertion-order tie-break; REQ-MODEL-007 requires reentrancy (handled implicitly by the single-isolate event-loop, but the append path is exercised by the test); REQ-MODEL-008 requires in-memory only (a process-restart reset is a test-time check).
  - **Files**: `lib/src/model/timeline.dart`, `test/timeline_test.dart`
  - **TDD evidence contract**:
    - **RED**: `test/timeline_test.dart` scenarios for *Default capacity holds exactly 200 records*, *Oldest record evicted when capacity is exceeded*, *Capacity honored when configured explicitly*, *Newest record first*, *Insertion order breaks tie on identical start time*, *Two concurrent calls each produce a record*, *Timeline resets across process restart*.
    - **GREEN**: implement `Timeline.append` with the head-insert + tail-evict + `latest` update logic.
    - **TRIANGULATE**: add `'latest ValueNotifier is set to the new record id on every append'`, `'records is an unmodifiable view'`.
    - **REFACTOR**: extract a private `_evictIfFull()` helper if the append method exceeds 6 lines.
  - **Acceptance**:
    - `test/timeline_test.dart` passes all seven scenarios.
    - The "process restart" scenario constructs a fresh `Timeline` in a separate test (or via the `clear()` helper) to simulate the restart — the assertion is that the new instance is empty.
    - `dart analyze` clean.
  - **Workload estimate**: ~205 lines.

---

## Phase C — Instrumentation API

These tasks build the `ApiTrace` static class on top of the model
layer. Every task follows RED → GREEN → TRIANGULATE → REFACTOR.

- [x] **TASK-013: Implement `ApiTraceConfig` + `ApiTraceOverlayPosition` + `ApiTraceOverlayLabel` (REQ-API-003, REQ-API-004)**
  - **Why**: REQ-API-003 requires the position/label enums; REQ-API-004 requires the default `details == {minimal}`, `timelineCapacity == 200`, `maxResponseBodyBytes == 4096`, `overlayPosition == bottomRight`, `overlayLabel == icon`. These are the locked answers to proposal Q2, Q3, Q5.
  - **Files**: `lib/src/config.dart`, `test/config_test.dart`
  - **TDD evidence contract**:
    - **RED**: `test/config_test.dart` scenarios for *Default overlay position is bottom-right*, *Default overlay label is icon*, *overlayPosition enum has exactly four values*, *overlayLabel enum has exactly three values*, *Default config details contain only minimal*, *Default config timeline capacity is 200*, *Default config max response body bytes is 4 KB*.
    - **GREEN**: declare the two enums and the `ApiTraceConfig` class with the `const` constructor.
    - **TRIANGULATE**: add `'overlayPosition values include bottomLeft, topRight, topLeft'`, `'overlayLabel values include badge, chip'`.
    - **REFACTOR**: extract a private `_defaultDetails` constant if it appears in more than one place.
  - **Acceptance**:
    - `test/config_test.dart` passes all scenarios.
    - `ApiTraceConfig()` produces a config with the five locked defaults.
    - `dart analyze` clean.
  - **Workload estimate**: ~120 lines.

- [x] **TASK-014: Implement `ApiTrace.call` async signature + returned id (REQ-API-001, REQ-API-008)**
  - **Why**: REQ-API-001 requires the async-with-execute signature; REQ-API-008 requires the returned id to be the record's id. The "happy path" is the foundation for the other API tests.
  - **Files**: `lib/src/api_trace.dart`, `test/api_trace_test.dart` (RED cycle for the happy-path scenarios only)
  - **TDD evidence contract**:
    - **RED**: `test/api_trace_test.dart` `'Execute callback awaited once'`, `'Recorded response matches execute return value'`, `'Returned id matches recorded record'`.
    - **GREEN**: implement the `call` method with a minimal happy path (no error branches yet, no enabled short-circuit yet — those are TASK-015/017).
    - **TRIANGULATE**: add `'Two distinct calls produce two distinct ids'`.
    - **REFACTOR**: extract `Future<String> _capture({...})` as a private helper if the `call` method exceeds 30 lines.
  - **Acceptance**:
    - The three named tests pass.
    - `ApiTrace.timeline.size` grows by exactly one per `ApiTrace.call(...)`.
    - `dart analyze` clean.
  - **Workload estimate**: ~140 lines (file + test additions for this task only).

- [x] **TASK-015: Implement `ApiTrace.enabled` short-circuit + `kDebugMode` default (REQ-API-002, REQ-API-006)**
  - **Why**: REQ-API-002 requires the short-circuit; REQ-API-006 requires the `kDebugMode`-at-first-read default. Both are required for the release-mode tree-shake to be safe (a `flutter build --release` sets `kDebugMode == false`, which short-circuits `call`).
  - **Files**: `lib/src/api_trace.dart`, `test/api_trace_test.dart` (extend with two new `group`s)
  - **TDD evidence contract**:
    - **RED**: `test/api_trace_test.dart` `'Disabled call returns null'`, `'Disabled call never invokes execute'`, `'enabled is true at first read in debug'`.
    - **GREEN**: add the field and the short-circuit.
    - **TRIANGULATE**: add `'enabled is mutable: assigning false is observed by a subsequent read'`, `'Disabled call does not append to timeline'`.
    - **REFACTOR**: extract the `if (!enabled) return …` early-return into a small private `_shortCircuit()` helper for clarity.
  - **Acceptance**:
    - All three scenarios pass.
    - The `enabled` field is mutable in the test (the test mutates it in `setUp` / `tearDown` to avoid cross-test pollution).
    - `dart analyze` clean.
  - **Workload estimate**: ~70 lines (additions to file + test).

- [x] **TASK-016: Implement per-call `detailOverride` (REQ-API-005)**
  - **Why**: REQ-API-005 requires the per-call override to widen the captured detail set for that call only, and to leave the global config unchanged.
  - **Files**: `lib/src/api_trace.dart`, `test/api_trace_test.dart` (extend with one new `group`)
  - **TDD evidence contract**:
    - **RED**: `test/api_trace_test.dart` `'Per-call override unions with global'`, `'Per-call override does not mutate global config'`, `'Null override uses global'`.
    - **GREEN**: add the union logic.
    - **TRIANGULATE**: add `'Override with full set captures all detail levels'`, `'Override with subset of global is idempotent'`.
    - **REFACTOR**: extract `Set<ApiTraceDetail> _effectiveDetails(Set<ApiTraceDetail>? override)`.
  - **Acceptance**:
    - The three scenarios pass.
    - After a call with `detailOverride: {ApiTraceDetail.response}`, `ApiTrace.config.details` is still `{ApiTraceDetail.minimal}` (no global mutation).
    - `dart analyze` clean.
  - **Workload estimate**: ~80 lines.

- [x] **TASK-017: Implement error capture + reentrancy contract (REQ-API-007, REQ-API-009, REQ-MODEL-007)**
  - **Why**: REQ-API-007 requires error capture (thrown + 4xx + 5xx); REQ-API-009 and REQ-MODEL-007 require that two concurrent (or nested) `ApiTrace.call` invocations each produce exactly one record. Both are required for the API to be safe in real apps.
  - **Files**: `lib/src/api_trace.dart`, `test/api_trace_test.dart` (extend with two new `group`s)
  - **TDD evidence contract**:
    - **RED**: `test/api_trace_test.dart` `'Thrown exception captured as error'`, `'4xx response captured as error'`, `'5xx response captured as error'`, `'2xx response captured as success'`, `'Reentrant call produces two distinct records'`, `'Two concurrent calls each produce a record'`.
    - **GREEN**: implement the try/catch and the outcome derivation.
    - **TRIANGULATE**: add `'Reentrant call: outer call awaits inner call before returning'`, `'Outcome derivation: 1xx, 2xx, 3xx are success'`, `'Outcome derivation: 4xx and 5xx are both error'`.
    - **REFACTOR**: extract the outcome derivation into a top-level private function `ApiTraceOutcome _deriveOutcome({ApiTraceResponse? response, Object? error})` in `api_trace.dart` (or move it to `model/api_trace_record.dart` if preferred).
  - **Acceptance**:
    - All six scenarios pass.
    - A `FormatException` thrown from `execute` produces `record.outcome == error` and `record.error is FormatException`.
    - A nested `ApiTrace.call` produces two records in the timeline; the outer id and the inner id are distinct.
    - `dart analyze` clean.
  - **Workload estimate**: ~140 lines (additions to file + test, including the reentrancy test which is the largest single test in the API layer).

---

## Phase D — Overlay UI

These tasks build the in-app debug-only overlay. Every task follows
RED → GREEN → TRIANGULATE → REFACTOR. Widget tests use
`flutter_test`'s `WidgetTester` and `pumpWidget`.

- [ ] **TASK-018: Implement `outcomeColor` + `fabAlignment` helpers (REQ-UI-003, REQ-UI-008)**
  - **What**: Create `lib/src/overlay/colors.dart` with `Color outcomeColor(ApiTraceOutcome outcome)` (green for success, red for error, neutral for cancelled). Create `lib/src/overlay/fab_position.dart` with `AlignmentGeometry fabAlignment(ApiTraceOverlayPosition position)` (the four-corner mapping). Both are top-level pure functions; no widgets yet.
  - **Why**: These two helpers are used by `ApiTraceFab` and `TimelineRow`. Implementing them first lets TASK-019 and TASK-020 build on top.
  - **Files**: `lib/src/overlay/colors.dart`, `lib/src/overlay/fab_position.dart`, `test/overlay_test.dart` (initial scaffolding + helper tests)
  - **TDD evidence contract**:
    - **RED**: `test/overlay_test.dart` `'outcomeColor: success is green'`, `'outcomeColor: error is red'`, `'outcomeColor: cancelled is neutral'`, `'fabAlignment: bottomRight is Alignment.bottomRight'`, `'fabAlignment: topLeft is Alignment.topLeft'`.
    - **GREEN**: implement the two helpers.
    - **TRIANGULATE**: add `'fabAlignment: bottomLeft is Alignment.bottomLeft'`, `'fabAlignment: topRight is Alignment.topRight'`.
    - **REFACTOR**: extract the outcome-to-color table into a `const Map<ApiTraceOutcome, Color>` if the switch is verbose.
  - **Acceptance**:
    - All scenarios pass.
    - `outcomeColor(success) == Colors.green.shade600` and `outcomeColor(error) == Colors.red.shade600` (per the design's resolved Q5).
    - `dart analyze` clean.
  - **Workload estimate**: ~85 lines.

- [ ] **TASK-019: Implement `ApiTraceFab` widget (REQ-UI-003, REQ-UI-004)**
  - **What**: Create `lib/src/overlay/fab.dart` with `ApiTraceFab({Key? key, required VoidCallback onPressed, required ApiTraceConfig config, required int recordCount})` (or similar). The widget renders a 40-px circular `FloatingActionButton` with `Icons.developer_mode`, positioned per `fabAlignment(config.overlayPosition)`, and the label shape per `config.overlayLabel` (icon-only / badge with count / chip with text).
  - **Why**: REQ-UI-003 requires the configurable position; REQ-UI-004 requires the configurable label shape (icon / badge / chip).
  - **Files**: `lib/src/overlay/fab.dart`, `test/overlay_test.dart` (extend with FAB scenarios)
  - **TDD evidence contract**:
    - **RED**: `test/overlay_test.dart` `'Icon-only FAB by default'`, `'Badge FAB shows count when > 0'`, `'Badge FAB hides count when count is 0'`, `'Chip FAB shows "API N" when count > 0'`, `'FAB at bottomRight by default'`, `'FAB at topLeft after config change'`.
    - **GREEN**: implement `ApiTraceFab`.
    - **TRIANGULATE**: add `'FAB at bottomLeft'`, `'FAB at topRight'`, `'Chip FAB hides when count is 0'`.
    - **REFACTOR**: extract `_FabLabel` widget (icon / badge / chip) if the FAB `build` method exceeds 30 lines.
  - **Acceptance**:
    - All scenarios pass.
    - `find.byIcon(Icons.developer_mode)` returns exactly one match inside the FAB subtree.
    - For `overlayLabel == badge` and `recordCount == 0`, `find.text('0')` returns no matches inside the FAB subtree.
    - For `overlayLabel == badge` and `recordCount == 7`, `find.text('7')` returns one match.
    - `dart analyze` clean.
  - **Workload estimate**: ~155 lines.

- [ ] **TASK-020: Implement `TimelineRow` widget (REQ-UI-005, REQ-UI-008)**
  - **What**: Create `lib/src/overlay/timeline_row.dart` with `TimelineRow({Key? key, required ApiTraceRecord record, required VoidCallback onTap})`. The row renders the record's `name`, `method`, `statusCode` (or `—` placeholder when null), `duration`, and the outcome-tinted `Icon` (or text color). The whole row is tappable.
  - **Why**: REQ-UI-005 requires the row to display name, method, statusCode, duration; REQ-UI-008 requires the green/red outcome coloring.
  - **Files**: `lib/src/overlay/timeline_row.dart`, `test/overlay_test.dart` (extend with row scenarios)
  - **TDD evidence contract**:
    - **RED**: `test/overlay_test.dart` `'Row shows name, method, statusCode, duration'`, `'Success row is green'`, `'Error row is red'`, `'4xx and 5xx share the same red color'`.
    - **GREEN**: implement `TimelineRow` with the `outcomeColor(record.outcome)` for the icon tint.
    - **TRIANGULATE**: add `'Row handles null statusCode with placeholder'`, `'Row onTap callback fires'`.
    - **REFACTOR**: extract `_StatusBadge` widget if the row's `build` method exceeds 25 lines.
  - **Acceptance**:
    - All scenarios pass.
    - For a `success` record, the row's `Icon` color resolves to a green hue (e.g. `Colors.green.shade600`).
    - For a 4xx record, the row's `Icon` color resolves to the same red as a 5xx record (verifiable by comparing the resolved `Color`).
    - `dart analyze` clean.
  - **Workload estimate**: ~140 lines.

- [ ] **TASK-021: Implement `TimelinePanel` widget + filter chips (REQ-UI-005, REQ-UI-006)**
  - **What**: Create `lib/src/overlay/timeline_panel.dart` with `TimelinePanel({Key? key, required List<ApiTraceRecord> records, required void Function(ApiTraceRecord) onTap})`. The panel renders the list (newest first, head-to-tail per the timeline), a `TextField` for the name substring filter, and three `FilterChip`s: *All*, *Success only*, *Error only*. Filters narrow the rendered list without mutating the underlying records.
  - **Why**: REQ-UI-005 requires the chronological panel; REQ-UI-006 requires the filter chips (success-only, error-only, name substring).
  - **Files**: `lib/src/overlay/timeline_panel.dart`, `test/overlay_test.dart` (extend with panel + filter scenarios)
  - **TDD evidence contract**:
    - **RED**: `test/overlay_test.dart` `'Newest-first ordering in panel'`, `'Empty timeline shows empty state'`, `'Error-only filter'`, `'Name substring filter'`, `'Underlying timeline is not mutated by filters'`.
    - **GREEN**: implement `TimelinePanel` with local state for the active filter and the substring query.
    - **TRIANGULATE**: add `'Toggling "All" restores the full list'`, `'Substring filter is case-insensitive'`, `'Empty-state message contains a developer-friendly hint'`.
    - **REFACTOR**: extract `_FilterRow` widget if the panel's `build` method exceeds 40 lines.
  - **Acceptance**:
    - All scenarios pass.
    - Activating *Error only* with one success + one error record renders exactly one row (the error record).
    - Deactivating the filter restores the full list; the underlying `records` list passed in is unchanged (`List.unmodifiable` or `UnmodifiableListView` enforced).
    - `dart analyze` clean.
  - **Workload estimate**: ~205 lines.

- [ ] **TASK-022: Implement `ApiTraceDetailScreen` widget (REQ-UI-007)**
  - **What**: Create `lib/src/overlay/detail_screen.dart` with `ApiTraceDetailScreen({Key? key, required ApiTraceRecord record})` (a `StatelessWidget` designed to be pushed via `Navigator.of(context).push(MaterialPageRoute(builder: (_) => ApiTraceDetailScreen(record: record)))` — per resolved Q3, the route is `MaterialPageRoute`). The screen renders every captured field in a `ListView`: name, method, url, statusCode, duration, startedAt, completedAt, captured details, request (if not null), response (if not null), error (if not null), extra. There are no action buttons (no "Copy as cURL", no "Re-run", no "Export" — per REQ-UI-007 out-of-scope).
  - **Why**: REQ-UI-007 requires the tap-to-detail read-only screen.
  - **Files**: `lib/src/overlay/detail_screen.dart`, `test/overlay_test.dart` (extend with detail scenarios)
  - **TDD evidence contract**:
    - **RED**: `test/overlay_test.dart` `'Detail screen shows captured fields'`, `'No button labelled "Copy as cURL"'`, `'No button labelled "Re-run"'`, `'No button labelled "Export"'`.
    - **GREEN**: implement `ApiTraceDetailScreen`.
    - **TRIANGULATE**: add `'Detail screen renders null body gracefully (no crash)'`, `'Detail screen renders error field when error is non-null'`.
    - **REFACTOR**: extract `_DetailSection` widget if the screen's `build` method exceeds 50 lines.
  - **Acceptance**:
    - All scenarios pass.
    - `find.text('Copy as cURL')`, `find.text('Re-run')`, and `find.text('Export')` all return no matches.
    - For a record captured at `{headers, response}`, the detail screen shows the request headers and the response body.
    - `dart analyze` clean.
  - **Workload estimate**: ~175 lines.

- [ ] **TASK-023: Implement `ApiTraceOverlay` widget (REQ-UI-001, REQ-UI-002, REQ-UI-005)**
  - **What**: Create `lib/src/overlay/api_trace_overlay.dart` with `class ApiTraceOverlay extends StatelessWidget`. The widget's `build` method first short-circuits to `SizedBox.shrink()` when `!kDebugMode` (REQ-UI-001); otherwise it renders a `Stack` containing a `Positioned.fill` of an `ApiTraceFab` (positioned via `Align(alignment: fabAlignment(config.overlayPosition))`) and a `TimelinePanel` shown when the FAB is tapped. The panel pushes the detail screen via `Navigator.of(context).push(MaterialPageRoute(...))`.
  - **Why**: REQ-UI-001 requires the `kDebugMode` guard; REQ-UI-002 requires the auto-mount in the overlay stack; REQ-UI-005 is exercised end-to-end by this widget.
  - **Files**: `lib/src/overlay/api_trace_overlay.dart`, `test/overlay_test.dart` (extend with overlay scenarios)
  - **TDD evidence contract**:
    - **RED**: `test/overlay_test.dart` `'Overlay widget absent under kReleaseMode'`, `'Overlay present under kDebugMode'`, `'Overlay absent when ApiTrace.enabled is false'`.
    - **GREEN**: implement `ApiTraceOverlay` with the `kDebugMode` guard and the FAB + panel composition.
    - **TRIANGULATE**: add `'Tapping FAB opens the panel'`, `'Tapping a row pushes the detail screen'`, `'Tapping the FAB again closes the panel'`.
    - **REFACTOR**: extract `_OpenCloseNotifier` if the open/closed state requires ValueListenable plumbing.
  - **Acceptance**:
    - All scenarios pass.
    - Under `kReleaseMode = true` (set via the test's `setUp`), `find.byType(ApiTraceOverlay)` returns no matches and `find.byType(FloatingActionButton)` returns no matches.
    - Under `kDebugMode = true` and `ApiTrace.enabled == true`, `find.byType(ApiTraceOverlay)` returns exactly one match.
    - `dart analyze` clean.
  - **Workload estimate**: ~165 lines.

- [ ] **TASK-024: Implement `ApiTraceBootstrap` widget + `ApiTrace.runApp` + `showOverlay` / `hideOverlay` (REQ-UI-001, REQ-UI-002, REQ-UI-005)**
  - **What**: Create `lib/src/bootstrap.dart` with `class ApiTraceBootstrap extends StatelessWidget`. The widget's `build` method short-circuits to `child` when `!kDebugMode`; otherwise it wraps `child` with an `Overlay` insertion of `ApiTraceOverlay`. Extend `ApiTrace` in `lib/src/api_trace.dart` with `static void runApp(Widget app)` (which in release calls `WidgetsFlutterBinding.ensureInitialized(); runApp(app);` and in debug wraps `app` in `ApiTraceBootstrap`), plus `static void showOverlay(BuildContext context)` and `static void hideOverlay(BuildContext context)` for programmatic overlay control.
  - **Why**: REQ-UI-001 requires the release-mode pass-through; REQ-UI-002 requires the one-line auto-mount.
  - **Files**: `lib/src/bootstrap.dart`, `lib/src/api_trace.dart` (extend with `runApp`, `showOverlay`, `hideOverlay`), `test/bootstrap_test.dart`
  - **TDD evidence contract**:
    - **RED**: `test/bootstrap_test.dart` `'Release-mode pass-through is identity'`, `'Debug-mode mounts exactly one ApiTraceOverlay'`, `'Mount point is above the developer Scaffold body'`, `'showOverlay programmatically opens the panel'`, `'hideOverlay programmatically closes the panel'`.
    - **GREEN**: implement `ApiTraceBootstrap` and the three static methods on `ApiTrace`.
    - **TRIANGULATE**: add `'ApiTrace.runApp in release does not construct ApiTraceBootstrap'`, `'ApiTrace.runApp in debug wraps with ApiTraceBootstrap'`.
    - **REFACTOR**: extract `_mountOverlay` private helper in `api_trace.dart` if `runApp` exceeds 15 lines.
  - **Acceptance**:
    - All five scenarios pass.
    - Under `kReleaseMode = true`, the widget tree produced by `ApiTrace.runApp(MaterialApp(home: ...))` is bit-identical to `runApp(MaterialApp(home: ...))` (asserted by traversing the tree and confirming no `ApiTraceBootstrap` / `ApiTraceOverlay` nodes exist).
    - `dart analyze` clean.
  - **Workload estimate**: ~170 lines.

- [ ] **TASK-025: Consolidate `test/overlay_test.dart` for all REQ-UI-001..008 scenarios**
  - **What**: Final pass on `test/overlay_test.dart`: ensure every REQ-UI scenario is covered (some are introduced in TASK-018..024; this task closes the loop with a final `group` that exercises the full overlay end-to-end). Add a `setUp` that resets `ApiTrace.timeline` via `clear()` and resets `ApiTrace.enabled` to `kDebugMode`.
  - **Why**: A single consolidated widget test file maps 1:1 to the 8 REQ-UI requirements and 17 scenarios, making `sdd-verify` straightforward.
  - **Files**: `test/overlay_test.dart` (final pass; no new production files)
  - **TDD evidence contract**:
    - **RED**: any scenario not yet covered by TASK-018..024.
    - **GREEN**: add the missing tests.
    - **TRIANGULATE**: add an end-to-end "developer flow" test: `ApiTrace.runApp(MaterialApp(...))` → call `ApiTrace.call(...)` → tap FAB → tap row → assert detail screen is on top.
    - **REFACTOR**: extract a `_pumpAppWithOverlay(WidgetTester tester, {ApiTraceConfig? config})` test helper if the file exceeds 250 lines.
  - **Acceptance**:
    - `flutter test test/overlay_test.dart` passes all 17 spec scenarios plus triangulation.
    - `dart analyze` clean.
  - **Workload estimate**: ~120 lines (additions / refactor of the existing test file).

---

## Phase E — Example app

These tasks create the `example/` app that proves the package works
end-to-end and is the substrate for the debug-build / release-build
smoke tests.

- [ ] **TASK-026: Create `example/pubspec.yaml`**
  - **What**: Add the example app's manifest. It depends on `flutter` and the local `flutter_api_inspector` package via `path:`.
  - **Why**: Per `openspec/AGENTS.md` rule 10, the example app is part of the official pub.dev package layout. The local-path dependency is the standard pattern for in-repo examples.
  - **Files**: `example/pubspec.yaml`
  - **Contents**:
    - `name: flutter_api_inspector_example`
    - `description: Example app for the flutter_api_inspector package.`
    - `publish_to: 'none'`
    - `environment: { sdk: ">=3.2.0 <4.0.0", flutter: ">=3.16.0" }`
    - `dependencies: { flutter: { sdk: flutter }, flutter_api_inspector: { path: ../ } }`
  - **Acceptance**: `flutter pub get` against `example/` resolves the local package without errors.
  - **Workload estimate**: ~20 lines.

- [ ] **TASK-027: Create `example/lib/main.dart` (stub + one real call)**
  - **What**: Implement a minimal `MaterialApp(home: ...)` example with two buttons: **"Run stub call"** (synchronous, returns a fake `ApiTraceResponse` with `statusCode == 200`) and **"Run real call to httpbin"** (one real call to `https://httpbin.org/get` using `dart:io`'s `HttpClient` — *no* `package:http`, no `package:dio`). The example wraps `runApp` with `ApiTrace.runApp` so the overlay mounts automatically.
  - **Why**: Per the proposal's locked answer to Q7, the example app exercises a stub (offline reliability) and one real call (smoke testing against a public test API).
  - **Files**: `example/lib/main.dart`
  - **Contents**:
    - `void main() => ApiTrace.runApp(const ExampleApp());`
    - `ExampleApp` is a `MaterialApp` with a home `Scaffold` containing two `ElevatedButton`s.
    - **Stub** button: `await ApiTrace.call(name: 'stub', method: 'GET', url: Uri.parse('https://example.com/stub'), execute: () async => ApiTraceResponse(statusCode: 200));`
    - **Real** button: `await ApiTrace.call(name: 'httpbin.get', method: 'GET', url: Uri.parse('https://httpbin.org/get'), execute: () async { final req = await HttpClient().getUrl(Uri.parse('https://httpbin.org/get')); final resp = await req.close(); await resp.drain(); return ApiTraceResponse(statusCode: resp.statusCode, responseBody: 'ok'); });`
    - The example uses `kDebugMode` to gate the **Real** button (hidden in release builds) to keep the example deterministic.
  - **TDD evidence contract**: not strictly TDD for the example (no `flutter_test` target for `example/`), but `flutter analyze` and `dart format` must be clean, and the apply phase must run the example in a debug build to manually confirm the overlay appears.
  - **Acceptance**:
    - `flutter pub get` from `example/` succeeds.
    - `flutter analyze` against `example/` is clean.
    - A debug build of the example shows the FAB after a stub call.
  - **Workload estimate**: ~110 lines.

---

## Phase F — Acceptance evidence

These tasks are not "implementation" — they are the acceptance gates
that the proposal, the spec, and `openspec/AGENTS.md` rule 4 require.
They produce the artifacts that `sdd-verify` consumes.

- [ ] **TASK-028: Record release-build smoke test in `apply-progress.md` (REQ-UI-001 out-of-band)**
  - **What**: Run `flutter build apk --release` (or `flutter build ios --release --no-codesign` on macOS) against the example, with and without the `flutter_api_inspector` dependency, and record: (a) the binary size delta (target ≤ 5 KB per proposal success metric #3), (b) the absence of the `ApiTraceOverlay` string in the release symbol table (`strings build/app/outputs/flutter-apk/app-release.apk | grep ApiTraceOverlay` returns nothing), and (c) the absence of `ApiTraceFab` / `ApiTraceOverlay` in the release widget tree (verified by an integration-style debug that imports the example and inspects the tree). Record the actual command, exit code, and output in `apply-progress.md`.
  - **Why**: REQ-UI-001 requires the release-mode tree-shake; the proposal's success metric #3 requires the binary size delta. The `flutter test` widget test in TASK-023 covers the in-process `kReleaseMode` simulation, but the actual `flutter build --release` is out-of-band.
  - **Files**: `openspec/changes/flutter_api_inspector-mvp/apply-progress.md` (append a *Release-build smoke test* section)
  - **TDD evidence contract**: not applicable (this is a smoke test, not a unit test). The evidence is the recorded command + output.
  - **Acceptance**:
    - The binary size delta is ≤ 5 KB.
    - The `ApiTraceOverlay` string is absent from the release symbol table.
    - The recorded output is committed to `apply-progress.md`.
    - If the host does **not** have an Android SDK or Xcode toolchain, this task is **deferred** to a follow-up environment; the deferred status is recorded in `apply-progress.md` and the open question #8 is escalated to `sdd-verify`.
  - **Workload estimate**: ~50 lines of recorded output.

- [ ] **TASK-029: Finalize TDD evidence table in `apply-progress.md`**
  - **What**: For each of TASK-001..027, ensure `apply-progress.md` has a row in a *TDD Cycle Evidence* table with: task id, REQ(s), RED command + result, GREEN command + result, TRIANGULATE command + result, REFACTOR command + result. The table is the proof that strict TDD was followed end-to-end.
  - **Why**: Per `openspec/AGENTS.md` rule 4 and `openspec/config.yaml` → `strict_tdd: true`, every shipped behavior must have RED → GREEN → TRIANGULATE → REFACTOR evidence.
  - **Files**: `openspec/changes/flutter_api_inspector-mvp/apply-progress.md` (consolidate the per-task evidence)
  - **TDD evidence contract**: not applicable (this task IS the evidence). The table's presence is the contract.
  - **Acceptance**:
    - The table has one row per TASK-001..027 (TASK-028..030 are out-of-band and excluded from the strict-TDD gate).
    - Every RED row shows a `flutter test` failure (or `dart analyze` failure for non-behavior tasks) before the corresponding GREEN row.
    - Every REQ-* from the three spec files is referenced in at least one row.
  - **Workload estimate**: ~80 lines of table.

- [ ] **TASK-030: Write `verify-report.md` final pass + success metrics 1-5**
  - **What**: After TASK-001..029 are complete, run the full quality suite (`flutter test`, `dart analyze`, `dart format --set-exit-if-changed .`, `flutter test --coverage`) and record the results in `openspec/changes/flutter_api_inspector-mvp/verify-report.md`. Validate each of the five proposal success metrics: (1) time-to-first-trace ≤ 2 min via the example app, (2) install size delta ≤ 30 KB via `du -sh lib/`, (3) zero release-build impact (depends on TASK-028), (4) strict TDD evidence (depends on TASK-029), (5) privacy-conscious default (already covered by TASK-010's contract test).
  - **Why**: `sdd-verify` consumes `verify-report.md` to decide whether to green-light `sdd-sync` and `sdd-archive`. The five success metrics are the proposal's acceptance criteria.
  - **Files**: `openspec/changes/flutter_api_inspector-mvp/verify-report.md`
  - **TDD evidence contract**: not applicable (this is the verification gate).
  - **Acceptance**:
    - `verify-report.md` is green with no CRITICAL or BLOCKED items.
    - All five success metrics have a recorded pass/fail status.
    - If the release-build smoke test (success metric #3) is deferred, the deferral is recorded with a follow-up action.
  - **Workload estimate**: ~50 lines.

---

## REQ-to-task coverage table

Every requirement from the three spec files is covered by at least one
TASK. The mapping below is the single source of truth for the
`apply-progress.md` → `verify-report.md` traceability chain.

| REQ | Task(s) | Test name(s) |
| --- | --- | --- |
| **REQ-API-001** (async call signature) | TASK-014 | `test/api_trace_test.dart` `'Execute callback awaited once'`, `'Recorded response matches execute return value'` |
| **REQ-API-002** (master switch short-circuits) | TASK-015 | `test/api_trace_test.dart` `'Disabled call returns null'`, `'Disabled call never invokes execute'` |
| **REQ-API-003** (overlay position/label enums) | TASK-013, TASK-018, TASK-019, TASK-025 | `test/config_test.dart` scenarios for *Default overlay position is bottom-right*, *Default overlay label is icon*, *overlayPosition enum has exactly four values*, *overlayLabel enum has exactly three values*; `test/overlay_test.dart` FAB-position scenarios |
| **REQ-API-004** (default detail set = {minimal}) | TASK-006, TASK-013, TASK-025 | `test/config_test.dart` *Default config details contain only minimal*, *Default config timeline capacity is 200*, *Default config max response body bytes is 4 KB*; `test/detail_test.dart` enum shape |
| **REQ-API-005** (per-call detailOverride widens) | TASK-016, TASK-025 | `test/api_trace_test.dart` *Per-call override unions with global*, *Per-call override does not mutate global config*, *Null override uses global* |
| **REQ-API-006** (enabled defaults to kDebugMode) | TASK-015 | `test/api_trace_test.dart` *enabled is true at first read in debug* |
| **REQ-API-007** (error capture: thrown + 4xx + 5xx) | TASK-017, TASK-025 | `test/api_trace_test.dart` *Thrown exception captured as error*, *4xx response captured as error*, *5xx response captured as error*, *2xx response captured as success* |
| **REQ-API-008** (returned id is record's id) | TASK-014 | `test/api_trace_test.dart` *Returned id matches recorded record* |
| **REQ-API-009** (reentrancy preserves records) | TASK-017, TASK-025 | `test/api_trace_test.dart` *Reentrant call produces two distinct records* |
| **REQ-UI-001** (kDebugMode guard placement) | TASK-023, TASK-024, TASK-025, TASK-028 | `test/overlay_test.dart` *Overlay widget absent under kReleaseMode*; TASK-028 records the out-of-band `flutter build --release` symbol check |
| **REQ-UI-002** (auto-mount in WidgetsApp overlay) | TASK-023, TASK-024, TASK-025, TASK-026 | `test/overlay_test.dart` *Overlay present under kDebugMode*, *Overlay absent when ApiTrace.enabled is false*; `test/bootstrap_test.dart` *Debug-mode mounts exactly one ApiTraceOverlay* |
| **REQ-UI-003** (configurable FAB position) | TASK-018, TASK-019, TASK-025 | `test/overlay_test.dart` *FAB at bottomRight by default*, *FAB at topLeft after config change* |
| **REQ-UI-004** (configurable FAB label) | TASK-019, TASK-025 | `test/overlay_test.dart` *Icon-only FAB by default*, *Badge FAB shows count when > 0*, *Badge FAB hides count when count is 0* |
| **REQ-UI-005** (panel renders chronological timeline) | TASK-020, TASK-021, TASK-023, TASK-025 | `test/overlay_test.dart` *Newest-first ordering*, *Empty timeline shows empty state* |
| **REQ-UI-006** (filter chips narrow the view) | TASK-021, TASK-025 | `test/overlay_test.dart` *Error-only filter*, *Name substring filter*, *Underlying timeline is not mutated by filters* |
| **REQ-UI-007** (tap-to-detail read-only) | TASK-022, TASK-025 | `test/overlay_test.dart` *Detail screen shows captured fields* (and the no-Copy-as-cURL / no-Re-run / no-Export assertions) |
| **REQ-UI-008** (error red / success green) | TASK-018, TASK-020, TASK-025 | `test/overlay_test.dart` *Success row is green*, *Error row is red*, *4xx and 5xx share the same red color* |
| **REQ-MODEL-001** (ApiTraceRecord schema) | TASK-009, TASK-010 | `test/api_trace_record_test.dart` *Record exposes all required fields with correct types*, *Record fields are immutable* |
| **REQ-MODEL-002** (ApiTraceOutcome enum) | TASK-007 | `test/outcome_test.dart` *Enum has exactly three cases* |
| **REQ-MODEL-003** (ring buffer capacity) | TASK-012 | `test/timeline_test.dart` *Default capacity holds exactly 200 records*, *Oldest record evicted when capacity is exceeded*, *Capacity honored when configured explicitly* |
| **REQ-MODEL-004** (newest-first ordering) | TASK-012 | `test/timeline_test.dart` *Newest record first*, *Insertion order breaks tie on identical start time* |
| **REQ-MODEL-005** (privacy-conscious default) | TASK-010 | `test/api_trace_record_test.dart` *Minimal capture has no body or headers*, *Headers-only capture includes headers but not bodies* |
| **REQ-MODEL-006** (response body truncation) | TASK-011 | `test/body_codec_test.dart` *Response body truncated to default 4 KB*, *Response body truncation honors configured limit* |
| **REQ-MODEL-007** (reentrancy preserves records) | TASK-012, TASK-017 | `test/timeline_test.dart` *Two concurrent calls each produce a record*; `test/api_trace_test.dart` *Reentrant call produces two distinct records* |
| **REQ-MODEL-008** (in-memory only) | TASK-012 | `test/timeline_test.dart` *Timeline resets across process restart* |

**Coverage check**: 25 REQs in the spec, 25 REQs mapped above. Every
REQ has at least one TASK that produces the named test. No REQ is
uncovered.

---

## Required git handoff (parent orchestrator action)

This executor has no shell access (consistent with the `sdd-init`,
`sdd-proposal`, `sdd-spec`, and `sdd-design` phases). The parent
orchestrator must perform the following before `sdd-apply` starts:

```bash
cd "C:/Users/Maxim/Desktop/MaxsDev/flutter_api_inspector"

# 1. Confirm the tasks file is present and untracked
ls openspec/changes/flutter_api_inspector-mvp/tasks.md

# 2. Confirm the working branch
git branch --show-current
# expected: change/flutter_api_inspector-mvp

# 3. Stage the tasks file
git add openspec/changes/flutter_api_inspector-mvp/tasks.md

# 4. Commit with the Pi harness identity (NOT the user's personal git config)
git -c user.name="el Gentleman" \
    -c user.email="el-gentleman@pi-harness.local" \
    commit -m "docs(sdd): break design into implementation tasks for flutter_api_inspector-mvp

30 ordered implementation tasks grouped into 6 phases (package
skeleton, model layer, instrumentation API, overlay UI, example app,
acceptance evidence), each with What / Why (REQ citations) / Files /
TDD evidence contract / Acceptance / Workload estimate.

Strict TDD: every task that ships behavior records RED -> GREEN ->
TRIANGULATE -> REFACTOR in apply-progress.md (per AGENTS.md rule 4
and openspec/config.yaml strict_tdd: true). The 25 REQ-* items in
the three spec files are mapped 1:1 to TASK-* items in the
REQ-to-task coverage table; the 52 spec scenarios are mapped to
named test cases.

Review workload forecast: ~2,900 changed lines (range 2,600-3,200).
400-line budget risk: High. Chained PRs recommended: Yes. Chain
strategy: pending (parent to pick stacked-to-main vs
feature-branch-chain vs size-exception). Suggested split: PR 1 =
skeleton + model, PR 2 = instrumentation API, PR 3 = overlay UI,
PR 4 = example + acceptance.

Eight open implementation questions from the design are resolved
with documented defaults (FAB icon = Icons.developer_mode, body
parser = no parse, detail route = MaterialPageRoute, FAB always
visible, theme = ThemeData with fixed outcome colors, id = Random.
secure().nextBytes(16), ApiTraceScaffold not reserved). The
release-build smoke test environment is surfaced to the user.

Refs: openspec/AGENTS.md rules 4, 6, 7, 10; openspec/config.yaml
strict_tdd, stack.minimum_runtime, testing.runner; design.md
File-by-file map, Testability section, and 8 Open technical
questions; specs/{instrumentation-api,overlay-ui,timeline-model}.md."
```

After this commit, the branch `change/flutter_api_inspector-mvp` is
ready for `sdd-apply` to begin TASK-001, subject to the parent's
delivery decision (chained PR split, chain strategy).

---

## Result Contract

```yaml
status: complete
executive_summary: >-
  SDD tasks written for flutter_api_inspector-mvp: 30 ordered
  implementation tasks grouped into 6 phases (A package skeleton,
  B model layer, C instrumentation API, D overlay UI, E example app,
  F acceptance evidence). Every task that ships behavior is bound
  to a RED -> GREEN -> TRIANGULATE -> REFACTOR cycle recorded in
  apply-progress.md. The 25 REQ-* items and 52 scenarios from the
  three spec files are mapped 1:1 to the 30 tasks; the REQ-to-task
  coverage table is the traceability chain from spec to test. The
  review workload forecast totals ~2,900 changed lines (range
  2,600-3,200) which is ~7x over the 400-line review budget;
  chained PRs are recommended in 4 work units (skeleton+model,
  API, overlay, example+acceptance) and the chain strategy is
  pending user decision. Eight open technical questions from the
  design are resolved with documented defaults (FAB icon,
  body-parser strategy, detail-screen route shape, FAB visibility
  for zero records, theme handling, id generation, ApiTraceScaffold
  naming); one question (release-build smoke test environment) is
  surfaced to the user because it depends on host SDK availability.
  Git commit of tasks.md is pending the parent orchestrator (this
  executor has no shell).
artifacts:
  - openspec/changes/flutter_api_inspector-mvp/tasks.md
next_recommended: sdd-apply # after parent delivery decision and git commit
risks:
  - "Total changed lines (~2,900) is ~7x over the 400-line review
    budget. Chained PRs strongly recommended; the parent must pause
    for user delivery decision before sdd-apply starts (Decision
    needed before apply: Yes)."
  - "Chain strategy is pending. User should pick stacked-to-main,
    feature-branch-chain, or size-exception. Default recommendation
    is feature-branch-chain for a brand-new package."
  - "Open technical question #8 (release-build smoke test
    environment) is surfaced to the user. The host running
    sdd-apply and sdd-verify may not have an Android SDK or Xcode
    toolchain. TASK-028 must be deferred to a host with the right
    SDKs if local execution is not possible."
  - "Phase D's overlay widget tests (TASK-018..025) share
    test/overlay_test.dart. The sdd-apply phase must be careful to
    merge incremental test additions cleanly; a test helper
    (_pumpAppWithOverlay) is recommended."
  - "The kDebugMode tree-shake depends on Dart AOT removing
    const-false branches. This is the documented behavior of
    flutter build --release; the in-process test in TASK-023
    (kReleaseMode = true) is a simulation, not a substitute for
    TASK-028's actual build."
  - "No pubspec.yaml exists yet, so flutter pub get / flutter test
    cannot be exercised until sdd-apply starts TASK-001."
  - "The example app uses dart:io's HttpClient directly (no
    package:http) per the no-new-dependencies rule; this is a
    deliberate choice to keep the dependency graph at flutter +
    flutter_test only."
  - "Git commit of tasks.md is pending the parent orchestrator
    (this executor has no shell). The required handoff command is
    in the Required git handoff section above."
skill_resolution: paths-injected
```
