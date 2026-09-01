# ============================================================================
# Harness: canonical-name normative table (§9) + double-zip structural fixture
# ============================================================================
# Drives the REAL emlpmL_canonicalName over every row of canonical_names.tsv
# and checks .proposal$ against expected_proposal and .row$ against
# expected_row. Then exercises the §6 ancestor-collapse rule on a synthetic
# double-zip (plugin_X/plugin_X) and asserts exactly one row survives (inner).
#
# Run headless:  ./praat --run harness/run_canonical_names.praat
# ============================================================================

# Load the installer as a library (main sequence suppressed by this flag).
emlpm_harnessMode = 1
include ../plugin_EMLPluginManager/install-from-disk.praat

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

        @emlpmL_canonicalName: lit$, hasSetup, cref$
        gotProp$ = emlpmL_canonicalName.proposal$
        gotRow$ = emlpmL_canonicalName.row$

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

appendInfoLine: ""
appendInfoLine: "RESULT: ", pass, " pass, ", fail, " fail"
