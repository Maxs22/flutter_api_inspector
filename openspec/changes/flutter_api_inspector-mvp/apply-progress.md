# Apply Progress — flutter_api_inspector-mvp (PR 1 of 4)

- **Change**: `flutter_api_inspector-mvp`
- **PR**: 1 of 4 (skeleton + model)
- **Branch**: `change/01-skeleton-model`
- **Started**: 2026-06-23
- **Strict TDD**: enforced (RED → GREEN → TRIANGULATE → REFACTOR for every behavior-shipping task)
- **Status**: in-progress

## Scope of this PR

- TASK-001..005 — Package skeleton (pubspec, lint, docs, barrel, baseline)
- TASK-006..012 — Model layer (enums, id, request/response, record, body codec, timeline)
- Out of scope: TASK-013..030 (instrumentation API, overlay UI, example app, acceptance evidence)

## Smoke-test deferral note

The release-build smoke test (REQ-UI-001, success metric #3, TASK-028) is part of
PR 4 (`change/04-example-and-acceptance`). It is deferred to a CI runner with the
Android SDK / Xcode toolchain (this Windows host does not have the full toolchain).
PR 1 does NOT attempt `flutter build --release`. The deferral is recorded here so
the PR 1 → PR 2 → PR 3 → PR 4 chain runs in the agreed order.

## Per-task evidence

Each behavior-shipping task records the RED → GREEN → TRIANGULATE → REFACTOR
cycle below.

## TASK-001: Create pubspec.yaml

- **REQ(s)**: (no spec REQ; pubspec.yaml is infrastructure per AGENTS.md rule 10)
- **Files**: pubspec.yaml
- **No TDD cycle**: pure infrastructure (no behavior to test)
- **Verification**:
  - `flutter pub get` succeeded — 26 dependencies installed
  - `flutter pub outdated` reports no blocking issues
- **Constraints respected**:
  - Dependencies: only `flutter` SDK (no `package:dio`, no `package:http`, no `package:uuid`, no `package:collection`)
  - Dev dependencies: `flutter_test` SDK + `flutter_lints ^3.0.0` (justified; official Flutter team lint ruleset; required by `analysis_options.yaml`)
  - Environment: `sdk >=3.2.0 <4.0.0`, `flutter >=3.16.0` (per `openspec/config.yaml` → `stack.minimum_runtime`)
- **Commit**: `5f9d12d` — `chore(pkg): add pubspec.yaml (TASK-001)`

## TASK-002: Create analysis_options.yaml and .gitignore

- **REQ(s)**: (no spec REQ; lint config is infrastructure)
- **Files**: analysis_options.yaml (created), .gitignore (already present from sdd-init; verified adequate)
- **No TDD cycle**: pure infrastructure
- **Verification**:
  - `dart analyze` reports "No issues found!" against the empty `lib/` and `test/`
  - `analysis_options.yaml` extends `package:flutter_lints/flutter.yaml` with: `strict-casts`, `strict-inference`, `strict-raw-types`, `prefer_final_locals`, `avoid_print`, `prefer_const_constructors`, `prefer_const_declarations`, `prefer_const_literals_to_create_immutables`, `unnecessary_late`, `unnecessary_this`, `sort_child_properties_last`, `use_super_parameters`, `unawaited_futures`, `unnecessary_null_aware_assignments`
  - `public_member_api_docs` is set to `ignore` for the MVP (per the user task's "library_names exception" — the MVP does not require doc comments on every public member)
- **Commit**: `1f850fb` — `chore(lint): add analysis_options.yaml (TASK-002)`

## TASK-003: Create README.md, CHANGELOG.md, and LICENSE (MIT)

- **REQ(s)**: (no spec REQ; pub.dev surface is infrastructure per AGENTS.md rule 10)
- **Files**: README.md, CHANGELOG.md, LICENSE
- **No TDD cycle**: pure documentation (no behavior to test)
- **Verification**:
  - `README.md` mentions `ApiTrace.call(name, …, execute: …)`, `ApiTrace.enabled`, `ApiTrace.config`, `ApiTrace.runApp`, and the `kDebugMode` tree-shake contract
  - `CHANGELOG.md` has a `## 0.1.0` section dated `2026-06-23`
  - `LICENSE` is the standard MIT text with copyright `2026, the flutter_api_inspector authors` (per the proposal's locked answer to open question #8)
- **Commit**: `8383ed0` — `docs: add README, CHANGELOG, MIT LICENSE (TASK-003)`

## TASK-006: Implement ApiTraceDetail enum (REQ-API-004)

- **REQ(s)**: REQ-API-004 (default detail set = `{minimal}`), REQ-MODEL-005 (privacy-conscious default)
- **Files**: lib/src/detail.dart, test/detail_test.dart
- **RED**: `test/detail_test.dart` `'has exactly five values'` failed to compile with `Target of URI doesn't exist: 'package:flutter_api_inspector/src/detail.dart'`. `flutter test` reported `Some tests failed.` (compile error).
- **GREEN**: declared `enum ApiTraceDetail { minimal, headers, request, response, full }` in `lib/src/detail.dart`. All three tests pass.
- **TRIANGULATE**: added `'values are minimal, headers, request, response, full (in order)'` (asserts the named order) and `'full is at index 4 and minimal is at index 0'` (asserts the index contract).
- **REFACTOR**: renamed the test cases to plain prose (removed the inline `RED:` / `TRIANGULATE:` markers from the test names); `flutter test` still green.
- **Acceptance**: 3 tests pass, `dart analyze` clean, `dart format` clean.
- **Commit**: `7083c65` — `feat(model): add ApiTraceDetail enum (TASK-006, REQ-API-004)`

## TASK-007: Implement ApiTraceOutcome enum (REQ-MODEL-002)

- **REQ(s)**: REQ-MODEL-002 (three-state outcome), REQ-UI-008 (error red / success green)
- **Files**: lib/src/outcome.dart, test/outcome_test.dart
- **RED**: `test/outcome_test.dart` `'has exactly three cases'` failed to compile with `Target of URI doesn't exist: 'package:flutter_api_inspector/src/outcome.dart'`. `flutter test` reported `Some tests failed.` (compile error).
- **GREEN**: declared `enum ApiTraceOutcome { success, error, cancelled }` in `lib/src/outcome.dart`. All three tests pass.
- **TRIANGULATE**: added `'cases are success, error, cancelled (in order)'` and `'success is at index 0 and cancelled is at index 2'`.
- **REFACTOR**: no refactor needed; the implementation is a single three-case enum.
- **Acceptance**: 3 tests pass, `dart analyze` clean, `dart format` clean.
- **Commit**: `49f0c1f` — `feat(model): add ApiTraceOutcome enum (TASK-007, REQ-MODEL-002)`

## TASK-008: Implement id.dart id generator (no package:uuid)

- **REQ(s)**: REQ-MODEL-001 (ApiTraceRecord schema), helper for `ApiTraceRecord.id`
- **Files**: lib/src/id.dart, test/id_test.dart
- **RED**: `test/id_test.dart` `'returns a non-empty string'` failed to compile with `Target of URI doesn't exist: 'package:flutter_api_inspector/src/id.dart'`. `flutter test` reported `Some tests failed.` (compile error).
- **GREEN**: declared `String generateId()` in `lib/src/id.dart` using `Random.secure()` and a manual hex encoder. All four tests pass.
- **TRIANGULATE**: added `'returns exactly 32 lowercase hex characters'` (asserts the format with a regex), `'10,000 generations produce 10,000 unique ids'` (documents the collision contract for 10k ids), and `'two consecutive calls produce different ids'` (smoke check).
- **REFACTOR**: renamed test cases to plain prose; `flutter test` still green.
- **Portability note**: avoids `Random.nextBytes` (Dart 3.6+) and `package:convert`'s `base16Lowercase` (separate dependency) to stay compatible with the package's SDK floor (`>=3.2.0`) and the zero-non-SDK-dependencies rule.
- **Acceptance**: 4 tests pass, `dart analyze` clean, `dart format` clean.
- **Commit**: `ede8eeb` — `feat(id): add generateId with Random.secure (TASK-008)`

## TASK-009: Implement ApiTraceRequest and ApiTraceResponse (REQ-MODEL-001)

- **REQ(s)**: REQ-MODEL-001 (ApiTraceRecord schema), REQ-MODEL-005 (privacy-conscious default)
- **Files**: lib/src/model/api_trace_request.dart, lib/src/model/api_trace_response.dart, test/api_trace_types_test.dart
- **RED**: `test/api_trace_types_test.dart` `'defaults to empty headers...'` failed to compile with `Target of URI doesn't exist` for both `api_trace_request.dart` and `api_trace_response.dart`. `flutter test` reported `Some tests failed.` (compile error).
- **GREEN**: declared both `final class ApiTraceRequest` and `final class ApiTraceResponse` with `const` constructors, all fields, and `copyWith` helpers. All 8 baseline tests pass.
- **TRIANGULATE**: added `'copyWith with body: null clears the body'` and `'copyWith with responseBody: null clears the response body'` to lock the sentinel pattern (`identical(_undefined, …)`) that distinguishes "argument omitted" from "argument is null" for the nullable fields. Also added `'copyWith overrides headers and preserves body'` / `'copyWith overrides body and preserves headers'` on `ApiTraceRequest`.
- **REFACTOR**: renamed test cases to plain prose; ran `dart format` (3 files changed, 1 unchanged). `flutter test` still green.
- **Implementation note**: the `copyWith` helpers use a private `const Object _undefined` sentinel + `identical(...)` checks so the privacy-conscious `fromCapture` factory in TASK-010 can set `body: null` / `responseBody: null` / `requestBody: null` explicitly without falling through to the `?? this.field` branch.
- **Acceptance**: 10 tests pass, `dart analyze` clean, `dart format` clean.
- **Commit**: `d4e7fb4` — `feat(model): add ApiTraceRequest and ApiTraceResponse (TASK-009, REQ-MODEL-001)`

## TASK-010: Implement ApiTraceRecord and fromCapture factory (REQ-MODEL-001, REQ-MODEL-005)

- **REQ(s)**: REQ-MODEL-001 (ApiTraceRecord schema), REQ-MODEL-005 (privacy-conscious default), REQ-API-007 (error capture for outcome derivation)
- **Files**: lib/src/model/api_trace_record.dart, test/api_trace_record_test.dart
- **RED**: `test/api_trace_record_test.dart` `'exposes all required fields with correct types'` failed to compile with `Target of URI doesn't exist: 'package:flutter_api_inspector/src/model/api_trace_record.dart'`. `flutter test` reported `Some tests failed.` (compile error).
- **GREEN**: declared `final class ApiTraceRecord` (immutable, all `final` fields) and the `factory ApiTraceRecord.fromCapture(...)`. The factory applies the privacy contract per the captured detail set. 16 tests pass.
- **TRIANGULATE**: added `'capturedDetails is stored unmodifiable'`, `'extra is stored unmodifiable'`, `'duration is clamped to zero when completedAt < startedAt'`, and `'response-only capture includes response body, not request, not headers'` to lock the redaction behavior for `{response}` alone and the defensive duration clamp.
- **REFACTOR**: renamed test cases to plain prose; ran `dart format` (2 files changed). `flutter test` still green.
- **Semantic decisions for the captured detail set** (locked here, recorded for the PR 2 `ApiTrace.call` and PR 3 UI to follow):
  - `{minimal}` → `request` null, `response` null, no bodies, no headers.
  - `{headers}` → `request` null, `response` kept (with `responseHeaders` and `requestHeaders` non-empty; both bodies nulled). Satisfies the REQ-MODEL-005 spec scenario `'Headers-only capture includes headers but not bodies'`.
  - `{request}` → `request` kept (with body, with headers if `headers`/`full` is also active); `response` null.
  - `{response}` → `response` kept (with `responseBody` truncated to `maxResponseBodyBytes`); `request` null. Headers empty unless `headers`/`full` is also active.
  - `{full}` → both objects kept with bodies, both header maps populated, response body truncated.
  - `headers` and `full` are the only levels that populate the header maps; `request`/`response` alone never populate headers.
- **Inline truncation note**: `fromCapture` uses a private `_truncateBody` helper for `String`, `List<int>`, and other `Object?` bodies. TASK-011 introduces `bodyCodec.truncate` and refactors this helper into a top-level function with broader contract coverage; the contract is already asserted by TASK-011's tests against the bodyCodec module.
- **Outcome derivation**: a private `_deriveOutcome({response, error})` returns `error` for thrown exceptions and 4xx/5xx status codes, `success` otherwise. `cancelled` is reserved for future use (REQ-API-007).
- **Acceptance**: 16 tests pass, `dart analyze` clean, `dart format` clean.
- **Commit**: `36cf16e` — `feat(model): add ApiTraceRecord with privacy-enforcing factory (TASK-010, REQ-MODEL-001, REQ-MODEL-005)`

## TASK-011: Implement body_codec.dart (REQ-MODEL-006)

- **REQ(s)**: REQ-MODEL-006 (response body truncation)
- **Files**: lib/src/body_codec.dart, test/body_codec_test.dart, lib/src/model/api_trace_record.dart (refactored)
- **RED**: `test/body_codec_test.dart` `'null body returns null'` failed to compile with `Target of URI doesn't exist: 'package:flutter_api_inspector/src/body_codec.dart'`. `flutter test` reported `Some tests failed.` (compile error).
- **GREEN**: declared `Object? truncate(Object? body, int maxBytes)` in `lib/src/body_codec.dart`. All 9 bodyCodec tests pass.
- **TRIANGULATE**: added `'String body of length > maxBytes is truncated to prefix'` (10 KB -> 4 KB), `'String body truncation honors configured limit'` (1024 -> 128), `'List<int> body is truncated by byte count'`, `'List<int> body of length <= maxBytes is returned unchanged'`, `'non-String non-bytes body is stringified and truncated'`, `'truncation at exactly maxBytes preserves length'` (boundary), `'zero maxBytes truncates to empty prefix'`.
- **REFACTOR (cross-task)**: refactored `ApiTraceRecord.fromCapture` (TASK-010) to call into `bodyCodec.truncate`, removing the inline `_truncateBody` helper. All 25 model-layer tests still pass.
- **Acceptance**: 25 model-layer tests pass (9 bodyCodec + 16 record), `dart analyze` clean, `dart format` clean.
- **Commit**: `e02b1ab` — `feat(codec): add bodyCodec.truncate and refactor fromCapture (TASK-011, REQ-MODEL-006)`

## TASK-012: Implement Timeline ring buffer (REQ-MODEL-003, REQ-MODEL-004, REQ-MODEL-007, REQ-MODEL-008)

- **REQ(s)**: REQ-MODEL-003 (capacity), REQ-MODEL-004 (newest-first ordering with insertion-order tie-break), REQ-MODEL-007 (reentrancy), REQ-MODEL-008 (in-memory only, resets across process restart)
- **Files**: lib/src/model/timeline.dart, test/timeline_test.dart
- **RED**: `test/timeline_test.dart` `'a fresh timeline is empty'` failed to compile with `Target of URI doesn't exist: 'package:flutter_api_inspector/src/model/timeline.dart'`. `flutter test` reported `Some tests failed.` (compile error).
- **GREEN**: declared `final class Timeline` with `int capacity`, an internal `List<ApiTraceRecord> _records`, an `UnmodifiableListView` exposed as `records`, a `ValueNotifier<String?> latest`, and the `append` / `clear` methods. The `append` method is `_records.insert(0, r); if (_records.length > capacity) _records.removeLast(); latest.value = r.id;`. 15 timeline tests pass.
- **TRIANGULATE**: added `'TRIANGULATE: default capacity holds exactly 200 records'` (asserts 200 records, head is the 200th), `'TRIANGULATE: latest ValueNotifier is set to the new record id on every append'`, `'TRIANGULATE: records is an unmodifiable view'`, `'TRIANGULATE: clear empties the timeline and resets latest'`, `'ValueListenable on latest fires once per append'`, and the smoke test `'append is a fire-and-forget call'`.
- **REFACTOR**: renamed the `'RED:'` test case to plain prose; ran `dart format` (2 files changed). `flutter test` still green — 60 model-layer tests total.
- **Reentrancy note**: append is synchronous, so two interleaved `ApiTrace.call` invocations (one awaiting `execute` while the other runs) each land in completion order. The timeline ends up with the records in completion order, which is the contract REQ-MODEL-007 asserts.
- **Acceptance**: 60 model-layer tests pass, `dart analyze` clean, `dart format` clean.
- **Commit**: `dbfab58` — `feat(timeline): add Timeline ring buffer (TASK-012, REQ-MODEL-003, REQ-MODEL-004, REQ-MODEL-007, REQ-MODEL-008)`

## TASK-004: Create lib/flutter_api_inspector.dart barrel export

- **REQ(s)**: (no spec REQ; barrel is infrastructure per AGENTS.md rule 10)
- **Files**: lib/flutter_api_inspector.dart
- **No TDD cycle**: pure infrastructure (no behavior to test)
- **Verification**:
  - `dart analyze` reports "No issues found!" with the barrel re-exporting the five PR 1 model layer types
  - `flutter test` is green — 60 model-layer tests
- **Order note**: The barrel was deferred from the original Phase A order to TASK-004 (after the model layer source files exist). The original ordering would have been forward references that broke `dart analyze` until TASK-006..012 landed. Creating the barrel last keeps the commit history bisect-clean.
- **Re-exports (PR 1)**:
  - `ApiTraceDetail` (TASK-006)
  - `ApiTraceOutcome` (TASK-007)
  - `ApiTraceRequest`, `ApiTraceResponse` (TASK-009)
  - `ApiTraceRecord` (TASK-010)
- **Internals not re-exported**: `Timeline` (TASK-012), `id` generator (TASK-008), `bodyCodec` (TASK-011).
- **Commit**: `092e91d` — `feat(barrel): add public barrel lib/flutter_api_inspector.dart (TASK-004)`
