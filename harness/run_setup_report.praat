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
    nComputedExpected = 0
    for r from 1 to nRows
        if expKind$# [r] = "computed"
            nComputedExpected = nComputedExpected + 1
        endif
    endfor
    expTally$ = emlManager_rptComputedPrefix$ + string$ (nComputedExpected) + emlManager_rptComputedSuffix$
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

# --- One command counter: the checklist's "adds N commands" and the report ---
# emlManagerCheckSetupPresent (the checklist) reads its count from the report
# parser, so the two cannot disagree. Each expected count below was derived
# by reading the fixture's setup.praat (after joining "..." continuation
# lines, ignoring "#" lines): the number of Add menu command / Add action
# command registrations that a user can click, with any leading modifiers
# removed. Left out of the count: a "--" menu line (a title that starts with
# a hyphen is a separator), a blank-title line (a spacer), a menu line with
# an empty script (a submenu title; the report lists it as a submenu), and
# an action line with an empty script (a heading label Praat does not let
# you click; the report omits it). Per fixture:
#   utils      3 menu lines, 1 submenu title                    -> 2
#   tgutils    4 menu lines, 1 submenu title; 12 buttons        -> 3 + 12 = 15
#   selection  7 menu lines, 1 submenu title; 2 action lines,
#              1 heading                                        -> 6 + 1 = 7
#   twopass    2 menu lines, 1 submenu title; 1 button          -> 1 + 1 = 2
#   jjatools   16 menu lines, 4 submenu titles; 20 buttons      -> 12 + 20 = 32
#   AERoPlot   3 menu lines: "--" (separator), 1 submenu title, 1
#              command; 12 action lines: 3 blank-title spacers, 3 headings,
#              6 buttons (3 for a Table, 2 for a Sound and a TextGrid, 1
#              for a Sound)                                     -> 1 + 6 = 7
#              (the report adds 1 submenu line, which is not counted)

appendInfoLine: ""
appendInfoLine: "--- one counter: checklist count = report count = hand count ---"

# In regNames$# order: utils, tgutils, selection, twopass, jjatools, AERoPlot.
expCounts# = { 2, 15, 7, 2, 32, 7 }
cntScratch$ = "/tmp/eml_pm_harness_setup_report"
runSystem_nocheck: "rm -rf " + cntScratch$
createFolder: cntScratch$
for cntI from 1 to size (regNames$#)
    cntName$ = regNames$# [cntI]
    cntText$ = readFile$ ("fixtures/regression/" + cntName$ + "_setup.praat")
    writeFile: cntScratch$ + "/setup.praat", cntText$
    @emlManagerCheckSetupPresent: cntScratch$
    @emlManagerParseSetupCommands: cntScratch$ + "/setup.praat"
    cntReport = 0
    for cntR from 1 to emlManagerParseSetupCommands.n
        if emlManagerParseSetupCommands.kind$# [cntR] <> ""
            ... and emlManagerParseSetupCommands.kind$# [cntR] <> "submenu"
            cntReport = cntReport + 1
        endif
    endfor
    if emlManagerCheckSetupPresent.commandCount = expCounts# [cntI]
        ... and cntReport = expCounts# [cntI]
        pass = pass + 1
        appendInfoLine: "PASS: ", cntName$, " -- checklist ", emlManagerCheckSetupPresent.commandCount,
            ... ", report ", cntReport, ", hand count ", expCounts# [cntI]
    else
        fail = fail + 1
        appendInfoLine: "FAIL: ", cntName$, " -- checklist ", emlManagerCheckSetupPresent.commandCount,
            ... ", report ", cntReport, ", hand count ", expCounts# [cntI]
    endif
endfor
runSystem_nocheck: "rm -rf " + cntScratch$

# The edge cases the two old counters disagreed on, in one fixture: a
# tab-indented nocheck line (1), a two-space nocheck line (0), a prose line
# (0), a modern five-argument line (0), and a legacy five-argument line (0:
# it has no script, so it is a submenu title and not a command).
edgeScratch$ = "/tmp/eml_pm_harness_setup_report_edge"
runSystem_nocheck: "rm -rf " + edgeScratch$
createFolder: edgeScratch$
writeFileLine: edgeScratch$ + "/setup.praat", tab$ + "nocheck Add menu command: ""Objects"", ""New"", ""Tabbed"", """", 0, ""a.praat"""
appendFileLine: edgeScratch$ + "/setup.praat", "nocheck  Add menu command: ""Objects"", ""New"", ""Two"", """", 0, ""a.praat"""
appendFileLine: edgeScratch$ + "/setup.praat", "Add menu commands: this line is prose"
appendFileLine: edgeScratch$ + "/setup.praat", "Add menu command: ""Objects"", ""New"", ""Short"", """", 0"
appendFileLine: edgeScratch$ + "/setup.praat", "Add menu command... ""Objects"" ""New"" ""Legacy short"" """" 0"
@emlManagerCheckSetupPresent: edgeScratch$
if emlManagerCheckSetupPresent.commandCount = 1
    pass = pass + 1
    appendInfoLine: "PASS: edge-case fixture counts 1"
else
    fail = fail + 1
    appendInfoLine: "FAIL: edge-case fixture counts ", emlManagerCheckSetupPresent.commandCount, ", expected 1"
endif
runSystem_nocheck: "rm -rf " + edgeScratch$

# --- Modifier stripping follows Praat's own rule (measured, 7.0.03) ---
appendInfoLine: ""
appendInfoLine: "--- modifier stripping: one space after each keyword ---"
@emlManagerStripCommandModifiers: "nocheck nowarn Add menu command"
if emlManagerStripCommandModifiers.rest$ = "Add menu command"
    pass = pass + 1
    appendInfoLine: "PASS: stacked modifiers, one space each, are removed"
else
    fail = fail + 1
    appendInfoLine: "FAIL: stacked modifiers -- rest '", emlManagerStripCommandModifiers.rest$, "'"
endif
@emlManagerStripCommandModifiers: "nocheck  Add menu command"
if emlManagerStripCommandModifiers.rest$ = " Add menu command"
    pass = pass + 1
    appendInfoLine: "PASS: a second space stays, so the command text starts with a blank"
else
    fail = fail + 1
    appendInfoLine: "FAIL: two spaces -- rest '", emlManagerStripCommandModifiers.rest$, "'"
endif
@emlManagerStripCommandModifiers: "nowarn" + tab$ + "Add menu command"
if emlManagerStripCommandModifiers.rest$ = "nowarn" + tab$ + "Add menu command"
    pass = pass + 1
    appendInfoLine: "PASS: a tab after a keyword is not a modifier separator"
else
    fail = fail + 1
    appendInfoLine: "FAIL: tab after keyword -- rest '", emlManagerStripCommandModifiers.rest$, "'"
endif

# --- Separators and spacers are not commands (golden cases) ---
# Each line is written alone and must count 0: a modern quoted "--", a
# legacy quoted "--", a legacy UNQUOTED -- (Praat 7.0.03 accepts it), an
# action button with a single "-", and a menu or action registration with
# an empty title (a spacer), a menu registration with no script (a submenu
# title) and an action registration with no script (a heading label). A real
# command on its own line counts 1.
appendInfoLine: ""
appendInfoLine: "--- separators, spacers, submenu titles and heading labels are not commands ---"
sepLine$# = {
    ... "Add menu command: ""Objects"", ""Praat"", ""-- sep --"", """", 0, ""a.praat""",
    ... "Add menu command... Objects Praat ""--"" """" 0",
    ... "Add menu command... Objects Praat -- """" 0",
    ... "Add action command: ""Table"", 1, """", 0, """", 0, ""-"", """", 0, """"",
    ... "Add menu command: ""Objects"", ""Praat"", """", """", 0, ""a.praat""",
    ... "Add menu command: ""Objects"", ""Praat"", "" "", """", 0, ""a.praat""",
    ... "Add action command: ""Table"", 1, """", 0, """", 0, "" "", """", 0, """"",
    ... "Add menu command: ""Objects"", ""Praat"", ""Real"", """", 0, ""a.praat""",
    ... "Add menu command: ""Objects"", ""Praat"", ""Submenu title"", """", 0, """"",
    ... "Add action command: ""Table"", 1, """", 0, """", 0, ""Heading label"", """", 0, """"" }
sepExpect# = { 0, 0, 0, 0, 0, 0, 0, 1, 0, 0 }
sepScratch$ = "/tmp/eml_pm_harness_setup_report_sep"
runSystem_nocheck: "rm -rf " + sepScratch$
createFolder: sepScratch$
for sepI from 1 to size (sepLine$#)
    writeFileLine: sepScratch$ + "/setup.praat", sepLine$# [sepI]
    @emlManagerCheckSetupPresent: sepScratch$
    if emlManagerCheckSetupPresent.commandCount = sepExpect# [sepI]
        pass = pass + 1
        appendInfoLine: "PASS: separator/spacer case ", sepI, " counts ", sepExpect# [sepI]
    else
        fail = fail + 1
        appendInfoLine: "FAIL: separator/spacer case ", sepI, " counts ",
            ... emlManagerCheckSetupPresent.commandCount, ", expected ", sepExpect# [sepI]
    endif
endfor
runSystem_nocheck: "rm -rf " + sepScratch$

# --- Rendered height of a line that the window wraps itself ---
# A line longer than the wrap width is one unbreakable word, which the
# window wraps onto more rows; each extra row adds a plain comment's height.
appendInfoLine: ""
appendInfoLine: "--- a word wider than the wrap width weighs extra rows ---"
@emlManagerPageMetrics
longWord$ = "plugin_LongNameABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789__no-version."
@emlManagerLinePx: longWord$
longPx = emlManagerLinePx.px
@emlManagerLinePx: "Will be archived."
shortPx = emlManagerLinePx.px
if length (longWord$) > emlManager_wrapWidth and longPx = shortPx + emlManagerPageMetrics.commentPx
    pass = pass + 1
    appendInfoLine: "PASS: a ", length (longWord$), "-character word weighs two rows (", longPx, " px, one row ", shortPx, ")"
else
    fail = fail + 1
    appendInfoLine: "FAIL: long word weighs ", longPx, " px, one row ", shortPx
endif
@emlManagerLinePx: "Short words only"
if emlManagerLinePx.px = emlManagerPageMetrics.commentPx
    pass = pass + 1
    appendInfoLine: "PASS: a line within the wrap width weighs one row"
else
    fail = fail + 1
    appendInfoLine: "FAIL: short line weighs ", emlManagerLinePx.px
endif

# --- The Installation complete line list never splits an entry ---
# The real list builder, over the six regression fixtures reported one after
# another (a long list, many page breaks), walked with the real page budget.
# No page may start on a continuation line, a header ("<folder> adds:") may
# not end a page, and the restart line may not start one.
appendInfoLine: ""
appendInfoLine: "--- Installation complete: no entry or header split across pages ---"
@emlManagerPageMetrics
nCl = size (regNames$#)
clScratch$ = "/tmp/eml_pm_harness_setup_report_pages"
runSystem_nocheck: "rm -rf " + clScratch$
createFolder: clScratch$
clSummary$# = empty$# (nCl)
clShow# = zero# (nCl)
clFolder$# = empty$# (nCl)
clPath$# = empty$# (nCl)
for clI from 1 to nCl
    createFolder: clScratch$ + "/" + regNames$# [clI]
    writeFile: clScratch$ + "/" + regNames$# [clI] + "/setup.praat",
        ... readFile$ ("fixtures/regression/" + regNames$# [clI] + "_setup.praat")
    clSummary$# [clI] = regNames$# [clI] + " version 1.0 installed."
    clShow# [clI] = 1
    clFolder$# [clI] = regNames$# [clI]
    clPath$# [clI] = clScratch$ + "/" + regNames$# [clI] + "/setup.praat"
endfor
@emlManagerBuildCompleteLines: clSummary$#, clShow#, clFolder$#, clPath$#, nCl
clN = emlManagerBuildCompleteLines.n
clLines$# = emlManagerBuildCompleteLines.lines$#
clKeep# = emlManagerBuildCompleteLines.keep#
clPx# = zero# (clN)
for clI from 1 to clN
    @emlManagerLinePx: clLines$# [clI]
    clPx# [clI] = emlManagerLinePx.px
endfor
@emlManagerPageBudgetWalk: clPx#, clKeep#, clN, emlManagerPageMetrics.budgetPx, 0, 0
clBad = 0
for clP from 1 to emlManagerPageBudgetWalk.nPages
    clFirst = emlManagerPageBudgetWalk.pageStartItem# [clP]
    clLast = emlManagerPageBudgetWalk.pageEndItem# [clP]
    if clKeep# [clFirst] = 1
        clBad = clBad + 1
    endif
    if endsWith (clLines$# [clLast], emlManager_rptHeaderSuffix$)
        clBad = clBad + 1
    endif
endfor
if clBad = 0 and emlManagerPageBudgetWalk.nPages > 3
    pass = pass + 1
    appendInfoLine: "PASS: ", clN, " lines in ", emlManagerPageBudgetWalk.nPages,
        ... " pages -- none starts on a continuation, none ends on a header"
else
    fail = fail + 1
    appendInfoLine: "FAIL: complete-dialog pages -- ", clBad, " bad boundary(ies) in ",
        ... emlManagerPageBudgetWalk.nPages, " pages"
endif
clRestart = clN
if clKeep# [clRestart] = 1 and clLines$# [clRestart] = emlManager_msgRestart$ and clLines$# [clRestart - 1] = ""
    pass = pass + 1
    appendInfoLine: "PASS: the restart line is kept with the blank line above it"
else
    fail = fail + 1
    appendInfoLine: "FAIL: restart line keep mark"
endif
runSystem_nocheck: "rm -rf " + clScratch$

appendInfoLine: ""
appendInfoLine: "RESULT: ", pass, " pass, ", fail, " fail"
