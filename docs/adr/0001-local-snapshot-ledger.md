# ADR 0001: Local Snapshot Ledger

Status: Accepted

## Decision

Sipped uses SwiftData as its only persistence mechanism. Reusable drink and container definitions are stored separately from drink logs. Each log copies the display identity, container values, calculation basis, raw alcohol inputs, and calculated contributions needed to preserve history independently.

Deterministic calculators remain presentation-independent. App acceptance tests launch with a memory-only store and injected date, region, and fixtures.

## Consequences

- Deleting My Drinks or custom containers cannot rewrite historical entries.
- Regional alcohol-standard changes can recalculate display values from stored volume and ABV.
- There is no account, backend, sync, analytics, export, or background service in the MVP.
