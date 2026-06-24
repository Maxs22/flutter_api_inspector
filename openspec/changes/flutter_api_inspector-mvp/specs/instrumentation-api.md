# Instrumentation API Specification

## Purpose

The `flutter_api_inspector` instrumentation API is the
developer-facing surface for capturing individual API calls. It
exposes a static `ApiTrace` class that wraps an `execute` callback,
the `ApiTraceConfig` class that controls global capture behavior,
and the `ApiTraceDetail` enum that selects which fields each call
records. The API is deliberately small: a single
`ApiTrace.call(name, ..., execute: ...)` entry point, a single
boolean master switch (`ApiTrace.enabled`), and a single global
config object. All instrumentation is explicit and manual — the
package MUST NOT install an `http.Client` wrap, a Dio interceptor,
or any global networking shim (per `openspec/AGENTS.md` rule 7).
All testable behavior in this file is verifiable with
`flutter test` against a fresh `ApiTrace` instance in
`package:flutter_test`.

## Requirements

### Requirement: REQ-API-001 — Async call signature with execute callback

The `ApiTrace.call` method MUST be an asynchronous function that
accepts a `name` parameter and a required `execute` callback of
type `Future<ApiTraceResponse> Function()`, and MUST await that
callback to obtain the response.

**TDD contract**: `flutter test` MUST record a RED → GREEN →
TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the
test(s) satisfying this requirement (per
`openspec/AGENTS.md` rule 4 and `openspec/config.yaml` →
`rules.apply.require_test_before_production_code`).

#### Scenario: Execute callback awaited once

- GIVEN a developer wraps an async call in `ApiTrace.call` with an
  `execute` callback that returns a `Future<ApiTraceResponse>`
- WHEN the developer awaits the `ApiTrace.call(...)` future
- THEN the `execute` callback has been awaited exactly once
- AND the returned `Future<String?>` resolves to a non-null record
  id that is present in the timeline

#### Scenario: Recorded response matches execute return value

- GIVEN `ApiTrace.call` is invoked with an `execute` callback that
  resolves to a specific `ApiTraceResponse` instance
- WHEN the call completes successfully
- THEN the record stored in the timeline has its `response` field
  equal (by identity) to that same `ApiTraceResponse` instance

### Requirement: REQ-API-002 — Master switch short-circuits to no-op

When `ApiTrace.enabled` is `false`, `ApiTrace.call` MUST return a
completed `Future<String?>` resolving to `null` without invoking
the `execute` callback and without appending to the timeline.

**TDD contract**: `flutter test` MUST record a RED → GREEN →
TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the
test(s) satisfying this requirement.

#### Scenario: Disabled call returns null

- GIVEN `ApiTrace.enabled` is `false`
- WHEN a developer invokes `ApiTrace.call(...)` with any
  `execute` callback
- THEN the returned `Future<String?>` resolves to `null`
- AND the timeline size is unchanged (zero growth)

#### Scenario: Disabled call never invokes execute

- GIVEN `ApiTrace.enabled` is `false`
- WHEN a developer invokes `ApiTrace.call(...)` with an
  `execute` callback that would throw
- THEN the `execute` callback is never invoked
- AND no exception escapes; the future still resolves to `null`

### Requirement: REQ-API-003 — Configurable overlay position and label

`ApiTraceConfig` MUST expose `overlayPosition` and `overlayLabel`
fields, each with a fixed enum, that control where and how the
floating action button renders in the overlay. Defaults MUST be
`overlayPosition = ApiTraceOverlayPosition.bottomRight` and
`overlayLabel = ApiTraceOverlayLabel.icon` (icon-only FAB, no
badge) — these are the locked answers to the proposal's open
question #3.

**TDD contract**: `flutter test` MUST record a RED → GREEN →
TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the
test(s) satisfying this requirement.

#### Scenario: Default overlay position is bottom-right

- GIVEN a fresh `ApiTraceConfig()` with no arguments
- WHEN the config is read
- THEN `config.overlayPosition == ApiTraceOverlayPosition.bottomRight`

#### Scenario: Default overlay label is icon

- GIVEN a fresh `ApiTraceConfig()` with no arguments
- WHEN the config is read
- THEN `config.overlayLabel == ApiTraceOverlayLabel.icon`

#### Scenario: overlayPosition enum has exactly four values

- GIVEN the `ApiTraceOverlayPosition` type
- WHEN the values are enumerated
- THEN the set equals
  `{bottomRight, bottomLeft, topRight, topLeft}`

#### Scenario: overlayLabel enum has exactly three values

- GIVEN the `ApiTraceOverlayLabel` type
- WHEN the values are enumerated
- THEN the set equals `{icon, badge, chip}`

### Requirement: REQ-API-004 — Default detail set is minimal only

`ApiTraceConfig.details` MUST default to the singleton
`{ApiTraceDetail.minimal}`. With this default, a recorded call
MUST contain no request body, no response body, and no headers
(per the locked "privacy-conscious default" product decision).

**TDD contract**: `flutter test` MUST record a RED → GREEN →
TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the
test(s) satisfying this requirement.

#### Scenario: Default config details contain only minimal

- GIVEN a fresh `ApiTraceConfig()` with no arguments
- WHEN the config is read
- THEN `config.details == {ApiTraceDetail.minimal}`

#### Scenario: Default config timeline capacity is 200

- GIVEN a fresh `ApiTraceConfig()` with no arguments
- WHEN the config is read
- THEN `config.timelineCapacity == 200`

#### Scenario: Default config max response body bytes is 4 KB

- GIVEN a fresh `ApiTraceConfig()` with no arguments
- WHEN the config is read
- THEN `config.maxResponseBodyBytes == 4 * 1024`

### Requirement: REQ-API-005 — Per-call detail override widens capture

A non-null `detailOverride` parameter on `ApiTrace.call` MUST
widen the captured detail set for that single call only. The
effective detail set for the call MUST be the union of the
global config's `details` and the `detailOverride`. Other calls
in the same timeline MUST continue to use the global config only.
A null `detailOverride` MUST use the global config unchanged.

**TDD contract**: `flutter test` MUST record a RED → GREEN →
TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the
test(s) satisfying this requirement.

#### Scenario: Per-call override unions with global

- GIVEN `ApiTrace.config.details == {ApiTraceDetail.minimal}` and
  a call is made with
  `detailOverride: {ApiTraceDetail.response}`
- WHEN the call completes
- THEN the record's `capturedDetails` equals
  `{ApiTraceDetail.minimal, ApiTraceDetail.response}`
- AND the record's `response.responseBody` is non-null

#### Scenario: Per-call override does not mutate global config

- GIVEN `ApiTrace.config.details == {ApiTraceDetail.minimal}` and
  a call is made with
  `detailOverride: {ApiTraceDetail.response}`
- WHEN the call completes
- THEN `ApiTrace.config.details` is unchanged and still equals
  `{ApiTraceDetail.minimal}`

#### Scenario: Null override uses global

- GIVEN `ApiTrace.config.details == {ApiTraceDetail.minimal}` and
  a call is made with `detailOverride: null`
- WHEN the call completes
- THEN the record's `capturedDetails` equals
  `{ApiTraceDetail.minimal}` only
- AND the record's `response` has no body and no headers

### Requirement: REQ-API-006 — enabled defaults to kDebugMode at first read

`ApiTrace.enabled` MUST be initialized to `kDebugMode` on its
first read and remain mutable thereafter (locked answer to open
question #6: `kDebugMode` at first read).

**TDD contract**: `flutter test` MUST record a RED → GREEN →
TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the
test(s) satisfying this requirement.

#### Scenario: enabled is true at first read in debug

- GIVEN a fresh `ApiTrace` instance loaded under `kDebugMode ==
  true` (the default for `flutter test`)
- WHEN `ApiTrace.enabled` is read before any explicit assignment
- THEN the value equals `true`
- AND the value remains mutable (assigning `false` is observed
  by a subsequent read)

### Requirement: REQ-API-007 — Error capture for thrown exceptions and 4xx/5xx

`ApiTrace.call` MUST capture any exception thrown by the
`execute` callback as an `ApiTraceOutcome.error` record. A
response with a status code in the 4xx or 5xx range MUST ALSO
be recorded as `ApiTraceOutcome.error`. A response with a status
code in the 1xx, 2xx, or 3xx range MUST be recorded as
`ApiTraceOutcome.success`. Both thrown exceptions and 4xx/5xx
responses render the same red color in the UI (locked answer to
open question #4: 4xx and 5xx are not visually distinct).

**TDD contract**: `flutter test` MUST record a RED → GREEN →
TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the
test(s) satisfying this requirement.

#### Scenario: Thrown exception captured as error

- GIVEN an `execute` callback that throws `FormatException`
- WHEN a developer awaits `ApiTrace.call(...)`
- THEN the returned `Future<String?>` resolves to a non-null id
- AND the record's `outcome == ApiTraceOutcome.error`
- AND the record's `error` field captures the thrown object

#### Scenario: 4xx response captured as error

- GIVEN an `execute` callback that resolves to a response with
  `statusCode = 404`
- WHEN a developer awaits `ApiTrace.call(...)`
- THEN the record's `outcome == ApiTraceOutcome.error`
- AND the record's `response.statusCode == 404`

#### Scenario: 5xx response captured as error

- GIVEN an `execute` callback that resolves to a response with
  `statusCode = 503`
- WHEN a developer awaits `ApiTrace.call(...)`
- THEN the record's `outcome == ApiTraceOutcome.error`
- AND the record's `response.statusCode == 503`

#### Scenario: 2xx response captured as success

- GIVEN an `execute` callback that resolves to a response with
  `statusCode = 200`
- WHEN a developer awaits `ApiTrace.call(...)`
- THEN the record's `outcome == ApiTraceOutcome.success`
- AND the record's `error` is null

### Requirement: REQ-API-008 — Returned id is the record's id

When `ApiTrace.call` completes successfully, the value returned
by the awaited future MUST equal the id of the newly recorded
`ApiTraceRecord` in the timeline.

**TDD contract**: `flutter test` MUST record a RED → GREEN →
TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the
test(s) satisfying this requirement.

#### Scenario: Returned id matches recorded record

- GIVEN a successful `ApiTrace.call(...)` invocation
- WHEN the developer awaits the returned `Future<String?>`
- THEN the resolved value is a non-null `String`
- AND that string equals the `id` of the last record appended
  to the timeline

### Requirement: REQ-API-009 — Reentrancy preserves record ordering

Two `ApiTrace.call` invocations that overlap in time (for
example, the `execute` callback of the first triggers a second
`ApiTrace.call` before the first resolves) MUST each produce
exactly one record in the timeline, and the timeline MUST
contain both records with distinct ids.

**TDD contract**: `flutter test` MUST record a RED → GREEN →
TRIANGULATE → REFACTOR sequence in `apply-progress.md` for the
test(s) satisfying this requirement.

#### Scenario: Reentrant call produces two distinct records

- GIVEN the outer `execute` callback awaits a second
  `ApiTrace.call(...)` invocation before returning
- WHEN both calls resolve
- THEN the timeline contains exactly two new records
- AND the outer call's id is distinct from the inner call's id
- AND both records have their own `duration` and `outcome` set

## Out of scope

- A sync (non-async) `ApiTrace.call` variant.
- A `finish(id, ...)` companion method.
- A `package:dio` interceptor or `http.Client` wrap.
- A custom user-supplied id generation (id is generated by the
  package, not the caller).
- A `print` / `developer.log` fallback for non-Flutter contexts.
- A `ApiTraceScaffold` widget (documented escape hatch only, not
  part of the v1 contract — see `proposal.md`).
- A `package:uuid` dependency (use `Random.secure()` or a small
  inline generator per `proposal.md` acceptance criteria).
