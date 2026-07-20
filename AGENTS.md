# Repository Guidelines

## Before You Make Changes

Resolve conflicts in this order: the user and referenced `.scratch` issue; feature PRD and accepted ADRs; `CONTEXT.md`; `docs/design-references/REFERENCE.md`; tests and implementation. Surface contradictions. Keep changes scoped and preserve unrelated work.

For codebase, architecture, or project-content questions, verify source files before editing. Use matching installed workflows—`diagnosing-bugs`, `tdd`, `review`, `codebase-design`, `domain-modeling`, `qa`, `triage`, `to-prd`, or `to-issues`—when their triggers apply.

## Tracker and Domain

Local PRDs live at `.scratch/<feature>/PRD.md`; issues live at `.scratch/<feature>/issues/<NN>-<slug>.md`. Read referenced tickets first. Use only `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, or `wontfix`; append discussion under `## Comments`.

Read `CONTEXT.md` and relevant `docs/adr/` files before domain work. Preserve immutable `DrinkLog` snapshots, SwiftData-only persistence, presentation-independent calculators, zero-start amounts, and container-only usage preferences.

## Implementation and Verification

Before UI work, inspect every image and instruction in `docs/design-references/REFERENCE.md`. The PRD controls behaviour; create original visuals and preserve Dynamic Type, VoiceOver, contrast, Reduce Motion, and 44-point targets.

Treat `project.yml` as authoritative. Use four-space Swift formatting. Add focused XCTest coverage and XCUITest coverage for visible behaviour. Build with `xcodebuild -project Sipped.xcodeproj -scheme Sipped -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO`. Report changed files, checks, and risks.
