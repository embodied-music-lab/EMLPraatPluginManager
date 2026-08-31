# ============================================================================
# EML Plugin Manager -- Install Plugin from Disk
# ============================================================================
# Purpose: Installs an already-downloaded plugin into Praat's preferences
#          folder. Accepts a .zip, .tar.gz/.tgz, or an already-unpacked
#          folder. Finds all plugin_ folders at any depth, lets the user
#          select which to install, archives any existing same-named plugin,
#          and places the new one.
# Date: 31 August 2026
# Version: 3.0
#
# ATTRIBUTION
# Framework: EML PraatGen by Ian Howell
#            Embodied Music Lab -- www.embodiedmusiclab.com
#            https://github.com/embodied-music-lab/PraatGen
# Code generation: Claude (Anthropic)
# ============================================================================

# ============================================================================
# Constants
# ============================================================================

kPluginPrefix$ = "plugin_"
kMacosxExclude$ = "__MACOSX"
kSetupFile$ = "setup.praat"
kStagingName$ = "eml_pm_staging"
kArchiveName$ = "eml_pm_archive"
kResultsName$ = "found_plugins.txt"
kPageSize = 12

kFloorVersion = 6630
kFloorVersionLabel$ = "6.6.30"

kExtZip$ = ".zip"
kExtTarGz$ = ".tar.gz"
kExtTgz$ = ".tgz"

kTitle$ = "Install Plugin from Disk"
kSelTitle$ = "Select plugins to install"
kMsgCancelled$ = "Installation cancelled."
kMsgVersionFail$ = "This script requires Praat "
    ... + kFloorVersionLabel$
    ... + " or newer. You have "
kMsgVersionSuffix$ = ". Please update Praat from praat.org and try again."
kMsgNoPluginFound$ = "No plugin folder (a folder whose name starts with "
    ... + kPluginPrefix$ + ") was found inside "
kMsgBadExt$ = "Only .zip, .tar.gz, and .tgz files are accepted. Got: "
kMsgUnpackFail$ = "Unpacking failed. "
kMsgLinuxUnzipHint$ = "The unzip tool may not be installed on this system."
    ... + " The file that could not be unpacked: "
kMsgNoneSelected$ = "No plugins selected."
kMsgCollision$ = "Two found plugins produce the same internal name: "
kMsgCollisionSuffix$ = ". Install them one at a time via the folder option."
kMsgVerifyFail$ = "Verification failed for "
kMsgArchiveFail$ = "FAILED: could not archive existing "
kMsgRestart$ = "Restart Praat to activate."
kMsgArchiveNote$ = " (previous version kept in the archive folder)"
kMsgStagingFail$ = "Failed to create staging folder."

kAnnotNoCommands$ = "registers no commands"
kAnnotNoSetup$ = "no setup.praat -- not a functioning plugin as-is"
kAnnotInstalled$ = "already installed -- replacing keeps the current "
    ... + "version in the archive folder"

# ============================================================================
# Work procedures
# ============================================================================

procedure emlpmL_versionOk
    .ok = praatVersion >= kFloorVersion
endproc

# ----------------------------------------------------------------------------
procedure emlpmL_makeStaging
    .path$ = preferencesDirectory$ + "/" + kStagingName$
    if folderExists (.path$)
        @emlpmL_cleanupStaging: .path$
    endif
    createFolder: .path$
    .ok = folderExists (.path$)
endproc

# ----------------------------------------------------------------------------
procedure emlpmL_cleanupStaging: .path$
    if not folderExists (.path$)
        .ok = 1
    else
        .q$ = """"
        if macintosh or unix
            runSystem_nocheck: "rm -rf " + .q$ + .path$ + .q$
        elsif windows
            runSystem_nocheck: "rmdir /s /q " + .q$ + .path$ + .q$
        endif
        .ok = not folderExists (.path$)
    endif
endproc

# ----------------------------------------------------------------------------
procedure emlpmL_unpack: .format$, .source$, .dest$
    .ok = 0
    .message$ = ""
    .q$ = """"
    createFolder: .dest$
    if macintosh
        runSystem_nocheck: "tar -xf "
            ... + .q$ + .source$ + .q$
            ... + " -C " + .q$ + .dest$ + .q$
    elsif windows
        runSystem_nocheck: "tar -xf "
            ... + .q$ + .source$ + .q$
            ... + " -C " + .q$ + .dest$ + .q$
    elsif unix
        if .format$ = "zip"
            runSystem_nocheck: "unzip -q "
                ... + .q$ + .source$ + .q$
                ... + " -d " + .q$ + .dest$ + .q$
        else
            runSystem_nocheck: "tar -xzf "
                ... + .q$ + .source$ + .q$
                ... + " -C " + .q$ + .dest$ + .q$
        endif
    endif
    .subDirs$# = folderNames$# (.dest$ + "/*")
    .subFiles$# = fileNames$# (.dest$ + "/*")
    if size (.subDirs$#) > 0 or size (.subFiles$#) > 0
        .ok = 1
    else
        .message$ = kMsgUnpackFail$
        if unix and .format$ = "zip"
            .message$ = .message$ + kMsgLinuxUnzipHint$ + .source$
        endif
    endif
endproc

# ----------------------------------------------------------------------------
# In-memory BFS walk with a growable vector queue. No cap; doubles on
# overflow. Collects all plugin_ folders, excludes __MACOSX subtrees.
# Input: .root$ (search root), .resultsFile$ (write found paths here)
# Output: .count (number of plugin folders found)
procedure emlpmL_findPluginDirs: .root$, .resultsFile$
    .count = 0
    writeFile: .resultsFile$, ""
    @emlpmL_baseName: .root$
    .rootName$ = emlpmL_baseName.name$
    if startsWith (.rootName$, kPluginPrefix$)
        appendFileLine: .resultsFile$, .root$
        .count = .count + 1
    endif
    # Growable queue: initial capacity 64
    .cap = 64
    .q$# = empty$# (.cap)
    .head = 1
    .tail = 0
    .tail = .tail + 1
    .q$# [.tail] = .root$
    while .head <= .tail
        .current$ = .q$# [.head]
        .head = .head + 1
        .subDirs$# = folderNames$# (.current$ + "/*")
        for .i from 1 to size (.subDirs$#)
            .dirName$ = .subDirs$# [.i]
            if .dirName$ <> kMacosxExclude$
                .subPath$ = .current$ + "/" + .dirName$
                if startsWith (.dirName$, kPluginPrefix$)
                    appendFileLine: .resultsFile$, .subPath$
                    .count = .count + 1
                endif
                # Push onto queue; grow if needed
                if .tail >= .cap
                    .newCap = .cap * 2
                    .newQ$# = empty$# (.newCap)
                    .liveCount = .tail - .head + 1
                    for .j from 0 to .liveCount - 1
                        .newQ$# [.j + 1] = .q$# [.head + .j]
                    endfor
                    .q$# = .newQ$#
                    .head = 1
                    .tail = .liveCount
                    .cap = .newCap
                endif
                .tail = .tail + 1
                .q$# [.tail] = .subPath$
            endif
        endfor
    endwhile
endproc

# ----------------------------------------------------------------------------
procedure emlpmL_nthQuoted: .line$, .n
    .result$ = ""
    .found = 0
    .pos = 1
    while .found < .n and .pos <= length (.line$)
        .rest$ = mid$ (.line$, .pos, length (.line$) - .pos + 1)
        .qIdx = index (.rest$, """")
        if .qIdx = 0
            .pos = length (.line$) + 1
        else
            .openPos = .pos + .qIdx
            .afterQ$ = mid$ (.line$, .openPos,
                ... length (.line$) - .openPos + 1)
            .closeIdx = index (.afterQ$, """")
            if .closeIdx = 0
                .pos = length (.line$) + 1
            else
                .found = .found + 1
                if .found = .n
                    .result$ = mid$ (.line$, .openPos, .closeIdx - 1)
                endif
                .pos = .openPos + .closeIdx
            endif
        endif
    endwhile
endproc

# ----------------------------------------------------------------------------
procedure emlpmL_scanRegLine: .line$
    .isReg = 0
    .title$ = ""
    if startsWith (.line$, "Add menu command")
        @emlpmL_nthQuoted: .line$, 3
        .title$ = emlpmL_nthQuoted.result$
        .isReg = 1
    elsif startsWith (.line$, "Add action command")
        @emlpmL_nthQuoted: .line$, 4
        .title$ = emlpmL_nthQuoted.result$
        .isReg = 1
    endif
    if startsWith (.title$, "--") or .title$ = ""
        .isReg = 0
        .title$ = ""
    endif
endproc

# ----------------------------------------------------------------------------
procedure emlpmL_checkSetupPresent: .folderPath$
    .hasSetup = 0
    .commandCount = 0
    .setupPath$ = .folderPath$ + "/" + kSetupFile$
    if not fileReadable (.setupPath$)
        # no setup.praat
    else
        .hasSetup = 1
        .rawLines$# = readLinesFromFile$# (.setupPath$)
        .nRaw = size (.rawLines$#)
        .joined$ = ""
        for .j from 1 to .nRaw
            .ln$ = .rawLines$# [.j]
            while length (.ln$) > 0 and left$ (.ln$, 1) = " "
                .ln$ = right$ (.ln$, length (.ln$) - 1)
            endwhile
            if startsWith (.ln$, "...")
                .ln$ = right$ (.ln$, length (.ln$) - 3)
                .joined$ = .joined$ + " " + .ln$
            else
                if .joined$ <> ""
                    @emlpmL_scanRegLine: .joined$
                    if emlpmL_scanRegLine.isReg = 1
                        .commandCount = .commandCount + 1
                    endif
                endif
                .joined$ = .ln$
            endif
        endfor
        if .joined$ <> ""
            @emlpmL_scanRegLine: .joined$
            if emlpmL_scanRegLine.isReg = 1
                .commandCount = .commandCount + 1
            endif
        endif
    endif
endproc

# ----------------------------------------------------------------------------
procedure emlpmL_archiveExisting: .pluginName$, .prefsDir$, .archiveDir$
    .ok = 0
    .message$ = ""
    .q$ = """"
    .sourcePath$ = .prefsDir$ + "/" + .pluginName$
    createFolder: .archiveDir$
    .d# = date# ()
    .y$ = string$ (.d# [1])
    .mo$ = right$ ("0" + string$ (.d# [2]), 2)
    .dy$ = right$ ("0" + string$ (.d# [3]), 2)
    .h$ = right$ ("0" + string$ (.d# [4]), 2)
    .mi$ = right$ ("0" + string$ (.d# [5]), 2)
    .s$ = right$ ("0" + string$ (.d# [6]), 2)
    .stamp$ = .y$ + .mo$ + .dy$ + "-" + .h$ + .mi$ + .s$
    .archiveDest$ = .archiveDir$ + "/" + .pluginName$ + "-" + .stamp$
    if macintosh or unix
        runSystem_nocheck: "mv "
            ... + .q$ + .sourcePath$ + .q$
            ... + " " + .q$ + .archiveDest$ + .q$
    elsif windows
        runSystem_nocheck: "move "
            ... + .q$ + .sourcePath$ + .q$
            ... + " " + .q$ + .archiveDest$ + .q$
    endif
    if folderExists (.archiveDest$) and not folderExists (.sourcePath$)
        .ok = 1
    else
        .message$ = kMsgArchiveFail$ + .pluginName$
    endif
endproc

# ----------------------------------------------------------------------------
procedure emlpmL_placeFolder: .sourcePath$, .pluginName$, .prefsDir$
    .ok = 0
    .q$ = """"
    .destPath$ = .prefsDir$ + "/" + .pluginName$
    if macintosh or unix
        runSystem_nocheck: "cp -R "
            ... + .q$ + .sourcePath$ + .q$
            ... + " " + .q$ + .destPath$ + .q$
    elsif windows
        runSystem_nocheck: "xcopy /E /I /Q "
            ... + .q$ + .sourcePath$ + .q$
            ... + " " + .q$ + .destPath$ + .q$
    endif
    .ok = folderExists (.destPath$)
endproc

# ----------------------------------------------------------------------------
procedure emlpmL_verify: .pluginName$, .prefsDir$, .hadSetup
    .ok = 0
    .message$ = ""
    .pluginPath$ = .prefsDir$ + "/" + .pluginName$
    if not folderExists (.pluginPath$)
        .message$ = kMsgVerifyFail$ + .pluginName$
            ... + " -- folder not found after placement"
    elsif .hadSetup = 1
        if not fileReadable (.pluginPath$ + "/" + kSetupFile$)
            .message$ = kMsgVerifyFail$ + .pluginName$
                ... + " -- setup.praat missing after placement"
        else
            .ok = 1
        endif
    else
        .ok = 1
    endif
endproc

# ----------------------------------------------------------------------------
# Reads back boolean selections using per-row derived variable names.
# Input: .derivedNames$# (the variable name for each row), .nFound
# Output: .selected# (vector of 0/1)
procedure emlpmL_readSelections: .derivedNames$#, .nFound
    .selected# = zero# (.nFound)
    for .i from 1 to .nFound
        .vn$ = .derivedNames$# [.i]
        .selected# [.i] = '.vn$'
    endfor
endproc

# ----------------------------------------------------------------------------
procedure emlpmL_baseName: .path$
    # Strip trailing separators first (chooseFolder$ may add one)
    .clean$ = .path$
    .stripping = 1
    while .stripping = 1 and length (.clean$) > 0
        if right$ (.clean$, 1) = "/" or right$ (.clean$, 1) = "\"
            .clean$ = left$ (.clean$, length (.clean$) - 1)
        else
            .stripping = 0
        endif
    endwhile
    .lastSlash = max (rindex (.clean$, "/"), rindex (.clean$, "\"))
    if .lastSlash > 0
        .name$ = right$ (.clean$, length (.clean$) - .lastSlash)
    else
        .name$ = .clean$
    endif
endproc

# ============================================================================
# Main sequence
# ============================================================================

@emlpmL_versionOk
if emlpmL_versionOk.ok = 0
    exitScript: kMsgVersionFail$ + praatVersion$ + kMsgVersionSuffix$
endif

# Dialog 1: what to install
beginPause: kTitle$
    choice: "Source type", 1
        option: "A compressed file (.zip or .tar.gz)"
        option: "A folder that is already unpacked"
clicked = endPause: "Cancel", "Continue", 2, 0
if clicked = 1
    exitScript: kMsgCancelled$
endif

prefsDir$ = preferencesDirectory$
archiveDir$ = prefsDir$ + "/" + kArchiveName$

@emlpmL_makeStaging
if emlpmL_makeStaging.ok = 0
    exitScript: kMsgStagingFail$
endif
stagingPath$ = emlpmL_makeStaging.path$

# --- Source acquisition ---

if source_type = 1
    sourcePath$ = chooseReadFile$: "Select the plugin archive"
    if sourcePath$ = ""
        @emlpmL_cleanupStaging: stagingPath$
        exitScript: kMsgCancelled$
    endif
    @emlpmL_baseName: sourcePath$
    sourceName$ = emlpmL_baseName.name$
    if endsWith (sourcePath$, kExtZip$)
        format$ = "zip"
    elsif endsWith (sourcePath$, kExtTarGz$)
        format$ = "targz"
    elsif endsWith (sourcePath$, kExtTgz$)
        format$ = "targz"
    else
        @emlpmL_cleanupStaging: stagingPath$
        exitScript: kMsgBadExt$ + sourceName$
    endif
    unpackDest$ = stagingPath$ + "/unpacked"
    @emlpmL_unpack: format$, sourcePath$, unpackDest$
    if emlpmL_unpack.ok = 0
        failMsg$ = emlpmL_unpack.message$
        @emlpmL_cleanupStaging: stagingPath$
        exitScript: failMsg$
    endif
    searchRoot$ = unpackDest$

elsif source_type = 2
    sourcePath$ = chooseFolder$: "Select the plugin folder"
    if sourcePath$ = ""
        @emlpmL_cleanupStaging: stagingPath$
        exitScript: kMsgCancelled$
    endif
    @emlpmL_baseName: sourcePath$
    sourceName$ = emlpmL_baseName.name$
    searchRoot$ = sourcePath$
endif

# --- Search for plugin folders ---

resultsFile$ = stagingPath$ + "/" + kResultsName$
@emlpmL_findPluginDirs: searchRoot$, resultsFile$
nFound = emlpmL_findPluginDirs.count

if nFound = 0
    @emlpmL_cleanupStaging: stagingPath$
    exitScript: kMsgNoPluginFound$ + sourceName$ + "."
endif

foundPaths$# = readLinesFromFile$# (resultsFile$)
nFound = size (foundPaths$#)

# --- Build selection data ---

pluginNames$# = empty$# (nFound)
boolLabels$# = empty$# (nFound)
derivedNames$# = empty$# (nFound)
descLines$# = empty$# (nFound)
setupFlags# = zero# (nFound)
defaultFlags# = zero# (nFound)
prefixLen = length (kPluginPrefix$)
rootLen = length (searchRoot$)

for iFound from 1 to nFound
    fPath$ = foundPaths$# [iFound]
    @emlpmL_baseName: fPath$
    pName$ = emlpmL_baseName.name$
    pluginNames$# [iFound] = pName$

    # Sanitize label: non-alnum/non-underscore chars become spaces, then trim
    sanitized$ = replace_regex$ (pName$, "[^A-Za-z0-9_]", " ", 0)
    while startsWith (sanitized$, " ")
        sanitized$ = right$ (sanitized$, length (sanitized$) - 1)
    endwhile
    while endsWith (sanitized$, " ")
        sanitized$ = left$ (sanitized$, length (sanitized$) - 1)
    endwhile
    boolLabels$# [iFound] = sanitized$

    # Derived variable name: spaces back to underscores
    derivedNames$# [iFound] = replace$ (sanitized$, " ", "_", 0)

    # Relative path from search root
    if left$ (fPath$, rootLen) = searchRoot$
        relPath$ = right$ (fPath$, length (fPath$) - rootLen)
        if relPath$ <> ""
            if left$ (relPath$, 1) = "/" or left$ (relPath$, 1) = "\"
                relPath$ = right$ (relPath$, length (relPath$) - 1)
            endif
        endif
    else
        relPath$ = fPath$
    endif
    if relPath$ = ""
        relPath$ = "./"
    endif

    # Setup check
    @emlpmL_checkSetupPresent: fPath$
    setupFlags# [iFound] = emlpmL_checkSetupPresent.hasSetup
    cmdCount = emlpmL_checkSetupPresent.commandCount

    # Build annotation
    annot$ = ""
    if emlpmL_checkSetupPresent.hasSetup = 1
        if cmdCount > 0
            annot$ = "adds " + string$ (cmdCount) + " command"
            if cmdCount > 1
                annot$ = annot$ + "s"
            endif
        else
            annot$ = kAnnotNoCommands$
        endif
        defaultFlags# [iFound] = 1
    else
        annot$ = kAnnotNoSetup$
        defaultFlags# [iFound] = 0
    endif

    isInstalled = folderExists (prefsDir$ + "/" + pName$)
    if isInstalled = 1
        annot$ = annot$ + " -- " + kAnnotInstalled$
    endif

    # Display name: folder suffix with underscores as spaces
    if length (pName$) > prefixLen
        suffix$ = right$ (pName$, length (pName$) - prefixLen)
    else
        suffix$ = pName$
    endif
    displayName$ = replace$ (suffix$, "_", " ", 0)
    descLines$# [iFound] = displayName$ + " (" + annot$
        ... + ") -- at " + relPath$
endfor

# --- Pre-dialog collision check ---

for iA from 1 to nFound
    for iB from iA + 1 to nFound
        if derivedNames$# [iA] = derivedNames$# [iB]
            @emlpmL_cleanupStaging: stagingPath$
            exitScript: kMsgCollision$
                ... + pluginNames$# [iA] + " and "
                ... + pluginNames$# [iB]
                ... + kMsgCollisionSuffix$
        endif
    endfor
endfor

# --- Selection dialog (paginated, max kPageSize per page) ---

nPages = ceiling (nFound / kPageSize)

for iPage from 1 to nPages
    pageStart = (iPage - 1) * kPageSize + 1
    pageEnd = min (iPage * kPageSize, nFound)

    if nPages = 1
        pageTitle$ = kSelTitle$
    else
        pageTitle$ = kSelTitle$ + " (page "
            ... + string$ (iPage) + " of " + string$ (nPages) + ")"
    endif

    beginPause: pageTitle$
        for iShow from pageStart to pageEnd
            comment: descLines$# [iShow]
            boolean: boolLabels$# [iShow], defaultFlags# [iShow]
        endfor

    if iPage < nPages
        clicked = endPause: "Cancel", "Next", 2, 0
    else
        clicked = endPause: "Cancel", "Install selected", 2, 0
    endif

    if clicked = 1
        @emlpmL_cleanupStaging: stagingPath$
        exitScript: kMsgCancelled$
    endif
endfor

# Read all selections (boolean variables persist across pages)
@emlpmL_readSelections: derivedNames$#, nFound
selFlags# = emlpmL_readSelections.selected#

nSelected = 0
for iCheck from 1 to nFound
    nSelected = nSelected + selFlags# [iCheck]
endfor
if nSelected = 0
    @emlpmL_cleanupStaging: stagingPath$
    exitScript: kMsgNoneSelected$
endif

# --- Install loop ---

summaryLines$# = empty$# (nSelected)
summaryIdx = 0
createFolder: archiveDir$

for iInst from 1 to nFound
    if selFlags# [iInst] = 1
        pName$ = pluginNames$# [iInst]
        pPath$ = foundPaths$# [iInst]
        hadSetup = setupFlags# [iInst]

        wasReplaced = 0
        archiveOk = 1
        if folderExists (prefsDir$ + "/" + pName$)
            @emlpmL_archiveExisting: pName$, prefsDir$, archiveDir$
            if emlpmL_archiveExisting.ok = 1
                wasReplaced = 1
            else
                archiveOk = 0
                summaryIdx = summaryIdx + 1
                summaryLines$# [summaryIdx] = emlpmL_archiveExisting.message$
            endif
        endif

        if archiveOk = 1
            @emlpmL_placeFolder: pPath$, pName$, prefsDir$
            @emlpmL_verify: pName$, prefsDir$, hadSetup
            summaryIdx = summaryIdx + 1
            if emlpmL_verify.ok = 0
                summaryLines$# [summaryIdx] = "FAILED: "
                    ... + pName$ + " -- " + emlpmL_verify.message$
            else
                if wasReplaced = 1
                    summaryLines$# [summaryIdx] = pName$
                        ... + kMsgArchiveNote$
                else
                    summaryLines$# [summaryIdx] = pName$
                endif
            endif
        endif
    endif
endfor

# --- Cleanup and summary ---

@emlpmL_cleanupStaging: stagingPath$

beginPause: "Installation complete"
    for iSummary from 1 to summaryIdx
        comment: summaryLines$# [iSummary]
    endfor
    comment: ""
    comment: kMsgRestart$
endPause: "OK", 1, 0
