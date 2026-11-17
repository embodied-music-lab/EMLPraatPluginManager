# ============================================================================
# EML Plugin Manager -- Remove Plugin
# ============================================================================
# Purpose: Removes one or more installed plugin_ folders from Praat's
#          preferences folder. Each selected plugin is first copied into the
#          archive folder (the same placement mechanism the installer uses),
#          the copy's file-and-folder inventory is checked against the
#          original, and only then are the original files and folders
#          deleted. Nothing is removed unless the user explicitly confirms.
# Date: 17 November 2026
# Version: 1.4
#
# 1.4 -- Version 0.7.3. The remove, Confirm removal and Removal complete
#       dialogs page by the measured on-screen height of their rows (a
#       comment that ends in a period is taller than one that does not), so
#       their buttons stay on a 900-pixel-tall screen. The Confirm removal dialog pages by the same
#       page budget as the selection dialog and names every
#       selected plugin; the safety switch and the Archive and remove button
#       appear on the last page only, and Quit appears on every page. The
#       Removal complete dialog pages the same way, so any number of
#       removed plugins fits on screen. It names every plugin with its file
#       count and, when folders remain, how many; a blank line separates
#       plugins; the archive paths and the usual cause of a remaining
#       folder are said once. The remaining-folder wording no longer claims
#       a remaining parent folder holds the hidden files itself. On the
#       Confirm removal and Removal complete dialogs, the last page always
#       holds at least one plugin together with the switch and Archive and
#       remove button (or the OK footer), never the footer alone. Quit now
#       says "Removal cancelled.".
#
# 1.3 -- Version 0.7.3. The Plugin Manager's own row shows its full folder
#       name followed by "itself", and a leftover folder shows "leftover",
#       each after a single space.
#
# 1.2 -- AMENDED selection-label subsystem (sec. 2a of the UX round spec,
#       Ian's 1 Sep amendment): Dialog 1's checkbox labels are bare by
#       default; emlManagerRemoveComputeSuffix now only computes each row's
#       annotation suffix (manager / ghost), and the whole listing's labels
#       are built in one pass through the shared emlManagerBuildLabels canon
#       (install-from-disk.praat), which prefixes only the rows whose bare
#       labels collide. Dialog 2's full-name lines carry the matching
#       "n<index>." breadcrumb only for a row that was actually prefixed.
#
# 1.1 -- REVISED selection-label subsystem (sec. 2 of the UX round spec):
#       emlManagerRemoveBuildLabel took each row's Dialog-1 listing index and
#       prefixed the checkbox label with it (identity, sec. 2a) unconditionally;
#       Dialog 2's full-name lines carried the same index so a shortened
#       checkbox could always be resolved against its full folder name.
#
# ATTRIBUTION
# Framework: EML PraatGen by Ian Howell
#            Embodied Music Lab -- www.embodiedmusiclab.com
#            https://github.com/embodied-music-lab/PraatGen
# Code generation: Claude (Anthropic)
# ============================================================================

# Reuses install-from-disk.praat's procedures as a library; the flag below
# suppresses that file's own main sequence (see its final guard). RE-MEASURED
# 2026-09-01 on this repo's own 6.6.30 barren build (two-level nested-include
# probe, /tmp/eml_pm_include_test): Praat resolves an "include" -- nested
# ones too -- relative to the OUTERMOST running script's own folder, NOT the
# file that names the include. (A bare "install-from-disk.praat" would
# resolve against the outermost script's folder and fail when the harness,
# which lives in harness/, is the outermost script.) The
# path is therefore written relative to the plugin folder rather than as a
# bare filename: this resolves correctly both when this file is itself the
# outermost script (real use: the round trip through the parent and back
# into plugin_EMLPraatPluginManager lands on the same file) and when a
# harness script includes this file from a different folder, because in
# both cases the outermost script's folder plus "../plugin_EMLPraatPluginManager"
# names this same folder.
emlManager_harnessMode = 1
include ../plugin_EMLPraatPluginManager/install-from-disk.praat

# ============================================================================
# Constants
# ============================================================================

emlManagerRemove_title1$ = "Remove a plugin"
emlManagerRemove_title2$ = "Confirm removal"
emlManagerRemove_titleNotice$ = "Nothing removed"
emlManagerRemove_titleComplete$ = "Removal complete"

emlManagerRemove_btnQuit$ = "Quit"
emlManagerRemove_msgCancelled$ = "Removal cancelled."
emlManagerRemove_btnContinue$ = "Continue"
emlManagerRemove_btnNext$ = "Next"
emlManagerRemove_btnArchiveRemove$ = "Archive and remove"
emlManagerRemove_btnOK$ = "OK"

emlManagerRemove_gateLabel$ = "Archive and remove the plugins listed above"
emlManagerRemove_msgGateOff$ = "Nothing was removed. To proceed, switch on '"
    ... + emlManagerRemove_gateLabel$ + "' and press the button again."

# The annotation words follow the folder name after a single space. They carry
# no punctuation: Praat's label sanitizer turns every non-alphanumeric
# character into a space, so " (itself)" displayed as two spaces plus the word.
emlManagerRemove_managerSuffix$ = " itself"

# UX round 2026-09-01, item 1: the Dialog-1 label suffix for a plugin_*
# folder that exists but is not installed (emlManagerIsInstalled = 0) -- a
# ghost left behind by an earlier removal.
emlManagerRemove_ghostSuffix$ = " leftover"

emlManagerRemove_msgAlways1$ = "The plugin is first copied to the archive with the same mechanism installs use."
emlManagerRemove_msgAlways2$ = "The copy's complete file inventory is verified against the original before anything is deleted."
emlManagerRemove_msgAlways3$ = "Settings a plugin keeps outside its own folder are not touched."

emlManagerRemove_msgMgr1$ = "You are removing the Plugin Manager itself."
emlManagerRemove_msgMgr2$ = "Its menu commands disappear after the next restart."
emlManagerRemove_msgMgr3$ = "The archive keeps a complete copy."
emlManagerRemove_msgMgr4$ = "To reinstall, run the install file from the repository or from wherever you downloaded it."

emlManagerRemove_noVersionTag$ = "no-version"
emlManagerRemove_archiveSep$ = "__"

emlManagerRemove_wordFileSingular$ = "file"
emlManagerRemove_wordFilePlural$ = "files"
emlManagerRemove_wordFolderSingular$ = "folder"
emlManagerRemove_wordFolderPlural$ = "folders"

emlManagerRemove_msgWillArchiveTo$ = "Will be archived to "
emlManagerRemove_msgRemovedSuffix$ = " is removed."
# SPEC_WRAPPER_SAFETY part 3 sweep: the confirmation dialog names the archive
# destination FOLDER only; the full path goes through emlManagerLogPath
# (install-from-disk.praat) into the Info window instead. The completion
# dialog does not repeat the destination per plugin (0.7.3 round 2): it says
# once that each archive path is in the Info window.
emlManagerRemove_logEventWillArchive$ = "Will archive to"
emlManagerRemove_logEventArchived$ = "Archived to"
emlManagerRemove_msgFilesArchivedSuffix$ = " archived, originals removed"
emlManagerRemove_msgArchivesInInfo$ = "Each archive path is printed in the Info window."
# HIDDEN FILES (measured): fileNames$#/folderNames$# cannot enumerate
# dot-files, so a folder can remain non-empty after the delete walk purely
# because of a file Praat could never have seen -- the archive copy (made
# with cp -R) has it regardless. The count of remaining folders includes
# every parent of such a folder, and a folder can also survive for another
# reason (permissions), so the wording claims only the usual cause and says
# the hidden files are inside, never that the folder itself holds them.
emlManagerRemove_msgRemainSingular$ = " folder remains."
emlManagerRemove_msgRemainPlural$ = " folders remain."
emlManagerRemove_msgRemainWhy$ = "A folder usually remains when hidden files inside it (for example .gitignore or .DS_Store) are ones Praat cannot see or delete."
emlManagerRemove_msgRemainTail$ = "A plugin with a remaining folder is no longer active. Its archive copy includes the hidden files."

emlManagerRemove_msgRestartNormal$ = "Restart Praat. The removed commands disappear from the menus."
emlManagerRemove_msgRestartManager$ = "Restart Praat. The Plugin Manager's commands will be gone."

emlManagerRemove_msgCopyFailPrefix$ = "Copying "
emlManagerRemove_msgCopyFailSuffix$ = " to the archive failed. Nothing was removed."
emlManagerRemove_msgVerifyDiffMid$ = ": differs at "
emlManagerRemove_msgVerifyDiffSuffix$ = ". Nothing was removed. The partial archive copy may be deleted by hand."

emlManagerRemove_pagePrefix$ = " (page "
emlManagerRemove_pageMid$ = " of "
emlManagerRemove_pageSuffix$ = ")"

emlManagerRemove_countsSep$ = ", "

# ============================================================================
# Work procedures
# ============================================================================

# ----------------------------------------------------------------------------
# Chooses .singular$ or .plural$ for .n, following ordinary English usage
# (only exactly 1 takes the singular form; 0 and every plural count take
# the plural form).
procedure emlManagerRemovePluralWord: .n, .singular$, .plural$
    if .n = 1
        .word$ = .singular$
    else
        .word$ = .plural$
    endif
endproc

# ----------------------------------------------------------------------------
# Emits .text$ inside the pause form currently being built, one comment
# field per wrapped line (pause-window comment fields do not wrap on their
# own). Reuses the installer's own word-wrapping procedure. Called only
# between a beginPause and its endPause.
procedure emlManagerRemoveEmitWrapped: .text$
    @emlManagerWrapText: .text$, emlManager_wrapWidth
    for .wi from 1 to size (emlManagerWrapText.lines$#)
        comment: emlManagerWrapText.lines$# [.wi]
    endfor
endproc

# ----------------------------------------------------------------------------
# The Removal complete dialog is built from "lines" that are either counted
# (.emit = 0, used to page the dialog) or emitted into the pause form being
# built (.emit = 1). One procedure writes each line group, so the height the
# page walk uses is exactly what the dialog then shows. .px is the rendered
# height in pixels (see emlManagerPageMetrics in install-from-disk.praat).
procedure emlManagerRemoveDoneLine: .text$, .emit
    @emlManagerWrappedPx: .text$, .emit
    .px = emlManagerWrappedPx.px
endproc

# One removed plugin's block: ONE paragraph holding its name, its file
# count, and (only when above 0) the count of folders that remain, then a
# blank line that separates it from the next block. One paragraph keeps the
# rendered height small: the pause form puts extra space after every comment
# that ends a sentence, so a sentence per comment made each block about twice
# as tall. The archive destination and the cause of a remaining folder are
# said once, in the footer below, and the full archive path is in the Info
# window.
procedure emlManagerRemoveDoneBlock: .name$, .fileCount, .remained, .emit
    @emlManagerRemovePluralWord: .fileCount,
        ... emlManagerRemove_wordFileSingular$, emlManagerRemove_wordFilePlural$
    .text$ = .name$ + emlManagerRemove_msgRemovedSuffix$ + " " + string$ (.fileCount)
        ... + " " + emlManagerRemovePluralWord.word$ + emlManagerRemove_msgFilesArchivedSuffix$ + "."
    if .remained > 0
        @emlManagerRemovePluralWord: .remained,
            ... emlManagerRemove_msgRemainSingular$, emlManagerRemove_msgRemainPlural$
        .text$ = .text$ + " " + string$ (.remained) + emlManagerRemovePluralWord.word$
    endif
    @emlManagerRemoveDoneLine: .text$, .emit
    .px = emlManagerRemoveDoneLine.px
    @emlManagerRemoveDoneLine: "", .emit
    .px = .px + emlManagerRemoveDoneLine.px
endproc

# The text that closes the last page: one paragraph with the Info-window
# pointer and, when any plugin left a folder behind, the hidden-files
# explanation; then a blank line and the restart line.
procedure emlManagerRemoveDoneFooter: .anyRemained, .anyManager, .emit
    .text$ = emlManagerRemove_msgArchivesInInfo$
    if .anyRemained = 1
        .text$ = .text$ + " " + emlManagerRemove_msgRemainWhy$ + " " + emlManagerRemove_msgRemainTail$
    endif
    @emlManagerRemoveDoneLine: .text$, .emit
    .px = emlManagerRemoveDoneLine.px
    @emlManagerRemoveDoneLine: "", .emit
    .px = .px + emlManagerRemoveDoneLine.px
    if .anyManager = 1
        @emlManagerRemoveDoneLine: emlManagerRemove_msgRestartManager$, .emit
    else
        @emlManagerRemoveDoneLine: emlManagerRemove_msgRestartNormal$, .emit
    endif
    .px = .px + emlManagerRemoveDoneLine.px
endproc

# ----------------------------------------------------------------------------
# The Confirm removal dialog, built the same way as the Removal complete
# dialog: counted (.emit = 0, used to page it) or emitted (.emit = 1) by one
# procedure, so the page walk counts exactly what the dialog then shows.
# One selected plugin's block: its full folder name (with the "n<index>."
# breadcrumb only when a collision prefixed its Dialog-1 checkbox), its file
# and folder counts, and where it will be archived. The full archive path
# goes to the Info window, once per emitted block.
procedure emlManagerRemoveGateBlock: .name$, .descPrefix$, .fileCount, .folderCount, .destName$, .destPath$, .emit
    @emlManagerRemoveDoneLine: .descPrefix$ + .name$, .emit
    .px = emlManagerRemoveDoneLine.px
    @emlManagerRemovePluralWord: .fileCount,
        ... emlManagerRemove_wordFileSingular$, emlManagerRemove_wordFilePlural$
    .fileWord$ = emlManagerRemovePluralWord.word$
    @emlManagerRemovePluralWord: .folderCount,
        ... emlManagerRemove_wordFolderSingular$, emlManagerRemove_wordFolderPlural$
    @emlManagerRemoveDoneLine: string$ (.fileCount) + " " + .fileWord$
        ... + emlManagerRemove_countsSep$ + string$ (.folderCount) + " "
        ... + emlManagerRemovePluralWord.word$, .emit
    .px = .px + emlManagerRemoveDoneLine.px
    if .emit = 1
        @emlManagerLogPath: emlManagerRemove_logEventWillArchive$, .destPath$
    endif
    @emlManagerRemoveDoneLine: emlManagerRemove_msgWillArchiveTo$ + .destName$ + ". "
        ... + emlManager_msgSeePathInInfo$, .emit
    .px = .px + emlManagerRemoveDoneLine.px
endproc

# What closes the last page: a blank line, the three always-true sentences,
# the Plugin Manager's own warning when it is selected, and the safety
# switch (one boolean row). The switch exists only on the last page.
procedure emlManagerRemoveGateFooter: .anyManager, .emit
    @emlManagerRemoveDoneLine: "", .emit
    .px = emlManagerRemoveDoneLine.px
    @emlManagerRemoveDoneLine: emlManagerRemove_msgAlways1$, .emit
    .px = .px + emlManagerRemoveDoneLine.px
    @emlManagerRemoveDoneLine: emlManagerRemove_msgAlways2$, .emit
    .px = .px + emlManagerRemoveDoneLine.px
    @emlManagerRemoveDoneLine: emlManagerRemove_msgAlways3$, .emit
    .px = .px + emlManagerRemoveDoneLine.px
    if .anyManager = 1
        @emlManagerRemoveDoneLine: "", .emit
        .px = .px + emlManagerRemoveDoneLine.px
        @emlManagerRemoveDoneLine: emlManagerRemove_msgMgr1$, .emit
        .px = .px + emlManagerRemoveDoneLine.px
        @emlManagerRemoveDoneLine: emlManagerRemove_msgMgr2$, .emit
        .px = .px + emlManagerRemoveDoneLine.px
        @emlManagerRemoveDoneLine: emlManagerRemove_msgMgr3$, .emit
        .px = .px + emlManagerRemoveDoneLine.px
        @emlManagerRemoveDoneLine: emlManagerRemove_msgMgr4$, .emit
        .px = .px + emlManagerRemoveDoneLine.px
    endif
    if .emit = 1
        boolean: emlManagerRemove_gateLabel$, 0
    endif
    @emlManagerPageMetrics
    .px = .px + emlManagerPageMetrics.booleanPx
endproc

# ----------------------------------------------------------------------------
# The archive destination for the plugin at .sourcePath$: its folder name,
# an underscore-joined version tag (the plugin's VERSION first line, or
# "no-version" when absent), and -- when that name is already taken in
# .archiveDir$ -- an appended "__2", "__3", etc. until a free name is found.
procedure emlManagerRemoveArchiveDest: .sourcePath$, .archiveDir$
    @emlManagerBaseName: .sourcePath$
    .folderName$ = emlManagerBaseName.name$
    @emlManagerReadVersion: .sourcePath$
    .ver$ = emlManagerReadVersion.version$
    if .ver$ = ""
        .verTag$ = emlManagerRemove_noVersionTag$
    else
        .verTag$ = .ver$
    endif
    .baseName$ = .folderName$ + emlManagerRemove_archiveSep$ + .verTag$
    .destName$ = .baseName$
    .n = 2
    while folderExists (.archiveDir$ + "/" + .destName$)
        .destName$ = .baseName$ + emlManagerRemove_archiveSep$ + string$ (.n)
        .n = .n + 1
    endwhile
    .destPath$ = .archiveDir$ + "/" + .destName$
endproc

# ----------------------------------------------------------------------------
# The structural inventory of .root$: every file path and every folder path
# (relative to .root$), combined into one sorted list, plus the separate
# file and folder counts. Both lists come from the installer's own
# emlManagerListRelFiles -- the ONE shared recursive tree walk -- reused
# here rather than reimplemented (DRY: it already walks every subfolder to
# find files, so it collects the folder paths it passes through in the same
# pass; see its definition in install-from-disk.praat). .scratchFile$ is
# scratch space for the file walk (overwritten; need not survive).
procedure emlManagerRemoveInventory: .root$, .scratchFile$
    @emlManagerListRelFiles: .root$, .scratchFile$
    .files$# = emlManagerListRelFiles.files$#
    .folders$# = emlManagerListRelFiles.folders$#
    .fileCount = size (.files$#)
    .folderCount = size (.folders$#)
    .total = .fileCount + .folderCount
    if .total > 0
        .all$# = empty$# (.total)
        for .i from 1 to .fileCount
            .all$# [.i] = .files$# [.i]
        endfor
        for .j from 1 to .folderCount
            .all$# [.fileCount + .j] = .folders$# [.j]
        endfor
        .paths$# = sort$# (.all$#)
    else
        .paths$# = empty$# (0)
    endif
endproc

# ----------------------------------------------------------------------------
# Compares the structural inventories of .srcRoot$ and .archiveRoot$
# (already-sorted relative-path lists). .ok is 1 only when every path
# matches, in order; otherwise .firstDiff$ names the first path that is
# missing from one side or extra on the other -- a two-pointer walk of both
# sorted lists, so any missing path, extra path, or count difference is
# caught. .scratchDir$ is scratch space for the two inventories.
procedure emlManagerRemoveVerify: .srcRoot$, .archiveRoot$, .scratchDir$
    @emlManagerRemoveInventory: .srcRoot$, .scratchDir$ + "/eml_pm_remove_src.txt"
    .srcPaths$# = emlManagerRemoveInventory.paths$#
    .srcN = size (.srcPaths$#)
    @emlManagerRemoveInventory: .archiveRoot$, .scratchDir$ + "/eml_pm_remove_arc.txt"
    .arcPaths$# = emlManagerRemoveInventory.paths$#
    .arcN = size (.arcPaths$#)
    .ok = 1
    .firstDiff$ = ""
    .i = 1
    .j = 1
    while .ok = 1 and (.i <= .srcN or .j <= .arcN)
        if .i > .srcN
            .ok = 0
            .firstDiff$ = .arcPaths$# [.j]
        elsif .j > .arcN
            .ok = 0
            .firstDiff$ = .srcPaths$# [.i]
        elsif .srcPaths$# [.i] = .arcPaths$# [.j]
            .i = .i + 1
            .j = .j + 1
        else
            .ok = 0
            if .srcPaths$# [.i] < .arcPaths$# [.j]
                .firstDiff$ = .srcPaths$# [.i]
            else
                .firstDiff$ = .arcPaths$# [.j]
            endif
        endif
    endwhile
endproc

# ----------------------------------------------------------------------------
# Deletes every file under .root$, then every folder under .root$ and .root$
# itself, deepest first. Deleting a folder that is not empty neither errors
# nor removes it (measured Praat behavior); such a folder is simply left in
# place and counted in .remainedCount, which the caller reports as harmless.
# .scratchFile$ is scratch space for the file walk.
procedure emlManagerRemoveDeleteTree: .root$, .scratchFile$
    @emlManagerListRelFiles: .root$, .scratchFile$
    .relFiles$# = emlManagerListRelFiles.files$#
    for .fi from 1 to size (.relFiles$#)
        deleteFile: .root$ + "/" + .relFiles$# [.fi]
    endfor
    .relFolders$# = emlManagerListRelFiles.folders$#
    .nFolders = size (.relFolders$#)
    .fullFolders$# = empty$# (.nFolders + 1)
    for .fo from 1 to .nFolders
        .fullFolders$# [.fo] = .root$ + "/" + .relFolders$# [.fo]
    endfor
    .fullFolders$# [.nFolders + 1] = .root$
    .sortedFolders$# = sort$# (.fullFolders$#)
    .nSorted = size (.sortedFolders$#)
    .remainedCount = 0
    for .k from 1 to .nSorted
        .idx = .nSorted - .k + 1
        .p$ = .sortedFolders$# [.idx]
        deleteFile: .p$
        if folderExists (.p$)
            .remainedCount = .remainedCount + 1
        endif
    endfor
endproc

# ----------------------------------------------------------------------------
# Archives, verifies, and removes one plugin. .destName$/.destPath$ are
# already computed (by emlManagerRemoveArchiveDest, once, before the user
# confirms) so preview and execution always agree on where a plugin goes.
# The copy uses the installer's own emlManagerPlaceFolder. When the copy
# does not produce the expected folder, .copyOk is 0 and nothing else runs.
# Verification and deletion run only when the previous step succeeded, so
# deletion never runs unless the archive copy is confirmed complete.
procedure emlManagerRemoveExecutePlugin: .folderName$, .destName$, .destPath$,
    ... .prefsDir$, .archiveDir$, .scratchDir$
    .sourcePath$ = .prefsDir$ + "/" + .folderName$
    createFolder: .archiveDir$
    @emlManagerPlaceFolder: .sourcePath$, .destName$, .archiveDir$
    .copyOk = emlManagerPlaceFolder.ok
    .verifyOk = 0
    .firstDiff$ = ""
    .remainedCount = 0
    if .copyOk = 1
        @emlManagerRemoveVerify: .sourcePath$, .destPath$, .scratchDir$
        .verifyOk = emlManagerRemoveVerify.ok
        .firstDiff$ = emlManagerRemoveVerify.firstDiff$
        if .verifyOk = 1
            @emlManagerRemoveDeleteTree: .sourcePath$, .scratchDir$ + "/eml_pm_remove_delete.txt"
            .remainedCount = emlManagerRemoveDeleteTree.remainedCount
        endif
    endif
endproc

# ----------------------------------------------------------------------------
# Items 1+2: the Dialog-1 annotation suffix for one plugin_* folder --
# appends the manager suffix when .isOwnFolder = 1, and (via the
# installed-test canon) the ghost suffix when the folder exists but is not
# installed. Pure suffix computation, no capping and no index prefix: the
# main sequence's Dialog-1 build collects every row's (.folderName$,
# .suffix$) pair first and hands the whole listing to emlManagerBuildLabels
# (sec. 2a AMENDED) in one pass, since whether a prefix is needed at all can
# only be decided once every row's bare label is known.
procedure emlManagerRemoveComputeSuffix: .folderName$, .isOwnFolder, .prefsDir$
    .suffix$ = ""
    if .isOwnFolder = 1
        .suffix$ = .suffix$ + emlManagerRemove_managerSuffix$
    endif
    @emlManagerIsInstalled: .prefsDir$ + "/" + .folderName$
    .isGhost = 0
    if emlManagerIsInstalled.installed = 0
        .isGhost = 1
        .suffix$ = .suffix$ + emlManagerRemove_ghostSuffix$
    endif
endproc

# ----------------------------------------------------------------------------
# Runs emlManagerRemoveExecutePlugin over .names$# in order, stopping at the
# first plugin whose copy or verify step fails (so nothing after a failure
# is touched). Does nothing at all unless .confirmed is 1 -- the gate
# dialog is the only caller allowed to pass 1, and only after its own
# boolean reads back on. .ranCount is how many entries were attempted; the
# result vectors are valid for indices 1 to .ranCount.
procedure emlManagerRemoveRun: .names$#, .destName$#, .destPath$#,
    ... .prefsDir$, .archiveDir$, .scratchDir$, .confirmed
    .n = size (.names$#)
    .cap = max (.n, 1)
    .copyOk# = zero# (.cap)
    .verifyOk# = zero# (.cap)
    .firstDiff$# = empty$# (.cap)
    .remainedCount# = zero# (.cap)
    .ranCount = 0
    if .confirmed = 1
        .i = 1
        .keepGoing = 1
        while .keepGoing = 1 and .i <= .n
            @emlManagerRemoveExecutePlugin: .names$# [.i], .destName$# [.i], .destPath$# [.i],
                ... .prefsDir$, .archiveDir$, .scratchDir$
            .copyOk# [.i] = emlManagerRemoveExecutePlugin.copyOk
            .verifyOk# [.i] = emlManagerRemoveExecutePlugin.verifyOk
            .firstDiff$# [.i] = emlManagerRemoveExecutePlugin.firstDiff$
            .remainedCount# [.i] = emlManagerRemoveExecutePlugin.remainedCount
            .ranCount = .ranCount + 1
            if emlManagerRemoveExecutePlugin.copyOk = 0 or emlManagerRemoveExecutePlugin.verifyOk = 0
                .keepGoing = 0
            endif
            .i = .i + 1
        endwhile
    endif
endproc

# ============================================================================
# Main sequence
# ============================================================================
# Skipped when this file is included by the test harness (which sets
# emlManagerRemove_harnessMode = 1 before the include), so the harness can
# drive the work procedures above directly, with the selection and the
# confirmation passed in as explicit arguments, and no dialog shown.

if not variableExists ("emlManagerRemove_harnessMode")

    @emlManagerVersionOk
    if emlManagerVersionOk.ok = 0
        exitScript: emlManager_msgVersionFail$ + praatVersion$ + emlManager_msgVersionSuffix$
    endif

    prefsDir$ = preferencesDirectory$
    archiveDir$ = prefsDir$ + "/" + emlManager_archiveName$

    @emlManagerMakeStaging
    if emlManagerMakeStaging.ok = 0
        exitScript: emlManager_msgStagingFail$
    endif
    scratchDir$ = emlManagerMakeStaging.path$

    # The manager's own folder is the one this running script sits in.
    ownFolder$ = defaultDirectory$
    @emlManagerBaseName: ownFolder$
    ownFolderName$ = emlManagerBaseName.name$

    # --- Dialog 1: selection ---

    allNames$# = folderNames$# (prefsDir$ + "/" + emlManager_pluginPrefix$ + "*")
    allNames$# = sort$# (allNames$#)
    nAll = size (allNames$#)

    suffix$# = empty$# (max (nAll, 1))
    @emlManagerPageMetrics
    itemPx# = zero# (max (nAll, 1))
    for iName from 1 to nAll
        isOwnFolder = 0
        if allNames$# [iName] = ownFolderName$
            isOwnFolder = 1
        endif
        @emlManagerRemoveComputeSuffix: allNames$# [iName], isOwnFolder, prefsDir$
        suffix$# [iName] = emlManagerRemoveComputeSuffix.suffix$
        itemPx# [iName] = emlManagerPageMetrics.booleanPx
    endfor

    # Sec. 2a AMENDED: one canon pass over the whole listing builds every
    # checkbox label -- bare by default, prefixed only for a row whose bare,
    # capped, sanitized label collides with another's (emlManagerBuildLabels;
    # shared with the install dialog's checklist, "one canon" per sec. 2a).
    # rowPrefixed# is kept for Dialog 2 below, which needs to know -- per
    # SELECTED row -- whether its checkbox carried the index prefix, so its
    # full-name line can carry the matching breadcrumb only when one is
    # actually needed to resolve a shortened, prefixed checkbox.
    @emlManagerBuildLabels: allNames$#, suffix$#, nAll, emlManager_boolLabelCap
    boolLabels$# = emlManagerBuildLabels.label$#
    derivedNames$# = emlManagerBuildLabels.derived$#
    rowPrefixed# = emlManagerBuildLabels.prefixed#

    # Page-budget pagination -- each row here is a single boolean with no
    # description comment, so this is a plain checkbox list; the budget walk
    # pages it by the booleans' rendered height.
    noKeep# = zero# (nAll)
    @emlManagerPageBudgetWalk: itemPx#, noKeep#, nAll, emlManagerPageMetrics.budgetPx, 0, 0
    nPages = emlManagerPageBudgetWalk.nPages
    pageStartItem# = emlManagerPageBudgetWalk.pageStartItem#
    pageEndItem# = emlManagerPageBudgetWalk.pageEndItem#
    for iPage from 1 to nPages
        pageStart = pageStartItem# [iPage]
        pageEnd = pageEndItem# [iPage]
        if nPages = 1
            pageTitle$ = emlManagerRemove_title1$
        else
            pageTitle$ = emlManagerRemove_title1$ + emlManagerRemove_pagePrefix$
                ... + string$ (iPage) + emlManagerRemove_pageMid$ + string$ (nPages)
                ... + emlManagerRemove_pageSuffix$
        endif

        beginPause: pageTitle$
            for iShow from pageStart to pageEnd
                boolean: boolLabels$# [iShow], 0
            endfor

        if iPage < nPages
            clicked = endPause: emlManagerRemove_btnQuit$, emlManagerRemove_btnNext$, 2, 0
        else
            clicked = endPause: emlManagerRemove_btnQuit$, emlManagerRemove_btnContinue$, 2, 0
        endif

        if clicked = 1
            @emlManagerCleanupStaging: scratchDir$
            exitScript: emlManagerRemove_msgCancelled$
        endif
    endfor

    @emlManagerReadSelections: derivedNames$#, nAll
    selFlags# = emlManagerReadSelections.selected#

    nSel = 0
    for iCheck from 1 to nAll
        nSel = nSel + selFlags# [iCheck]
    endfor
    if nSel = 0
        @emlManagerCleanupStaging: scratchDir$
        exitScript: emlManager_msgNoneSelected$
    endif

    # Sec. 2a: selectedIndex# carries each selected plugin's Dialog-1 listing
    # position, so Dialog 2 can prefix its full-name line with the SAME
    # index the (possibly shortened) checkbox label used.
    selectedNames$# = empty$# (nSel)
    selectedIndex# = zero# (nSel)
    kSel = 0
    for iCheck from 1 to nAll
        if selFlags# [iCheck] = 1
            kSel = kSel + 1
            selectedNames$# [kSel] = allNames$# [iCheck]
            selectedIndex# [kSel] = iCheck
        endif
    endfor

    # --- Precompute archive destinations and counts, once, for both the
    #     confirmation dialog and the execution that follows it ---

    destName$# = empty$# (nSel)
    destPath$# = empty$# (nSel)
    fileCount# = zero# (nSel)
    folderCount# = zero# (nSel)
    anyManager = 0
    for iPre from 1 to nSel
        pluginPath$ = prefsDir$ + "/" + selectedNames$# [iPre]
        @emlManagerRemoveArchiveDest: pluginPath$, archiveDir$
        destName$# [iPre] = emlManagerRemoveArchiveDest.destName$
        destPath$# [iPre] = emlManagerRemoveArchiveDest.destPath$
        @emlManagerRemoveInventory: pluginPath$, scratchDir$ + "/eml_pm_remove_precount.txt"
        fileCount# [iPre] = emlManagerRemoveInventory.fileCount
        folderCount# [iPre] = emlManagerRemoveInventory.folderCount
        if selectedNames$# [iPre] = ownFolderName$
            anyManager = 1
        endif
    endfor

    # --- Dialog 2: the gate, looping until Quit or a confirmed removal.
    #     Paged by the same page budget as Dialog 1: every selected
    #     plugin is named, and the safety switch with the Archive and remove
    #     button sit on the last page only. Quit is on every page ---

    gateDescPrefix$# = empty$# (nSel)
    gateLines# = zero# (nSel)
    for iGate from 1 to nSel
        # Sec. 2a AMENDED: the full folder name carries the matching
        # "n<index>." breadcrumb only when Dialog 1's checkbox for this row
        # was itself prefixed (a collision forced it).
        # An element of empty$# that is never assigned is not a usable
        # string (Praat 7.0.03 crashes when it is passed on), so every
        # element is set.
        gateDescPrefix$# [iGate] = ""
        if rowPrefixed# [selectedIndex# [iGate]] = 1
            @emlManagerIndexDescPrefix: selectedIndex# [iGate]
            gateDescPrefix$# [iGate] = emlManagerIndexDescPrefix.prefix$
        endif
        @emlManagerRemoveGateBlock: selectedNames$# [iGate], gateDescPrefix$# [iGate],
            ... fileCount# [iGate], folderCount# [iGate], destName$# [iGate], destPath$# [iGate], 0
        gateLines# [iGate] = emlManagerRemoveGateBlock.px
    endfor
    @emlManagerRemoveGateFooter: anyManager, 0
    # The footer (safety switch and Archive and remove) is kept with the
    # last plugin block, so the last page never holds the switch alone.
    gateKeep# = zero# (nSel)
    @emlManagerPageBudgetWalk: gateLines#, gateKeep#, nSel, emlManagerPageMetrics.budgetPx,
        ... emlManagerRemoveGateFooter.px, 1
    nGatePages = emlManagerPageBudgetWalk.nPages
    gatePageStart# = emlManagerPageBudgetWalk.pageStartItem#
    gatePageEnd# = emlManagerPageBudgetWalk.pageEndItem#

    gateOn = 0
    while gateOn = 0
        for iGatePage from 1 to nGatePages
            if nGatePages = 1
                gatePageTitle$ = emlManagerRemove_title2$
            else
                gatePageTitle$ = emlManagerRemove_title2$ + emlManagerRemove_pagePrefix$
                    ... + string$ (iGatePage) + emlManagerRemove_pageMid$ + string$ (nGatePages)
                    ... + emlManagerRemove_pageSuffix$
            endif
            beginPause: gatePageTitle$
                for iShow2 from gatePageStart# [iGatePage] to gatePageEnd# [iGatePage]
                    @emlManagerRemoveGateBlock: selectedNames$# [iShow2], gateDescPrefix$# [iShow2],
                        ... fileCount# [iShow2], folderCount# [iShow2], destName$# [iShow2],
                        ... destPath$# [iShow2], 1
                endfor
                if iGatePage = nGatePages
                    @emlManagerRemoveGateFooter: anyManager, 1
                endif
            if iGatePage < nGatePages
                clicked2 = endPause: emlManagerRemove_btnQuit$, emlManagerRemove_btnNext$, 2, 0
            else
                clicked2 = endPause: emlManagerRemove_btnQuit$, emlManagerRemove_btnArchiveRemove$, 1, 0
            endif

            if clicked2 = 1
                @emlManagerCleanupStaging: scratchDir$
                exitScript: emlManagerRemove_msgCancelled$
            endif
        endfor

        @emlManagerDeriveLabel: emlManagerRemove_gateLabel$
        gateVarName$ = emlManagerDeriveLabel.derived$
        gateOn = 'gateVarName$'

        if gateOn = 0
            beginPause: emlManagerRemove_titleNotice$
                @emlManagerRemoveEmitWrapped: emlManagerRemove_msgGateOff$
            endPause: emlManagerRemove_btnOK$, 1, 0
        endif
    endwhile

    # --- Execution: only reached once the gate above has passed ---

    @emlManagerRemoveRun: selectedNames$#, destName$#, destPath$#,
        ... prefsDir$, archiveDir$, scratchDir$, 1
    ranCount = emlManagerRemoveRun.ranCount
    lastFailedName$ = selectedNames$# [ranCount]

    if emlManagerRemoveRun.copyOk# [ranCount] = 0
        @emlManagerCleanupStaging: scratchDir$
        exitScript: emlManagerRemove_msgCopyFailPrefix$ + lastFailedName$
            ... + emlManagerRemove_msgCopyFailSuffix$
    elsif emlManagerRemoveRun.verifyOk# [ranCount] = 0
        @emlManagerCleanupStaging: scratchDir$
        exitScript: emlManager_msgVerifyFail$ + lastFailedName$
            ... + emlManagerRemove_msgVerifyDiffMid$ + emlManagerRemoveRun.firstDiff$# [ranCount]
            ... + emlManagerRemove_msgVerifyDiffSuffix$
    endif

    # --- Completion dialog: reached only when every selected plugin succeeded.
    #     Paged by the same page budget as the selection dialog, so
    #     any number of removed plugins fits on screen, and every plugin is
    #     named ---

    anyRemained = 0
    doneLines# = zero# (nSel)
    for iDone from 1 to nSel
        @emlManagerLogPath: emlManagerRemove_logEventArchived$, destPath$# [iDone]
        remained = emlManagerRemoveRun.remainedCount# [iDone]
        if remained > 0
            anyRemained = 1
        endif
        @emlManagerRemoveDoneBlock: selectedNames$# [iDone], fileCount# [iDone], remained, 0
        doneLines# [iDone] = emlManagerRemoveDoneBlock.px
    endfor
    @emlManagerRemoveDoneFooter: anyRemained, anyManager, 0
    doneKeep# = zero# (nSel)
    @emlManagerPageBudgetWalk: doneLines#, doneKeep#, nSel, emlManagerPageMetrics.budgetPx,
        ... emlManagerRemoveDoneFooter.px, 1
    nDonePages = emlManagerPageBudgetWalk.nPages
    donePageStart# = emlManagerPageBudgetWalk.pageStartItem#
    donePageEnd# = emlManagerPageBudgetWalk.pageEndItem#
    for iDonePage from 1 to nDonePages
        if nDonePages = 1
            donePageTitle$ = emlManagerRemove_titleComplete$
        else
            donePageTitle$ = emlManagerRemove_titleComplete$ + emlManagerRemove_pagePrefix$
                ... + string$ (iDonePage) + emlManagerRemove_pageMid$ + string$ (nDonePages)
                ... + emlManagerRemove_pageSuffix$
        endif
        beginPause: donePageTitle$
            for iDone from donePageStart# [iDonePage] to donePageEnd# [iDonePage]
                @emlManagerRemoveDoneBlock: selectedNames$# [iDone], fileCount# [iDone],
                    ... emlManagerRemoveRun.remainedCount# [iDone], 1
            endfor
            if iDonePage = nDonePages
                @emlManagerRemoveDoneFooter: anyRemained, anyManager, 1
            endif
        if iDonePage < nDonePages
            endPause: emlManagerRemove_btnNext$, 1, 0
        else
            endPause: emlManagerRemove_btnOK$, 1, 0
        endif
    endfor

    @emlManagerCleanupStaging: scratchDir$

endif
