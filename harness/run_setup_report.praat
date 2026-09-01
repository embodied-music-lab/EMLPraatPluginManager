# ============================================================================
# Harness: installed-command report normative table + two whole-file checks
# ============================================================================
# Drives the REAL emlManagerParseSetupCommands over one synthetic setup.praat
# built from every input_line in setup_report.tsv, in order (so the per-depth
# title stack sees the same document a real setup.praat would), and checks
# each row's .kind$#/.text$# against expected_kind/expected_text. A row whose
# expected_kind is "ignored" (a comment line) contributes no output entry and
# is skipped without consuming one. Then two dedicated fixture files exercise
# the whole-file rules that a single row can't: rule 5 (zero registrations)
# and rule 4 (a mix of literal and computed titles, tallied on one line).
#
# Run headless:  ./praat --run harness/run_setup_report.praat
# ============================================================================

emlManager_harnessMode = 1
include ../plugin_EMLPraatPluginManager/install-from-disk.praat

tsv$ = "setup_report.tsv"
lines$# = readLinesFromFile$# (tsv$)
nRows = size (lines$#)

pass = 0
fail = 0
writeInfoLine: "=== installed-command report table: ", nRows, " rows ==="

# --- Build one combined setup.praat from every row's input_line, in order ---
# (Praat resolves a relative path against the running script's own folder,
# not the process's working directory, so these need no "harness/" prefix.)

combined$ = "setup_report_combined.praat"
writeFile: combined$, ""

inputLine$# = empty$# (nRows)
expKind$# = empty$# (nRows)
expText$# = empty$# (nRows)
nExpected = 0

for r from 1 to nRows
    fields$# = splitBy$# (lines$# [r], tab$)
    if size (fields$#) >= 3
        inputLine$# [r] = fields$# [1]
        expKind$# [r] = fields$# [2]
        expText$# [r] = fields$# [3]
        appendFileLine: combined$, inputLine$# [r]
        if expKind$# [r] <> "ignored"
            nExpected = nExpected + 1
        endif
    endif
endfor

@emlManagerParseSetupCommands: combined$
n = emlManagerParseSetupCommands.n

# The combined fixture deliberately includes computed-title rows, so the
# parser appends one tally line after all per-line rows (rule 4).
expTotal = nExpected + 1
if n = expTotal
    pass = pass + 1
    appendInfoLine: "PASS: total report lines = ", n, " (", nExpected,
        ... " per-row + 1 tally)"
else
    fail = fail + 1
    appendInfoLine: "FAIL: expected ", expTotal, " total report lines, got ", n
endif

outIdx = 0
for r from 1 to nRows
    if expKind$# [r] <> "" or expText$# [r] <> "" or inputLine$# [r] <> ""
        if expKind$# [r] <> "ignored"
            outIdx = outIdx + 1
            if outIdx <= n
                gotKind$ = emlManagerParseSetupCommands.kind$# [outIdx]
                gotText$ = emlManagerParseSetupCommands.text$# [outIdx]
            else
                gotKind$ = "<missing>"
                gotText$ = "<missing>"
            endif
            okKind = (gotKind$ = expKind$# [r])
            okText = (gotText$ = expText$# [r])
            if okKind = 1 and okText = 1
                pass = pass + 1
            else
                fail = fail + 1
                appendInfoLine: "FAIL row ", r, ": ", inputLine$# [r]
                if okKind = 0
                    appendInfoLine: "   kind: expected '", expKind$# [r],
                        ... "' got '", gotKind$, "'"
                endif
                if okText = 0
                    appendInfoLine: "   text: expected '", expText$# [r],
                        ... "' got '", gotText$, "'"
                endif
            endif
        endif
    endif
endfor

# The one line past the per-row entries is the rule-4 tally.
if n = expTotal
    tallyText$ = emlManagerParseSetupCommands.text$# [n]
    expTally$ = emlManager_rptComputedPrefix$ + string$ (3) + emlManager_rptComputedSuffix$
    if tallyText$ = expTally$
        pass = pass + 1
        appendInfoLine: "PASS: tally line = '", tallyText$, "'"
    else
        fail = fail + 1
        appendInfoLine: "FAIL: tally line expected '", expTally$, "' got '", tallyText$, "'"
    endif
endif

deleteFile: combined$

# --- Whole-file check: rule 5, zero registrations ---

appendInfoLine: ""
appendInfoLine: "--- whole-file check: rule 5 (zero registrations) ---"

fx5$ = "fixtures/setup_rule5_empty.praat"
@emlManagerParseSetupCommands: fx5$
if emlManagerParseSetupCommands.n = 1
    ... and emlManagerParseSetupCommands.text$# [1] = emlManager_rptNoCommands$
    pass = pass + 1
    appendInfoLine: "PASS: rule 5 fixture -> '", emlManagerParseSetupCommands.text$# [1], "'"
else
    fail = fail + 1
    appendInfoLine: "FAIL: rule 5 fixture -- n=", emlManagerParseSetupCommands.n,
        ... " text[1]='", emlManagerParseSetupCommands.text$# [1], "'"
endif

# --- Whole-file check: rule 4, literal and computed lines mixed ---

appendInfoLine: ""
appendInfoLine: "--- whole-file check: rule 4 (literal + computed mixed) ---"

fx4$ = "fixtures/setup_rule4_mixed.praat"
@emlManagerParseSetupCommands: fx4$
expectedRule4Kind$# = { "menu", "action", "computed", "computed", "" }
expectedRule4Text$# = {
    ... "Adds ""Alpha"" to the Praat menu in the Objects window.",
    ... "Adds a ""Beta"" button that appears when you select a Sound.",
    ... "",
    ... "",
    ... emlManager_rptComputedPrefix$ + string$ (2) + emlManager_rptComputedSuffix$
    ... }
if emlManagerParseSetupCommands.n = 5
    pass = pass + 1
    appendInfoLine: "PASS: rule 4 fixture -- 5 report lines"
    for i4 from 1 to 5
        gotK$ = emlManagerParseSetupCommands.kind$# [i4]
        gotT$ = emlManagerParseSetupCommands.text$# [i4]
        if gotK$ = expectedRule4Kind$# [i4] and gotT$ = expectedRule4Text$# [i4]
            pass = pass + 1
        else
            fail = fail + 1
            appendInfoLine: "FAIL: rule 4 fixture row ", i4, " -- kind '", gotK$,
                ... "' text '", gotT$, "'"
        endif
    endfor
else
    fail = fail + 1
    appendInfoLine: "FAIL: rule 4 fixture -- expected 5 report lines, got ",
        ... emlManagerParseSetupCommands.n
endif


# --- Regression fixture: six real-world plugin setup.praat files ---
# cpran/plugin_utils, plugin_tgutils, plugin_selection, plugin_twopass;
# jjatria/plugin_jjatools; AERodgers/plugin_AERoPlot (same six as the E2E
# drive record). Each *_expected.tsv is the parser's own output, recorded
# after a human eyeball -- a future parser change that disagrees fails here.
appendInfoLine: ""
appendInfoLine: "--- regression fixture: six real-world plugins ---"

regNames$# = { "plugin_utils", "plugin_tgutils", "plugin_selection",
    ... "plugin_twopass", "plugin_jjatools", "plugin_AERoPlot" }

for regI from 1 to size (regNames$#)
    regName$ = regNames$# [regI]
    regSetup$ = "fixtures/regression/" + regName$ + "_setup.praat"
    regExpected$ = "fixtures/regression/" + regName$ + "_expected.tsv"

    @emlManagerParseSetupCommands: regSetup$
    regN = emlManagerParseSetupCommands.n

    regExpLines$# = readLinesFromFile$# (regExpected$)
    regExpN = size (regExpLines$#)

    if regN = regExpN
        pass = pass + 1
        regRowsOk = 1
        for regJ from 1 to regN
            regFields$# = splitBy$# (regExpLines$# [regJ], tab$)
            regExpKind$ = regFields$# [1]
            if size (regFields$#) >= 2
                regExpText$ = regFields$# [2]
            else
                regExpText$ = ""
            endif
            regGotKind$ = emlManagerParseSetupCommands.kind$# [regJ]
            regGotText$ = emlManagerParseSetupCommands.text$# [regJ]
            if regGotKind$ = regExpKind$ and regGotText$ = regExpText$
                pass = pass + 1
            else
                fail = fail + 1
                regRowsOk = 0
                appendInfoLine: "FAIL ", regName$, " row ", regJ, ": expected [",
                    ... regExpKind$, "] ", regExpText$
                appendInfoLine: "   got [", regGotKind$, "] ", regGotText$
            endif
        endfor
        if regRowsOk = 1
            appendInfoLine: "PASS: ", regName$, " -- ", regN, " report lines match golden"
        endif
    else
        fail = fail + 1
        appendInfoLine: "FAIL: ", regName$, " -- expected ", regExpN,
            ... " report lines, got ", regN
    endif
endfor

appendInfoLine: ""
appendInfoLine: "RESULT: ", pass, " pass, ", fail, " fail"
