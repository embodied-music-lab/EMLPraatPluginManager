# ============================================================================
# Harness: canonical-name normative table (§9) + double-zip structural fixture
# ============================================================================
# Drives the REAL emlManagerCanonicalName over every row of canonical_names.tsv
# and checks .proposal$ against expected_proposal and .row$ against
# expected_row. Then exercises the §6 ancestor-collapse rule on a synthetic
# double-zip (plugin_X/plugin_X) and asserts exactly one row survives (inner).
#
# Run headless:  ./praat --run harness/run_canonical_names.praat
# ============================================================================

# Load the installer as a library (main sequence suppressed by this flag).
emlManager_harnessMode = 1
include ../plugin_EMLPraatPluginManager/install-from-disk.praat

tsv$ = "canonical_names.tsv"
if not fileReadable (tsv$)
    tsv$ = "harness/canonical_names.tsv"
endif
lines$# = readLinesFromFile$# (tsv$)
nRows = size (lines$#)

pass = 0
fail = 0
writeInfoLine: "=== canonical-name table: ", nRows, " rows ==="

for r from 1 to nRows
    fields$# = splitBy$# (lines$# [r], tab$)
    if size (fields$#) >= 5
        lit$ = fields$# [1]
        hasSetup = number (fields$# [2])
        cref$ = fields$# [3]
        expProp$ = fields$# [4]
        expRow$ = fields$# [5]

        @emlManagerCanonicalName: lit$, hasSetup, cref$
        gotProp$ = emlManagerCanonicalName.proposal$
        gotRow$ = emlManagerCanonicalName.row$

        okProp = (gotProp$ = expProp$)
        okRow = (gotRow$ = expRow$)
        if okProp = 1 and okRow = 1
            pass = pass + 1
        else
            fail = fail + 1
            appendInfoLine: "FAIL row ", r, ": ", lit$, " [", cref$, "]"
            if okProp = 0
                appendInfoLine: "   proposal: expected '", expProp$,
                    ... "' got '", gotProp$, "'"
            endif
            if okRow = 0
                appendInfoLine: "   row: expected '", expRow$,
                    ... "' got '", gotRow$, "'"
            endif
        endif
    endif
endfor

# --- §6 double-zip structural fixture ---
# Two candidates, outer is a strict path-ancestor of inner, equal proposals.
# Mirror of the main-sequence collapse: ancestor with equal proposal is dropped.
appendInfoLine: "--- double-zip structural fixture ---"
zpath$# = { "/tmp/arc/plugin_X", "/tmp/arc/plugin_X/plugin_X" }
zprop$# = { "plugin_X", "plugin_X" }
zkeep# = { 1, 1 }
for a from 1 to 2
    if zkeep# [a] = 1
        for b from 1 to 2
            if b <> a and zkeep# [b] = 1
                if zprop$# [a] = zprop$# [b]
                    if startsWith (zprop$# [b], zprop$# [a])
                        if startsWith (zpath$# [b], zpath$# [a] + "/")
                            zkeep# [a] = 0
                        endif
                    endif
                endif
            endif
        endfor
    endif
endfor
nKept = zkeep# [1] + zkeep# [2]
if nKept = 1 and zkeep# [2] = 1
    pass = pass + 1
    appendInfoLine: "PASS: one row survives (innermost)"
else
    fail = fail + 1
    appendInfoLine: "FAIL: expected 1 (inner) survivor, kept ", nKept,
        ... " (outer=", zkeep# [1], " inner=", zkeep# [2], ")"
endif


# --- Item 3: emlManagerCompareVersions acceptance rows ---
appendInfoLine: "--- comparator acceptance rows ---"

procedure emlManagerHarnessCheckCmp: .label$, .a$, .b$, .expCmp
    @emlManagerCompareVersions: .a$, .b$
    if emlManagerCompareVersions.cmp = .expCmp
        pass = pass + 1
        appendInfoLine: "PASS cmp: ", .label$
    else
        fail = fail + 1
        appendInfoLine: "FAIL cmp: ", .label$, " -- expected ", .expCmp,
            ... " got ", emlManagerCompareVersions.cmp
    endif
endproc

# 1.2 vs 1.10 -> candidate newer when candidate is 1.10
@emlManagerHarnessCheckCmp: "1.10 newer than 1.2", "1.10", "1.2", 1
# 1.2.0 vs 1.2 -> equal
@emlManagerHarnessCheckCmp: "1.2.0 equal to 1.2", "1.2.0", "1.2", 0
# 2 vs 1.9.9 -> newer
@emlManagerHarnessCheckCmp: "2 newer than 1.9.9", "2", "1.9.9", 1
# 1.2 vs 1.2b -> text comparison on component 2
@emlManagerHarnessCheckCmp: "1.2 vs 1.2b (text compare)", "1.2", "1.2b", -1

# --- Item 3: staged-folder acceptance rows, one per annotation branch ---
appendInfoLine: "--- version-aware annotation branches (staged folders) ---"

annotScratch$ = "/tmp/eml_pm_harness_annot"
q$ = """"
runSystem_nocheck: "rm -rf " + q$ + annotScratch$ + q$
createFolder: annotScratch$

procedure emlManagerHarnessCheckAnnot: .label$,
    ... .candFolder$, .instFolder$, .expAnnot$, .expChecked
    @emlManagerInstalledAnnotation: .candFolder$, .instFolder$, annotScratch$
    okAnnot = (emlManagerInstalledAnnotation.annot$ = .expAnnot$)
    okChecked = (emlManagerInstalledAnnotation.checked = .expChecked)
    if okAnnot = 1 and okChecked = 1
        pass = pass + 1
        appendInfoLine: "PASS annot: ", .label$
    else
        fail = fail + 1
        appendInfoLine: "FAIL annot: ", .label$
        if okAnnot = 0
            appendInfoLine: "   annot: expected '", .expAnnot$,
                ... "' got '", emlManagerInstalledAnnotation.annot$, "'"
        endif
        if okChecked = 0
            appendInfoLine: "   checked: expected ", .expChecked,
                ... " got ", emlManagerInstalledAnnotation.checked
        endif
    endif
endproc

# Branch: both VERSION, candidate newer -> CHECKED
createFolder: annotScratch$ + "/cand_newer"
writeFileLine: annotScratch$ + "/cand_newer/VERSION", "1.5.0"
createFolder: annotScratch$ + "/inst_1_2_0"
writeFileLine: annotScratch$ + "/inst_1_2_0/VERSION", "1.2.0"
@emlManagerHarnessCheckAnnot: "both VERSION, newer",
    ... annotScratch$ + "/cand_newer", annotScratch$ + "/inst_1_2_0",
    ... "already installed (you have 1.2.0; this archive is 1.5.0)"
    ... + "; replacing keeps the current copy in the archive folder", 1

# Branch: both VERSION, equal -> UNCHECKED
createFolder: annotScratch$ + "/cand_equal"
writeFileLine: annotScratch$ + "/cand_equal/VERSION", "1.2.0"
@emlManagerHarnessCheckAnnot: "both VERSION, equal",
    ... annotScratch$ + "/cand_equal", annotScratch$ + "/inst_1_2_0",
    ... "this version (1.2.0) is already installed"
    ... + "; replacing keeps the current copy in the archive folder", 0

# Branch: both VERSION, candidate older -> UNCHECKED
createFolder: annotScratch$ + "/cand_older"
writeFileLine: annotScratch$ + "/cand_older/VERSION", "1.0.0"
@emlManagerHarnessCheckAnnot: "both VERSION, older",
    ... annotScratch$ + "/cand_older", annotScratch$ + "/inst_1_2_0",
    ... "OLDER than installed (you have 1.2.0; this archive is 1.0.0)"
    ... + "; replacing keeps the current copy in the archive folder", 0

# Branch: no VERSION either side, trees appear identical -> UNCHECKED
createFolder: annotScratch$ + "/inst_noversion"
writeFileLine: annotScratch$ + "/inst_noversion/setup.praat", "Add menu command"
createFolder: annotScratch$ + "/cand_identical"
writeFileLine: annotScratch$ + "/cand_identical/setup.praat", "Add menu command"
@emlManagerHarnessCheckAnnot: "no VERSION, appears identical",
    ... annotScratch$ + "/cand_identical", annotScratch$ + "/inst_noversion",
    ... "already installed; appears identical to the installed copy"
    ... + "; replacing keeps the current copy in the archive folder", 0

# Branch: no VERSION either side, trees differ -> CHECKED
createFolder: annotScratch$ + "/cand_differs"
writeFileLine: annotScratch$ + "/cand_differs/setup.praat", "Add menu command DIFFERENT"
@emlManagerHarnessCheckAnnot: "no VERSION, differs",
    ... annotScratch$ + "/cand_differs", annotScratch$ + "/inst_noversion",
    ... "already installed; differs from the installed copy"
    ... + "; replacing keeps the current copy in the archive folder", 1

runSystem_nocheck: "rm -rf " + q$ + annotScratch$ + q$

appendInfoLine: ""
appendInfoLine: "RESULT: ", pass, " pass, ", fail, " fail"
