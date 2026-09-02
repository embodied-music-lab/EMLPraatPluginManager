# Spec — install scan optimization (v0.7.1)

Fable, 2 September 2026. Approved by Ian ("I am good with that manager
shape. Please go ahead and do it."). Motivating measurement: a source
folder containing ~15 plugin folders with nested subfolders locked
Praat's GUI for ~15 seconds during "Install plugin from disk". The cost
is not the directory walk; it is the per-candidate name-evidence scan
(`emlManagerScanNameEvidence`) reading every line of every `.praat`
file through a per-line procedure call, once per candidate, with nested
candidates re-read by every ancestor candidate's scan.

All three fixes below live in
`plugin_EMLPraatPluginManager/install-from-disk.praat`. No other file
changes except the harness, DRIVE_RECORD, and VERSION/install-file
regeneration. `emlManagerCanonicalName` is NOT modified — the existing
34-case normative harness for it must pass byte-identically.

## Fix 1 — skip the scan when it cannot change the outcome

Site: the per-candidate loop (currently ~line 1920-1930), where the
code computes `heurName$` via `@emlManagerCanonicalName: litName$,
hasSetup, "none"` and then unconditionally runs
`@emlManagerScanNameEvidence`.

Change: run the scan ONLY when it can affect the result. The skip
condition, exactly:

    emlManagerCanonicalName.isNearMiss = 0 (from the heuristic call)
    AND heurName$ = litName$

When the condition holds, set `contentRef$ = "none"` and do not call
`@emlManagerScanNameEvidence`. Everything downstream (the second
`@emlManagerCanonicalName` call, annotations, defaults) runs unchanged
with that `contentRef$`.

Why this is outcome-preserving: with `isNearMiss = 0` and
`heuristic = literal`, every branch of `emlManagerCanonicalName`
produces `proposal$ = litName$`, `row$ = "row"`, `renamedFrom$ = ""`
regardless of `contentRef$`. The only observable difference is
`confirmed`, whose sole consumer is the cosmetic annotation
`emlManager_annotConfirmed$` ("name confirmed by the plugin's own
scripts").

PINNED BEHAVIOR DELTA (accepted by Ian with the shape): rows whose
folder name is already canonical no longer show that annotation. That
is more honest, not less — nothing was in question for those rows.
Near-miss rows and rows whose heuristic differs from the literal still
scan and still earn their annotations exactly as before.

## Fix 2 — whole-file pre-gate inside the scan

Site: `emlManagerScanOneFile`.

Change: before the line loop, read the whole file once and test for the
prefix:

    .content$ = readFile$ (.fpath$)
    if index (.content$, emlManager_pluginPrefix$) = 0
        → all four counters stay 0; return without the line loop
    endif

Files that do contain the prefix proceed through the existing
`readLinesFromFile$#` line loop unchanged (line semantics, the maximal
name-char run walk, and the subpath discriminator are untouched).

Safety note, pinned: the measured readFile$ caveat in DRIVE_RECORD is
about BYTE-safety for round-tripping (binary/non-ASCII writes). Here
the file is only searched for the ASCII substring `plugin_`, which
survives any decoding readFile$ applies; readLinesFromFile$# performs
the same decoding, so gate and loop see the same text. If readFile$
errors on a file the line loop could read, that would be a measured
finding to report — the builder must not discover-and-silently-workaround.

## Fix 3 — a candidate's scan excludes nested candidates' subtrees

Site: `emlManagerScanNameEvidence`'s BFS enqueue loop.

Change: when enqueuing subfolders, skip (do not enqueue) any subfolder
whose NAME is itself a candidate per `@emlManagerIsCandidateName`, at
any depth. The excluded folder's entire subtree is out of the parent's
scan; the nested candidate is scanned on its own turn by the
per-candidate loop as today.

PINNED BEHAVIOR DELTA (accepted): evidence counts change for folders
that contain nested plugin folders. This is a correctness improvement,
not a regression — a nested plugin's scripts mentioning its own name
were being counted as evidence about the PARENT's name. The
`__MACOSX` exclusion stays as is, alongside the new one.

Scope guard: `emlManagerFindPluginDirs` (candidate discovery) still
descends everywhere, unchanged — nested candidates must still be
FOUND; they are only excluded from other candidates' EVIDENCE scans.
`emlManagerListRelFiles` (the item-3 diff probe) is explicitly OUT of
scope for this round; if timing later shows it hot, that is a new
spec.

## Harness additions (all three drive the changed code, not the pure canon)

New harness script `harness/run_scan_optimization.<ext>` following the
existing harness conventions (generated scripts via separate
`praat --run`, container barren Praat), with these cases:

1. SEMANTICS, skip-gate: a canonical folder `plugin_Alpha` containing a
   `.praat` file mentioning `plugin_Alpha` → contentRef path not taken
   (scan skipped), final proposal/row/default identical to the
   pre-change behavior except the absent "confirmed" annotation;
   assert the report text for the row carries no
   `emlManager_annotConfirmed$` and is otherwise unchanged.
2. SEMANTICS, scan still fires: a junk-suffixed folder
   `plugin_Beta-main` whose scripts reference `plugin_Beta` → scan
   runs, contentRef$ = "proposal", annotation "renamed from ...;
   confirmed" exactly as before the change (byte-compare against a
   recorded pre-change expectation for this fixture).
3. SEMANTICS, near-miss: `old_plugin_Gamma` with confirming content →
   still scans, still becomes a confirmed row. (Near-miss rows never
   hit the skip gate.)
4. SEMANTICS, pre-gate: a candidate containing one `.praat` file with
   no `plugin_` occurrence and one with occurrences → counters equal
   the pre-change scan's counters on the same fixture.
5. SEMANTICS, nested exclusion. AMENDED 2 Sep after the build: the
   original fixture (nested `plugin_Inner` with a DIFFERENT name that
   never mentions the outer name) shows NO delta — the scan only
   counts matches byte-equal to the candidate's own literal/proposal,
   so differently-named nested candidates never polluted anything.
   The builder measured old = new = "none" on that fixture and
   correctly stopped rather than manufacturing the predicted delta;
   the spec's prose was wrong. The REAL polluting case, measured by
   the verifier (2 Sep, old vs new code via git worktree at 8db0a1e):
   a SAME-STEM nested candidate — `plugin_Outer-main` containing a
   stale copy `plugin_Outer/old.praat` whose text mentions
   `plugin_Outer` — old code contentRef$ = "proposal" (the stale
   copy's self-references CONFIRMED the parent's proposal), new code
   contentRef$ = "none". That is the pinned delta: a stale copy of a
   plugin inside its own shipping folder no longer supplies the
   evidence that confirms the name. The differently-named fixture
   stays in the harness as a no-delta regression case.
6. TIMING: a generated synthetic tree — 15 candidate folders, each
   with 3 levels of nesting and ~40 `.praat` files of ~200 lines
   (most without `plugin_`), fixture built by script, not committed
   as files. Measure wall-clock of the full discovery+canonicalize
   pass (stopwatch via Praat's `stopwatch`) before and after by
   running the OLD code path (a copy of the pre-change procedures is
   NOT kept in the shipped file — measure "before" at the parent git
   commit via a worktree or stash, and record both numbers with the
   commands used). Acceptance: the after time is under 1 second on
   the container for this fixture, and the number, the fixture
   generator, and both commands land in DRIVE_RECORD.

Existing harnesses must stay green: run_canonical_names (34),
run_setup_report (113), run_remove_plugin (54), run_wrapper_installer
(23). `tools/build_installer.py --check` green after VERSION bump.

## Version and delivery

VERSION 0.7.1. Install file regenerated by `tools/build_installer.py`.
Commit message: "v0.7.1: install scan is gated and bounded — skip
no-op evidence scans, pre-gate files, exclude nested candidates".
No push from the build session; Fable verifies, commits, bundles.
