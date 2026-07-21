# Sipped Domain Context

Sipped is a private, local beverage ledger. It records what was consumed without scoring, coaching, or estimating physiological effects. A user may choose a daily fluid goal, but it is only a neutral fixed 100% scale for History.

## Core terms

- **Drink definition**: A reusable beverage description and transparent calculation basis. Built-in definitions are reference data; user-created definitions appear in My Drinks.
- **Container definition**: A named vessel, capacity, artwork identifier, and explicit set of compatible drink categories.
- **Drink log**: An immutable historical snapshot of the selected drink, container, raw assumptions, and calculated contributions at logging time.
- **Contribution**: One of four independent values: literal fluid volume, cumulative caffeine, inherent plus added sugar, or regional standard drinks.
- **Alcohol standard**: The region-specific grams of ethanol represented by one displayed standard drink. Logs retain raw volume and ABV so this display can be recalculated.
- **Usage preference**: The last container selected for a saved drink. It never stores or restores a previous fill amount.
- **Preferred category**: A category promoted in catalogue ordering. Preference never changes category visibility.
- **Daily fluid goal**: An optional user-selected total stored canonically in millilitres. History uses it as the fixed 100% scale for literal fluid volume; it does not coach, recommend, remind, score, or make a hydration claim.

## Invariants

- Every new amount begins at zero.
- Historical logs do not depend on mutable library records.
- Fluid is literal consumed volume; alcohol is not subtracted.
- Every beverage contributes its full literal consumed volume to fluid totals, including alcoholic drinks.
- Caffeine is cumulative intake; no metabolic model is used.
- A missing, zero, negative, non-finite, or out-of-range daily fluid goal is invalid and must not be used as a chart scale.
- All user history and preferences remain on device in SwiftData.
