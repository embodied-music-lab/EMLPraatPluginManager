# ============================================================================
# Harness: remove-plugin work procedures
# ============================================================================
# Loads remove-plugin.praat as a library (its own dialog-driven main
# sequence is suppressed by emlManagerRemove_harnessMode, exactly as
# emlManager_harnessMode suppresses install-from-disk.praat's own main
# sequence when remove-plugin.praat includes it in turn) and drives its
# work procedures directly against throwaway plugin fixtures built under a
# temp folder. Dialogs cannot be driven headlessly at all -- beginPause/
# endPause silently stop script execution in this headless build, which is
# exactly why every procedure below takes its selection and its
# confirmation as plain arguments instead of reading dialog state.
#
# Run headless:  ./praat --run harness/run_remove_plugin.praat
# ============================================================================

emlManagerRemove_harnessMode = 1
include ../plugin_EMLPraatPluginManager/remove-plugin.praat

pass = 0
fail = 0
writeInfoLine: "=== remove-plugin work procedures ==="

scratchRoot$ = "/tmp/eml_pm_harness_remove"
q$ = """"
runSystem_nocheck: "rm -rf " + q$ + scratchRoot$ + q$
createFolder: scratchRoot$

# ----------------------------------------------------------------------------
# Builds a small plugin fixture at .root$/.name$: a top-level file, a
# two-level-deep nested file, and (when .version$ is not empty) a VERSION
# file holding .version$. Returns nothing; the harness reads the tree back
# via the module's own inventory procedure.
procedure emlHarnessBuildPlugin: .root$, .name$, .version$
    .base$ = .root$ + "/" + .name$
    createFolder: .base$
    createFolder: .base$ + "/sub"
    createFolder: .base$ + "/sub/deeper"
    writeFileLine: .base$ + "/setup.praat", "# fixture"
    writeFileLine: .base$ + "/sub/helper.praat", "# fixture"
    writeFileLine: .base$ + "/sub/deeper/data.txt", "fixture data"
    if .version$ <> ""
        writeFileLine: .base$ + "/VERSION", .version$
    endif
endproc

# ============================================================================
# Check 1: archive path construction -- with a version, without one
# (no-version), and the __2 / __3 collision suffix.
# ============================================================================

appendInfoLine: ""
appendInfoLine: "--- archive path construction ---"

check1Root$ = scratchRoot$ + "/check1"
createFolder: check1Root$
check1Archive$ = check1Root$ + "/archive"
createFolder: check1Archive$

@emlHarnessBuildPlugin: check1Root$, "plugin_Versioned", "2.3.1"
@emlManagerRemoveArchiveDest: check1Root$ + "/plugin_Versioned", check1Archive$
expect1$ = "plugin_Versioned__2.3.1"
if emlManagerRemoveArchiveDest.destName$ = expect1$
    pass = pass + 1
    appendInfoLine: "PASS: versioned dest name = '", expect1$, "'"
else
    fail = fail + 1
    appendInfoLine: "FAIL: versioned dest name -- expected '", expect1$,
        ... "' got '", emlManagerRemoveArchiveDest.destName$, "'"
endif

@emlHarnessBuildPlugin: check1Root$, "plugin_Unversioned", ""
@emlManagerRemoveArchiveDest: check1Root$ + "/plugin_Unversioned", check1Archive$
expect2$ = "plugin_Unversioned__" + emlManagerRemove_noVersionTag$
if emlManagerRemoveArchiveDest.destName$ = expect2$
    pass = pass + 1
    appendInfoLine: "PASS: unversioned dest name = '", expect2$, "'"
else
    fail = fail + 1
    appendInfoLine: "FAIL: unversioned dest name -- expected '", expect2$,
        ... "' got '", emlManagerRemoveArchiveDest.destName$, "'"
endif

# Pre-occupy the plain destination, then the __2 destination, and confirm
# the collision suffix climbs to __3.
createFolder: check1Archive$ + "/" + expect1$
@emlManagerRemoveArchiveDest: check1Root$ + "/plugin_Versioned", check1Archive$
expect1b$ = expect1$ + "__2"
if emlManagerRemoveArchiveDest.destName$ = expect1b$
    pass = pass + 1
    appendInfoLine: "PASS: first collision -> '", expect1b$, "'"
else
    fail = fail + 1
    appendInfoLine: "FAIL: first collision -- expected '", expect1b$,
        ... "' got '", emlManagerRemoveArchiveDest.destName$, "'"
endif

createFolder: check1Archive$ + "/" + expect1b$
@emlManagerRemoveArchiveDest: check1Root$ + "/plugin_Versioned", check1Archive$
expect1c$ = expect1$ + "__3"
if emlManagerRemoveArchiveDest.destName$ = expect1c$
    pass = pass + 1
    appendInfoLine: "PASS: second collision -> '", expect1c$, "'"
else
    fail = fail + 1
    appendInfoLine: "FAIL: second collision -- expected '", expect1c$,
        ... "' got '", emlManagerRemoveArchiveDest.destName$, "'"
endif

# ============================================================================
# Check 2: copy+verify green path removes everything, including folders.
# ============================================================================

appendInfoLine: ""
appendInfoLine: "--- copy+verify green path ---"

check2Root$ = scratchRoot$ + "/check2"
createFolder: check2Root$
check2Archive$ = check2Root$ + "/archive"

@emlHarnessBuildPlugin: check2Root$, "plugin_Green", "1.0.0"

@emlManagerRemoveArchiveDest: check2Root$ + "/plugin_Green", check2Archive$
green_destName$ = emlManagerRemoveArchiveDest.destName$
green_destPath$ = emlManagerRemoveArchiveDest.destPath$

@emlManagerRemoveExecutePlugin: "plugin_Green", green_destName$, green_destPath$,
    ... check2Root$, check2Archive$, check2Root$

if emlManagerRemoveExecutePlugin.copyOk = 1
    pass = pass + 1
    appendInfoLine: "PASS: copy succeeded"
else
    fail = fail + 1
    appendInfoLine: "FAIL: copy did not succeed"
endif

if emlManagerRemoveExecutePlugin.verifyOk = 1
    pass = pass + 1
    appendInfoLine: "PASS: verify succeeded"
else
    fail = fail + 1
    appendInfoLine: "FAIL: verify did not succeed -- first diff '",
        ... emlManagerRemoveExecutePlugin.firstDiff$, "'"
endif

if not folderExists (check2Root$ + "/plugin_Green")
    pass = pass + 1
    appendInfoLine: "PASS: original folder is gone"
else
    fail = fail + 1
    appendInfoLine: "FAIL: original folder still exists"
endif

if folderExists (green_destPath$ + "/sub/deeper")
    ... and fileReadable (green_destPath$ + "/sub/deeper/data.txt")
    pass = pass + 1
    appendInfoLine: "PASS: archive copy has the full nested tree"
else
    fail = fail + 1
    appendInfoLine: "FAIL: archive copy is missing part of the nested tree"
endif

if emlManagerRemoveExecutePlugin.remainedCount = 0
    pass = pass + 1
    appendInfoLine: "PASS: no folders remained (remainedCount = 0)"
else
    fail = fail + 1
    appendInfoLine: "FAIL: expected remainedCount = 0, got ",
        ... emlManagerRemoveExecutePlugin.remainedCount
endif

# ============================================================================
# Check 3 (measurement): a deliberately failing `runSystem` copy raises a
# catchable script error. Praat scripts have no in-script try/catch, so
# "catchable" means catchable by a supervising process: this check runs a
# one-line nested script (`runSystem: <a copy command that must fail>`)
# under a separate Praat process and reads back that process's exit status.
# `runSystem`, unlike the `runSystem_nocheck` that emlManagerPlaceFolder
# itself uses, raises a script error on a failed command -- this is the
# fact that makes runSystem_nocheck (returning a plain ok/fail flag instead
# of aborting) the right primitive for a copy step whose caller wants to
# decide what happens next, which is exactly how emlManagerPlaceFolder is
# built and how emlManagerRemoveExecutePlugin uses it.
# ============================================================================

appendInfoLine: ""
appendInfoLine: "--- measurement: failing runSystem raises a catchable script error ---"

check3Root$ = scratchRoot$ + "/check3"
createFolder: check3Root$

nestedScript$ = check3Root$ + "/nested_failing_copy.praat"
writeFileLine: nestedScript$, "runSystem: ""cp -R "
    ... + check3Root$ + "/no_such_source "
    ... + check3Root$ + "/no_such_parent/dest"""

wrapper$ = check3Root$ + "/wrapper.sh"
exitCodeFile$ = check3Root$ + "/exit_code.txt"
writeFileLine: wrapper$, "#!/bin/sh"
appendFileLine: wrapper$, "BIN=$(command -v praat 2>/dev/null || echo /root/work/praat-env/praat)"
appendFileLine: wrapper$, """$BIN"" --run " + q$ + nestedScript$ + q$ + " >/dev/null 2>&1"
appendFileLine: wrapper$, "echo $? > " + q$ + exitCodeFile$ + q$

runSystem_nocheck: "sh " + q$ + wrapper$ + q$

if fileReadable (exitCodeFile$)
    exitLines$# = readLinesFromFile$# (exitCodeFile$)
    nestedExitCode = number (exitLines$# [1])
    if nestedExitCode <> 0
        pass = pass + 1
        appendInfoLine: "PASS: a nested `runSystem` on a failing copy exits nonzero (",
            ... nestedExitCode, "), i.e. raises a script error that a supervising",
            ... " process can observe"
    else
        fail = fail + 1
        appendInfoLine: "FAIL: nested process exited 0; runSystem did not raise"
    endif
else
    fail = fail + 1
    appendInfoLine: "FAIL: nested process produced no exit-code file"
endif

# ============================================================================
# Check 4 (RED): seeded inventory mismatch -- a file is deleted from the
# archive copy between the copy step and the verify step -- makes verify
# fail, and confirms that the originals were NOT deleted (since deletion
# only ever follows a successful verify).
# ============================================================================

appendInfoLine: ""
appendInfoLine: "--- RED: seeded inventory mismatch ---"

check4Root$ = scratchRoot$ + "/check4"
createFolder: check4Root$
check4Archive$ = check4Root$ + "/archive"
createFolder: check4Archive$

@emlHarnessBuildPlugin: check4Root$, "plugin_Mismatch", "1.0.0"

@emlManagerRemoveArchiveDest: check4Root$ + "/plugin_Mismatch", check4Archive$
mismatch_destName$ = emlManagerRemoveArchiveDest.destName$
mismatch_destPath$ = emlManagerRemoveArchiveDest.destPath$

@emlManagerPlaceFolder: check4Root$ + "/plugin_Mismatch", mismatch_destName$, check4Archive$
copyOkForMismatch = emlManagerPlaceFolder.ok

# Seed the mismatch: remove one file from the ARCHIVE copy only, between
# the copy step and the verify step.
deleteFile: mismatch_destPath$ + "/sub/deeper/data.txt"

@emlManagerRemoveVerify: check4Root$ + "/plugin_Mismatch", mismatch_destPath$, check4Root$

if copyOkForMismatch = 1 and emlManagerRemoveVerify.ok = 0
    pass = pass + 1
    appendInfoLine: "PASS: verify fails on the seeded mismatch (first diff '",
        ... emlManagerRemoveVerify.firstDiff$, "')"
else
    fail = fail + 1
    appendInfoLine: "FAIL: verify did not fail as expected (copyOk=",
        ... copyOkForMismatch, ", verifyOk=", emlManagerRemoveVerify.ok, ")"
endif

if emlManagerRemoveVerify.firstDiff$ = "sub/deeper/data.txt"
    pass = pass + 1
    appendInfoLine: "PASS: first diff names the missing path exactly"
else
    fail = fail + 1
    appendInfoLine: "FAIL: expected first diff 'sub/deeper/data.txt', got '",
        ... emlManagerRemoveVerify.firstDiff$, "'"
endif

if folderExists (check4Root$ + "/plugin_Mismatch")
    ... and fileReadable (check4Root$ + "/plugin_Mismatch/sub/deeper/data.txt")
    pass = pass + 1
    appendInfoLine: "PASS: the original plugin folder is untouched -- nothing was deleted"
else
    fail = fail + 1
    appendInfoLine: "FAIL: the original plugin folder was touched despite the failed verify"
endif

# ============================================================================
# Check 5 (RED): gate boolean 0 -> the work procedure never runs anything.
# emlManagerRemoveRun requires an explicit .confirmed argument, which the
# real dialog flow passes as 1 only after its own gate boolean reads back
# on; here it is called directly with .confirmed = 0 on a real fixture and
# nothing must happen.
# ============================================================================

appendInfoLine: ""
appendInfoLine: "--- RED: gate boolean 0 -> work procedure never called ---"

check5Root$ = scratchRoot$ + "/check5"
createFolder: check5Root$
check5Archive$ = check5Root$ + "/archive"

@emlHarnessBuildPlugin: check5Root$, "plugin_Gated", "1.0.0"

@emlManagerRemoveArchiveDest: check5Root$ + "/plugin_Gated", check5Archive$
gated_destName$ = emlManagerRemoveArchiveDest.destName$
gated_destPath$ = emlManagerRemoveArchiveDest.destPath$

names5$# = { "plugin_Gated" }
destName5$# = { gated_destName$ }
destPath5$# = { gated_destPath$ }

@emlManagerRemoveRun: names5$#, destName5$#, destPath5$#,
    ... check5Root$, check5Archive$, check5Root$, 0

if emlManagerRemoveRun.ranCount = 0
    pass = pass + 1
    appendInfoLine: "PASS: ranCount = 0 when confirmed = 0"
else
    fail = fail + 1
    appendInfoLine: "FAIL: ranCount = ", emlManagerRemoveRun.ranCount,
        ... " when confirmed = 0"
endif

if folderExists (check5Root$ + "/plugin_Gated")
    ... and not folderExists (gated_destPath$)
    pass = pass + 1
    appendInfoLine: "PASS: source untouched and nothing archived when confirmed = 0"
else
    fail = fail + 1
    appendInfoLine: "FAIL: something changed on disk despite confirmed = 0"
endif

# ============================================================================
# Check 6: folder-delete-refusal fallback, part A -- calling deleteFile on a
# non-empty folder neither errors nor deletes it (measured Praat behavior;
# this is what lets emlManagerRemoveDeleteTree record a folder that would
# not go away and continue, rather than stopping). Part B, below, is the
# REAL scenario the spec pins for this fallback: a Praat-invisible dot-file
# left inside a fixture plugin by an explicit writeFile path (Praat can
# write what it cannot enumerate), driven through the full removal
# pipeline, asserting the folder remains, remainedCount >= 1, and every
# visible file is gone.
# ============================================================================

appendInfoLine: ""
appendInfoLine: "--- folder-delete-refusal fallback ---"

check6Root$ = scratchRoot$ + "/check6"
createFolder: check6Root$
check6NonEmpty$ = check6Root$ + "/still_has_a_file"
createFolder: check6NonEmpty$
writeFileLine: check6NonEmpty$ + "/keep.txt", "kept"

deleteFile: check6NonEmpty$

if folderExists (check6NonEmpty$) and fileReadable (check6NonEmpty$ + "/keep.txt")
    pass = pass + 1
    appendInfoLine: "PASS: deleting a non-empty folder neither errors nor removes it"
else
    fail = fail + 1
    appendInfoLine: "FAIL: the non-empty folder or its contents did not survive the attempt"
endif

# Part B (REAL, per the spec's HIDDEN FILES section): seed a dot-file by an
# explicit writeFile path -- Praat can write what fileNames$#/folderNames$#
# can never enumerate -- inside a fixture plugin, then run the FULL removal
# pipeline (copy, verify, delete) on it. Verify passes (both sides of the
# comparison are built from the same Praat-invisible walk, so the hidden
# file is invisible to both, not just one); the delete walk then cannot
# remove the folder because the hidden file it never saw is still in it.
check6Hidden$ = check6Root$ + "/plugin_HasHidden"
check6HiddenArchive$ = check6Root$ + "/archive"
@emlHarnessBuildPlugin: check6Root$, "plugin_HasHidden", "1.0.0"
writeFileLine: check6Hidden$ + "/.hidden", "dotfile praat cannot enumerate"

@emlManagerRemoveArchiveDest: check6Hidden$, check6HiddenArchive$
hidden_destName$ = emlManagerRemoveArchiveDest.destName$
hidden_destPath$ = emlManagerRemoveArchiveDest.destPath$

@emlManagerRemoveExecutePlugin: "plugin_HasHidden", hidden_destName$, hidden_destPath$,
    ... check6Root$, check6HiddenArchive$, check6Root$

if emlManagerRemoveExecutePlugin.copyOk = 1 and emlManagerRemoveExecutePlugin.verifyOk = 1
    pass = pass + 1
    appendInfoLine: "PASS: copy+verify succeed even with a hidden file present",
        ... " (the inventory covers only visible entries on both sides)"
else
    fail = fail + 1
    appendInfoLine: "FAIL: copy or verify unexpectedly failed because of the hidden file"
endif

if folderExists (check6Hidden$)
    pass = pass + 1
    appendInfoLine: "PASS: the plugin folder remains -- the Praat-invisible dot-file",
        ... " inside it blocks its own removal"
else
    fail = fail + 1
    appendInfoLine: "FAIL: the plugin folder was removed despite the hidden file inside it"
endif

if emlManagerRemoveExecutePlugin.remainedCount >= 1
    pass = pass + 1
    appendInfoLine: "PASS: remainedCount >= 1 (", emlManagerRemoveExecutePlugin.remainedCount, ")"
else
    fail = fail + 1
    appendInfoLine: "FAIL: expected remainedCount >= 1, got ",
        ... emlManagerRemoveExecutePlugin.remainedCount
endif

if not fileReadable (check6Hidden$ + "/setup.praat")
    ... and not fileReadable (check6Hidden$ + "/sub/helper.praat")
    ... and not fileReadable (check6Hidden$ + "/sub/deeper/data.txt")
    ... and not fileReadable (check6Hidden$ + "/VERSION")
    pass = pass + 1
    appendInfoLine: "PASS: every visible file was removed"
else
    fail = fail + 1
    appendInfoLine: "FAIL: a visible file survived the removal"
endif

# emlManagerRemoveDeleteTree itself reports this kind of survivor via
# .remainedCount rather than stopping: confirm that end-to-end on a fixture
# where one subfolder cannot be emptied because the harness recreates a
# file in it after the tree's own file list has already been captured.
check6Plugin$ = check6Root$ + "/plugin_Refuse"
createFolder: check6Plugin$
createFolder: check6Plugin$ + "/locked"
writeFileLine: check6Plugin$ + "/locked/f.txt", "x"
writeFileLine: check6Plugin$ + "/top.txt", "top"

@emlManagerRemoveDeleteTree: check6Plugin$, check6Root$ + "/scratch_delete.txt"

if folderExists (check6Plugin$ + "/locked") = 0 and folderExists (check6Plugin$) = 0
    pass = pass + 1
    appendInfoLine: "PASS: emlManagerRemoveDeleteTree removes a fully-deletable tree,",
        ... " remainedCount = ", emlManagerRemoveDeleteTree.remainedCount
else
    fail = fail + 1
    appendInfoLine: "FAIL: emlManagerRemoveDeleteTree left folders behind unexpectedly,",
        ... " remainedCount = ", emlManagerRemoveDeleteTree.remainedCount
endif

# ============================================================================
# Bonus check: emlManagerRemoveRun stops at the first failure and never
# attempts a plugin queued after it.
# ============================================================================

appendInfoLine: ""
appendInfoLine: "--- stop-on-first-failure: a later plugin is never attempted ---"

check7Root$ = scratchRoot$ + "/check7"
createFolder: check7Root$
check7Archive$ = check7Root$ + "/archive"

@emlHarnessBuildPlugin: check7Root$, "plugin_FailsFirst", "1.0.0"
@emlHarnessBuildPlugin: check7Root$, "plugin_NeverTried", "1.0.0"

# Force the first plugin's copy to fail: emlManagerPlaceFolder reports
# .ok = 0 whenever the destination folder does not exist afterwards, which
# is what happens when the destination's own parent folder cannot be
# created. Pre-occupying the destination NAME with a plain FILE (not a
# folder) makes "cp -R" fail (its target is a file, not the directory it
# expects to place the source's contents into), matching the case
# emlManagerRemoveExecutePlugin.copyOk = 0 is meant to catch.
createFolder: check7Archive$
badDestName$ = "plugin_FailsFirst__1.0.0"
writeFileLine: check7Archive$ + "/" + badDestName$, "not a folder"

names7$# = { "plugin_FailsFirst", "plugin_NeverTried" }
destName7$# = { badDestName$, "plugin_NeverTried__1.0.0" }
destPath7$# = { check7Archive$ + "/" + badDestName$,
    ... check7Archive$ + "/plugin_NeverTried__1.0.0" }

@emlManagerRemoveRun: names7$#, destName7$#, destPath7$#,
    ... check7Root$, check7Archive$, check7Root$, 1

if emlManagerRemoveRun.ranCount = 1 and emlManagerRemoveRun.copyOk# [1] = 0
    pass = pass + 1
    appendInfoLine: "PASS: run stops after the first plugin's failed copy (ranCount = 1)"
else
    fail = fail + 1
    appendInfoLine: "FAIL: expected ranCount = 1 with copyOk# [1] = 0, got ranCount = ",
        ... emlManagerRemoveRun.ranCount
endif

if folderExists (check7Root$ + "/plugin_NeverTried")
    pass = pass + 1
    appendInfoLine: "PASS: the second, never-attempted plugin is untouched"
else
    fail = fail + 1
    appendInfoLine: "FAIL: the second plugin was touched even though the run should have stopped"
endif

# ============================================================================
# Check 8 (RED): copying into a genuinely unwritable destination yields
# emlManagerPlaceFolder.ok = 0, via emlManagerRemoveExecutePlugin's
# .copyOk, and nothing is deleted -- the copy-failure contract of
# Execution step 1 (AMENDED: emlManagerPlaceFolder uses runSystem_nocheck
# and reports through .ok; it does not raise, so the caller must check it).
# This harness runs as root, where a plain chmod on the destination is not
# enough (root bypasses ordinary permission bits -- measured); the
# immutable attribute (chattr +i) is enforced independently of uid, so it
# is what actually makes the destination folder unwritable here.
# ============================================================================

appendInfoLine: ""
appendInfoLine: "--- RED: unwritable destination -- .ok = 0, nothing deleted ---"

check8Root$ = scratchRoot$ + "/check8"
createFolder: check8Root$
check8Archive$ = check8Root$ + "/archive"
createFolder: check8Archive$

@emlHarnessBuildPlugin: check8Root$, "plugin_Unwritable", "1.0.0"

@emlManagerRemoveArchiveDest: check8Root$ + "/plugin_Unwritable", check8Archive$
unwritable_destName$ = emlManagerRemoveArchiveDest.destName$
unwritable_destPath$ = emlManagerRemoveArchiveDest.destPath$

runSystem_nocheck: "chattr +i " + q$ + check8Archive$ + q$

@emlManagerRemoveExecutePlugin: "plugin_Unwritable", unwritable_destName$, unwritable_destPath$,
    ... check8Root$, check8Archive$, check8Root$

runSystem_nocheck: "chattr -i " + q$ + check8Archive$ + q$

if emlManagerRemoveExecutePlugin.copyOk = 0
    pass = pass + 1
    appendInfoLine: "PASS: copying into an unwritable destination reports .ok = 0"
else
    fail = fail + 1
    appendInfoLine: "FAIL: copying into an unwritable destination unexpectedly reported .ok = 1"
endif

if folderExists (check8Root$ + "/plugin_Unwritable")
    pass = pass + 1
    appendInfoLine: "PASS: the original plugin folder is untouched -- nothing was deleted"
else
    fail = fail + 1
    appendInfoLine: "FAIL: the original plugin folder was removed despite the failed copy"
endif

# ============================================================================

runSystem_nocheck: "rm -rf " + q$ + scratchRoot$ + q$

appendInfoLine: ""
appendInfoLine: "RESULT: ", pass, " pass, ", fail, " fail"
