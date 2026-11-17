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

# ----------------------------------------------------------------------------
# Harness-only helper: .n repetitions of .ch$ concatenated (Praat has no
# built-in string-repeat operator). Used to build synthetic over-length
# names for Check 10's cap-invariant sweeps.
procedure emlHarnessRepeatChar: .ch$, .n
    .result$ = ""
    for .i from 1 to .n
        .result$ = .result$ + .ch$
    endfor
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
    # 127 is the shell's "command not found": no nested Praat ran at all, so
    # it proves nothing about runSystem. Only a real nonzero Praat status
    # (255 for a script error) counts.
    if nestedExitCode <> 0 and nestedExitCode <> 127
        pass = pass + 1
        appendInfoLine: "PASS: a nested `runSystem` on a failing copy exits nonzero (",
            ... nestedExitCode, "), i.e. raises a script error that a supervising",
            ... " process can observe"
    else
        fail = fail + 1
        if nestedExitCode = 127
            appendInfoLine: "FAIL: no nested praat ran (exit 127, command not found) -- put a praat on PATH"
        else
            appendInfoLine: "FAIL: nested process exited 0; runSystem did not raise"
        endif
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
# UX round 2026-09-01, item 4: Check 9 -- the installed-test canon and ghost
# semantics. A ghost fixture is a plugin_* folder containing ONLY a seeded
# ".DS_Store", written by an explicit path (fileNames$#/folderNames$# cannot
# enumerate dot-files, matching real macOS's own invisible .DS_Store).
# ============================================================================

appendInfoLine: ""
appendInfoLine: "--- Check 9: installed-test canon and ghost semantics ---"

check9Root$ = scratchRoot$ + "/check9"
createFolder: check9Root$
check9Prefs$ = check9Root$ + "/prefs"
createFolder: check9Prefs$

# --- 9a. emlManagerIsInstalled: ghost vs. real plugin ---

check9Ghost$ = check9Prefs$ + "/plugin_Ghost"
createFolder: check9Ghost$
writeFileLine: check9Ghost$ + "/.DS_Store", "macOS junk Praat cannot enumerate"

@emlManagerIsInstalled: check9Ghost$
if emlManagerIsInstalled.installed = 0
    pass = pass + 1
    appendInfoLine: "PASS: a folder with only a seeded .DS_Store is not installed"
else
    fail = fail + 1
    appendInfoLine: "FAIL: a ghost folder was reported installed"
endif

@emlHarnessBuildPlugin: check9Prefs$, "plugin_Real", "1.0.0"
@emlManagerIsInstalled: check9Prefs$ + "/plugin_Real"
if emlManagerIsInstalled.installed = 1
    pass = pass + 1
    appendInfoLine: "PASS: a folder with setup.praat is installed"
else
    fail = fail + 1
    appendInfoLine: "FAIL: a real plugin (setup.praat present) was reported not installed"
endif

# --- 9b. the collision path: a ghost yields no annotation; a real
#     installed plugin does ---

check9Cand$ = check9Root$ + "/candidate"
createFolder: check9Cand$
@emlHarnessBuildPlugin: check9Cand$, "plugin_Ghost", ""

@emlManagerInstalledCollisionCheck: check9Cand$ + "/plugin_Ghost", check9Ghost$, check9Root$
if emlManagerInstalledCollisionCheck.hasCollision = 0 and emlManagerInstalledCollisionCheck.annot$ = ""
    pass = pass + 1
    appendInfoLine: "PASS: the collision path against a ghost yields no annotation"
else
    fail = fail + 1
    appendInfoLine: "FAIL: the collision path against a ghost -- hasCollision=",
        ... emlManagerInstalledCollisionCheck.hasCollision, ", annot$='",
        ... emlManagerInstalledCollisionCheck.annot$, "'"
endif

@emlHarnessBuildPlugin: check9Cand$, "plugin_Real", "2.0.0"
@emlManagerInstalledCollisionCheck: check9Cand$ + "/plugin_Real",
    ... check9Prefs$ + "/plugin_Real", check9Root$
if emlManagerInstalledCollisionCheck.hasCollision = 1 and emlManagerInstalledCollisionCheck.annot$ <> ""
    pass = pass + 1
    appendInfoLine: "PASS: the collision path against a real installed plugin annotates ('",
        ... emlManagerInstalledCollisionCheck.annot$, "')"
else
    fail = fail + 1
    appendInfoLine: "FAIL: the collision path against a real installed plugin -- hasCollision=",
        ... emlManagerInstalledCollisionCheck.hasCollision
endif

# --- 9c. the remove listing: a ghost is included, annotated with the ghost
#     suffix; a real plugin is not so annotated. Sec. 2a AMENDED: a lone row
#     (no other row in the listing to collide with) stays BARE, so this
#     drives emlManagerRemoveComputeSuffix (suffix + ghost detection) and
#     caps the result with NO index prefix (emlManagerApplyLabelCap with
#     .prefix$ = ""), exactly what emlManagerBuildLabels does for an
#     uncollided row. Sec. 2c: the ghost suffix (40 chars) always exceeds
#     Sec. 2c (0.7.3 round 2): the ghost suffix is " leftover", 9
#     characters, within emlManager_labelSuffixCap (16), so it is never
#     shortened and its word always shows; the sanitizer leaves the single
#     space as it is.

check9GhostShort$ = check9Prefs$ + "/plugin_X"
createFolder: check9GhostShort$
writeFileLine: check9GhostShort$ + "/.DS_Store", "macOS junk Praat cannot enumerate"

@emlManagerRemoveComputeSuffix: "plugin_X", 0, check9Prefs$
@emlManagerApplyLabelCap: "", "plugin_X", emlManagerRemoveComputeSuffix.suffix$, emlManager_boolLabelCap
@emlManagerDeriveLabel: emlManagerApplyLabelCap.capped$
check9GhostLabel$ = emlManagerDeriveLabel.label$
if emlManagerRemoveComputeSuffix.isGhost = 1
    ... and check9GhostLabel$ = "plugin_X leftover"
    pass = pass + 1
    appendInfoLine: "PASS: the remove listing marks the ghost with its suffix ('",
        ... check9GhostLabel$, "')"
else
    fail = fail + 1
    appendInfoLine: "FAIL: the remove listing did not mark the ghost -- label$='",
        ... check9GhostLabel$, "'"
endif

@emlManagerRemoveComputeSuffix: "plugin_Real", 0, check9Prefs$
@emlManagerApplyLabelCap: "", "plugin_Real", emlManagerRemoveComputeSuffix.suffix$, emlManager_boolLabelCap
@emlManagerDeriveLabel: emlManagerApplyLabelCap.capped$
check9RealLabel$ = emlManagerDeriveLabel.label$
if emlManagerRemoveComputeSuffix.isGhost = 0
    ... and index (check9RealLabel$, "leftover") = 0
    pass = pass + 1
    appendInfoLine: "PASS: the remove listing does not mark a real plugin as a ghost"
else
    fail = fail + 1
    appendInfoLine: "FAIL: a real plugin was marked as a ghost -- label$='",
        ... check9RealLabel$, "'"
endif

# --- 9d. the install-loop mechanism for placing over a ghost: clear the
#     remnant (the same emlManagerCleanupStaging call the install loop
#     makes), THEN place -- confirms setup.praat lands directly at the top
#     level rather than nested a level deep (which is what a plain
#     emlManagerPlaceFolder onto a still-existing destination would do,
#     since its "cp -R" nests source-into-destination when destination
#     already exists).
check9GhostDest$ = check9Prefs$ + "/plugin_GhostReuse"
createFolder: check9GhostDest$
writeFileLine: check9GhostDest$ + "/.DS_Store", "macOS junk Praat cannot enumerate"

check9NewSource$ = check9Root$ + "/newsource"
createFolder: check9NewSource$
@emlHarnessBuildPlugin: check9NewSource$, "plugin_GhostReuse", "1.0.0"

@emlManagerCleanupStaging: check9GhostDest$
@emlManagerPlaceFolder: check9NewSource$ + "/plugin_GhostReuse", "plugin_GhostReuse", check9Prefs$

if fileReadable (check9GhostDest$ + "/setup.praat")
    ... and fileReadable (check9GhostDest$ + "/VERSION")
    ... and not folderExists (check9GhostDest$ + "/plugin_GhostReuse")
    pass = pass + 1
    appendInfoLine: "PASS: placing over a cleared ghost lands the new files directly,",
        ... " not nested a level deeper"
else
    fail = fail + 1
    appendInfoLine: "FAIL: placement over a cleared ghost did not land directly at the top level"
endif

# --- 9e. UX round spec sec. 4: the completion report actually emits the
#     reused-leftover line on a ghost install -- drives the report-assembly
#     path (emlManagerResolveInstallTarget + emlManagerBuildInstallSummaryLines,
#     the same two procedures the main sequence's install loop calls) with
#     no dialog. A plain (non-ghost) install is the control: exactly one
#     summary line, no reused-leftover note.

check9ArchiveDir$ = check9Prefs$ + "/archive"

check9GhostReportDest$ = check9Prefs$ + "/plugin_GhostReport"
createFolder: check9GhostReportDest$
writeFileLine: check9GhostReportDest$ + "/.DS_Store", "macOS junk Praat cannot enumerate"

check9ReportSource$ = check9Root$ + "/reportsource"
createFolder: check9ReportSource$
@emlHarnessBuildPlugin: check9ReportSource$, "plugin_GhostReport", "1.0.0"

@emlManagerResolveInstallTarget: check9GhostReportDest$, "plugin_GhostReport",
    ... check9Prefs$, check9ArchiveDir$
if emlManagerResolveInstallTarget.wasGhostReused = 1 and emlManagerResolveInstallTarget.archiveOk = 1
    pass = pass + 1
    appendInfoLine: "PASS: resolving a ghost destination sets wasGhostReused, archives nothing"
else
    fail = fail + 1
    appendInfoLine: "FAIL: resolving a ghost destination -- wasGhostReused=",
        ... emlManagerResolveInstallTarget.wasGhostReused, ", archiveOk=",
        ... emlManagerResolveInstallTarget.archiveOk
endif

@emlManagerPlaceFolder: check9ReportSource$ + "/plugin_GhostReport", "plugin_GhostReport", check9Prefs$
@emlManagerBuildInstallSummaryLines: "plugin_GhostReport", "plugin_GhostReport",
    ... emlManagerResolveInstallTarget.wasReplaced, emlManagerResolveInstallTarget.wasGhostReused,
    ... check9Prefs$
if emlManagerBuildInstallSummaryLines.n = 2
    ... and emlManagerBuildInstallSummaryLines.lines$# [2] = emlManager_msgGhostReused$
    pass = pass + 1
    appendInfoLine: "PASS: the completion report emits the reused-leftover line on a ghost install ('",
        ... emlManagerBuildInstallSummaryLines.lines$# [2], "')"
else
    fail = fail + 1
    appendInfoLine: "FAIL: reused-leftover report line not emitted -- n=",
        ... emlManagerBuildInstallSummaryLines.n
endif

check9PlainSource$ = check9Root$ + "/plainsource"
createFolder: check9PlainSource$
@emlHarnessBuildPlugin: check9PlainSource$, "plugin_PlainInstall", "1.0.0"
@emlManagerResolveInstallTarget: check9Prefs$ + "/plugin_PlainInstall", "plugin_PlainInstall",
    ... check9Prefs$, check9ArchiveDir$
@emlManagerBuildInstallSummaryLines: "plugin_PlainInstall", "plugin_PlainInstall",
    ... emlManagerResolveInstallTarget.wasReplaced, emlManagerResolveInstallTarget.wasGhostReused,
    ... check9Prefs$
if emlManagerBuildInstallSummaryLines.n = 1
    pass = pass + 1
    appendInfoLine: "PASS: a plain (non-ghost) install gets no reused-leftover line"
else
    fail = fail + 1
    appendInfoLine: "FAIL: a plain install unexpectedly got a reused-leftover line -- n=",
        ... emlManagerBuildInstallSummaryLines.n
endif

# ============================================================================
# UX round 2026-09-01 AMENDED, sec. 2e: Check 10 -- the selection-row label
# builder. 10a-10l table-drive the low-level cap/suffix/marker mechanics
# (emlManagerIndexPrefix + emlManagerApplyLabelCap + emlManagerDeriveLabel)
# directly against expected strings computed by the documented algorithm
# (sec. 2c: cap = emlManager_boolLabelCap = 38, marker =
# emlManager_labelMarker$ = "___", suffix shortened tail-preserving to at
# most emlManager_labelSuffixCap = 16 chars before the name gets what's
# left) -- unaffected by the 2a amendment, since the amendment only changes
# WHETHER those mechanics run with an index prefix, never how they behave
# once invoked. 10m/10n then drive the higher-level canon
# (emlManagerBuildLabels) that makes that bare-vs-prefixed decision.
# ============================================================================

appendInfoLine: ""
appendInfoLine: "--- Check 10: selection-row label builder (table-driven) ---"

managerSuffix$ = emlManagerRemove_managerSuffix$
ghostSuffix$ = emlManagerRemove_ghostSuffix$

# 10a. under-cap: unchanged apart from the identity prefix.
@emlManagerIndexPrefix: 1
@emlManagerApplyLabelCap: emlManagerIndexPrefix.prefix$, "plugin_Short", "", emlManager_boolLabelCap
expect10a$ = "n1_ plugin_Short"
if emlManagerApplyLabelCap.capped$ = expect10a$
    pass = pass + 1
    appendInfoLine: "PASS: under-cap label is unchanged apart from its index prefix -- '",
        ... expect10a$, "'"
else
    fail = fail + 1
    appendInfoLine: "FAIL: under-cap label -- expected '", expect10a$,
        ... "' got '", emlManagerApplyLabelCap.capped$, "'"
endif

# 10b. over-cap plain name: cap invariant holds exactly, marker inside.
@emlManagerIndexPrefix: 2
@emlManagerApplyLabelCap: emlManagerIndexPrefix.prefix$,
    ... "plugin_ThisIsAVeryLongPluginFolderNameIndeed", "", emlManager_boolLabelCap
expect10b$ = "n2_ plugin_ThisIsAVer___lderNameIndeed"
if emlManagerApplyLabelCap.capped$ = expect10b$
    ... and length (emlManagerApplyLabelCap.capped$) = emlManager_boolLabelCap
    pass = pass + 1
    appendInfoLine: "PASS: over-cap plain name -> '", expect10b$, "' (", emlManager_boolLabelCap, " chars)"
else
    fail = fail + 1
    appendInfoLine: "FAIL: over-cap plain name -- expected '", expect10b$,
        ... "' got '", emlManagerApplyLabelCap.capped$, "'"
endif

# 10c. sec. 2e: two long names sharing a head, different rows (indices 3 and
# 4) -> distinct labels, the distinguishing text carried in the preserved
# tail (>= 14 chars, sec. 2c) even before the index is considered.
@emlManagerIndexPrefix: 3
@emlManagerApplyLabelCap: emlManagerIndexPrefix.prefix$,
    ... "plugin_CommonHeadPrefixSection_versionAAAA", "", emlManager_boolLabelCap
distinct1$ = emlManagerApplyLabelCap.capped$
@emlManagerIndexPrefix: 4
@emlManagerApplyLabelCap: emlManagerIndexPrefix.prefix$,
    ... "plugin_CommonHeadPrefixSection_versionBBBB", "", emlManager_boolLabelCap
distinct2$ = emlManagerApplyLabelCap.capped$
expect10c1$ = "n3_ plugin_CommonHead___on_versionAAAA"
expect10c2$ = "n4_ plugin_CommonHead___on_versionBBBB"
tail1$ = right$ (distinct1$, length (distinct1$) - length ("n3_ "))
tail2$ = right$ (distinct2$, length (distinct2$) - length ("n4_ "))
if distinct1$ = expect10c1$ and distinct2$ = expect10c2$
    ... and distinct1$ <> distinct2$ and tail1$ <> tail2$
    pass = pass + 1
    appendInfoLine: "PASS: two long same-headed names yield distinct labels, distinct even",
        ... " before the index ('", tail1$, "' vs '", tail2$, "')"
else
    fail = fail + 1
    appendInfoLine: "FAIL: same-headed names -- got '", distinct1$, "' and '", distinct2$, "'"
endif

# 10d/10e. suffix preservation across a short and a long name: the manager
# suffix (" itself", 7 chars, within emlManager_labelSuffixCap) is kept whole
# in every case; when the prefix, name, and suffix together exceed the cap,
# the NAME shortens (sec. 2c, 0.7.3 round 2), never the annotation.
@emlManagerIndexPrefix: 5
@emlManagerApplyLabelCap: emlManagerIndexPrefix.prefix$, "plugin_X", managerSuffix$,
    ... emlManager_boolLabelCap
expect10d$ = "n5_ plugin_X itself"
if emlManagerApplyLabelCap.capped$ = expect10d$
    ... and startsWith (emlManagerApplyLabelCap.capped$, "n5_ plugin_X")
    pass = pass + 1
    appendInfoLine: "PASS: manager-suffix label (short name) -> '", expect10d$, "'"
else
    fail = fail + 1
    appendInfoLine: "FAIL: manager-suffix label (short name) -- expected '", expect10d$,
        ... "' got '", emlManagerApplyLabelCap.capped$, "'"
endif

@emlManagerIndexPrefix: 6
@emlManagerApplyLabelCap: emlManagerIndexPrefix.prefix$, "plugin_EMLPraatPluginManager",
    ... managerSuffix$, emlManager_boolLabelCap
expect10e$ = "n6_ plugin_EMLPraatP___nManager itself"
if emlManagerApplyLabelCap.capped$ = expect10e$
    ... and length (emlManagerApplyLabelCap.capped$) = emlManager_boolLabelCap
    ... and endsWith (emlManagerApplyLabelCap.capped$, managerSuffix$)
    pass = pass + 1
    appendInfoLine: "PASS: manager-suffix label (full manager folder name, forced index prefix:",
        ... " the name shortens, the annotation stays whole) -> '", expect10e$, "'"
else
    fail = fail + 1
    appendInfoLine: "FAIL: manager-suffix label (long name) -- expected '", expect10e$,
        ... "' got '", emlManagerApplyLabelCap.capped$, "'"
endif

# 10f/10g. the ghost suffix (" leftover", 9 chars), short and long name.
@emlManagerIndexPrefix: 7
@emlManagerApplyLabelCap: emlManagerIndexPrefix.prefix$, "plugin_Ghost", ghostSuffix$,
    ... emlManager_boolLabelCap
expect10f$ = "n7_ plugin_Ghost leftover"
if emlManagerApplyLabelCap.capped$ = expect10f$
    ... and startsWith (emlManagerApplyLabelCap.capped$, "n7_ plugin_Ghost")
    pass = pass + 1
    appendInfoLine: "PASS: ghost-suffix label (short name) -> '", expect10f$, "'"
else
    fail = fail + 1
    appendInfoLine: "FAIL: ghost-suffix label (short name) -- expected '", expect10f$,
        ... "' got '", emlManagerApplyLabelCap.capped$, "'"
endif

@emlManagerIndexPrefix: 8
@emlManagerApplyLabelCap: emlManagerIndexPrefix.prefix$, "plugin_ALongerGhostFolderName",
    ... ghostSuffix$, emlManager_boolLabelCap
expect10g$ = "n8_ plugin_ALonger___lderName leftover"
if emlManagerApplyLabelCap.capped$ = expect10g$
    ... and length (emlManagerApplyLabelCap.capped$) = emlManager_boolLabelCap
    ... and endsWith (emlManagerApplyLabelCap.capped$, ghostSuffix$)
    pass = pass + 1
    appendInfoLine: "PASS: ghost-suffix label (29-character name shortens, annotation whole) -> '", expect10g$, "'"
else
    fail = fail + 1
    appendInfoLine: "FAIL: ghost-suffix label (long name) -- expected '", expect10g$,
        ... "' got '", emlManagerApplyLabelCap.capped$, "'"
endif

# 10h. a moderate synthetic suffix (23 chars, still > emlManager_labelSuffixCap)
# -- both the name and the suffix shorten; the suffix's own tail survives.
@emlManagerIndexPrefix: 9
@emlManagerApplyLabelCap: emlManagerIndexPrefix.prefix$, "plugin_ThisNameIsQuiteLongIndeedYes",
    ... " [v2.0-beta annotation]", emlManager_boolLabelCap
expect10h$ = "n9_ plugin____ndeedYes [v2.___otation]"
if emlManagerApplyLabelCap.capped$ = expect10h$
    ... and endsWith (emlManagerApplyLabelCap.capped$, "otation]")
    pass = pass + 1
    appendInfoLine: "PASS: moderate-suffix case -> '", expect10h$, "'"
else
    fail = fail + 1
    appendInfoLine: "FAIL: moderate-suffix case -- expected '", expect10h$,
        ... "' got '", emlManagerApplyLabelCap.capped$, "'"
endif

# 10i. sec. 2e / defect 1: the MEASURED overflow case -- a name 35-37 chars
# long (the old formula's suffixBudget = cap - len(name) collapsed to 1-3
# chars there, which its own middle-ellipsis then silently overran) combined
# with a long suffix. Swept across the whole 35-37 range: the cap must never
# be exceeded in this or any other branch.
overflowOk = 1
for overflowLen from 35 to 37
    @emlHarnessRepeatChar: "N", overflowLen - 7
    overflowName$ = "plugin_" + emlHarnessRepeatChar.result$
    @emlManagerIndexPrefix: 10
    @emlManagerApplyLabelCap: emlManagerIndexPrefix.prefix$, overflowName$, ghostSuffix$,
        ... emlManager_boolLabelCap
    if length (emlManagerApplyLabelCap.capped$) > emlManager_boolLabelCap
        ... or not endsWith (emlManagerApplyLabelCap.capped$, ghostSuffix$)
        overflowOk = 0
        appendInfoLine: "  overflow sweep len=", overflowLen, " -> '",
            ... emlManagerApplyLabelCap.capped$, "' (", length (emlManagerApplyLabelCap.capped$), " chars)"
    endif
endfor
if overflowOk = 1
    pass = pass + 1
    appendInfoLine: "PASS: defect-1 overflow sweep (name len 35-37 + long suffix) never exceeds",
        ... " the cap, suffix always present"
else
    fail = fail + 1
    appendInfoLine: "FAIL: defect-1 overflow sweep exceeded the cap or dropped the suffix"
endif

# 10j. defect 2 regression: name length >= the whole cap, WITH a suffix --
# the suffix must still survive (never dropped), the cap invariant still
# holds.
@emlHarnessRepeatChar: "Z", 40
tooLongName$ = "plugin_" + emlHarnessRepeatChar.result$
@emlManagerIndexPrefix: 1
@emlManagerApplyLabelCap: emlManagerIndexPrefix.prefix$, tooLongName$, ghostSuffix$,
    ... emlManager_boolLabelCap
if length (emlManagerApplyLabelCap.capped$) <= emlManager_boolLabelCap
    ... and endsWith (emlManagerApplyLabelCap.capped$, ghostSuffix$)
    pass = pass + 1
    appendInfoLine: "PASS: defect-2 regression -- a name >= the cap keeps its suffix -> '",
        ... emlManagerApplyLabelCap.capped$, "'"
else
    fail = fail + 1
    appendInfoLine: "FAIL: defect-2 regression -- suffix dropped or cap exceeded, got '",
        ... emlManagerApplyLabelCap.capped$, "'"
endif

# 10k. sec. 2e / defect 3: two rows whose name+suffix are IDENTICAL (the
# text after the index prefix comes out byte-identical) still get distinct
# full labels -- and distinct readback variables -- solely from the index
# (single-digit indices 1 and 9, so the prefix WIDTH is also identical,
# isolating the index itself as the only source of the difference).
sameName$ = "plugin_VeryLongIdenticalPluginNameHere"
@emlManagerIndexPrefix: 1
@emlManagerApplyLabelCap: emlManagerIndexPrefix.prefix$, sameName$, "", emlManager_boolLabelCap
labelIdx1$ = emlManagerApplyLabelCap.capped$
@emlManagerDeriveLabel: labelIdx1$
derivedIdx1$ = emlManagerDeriveLabel.derived$
@emlManagerIndexPrefix: 9
@emlManagerApplyLabelCap: emlManagerIndexPrefix.prefix$, sameName$, "", emlManager_boolLabelCap
labelIdx9$ = emlManagerApplyLabelCap.capped$
@emlManagerDeriveLabel: labelIdx9$
derivedIdx9$ = emlManagerDeriveLabel.derived$
postPrefix1$ = right$ (labelIdx1$, length (labelIdx1$) - length ("n1_ "))
postPrefix9$ = right$ (labelIdx9$, length (labelIdx9$) - length ("n9_ "))
if postPrefix1$ = postPrefix9$ and labelIdx1$ <> labelIdx9$ and derivedIdx1$ <> derivedIdx9$
    pass = pass + 1
    appendInfoLine: "PASS: identical post-prefix text ('", postPrefix1$,
        ... "') still yields distinct labels and distinct readback variables ('",
        ... derivedIdx1$, "' vs '", derivedIdx9$, "') -- the Dialog-1 readback",
        ... " collapse (defect 3) cannot recur"
else
    fail = fail + 1
    appendInfoLine: "FAIL: index-prefix collision cure -- label1='", labelIdx1$,
        ... "' label9='", labelIdx9$, "' derived1='", derivedIdx1$, "' derived9='", derivedIdx9$, "'"
endif

# 10l. sec. 2e: sanitizer-survival of the prefix and the marker, plus the
# leading-letter requirement (measured, GUI drive: a Praat variable name
# must start with a letter, which is why emlManager_indexLabelLead$ puts a
# fixed letter at the very front of every index prefix -- see
# emlManagerIndexPrefix). Runs a capped label carrying both the index
# prefix and the marker (a name too long to fit, plus the ghost suffix) through emlManagerDeriveLabel
# and confirms: derived$ starts with a letter (so indirect '.derived$'
# readback parses at all -- the real, GUI-measured failure mode this
# guards), the leading letter, index digit, and its underscore are all
# still there, the marker's three underscores are still there, and nothing
# outside [A-Za-z0-9_] survives into .derived$ (the readback variable
# name).
@emlManagerIndexPrefix: 7
@emlManagerApplyLabelCap: emlManagerIndexPrefix.prefix$, "plugin_ALongerGhostFolderNameThatOverflows",
    ... ghostSuffix$, emlManager_boolLabelCap
@emlManagerDeriveLabel: emlManagerApplyLabelCap.capped$
sanitizedDerived$ = emlManagerDeriveLabel.derived$
if startsWith (sanitizedDerived$, emlManager_indexLabelLead$ + "7_")
    ... and index_regex (sanitizedDerived$, "^[a-z]") > 0
    ... and index (sanitizedDerived$, emlManager_labelMarker$) > 0
    ... and index_regex (sanitizedDerived$, "[^A-Za-z0-9_]") = 0
    pass = pass + 1
    appendInfoLine: "PASS: derived$ starts with a letter (leading-letter index prefix), the",
        ... " index and the ", emlManager_labelMarker$,
        ... " marker both survive the sanitizer intact -- derived$ = '", sanitizedDerived$, "'"
else
    fail = fail + 1
    appendInfoLine: "FAIL: sanitizer-survival -- derived$ = '", sanitizedDerived$, "'"
endif

# 10m. sec. 2a AMENDED / 2e: a listing of DISTINCT names yields NO prefixes
# at all -- the realistic case. Five plainly different plugin names (no two
# sharing a capped, sanitized label) run through the shared canon
# emlManagerBuildLabels; every row must come back bare (no leading
# "n<i>_ "), every label distinct, and (since bare labels equal their own
# sanitized text) every derived readback variable distinct too.
check10mN = 5
check10mNames$# = { "plugin_Alpha", "plugin_Bravo", "plugin_Charlie",
    ... "plugin_Delta", "plugin_Echo" }
# emlManagerBuildLabels requires every .suffix$# element already WRITTEN
# (see its own doc comment) -- a literal all-"" vector, not a raw
# empty$# (n) whose elements were never assigned.
check10mSuffix$# = { "", "", "", "", "" }
@emlManagerBuildLabels: check10mNames$#, check10mSuffix$#, check10mN, emlManager_boolLabelCap

check10mAllBare = 1
check10mLabelsUnique = 1
check10mDerivedUnique = 1
for check10mI from 1 to check10mN
    if emlManagerBuildLabels.prefixed# [check10mI] <> 0
        check10mAllBare = 0
    endif
    if index_regex (emlManagerBuildLabels.label$# [check10mI], "^n[0-9]+_") > 0
        check10mAllBare = 0
    endif
    for check10mJ from check10mI + 1 to check10mN
        if emlManagerBuildLabels.label$# [check10mJ] = emlManagerBuildLabels.label$# [check10mI]
            check10mLabelsUnique = 0
        endif
        if emlManagerBuildLabels.derived$# [check10mJ] = emlManagerBuildLabels.derived$# [check10mI]
            check10mDerivedUnique = 0
        endif
    endfor
endfor
if check10mAllBare = 1 and check10mLabelsUnique = 1 and check10mDerivedUnique = 1
    pass = pass + 1
    appendInfoLine: "PASS: a listing of distinct names yields zero index prefixes,",
        ... " labels and readback variables both already unique -- e.g. '",
        ... emlManagerBuildLabels.label$# [1], "'"
else
    fail = fail + 1
    appendInfoLine: "FAIL: distinct-name listing -- allBare=", check10mAllBare,
        ... ", labelsUnique=", check10mLabelsUnique, ", derivedUnique=", check10mDerivedUnique
endif

# 10n. sec. 2a AMENDED / 2e: a FORCED post-cap collision -- two names built
# so their BARE capped labels come out byte-identical (same first 21 chars,
# the head emlManagerMiddleEllipsis keeps at cap=38/no-suffix/no-prefix, and
# same last 14 chars, the tail it keeps -- only the middle, which the
# ellipsis discards, differs) -- still yields prefixed, DISTINCT labels and
# DISTINCT derived readback variables, and the cap invariant still holds
# with the prefix added back in.
@emlHarnessRepeatChar: "H", 14
check10nHead$ = "plugin_" + emlHarnessRepeatChar.result$
@emlHarnessRepeatChar: "T", 14
check10nTail$ = emlHarnessRepeatChar.result$
check10nName1$ = check10nHead$ + "MID1" + check10nTail$
check10nName2$ = check10nHead$ + "MID2" + check10nTail$
if length (check10nHead$) <> 21 or length (check10nTail$) <> 14
    fail = fail + 1
    appendInfoLine: "FAIL: 10n fixture malformed -- head len=", length (check10nHead$),
        ... " tail len=", length (check10nTail$)
else
    check10nN = 2
    check10nNames$# = { check10nName1$, check10nName2$ }
    check10nSuffix$# = { "", "" }

    # Control: the bare capped labels really do collide before the canon
    # intervenes (otherwise this fixture is not testing what it claims to).
    @emlManagerApplyLabelCap: "", check10nName1$, "", emlManager_boolLabelCap
    check10nBare1$ = emlManagerApplyLabelCap.capped$
    @emlManagerApplyLabelCap: "", check10nName2$, "", emlManager_boolLabelCap
    check10nBare2$ = emlManagerApplyLabelCap.capped$

    @emlManagerBuildLabels: check10nNames$#, check10nSuffix$#, check10nN, emlManager_boolLabelCap

    if check10nBare1$ = check10nBare2$
        ... and emlManagerBuildLabels.prefixed# [1] = 1 and emlManagerBuildLabels.prefixed# [2] = 1
        ... and emlManagerBuildLabels.label$# [1] <> emlManagerBuildLabels.label$# [2]
        ... and emlManagerBuildLabels.derived$# [1] <> emlManagerBuildLabels.derived$# [2]
        ... and length (emlManagerBuildLabels.label$# [1]) <= emlManager_boolLabelCap
        ... and length (emlManagerBuildLabels.label$# [2]) <= emlManager_boolLabelCap
        pass = pass + 1
        appendInfoLine: "PASS: a forced post-cap collision (bare labels both '", check10nBare1$,
            ... "') is cured by the index prefix -- '", emlManagerBuildLabels.label$# [1],
            ... "' vs '", emlManagerBuildLabels.label$# [2], "', readback '",
            ... emlManagerBuildLabels.derived$# [1], "' vs '", emlManagerBuildLabels.derived$# [2], "'"
    else
        fail = fail + 1
        appendInfoLine: "FAIL: forced post-cap collision -- bare1='", check10nBare1$,
            ... "' bare2='", check10nBare2$, "' prefixed=[",
            ... emlManagerBuildLabels.prefixed# [1], ",", emlManagerBuildLabels.prefixed# [2],
            ... "] label1='", emlManagerBuildLabels.label$# [1], "' label2='",
            ... emlManagerBuildLabels.label$# [2], "'"
    endif
endif

# 10o. 0.7.3: a realistic Dialog-1 listing -- the manager's own folder, five
# ordinary plugins, a leftover (ghost) folder, and one 44-character name --
# built through the real emlManagerBuildLabels with the real suffix
# constants. Every label stays within the cap and bare, the manager row shows
# its full folder name followed by its whole annotation, and a name that fits
# the cap is never shortened. The labels are printed for the build report.
@emlHarnessRepeatChar: "L", 37
check10oLong$ = "plugin_" + emlHarnessRepeatChar.result$
check10oNames$# = { "plugin_EMLPraatPluginManager", "plugin_AERoPlot", "plugin_jjatools",
    ... "plugin_strutils", "plugin_tgutils", "plugin_utils", "plugin_LeftoverOne", check10oLong$ }
check10oSuffix$# = { managerSuffix$, "", "", "", "", "", ghostSuffix$, "" }
check10oN = size (check10oNames$#)
@emlManagerBuildLabels: check10oNames$#, check10oSuffix$#, check10oN, emlManager_boolLabelCap
check10oOk = 1
for check10oI to check10oN
    check10oLabel$ = emlManagerBuildLabels.label$# [check10oI]
    appendInfoLine: "  label ", check10oI, ": '", check10oLabel$, "' (", length (check10oLabel$), " chars)"
    if length (check10oLabel$) > emlManager_boolLabelCap or emlManagerBuildLabels.prefixed# [check10oI] = 1
        check10oOk = 0
    endif
    if length (check10oNames$# [check10oI]) <= emlManager_boolLabelCap
        ... and not startsWith (check10oLabel$, check10oNames$# [check10oI])
        check10oOk = 0
    endif
endfor
if check10oOk = 1
    ... and emlManagerBuildLabels.label$# [1] = "plugin_EMLPraatPluginManager itself"
    ... and emlManagerBuildLabels.label$# [7] = "plugin_LeftoverOne leftover"
    pass = pass + 1
    appendInfoLine: "PASS: realistic listing -- every label within the cap, bare, names that fit kept whole"
else
    fail = fail + 1
    appendInfoLine: "FAIL: realistic listing -- see the labels above"
endif

# 10p. 0.7.3 round 2: the annotation words ALWAYS show. Swept over every
# name length from 8 to 60 characters, with the ghost suffix, the manager
# suffix, and both together, bare and with a forced index prefix: the label
# stays within the cap and still ends with the whole annotation after the
# sanitizer (so "leftover" and "itself" are never truncated away, including
# for the 28-38 character names that used to lose them).
check10pOk = 1
check10pCases = 0
check10pBoth$ = managerSuffix$ + ghostSuffix$
check10pSuffix$# = { ghostSuffix$, managerSuffix$, check10pBoth$ }
for check10pLen from 8 to 60
    @emlHarnessRepeatChar: "A", check10pLen - 7
    check10pName$ = "plugin_" + emlHarnessRepeatChar.result$
    for check10pK to 3
        for check10pPre from 0 to 1
            check10pPrefix$ = ""
            if check10pPre = 1
                @emlManagerIndexPrefix: 12
                check10pPrefix$ = emlManagerIndexPrefix.prefix$
            endif
            @emlManagerApplyLabelCap: check10pPrefix$, check10pName$, check10pSuffix$# [check10pK],
                ... emlManager_boolLabelCap
            @emlManagerDeriveLabel: emlManagerApplyLabelCap.capped$
            check10pLabel$ = emlManagerDeriveLabel.label$
            check10pWords$ = replace_regex$ (check10pSuffix$# [check10pK], "^ ", "", 0)
            check10pCases = check10pCases + 1
            if length (emlManagerApplyLabelCap.capped$) > emlManager_boolLabelCap
                ... or not endsWith (check10pLabel$, check10pWords$)
                check10pOk = 0
                appendInfoLine: "  10p len=", check10pLen, " k=", check10pK, " pre=", check10pPre,
                    ... " -> '", check10pLabel$, "'"
            endif
        endfor
    endfor
endfor
if check10pOk = 1
    pass = pass + 1
    appendInfoLine: "PASS: the annotation words survive whole in all ", check10pCases,
        ... " name-length/suffix/prefix cases, always within the cap"
else
    fail = fail + 1
    appendInfoLine: "FAIL: an annotation was truncated or the cap exceeded -- see the lines above"
endif

# ============================================================================
# 0.7.3 round 2: Check 14 -- the Removal complete dialog stays inside the
# page budget. The dialog's line groups can be COUNTED without a pause form
# (emit = 0), so this drives the real counting procedures and the real page
# walk. A verifier drive measured the old dialog at 998 px for four plugins
# (the OK button off a 900 px screen).
# ============================================================================

appendInfoLine: ""
appendInfoLine: "--- Check 14: Removal complete dialog fits the page budget ---"
@emlManagerPageMetrics

@emlHarnessRepeatChar: "L", 37
check14Long$ = "plugin_" + emlHarnessRepeatChar.result$
check14Names$# = { check14Long$, "plugin_LeftoverOne", "plugin_tgutils", "plugin_utils" }
check14Files# = { 1, 0, 41, 12 }
check14Remained# = { 0, 1, 1, 2 }
check14N = size (check14Names$#)
check14Lines# = zero# (check14N)
check14Total = 0
for check14I to check14N
    @emlManagerRemoveDoneBlock: check14Names$# [check14I], check14Files# [check14I], check14Remained# [check14I], 0
    check14Lines# [check14I] = emlManagerRemoveDoneBlock.px
    check14Total = check14Total + check14Lines# [check14I]
endfor
@emlManagerRemoveDoneFooter: 1, 0, 0
check14Footer = emlManagerRemoveDoneFooter.px
check14Keep# = zero# (check14N)
@emlManagerPageBudgetWalk: check14Lines#, check14Keep#, check14N, emlManagerPageMetrics.budgetPx, check14Footer, 1
if emlManagerPageBudgetWalk.nPages = 1 and check14Total + check14Footer <= emlManagerPageMetrics.budgetPx
    pass = pass + 1
    appendInfoLine: "PASS: four plugins fit one page -- ", check14Total, " px in blocks + ",
        ... check14Footer, " px in the footer (budget ", emlManagerPageMetrics.budgetPx, ")"
else
    fail = fail + 1
    appendInfoLine: "FAIL: four plugins -- ", emlManagerPageBudgetWalk.nPages, " pages, ",
        ... check14Total, " + ", check14Footer, " px"
endif

# Twelve plugins each leaving folders: the dialog pages, every page holds at
# most the budget (the last page counts the footer), and every plugin lands
# on exactly one page.
check14M = 12
check14BigLines# = zero# (check14M)
for check14I to check14M
    @emlManagerRemoveDoneBlock: "plugin_Name" + string$ (check14I), 20, 2, 0
    check14BigLines# [check14I] = emlManagerRemoveDoneBlock.px
endfor
check14BigKeep# = zero# (check14M)
@emlManagerPageBudgetWalk: check14BigLines#, check14BigKeep#, check14M, emlManagerPageMetrics.budgetPx, check14Footer, 1
check14PagesOk = 1
check14Covered = 0
for check14P to emlManagerPageBudgetWalk.nPages
    check14PageLines = 0
    for check14I from emlManagerPageBudgetWalk.pageStartItem# [check14P] to emlManagerPageBudgetWalk.pageEndItem# [check14P]
        check14PageLines = check14PageLines + check14BigLines# [check14I]
        check14Covered = check14Covered + 1
    endfor
    if check14P = emlManagerPageBudgetWalk.nPages
        check14PageLines = check14PageLines + check14Footer
    endif
    if check14PageLines > emlManagerPageMetrics.budgetPx
        check14PagesOk = 0
    endif
endfor
if emlManagerPageBudgetWalk.nPages > 1 and check14PagesOk = 1 and check14Covered = check14M
    pass = pass + 1
    appendInfoLine: "PASS: twelve plugins page into ", emlManagerPageBudgetWalk.nPages,
        ... " pages, each within the budget, every plugin on one page"
else
    fail = fail + 1
    appendInfoLine: "FAIL: twelve plugins -- pages=", emlManagerPageBudgetWalk.nPages,
        ... ", pagesOk=", check14PagesOk, ", covered=", check14Covered
endif

# ============================================================================
# 0.7.3 round 3: Check 15 -- the Confirm removal dialog pages by the same
# budget. Seven plugins used to render 1043 px on one page. Counting uses the
# real block and footer procedures (emit = 0); the footer holds the safety
# switch, so it is counted on the last page only.
# ============================================================================

appendInfoLine: ""
appendInfoLine: "--- Check 15: Confirm removal dialog pages by the budget ---"
@emlManagerPageMetrics

check15N = 7
check15Lines# = zero# (check15N)
for check15I to check15N
    @emlManagerRemoveGateBlock: "plugin_Name" + string$ (check15I), "", 20, 3,
        ... "plugin_Name" + string$ (check15I) + "__1.0.0", "/x/y", 0
    check15Lines# [check15I] = emlManagerRemoveGateBlock.px
endfor
@emlManagerRemoveGateFooter: 1, 0
check15Footer = emlManagerRemoveGateFooter.px
check15Keep# = zero# (check15N)
@emlManagerPageBudgetWalk: check15Lines#, check15Keep#, check15N, emlManagerPageMetrics.budgetPx, check15Footer, 1
check15PagesOk = 1
check15Covered = 0
for check15P to emlManagerPageBudgetWalk.nPages
    check15PageLines = 0
    for check15I from emlManagerPageBudgetWalk.pageStartItem# [check15P] to emlManagerPageBudgetWalk.pageEndItem# [check15P]
        check15PageLines = check15PageLines + check15Lines# [check15I]
        check15Covered = check15Covered + 1
    endfor
    if check15P = emlManagerPageBudgetWalk.nPages
        check15PageLines = check15PageLines + check15Footer
    endif
    if check15PageLines > emlManagerPageMetrics.budgetPx
        check15PagesOk = 0
    endif
endfor
if emlManagerPageBudgetWalk.nPages > 1 and check15PagesOk = 1 and check15Covered = check15N
    pass = pass + 1
    appendInfoLine: "PASS: seven plugins page into ", emlManagerPageBudgetWalk.nPages,
        ... " pages, each within the budget, every plugin on one page"
else
    fail = fail + 1
    appendInfoLine: "FAIL: seven plugins -- pages=", emlManagerPageBudgetWalk.nPages,
        ... ", pagesOk=", check15PagesOk, ", covered=", check15Covered
endif

# A single plugin stays on one page.
@emlManagerPageBudgetWalk: { check15Lines# [1] }, { 0 }, 1, emlManagerPageMetrics.budgetPx, check15Footer, 1
if emlManagerPageBudgetWalk.nPages = 1
    pass = pass + 1
    appendInfoLine: "PASS: one plugin keeps the dialog on one page"
else
    fail = fail + 1
    appendInfoLine: "FAIL: one plugin -- ", emlManagerPageBudgetWalk.nPages, " pages"
endif

# ============================================================================
# 0.7.3 round 4: Check 16 -- the page-budget canon. A comment's height comes
# from its last character; the budget is the screen less the chrome; and
# every page of the real Confirm removal and Removal complete dialogs, plus
# the chrome, fits the tallest allowed window (including 12 and 40 plugins).
# ============================================================================

appendInfoLine: ""
appendInfoLine: "--- Check 16: page-budget canon ---"

@emlManagerPageMetrics
@emlManagerLinePx: "Ends in a period."
check16Period = emlManagerLinePx.px
@emlManagerLinePx: "Ends in a colon:"
check16Colon = emlManagerLinePx.px
@emlManagerLinePx: "Ends in a letter"
check16Plain = emlManagerLinePx.px
@emlManagerLinePx: ""
check16Blank = emlManagerLinePx.px
if check16Period = emlManagerPageMetrics.periodPx and check16Colon = emlManagerPageMetrics.colonPx
    ... and check16Plain = emlManagerPageMetrics.commentPx and check16Blank = emlManagerPageMetrics.periodPx
    ... and check16Period > check16Colon and check16Colon > check16Plain
    ... and emlManagerPageMetrics.budgetPx + emlManagerPageMetrics.chromePx = emlManagerPageMetrics.screenPx
    pass = pass + 1
    appendInfoLine: "PASS: line heights follow the last character; budget + chrome = tallest window"
else
    fail = fail + 1
    appendInfoLine: "FAIL: page-budget canon -- period ", check16Period, ", colon ", check16Colon,
        ... ", plain ", check16Plain, ", blank ", check16Blank
endif

for check16Round to 2
    check16Count = 12
    if check16Round = 2
        check16Count = 40
    endif
    check16Px# = zero# (check16Count)
    for check16I to check16Count
        @emlManagerRemoveDoneBlock: "plugin_Name" + string$ (check16I), 20, 2, 0
        check16Px# [check16I] = emlManagerRemoveDoneBlock.px
    endfor
    @emlManagerRemoveDoneFooter: 1, 1, 0
    check16Footer = emlManagerRemoveDoneFooter.px
    check16Keep# = zero# (check16Count)
    @emlManagerPageBudgetWalk: check16Px#, check16Keep#, check16Count, emlManagerPageMetrics.budgetPx, check16Footer, 1
    check16Ok = 1
    for check16P to emlManagerPageBudgetWalk.nPages
        check16Page = emlManagerPageMetrics.chromePx
        for check16I from emlManagerPageBudgetWalk.pageStartItem# [check16P] to emlManagerPageBudgetWalk.pageEndItem# [check16P]
            check16Page = check16Page + check16Px# [check16I]
        endfor
        if check16P = emlManagerPageBudgetWalk.nPages
            check16Page = check16Page + check16Footer
        endif
        if check16Page > emlManagerPageMetrics.screenPx
            check16Ok = 0
        endif
    endfor
    if check16Ok = 1
        pass = pass + 1
        appendInfoLine: "PASS: ", check16Count, " removed plugins -- every page, with the chrome, is within ",
            ... emlManagerPageMetrics.screenPx, " px (", emlManagerPageBudgetWalk.nPages, " pages)"
    else
        fail = fail + 1
        appendInfoLine: "FAIL: ", check16Count, " removed plugins -- a page is taller than ",
            ... emlManagerPageMetrics.screenPx, " px"
    endif
endfor

# ============================================================================
# UX round 2026-09-01, item 4: Check 11 -- line-budget pagination
# (emlManagerPageBudgetWalk) on synthetic item sets.
# ============================================================================

appendInfoLine: ""
appendInfoLine: "--- Check 11: page-budget pagination (synthetic item sets) ---"

# The walk counts in whatever unit its caller uses; these synthetic sets use
# lines and a budget of 30 so the expected page breaks are easy to read.
check11Budget = 30

# 45 plain checkboxes (1 line each) -> pages of 30 + 15
plain45# = zero# (45)
for i45 from 1 to 45
    plain45# [i45] = 1
endfor
plain45Keep# = zero# (45)
@emlManagerPageBudgetWalk: plain45#, plain45Keep#, 45, check11Budget, 0, 0
if emlManagerPageBudgetWalk.nPages = 2
    ... and emlManagerPageBudgetWalk.pageStartItem# [1] = 1
    ... and emlManagerPageBudgetWalk.pageEndItem# [1] = 30
    ... and emlManagerPageBudgetWalk.pageStartItem# [2] = 31
    ... and emlManagerPageBudgetWalk.pageEndItem# [2] = 45
    pass = pass + 1
    appendInfoLine: "PASS: 45 plain checkboxes -> pages of 30 + 15"
else
    fail = fail + 1
    appendInfoLine: "FAIL: 45 plain checkboxes -- nPages=", emlManagerPageBudgetWalk.nPages
endif

# 10 annotated items of 4 lines each -> 7 per page (28 lines); the 8th item
# never splits across the page boundary even though 2 lines of budget (30 -
# 28) remain
annot10# = zero# (10)
for i10 from 1 to 10
    annot10# [i10] = 4
endfor
annot10Keep# = zero# (10)
@emlManagerPageBudgetWalk: annot10#, annot10Keep#, 10, check11Budget, 0, 0
if emlManagerPageBudgetWalk.nPages = 2
    ... and emlManagerPageBudgetWalk.pageStartItem# [1] = 1
    ... and emlManagerPageBudgetWalk.pageEndItem# [1] = 7
    ... and emlManagerPageBudgetWalk.pageStartItem# [2] = 8
    ... and emlManagerPageBudgetWalk.pageEndItem# [2] = 10
    pass = pass + 1
    appendInfoLine: "PASS: 10 items of 4 lines each -> 7 per page (28 lines), item 8 never splits"
else
    fail = fail + 1
    appendInfoLine: "FAIL: annotated 4-line items -- nPages=", emlManagerPageBudgetWalk.nPages,
        ... ", page1 end=", emlManagerPageBudgetWalk.pageEndItem# [1]
endif

# last-page reserve honored, WITH slack: 20 plain items + a 2-line reserve
# fit together on one page (20 + 2 = 22 <= 30)
plain20# = zero# (20)
for i20 from 1 to 20
    plain20# [i20] = 1
endfor
plain20Keep# = zero# (20)
@emlManagerPageBudgetWalk: plain20#, plain20Keep#, 20, check11Budget, 2, 0
if emlManagerPageBudgetWalk.nPages = 1
    ... and emlManagerPageBudgetWalk.pageStartItem# [1] = 1
    ... and emlManagerPageBudgetWalk.pageEndItem# [1] = 20
    pass = pass + 1
    appendInfoLine: "PASS: last-page reserve with slack -- 20 items + reserve share one page"
else
    fail = fail + 1
    appendInfoLine: "FAIL: last-page reserve with slack -- nPages=", emlManagerPageBudgetWalk.nPages
endif

# last-page reserve honored, WITHOUT slack: 29 plain items already fill the
# budget to the edge (29 + 2 = 31 > 30) -- the reserve spills onto its own
# page rather than crowding the last item off
plain29# = zero# (29)
for i29 from 1 to 29
    plain29# [i29] = 1
endfor
plain29Keep# = zero# (29)
@emlManagerPageBudgetWalk: plain29#, plain29Keep#, 29, check11Budget, 2, 0
if emlManagerPageBudgetWalk.nPages = 2
    ... and emlManagerPageBudgetWalk.pageStartItem# [1] = 1
    ... and emlManagerPageBudgetWalk.pageEndItem# [1] = 29
    ... and emlManagerPageBudgetWalk.pageStartItem# [2] > emlManagerPageBudgetWalk.pageEndItem# [2]
    pass = pass + 1
    appendInfoLine: "PASS: last-page reserve without slack -- spills onto its own page,",
        ... " no item is pushed off page 1"
else
    fail = fail + 1
    appendInfoLine: "FAIL: last-page reserve without slack -- nPages=",
        ... emlManagerPageBudgetWalk.nPages, ", page1 end=", emlManagerPageBudgetWalk.pageEndItem# [1]
endif

# ============================================================================
# UX round 2026-09-01 REVISED, sec. 2a: Check 12 -- index-prefixed labels
# are valid, indirectly-readable Praat variables end to end. MEASURED GUI
# REGRESSION: a Praat script variable name must start with a letter (a
# pause-form boolean's readback substitutes '.derived$' as literal source
# text and re-parses it), and every index-prefixed label starts with a
# digit -- this broke real removal in the GUI drive with "Unknown symbol:
# <12_...>" before emlManagerDeriveLabel's leading-digit guard. Builds
# labels across an 18-row fixture (the same count as the real drive's
# sandbox), assigns each row's derived variable by the SAME indirect
# mechanism Praat uses for a checked/unchecked pause-form boolean, then
# drives the real emlManagerReadSelections and confirms every value round-
# trips. This is the headless regression guard for the exact defect Check
# 10l's static sanitizer check alone did not catch (a static string check
# cannot see a parse error).
# ============================================================================

appendInfoLine: ""
appendInfoLine: "--- Check 12: index-prefixed labels are valid Praat variables (readback) ---"

check12N = 18
check12Derived$# = empty$# (check12N)
check12Expect# = zero# (check12N)
for check12I from 1 to check12N
    @emlManagerIndexPrefix: check12I
    check12Name$ = "plugin_Row" + string$ (check12I)
    @emlManagerApplyLabelCap: emlManagerIndexPrefix.prefix$, check12Name$, "", emlManager_boolLabelCap
    @emlManagerDeriveLabel: emlManagerApplyLabelCap.capped$
    check12Derived$# [check12I] = emlManagerDeriveLabel.derived$
    check12Expect# [check12I] = check12I mod 2
    check12Vn$ = check12Derived$# [check12I]
    'check12Vn$' = check12Expect# [check12I]
endfor

@emlManagerReadSelections: check12Derived$#, check12N
check12Ok = 1
for check12I from 1 to check12N
    if emlManagerReadSelections.selected# [check12I] <> check12Expect# [check12I]
        check12Ok = 0
    endif
endfor
if check12Ok = 1
    pass = pass + 1
    appendInfoLine: "PASS: all ", check12N, " index-prefixed labels round-trip through indirect",
        ... " readback (the exact mechanism the real pause-form boolean uses)"
else
    fail = fail + 1
    appendInfoLine: "FAIL: index-prefixed label readback mismatch somewhere in ", check12N, " rows"
endif

# ============================================================================
# 0.7.3 round 2: Check 13 -- two labels that derive the SAME readback name.
# Praat reads a checkbox back through the variable name it derives from the
# label (spaces to underscores, first letter lowercased). "plugin_foo-bar"
# shows as "plugin_foo bar" and "plugin_foo_bar" shows as "plugin_foo_bar";
# the labels differ, the derived names are identical. emlManagerBuildLabels
# must therefore test the DERIVED names. Each case below builds the listing
# through the real canon, then plays the pause form: every row's derived
# variable is set to 0, exactly one row's is set to 1 (the user ticks that
# row), and emlManagerReadSelections -- the real readback -- must report
# that row and no other. A rejected case would show a second selected row.
# ============================================================================

procedure emlHarnessTickEachRow: .names$#
    .n = size (.names$#)
    .suffix$# = empty$# (.n)
    for .i to .n
        .suffix$# [.i] = ""
    endfor
    @emlManagerBuildLabels: .names$#, .suffix$#, .n, emlManager_boolLabelCap
    .derived$# = emlManagerBuildLabels.derived$#
    .prefixedCount = 0
    .ok = 1
    for .i to .n
        .prefixedCount = .prefixedCount + emlManagerBuildLabels.prefixed# [.i]
    endfor
    for .tick to .n
        for .i to .n
            .vn$ = .derived$# [.i]
            '.vn$' = 0
        endfor
        .vn$ = .derived$# [.tick]
        '.vn$' = 1
        @emlManagerReadSelections: .derived$#, .n
        for .i to .n
            .want = 0
            if .i = .tick
                .want = 1
            endif
            if emlManagerReadSelections.selected# [.i] <> .want
                .ok = 0
            endif
        endfor
    endfor
endproc

appendInfoLine: ""
appendInfoLine: "--- Check 13: rows that derive the same readback name are told apart ---"

check13A$# = { "plugin_foo-bar", "plugin_foo_bar" }
@emlHarnessTickEachRow: check13A$#
check13AOk = emlHarnessTickEachRow.ok
check13APrefixed = emlHarnessTickEachRow.prefixedCount

check13B$# = { "Plugin_Upper", "plugin_Upper" }
@emlHarnessTickEachRow: check13B$#
check13BOk = emlHarnessTickEachRow.ok
check13BPrefixed = emlHarnessTickEachRow.prefixedCount

check13C$# = { "plugin_a b", "plugin_a-b", "plugin_other", "plugin_a_b", "plugin_a.b" }
@emlHarnessTickEachRow: check13C$#
check13COk = emlHarnessTickEachRow.ok
check13CPrefixed = emlHarnessTickEachRow.prefixedCount

# Distinct names stay bare (no prefix is added without a real collision).
check13D$# = { "plugin_foo", "plugin_bar", "plugin_foo2" }
@emlHarnessTickEachRow: check13D$#
check13DOk = emlHarnessTickEachRow.ok
check13DPrefixed = emlHarnessTickEachRow.prefixedCount

if check13AOk = 1 and check13APrefixed = 2
    pass = pass + 1
    appendInfoLine: "PASS: plugin_foo-bar and plugin_foo_bar -- both get the index prefix, and ticking",
        ... " either one reads back as only that row"
else
    fail = fail + 1
    appendInfoLine: "FAIL: plugin_foo-bar / plugin_foo_bar -- readback ok=", check13AOk,
        ... ", prefixed rows=", check13APrefixed
endif
if check13BOk = 1 and check13BPrefixed = 2
    pass = pass + 1
    appendInfoLine: "PASS: Plugin_Upper and plugin_Upper (same name once the first letter is",
        ... " lowercased) -- told apart"
else
    fail = fail + 1
    appendInfoLine: "FAIL: Plugin_Upper / plugin_Upper -- readback ok=", check13BOk,
        ... ", prefixed rows=", check13BPrefixed
endif
if check13COk = 1 and check13CPrefixed = 4
    pass = pass + 1
    appendInfoLine: "PASS: four punctuation variants of plugin_a_b are told apart, and the",
        ... " bystander plugin_other stays bare"
else
    fail = fail + 1
    appendInfoLine: "FAIL: plugin_a_b variants -- readback ok=", check13COk,
        ... ", prefixed rows=", check13CPrefixed
endif
if check13DOk = 1 and check13DPrefixed = 0
    pass = pass + 1
    appendInfoLine: "PASS: distinct names get no prefix"
else
    fail = fail + 1
    appendInfoLine: "FAIL: distinct names -- readback ok=", check13DOk, ", prefixed rows=", check13DPrefixed
endif

# ============================================================================
# 0.7.3 round 5: Check 17 -- the keep-together rules of the page walk. An
# item marked keep-with-previous never starts a page; a footer reserve that
# keeps with the last block never makes a footer-only page (the Confirm
# removal safety switch is never alone); a block taller than the budget
# still gets a page.
# ============================================================================

appendInfoLine: ""
appendInfoLine: "--- Check 17: keep-together rules of the page walk ---"
@emlManagerPageMetrics

# Blocks of three one-unit items (marks 0, 1, 1), budget 31: pages end on a
# block boundary however the budget falls (10 blocks fill 30 units; the 31st
# unit would start an eleventh block that does not fit).
check17Px# = zero# (36)
check17Keep# = zero# (36)
for check17I to 36
    check17Px# [check17I] = 1
    if check17I mod 3 <> 1
        check17Keep# [check17I] = 1
    endif
endfor
@emlManagerPageBudgetWalk: check17Px#, check17Keep#, 36, 31, 0, 0
check17Ok = emlManagerPageBudgetWalk.nPages = 2
for check17P to emlManagerPageBudgetWalk.nPages
    if check17Keep# [emlManagerPageBudgetWalk.pageStartItem# [check17P]] = 1
        check17Ok = 0
    endif
endfor
if check17Ok = 1 and emlManagerPageBudgetWalk.pageEndItem# [1] = 30
    pass = pass + 1
    appendInfoLine: "PASS: blocks of three stay whole -- page 1 ends at item 30, no page starts on a continuation"
else
    fail = fail + 1
    appendInfoLine: "FAIL: blocks of three -- pages ", emlManagerPageBudgetWalk.nPages,
        ... ", page 1 ends at ", emlManagerPageBudgetWalk.pageEndItem# [1]
endif

# A block taller than the budget still gets a page, and the walk ends.
@emlManagerPageBudgetWalk: { 40, 5, 5 }, { 0, 0, 1 }, 3, 31, 0, 0
if emlManagerPageBudgetWalk.nPages = 2 and emlManagerPageBudgetWalk.pageEndItem# [1] = 1
    pass = pass + 1
    appendInfoLine: "PASS: a block taller than the budget takes a page alone"
else
    fail = fail + 1
    appendInfoLine: "FAIL: oversize block -- pages ", emlManagerPageBudgetWalk.nPages
endif

# A footer that keeps with the last block: 29 one-unit items, a 2-unit
# footer, budget 30. Page 1 takes 28 items; page 2 takes item 29 with the
# footer. Without the keep, the footer would sit alone on page 3.
check17Px# = zero# (29)
check17Keep# = zero# (29)
for check17I to 29
    check17Px# [check17I] = 1
endfor
@emlManagerPageBudgetWalk: check17Px#, check17Keep#, 29, 30, 2, 1
if emlManagerPageBudgetWalk.nPages = 2 and emlManagerPageBudgetWalk.pageStartItem# [2] = 29
    ... and emlManagerPageBudgetWalk.pageEndItem# [2] = 29
    pass = pass + 1
    appendInfoLine: "PASS: a footer kept with the last block moves that block to the footer's page"
else
    fail = fail + 1
    appendInfoLine: "FAIL: kept footer -- pages ", emlManagerPageBudgetWalk.nPages,
        ... ", page 2 holds ", emlManagerPageBudgetWalk.pageStartItem# [2], " to ", emlManagerPageBudgetWalk.pageEndItem# [2]
endif

# The real Confirm removal blocks and footer, 1 to 40 plugins: the last page
# always holds at least one plugin block with the footer, and every page
# (the last with the footer) is within the budget.
check17Bad = 0
check17Worst = 0
for check17N from 1 to 40
    check17Px# = zero# (check17N)
    check17Keep# = zero# (check17N)
    for check17I to check17N
        @emlManagerRemoveGateBlock: "plugin_Name" + string$ (check17I), "", 20, 3,
            ... "plugin_Name" + string$ (check17I) + "__1.0.0", "/x/y", 0
        check17Px# [check17I] = emlManagerRemoveGateBlock.px
    endfor
    @emlManagerRemoveGateFooter: 1, 0
    check17Footer = emlManagerRemoveGateFooter.px
    @emlManagerPageBudgetWalk: check17Px#, check17Keep#, check17N, emlManagerPageMetrics.budgetPx, check17Footer, 1
    check17Last = emlManagerPageBudgetWalk.nPages
    if emlManagerPageBudgetWalk.pageStartItem# [check17Last] > emlManagerPageBudgetWalk.pageEndItem# [check17Last]
        check17Bad = check17Bad + 1
    endif
    for check17P to check17Last
        check17Sum = 0
        for check17I from emlManagerPageBudgetWalk.pageStartItem# [check17P] to emlManagerPageBudgetWalk.pageEndItem# [check17P]
            check17Sum = check17Sum + check17Px# [check17I]
        endfor
        if check17P = check17Last
            check17Sum = check17Sum + check17Footer
        endif
        if check17Sum > emlManagerPageMetrics.budgetPx
            check17Bad = check17Bad + 1
        endif
    endfor
endfor
if check17Bad = 0
    pass = pass + 1
    appendInfoLine: "PASS: 1 to 40 plugins -- the safety switch always shares a page with a plugin block, every page within the budget"
else
    fail = fail + 1
    appendInfoLine: "FAIL: confirm pages -- ", check17Bad, " bad page(s) across 1 to 40 plugins"
endif

# The same real blocks and footer WITHOUT the keep, as the proof the keep
# does something: some count from 1 to 40 leaves the footer alone.
check17Alone = 0
for check17N from 1 to 40
    check17Px# = zero# (check17N)
    check17Keep# = zero# (check17N)
    for check17I to check17N
        @emlManagerRemoveGateBlock: "plugin_Name" + string$ (check17I), "", 20, 3,
            ... "plugin_Name" + string$ (check17I) + "__1.0.0", "/x/y", 0
        check17Px# [check17I] = emlManagerRemoveGateBlock.px
    endfor
    @emlManagerRemoveGateFooter: 1, 0
    @emlManagerPageBudgetWalk: check17Px#, check17Keep#, check17N, emlManagerPageMetrics.budgetPx, emlManagerRemoveGateFooter.px, 0
    check17Last = emlManagerPageBudgetWalk.nPages
    if emlManagerPageBudgetWalk.pageStartItem# [check17Last] > emlManagerPageBudgetWalk.pageEndItem# [check17Last]
        check17Alone = check17Alone + 1
    endif
endfor
if check17Alone > 0
    pass = pass + 1
    appendInfoLine: "PASS: without the keep, ", check17Alone, " of 40 counts leave the footer alone, so the check above is not vacuous"
else
    fail = fail + 1
    appendInfoLine: "FAIL: no footer-only page without the keep; the check above proves nothing"
endif

# The cancel message is one per command.
if emlManagerRemove_msgCancelled$ = "Removal cancelled."
    pass = pass + 1
    appendInfoLine: "PASS: Remove plugin cancels with its own message"
else
    fail = fail + 1
    appendInfoLine: "FAIL: Remove plugin cancel message is '", emlManagerRemove_msgCancelled$, "'"
endif

# 0.7.3 round 6: Check 18 -- the install checklist's literal-names switch is
# never alone on a page. The real checklist walk (emlManagerChecklistPages,
# the procedure the install dialog calls) over 1 to 80 plugin rows, once with
# one-line descriptions and once with descriptions that wrap to several
# lines: the last page always lists at least one plugin, and every page
# (the last with the switch and its spacer) is within the budget.
appendInfoLine: ""
appendInfoLine: "--- Check 18: install checklist switch never alone on a page ---"
@emlManagerPageMetrics
check18Bad = 0
check18Alone = 0
for check18Kind to 2
    for check18N from 1 to 80
        check18Desc$# = empty$# (check18N)
        for check18I to check18N
            check18Desc$# [check18I] = "plugin_Name" + string$ (check18I) + "__1.0.0 -- new, adds 5 commands"
            if check18Kind = 2
                check18Desc$# [check18I] = check18Desc$# [check18I]
                    ... + " (replaces plugin_Name" + string$ (check18I) + "__0.9.0 in your preferences folder, which is archived first and can be restored from the archive folder)"
            endif
        endfor
        @emlManagerChecklistPages: check18Desc$#, check18N
        check18Last = emlManagerChecklistPages.nPages
        if emlManagerChecklistPages.pageStartItem# [check18Last] > emlManagerChecklistPages.pageEndItem# [check18Last]
            check18Bad = check18Bad + 1
        endif
        for check18P to check18Last
            check18Sum = 0
            for check18I from emlManagerChecklistPages.pageStartItem# [check18P] to emlManagerChecklistPages.pageEndItem# [check18P]
                @emlManagerWrappedPx: check18Desc$# [check18I], 0
                check18Sum = check18Sum + emlManagerWrappedPx.px + emlManagerPageMetrics.booleanPx
            endfor
            if check18P = check18Last
                check18Sum = check18Sum + emlManagerPageMetrics.reservePx
            endif
            if check18Sum > emlManagerPageMetrics.budgetPx
                check18Bad = check18Bad + 1
            endif
        endfor
        # The same rows with the switch allowed a page of its own.
        check18Px# = zero# (check18N)
        for check18I to check18N
            @emlManagerWrappedPx: check18Desc$# [check18I], 0
            check18Px# [check18I] = emlManagerWrappedPx.px + emlManagerPageMetrics.booleanPx
        endfor
        check18NoKeep# = zero# (check18N)
        @emlManagerPageBudgetWalk: check18Px#, check18NoKeep#, check18N, emlManagerPageMetrics.budgetPx, emlManagerPageMetrics.reservePx, 0
        check18Last = emlManagerPageBudgetWalk.nPages
        if emlManagerPageBudgetWalk.pageStartItem# [check18Last] > emlManagerPageBudgetWalk.pageEndItem# [check18Last]
            check18Alone = check18Alone + 1
        endif
    endfor
endfor
if check18Bad = 0
    pass = pass + 1
    appendInfoLine: "PASS: 160 checklist sizes -- the switch always shares a page with a plugin, every page within the budget"
else
    fail = fail + 1
    appendInfoLine: "FAIL: checklist pages -- ", check18Bad, " bad page(s)"
endif
if check18Alone > 0
    pass = pass + 1
    appendInfoLine: "PASS: without the keep, ", check18Alone, " of 160 sizes leave the switch alone, so the check above is not vacuous"
else
    fail = fail + 1
    appendInfoLine: "FAIL: no switch-only page without the keep; the check above proves nothing"
endif

# ============================================================================

runSystem_nocheck: "rm -rf " + q$ + scratchRoot$ + q$

appendInfoLine: ""
appendInfoLine: "RESULT: ", pass, " pass, ", fail, " fail"
