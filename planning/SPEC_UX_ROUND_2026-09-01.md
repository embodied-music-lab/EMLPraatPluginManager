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
  suffix " leftover" (AMENDED 0.7.3; was " (leftover folder; not an
  active plugin)", too long for the cap beside a real folder name).
  The suffix is subject to the cap rule in §2c.
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

a. AMENDED (Ian, 1 Sep: visible index prefixes on every row are a
   waste of space): labels are BARE by default. The index prefix
   ("n12_" — letter-initial, since a derived variable name must not
   start with a digit, measured) is applied ONLY to rows whose
   capped, sanitized labels would otherwise collide within the
   dialog: after building all capped labels for the listing, any
   group of duplicates gets the prefix; unique labels get none. In
   realistic listings no prefixes appear at all. Uniqueness of the
   derived readback variables remains guaranteed by construction —
   bare labels are unique because they only stay bare when
   their derived readback names are distinct; collided labels are made unique by the prefix. The
   install dialog's description comments and the remove flow's
   Dialog 2 continue to carry FULL names (no index numbering
   needed when no prefixes are shown; when a collision forced
   prefixes, Dialog 2 lines carry the matching "n12." so the user
   can resolve them). Applies to BOTH selection dialogs — one canon.
b. ELLIPSIS MARKER = "___" (three underscores) — sanitizer-proof,
   exactly three characters.
c. CAP INVARIANT: total label length (index prefix included) is
   ALWAYS <= emlManager_boolLabelCap = 38. Deterministic budget,
   AMENDED 0.7.3 (the manager's own row rendered as
   "plugin_EMLP___nManager  thi___ itself"):
   - The name and suffix fit together: nothing is shortened.
   - Otherwise the suffix is first shortened TAIL-PRESERVING to at
     most 16 characters (the annotation words are shorter, so they
     stay whole); the name then gets cap - prefix - len(suffix) and
     middle-ellipsizes into that budget (tail-preserving, tail >= 8).
     The annotation is never dropped or cut, so "itself" and
     "leftover" always show; a name that fits the cap alone is
     shortened when its annotation needs the room (AMENDED 0.7.3
     round 2: the earlier rule that kept the name whole and cut the
     suffix lost the marker for names of 28-38 characters).
   - No suffix: the name middle-ellipsizes into cap - prefix with
     tail >= 14.
   The annotation texts are short so the common rows fit whole:
   " itself" for the manager's own folder and " leftover" for a
   ghost, each after a single space and with no punctuation (the
   sanitizer turns every punctuation mark into a space, so " (itself)"
   showed as two spaces). The manager's own folder name, 28
   characters, plus " itself" is 35 and fits whole. Dialog 2 names
   every plugin in full.
d. COLLISION GUARDS compare REAL identities, never labels: the
   install pre-dialog duplicate check compares the uncapped
   proposed names. The label canon (emlManagerBuildLabels) gives the
   index prefix to every row whose bare DERIVED readback name equals
   another row's -- AMENDED 0.7.3 round 2: the test runs on the name
   Praat reads the checkbox back through (sanitized label, spaces to
   underscores, first letter lowercased), not on the label, because
   "plugin_foo-bar" (label "plugin_foo bar") and "plugin_foo_bar"
   read back as the same variable, so ticking one selected the
   other. The remove flow therefore needs no separate duplicate
   guard: its readback names are unique by construction.
e. Harness (amended with 2a): cap never exceeded in any branch
   incl. the 35-37 overflow case; suffix always present when given;
   a listing of DISTINCT names yields NO prefixes and unique
   sanitized labels; a FORCED post-cap collision (two names whose
   capped labels are identical) yields prefixed, distinct labels
   and distinct derived variables; sanitizer-survival of the
   prefix and marker asserted through emlManagerDeriveLabel.

## 3. Page-budget pagination (Ian's ruling: 12 items was too few)

AMENDED 0.7.3 (round 4): the budget measures what is rendered. The
original ruling counted lines (30 per page); a verifier drive showed
that count lets a page grow past a 900-pixel screen, because a
comment that ends in a period renders taller than one that does not.
Procedure `emlManagerPageMetrics` is now the ONE place that states
the weights and the budget, in pixels, measured on Praat 7.0.03
(Linux, Xvfb 1280x900, openbox):

- comment ending in a period, and an empty comment: 37
- comment ending in a colon: 27
- comment ending in any other character: 22
- boolean row: 32
- chrome (button row and padding): 91, the largest measured
- tallest allowed window (`.screenPx`): 800, which is 900 less 100
  for the title bar and the menu bar, dock or taskbar
- budget for rows (`.budgetPx`): 709 (800 less 91)

Procedure `emlManagerLinePx` gives one comment's weight from its last
character; `emlManagerWrappedPx` gives a text's weight after word
wrapping and can emit the same lines, so the weight counted is the
weight shown. A comment longer than the wrap width can only be one
unbreakable word, which the window wraps onto more rows; each extra
row adds 22. Items never split across pages: if adding the next
item's height would exceed the budget and the page already holds at
least one item, start a new page. AMENDED 0.7.3 (round 5): the walk
takes a keep-with-previous mark per item, and a marked item stays on
the page of the item before it. That one rule keeps together the
wrapped lines of one command (the Installation complete dialog and the
generated wrapper completion), a "<plugin> adds:" heading with the
summary line above it and the first command below it, and the restart
line with the blank line above it. The same rule governs a footer
reserve when the caller asks that it keep with the last block: the
Confirm removal footer (the safety switch and Archive and remove) and
the Removal complete footer keep with the last plugin block, so the
last page never holds a footer alone. The final page of the install
dialog additionally carries the literal-toggle boolean and its blank
spacer (`.reservePx`, 69), kept with the last plugin block (AMENDED round 6),
so the toggle never sits alone on a page. Page titles keep the " (page i of n)"
form; n is computed from the same budget walk, stated once. The walk
(`emlManagerPageBudgetWalk`) works in any unit; the callers pass
pixels. `emlManager_pageLineBudget` and `emlManager_pageSize` are
retired; no other page size or line weight appears anywhere. The
generated install files carry the same procedures, extracted from
install-from-disk.praat.

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
