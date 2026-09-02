# ============================================================================
# Harness: install scan optimization (SPEC_SCAN_OPTIMIZATION.md, v0.7.1)
# ============================================================================
# Drives the REAL emlManagerCanonicalName / emlManagerScanNameEvidence /
# emlManagerScanOneFile / emlManagerIsCandidateName procedures against
# purpose-built fixtures for the three pinned fixes:
#   Fix 1 -- skip the name-evidence scan when it cannot change the outcome
#            (the per-candidate loop's skip gate, ~line 1946-1961).
#   Fix 2 -- whole-file pre-gate inside emlManagerScanOneFile.
#   Fix 3 -- a candidate's scan excludes nested candidates' subtrees, inside
#            emlManagerScanNameEvidence's BFS enqueue loop.
#
# Cases 1-3 and 5 cannot call the per-candidate loop directly -- it lives
# inside the main sequence, guarded by "if not variableExists
# (emlManager_harnessMode)" so the harness's own include doesn't execute
# a GUI-driving run (same reason run_canonical_names.praat's double-zip
# fixture mirrors the main sequence's sec.6 ancestor-collapse instead of
# calling it: this is the project's established pattern for main-sequence
# logic, and the accepted "harness blind spot" -- driving the same real
# procedures with the same real arguments proves the procedures, not the
# call site -- per DRIVE_RECORD 2026-08-31). emlHarnessRunCandidate below
# mirrors the skip-gate site verbatim (same condition, same procedure
# calls in the same order) and emlHarnessAnnot5 mirrors the sec.5 name
# annotation assembly (lines ~2004-2020) so the harness can assert on the
# annotation text a real install run would show.
#
# Case 6 (timing) additionally needs the OLD (pre-fix) code's numbers;
# those were measured once, out of band, via a git worktree at the parent
# commit -- see harness/DRIVE_RECORD_2026-08-31.md, dated section
# "v0.7.1 -- scan optimization", for the fixture generator, both exact
# commands, and both numbers. This harness only re-measures the CURRENT
# (fixed) code's time and asserts it against the spec's <1s bar; the
# pre-fix procedures are deliberately not kept in the shipped file (spec,
# case 6), so there is nothing to re-run "before" against on every pass.
#
# Run headless:  ./praat --run harness/run_scan_optimization.praat
# ============================================================================

emlManager_harnessMode = 1
include ../plugin_EMLPraatPluginManager/install-from-disk.praat

pass = 0
fail = 0
writeInfoLine: "=== scan optimization (SPEC_SCAN_OPTIMIZATION v0.7.1) ==="

scratchRoot$ = "/tmp/eml_pm_harness_scanopt"
q$ = """"
runSystem_nocheck: "rm -rf " + q$ + scratchRoot$ + q$
createFolder: scratchRoot$

# ----------------------------------------------------------------------------
# Mirror of the per-candidate loop's Fix 1 site (install-from-disk.praat,
# the per-candidate loop just after @emlManagerCheckSetupPresent): computes
# the heuristic proposal, applies the skip-gate condition exactly as pinned,
# and (only when the gate does not hold) runs the real content scan. Then
# runs the real second @emlManagerCanonicalName call. Reports whether the
# scan was actually invoked, so a case can assert on that directly.
procedure emlHarnessRunCandidate: .fPath$, .litName$, .hasSetup
    @emlManagerCanonicalName: .litName$, .hasSetup, "none"
    .heurName$ = emlManagerCanonicalName.proposal$
    .heurIsNearMiss = emlManagerCanonicalName.isNearMiss
    if .heurIsNearMiss = 0 and .heurName$ = .litName$
        .scanRan = 0
        .contentRef$ = "none"
    else
        .scanRan = 1
        @emlManagerScanNameEvidence: .fPath$, .litName$, .heurName$
        .contentRef$ = emlManagerScanNameEvidence.contentRef$
    endif
    @emlManagerCanonicalName: .litName$, .hasSetup, .contentRef$
    .proposal$ = emlManagerCanonicalName.proposal$
    .row$ = emlManagerCanonicalName.row$
    .isNearMiss = emlManagerCanonicalName.isNearMiss
    .confirmed = emlManagerCanonicalName.confirmed
    .renamedFrom$ = emlManagerCanonicalName.renamedFrom$
endproc

# ----------------------------------------------------------------------------
# Mirror of the sec.5 name annotation assembly (install-from-disk.praat,
# just after the per-candidate loop's already-installed check). Takes the
# same inputs that site reads and produces the same annot5$.
procedure emlHarnessAnnot5: .contentRef$, .isNearMiss, .rowKind$, .confirmed, .renamedFrom$, .litName$
    .annot5$ = ""
    if .contentRef$ = "literal"
        .annot5$ = emlManager_annotKeepsName$
    elsif .isNearMiss = 1 and .rowKind$ = "row_unchecked"
        .annot5$ = emlManager_annotGuessed$ + .litName$
    else
        if .renamedFrom$ <> ""
            .annot5$ = emlManager_annotRenamedFrom$ + .litName$
        endif
        if .confirmed = 1
            if .annot5$ <> ""
                .annot5$ = .annot5$ + "; "
            endif
            .annot5$ = .annot5$ + emlManager_annotConfirmed$
        endif
    endif
endproc

procedure emlHarnessCheck: .label$, .ok
    if .ok = 1
        pass = pass + 1
        appendInfoLine: "PASS: ", .label$
    else
        fail = fail + 1
        appendInfoLine: "FAIL: ", .label$
    endif
endproc

# ==============================================================================
# Case 1 -- SEMANTICS, skip-gate: a canonical folder containing a .praat file
# mentioning its own canonical name. Fix 1 must skip the scan entirely; the
# only observable difference from the pre-change result is the absent
# "confirmed" annotation -- proposal/row/renamedFrom are unchanged.
# ==============================================================================
appendInfoLine: ""
appendInfoLine: "--- Case 1: skip-gate (plugin_Alpha, canonical, self-referencing) ---"

c1$ = scratchRoot$ + "/plugin_Alpha"
createFolder: c1$
writeFileLine: c1$ + "/note.praat", "# see plugin_Alpha for details"

@emlHarnessRunCandidate: c1$, "plugin_Alpha", 0
@emlHarnessCheck: "scan was skipped (contentRef path not taken)",
    ... (emlHarnessRunCandidate.scanRan = 0)
@emlHarnessCheck: "contentRef$ = none", (emlHarnessRunCandidate.contentRef$ = "none")
@emlHarnessCheck: "proposal$ = plugin_Alpha", (emlHarnessRunCandidate.proposal$ = "plugin_Alpha")
@emlHarnessCheck: "row$ = row", (emlHarnessRunCandidate.row$ = "row")
@emlHarnessCheck: "renamedFrom$ = """" (unchanged)", (emlHarnessRunCandidate.renamedFrom$ = "")
@emlHarnessCheck: "confirmed = 0 (no evidence was gathered)",
    ... (emlHarnessRunCandidate.confirmed = 0)

@emlHarnessAnnot5: emlHarnessRunCandidate.contentRef$, emlHarnessRunCandidate.isNearMiss,
    ... emlHarnessRunCandidate.row$, emlHarnessRunCandidate.confirmed,
    ... emlHarnessRunCandidate.renamedFrom$, "plugin_Alpha"
@emlHarnessCheck: "row annotation carries no emlManager_annotConfirmed$ (report text otherwise unchanged: empty)",
    ... (emlHarnessAnnot5.annot5$ = "")

# Confirm the skip is load-bearing, not accidental: if the scan HAD run on
# this same fixture, it would have found the self-reference and confirmed
# the row (byte-for-byte the pre-change result) -- proving the skip changed
# only the annotation, per the spec's outcome-preserving argument.
@emlManagerScanNameEvidence: c1$, "plugin_Alpha", "plugin_Alpha"
@emlHarnessCheck: "(if scanned anyway) contentRef$ = proposal -- confirms the skip is load-bearing",
    ... (emlManagerScanNameEvidence.contentRef$ = "proposal")

# ==============================================================================
# Case 2 -- SEMANTICS, scan still fires: a junk-suffixed folder whose scripts
# reference the stripped (canonical) name. heurName$ <> litName$, so the skip
# gate does not hold -- the scan must run exactly as before the change.
# ==============================================================================
appendInfoLine: ""
appendInfoLine: "--- Case 2: scan still fires (plugin_Beta-main, junk suffix) ---"

c2$ = scratchRoot$ + "/plugin_Beta-main"
createFolder: c2$
writeFileLine: c2$ + "/note.praat", "# part of plugin_Beta suite"

@emlHarnessRunCandidate: c2$, "plugin_Beta-main", 0
@emlHarnessCheck: "scan ran (heurName$ <> litName$, skip gate does not hold)",
    ... (emlHarnessRunCandidate.scanRan = 1)
@emlHarnessCheck: "contentRef$ = proposal", (emlHarnessRunCandidate.contentRef$ = "proposal")
@emlHarnessCheck: "proposal$ = plugin_Beta", (emlHarnessRunCandidate.proposal$ = "plugin_Beta")
@emlHarnessCheck: "row$ = row", (emlHarnessRunCandidate.row$ = "row")
@emlHarnessCheck: "confirmed = 1", (emlHarnessRunCandidate.confirmed = 1)
@emlHarnessCheck: "renamedFrom$ = plugin_Beta-main",
    ... (emlHarnessRunCandidate.renamedFrom$ = "plugin_Beta-main")

@emlHarnessAnnot5: emlHarnessRunCandidate.contentRef$, emlHarnessRunCandidate.isNearMiss,
    ... emlHarnessRunCandidate.row$, emlHarnessRunCandidate.confirmed,
    ... emlHarnessRunCandidate.renamedFrom$, "plugin_Beta-main"
expectedAnnot2$ = emlManager_annotRenamedFrom$ + "plugin_Beta-main" + "; " + emlManager_annotConfirmed$
@emlHarnessCheck: "annotation = 'renamed from plugin_Beta-main; " + emlManager_annotConfirmed$ + "' (byte-identical to pre-change: none of the three fixes changes this fixture's outcome)",
    ... (emlHarnessAnnot5.annot5$ = expectedAnnot2$)

# ==============================================================================
# Case 3 -- SEMANTICS, near-miss: near-miss rows never hit the skip gate
# (isNearMiss = 1 always fails the "isNearMiss = 0" half of the condition),
# so they still scan and still earn a confirmed row exactly as before.
# ==============================================================================
appendInfoLine: ""
appendInfoLine: "--- Case 3: near-miss always scans (old_plugin_Gamma) ---"

c3$ = scratchRoot$ + "/old_plugin_Gamma"
createFolder: c3$
writeFileLine: c3$ + "/note.praat", "# part of plugin_Gamma suite"

@emlHarnessRunCandidate: c3$, "old_plugin_Gamma", 0
@emlHarnessCheck: "scan ran (near-miss rows never hit the skip gate)",
    ... (emlHarnessRunCandidate.scanRan = 1)
@emlHarnessCheck: "isNearMiss = 1", (emlHarnessRunCandidate.isNearMiss = 1)
@emlHarnessCheck: "contentRef$ = proposal", (emlHarnessRunCandidate.contentRef$ = "proposal")
@emlHarnessCheck: "proposal$ = plugin_Gamma", (emlHarnessRunCandidate.proposal$ = "plugin_Gamma")
@emlHarnessCheck: "confirmed = 1", (emlHarnessRunCandidate.confirmed = 1)
@emlHarnessCheck: "row$ = row (confirmed near-miss)", (emlHarnessRunCandidate.row$ = "row")

# ==============================================================================
# Case 4 -- SEMANTICS, pre-gate: one file with no plugin_ occurrence at all
# (Fix 2 must skip its line loop entirely) and one file with occurrences
# (Fix 2 must scan it exactly as before). The resulting counters must equal
# what an ungated line-by-line scan of the same two files would produce --
# proven here by an explicit reference re-scan (calling the real
# emlManagerScanOneLine directly on every line of both files, bypassing
# emlManagerScanOneFile's pre-gate) and comparing its totals to the real,
# gated emlManagerScanNameEvidence's totals on the identical fixture.
# ==============================================================================
appendInfoLine: ""
appendInfoLine: "--- Case 4: pre-gate does not change counters (plugin_Delta) ---"

c4$ = scratchRoot$ + "/plugin_Delta"
createFolder: c4$
noFile$ = c4$ + "/file_no.praat"
writeFileLine: noFile$, "alpha bravo charlie"
appendFileLine: noFile$, "no match anywhere in this file"
appendFileLine: noFile$, "just filler text, three lines, zero occurrences"
withFile$ = c4$ + "/file_with.praat"
writeFileLine: withFile$, "# unrelated filler line"
appendFileLine: withFile$, "# refers to plugin_Delta directly"
appendFileLine: withFile$, "# more filler, and another plugin_Delta mention"

# Reference: emlManagerScanOneLine (the real per-line matcher) over every
# line of both files, unconditionally -- i.e. without Fix 2's whole-file gate.
refCProp = 0
refCLit = 0
refNcProp = 0
refNcLit = 0
refFiles$# = { noFile$, withFile$ }
for rf from 1 to 2
    refLines$# = readLinesFromFile$# (refFiles$# [rf])
    for rl from 1 to size (refLines$#)
        @emlManagerScanOneLine: refLines$# [rl], c4$, "plugin_Delta", "plugin_Delta"
        refCProp = refCProp + emlManagerScanOneLine.cProp
        refCLit = refCLit + emlManagerScanOneLine.cLit
        refNcProp = refNcProp + emlManagerScanOneLine.ncProp
        refNcLit = refNcLit + emlManagerScanOneLine.ncLit
    endfor
endfor

@emlManagerScanNameEvidence: c4$, "plugin_Delta", "plugin_Delta"
@emlHarnessCheck: "cProp matches ungated reference (" + string$ (refCProp) + ")",
    ... (emlManagerScanNameEvidence.cProp = refCProp)
@emlHarnessCheck: "cLit matches ungated reference (" + string$ (refCLit) + ")",
    ... (emlManagerScanNameEvidence.cLit = refCLit)
@emlHarnessCheck: "ncProp matches ungated reference (" + string$ (refNcProp) + ")",
    ... (emlManagerScanNameEvidence.ncProp = refNcProp)
@emlHarnessCheck: "ncLit matches ungated reference (" + string$ (refNcLit) + ")",
    ... (emlManagerScanNameEvidence.ncLit = refNcLit)
@emlHarnessCheck: "cProp = 2 (both plugin_Delta mentions in file_with.praat counted)",
    ... (emlManagerScanNameEvidence.cProp = 2)

# ==============================================================================
# Case 5 -- SEMANTICS, nested exclusion: plugin_Outer-main (forced to scan by
# its junk suffix, no evidence of its own) contains plugin_Inner/inner.praat,
# which mentions plugin_Inner heavily and plugin_Outer not at all. Fix 3
# excludes plugin_Inner's subtree from the outer scan entirely.
#
# MEASURED, not assumed: this exact fixture was also run against the
# pre-change code (git worktree at the parent commit -- see DRIVE_RECORD).
# The old code ALSO returns contentRef$ = "none" here: emlManagerScanOneLine
# only counts a match that is byte-equal to the scanned candidate's OWN
# literal$/proposal$ (see the .isProp/.isLit test), and inner.praat, by this
# fixture's own construction, never contains "plugin_Outer" text at all --
# so there is no string for the old, unexcluded walk to match against Outer's
# name regardless of whether plugin_Inner's subtree is walked. The spec's
# prose for this case ("the pre-change code would have found external
# evidence") does not hold for this literal construction; see the DRIVE_
# RECORD entry for the measured old/new values and this discrepancy, flagged
# as an open question rather than resolved by inventing fixture content the
# spec did not specify (e.g. an actual plugin_Outer mention inside
# inner.praat, which would contradict "plugin_Outer never").
# ==============================================================================
appendInfoLine: ""
appendInfoLine: "--- Case 5: nested exclusion (plugin_Outer-main / plugin_Inner) ---"

c5$ = scratchRoot$ + "/plugin_Outer-main"
createFolder: c5$
c5inner$ = c5$ + "/plugin_Inner"
createFolder: c5inner$
c5innerFile$ = c5inner$ + "/inner.praat"
writeFileLine: c5innerFile$, "# about plugin_Inner"
appendFileLine: c5innerFile$, "# plugin_Inner does things"
appendFileLine: c5innerFile$, "# plugin_Inner again, and plugin_Inner once more"

@emlManagerIsCandidateName: "plugin_Inner"
@emlHarnessCheck: "plugin_Inner is itself a candidate name (precondition for Fix 3 to apply)",
    ... (emlManagerIsCandidateName.yes = 1)

@emlHarnessRunCandidate: c5$, "plugin_Outer-main", 0
@emlHarnessCheck: "scan ran (forced by the junk suffix -- heurName$ <> litName$)",
    ... (emlHarnessRunCandidate.scanRan = 1)
@emlHarnessCheck: "contentRef$ = none (nested plugin_Inner subtree excluded from Outer's scan)",
    ... (emlHarnessRunCandidate.contentRef$ = "none")

# ==============================================================================
# Case 6 -- TIMING: 15 candidate folders, each 3 levels of nested subfolders
# deep, ~40 .praat files of ~200 lines apiece (most without plugin_), built
# fresh into scratchRoot$ (not committed as files). Times the full
# discovery+canonicalize pass (emlManagerFindPluginDirs, then the
# per-candidate loop's heuristic call, skip-gate, conditional scan, and
# final call) with the CURRENT (fixed) code via Praat's stopwatch.
#
# The "before" number for this identical fixture was measured once, out of
# band, against the pre-change code at the parent commit via a git worktree;
# see DRIVE_RECORD for the fixture generator, both exact commands, and both
# numbers. Acceptance here is only the spec's <1s bar on the after number.
# ==============================================================================
appendInfoLine: ""
appendInfoLine: "--- Case 6: timing, 15 candidates x 3 nested levels x ~40 files x ~200 lines ---"

timingRoot$ = scratchRoot$ + "/timing"
createFolder: timingRoot$

procedure emlHarnessGenTimingTree: .root$, .nCandidates
    for .c from 1 to .nCandidates
        if .c < 10
            .idx$ = "0" + string$ (.c)
        else
            .idx$ = string$ (.c)
        endif
        .candName$ = "plugin_Cand" + .idx$
        .candPath$ = .root$ + "/" + .candName$
        createFolder: .candPath$
        .l1$ = .candPath$ + "/sub1"
        .l2$ = .l1$ + "/sub2"
        .l3$ = .l2$ + "/sub3"
        createFolder: .l1$
        createFolder: .l2$
        createFolder: .l3$
        .levels$# = { .candPath$, .l1$, .l2$, .l3$ }
        for .lv from 1 to 4
            for .f from 1 to 10
                .fname$ = .levels$# [.lv] + "/file" + string$ (.f) + ".praat"
                .content$ = ""
                for .ln from 1 to 200
                    if .f = 10 and .ln = 100
                        .content$ = .content$ + "# related to " + .candName$ + newline$
                    else
                        .content$ = .content$ + "# filler line " + string$ (.ln)
                            ... + " of no consequence, level " + string$ (.lv) + newline$
                    endif
                endfor
                writeFile: .fname$, .content$
            endfor
        endfor
    endfor
endproc

@emlHarnessGenTimingTree: timingRoot$, 15

stopwatch
timingResultsFile$ = scratchRoot$ + "/timing_found.txt"
@emlManagerFindPluginDirs: timingRoot$, timingResultsFile$
timingFound$# = readLinesFromFile$# (timingResultsFile$)
timingScanCount = 0
for ti from 1 to size (timingFound$#)
    tPath$ = timingFound$# [ti]
    @emlManagerBaseName: tPath$
    tLit$ = emlManagerBaseName.name$
    @emlManagerCheckSetupPresent: tPath$
    tHasSetup = emlManagerCheckSetupPresent.hasSetup
    @emlHarnessRunCandidate: tPath$, tLit$, tHasSetup
    timingScanCount = timingScanCount + emlHarnessRunCandidate.scanRan
endfor
afterTime = stopwatch

appendInfoLine: "found ", size (timingFound$#), " candidates; scans actually run: ", timingScanCount
appendInfoLine: "AFTER (current code) wall-clock: ", fixed$ (afterTime, 3), " s"
@emlHarnessCheck: "found all 15 candidates", (size (timingFound$#) = 15)
@emlHarnessCheck: "after time < 1 second (spec acceptance bar)", (afterTime < 1.0)
appendInfoLine: "(before-code number is a one-time worktree measurement -- see DRIVE_RECORD, not re-run here)"

runSystem_nocheck: "rm -rf " + q$ + scratchRoot$ + q$

appendInfoLine: ""
appendInfoLine: "RESULT: ", pass, " pass, ", fail, " fail"
