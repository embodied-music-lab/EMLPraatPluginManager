# Drive record — 31 August 2026, Linux

Environment: Praat 6.6.30, Linux x64, in a clean container. Two
legs: the barren (command-line) build drove every procedure
headlessly; the full GUI build under Xvfb (with openbox, xcompmgr,
xdotool — the PraatGen sandbox recipe) drove the real dialogs with
scripted input and screenshot capture.

## Syntax and environment facts, measured at 6.6.30

- `praatVersion` = 6630; `praatVersion$` = "6.6.30".
- String-vector element assignment (`q$# [i] = ...`) works.
- The growable-queue doubling pattern works (capacity 64 to 16
  after 10 pushes in the probe; two forced doublings in the
  613-folder case).
- `include` resolves relative to the including script; a
  procedures-only include executes nothing.
- `createFolder` does not create parent folders.
- `folderExists`, `readLinesFromFile$#`, `replace_regex$`,
  `date#`, `startsWith`/`endsWith`, `rindex` all present.
- A boolean labeled with an underscore-containing name derives its
  variable verbatim; only characters outside letters, digits, and
  underscores are sanitized to spaces (and derive back as
  underscores).
- Return does NOT activate the default button on pause dialogs
  under GTK/Xvfb; drives click buttons by coordinates.

## install-from-disk.praat

Headless (procedures): 17 of 17 cases pass — baseName edge cases;
tar.gz and zip unpacking; the complete recursive search including
nested-inside-a-match, the `__MACOSX` exclusion, and the 613-folder
completeness case; the setup.praat scanner (continuation lines
joined, separator rows excluded, count 3 of 3); archive-with-stamp
including the detected-failure path; copy placement with the source
proven byte-identical afterward; verify; staging round trip with
the preferences directory otherwise undisturbed.

GUI (dialogs): 8 of 8 cases pass — underscore-name derivation
end to end (the load-bearing case); dash-name sanitized label with
installation under the exact original name; the derived-name
collision refusal, shown before any selection dialog with the spec
wording; pagination at 12 with both pages driven and all 15
plugins installed; uncheck-one installing exactly the rest; the
extension refusal; the cancel path; and the summary dialog. Key
screenshots in `evidence/`; each was inspected by eye.

## bootstrap/eml-plugin-manager-install.praat

Headless: 6 of 6 valid cases pass — four payload files with line
counts matching the embedded manifest; VERSION content exact; the
completion-marker logic in both directions; VERSION written only
after verify (confirmed in source); the generated about.praat runs
and prints correctly from a real plugin folder; setup.praat is the
single registration line. (A seventh assertion failed in the
driver, not the code: the driver expected a "Version: " label the
spec never required.)

## Not covered

Windows (documented behavior only; needs a manual pass on real
hardware). macOS rendering of the dialogs (logic is proven; a
short interactive sanity pass on a Mac remains worthwhile before
public release). The manager's future networked features do not
exist yet and are therefore untested.

## End-to-end with real-world plugins (same day, later)

Six genuine, unmodified plugins acquired from their public
repositories (cpran: utils, tgutils, selection, twopass; jjatria:
jjatools; AERodgers: AERoPlot) and packaged into five archives of
deliberately varied shape: plugin at archive root (zip and tar.gz),
GitHub Download-ZIP style (`plugin_tgutils-master/`), nested one
level down (`release/plugin_selection/`), and one zip holding two
plugins side by side. All five installed through the real GUI
dialogs; the two-plugin archive showed both rows ("jjatools, adds
36 commands"; "twopass, adds 1 command") and installed both in one
pass; the nested layout resolved correctly. An independent verifier
re-diffed every installed folder against its source archive:
byte-identical, no staging leftovers, zero discrepancies. Finale:
bare Praat launched with all six accumulated plugins — clean
startup, no error dialogs, meaning every real setup.praat executed.
Evidence pngs in `evidence/`.

Real-world finding for the roadmap: a GitHub-style archive installs
under its literal folder name (`plugin_tgutils-master`), which
works but leaves a noncanonical name in the preferences folder.
Whether the installer should offer to strip `-master`/`-main`
style suffixes is an open design question, deliberately not
decided in code.

## v4.1 — canonical-name proposals (1 September 2026)

The canonical-name revision (spec:
`planning/PRAATGEN_ASK_CANONICAL_NAMES_2026-08-31.md`) landed as
v4.1 and is fully verified: the 24-row normative table plus the
double-zip fixture pass through the real `emlpmL_canonicalName`
procedure (25/25, re-run independently against this repo layout —
`harness/run_canonical_names.praat`); all 17 prior headless cases
re-driven green against the new file via its library-mode flag
(`emlpm_harnessMode`); and six GUI cases pass with screenshots:
the real `plugin_tgutils-master` installing as `plugin_tgutils`
with the content-confirmed annotation, the literal-names toggle
preserving the found name, the two-proposal collision refusing
before the dialog, the near-miss `owner-plugin_Nm-sha` appearing
unchecked with its guessed name and installing as `plugin_Nm` when
checked, and the multi-plugin and nested regressions unchanged.

Accepted deviations from the spec, adjudicated: the §6 ancestor
collapse lives in the main sequence (a pairwise operation cannot
be a per-name pure function); the §5 1 MB scan cap is dropped
(Praat has no file-size primitive, so a cap would cost the read it
avoids); exit buttons read "Quit" per the project's house rule.
Exit-path buttons in the bootstrap should adopt the same rule at
its next revision.

Known cosmetic defect, open: in the selection dialog, a
description comment that wraps to a second line renders under the
row's checkbox and label (see `evidence/G1_dialog2_selection.png`).
Clicking is unaffected. Needs a layout pass — shorter annotations
or a spacer line.

Environment facts added: Praat 7.0.x refuses file writes under
`--run` without `--FULL-TRUST` (headless automation on 7 needs the
flag; interactive GUI use is unaffected). In this sandbox, the GUI
binary crashes when launched as `--run` with a script
(GtkStyleContext); the working path is opening the script editor
and driving Run by click. Praat's single-instance lock survives
kill -9; restart the display stack between GUI cases.

## v5.0 — namespace, version-aware collisions, wrap fix (1 September)

Executed by delegated agents from the pinned spec
`planning/HANDBACK_V5_POLISH_2026-09-01.md`; PraatGen not involved.
The `emlpmL_`/`emlpmB_`/`k*` identifiers — a spec-side invention —
are renamed into the project namespace: procedures `emlManager*`,
constants `emlManager_*`, library flag `emlManager_harnessMode`
(full mapping in the git diff). Bootstrap exit button now reads
Quit, and its default button is corrected to Install (it had
shipped defaulting to the exit button — caught during the rename
review). New: `emlManagerCompareVersions` (component-wise; the
future catalog comparator), `emlManagerReadVersion`, a difference
probe (sorted relative file lists + setup.praat byte-equality),
version-aware already-installed annotations with new checkbox
defaults (equal / appears-identical / older = unchecked), and
word-boundary wrapping of long description lines. Verified: 34/34
extended harness, 17/17 headless regression, three GUI cases with
screenshots (wrap fix clear of the checkbox; equal-version row
unchecked with its annotation). Residual cosmetic: the 78-char
wrap can still exceed the dialog's visual width by a word; a
future touch may tighten to ~70. New measured 6.6.30 facts:
`sort$#` works on string vectors; string comparison is
lexicographic ASCII; `fileNames$#`/`folderNames$#` return sorted
results; `readFile$` preserves exact bytes.

## Measured facts, 2026-09-01 rounds (v0.6.0-v0.6.2)

Consolidated from code comments and specifications, extracted as
present-tense rules (measured at Praat 6.6.30 unless otherwise noted):

- Pause-window comment fields do not wrap on their own; multiple lines
  must be emitted as separate comment widgets.
- Boolean checkbox labels clip at ~38 characters on macOS and never
  wrap or autosize; capping is a hard invariant enforced at every label
  construction site.
- Praat lowercases the first character when deriving a pause-form
  variable name from a field label; the derived variable name differs
  from the displayed label text in this one transformation.
- A derived variable name must not start with a digit; reading such a
  widget back through indirect substitution (`.varname$`) triggers a
  parse error ("Unknown symbol") rather than failing gracefully.
- `include` resolves every directive — including nested includes —
  relative to the OUTERMOST running script's folder, not the file
  containing the include line.
- `deleteFile` removes both files and empty folders; applying it to a
  non-empty folder does not error, but leaves the folder in place.
- `fileNames$#` and `folderNames$#` cannot enumerate dot-files (hidden
  files on macOS and Unix), so inventories and delete walks cover only
  visible entries while system commands like `cp -R` include them.
- `filesAreIdentical` does not exist as a Praat procedure at 6.6.30.
- `readFile$` and `writeFile` are not byte-safe for binary or non-ASCII
  content; null bytes are dropped and UTF-16 switching occurs, making
  in-Praat byte comparison impossible.
- Concatenating a never-assigned element of an empty-initialized string
  vector (even indirectly via assignment copy or procedure argument)
  segfaults the interpreter; every vector element must be explicitly
  written before use.
- Praat's single-instance lock survives forceful termination (`kill -9`);
  stale lock files must be manually removed before relaunching with a
  reused preferences directory.
- `cp -R source dest` nests source one level deeper when dest already
  exists as a directory; clear a surviving destination folder before
  placement.
- GUI drives must launch Praat with an ABSOLUTE `--pref-dir` path; a
  relative path corrupts staging paths built from it.
- Enumerate windows via `_NET_CLIENT_LIST`; window titles use curly
  quotes, so `xdotool search --name` with straight quotes misses them.
