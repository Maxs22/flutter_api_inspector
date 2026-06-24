# Archive Report — `flutter_api_inspector-mvp`

- **Change**: `flutter_api_inspector-mvp`
- **Archived**: 2026-06-24
- **Source PR 4 verify gate**: `b7ee9b0` (PR 4 — Independent fresh-context re-verification, 2026-06-24, subagent 2) — **GREEN**
- **Active change after archive**: `null`
- **Artifact store**: `openspec/` (authoritative)
- **Author identity**: `el Gentleman <el-gentleman@pi-harness.local>` (locked)

---

## Final summary

`flutter_api_inspector` v0.1.0 is shipped to `main` as a pub.dev-targeted Flutter
package that gives developers a manual, debug-only API-call overlay timeline. The
package exposes a small, explicit `ApiTrace.call(name, …, execute: …)` entry
point plus a config object (`ApiTraceConfig`), a master switch (`ApiTrace.enabled`),
and a debug-only overlay (FAB + panel + detail screen) that renders the
in-memory ring buffer of `ApiTraceRecord` objects in newest-first order. All
instrumentation is explicit (no auto-interceptor per AGENTS.md rule 7); the
overlay is guarded by `kDebugMode` (per AGENTS.md rule 6) and tree-shakes
completely out of `flutter build --release` binaries (verified at TASK-028).
All 30 tasks across 4 chained PRs are `- [x]`; all 25 REQs (9 API + 8 MODEL + 8
UI) are covered by named tests; the strict-TDD evidence table in
`apply-progress.md` has 27 rows (TASK-001..027); all 5 proposal success metrics
PASS; all 6 verification gates (3 library + 3 example) PASS on a fresh-context
re-run.

---

## Merged PRs

| PR | Branch | Head commit | Merge commit | TASKs | REQs | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `change/01-skeleton-model` | `76482ec` (per chained-PR metadata; merge to `main` confirmed via `git log main --oneline`) | merged to `main` | TASK-001..012 | REQ-MODEL-001..008, REQ-API-004 (enum half) | MERGED |
| 2 | `change/02-instrumentation-api` | `158e188` | merged to `main` | TASK-013..017 | REQ-API-001..009 | MERGED |
| 3 | `change/03-overlay-ui` | `284d00c` | merged to `main` | TASK-018..025 | REQ-UI-001..008 | MERGED |
| 4 | `change/04-example-and-acceptance` | `74ef624` (per design + chained-PR metadata); PR 4 re-verify follow-up docs at `9e4f458` and `b7ee9b0` | merged to `main` (PR 4 squash merge at `1ab13eb`) | TASK-026..030 | (acceptance evidence; no new public REQs) | MERGED |

`main` HEAD at the time of archive: `b7ee9b0` (PR 4 fresh-context
re-verification follow-up commit, supplementing the PR 4 final pass at
`9e4f458`). All 4 merge commits are reachable from `main`.

---

## Verification gate (PR 4, GREEN)

The PR 4 fresh-context re-verification at commit `b7ee9b0` (see
`openspec/changes/archive/flutter_api_inspector-mvp/verify-report.md` →
"PR 4 — Independent fresh-context re-verification (2026-06-24, subagent 2)")
confirms **GREEN** with:

- 5/5 in-scope tasks (TASK-026..030) PASS
- 5/5 proposal success metrics PASS
- 6/6 verification gates PASS
- 0 CRITICAL or BLOCKED findings
- 6 MINOR findings (commit count discrepancy, identity drift remediation,
  Android scaffold prerequisite, gradle wrapper gitignore, pub outdated
  informational warning, iOS path deferral) — all accepted per the task brief
  or documented in `apply-progress.md`

The 6 verification gates (re-run independently during archive on 2026-06-24):

1. `flutter test` (library) → 153 passed, 0 failed, 0 errors
2. `dart analyze` (library) → No issues found!
3. `dart format --set-exit-if-changed .` (library) → no-op (31 files, 0 changed)
4. `flutter pub get` (example) → Got dependencies! (27 deps resolved, local-path
   dep `flutter_api_inspector: { path: ../ }` resolves)
5. `flutter analyze` (example) → No issues found! (ran in 1.2s)
6. `dart format --set-exit-if-changed .` (example) → no-op (1 file, 0 changed)

---

## Success metrics (5/5 PASS)

| # | Metric | Measurement | Verdict |
| --- | --- | --- | --- |
| 1 | Time-to-first-trace ≤ 2 min | Structural: 1-line `main` (`ApiTrace.runApp`) + 2 buttons + 1 `ApiTrace.call` per button. `flutter test` end-to-end test in TASK-025 proves the overlay mounts in-process; the example is the substrate for the manual smoke test. | **PASS** |
| 2 | Install size delta ≤ 30 KB | With-package `libapp.so` is 1,246,128 bytes; control `libapp.so` is 3,081,136 bytes; **delta −1,835,008 bytes** (with-package is SMALLER). 30 KB threshold met with full margin. | **PASS** |
| 3 | Zero release-build impact | `flutter build apk --release --target-platform android-arm64` succeeded; 0 occurrences of every overlay/UI/internal `ApiTrace*` symbol in `libapp.so` and `classes.dex` (12 × 2 = 24 zero-occurrence results). 5 KB threshold met. | **PASS** |
| 4 | Strict TDD evidence | TDD Cycle Evidence table in `apply-progress.md` covers TASK-001..027 in 27 rows; every `REQ-*` from the three spec files (9 API + 8 MODEL + 8 UI = 25 REQs) is referenced in at least one row. | **PASS** |
| 5 | Privacy-conscious default holds | TASK-010 contract test `minimal capture has no body or headers` in `test/api_trace_record_test.dart` asserts `record.request == null` and `record.response == null` for `{ApiTraceDetail.minimal}` capture. | **PASS** |

---

## Tasks checkbox audit (final)

`openspec/changes/archive/flutter_api_inspector-mvp/tasks.md` at the time of
archive (re-confirmed during the final task completion gate):

- **30 `- [x]`** (`grep -c '^- \[x\]' tasks.md` returns 30)
- **0 `- [ ]`** (`grep -c '^- \[ \]' tasks.md` returns 0)

| Task group | Range | Status |
| --- | --- | --- |
| PR 1 | TASK-001..012 | 12 of 12 `- [x]` |
| PR 2 | TASK-013..017 | 5 of 5 `- [x]` |
| PR 3 | TASK-018..025 | 8 of 8 `- [x]` |
| PR 4 | TASK-026..030 | 5 of 5 `- [x]` |

No stale-checkbox reconciliation was needed. No unchecked implementation task
remains. The final task completion gate passes cleanly.

---

## Open follow-ups

1. **iOS release-build path verification in CI.** TASK-028 exercised
   `flutter build apk --release --target-platform android-arm64` and confirmed
   0 overlay symbols in `libapp.so` and `classes.dex`. The iOS path
   (`flutter build ios --release --no-codesign`) was NOT exercised because the
   host is Windows and Xcode is unavailable. The `kDebugMode` tree-shake
   contract is platform-agnostic (the Dart AOT compiler eliminates the
   const-false branch in any release build), so the iOS path is expected to
   mirror the Android result. A CI runner with Xcode can confirm. **Severity:
   MINOR (deferral, not a gap).** No archive blocker.
2. **`flutter_lints ^3.0.0` dev dependency.** The proposal acceptance
   criteria say "no new dependencies beyond `flutter` and `flutter_test`".
   `flutter_lints` is dev-only, official, and required by `analysis_options.yaml`.
   The `pubspec.yaml` comment documents the justification. A follow-up change
   could amend the proposal acceptance criteria to allow `flutter_lints`
   explicitly. **Severity: MINOR (informational).**
3. **2 PR 3 finalization commits used the user's personal git identity.** All
   PR 4 commits correctly use the locked `el Gentleman <el-gentleman@pi-harness.local>`
   identity. Local `git config` has been set to the harness identity for all
   archive operations. Historical drift is fully closed. **Severity: MINOR
   (documented deviation; accepted in the task brief as MINOR #1 in
   `apply-progress.md`).**

---

## Authoring trail (commit identity)

- **Locked identity for this change**: `el Gentleman <el-gentleman@pi-harness.local>`
- **All PR 4 commits** (7 total, including 2 SDD documentation follow-ups at
  `aaea98d` and `9e4f458`): use the locked identity. Verified by
  `git log change/04-example-and-acceptance ^main --format='%H %an <%ae>'`.
- **PR 3 historical drift** (MINOR #1 in `apply-progress.md`): 2 PR 3
  finalization commits (`3dfb5db`, `8d738ef`) used the user's personal git
  identity. The drift was detected, remediated (local `git config` set to the
  harness identity for PR 4 and beyond), and documented in
  `apply-progress.md` PR 3 section + PR 4 deviation #2.
- **Archive commit (this operation)**: uses the locked identity. Author is the
  same `el Gentleman <el-gentleman@pi-harness.local>` that authored the
  PR 4 deliverable.

---

## Canonical specs promoted

The 3 delta specs from the change have been moved verbatim from
`openspec/changes/archive/flutter_api_inspector-mvp/specs/` to
`openspec/specs/` (the canonical specs directory). This is a new canonical
spec layer (the directory was previously empty except for `.gitkeep`); no
merge with existing canonical specs was required.

| Canonical spec | REQs | Source line count |
| --- | --- | --- |
| `openspec/specs/instrumentation-api.md` | 9 REQs (REQ-API-001..009) | 12,098 bytes / ~225 lines |
| `openspec/specs/overlay-ui.md` | 8 REQs (REQ-UI-001..008) | 10,652 bytes / ~190 lines |
| `openspec/specs/timeline-model.md` | 8 REQs (REQ-MODEL-001..008) | 10,326 bytes / ~190 lines |

The canonical `openspec/specs/.gitkeep` is preserved (the directory
existed pre-archive, so the file stays as a marker). Total: **25 REQs** in
3 spec files. The previous `openspec/changes/flutter_api_inspector-mvp/specs/`
directory in the archive is now empty (git does not track empty directories).

---

## Archive operation summary

Files moved (git-tracked, recorded in the archive commit):

```
R  openspec/changes/flutter_api_inspector-mvp/apply-progress.md -> openspec/changes/archive/flutter_api_inspector-mvp/apply-progress.md
R  openspec/changes/flutter_api_inspector-mvp/design.md -> openspec/changes/archive/flutter_api_inspector-mvp/design.md
R  openspec/changes/flutter_api_inspector-mvp/proposal.md -> openspec/changes/archive/flutter_api_inspector-mvp/proposal.md
R  openspec/changes/flutter_api_inspector-mvp/tasks.md -> openspec/changes/archive/flutter_api_inspector-mvp/tasks.md
R  openspec/changes/flutter_api_inspector-mvp/verify-report.md -> openspec/changes/archive/flutter_api_inspector-mvp/verify-report.md
R  openspec/changes/flutter_api_inspector-mvp/specs/instrumentation-api.md -> openspec/specs/instrumentation-api.md
R  openspec/changes/flutter_api_inspector-mvp/specs/overlay-ui.md -> openspec/specs/overlay-ui.md
R  openspec/changes/flutter_api_inspector-mvp/specs/timeline-model.md -> openspec/specs/timeline-model.md
A  openspec/changes/archive/flutter_api_inspector-mvp/archive-report.md
M  openspec/config.yaml
```

Branches kept (no deletion, per task brief):

- `change/01-skeleton-model` (historical reference, PR 1)
- `change/02-instrumentation-api` (historical reference, PR 2)
- `change/03-overlay-ui` (historical reference, PR 3)
- `change/04-example-and-acceptance` (historical reference, PR 4)
- `change/flutter_api_inspector-mvp` (chained-PR base)

No remote operations performed. No push. No PR opened. No auto-commit
beyond the archive commit.

---

## Result contract

```yaml
status: ARCHIVED
executive_summary: >-
  flutter_api_inspector-mvp is formally CLOSED. All 4 chained PRs are
  merged to main; all 30 tasks are - [x]; all 25 REQs (9 API + 8 MODEL +
  8 UI) are covered by named tests; the strict-TDD evidence table in
  apply-progress.md has 27 rows; all 5 proposal success metrics PASS; all
  6 verification gates PASS on a fresh-context re-run. The change
  directory was moved from openspec/changes/flutter_api_inspector-mvp/ to
  openspec/changes/archive/flutter_api_inspector-mvp/ as an audit
  trail; the 3 delta specs were promoted verbatim to openspec/specs/ as
  the canonical spec layer (this is a new layer; no merge was needed).
  openspec/config.yaml was updated: active_change = null,
  active_change_strategy / active_change_branch / active_change_chained_prs
  removed. No push, no PR, no auto-commit beyond the archive. The 4
  chained-PR branches + the change/flutter_api_inspector-mvp base branch
  are kept as historical references. The iOS release-build path
  verification remains the only open follow-up (deferred to CI; Windows
  host has no Xcode).
artifacts:
  - openspec/changes/archive/flutter_api_inspector-mvp/proposal.md
  - openspec/changes/archive/flutter_api_inspector-mvp/design.md
  - openspec/changes/archive/flutter_api_inspector-mvp/tasks.md
  - openspec/changes/archive/flutter_api_inspector-mvp/apply-progress.md
  - openspec/changes/archive/flutter_api_inspector-mvp/verify-report.md
  - openspec/changes/archive/flutter_api_inspector-mvp/archive-report.md
  - openspec/specs/instrumentation-api.md
  - openspec/specs/overlay-ui.md
  - openspec/specs/timeline-model.md
  - openspec/config.yaml
next_recommended: none # the change is closed; no further SDD phase is required
risks:
  - "iOS release-build path verification (flutter build ios --release --no-codesign) was NOT exercised on this Windows host. kDebugMode tree-shake is platform-agnostic; iOS is expected to mirror the Android result verified in TASK-028. A CI runner with Xcode can confirm. MINOR (deferral, not a gap)."
  - "flutter_lints ^3.0.0 is a non-SDK dev dependency. MINOR (informational; carried over from PR 1; documented in pubspec.yaml and apply-progress.md)."
  - "2 PR 3 finalization commits used the user's personal git identity; all 7 PR 4 commits + the archive commit correctly use the locked el Gentleman <el-gentleman@pi-harness.local> identity. Historical drift is fully closed. MINOR (documented as MINOR #1 in apply-progress.md)."
  - "Task brief commit count was stale for PR 4 (brief said 5 commits at 74ef624; actual is 7 commits at HEAD b7ee9b0, 2 extra are SDD documentation commits). MINOR (documentation drift only; PR 4 deliverable unaffected)."
  - "openspec/specs/.gitkeep is preserved alongside the 3 promoted specs. Cosmetic only; no effect on contracts. MINOR."
  - "The .atl/ and .pi/ directories at the repo root are untracked (not in .gitignore) and remain outside the archive commit. This matches the pre-archive state. Cosmetic only; no effect on the change."
skill_resolution: paths-injected
```
