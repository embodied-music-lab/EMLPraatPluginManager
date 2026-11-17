# ============================================================================
# Harness: create-install-file.praat (generator) and its generated wrapper
# ============================================================================
# Two legs. Leg 1 drives the GENERATOR's own work procedures directly
# (create-install-file.praat's own harness-mode guard, exactly the pattern
# remove-plugin.praat and install-from-disk.praat use). Leg 2 generates a
# real wrapper for the fixture plugin below, then includes THAT generated
# file under ITS OWN harness flag (wrapHarnessMode, declared inside the
# wrapper's own static template) and drives its work procedures the same
# way -- dialogs cannot be driven headlessly at all in this build
# (beginPause/endPause silently stop script execution), which is exactly
# why every procedure on both sides takes its inputs as plain arguments
# instead of reading dialog state.
#
# Run headless:  ./praat --run harness/run_wrapper_installer.praat
# ============================================================================

emlManagerCif_harnessMode = 1
include ../plugin_EMLPraatPluginManager/create-install-file.praat

pass = 0
fail = 0
writeInfoLine: "=== create-install-file.praat (generator + generated wrapper) ==="

scratchRoot$ = "/tmp/eml_pm_harness_wrapper"
q$ = """"
runSystem_nocheck: "rm -rf " + q$ + scratchRoot$ + q$
createFolder: scratchRoot$

fixtureSrc$ = "fixtures/wrapper_plugin"

# ----------------------------------------------------------------------------
# Recursive byte-for-byte comparison of two folders via the system `diff`,
# read back through the same nested-process/exit-code-file pattern
# run_remove_plugin.praat's Check 3 uses (no in-script try/catch in Praat,
# so a supervising process's own exit status is how a failure is observed).
procedure emlHarnessDirsIdentical: .a$, .b$
    .exitFile$ = scratchRoot$ + "/diff_exit.txt"
    deleteFile: .exitFile$
    .wrapper$ = scratchRoot$ + "/diff_wrapper.sh"
    writeFileLine: .wrapper$, "#!/bin/sh"
    appendFileLine: .wrapper$, "diff -r " + q$ + .a$ + q$ + " " + q$ + .b$ + q$ + " >/dev/null 2>&1"
    appendFileLine: .wrapper$, "echo $? > " + q$ + .exitFile$ + q$
    runSystem_nocheck: "sh " + q$ + .wrapper$ + q$
    .identical = 0
    if fileReadable (.exitFile$)
        .codeLines$# = readLinesFromFile$# (.exitFile$)
        if number (.codeLines$# [1]) = 0
            .identical = 1
        endif
    endif
endproc

# ----------------------------------------------------------------------------
# True iff every line of .lines$# containing "runSystem_nocheck:" is built
# ONLY from the pinned components (the quote-holder variable, the three
# path variables the wrapper's own rename/delete/place procedures use, the
# literal shell command words, "/.", spaces, "+", and quote characters) --
# i.e. once every allowed token is blanked out, no "$" (the start of any
# OTHER variable reference) remains. Returns the first offending line too.
procedure emlHarnessAuditSystemLines: .lines$#
    .ok = 1
    .offender$ = ""
    .allowed$# = { ".q$", ".src$", ".dst$", ".target$", ".scriptFolder$",
        ... """mv """, """move """, """rm -rf """, """rmdir /s /q """,
        ... """cp -R """, """xcopy /E /I /Q """, """/.""", "+", """ """ }
    for .i to size (.lines$#)
        .ln$ = .lines$# [.i]
        if index (.ln$, "runSystem_nocheck:") > 0
            .residual$ = .ln$
            for .a to size (.allowed$#)
                .residual$ = replace$ (.residual$, .allowed$# [.a], "", 0)
            endfor
            if index (.residual$, "$") > 0
                .ok = 0
                if .offender$ = ""
                    .offender$ = .ln$
                endif
            endif
        endif
    endfor
endproc

# ============================================================================
# Leg 1: the generator's own work procedures
# ============================================================================

appendInfoLine: ""
appendInfoLine: "--- generator: version-field validation ---"

versionCases$# = { "1.2.0", "1.0", "12", "1.2.a", "abc", "", "1 2", "1..2", "." }
versionExpect# = { 1, 1, 1, 0, 0, 0, 0, 1, 0 }
versionAllOk = 1
for vi to size (versionCases$#)
    @emlManagerCifVersionValid: versionCases$# [vi]
    if emlManagerCifVersionValid.ok <> versionExpect# [vi]
        versionAllOk = 0
        appendInfoLine: "  mismatch on '", versionCases$# [vi], "': got ",
            ... emlManagerCifVersionValid.ok, " want ", versionExpect# [vi]
    endif
endfor
if versionAllOk = 1
    pass = pass + 1
    appendInfoLine: "PASS: version-field validation matches the pinned rule",
        ... " (digits/periods, at least one digit) across ", size (versionCases$#), " cases"
else
    fail = fail + 1
    appendInfoLine: "FAIL: version-field validation mismatched (see above)"
endif

appendInfoLine: ""
appendInfoLine: "--- generator: VERSION file written/overwritten ---"

check2Dir$ = scratchRoot$ + "/check2"
createFolder: check2Dir$
@emlManagerCifWriteVersion: check2Dir$, "3.4.5"
if fileReadable (check2Dir$ + "/VERSION")
    v1$# = readLinesFromFile$# (check2Dir$ + "/VERSION")
    if v1$# [1] = "3.4.5"
        pass = pass + 1
        appendInfoLine: "PASS: VERSION created when absent ('", v1$# [1], "')"
    else
        fail = fail + 1
        appendInfoLine: "FAIL: VERSION content wrong after creation: '", v1$# [1], "'"
    endif
else
    fail = fail + 1
    appendInfoLine: "FAIL: VERSION was not created"
endif

@emlManagerCifWriteVersion: check2Dir$, "9.9.9"
v2$# = readLinesFromFile$# (check2Dir$ + "/VERSION")
if v2$# [1] = "9.9.9" and size (v2$#) = 1
    pass = pass + 1
    appendInfoLine: "PASS: VERSION overwritten (one line, '", v2$# [1], "')"
else
    fail = fail + 1
    appendInfoLine: "FAIL: VERSION not cleanly overwritten -- got '", v2$# [1], "', ",
        ... size (v2$#), " line(s)"
endif

appendInfoLine: ""
appendInfoLine: "--- generator: part 2 folder-source validation order ---"

check1bRoot$ = scratchRoot$ + "/check1b"
createFolder: check1bRoot$

createFolder: check1bRoot$ + "/NotAPlugin"
@emlManagerCifValidateFolderSource: check1bRoot$ + "/NotAPlugin"
if emlManagerCifValidateFolderSource.result$ = "bad_prefix"
    ... and emlManagerCifValidateFolderSource.name$ = "NotAPlugin"
    pass = pass + 1
    appendInfoLine: "PASS: (a) a folder not named plugin_* is refused as 'bad_prefix'"
else
    fail = fail + 1
    appendInfoLine: "FAIL: (a) bad-prefix case -- got result='",
        ... emlManagerCifValidateFolderSource.result$, "'"
endif

createFolder: check1bRoot$ + "/plugin_NoSetup"
@emlManagerCifValidateFolderSource: check1bRoot$ + "/plugin_NoSetup"
if emlManagerCifValidateFolderSource.result$ = "no_setup"
    pass = pass + 1
    appendInfoLine: "PASS: (b) a plugin_* folder with no top-level setup.praat is refused as 'no_setup'"
else
    fail = fail + 1
    appendInfoLine: "FAIL: (b) no-setup case -- got result='",
        ... emlManagerCifValidateFolderSource.result$, "'"
endif

createFolder: check1bRoot$ + "/BothWrong"
@emlManagerCifValidateFolderSource: check1bRoot$ + "/BothWrong"
if emlManagerCifValidateFolderSource.result$ = "bad_prefix"
    pass = pass + 1
    appendInfoLine: "PASS: validation ORDER -- a folder failing both (a) and (b) reports (a) first"
else
    fail = fail + 1
    appendInfoLine: "FAIL: validation order -- expected 'bad_prefix' to win, got '",
        ... emlManagerCifValidateFolderSource.result$, "'"
endif

createFolder: check1bRoot$ + "/plugin_NonAsciiCaf" + unicode$ (233)
writeFileLine: check1bRoot$ + "/plugin_NonAsciiCaf" + unicode$ (233) + "/setup.praat", "# ok"
@emlManagerCifValidateFolderSource: check1bRoot$ + "/plugin_NonAsciiCaf" + unicode$ (233)
if emlManagerCifValidateFolderSource.result$ = "non_ascii"
    pass = pass + 1
    appendInfoLine: "PASS: (c) a plugin_* folder with setup.praat but a non-ASCII name is refused as 'non_ascii' -- reaches (c) only after (a) and (b) both pass"
else
    fail = fail + 1
    appendInfoLine: "FAIL: (c) non-ASCII case -- got result='",
        ... emlManagerCifValidateFolderSource.result$, "'"
endif

createFolder: check1bRoot$ + "/plugin_Good"
writeFileLine: check1bRoot$ + "/plugin_Good/setup.praat", "# ok"
@emlManagerCifValidateFolderSource: check1bRoot$ + "/plugin_Good"
okCase1 = emlManagerCifValidateFolderSource.result$ = "ok"
    ... and emlManagerCifValidateFolderSource.name$ = "plugin_Good"
@emlManagerCifValidateFolderSource: check1bRoot$ + "/plugin_Good/"
okCase2 = emlManagerCifValidateFolderSource.result$ = "ok"
    ... and emlManagerCifValidateFolderSource.name$ = "plugin_Good"
if okCase1 = 1 and okCase2 = 1
    pass = pass + 1
    appendInfoLine: "PASS: a valid plugin_* folder (with and without a trailing '/') validates 'ok'"
else
    fail = fail + 1
    appendInfoLine: "FAIL: valid-folder case -- no-slash ok=", okCase1, " trailing-slash ok=", okCase2
endif

# The interactive cancel path (chooseFolder$ returning "") cannot be driven
# headlessly (dialogs silently stop script execution in this build) -- the
# main sequence's own cancel check is the single inline "chosenFolder$ = """"
# comparison BEFORE emlManagerCifValidateFolderSource is ever called, so
# there is no separate procedure-level surface for it; verified instead by
# the GUI drive (harness/evidence/v072_chooser_*). As the nearest headless
# proxy, confirm the validator itself does not crash and resolves
# deterministically on the empty string, in case a future caller ever
# reaches it without the guard.
@emlManagerCifValidateFolderSource: ""
if emlManagerCifValidateFolderSource.result$ = "bad_prefix"
    ... and emlManagerCifValidateFolderSource.name$ = ""
    pass = pass + 1
    appendInfoLine: "PASS: the validator resolves the empty-path edge case deterministically",
        ... " (result='bad_prefix', name='') -- the real cancel path itself is",
        ... " the main sequence's own inline check before this procedure is called, GUI-verified"
else
    fail = fail + 1
    appendInfoLine: "FAIL: empty-path edge case -- got result='",
        ... emlManagerCifValidateFolderSource.result$, "' name='",
        ... emlManagerCifValidateFolderSource.name$, "'"
endif

appendInfoLine: ""
appendInfoLine: "--- generator: manifest and report-line assembly on the fixture ---"

check3Plugin$ = scratchRoot$ + "/check3/plugin_WrapTest"
createFolder: scratchRoot$ + "/check3"
runSystem_nocheck: "cp -R " + q$ + fixtureSrc$ + q$ + " " + q$ + check3Plugin$ + q$

@emlManagerCifBuildManifest: check3Plugin$, "install-WrapTest.praat", scratchRoot$ + "/check3_scratch.txt"
expectManifest$# = { "install-WrapTest.praat", "main.praat", "setup.praat", "sub/helper.praat" }
manifestOk = 0
if emlManagerCifBuildManifest.n = size (expectManifest$#)
    manifestOk = 1
    for mi to size (expectManifest$#)
        if emlManagerCifBuildManifest.paths$# [mi] <> expectManifest$# [mi]
            manifestOk = 0
        endif
    endfor
endif
if manifestOk = 1
    pass = pass + 1
    appendInfoLine: "PASS: manifest is the sorted file list plus the wrapper's own name (",
        ... emlManagerCifBuildManifest.n, " entries)"
else
    fail = fail + 1
    appendInfoLine: "FAIL: manifest mismatch -- got ", emlManagerCifBuildManifest.n, " entries:"
    for mi to emlManagerCifBuildManifest.n
        appendInfoLine: "    ", emlManagerCifBuildManifest.paths$# [mi]
    endfor
endif

# Regenerating over an EXISTING wrapper file must not duplicate its entry.
writeFileLine: check3Plugin$ + "/install-WrapTest.praat", "# stale wrapper from a previous generation"
@emlManagerCifBuildManifest: check3Plugin$, "install-WrapTest.praat", scratchRoot$ + "/check3_scratch2.txt"
wrapperCount = 0
for mi to emlManagerCifBuildManifest.n
    if emlManagerCifBuildManifest.paths$# [mi] = "install-WrapTest.praat"
        wrapperCount = wrapperCount + 1
    endif
endfor
if wrapperCount = 1 and emlManagerCifBuildManifest.n = size (expectManifest$#)
    pass = pass + 1
    appendInfoLine: "PASS: regenerating over an existing wrapper lists its name exactly once"
else
    fail = fail + 1
    appendInfoLine: "FAIL: regeneration duplicated or dropped the wrapper's own manifest entry",
        ... " (count=", wrapperCount, ", n=", emlManagerCifBuildManifest.n, ")"
endif
deleteFile: check3Plugin$ + "/install-WrapTest.praat"

@emlManagerCifBuildReportLines: check3Plugin$ + "/setup.praat", emlManager_wrapWidth
reportOk = 0
if emlManagerCifBuildReportLines.n = 2
    if index (emlManagerCifBuildReportLines.lines$# [1], "Wrap Test") > 0
        ... and index (emlManagerCifBuildReportLines.lines$# [2], "Act...") > 0
        reportOk = 1
    endif
endif
if reportOk = 1
    pass = pass + 1
    appendInfoLine: "PASS: report lines name both fixture commands (",
        ... emlManagerCifBuildReportLines.n, " lines)"
else
    fail = fail + 1
    appendInfoLine: "FAIL: report lines wrong -- n=", emlManagerCifBuildReportLines.n
    for ri to emlManagerCifBuildReportLines.n
        appendInfoLine: "    [", emlManagerCifBuildReportLines.lines$# [ri], "]"
    endfor
endif

appendInfoLine: ""
appendInfoLine: "--- generator: wrapper generation, baked content, ASCII, canon byte-match ---"

@emlManagerCifGenerateWrapper: check3Plugin$, "plugin_WrapTest", "1.2.0", scratchRoot$ + "/check4_scratch.txt"
if emlManagerCifGenerateWrapper.ok = 1
    ... and emlManagerCifGenerateWrapper.wrapperFileName$ = "install-WrapTest.praat"
    pass = pass + 1
    appendInfoLine: "PASS: generation succeeded, wrapper file name = '",
        ... emlManagerCifGenerateWrapper.wrapperFileName$, "'"
else
    fail = fail + 1
    appendInfoLine: "FAIL: generation did not succeed as expected (ok=",
        ... emlManagerCifGenerateWrapper.ok, ")"
endif

wrapperPath$ = check3Plugin$ + "/" + emlManagerCifGenerateWrapper.wrapperFileName$
wrapperLines$# = readLinesFromFile$# (wrapperPath$)

bakedNameOk = 0
bakedVersionOk = 0
for li to size (wrapperLines$#)
    if wrapperLines$# [li] = "wrapFolderName$ = ""plugin_WrapTest"""
        bakedNameOk = 1
    endif
    if wrapperLines$# [li] = "wrapVersion$ = ""1.2.0"""
        bakedVersionOk = 1
    endif
endfor
if bakedNameOk = 1 and bakedVersionOk = 1
    pass = pass + 1
    appendInfoLine: "PASS: the generated wrapper bakes the true folder name and the version"
else
    fail = fail + 1
    appendInfoLine: "FAIL: baked name/version line missing -- name=", bakedNameOk,
        ... " version=", bakedVersionOk
endif

# The report's keep-with-previous marks are baked beside the lines: one mark
# per line (a one-line entry is 0), so the wrapper's page walk keeps each
# entry whole.
bakedKeepOk = 0
for li to size (wrapperLines$#)
    if wrapperLines$# [li] = "wrapReportKeep# = { 0, 0 }"
        bakedKeepOk = 1
    endif
endfor
if bakedKeepOk = 1
    pass = pass + 1
    appendInfoLine: "PASS: the wrapper bakes one keep mark per report line"
else
    fail = fail + 1
    appendInfoLine: "FAIL: baked keep marks missing or wrong"
endif

# One cancel message per command: Create install file says so, not
# "Installation cancelled.".
if emlManagerCif_msgCancelled$ = "Install file creation cancelled."
    ... and emlManagerCif_msgCancelled$ <> emlManager_msgCancelled$
    pass = pass + 1
    appendInfoLine: "PASS: Create install file cancels with its own message"
else
    fail = fail + 1
    appendInfoLine: "FAIL: Create install file cancel message is '", emlManagerCif_msgCancelled$, "'"
endif

if emlManagerCifGenerateWrapper.manifestCount = size (expectManifest$#)
    ... and emlManagerCifGenerateWrapper.reportCount = 2
    pass = pass + 1
    appendInfoLine: "PASS: manifest count (", emlManagerCifGenerateWrapper.manifestCount,
        ... ") and report-line count (", emlManagerCifGenerateWrapper.reportCount, ") are correct"
else
    fail = fail + 1
    appendInfoLine: "FAIL: manifest/report counts wrong -- manifest=",
        ... emlManagerCifGenerateWrapper.manifestCount, " report=", emlManagerCifGenerateWrapper.reportCount
endif

# Pure ASCII: same nested-process technique as the dirs-identical check --
# `grep -P` finds any byte outside the printable-ASCII-plus-whitespace
# range; a match (exit 0) means the wrapper is NOT pure ASCII.
asciiExitFile$ = scratchRoot$ + "/ascii_exit.txt"
deleteFile: asciiExitFile$
asciiWrapper$ = scratchRoot$ + "/ascii_check.sh"
writeFileLine: asciiWrapper$, "#!/bin/sh"
appendFileLine: asciiWrapper$, "grep -qP ""[^\x09\x0A\x0D\x20-\x7E]"" " + q$ + wrapperPath$ + q$
appendFileLine: asciiWrapper$, "echo $? > " + q$ + asciiExitFile$ + q$
runSystem_nocheck: "sh " + q$ + asciiWrapper$ + q$
asciiExit$# = readLinesFromFile$# (asciiExitFile$)
if number (asciiExit$# [1]) = 1
    pass = pass + 1
    appendInfoLine: "PASS: the generated wrapper is pure ASCII"
else
    fail = fail + 1
    appendInfoLine: "FAIL: the generated wrapper contains a non-ASCII byte"
endif

# Embedded canon procedures byte-match the generator's own extraction from
# install-from-disk.praat -- run the SAME extraction the generator itself
# used and confirm the exact block is present, contiguous, in the wrapper.
procedure emlHarnessBlockInWrapper: .wrapperLines$#, .block$#, .blockN
    .found = 0
    .total = size (.wrapperLines$#)
    .i = 1
    while .found = 0 and .i <= .total - .blockN + 1
        .match = 1
        for .k to .blockN
            if .wrapperLines$# [.i + .k - 1] <> .block$# [.k]
                .match = 0
            endif
        endfor
        if .match = 1
            .found = 1
        endif
        .i = .i + 1
    endwhile
endproc

@emlManagerCifReadInstallerSource
sourceLines$# = emlManagerCifReadInstallerSource.lines$#

canonAllMatch = 1
canonNames$# = { "emlManagerIsInstalled", "emlManagerIsNumericToken",
    ... "emlManagerCompareVersions", "emlManagerWrapText" }
for ci to size (canonNames$#)
    @emlManagerCifExtractBlock: sourceLines$#, canonNames$# [ci]
    if emlManagerCifExtractBlock.found = 0
        canonAllMatch = 0
        appendInfoLine: "  could not extract ", canonNames$# [ci], " from install-from-disk.praat"
    else
        @emlHarnessBlockInWrapper: wrapperLines$#, emlManagerCifExtractBlock.block$#,
            ... emlManagerCifExtractBlock.n
        if emlHarnessBlockInWrapper.found = 0
            canonAllMatch = 0
            appendInfoLine: "  ", canonNames$# [ci], " not byte-identical in the generated wrapper"
        endif
    endif
endfor
@emlManagerCifExtractLine: sourceLines$#, "emlManager_setupFile$ ="
constSetup$ = emlManagerCifExtractLine.line$
@emlManagerCifExtractLine: sourceLines$#, "emlManager_wrapWidth ="
constWrap$ = emlManagerCifExtractLine.line$
constFoundInWrapper = 0
for li to size (wrapperLines$#)
    if wrapperLines$# [li] = constSetup$
        constFoundInWrapper = constFoundInWrapper + 1
    endif
    if wrapperLines$# [li] = constWrap$
        constFoundInWrapper = constFoundInWrapper + 1
    endif
endfor
if constFoundInWrapper <> 2
    canonAllMatch = 0
    appendInfoLine: "  the two extracted constant lines were not both found verbatim"
endif

if canonAllMatch = 1
    pass = pass + 1
    appendInfoLine: "PASS: all three embedded canons (and their two constant deps) are",
        ... " byte-identical between install-from-disk.praat and the generated wrapper"
else
    fail = fail + 1
    appendInfoLine: "FAIL: an embedded canon or constant did not byte-match (see above)"
endif

# ============================================================================
# Leg 2: the generated wrapper's own runtime work procedures
# ============================================================================
# `include` is resolved when Praat PARSES a script, before any of it runs --
# so a file this same script only just generated cannot be `include`d later
# in this same run (measured: attempting it fails at parse time with the
# generated file not yet on disk). Leg 2 is therefore driven as a genuinely
# separate `praat --run` process against the wrapper Leg 1 already wrote,
# using the same nested-process technique as the ASCII and diff checks
# above (and run_remove_plugin.praat's Check 3): the driver below is
# written out, run, and its own info-window output and pass/fail totals are
# read back and folded into this session's own.

leg2DriverLines$# = {
    ... "wrapHarnessMode = 1",
    ... "include /tmp/eml_pm_harness_wrapper/check3/plugin_WrapTest/install-WrapTest.praat",
    ... "",
    ... "pass = 0",
    ... "fail = 0",
    ... "scratchRoot$ = ""/tmp/eml_pm_harness_wrapper""",
    ... "q$ = """"""""",
    ... "fixtureCopy$ = ""/tmp/eml_pm_harness_wrapper/check3/plugin_WrapTest""",
    ... "",
    ... "procedure emlHarnessDirsIdentical: .a$, .b$",
    ... "    .exitFile$ = scratchRoot$ + ""/leg2_diff_exit.txt""",
    ... "    deleteFile: .exitFile$",
    ... "    .wrapper$ = scratchRoot$ + ""/leg2_diff_wrapper.sh""",
    ... "    writeFileLine: .wrapper$, ""#!/bin/sh""",
    ... "    appendFileLine: .wrapper$, ""diff -r "" + q$ + .a$ + q$ + "" "" + q$ + .b$ + q$ + "" >/dev/null 2>&1""",
    ... "    appendFileLine: .wrapper$, ""echo $? > "" + q$ + .exitFile$ + q$",
    ... "    runSystem_nocheck: ""sh "" + q$ + .wrapper$ + q$",
    ... "    .identical = 0",
    ... "    if fileReadable (.exitFile$)",
    ... "        .codeLines$# = readLinesFromFile$# (.exitFile$)",
    ... "        if number (.codeLines$# [1]) = 0",
    ... "            .identical = 1",
    ... "        endif",
    ... "    endif",
    ... "endproc",
    ... "",
    ... "procedure emlHarnessAuditSystemLines: .lines$#",
    ... "    .ok = 1",
    ... "    .offender$ = """"",
    ... "    .allowed$# = { "".q$"", "".src$"", "".dst$"", "".target$"", "".scriptFolder$"",",
    ... "        ... ""mv "", ""move "", ""rm -rf "", ""rmdir /s /q "",",
    ... "        ... ""cp -R "", ""xcopy /E /I /Q "", ""/."", ""+"", "" "" }",
    ... "    for .i to size (.lines$#)",
    ... "        .ln$ = .lines$# [.i]",
    ... "        if index (.ln$, ""runSystem_nocheck:"") > 0",
    ... "            .residual$ = .ln$",
    ... "            for .a to size (.allowed$#)",
    ... "                .residual$ = replace$ (.residual$, .allowed$# [.a], """", 0)",
    ... "            endfor",
    ... "            if index (.residual$, ""$"") > 0",
    ... "                .ok = 0",
    ... "                if .offender$ = """"",
    ... "                    .offender$ = .ln$",
    ... "                endif",
    ... "            endif",
    ... "        endif",
    ... "    endfor",
    ... "endproc",
    ... "",
    ... "procedure emlHarnessBlockInWrapper: .wrapperLines$#, .block$#, .blockN",
    ... "    .found = 0",
    ... "    .total = size (.wrapperLines$#)",
    ... "    .i = 1",
    ... "    while .found = 0 and .i <= .total - .blockN + 1",
    ... "        .match = 1",
    ... "        for .k to .blockN",
    ... "            if .wrapperLines$# [.i + .k - 1] <> .block$# [.k]",
    ... "                .match = 0",
    ... "            endif",
    ... "        endfor",
    ... "        if .match = 1",
    ... "            .found = 1",
    ... "        endif",
    ... "        .i = .i + 1",
    ... "    endwhile",
    ... "endproc",
    ... "",
    ... "wrapperLines$# = readLinesFromFile$# (""/tmp/eml_pm_harness_wrapper/check3/plugin_WrapTest/install-WrapTest.praat"")",
    ... "",
    ... "appendInfoLine: """"",
    ... "appendInfoLine: ""--- wrapper runtime: RED -- manifest-verify catches a deleted file ---""",
    ... "",
    ... "check6Src$ = scratchRoot$ + ""/check6/plugin_WrapTest""",
    ... "createFolder: scratchRoot$ + ""/check6""",
    ... "runSystem_nocheck: ""cp -R "" + q$ + fixtureCopy$ + q$ + "" "" + q$ + check6Src$ + q$",
    ... "deleteFile: check6Src$ + ""/sub/helper.praat""",
    ... "",
    ... "@wrapVerifyManifestUnder: check6Src$",
    ... "if wrapVerifyManifestUnder.ok = 0 and wrapVerifyManifestUnder.missingPath$ = ""sub/helper.praat""",
    ... "    pass = pass + 1",
    ... "    appendInfoLine: ""PASS: a deleted manifest file is caught, named exactly ('"",",
    ... "        ... wrapVerifyManifestUnder.missingPath$, ""') -- the real main sequence stops here,"",",
    ... "        ... "" before any prefs folder is ever created or touched""",
    ... "else",
    ... "    fail = fail + 1",
    ... "    appendInfoLine: ""FAIL: manifest-verify did not catch the deleted file as expected -- ok="",",
    ... "        ... wrapVerifyManifestUnder.ok, "" missing='"", wrapVerifyManifestUnder.missingPath$, ""'""",
    ... "endif",
    ... "",
    ... "appendInfoLine: """"",
    ... "appendInfoLine: ""--- wrapper runtime: fresh install green (contents byte-identical) ---""",
    ... "",
    ... "check7Prefs$ = scratchRoot$ + ""/check7_prefs""",
    ... "runSystem_nocheck: ""rm -rf "" + q$ + check7Prefs$ + q$",
    ... "createFolder: check7Prefs$",
    ... "",
    ... "@wrapDoPlace: fixtureCopy$, check7Prefs$, ""plugin_WrapTest""",
    ... "placeOk = wrapDoPlace.ok",
    ... "@wrapVerifyManifestUnder: check7Prefs$ + ""/plugin_WrapTest""",
    ... "structOk = wrapVerifyManifestUnder.ok",
    ... "@emlHarnessDirsIdentical: fixtureCopy$, check7Prefs$ + ""/plugin_WrapTest""",
    ... "if placeOk = 1 and structOk = 1 and emlHarnessDirsIdentical.identical = 1",
    ... "    pass = pass + 1",
    ... "    appendInfoLine: ""PASS: fresh install places byte-identical contents"",",
    ... "        ... "" (source and installed copy diff -r clean) and passes structural verify""",
    ... "else",
    ... "    fail = fail + 1",
    ... "    appendInfoLine: ""FAIL: fresh install -- placeOk="", placeOk, "" structOk="", structOk,",
    ... "        ... "" identical="", emlHarnessDirsIdentical.identical",
    ... "endif",
    ... "",
    ... "appendInfoLine: """"",
    ... "appendInfoLine: ""--- wrapper runtime: ghost destination -- proceeds, reused-leftover line ---""",
    ... "",
    ... "check8Prefs$ = scratchRoot$ + ""/check8_prefs""",
    ... "runSystem_nocheck: ""rm -rf "" + q$ + check8Prefs$ + q$",
    ... "createFolder: check8Prefs$",
    ... "check8Ghost$ = check8Prefs$ + ""/plugin_WrapTest""",
    ... "createFolder: check8Ghost$",
    ... "writeFileLine: check8Ghost$ + ""/.DS_Store"", ""macOS junk Praat cannot enumerate""",
    ... "",
    ... "@emlManagerIsInstalled: check8Ghost$",
    ... "ghostIsInstalled = emlManagerIsInstalled.installed",
    ... "",
    ... "@wrapDoPlace: fixtureCopy$, check8Prefs$, ""plugin_WrapTest""",
    ... "@wrapVerifyManifestUnder: check8Ghost$",
    ... "@wrapBuildCompletionLines: 1",
    ... "ghostLineFound = 0",
    ... "for gi to wrapBuildCompletionLines.n",
    ... "    if wrapBuildCompletionLines.lines$# [gi] = wrapMsgReusedLeftover$",
    ... "        ghostLineFound = 1",
    ... "    endif",
    ... "endfor",
    ... "",
    ... "if ghostIsInstalled = 0 and wrapDoPlace.ok = 1 and wrapVerifyManifestUnder.ok = 1",
    ... "    ... and fileReadable (check8Ghost$ + ""/.DS_Store"") and ghostLineFound = 1",
    ... "    pass = pass + 1",
    ... "    appendInfoLine: ""PASS: placing over a ghost folder (no setup.praat) succeeds without"",",
    ... "        ... "" nesting, the pre-existing leftover file rides along untouched, and the"",",
    ... "        ... "" completion assembly includes the reused-leftover line""",
    ... "else",
    ... "    fail = fail + 1",
    ... "    appendInfoLine: ""FAIL: ghost-destination path -- installed="", ghostIsInstalled,",
    ... "        ... "" placeOk="", wrapDoPlace.ok, "" structOk="", wrapVerifyManifestUnder.ok,",
    ... "        ... "" leftoverSurvived="", fileReadable (check8Ghost$ + ""/.DS_Store""),",
    ... "        ... "" ghostLineFound="", ghostLineFound",
    ... "endif",
    ... "",
    ... "appendInfoLine: """"",
    ... "appendInfoLine: ""--- wrapper runtime: conflict matrix -- newer/same/older/unknown ---""",
    ... "",
    ... "matrixOk = 1",
    ... "@wrapDetermineStatus: """", ""1.2.0""",
    ... "if wrapDetermineStatus.statusLine$ <> wrapStatusUnknown$ or wrapDetermineStatus.defaultBtn <> 1",
    ... "    matrixOk = 0",
    ... "    appendInfoLine: ""  unknown case wrong: '"", wrapDetermineStatus.statusLine$, ""' default="",",
    ... "        ... wrapDetermineStatus.defaultBtn",
    ... "endif",
    ... "@wrapDetermineStatus: ""1.0.0"", ""1.2.0""",
    ... "if wrapDetermineStatus.statusLine$ <> wrapStatusNewer$ or wrapDetermineStatus.defaultBtn <> 2",
    ... "    matrixOk = 0",
    ... "    appendInfoLine: ""  newer case wrong: '"", wrapDetermineStatus.statusLine$, ""' default="",",
    ... "        ... wrapDetermineStatus.defaultBtn",
    ... "endif",
    ... "@wrapDetermineStatus: ""1.2.0"", ""1.2.0""",
    ... "if wrapDetermineStatus.statusLine$ <> wrapStatusSame$ or wrapDetermineStatus.defaultBtn <> 1",
    ... "    matrixOk = 0",
    ... "    appendInfoLine: ""  same case wrong: '"", wrapDetermineStatus.statusLine$, ""' default="",",
    ... "        ... wrapDetermineStatus.defaultBtn",
    ... "endif",
    ... "@wrapDetermineStatus: ""1.5.0"", ""1.2.0""",
    ... "if wrapDetermineStatus.statusLine$ <> wrapStatusOlder$ or wrapDetermineStatus.defaultBtn <> 1",
    ... "    matrixOk = 0",
    ... "    appendInfoLine: ""  older case wrong: '"", wrapDetermineStatus.statusLine$, ""' default="",",
    ... "        ... wrapDetermineStatus.defaultBtn",
    ... "endif",
    ... "if matrixOk = 1",
    ... "    pass = pass + 1",
    ... "    appendInfoLine: ""PASS: newer/same/older/unknown each produce the pinned status line"",",
    ... "        ... "" and the pinned default button""",
    ... "else",
    ... "    fail = fail + 1",
    ... "    appendInfoLine: ""FAIL: conflict matrix mismatch (see above)""",
    ... "endif",
    ... "",
    ... "appendInfoLine: """"",
    ... "appendInfoLine: ""--- wrapper runtime: rename path (old_plugin_X, then _2) and re-install ---""",
    ... "",
    ... "check9Prefs$ = scratchRoot$ + ""/check9_prefs""",
    ... "runSystem_nocheck: ""rm -rf "" + q$ + check9Prefs$ + q$",
    ... "createFolder: check9Prefs$",
    ... "createFolder: check9Prefs$ + ""/plugin_WrapTest""",
    ... "writeFileLine: check9Prefs$ + ""/plugin_WrapTest/setup.praat"", ""# old installed copy""",
    ... "",
    ... "@wrapComputeOldName: check9Prefs$, ""plugin_WrapTest""",
    ... "oldName1$ = wrapComputeOldName.destName$",
    ... "@wrapDoRename: check9Prefs$, ""plugin_WrapTest"", oldName1$",
    ... "renameOk1 = wrapDoRename.ok",
    ... "oldExists1 = folderExists (check9Prefs$ + ""/"" + oldName1$)",
    ... "origGoneAfterRename1 = not folderExists (check9Prefs$ + ""/plugin_WrapTest"")",
    ... "",
    ... "@wrapDoPlace: fixtureCopy$, check9Prefs$, ""plugin_WrapTest""",
    ... "@wrapVerifyManifestUnder: check9Prefs$ + ""/plugin_WrapTest""",
    ... "firstInstallOk = wrapDoPlace.ok and wrapVerifyManifestUnder.ok",
    ... "",
    ... "if renameOk1 = 1 and oldName1$ = ""old_plugin_WrapTest"" and oldExists1 = 1",
    ... "    ... and origGoneAfterRename1 = 1 and firstInstallOk = 1",
    ... "    pass = pass + 1",
    ... "    appendInfoLine: ""PASS: the rename path archives the installed copy to '"", oldName1$,",
    ... "        ... ""' and the new copy installs cleanly""",
    ... "else",
    ... "    fail = fail + 1",
    ... "    appendInfoLine: ""FAIL: rename path -- renameOk="", renameOk1, "" oldName='"", oldName1$,",
    ... "        ... ""' oldExists="", oldExists1, "" origGone="", origGoneAfterRename1,",
    ... "        ... "" firstInstallOk="", firstInstallOk",
    ... "endif",
    ... "",
    ... "createFolder: check9Prefs$ + ""/plugin_WrapTest""",
    ... "writeFileLine: check9Prefs$ + ""/plugin_WrapTest/setup.praat"", ""# installed copy, second round""",
    ... "",
    ... "@wrapComputeOldName: check9Prefs$, ""plugin_WrapTest""",
    ... "oldName2$ = wrapComputeOldName.destName$",
    ... "@wrapDoRename: check9Prefs$, ""plugin_WrapTest"", oldName2$",
    ... "renameOk2 = wrapDoRename.ok",
    ... "",
    ... "if renameOk2 = 1 and oldName2$ = ""old_plugin_WrapTest_2""",
    ... "    pass = pass + 1",
    ... "    appendInfoLine: ""PASS: a second collision on the archive name climbs to '"", oldName2$, ""'""",
    ... "else",
    ... "    fail = fail + 1",
    ... "    appendInfoLine: ""FAIL: second-collision suffix wrong -- got '"", oldName2$, ""', renameOk="", renameOk2",
    ... "endif",
    ... "",
    ... "appendInfoLine: """"",
    ... "appendInfoLine: ""--- wrapper runtime: delete path (only reachable with the boolean gate on) ---""",
    ... "",
    ... "check10Prefs$ = scratchRoot$ + ""/check10_prefs""",
    ... "runSystem_nocheck: ""rm -rf "" + q$ + check10Prefs$ + q$",
    ... "createFolder: check10Prefs$",
    ... "createFolder: check10Prefs$ + ""/plugin_WrapTest""",
    ... "writeFileLine: check10Prefs$ + ""/plugin_WrapTest/setup.praat"", ""# to be deleted""",
    ... "",
    ... "@wrapDoDelete: check10Prefs$, ""plugin_WrapTest""",
    ... "if wrapDoDelete.ok = 1 and not folderExists (check10Prefs$ + ""/plugin_WrapTest"")",
    ... "    pass = pass + 1",
    ... "    appendInfoLine: ""PASS: the delete work procedure removes the installed copy outright,"",",
    ... "        ... "" no old_ folder created""",
    ... "else",
    ... "    fail = fail + 1",
    ... "    appendInfoLine: ""FAIL: delete path did not remove the installed copy as expected""",
    ... "endif",
    ... "",
    ... "if not folderExists (check10Prefs$ + ""/old_plugin_WrapTest"")",
    ... "    pass = pass + 1",
    ... "    appendInfoLine: ""PASS: no old_plugin_WrapTest folder was created by the delete path""",
    ... "else",
    ... "    fail = fail + 1",
    ... "    appendInfoLine: ""FAIL: an old_ folder appeared even though the delete path was taken""",
    ... "endif",
    ... "",
    ... "gateLineIf = 0",
    ... "gateLineElse = 0",
    ... "gateLineEndif = 0",
    ... "gateDeletePos = 0",
    ... "gateRenamePos = 0",
    ... "for li to size (wrapperLines$#)",
    ... "    trimmed$ = replace_regex$ (wrapperLines$# [li], ""^ +"", """", 0)",
    ... "    if trimmed$ = ""if deleteOn = 1"" and gateLineIf = 0",
    ... "        gateLineIf = li",
    ... "    elsif gateLineIf > 0 and gateLineElse = 0 and trimmed$ = ""else""",
    ... "        gateLineElse = li",
    ... "    elsif gateLineElse > 0 and gateLineEndif = 0 and trimmed$ = ""endif""",
    ... "        gateLineEndif = li",
    ... "    endif",
    ... "    if gateLineIf > 0 and gateLineElse = 0 and index (wrapperLines$# [li], ""@wrapDoDelete:"") > 0",
    ... "        gateDeletePos = li",
    ... "    endif",
    ... "    if gateLineElse > 0 and gateLineEndif = 0 and index (wrapperLines$# [li], ""@wrapDoRename:"") > 0",
    ... "        gateRenamePos = li",
    ... "    endif",
    ... "endfor",
    ... "if gateLineIf > 0 and gateLineElse > gateLineIf and gateLineEndif > gateLineElse",
    ... "    ... and gateDeletePos > gateLineIf and gateDeletePos < gateLineElse",
    ... "    ... and gateRenamePos > gateLineElse and gateRenamePos < gateLineEndif",
    ... "    pass = pass + 1",
    ... "    appendInfoLine: ""PASS: the wrapper's own source gates the delete call behind"",",
    ... "        ... "" if deleteOn = 1 and the rename call behind its else --"",",
    ... "        ... "" the boolean is the only thing that decides which one runs""",
    ... "else",
    ... "    fail = fail + 1",
    ... "    appendInfoLine: ""FAIL: could not confirm the boolean gates delete vs. rename in the"",",
    ... "        ... "" wrapper's own source (if@"", gateLineIf, "" else@"", gateLineElse,",
    ... "        ... "" endif@"", gateLineEndif, "" delete@"", gateDeletePos, "" rename@"", gateRenamePos, "")""",
    ... "endif",
    ... "",
    ... "appendInfoLine: """"",
    ... "appendInfoLine: ""--- wrapper runtime: path-construction audit ---""",
    ... "",
    ... "@emlHarnessAuditSystemLines: wrapperLines$#",
    ... "if emlHarnessAuditSystemLines.ok = 1",
    ... "    pass = pass + 1",
    ... "    appendInfoLine: ""PASS: every runSystem_nocheck line in the generated wrapper interpolates"",",
    ... "        ... "" only the pinned components (preferencesDirectory$-derived paths, the baked"",",
    ... "        ... "" folder name, the wrapper's own resolved parent, and the literal shell text) --"",",
    ... "        ... "" never any user-typed text""",
    ... "else",
    ... "    fail = fail + 1",
    ... "    appendInfoLine: ""FAIL: a system-command line interpolates something outside the pinned"",",
    ... "        ... "" components: '"", emlHarnessAuditSystemLines.offender$, ""'""",
    ... "endif",
    ... "",
    ... "appendInfoLine: """"",
    ... "appendInfoLine: ""--- wrapper runtime: self-install guard condition matrix (part 1) ---""",
    ... "",
    ... "guardMatrixOk = 1",
    ... "",
    ... "@wrapCheckSelfInstall: ""/a/b/plugin_X"", ""/a/b/plugin_X""",
    ... "if wrapCheckSelfInstall.fires <> 1",
    ... "    guardMatrixOk = 0",
    ... "    appendInfoLine: ""  equal paths should fire, got "", wrapCheckSelfInstall.fires",
    ... "endif",
    ... "",
    ... "@wrapCheckSelfInstall: ""/a/b/plugin_X/sub/dir"", ""/a/b/plugin_X""",
    ... "if wrapCheckSelfInstall.fires <> 1",
    ... "    guardMatrixOk = 0",
    ... "    appendInfoLine: ""  wrapper nested under dest should fire, got "", wrapCheckSelfInstall.fires",
    ... "endif",
    ... "",
    ... "@wrapCheckSelfInstall: ""/a/b/plugin_Y"", ""/a/b/plugin_X""",
    ... "if wrapCheckSelfInstall.fires <> 0",
    ... "    guardMatrixOk = 0",
    ... "    appendInfoLine: ""  unrelated paths should NOT fire, got "", wrapCheckSelfInstall.fires",
    ... "endif",
    ... "",
    ... "@wrapCheckSelfInstall: ""/a/b/plugin_XY"", ""/a/b/plugin_X""",
    ... "if wrapCheckSelfInstall.fires <> 0",
    ... "    guardMatrixOk = 0",
    ... "    appendInfoLine: ""  a same-prefix SIBLING (plugin_XY under plugin_X by naive""",
    ... "        ... "" substring only) must NOT fire -- got "", wrapCheckSelfInstall.fires",
    ... "endif",
    ... "",
    ... "@wrapCheckSelfInstall: ""/a/b/plugin_X/"", ""/a/b/plugin_X""",
    ... "if wrapCheckSelfInstall.fires <> 1",
    ... "    guardMatrixOk = 0",
    ... "    appendInfoLine: ""  trailing slash on scriptFolder$ should still fire (equal), got "",",
    ... "        ... wrapCheckSelfInstall.fires",
    ... "endif",
    ... "",
    ... "@wrapCheckSelfInstall: ""/a/b/plugin_X"", ""/a/b/plugin_X/""",
    ... "if wrapCheckSelfInstall.fires <> 1",
    ... "    guardMatrixOk = 0",
    ... "    appendInfoLine: ""  trailing slash on destPath$ should still fire (equal), got "",",
    ... "        ... wrapCheckSelfInstall.fires",
    ... "endif",
    ... "",
    ... "@wrapCheckSelfInstall: ""C:\a\b\plugin_X"", ""C:\a\b\plugin_X""",
    ... "if wrapCheckSelfInstall.fires <> 1",
    ... "    guardMatrixOk = 0",
    ... "    appendInfoLine: ""  backslash-separated equal paths should fire after normalization, got "",",
    ... "        ... wrapCheckSelfInstall.fires",
    ... "endif",
    ... "",
    ... "@wrapCheckSelfInstall: ""C:\a\b\plugin_X\sub"", ""C:\a\b\plugin_X""",
    ... "if wrapCheckSelfInstall.fires <> 1",
    ... "    guardMatrixOk = 0",
    ... "    appendInfoLine: ""  backslash-separated nested-under-dest should fire, got "",",
    ... "        ... wrapCheckSelfInstall.fires",
    ... "endif",
    ... "",
    ... "@wrapCheckSelfInstall: ""C:\a\b\plugin_Y"", ""C:\a\b\plugin_X""",
    ... "if wrapCheckSelfInstall.fires <> 0",
    ... "    guardMatrixOk = 0",
    ... "    appendInfoLine: ""  backslash-separated unrelated paths should NOT fire, got "",",
    ... "        ... wrapCheckSelfInstall.fires",
    ... "endif",
    ... "",
    ... "if guardMatrixOk = 1",
    ... "    pass = pass + 1",
    ... "    appendInfoLine: ""PASS: the self-install guard condition matrix -- equal paths,"",",
    ... "        ... "" wrapper nested under dest, unrelated paths, a same-prefix sibling,"",",
    ... "        ... "" trailing-slash normalization (both sides), and backslash normalization"",",
    ... "        ... "" (both equal and nested) -- all fire/do-not-fire exactly as pinned""",
    ... "else",
    ... "    fail = fail + 1",
    ... "    appendInfoLine: ""FAIL: self-install guard condition matrix mismatch (see above)""",
    ... "endif",
    ... "",
    ... "appendInfoLine: """"",
    ... "appendInfoLine: ""LEG2 RESULT: "", pass, "" pass, "", fail, "" fail""",
    ... "",
    ... "summaryFile$ = scratchRoot$ + ""/leg2_summary.txt""",
    ... "writeFileLine: summaryFile$, string$ (pass)",
    ... "appendFileLine: summaryFile$, string$ (fail)" }

leg2Driver$ = scratchRoot$ + "/leg2_driver.praat"
for dli to size (leg2DriverLines$#)
    if dli = 1
        writeFileLine: leg2Driver$, leg2DriverLines$# [dli]
    else
        appendFileLine: leg2Driver$, leg2DriverLines$# [dli]
    endif
endfor

leg2Log$ = scratchRoot$ + "/leg2_log.txt"
leg2RunnerSh$ = scratchRoot$ + "/leg2_runner.sh"
writeFileLine: leg2RunnerSh$, "#!/bin/sh"
appendFileLine: leg2RunnerSh$, "BIN=$(command -v praat 2>/dev/null || echo /root/work/praat-env/praat)"
appendFileLine: leg2RunnerSh$, """$BIN"" --run " + q$ + leg2Driver$ + q$ + " > " + q$ + leg2Log$ + q$ + " 2>&1"
runSystem_nocheck: "sh " + q$ + leg2RunnerSh$ + q$

if fileReadable (leg2Log$)
    leg2LogLines$# = readLinesFromFile$# (leg2Log$)
    for lli to size (leg2LogLines$#)
        appendInfoLine: leg2LogLines$# [lli]
    endfor
else
    appendInfoLine: "FAIL: Leg 2's nested praat process produced no log output at all"
endif

leg2Summary$ = scratchRoot$ + "/leg2_summary.txt"
if fileReadable (leg2Summary$)
    leg2SummaryLines$# = readLinesFromFile$# (leg2Summary$)
    if size (leg2SummaryLines$#) = 2
        pass = pass + number (leg2SummaryLines$# [1])
        fail = fail + number (leg2SummaryLines$# [2])
    else
        fail = fail + 1
        appendInfoLine: "FAIL: Leg 2's summary file is malformed"
    endif
else
    fail = fail + 1
    appendInfoLine: "FAIL: Leg 2's nested praat process never wrote a summary file",
        ... " (it did not run to completion)"
endif
# ============================================================================

runSystem_nocheck: "rm -rf " + q$ + scratchRoot$ + q$

appendInfoLine: ""

# --- Check 12 (ASCII guard): a plugin whose setup.praat carries non-ASCII
#     characters still yields a PURE ASCII wrapper, with "?" in the baked
#     report text; and the sanitizer flags a non-ASCII folder name. ---
naDir$ = "fixtures/wrapper_plugin_nonascii"
@emlManagerCifBuildReportLines: naDir$ + "/setup.praat", emlManager_wrapWidth
naN = emlManagerCifBuildReportLines.n
naJoined$ = ""
for iNa from 1 to naN
    @emlManagerCifAsciiSanitize: emlManagerCifBuildReportLines.lines$# [iNa]
    naJoined$ = naJoined$ + emlManagerCifAsciiSanitize.out$ + " / "
endfor
naClean = 1
for iNc from 1 to length (naJoined$)
    if index (emlManagerCif_ascii$, mid$ (naJoined$, iNc, 1)) = 0
        naClean = 0
    endif
endfor
if naClean = 1 and index (naJoined$, "?") > 0
    appendInfoLine: "PASS: non-ASCII setup.praat report text sanitized to pure ASCII with ? markers"
    pass = pass + 1
else
    appendInfoLine: "FAIL: sanitized report text still carries non-ASCII or lost its ? markers: ", naJoined$
    fail = fail + 1
endif
@emlManagerCifAsciiSanitize: "plugin_Caf" + unicode$ (233) + "Tools"
if emlManagerCifAsciiSanitize.hadNonAscii = 1
    appendInfoLine: "PASS: non-ASCII folder name is flagged by the sanitizer"
    pass = pass + 1
else
    appendInfoLine: "FAIL: non-ASCII folder name not flagged"
    fail = fail + 1
endif

appendInfoLine: "RESULT: ", pass, " pass, ", fail, " fail"
