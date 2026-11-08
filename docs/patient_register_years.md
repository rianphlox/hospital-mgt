# Annual patient cards

Card numbers restart each year, so `registerYear` + normalized card number
identifies a register card. A 1 in 2026 and A 1 in 2027 are separate entries.
Search starts on the device's current year; use the year picker for older
registers or All years. Age remains a record field, not a search mode.

New entries default to their visit date's year (otherwise creation year).
Staff can enter the card year explicitly. Editing an existing visit date does
not silently move the card to another year's register. Imports accept
`registerYear` or `year`, falling back to visitDate then current year.
Legacy Firestore records derive the year from visitDate, then createdAt.

Cards must be one letter A-L followed by digits, case-insensitive, with optional
spaces, `-` or `/` before the digits (maximum 20 characters). For example B 50,
b50 and B-50 refer to the same card within a year.

## Firestore setup

Deploy the two composite indexes in the root `firestore.indexes.json` before
using year-filtered card/name search. They combine registerYear with
cardNumberNormalized (ascending) or nameSearchKeys (array contains).
No Firebase project configuration is stored here; deploy to the hospital's
existing project using its authorized Firebase tooling, or create matching
indexes in its console. Index deployment has not been performed by this change.

For compatibility, year-filtered searches also read the corresponding
unscoped query and retain only legacy documents missing registerYear. The year
picker reads the collection to discover all years, including legacy years.
Result limits apply after year filtering so another year's records never hide
matches. This costs additional reads; a future controlled backfill and a year
metadata collection can remove these compatibility reads for larger registers.
No patient documents are automatically migrated or imported by this change.

Duplicate checks on create, edit and import are scoped to year/card. As before,
these client-side preflight checks are not a transactional uniqueness guarantee
against simultaneous writes from multiple devices; enforce that server-side
before relying on strict concurrent uniqueness.
