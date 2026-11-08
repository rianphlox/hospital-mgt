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
b50 and B-50 refer to the same card within a year. Leading zeros are ignored:
H1, H01, H001, H0001, h 001 and H-01 all have the key H1. Zero-only numbers
are accepted consistently: H0 and H000 share H0. The card as written is kept
for display/export. Card search retains numeric prefix matching (H1 also finds
H10 to H19, etc.) with exact identities first.

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

## Compatibility with zero-padded stored keys

Older documents can still store `cardNumberNormalized: H001`. Reads rebuild
identity from `cardNumber`; card lookups, search, and import duplicate checks
query the whole letter range (e.g. H), then compare canonical keys locally.
This catches any number of leading zeros, without enumerating padding lengths
or limiting candidates before matching. The existing indexes are sufficient.

No migration is required for correctness. A controlled one-off backfill of
`registerYear` and `cardNumberNormalized` is advisable as the register grows:
first audit same-year canonical collisions (never auto-merge real patients),
then recompute those fields from each record while preserving `cardNumber`.
After all documents are verified, a later change can use narrower canonical
queries and drop the broad letter/legacy-year reads. This change does not
write, delete, or merge existing database records.
