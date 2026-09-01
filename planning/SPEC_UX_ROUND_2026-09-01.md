# Pinned specification — UX round (v0.6.1): installed-test canon, ghost folders, label ellipsis, line-budget pagination

Every design decision below is made. Where this text is ambiguous or
impossible as written, STOP and report the question — do not
improvise. Files: `plugin_EMLPraatPluginManager/install-from-disk.praat`,
`plugin_EMLPraatPluginManager/remove-plugin.praat`, harness additions,
and the maintainer regeneration of the root install file. Nothing else.

## 1. The installed-test canon (correctness fix, measured on Ian's Mac)

Motivating defect: "already installed" tests are bare `folderExists`
on the top-level folder. Removal deletes every file Praat can see,
but macOS `.DS_Store` files are invisible to Praat's enumeration, so
the emptied folder survives as a GHOST — and the next install run
annotates it "already installed; differs from the installed copy".
On macOS this happens after essentially every removal.

Ruling: **a plugin is installed if and only if its top-level
`plugin_*` folder contains `setup.praat`** — Praat's own activation
rule. ONE canon procedure (`emlManagerIsInstalled`: folder path in,
.installed out) used by every site that currently asks
`folderExists` about an installed plugin: the pre-dialog collision
check (~line 1555), the literal-mode re-check (~line 1759), and the
remove module's Dialog-1 listing. Grep for any further
`folderExists (prefsDir$ ...` site and route it through the canon.

Ghost semantics:
- Installer: a ghost folder is FRESH GROUND. No collision
  annotation, no version comparison; install proceeds normally,
  placing files over the remnant. The completion report adds one
  line for that plugin: "Reused a leftover folder from an earlier
  removal." (named constant).
- Remove Dialog 1: ghosts are LISTED, annotated with the label
  suffix " (leftover folder; not an active plugin)" (subject to the
  ellipsis cap in §2 — the suffix survives, the name shortens).
  Removing a ghost archives whatever the walk can see (possibly
  nothing) and deletes as usual; the completion dialog reports it
  with the standard lines.

## 2. Selection labels — REVISED after the failed round (identity and display separated)

The first design derived the readback variable from the CAPPED
label, which let two long names collapse onto one variable
(measured), could exceed the cap (measured), silently dropped
annotation suffixes (measured), and displayed neither "..." nor
parentheses because the sanitizer strips them (measured). All four
are cured structurally:

a. INDEX PREFIX = identity. Every selection-row label begins with
   the item's index and an underscore: "12_ ". Digits and
   underscore survive the sanitizer, so every label — and therefore
   every derived readback variable — is unique BY CONSTRUCTION,
   whatever the ellipsis does to the rest. The install dialog's
   description comment above each checkbox begins with the same
   index ("12. <full name> ..."), and the remove flow's Dialog 2
   lists each selected plugin's FULL folder name prefixed by the
   same index, so the user can always resolve a shortened checkbox
   against its full name.
b. ELLIPSIS MARKER = "___" (three underscores) — sanitizer-proof,
   exactly three characters.
c. CAP INVARIANT: total label length (index prefix included) is
   ALWAYS <= emlManager_boolLabelCap = 38. Deterministic budget:
   when a suffix is present, the suffix is first shortened
   TAIL-PRESERVING to at most 16 characters; the name then gets
   cap - prefix - marker - len(shortSuffix) and middle-ellipsizes
   into that budget (tail-preserving, tail >= 8). The suffix is
   NEVER dropped. When no suffix, the name middle-ellipsizes into
   cap - prefix with tail >= 14.
d. COLLISION GUARDS compare REAL identities, never labels: the
   install pre-dialog duplicate check compares the uncapped
   proposed names; the remove flow needs no duplicate guard at all
   (folder names in one directory are unique; the index prefix
   makes variables unique regardless).
e. Harness: table-driven checks on the REAL label builder — cap
   never exceeded in any branch incl. the measured overflow case
   (35 < len(name) < 38 with long suffix); suffix always present
   when given; two long near-identical names yield labels distinct
   even BEFORE the index (tails preserved) and variables distinct
   BY the index; sanitizer-survival of prefix and marker asserted
   by running the builder output through emlManagerDeriveLabel and
   checking digits/underscores intact.

## 3. Line-budget pagination (Ian's ruling: 12 items was too few)

Ruling: replace the pagination-at-12 ITEM count with ONE canon
constant `emlManager_pageLineBudget = 30`, counting RENDERED LINES:
each wrapped comment line = 1, each blank comment = 1, each boolean
= 1. Items never split across pages: if adding the next item's
lines would exceed the budget and the page already holds at least
one item, start a new page. The final page additionally carries the
literal-toggle boolean and its blank spacer (install dialog only) —
reserve those 2 lines on the last page. Page titles keep the
existing " (page i of n)" form; n is computed from the same budget
walk, stated once. Effect: a plain checkbox list pages at 30 items;
annotated lists page at whatever count fits the same height.
`emlManager_pageSize` (12) is retired; no other literal page size
anywhere.

## 4. Harness additions (all headless, real assertions)

- Ghost: fixture folder containing ONLY a seeded ".DS_Store"
  (written by explicit path) → emlManagerIsInstalled reports not
  installed; the collision path yields no annotation; the remove
  listing includes it with the ghost suffix.
- Real plugin (setup.praat present) → installed.
- Ellipsis: superseded by the REVISED section 2e — its table-driven
  checks on the real label builder are the authority.
- Ghost completion-report line: the harness asserts the
  reused-leftover line is actually emitted on a ghost install
  (drive the report-assembly path in harness mode).
- Pagination: budget walk on synthetic item sets — 45 plain
  checkboxes → pages of 30 + 15; annotated items of 4 lines each →
  7 per page (28 lines) with the item-never-splits rule asserted;
  last-page reserve honored.
