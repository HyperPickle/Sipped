# Sipped Domain Context

Sipped is a private, local beverage ledger. It records what was consumed without scoring, coaching, or estimating physiological effects.

## Core terms

- **Drink definition**: A reusable beverage description and transparent calculation basis. Built-in definitions are reference data; user-created definitions appear in My Drinks.
- **Container definition**: A named vessel, capacity, artwork identifier, and explicit set of compatible drink categories.
- **Drink log**: An immutable historical snapshot of the selected drink, container, raw assumptions, and calculated contributions at logging time.
- **Contribution**: One of four independent values: literal fluid volume, cumulative caffeine, inherent plus added sugar, or regional standard drinks.
- **Alcohol standard**: The region-specific grams of ethanol represented by one displayed standard drink. Logs retain raw volume and ABV so this display can be recalculated.
- **Usage preference**: The last container selected for a saved drink. It never stores or restores a previous fill amount.
- **Preferred category**: A category promoted in catalogue ordering. Preference never changes category visibility.

## Invariants

- Every new amount begins at zero.
- Historical logs do not depend on mutable library records.
- Fluid is literal consumed volume; alcohol is not subtracted.
- Caffeine is cumulative intake; no metabolic model is used.
- All user history and preferences remain on device in SwiftData.

