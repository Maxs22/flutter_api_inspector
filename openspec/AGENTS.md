# OpenSpec Agent Instructions — flutter_api_inspector

These instructions apply to any subagent or session that reads or writes files
under `openspec/`. They are the SDD contract for the `flutter_api_inspector`
Flutter package.

## Language

- Artifact content (`.md`, `.yaml`, `.dart`, comments, log strings, error
  messages, and pubspec metadata) is **English**. This package is targeted at
  pub.dev and the global Flutter community; do not localize artifact content.
- Conversation with the user may be in any language they choose, but the
  artifacts stay in English unless the user explicitly requests otherwise.

## Project identity

- **Package name**: `flutter_api_inspector` (reserved on pub.dev, 404 confirmed).
- **Target**: pub.dev, Flutter 3.16+ / Dart 3.2+.
- **Core idea**: manual API instrumentation + debug-only overlay timeline.
  No auto-interceptor. No background network capture.

## Phase artifacts (under `openspec/changes/<change>/`)

| File                  | Owner phase    | Purpose                                                       |
| --------------------- | -------------- | ------------------------------------------------------------- |
| `exploration.md`      | `sdd-explore`  | Domain map, actors, integrations, risks, non-goals            |
| `proposal.md`         | `sdd-proposal` | Problem, solution, scope, success metrics, open questions     |
| `specs/*.md`          | `sdd-spec`     | Contracts: instrumentation API, overlay UI, timeline model   |
| `design.md`           | `sdd-design`   | Module layout, public surface, state flow, debug guard wiring |
| `tasks.md`            | `sdd-tasks`    | Ordered checklist with acceptance criteria and TDD evidence   |
| `apply-progress.md`   | `sdd-apply`    | What was built, commands run, gaps, follow-ups                |
| `verify-report.md`    | `sdd-verify`   | Test evidence, smoke results, production blockers             |
| `sync-report.md`      | `sdd-sync`     | Repo alignment, dependency surface, publish readiness         |
| `archive-report.md`   | `sdd-archive`  | Final retrospective                                            |

## Hard rules

1. Each phase writes **only its own artifact**. A phase must not edit a later
   artifact even if the information is obvious. Raise a risk instead.
2. Each phase artifact ends with a `## Result Contract` block containing:
   `status`, `executive_summary`, `artifacts`, `next_recommended`, `risks`,
   `skill_resolution`.
3. If a phase discovers the proposal is wrong, it raises a risk and stops. It
   does not silently mutate upstream artifacts.
4. Tests are required for everything that ships. Strict TDD is enabled in
   `openspec/config.yaml` (`strict_tdd: true`); the apply phase must record
   RED, GREEN, TRIANGULATE, and REFACTOR evidence per task.
5. **Never commit on behalf of the user. Never push. Never open a PR.** The
   `sdd-init` phase may commit the openspec/ infrastructure only, using the
   Pi harness identity, and that commit must be the only commit it produces.
6. The overlay and FAB are debug-only. Any code path that renders the overlay
   MUST be guarded by `kDebugMode` from `package:flutter/foundation.dart`. A
   release build (`flutter build --release`) must not include the overlay
   surface in the final binary tree-shaking pass.
7. Manual instrumentation is the contract. Do not introduce auto-interceptors
   (no `http` client overrides, no Dio interceptors, no `package:dio` shim).
8. Secrets in `.env.example` only; never commit real values. For this package
   there are no runtime secrets, but the rule still applies to the example
   app if one is added later.
9. **Non-authoritative store carve-out does not apply**: this project uses the
   `openspec/` artifact store. Native SDD status is authoritative.
10. The package follows the [official pub.dev package layout guidelines](https://dart.dev/effective-pub):
    `lib/`, `test/`, `example/`, `pubspec.yaml`, `README.md`, `CHANGELOG.md`,
    and `LICENSE`. These are created during the first `sdd-proposal` /
    `sdd-tasks` phase, not during init.

## Project stack (locked)

See `openspec/config.yaml` → `stack`. Do not propose alternative stacks
inside phase artifacts. Surface a risk and stop if a stack decision needs to
change.

## Testing surface (locked)

- Primary command: `flutter test` (unit + widget tests).
- Lint / typecheck: `dart analyze`.
- Format: `dart format .`.
- Coverage: `flutter test --coverage`.

Strict TDD is enforced. See `openspec/config.yaml` → `rules.apply` and
`rules.verify` for the gate conditions.
