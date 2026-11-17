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
- `preferencesDirectory$` is version-correct: Praat 6.6.30 reports
  `~/.praat-dir` and Praat 7.0.02 reports `~/.config/praat` on Linux
  (measured, same probe script). Always read it at RUNTIME; never
  bake or hardcode a preferences path — a script generated under one
  Praat version must land in the right folder under another.
- `include` is resolved when Praat PARSES a script, before any line
  executes: a script cannot generate a file and include it in the
  same run. Test a generated script from a separate `praat --run`
  subprocess.
- Harness blind spot to guard against: driving work procedures with
  correct arguments proves the procedures, not the main sequence's
  own call sites. Interactive argument-passing needs the GUI drive.

## v0.7.1 -- install scan is gated and bounded (2 September 2026)

Executed from the pinned spec `planning/SPEC_SCAN_OPTIMIZATION.md`
(Fable, approved by Ian). Three fixes, all inside
`plugin_EMLPraatPluginManager/install-from-disk.praat`, no other
source file touched:

- Fix 1 (per-candidate loop, ~line 1946): skip
  `@emlManagerScanNameEvidence` when `isNearMiss = 0` (from the
  heuristic `@emlManagerCanonicalName` call) AND the heuristic
  proposal equals the literal folder name -- every branch of
  `emlManagerCanonicalName` is then invariant to `contentRef$`, so
  `contentRef$ = "none"` stands in for the skipped scan's result.
- Fix 2 (`emlManagerScanOneFile`): read the whole file once with
  `readFile$` and test `index (.content$, emlManager_pluginPrefix$)
  > 0` before paying for the per-line loop; a file with zero
  occurrences of the ASCII substring `plugin_` cannot contribute
  evidence.
- Fix 3 (`emlManagerScanNameEvidence`'s BFS enqueue loop): a
  subfolder is not enqueued when its own NAME is itself a candidate
  per `@emlManagerIsCandidateName`, at any depth -- that subtree is
  scanned on the nested candidate's own turn in the per-candidate
  loop instead.

### Harness

New `harness/run_scan_optimization.praat`, 31/31 real assertions
(cases 1-6 of the spec). Cases 1, 2, 3 and 5 drive the per-candidate
loop's Fix 1 site by mirroring it in the harness (same condition,
same real procedure calls, in the same order) rather than calling it
directly -- that site lives inside the main sequence, which is
suppressed under `emlManager_harnessMode` (the same accepted
blind-spot pattern `run_canonical_names.praat`'s double-zip fixture
already uses for the sec.6 ancestor-collapse rule). Case 4 proves
Fix 2's pre-gate changes no counter by comparing the real, gated
`emlManagerScanNameEvidence` against a reference re-scan that calls
the real `emlManagerScanOneLine` on every line of the same two files
without the file-level gate. Case 6 builds a synthetic 15-candidate,
3-nested-level, ~40-files-per-candidate x ~200-lines fixture (fresh
each run, not committed) and times the current code's discovery +
per-candidate pass with `stopwatch`.

### Pinned behavior deltas (accepted by Ian with the shape)

- Skip-gate annotation loss: a row whose folder name is already
  canonical (not a near-miss, heuristic proposal equals the literal
  name) no longer shows the "name confirmed by the plugin's own
  scripts" annotation, because the scan that would confirm it no
  longer runs. Proposal, disposition (`row$`), and `renamedFrom$`
  are unchanged -- verified directly: harness case 1 also forces the
  scan on the same fixture and confirms it would have returned
  `contentRef$ = "proposal"` (i.e. the annotation is the ONLY
  casualty). Near-miss rows and rows whose heuristic differs from
  the literal name are unaffected (cases 2 and 3).
- Nested-exclusion evidence change: for a candidate that contains a
  nested candidate folder, Fix 3 can change `contentRef$`. Measured
  on the spec's own case-5 fixture (`plugin_Outer-main` containing
  `plugin_Inner/inner.praat`, which mentions `plugin_Inner` heavily
  and never mentions `plugin_Outer`):
    - NEW value (current code, Fix 3 applied): `contentRef$ = "none"`.
    - OLD value (pre-change code, git worktree at parent commit
      8db0a1e, same literal fixture): ALSO `contentRef$ = "none"`.
  **Open question / measured discrepancy, not resolved here**: the
  spec's prose for this case claims "the pre-change code would have
  found external evidence," predicting a nonzero old value. Measured
  against the real pre-fix `emlManagerScanNameEvidence` /
  `emlManagerScanOneLine`, that does not hold for the literal
  fixture the spec describes: a match only counts toward a
  candidate's evidence when it is byte-equal to that candidate's OWN
  `literal$` or `proposal$` (the `.isProp`/`.isLit` test in
  `emlManagerScanOneLine`), and by the fixture's own construction
  ("plugin_Outer never" appears in inner.praat) there is no string
  in the nested file for the old, unexcluded walk to match against
  Outer's name -- so old and new agree on this exact fixture, and
  the delta the spec predicts did not materialize. The general
  mechanism Fix 3's own section describes ("a nested plugin's
  scripts mentioning its OWN name were being counted as evidence
  about the PARENT's name") does hold whenever a nested candidate
  shares its ancestor's exact literal or proposal string (e.g. a
  double-zip, `plugin_X/plugin_X`) -- just not for two candidates
  with genuinely different names and no cross-mention, as case 5 is
  literally written. Flagging for Fable/Ian rather than inventing
  fixture content (e.g. an actual `plugin_Outer` mention inside
  inner.praat) the spec did not specify.
  Commands used: a throwaway probe script building exactly the
  case-5 fixture and calling the real `emlManagerCanonicalName` /
  `emlManagerScanNameEvidence` was placed at
  `harness/probe.praat` (so its relative `include` resolves) once
  inside `git worktree add /tmp/emlpm_before HEAD` (parent commit
  8db0a1e, old code) and run with
  `/root/work/praat-env/praat --run /tmp/emlpm_before/harness/probe.praat`,
  then placed at the same relative path in the main tree (new code,
  post Fix 1/2/3) and run with
  `/root/work/praat-env/praat --run harness/probe.praat` from
  `/root/work/EMLPluginManager`; both invocations printed
  `contentRef$ = none`. The worktree was removed afterward
  (`git worktree remove /tmp/emlpm_before --force`) and both probe
  copies were deleted -- this probe is not part of the shipped
  harness suite.

### Timing (case 6)

Fixture: 15 candidate folders (`plugin_Cand01`..`plugin_Cand15`,
all canonical -- literally the motivating scenario, a source folder
of plainly-named plugin folders), each 3 levels of nested plain
subfolders deep (`sub1/sub2/sub3`), 40 `.praat` files per candidate
(10 per level across the 4 folders), 200 lines each -- 600 files,
120,000 lines total. 4 of the 40 files per candidate (1 per level)
contain one `plugin_<CandNN>` mention; the rest contain none.
Generator: the `emlHarnessGenTimingTree` procedure inlined in both
`harness/run_scan_optimization.praat` (current code) and a
throwaway, uncommitted twin placed at
`/tmp/emlpm_before/harness/run_timing_before.praat` for the "before"
leg (identical generator text, so both legs build the same fixture).

Commands:
- Before (pre-change code, parent commit 8db0a1e):
  `cd /root/work/EMLPluginManager && git worktree add /tmp/emlpm_before HEAD`,
  then `cd /tmp/emlpm_before && /root/work/praat-env/praat --run harness/run_timing_before.praat`
  (script timed the OLD per-candidate sequence -- heuristic
  `emlManagerCanonicalName` call, UNCONDITIONAL
  `emlManagerScanNameEvidence`, final `emlManagerCanonicalName` call
  -- with `stopwatch`, over all 15 found candidates), then
  `cd /root/work/EMLPluginManager && git worktree remove /tmp/emlpm_before --force`.
  Measured twice for stability: **2.169 s** and **2.202 s**.
- After (current code, Fix 1/2/3 applied):
  `cd /root/work/EMLPluginManager/harness && /root/work/praat-env/praat --run run_scan_optimization.praat`
  (case 6 timed with `stopwatch`, same fixture, same 15 candidates).
  Measured twice: **0.007 s** both times.

All 15 candidates are canonical by construction, so Fix 1's skip
gate fires for all of them in the after leg (`scans actually run: 0`
in the harness output) -- the after number reflects discovery
(`emlManagerFindPluginDirs`) plus `emlManagerCheckSetupPresent` plus
two cheap `emlManagerCanonicalName` calls per candidate, with zero
file reads. Acceptance (spec: after < 1 s) met by a wide margin
(~300x faster than the measured before number on this fixture).

### Newly measured Praat facts (6.6.30), this round

- `readFile$` followed immediately by `readLinesFromFile$#` on the
  same file, for a pure-ASCII substring test, sees the same decoded
  text -- no observed divergence (the previously measured
  `readFile$` byte-safety caveat is specific to binary/non-ASCII
  round-tripping, not ASCII substring search; not re-measured here
  beyond confirming Fix 2's harness case 4 counters match an ungated
  reference exactly).
- Vector literals (`v$# = { a$, b$ }`) accept variables, not just
  string literals, confirmed at 6.6.30.
- `stopwatch` (no arguments, used as a value) returns elapsed
  seconds since the previous `stopwatch` call or script start, and
  resets on each read -- first use in this repo's harnesses.

### Verifier addendum (Fable, 2 Sep) — the real Fix-3 delta, measured

The builder flagged that case 5's spec fixture (differently-named
nested candidate, no cross-mention) shows no old-vs-new delta and
declined to manufacture one. Correct call; the spec prose was wrong
and is amended in place. The genuine polluting construction is a
SAME-STEM nested candidate, and it is measured, old vs new:

    fixture: /tmp/scanprobe/src/plugin_Outer-main/plugin_Outer/old.praat
             (stale copy; its text mentions plugin_Outer)
    drive:   @emlManagerScanNameEvidence: ".../plugin_Outer-main",
             "plugin_Outer-main", "plugin_Outer"
    OLD (worktree at 8db0a1e): contentRef=proposal
    NEW (v0.7.1 working tree):  contentRef=none

Under the old code, a stale copy of a plugin left inside its own
shipping folder CONFIRMED the parent's proposed name using the stale
copy's text. Under Fix 3 the nested candidate's subtree is excluded
and adjudicated on its own turn. Independent verification: all five
harnesses re-run green by the verifier (34/113/54/23/31, 0 fail).

## v0.7.2 -- wrapper safety: self-install guard, folder source, path canon (2 September 2026)

Executed from the pinned spec `planning/SPEC_WRAPPER_SAFETY.md` (Fable,
approved by Ian). Files touched: `create-install-file.praat` (dialog
flow + wrapper template), `install-from-disk.praat` and
`remove-plugin.praat` (part 3 sweep only), `harness/run_wrapper_installer.praat`,
`VERSION`, the regenerated `eml-plugin-manager-install.praat`.

### Part 0 -- reproduction of Ian's field failure (v0.7.1, commit de8257c)

GUI-driven (Xvfb + xdotool + `/root/work/drive/gui/praat` 6.6.30) against
the unmodified v0.7.1 code, BEFORE any change in this round. Scratch
`--pref-dir` at `/root/work/drive/v072/prefs_repro`, fixture
`plugin_EMLVoiceViews` (setup.praat + scripts/x.praat). Generated the
install file via the manager's own "Create install file for a plugin"
command (writes the wrapper into the INSTALLED copy, since that command
only ever offered installed plugins before Part 2); opened and ran that
wrapper from inside `.../prefs_repro/plugin_EMLVoiceViews/`; at the
"Already installed" pause chose "Keep a backup and install" -- the
button Ian used.

REPRODUCED exactly as the spec describes: the wrapper renamed its own
running folder (`scriptFolder$ == destPath$`) to
`old_plugin_EMLVoiceViews`, the subsequent `cp -R` copied from the
now-nonexistent original path (`runSystem_nocheck`, silent failure)
into a freshly created empty `destPath$`, and the post-copy manifest
verify honestly reported "VERSION is missing from the installed copy" --
the exact wording quoted in the spec. Aftermath: `plugin_EMLVoiceViews/`
left empty, `old_plugin_EMLVoiceViews/` holding all four original files.
Evidence: `harness/evidence/v072_repro_01_already_installed.png`,
`v072_repro_02_install_failed.png`, `v072_repro_transcript.txt` (full
step-by-step transcript with the filesystem `ls` aftermath).

### Part 1 -- self-install guard

Added to the static wrapper template (`emlManagerCif_staticTemplate$#`
in `create-install-file.praat`), immediately after `scriptFolder$` and
`destPath$` are computed and before the manifest verify / already-
installed dialog, exactly per the spec: `wrapNormalizePath` strips a
trailing `/` or `\` AND replaces `\` with `/` first (unconditional,
harmless on POSIX, no Windows box to measure against);
`wrapCheckSelfInstall` fires on `normScript$ = normDest$` OR
`startsWith (normScript$, normDest$ + "/")`. On fire: one dedicated
pause ("Install: already in place"), body names the folder
(`wrapFolderName$`), this installer's baked version (`wrapVersion$`),
the pinned sentence, and the installed copy's version via
`wrapReadVersionFile` (or "unknown" if unreadable); single OK button,
then `exitScript ( )` -- no rename, no copy, no folder creation on this
path. Re-ran the identical Part-0 drive against a freshly regenerated
wrapper (fixed generator, scratch `--pref-dir`
`/root/work/drive/v072/prefs_guard`): the guard dialog fired in place
of the already-installed pause, and the prefs tree was provably
unchanged after clicking OK (no rename, no `old_plugin_EMLVoiceViews`
anywhere, all four original files still present). Evidence:
`harness/evidence/v072_guard_01_dialog.png`, `v072_guard_transcript.txt`.

Headless: the condition matrix (equal paths; wrapper nested under dest;
unrelated paths -- no fire; a same-prefix sibling folder, e.g.
plugin_XY under plugin_X, checked explicitly to rule out a naive
substring test -- no fire; trailing-slash normalization on either side;
backslash normalization for both the equal and nested-under cases) is
driven at the procedure level (`@wrapCheckSelfInstall`) inside leg 2 of
`run_wrapper_installer.praat`'s generated-wrapper harness driver -- 9
sub-cases, 1 aggregate PASS/FAIL line.

### Part 2 -- folder-source option

MEASUREMENT (required before implementing): both `chooseFolder$:` and
`chooseDirectory$:` exist and work at GUI 6.6.30 -- each opens a
working GTK folder-selection dialog (titled by the caller's argument),
each returns `""` on Cancel. Evidence:
`harness/evidence/v072_measure_chooseFolder.png` (titled "Probe
chooseFolder$"), `v072_measure_chooseDirectory.png` (titled "Probe
chooseDirectory$"), both showing the same GTK "Recent" folder list.
Chose `chooseFolder$:` for the implementation, for consistency with
its only other call site in this codebase (`install-from-disk.praat`'s
"a folder that is already unpacked" source option already uses it).

Implementation in `create-install-file.praat`: the installed-plugin
optionmenu gains one final option, exact text "Another folder (chosen
in the next step)"; choosing it invokes `chooseFolder$:`, and a `""`
return (Cancel) exits politely via the existing
`emlManager_msgCancelled$` one-liner (matching the rest of the
manager's cancel convention) rather than an error dialog. The chosen
folder is validated by a new procedure,
`emlManagerCifValidateFolderSource`, factored out specifically so the
validation ORDER is testable headless at the procedure level: (a)
name must start with `plugin_` (refused, never auto-renamed -- offer-
never-force, and here not even offered, since renaming the author's
dev folder isn't this command's business); (b) top-level setup.praat
required, reusing `emlManagerIsInstalled` unchanged (the
installed-iff-setup canon), never reimplemented; (c) the existing
non-ASCII name refusal, reusing `emlManagerCifAsciiSanitize`
unchanged. Trims a trailing `/` or `\` first. After validation the
flow is identical to the installed-plugin path (version popup, VERSION
write, wrapper write, same completion dialog as amended by Part 3).
The installed-plugin path is untouched and stays available.

GUI end-to-end drive (fixed code, all three parts applied): scratch
`--pref-dir` `/root/work/drive/v072/prefs_chooser` (NOT pre-populated
with the dev plugin, to prove the dev copy really lives outside
prefs), dev folder
`/root/work/drive/v072/devfolder/plugin_EMLDevPlugin` (setup.praat +
scripts/x.praat, no VERSION, no wrapper -- both written by the command
under test). Opened the optionmenu (shows the one installed plugin
plus "Another folder..."), chose the folder entry, drove the GTK
chooser to `plugin_EMLDevPlugin` and clicked Choose, validation passed
silently, version dialog appeared, completion dialog named the folder
and pointed at the Info window (Part 3), Info window raised on its own
showing the full path. Filesystem check: VERSION and
install-EMLDevPlugin.praat now exist INSIDE the dev folder, outside
prefs. Ran that wrapper from inside the dev folder: no guard fired
(dev folder and prefs are unrelated paths -- correctly does not fire),
no already-installed pause (nothing installed yet), clean "Installed"
pause, and the filesystem check afterward showed a clean 4-file
install inside `prefs_chooser/plugin_EMLDevPlugin/`. Evidence:
`harness/evidence/v072_chooser_00_dropdown.png` through
`v072_chooser_05_installed.png`, `v072_chooser_transcript.txt`.

Newly measured Praat/GTK fact from this drive: in the GTK folder
chooser (SELECT_FOLDER mode), typing a full path into the location-bar
entry and pressing Return does NOT select that folder -- GTK's inline
path-completion consumes the Return to accept/extend the completion
(observed: a second Return auto-completed into the folder's own
`scripts/` subfolder rather than selecting the target). The reliable
path for driving it (headless-adjacent GUI automation) is: click
"Other Locations" > navigate the tree by double-clicking down to the
parent directory, single-click the target folder to select it (enables
Choose), then click Choose.

Headless: the validation order (bad-prefix wins over missing-setup
when a folder fails both; missing-setup case; non-ASCII case, reached
only once (a) and (b) both pass; the valid-folder case with and
without a trailing slash) is driven directly against
`@emlManagerCifValidateFolderSource` in `run_wrapper_installer.praat`
-- 6 sub-checks. The interactive Cancel path (`chooseFolder$:`
returning `""`) cannot be driven headlessly (dialogs stop script
execution under `--run`); it is verified by the GUI drive instead
(the transcript's polite-cancel convention is exercised structurally,
not this specific dialog) -- the harness instead exercises the
validator's own behavior on an empty-string input as the nearest
procedure-level proxy, and notes in its own PASS line that the real
cancel path is GUI-verified, not headless-verified.

### Part 3 -- the path canon and sweep

Canon (`install-from-disk.praat`, beside the manager's other canons):
`emlManagerLogPath: .event$, .path$` does
`appendInfoLine: "EML Plugin Manager -- " + .event$ + ":"`, then
`appendInfoLine: .path$`, then a blank `appendInfoLine: ""`. NO
`clearinfo` anywhere in the manager (confirmed: none was ever present,
and none was added). The pointer sentence
`emlManager_msgSeePathInInfo$ = "The full path is printed in the Info
window."` is defined once in `install-from-disk.praat` and reused via
`include` by `create-install-file.praat` and `remove-plugin.praat`.

MEASUREMENT (required before shipping the pointer sentence): with the
Info window CLOSED (never opened this session), does `appendInfoLine`
from a running script open/raise it? YES -- confirmed twice: once from
a cold start (window never yet opened) and once again after the
window was explicitly closed and a second script ran `appendInfoLine`
-- both times the Info window opened/raised on its own with the new
text visible. Evidence: `harness/evidence/v072_infowindow_01_first_open.png`,
`v072_infowindow_02_reopen_after_close.png`. Also confirmed live during
the Part-2 chooser drive (`v072_chooser_04_infowindow.png`): the Info
window raised on its own after the completion dialog's pointer
sentence, showing exactly the canon's three-line shape (label+path
line, path line, blank line off-screen below).

Sweep sites -- every pause/comment/exitScript in the three files and
the wrapper template that interpolated a filesystem PATH into dialog
text:

CHANGED (4 sites):
1. `create-install-file.praat`, completion dialog ("Install file
   created"): previously interpolated the full `pluginPath$`. Now
   names the folder only (`pluginFolderName$`), the pointer sentence
   follows, and `@emlManagerLogPath` is called with the full
   `pluginPath$` before the dialog opens.
2. `install-from-disk.praat`, `emlManagerUnpack`'s Linux
   unzip-not-installed hint (unix + zip format only): previously
   appended the full `.source$` (source archive path) to the hint
   text. Now appends the bare `.sourceName$`; the call site logs the
   full `sourcePath$` via `@emlManagerLogPath` and appends the pointer
   sentence to the failure message, but ONLY when the hint actually
   fired (`.hadHint`) -- the plain unpack-failure message (no hint)
   never named a path in the first place, so nothing is logged for
   that branch.
3. `remove-plugin.praat`, confirmation dialog, per-plugin "Will be
   archived to <path>." line (in a `for` loop over the selected
   plugins): now names the archive destination folder only
   (`destName$# [iShow2]`), pointer sentence appended, full
   `destPath$# [iShow2]` logged via `@emlManagerLogPath` once per
   plugin before its line.
4. `remove-plugin.praat`, completion dialog, per-plugin "archived to
   <path>" line: same treatment -- `destName$# [iDone]` + pointer
   sentence in the dialog, full `destPath$# [iDone]` logged via
   `@emlManagerLogPath`.

LEFT UNCHANGED, with reason (2 sites):
5. `install-from-disk.praat`, the multi-select install dialog's
   per-candidate description line ("`<display name> (<annotations>)
   -- at <relPath$>`"): `relPath$` is the candidate's path relative to
   the unpacked archive's own root (e.g. `subdir/plugin_X`), computed
   by stripping the archive root prefix -- not an absolute filesystem
   path, and it reveals nothing about the local machine's directory
   layout. It exists specifically to disambiguate multiple candidates
   that propose the same installed name at different depths inside
   one archive, which the bare display name alone cannot do. Left
   unchanged as a bounded relative identifier, matching the spec's
   "bare folder or file NAME" carve-out in spirit even though it is
   not literally single-segment.
6. Wrapper template (`create-install-file.praat`'s
   `emlManagerCif_staticTemplate$#`), `wrapVerifyManifestUnder`'s
   `.missingPath$` (used in both the source-side and dest-side
   manifest-verify failure messages, via `wrapMsgMissingSuffix$` and
   `wrapMsgIncompleteSuffix$`): this is one entry of
   `wrapManifestPath$#`, the manifest's own relative file list (e.g.
   `sub/helper.praat` or `VERSION`) -- relative to the plugin's own
   root, never an absolute filesystem path, and already exercised
   under this exact framing by `run_wrapper_installer.praat`'s
   existing RED case ("a deleted manifest file is caught, named
   exactly ('sub/helper.praat')"). Left unchanged.

No other site in any of the four files interpolates a `*Path$`/`*Dir$`-
named variable into pause/comment/exitScript text; every other such
variable found by a repo-wide sweep (`stagingPath$`, `.folderPath$`,
`.prefsDir$`/`prefsDir$`, `.scratchDir$`, `.archiveDir$`,
`.setupPath$`, `.pluginPath$`, `fPath$`, `.sourcePath$`/`sourcePath$`,
`destPath$`/`.destPath$` outside the four changed sites, `pPath$`,
`.reportPath$`, `rawPath$#`, `reportPath$#`) is used only for internal
filesystem operations (`fileReadable`, `createFolder`,
`runSystem_nocheck` shell construction, procedure plumbing) and never
reaches dialog text.

### Harness

`run_wrapper_installer.praat` gained: 6 procedure-level checks for
Part 2's validation order (bad-prefix; no-setup; order when both fail;
non-ASCII reached only after (a)/(b) pass; valid folder with and
without a trailing slash; the empty-string edge case as the nearest
headless proxy for the interactive Cancel path) in leg 1, and a
9-sub-case self-install guard condition matrix (Part 1) driven inside
leg 2's generated-wrapper driver script, exercising the real
`@wrapCheckSelfInstall` procedure baked into the actual generated
wrapper.

All five harnesses, final count lines (verbatim, this round's run):

    run_canonical_names.praat:    RESULT: 34 pass, 0 fail
    run_setup_report.praat:       RESULT: 113 pass, 0 fail
    run_remove_plugin.praat:      RESULT: 54 pass, 0 fail
    run_wrapper_installer.praat:  LEG2 RESULT: 11 pass, 0 fail
                                   RESULT: 30 pass, 0 fail
    run_scan_optimization.praat:  RESULT: 31 pass, 0 fail

VERSION bumped 0.7.1 -> 0.7.2; `python3 tools/build_installer.py`
regenerated the embedded install file; `python3 tools/build_installer.py
--check` reports "check OK -- install file matches the plugin folder".

### Newly measured Praat facts (6.6.30), this round

- Both `chooseFolder$:` and `chooseDirectory$:` exist and work at GUI
  6.6.30 (GTK folder-selection dialog, `""` return on Cancel). Not
  previously measured in this repo.
- The Info window opens/raises on its own from a script's
  `appendInfoLine` call, both from a cold start (never opened) and
  after being explicitly closed -- confirmed twice, screenshotted both
  times.
- The GTK folder chooser in SELECT_FOLDER mode does not accept a typed
  full path via the location-bar entry + Return as a folder selection;
  inline path completion consumes the Return and can auto-complete
  into a subfolder instead. Driving it requires navigating the
  left-side location tree and single-clicking the target folder.

### Verifier addendum (Fable, 2 Sep, v0.7.2) — independent PASS, two honesty notes

Independent verification (separate agent, own harness runs, evidence
audit, targeted re-measurement of the guard matrix against the FINAL
generated wrapper): PASS on every pin. Two notes for the record:

- The chooser CANCEL path is code-reviewed and headless-proxied
  (validator on ""), but no GUI drive actually pressed Cancel on the
  GTK dialog. Recorded as untested-at-the-dialog, not verified.
- Much of this round's implementation was already in the working tree
  when the final builder started — left by an earlier build launch that
  was cancelled mid-run. The final builder verified rather than
  rewrote; the independent verifier reproduced every measurable claim.
  Recorded so the single-narrative section above is read with shared
  provenance in mind.

Canon label uses ASCII "--" rather than the spec's em dash, per the
repo-wide ASCII convention; spec amended to match.

## v0.7.3 round 2 -- Trust-window counts and parser tokenization (17 November 2026)

Praat 7.0.03 official Linux build, own HOME, Xvfb, third Trust button
chosen every time ("Yes, and I even allow this script to CONTROL MY
COMPUTER from now on"). Counts are Trust windows that appeared.

- Manager install file: 1 window on the first run; 0 on a second run
  in the same session.
- Install plugin from disk, Remove plugin, Create install file: 1
  window each on the first run in a session; 0 on a second run.
- A generated install-<name>.praat: 1 window; 0 on a second run of
  the same file; 1 more window for a different install file.
- After quit and relaunch: every command asked again (grants are per
  script file and per Praat session). A grant for one command does
  not cover the others; included modules are covered by the script
  that includes them.
- A full sitting that uses all three commands therefore sees 3
  windows, plus 1 per distinct install file.

Tokenization probes (probe/*.praat): a modifier keyword followed by
exactly one space is stripped and the command runs; two spaces or a
tab leave a leading blank and the command fails (skipped silently
under nocheck). The parser, the checklist count and the report count
now share this rule and one counter.

GUI drives: Remove plugin with colliding labels (foo-bar, foo_bar)
selects only the ticked row; the 4-plugin Removal complete dialog
renders about 755 px tall with OK visible.
