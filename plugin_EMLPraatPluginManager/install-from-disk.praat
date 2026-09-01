# ============================================================================
# EML Plugin Manager -- Install Plugin from Disk
# ============================================================================
# Purpose: Installs an already-downloaded plugin into Praat's preferences
#          folder. Accepts a .zip, .tar.gz/.tgz, or an already-unpacked
#          folder. Finds all plugin_ folders (and plugin_ near-misses) at any
#          depth, proposes a canonical folder name for each (stripping host/
#          branch/version/copy junk, honouring the plugin's own self-references),
#          lets the user select which to install and whether to keep literal
#          names, archives any existing same-named plugin, and places the new one.
# Date: 1 September 2026
# Version: 5.0
#
# 4.1 -- Exit-button labels: buttons that stop the script now read "Quit"
#       (were "Cancel"). Rule: "Cancel" only when the action is cancelled
#       but the script returns to another point; "Quit" when the script
#       stops. Every exit path here calls exitScript, so all read "Quit".
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

emlManager_pluginPrefix$ = "plugin_"
emlManager_macosxExclude$ = "__MACOSX"
emlManager_setupFile$ = "setup.praat"
emlManager_stagingName$ = "eml_pm_staging"
emlManager_archiveName$ = "eml_pm_archive"
emlManager_resultsName$ = "found_plugins.txt"
emlManager_pageSize = 12

# Canon wrap width for every pause-dialog wrap call site in the plugin
# (this file and remove-plugin.praat). 78 overflowed Praat's pause
# window in its proportional font (measured in the GUI drive); 62 is
# the width the install file's own dialog was pinned at.
emlManager_wrapWidth = 62

emlManager_floorVersion = 6630
emlManager_floorVersionLabel$ = "6.6.30"

emlManager_extZip$ = ".zip"
emlManager_extTarGz$ = ".tar.gz"
emlManager_extTgz$ = ".tgz"

# Characters that may appear in a plugin_ name reference (sec. 5 content scan)
emlManager_nameChars$ = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"

emlManager_title$ = "Install Plugin from Disk"
emlManager_selTitle$ = "Select plugins to install"
emlManager_useLiteralLabel$ = "Use folder names exactly as found"
emlManager_msgCancelled$ = "Installation cancelled."
emlManager_msgVersionFail$ = "This script requires Praat "
    ... + emlManager_floorVersionLabel$
    ... + " or newer. You have "
emlManager_msgVersionSuffix$ = ". Please update Praat from praat.org and try again."
emlManager_msgNoPluginFound$ = "No plugin folder (a folder whose name starts with "
    ... + emlManager_pluginPrefix$ + ") was found inside "
emlManager_msgNoInstallable$ = "No installable plugin folder was found inside "
emlManager_msgBadExt$ = "Only .zip, .tar.gz, and .tgz files are accepted. Got: "
emlManager_msgUnpackFail$ = "Unpacking failed. "
emlManager_msgLinuxUnzipHint$ = "The unzip tool may not be installed on this system."
    ... + " The file that could not be unpacked: "
emlManager_msgNoneSelected$ = "No plugins selected."
emlManager_msgCollision$ = "Two found plugins produce the same internal name: "
emlManager_msgCollisionSuffix$ = ". Install them one at a time via the folder option."
emlManager_msgCollisionLiteral$ = "Two selected folders share the same literal name: "
emlManager_msgVerifyFail$ = "Verification failed for "
emlManager_msgArchiveFail$ = "FAILED: could not archive existing "
emlManager_msgRestart$ = "Restart Praat to activate."
emlManager_msgArchiveNote$ = " (previous version kept in the archive folder)"
emlManager_msgStagingFail$ = "Failed to create staging folder."

emlManager_annotNoCommands$ = "registers no commands"
emlManager_annotNoSetup$ = "no setup.praat -- not a functioning plugin as-is"

# Item 3: version-aware already-installed annotations. Every branch ends with
# emlManager_annotInstSuffix$; the branch-specific pieces are assembled around
# the installed (X) and candidate (Y) version strings at runtime.
emlManager_annotInstNewerPrefix$ = "already installed (you have "
emlManager_annotInstOlderPrefix$ = "OLDER than installed (you have "
emlManager_annotInstMid$ = "; this archive is "
emlManager_annotInstEqualPrefix$ = "this version ("
emlManager_annotInstEqualMid$ = ") is already installed"
emlManager_annotInstIdentical$ = "already installed; appears identical to the installed copy"
emlManager_annotInstDiffers$ = "already installed; differs from the installed copy"
emlManager_annotInstSuffix$ = "; replacing keeps the current copy in the archive folder"

emlManager_annotConfirmed$ = "name confirmed by the plugin's own scripts"
emlManager_annotKeepsName$ = "keeps its folder name -- the plugin's scripts reference it"
emlManager_annotRenamedFrom$ = "renamed from "
emlManager_annotGuessed$ = "name guessed from folder "

# Item 5: installed-command report (emlManagerParseSetupCommands and its
# Installation-complete dialog integration -- see below).
emlManager_rptCmdMenu$ = "Add menu command"
emlManager_rptCmdAction$ = "Add action command"
emlManager_rptVowels$ = "AEIOU"
emlManager_rptNoCommands$ = "Adds no menu commands or buttons (files only)."
emlManager_rptComputedPrefix$ = "Plus "
emlManager_rptComputedSuffix$ = " command(s) named when the plugin loads."
emlManager_rptHeaderSuffix$ = " adds:"
emlManager_titleComplete$ = "Installation complete"
emlManager_msgOk$ = "OK"
emlManager_msgNext$ = "Next"

# ============================================================================
# Work procedures
# ============================================================================

procedure emlManagerVersionOk
    .ok = praatVersion >= emlManager_floorVersion
endproc

# ----------------------------------------------------------------------------
# Item 3. True when .s$ is a non-empty run of ASCII digits.
procedure emlManagerIsNumericToken: .s$
    .yes = 0
    if .s$ <> "" and index_regex (.s$, "^[0-9]+$") > 0
        .yes = 1
    endif
endproc

# ----------------------------------------------------------------------------
# Item 3. Component-wise version comparator: -1 a older, 0 equal, 1 a newer.
# Split both on ".", compare numerically component-wise; a missing component
# counts as 0. A non-numeric component makes THAT component compare as plain
# text instead (this is the comparator the future catalog layer needs).
procedure emlManagerCompareVersions: .a$, .b$
    .cmp = 0
    .aParts$# = splitBy$# (.a$, ".")
    .bParts$# = splitBy$# (.b$, ".")
    .na = size (.aParts$#)
    .nb = size (.bParts$#)
    .n = max (.na, .nb)
    .i = 1
    .done = 0
    while .done = 0 and .i <= .n
        if .i <= .na
            .av$ = .aParts$# [.i]
        else
            .av$ = "0"
        endif
        if .i <= .nb
            .bv$ = .bParts$# [.i]
        else
            .bv$ = "0"
        endif
        @emlManagerIsNumericToken: .av$
        .aNum = emlManagerIsNumericToken.yes
        @emlManagerIsNumericToken: .bv$
        .bNum = emlManagerIsNumericToken.yes
        if .aNum = 1 and .bNum = 1
            .avn = number (.av$)
            .bvn = number (.bv$)
            if .avn < .bvn
                .cmp = -1
                .done = 1
            elsif .avn > .bvn
                .cmp = 1
                .done = 1
            endif
        else
            if .av$ <> .bv$
                if .av$ < .bv$
                    .cmp = -1
                else
                    .cmp = 1
                endif
                .done = 1
            endif
        endif
        .i = .i + 1
    endwhile
endproc

# ----------------------------------------------------------------------------
# Item 3. First line of a top-level VERSION file, trimmed of whitespace; the
# empty string when the file is absent.
procedure emlManagerReadVersion: .folder$
    .version$ = ""
    .path$ = .folder$ + "/VERSION"
    if fileReadable (.path$)
        .lines$# = readLinesFromFile$# (.path$)
        if size (.lines$#) >= 1
            .raw$ = .lines$# [1]
            while length (.raw$) > 0 and
                ... (left$ (.raw$, 1) = " " or left$ (.raw$, 1) = tab$)
                .raw$ = right$ (.raw$, length (.raw$) - 1)
            endwhile
            while length (.raw$) > 0 and
                ... (right$ (.raw$, 1) = " " or right$ (.raw$, 1) = tab$)
                .raw$ = left$ (.raw$, length (.raw$) - 1)
            endwhile
            .version$ = .raw$
        endif
    endif
endproc

# ----------------------------------------------------------------------------
# Item 3 difference probe (also the shared recursive tree walk -- the ONE
# BFS every caller needing files, folders, or both reuses; never
# reimplemented). Recursively lists every file AND every subfolder under
# .root$, as paths relative to .root$ (the root itself is not included among
# .folders$#), each returned SORTED. Excludes __MACOSX subtrees.
# .scratchFile$ is scratch space for the file list (overwritten); it never
# needs to survive. The folder list is small enough to keep in memory.
procedure emlManagerListRelFiles: .root$, .scratchFile$
    writeFile: .scratchFile$, ""
    .rootLen = length (.root$)
    .cap = 64
    .q$# = empty$# (.cap)
    .head = 1
    .tail = 1
    .q$# [1] = .root$
    .folderCap = 64
    .rawFolders$# = empty$# (.folderCap)
    .folderN = 0
    while .head <= .tail
        .cur$ = .q$# [.head]
        .head = .head + 1
        .files$# = fileNames$# (.cur$ + "/*")
        for .fi from 1 to size (.files$#)
            .fpath$ = .cur$ + "/" + .files$# [.fi]
            .rel$ = right$ (.fpath$, length (.fpath$) - .rootLen)
            if startsWith (.rel$, "/") or startsWith (.rel$, "\")
                .rel$ = right$ (.rel$, length (.rel$) - 1)
            endif
            appendFileLine: .scratchFile$, .rel$
        endfor
        .subs$# = folderNames$# (.cur$ + "/*")
        for .si from 1 to size (.subs$#)
            if .subs$# [.si] <> emlManager_macosxExclude$
                .subPath$ = .cur$ + "/" + .subs$# [.si]
                .relFolder$ = right$ (.subPath$, length (.subPath$) - .rootLen)
                if startsWith (.relFolder$, "/") or startsWith (.relFolder$, "\")
                    .relFolder$ = right$ (.relFolder$, length (.relFolder$) - 1)
                endif
                if .folderN >= .folderCap
                    .newFolderCap = .folderCap * 2
                    .newRawFolders$# = empty$# (.newFolderCap)
                    for .fk from 1 to .folderN
                        .newRawFolders$# [.fk] = .rawFolders$# [.fk]
                    endfor
                    .rawFolders$# = .newRawFolders$#
                    .folderCap = .newFolderCap
                endif
                .folderN = .folderN + 1
                .rawFolders$# [.folderN] = .relFolder$
                if .tail >= .cap
                    .newCap = .cap * 2
                    .newQ$# = empty$# (.newCap)
                    .live = .tail - .head + 1
                    for .k from 0 to .live - 1
                        .newQ$# [.k + 1] = .q$# [.head + .k]
                    endfor
                    .q$# = .newQ$#
                    .head = 1
                    .tail = .live
                    .cap = .newCap
                endif
                .tail = .tail + 1
                .q$# [.tail] = .subPath$
            endif
        endfor
    endwhile
    .raw$# = readLinesFromFile$# (.scratchFile$)
    if size (.raw$#) > 0
        .files$# = sort$# (.raw$#)
    else
        .files$# = empty$# (0)
    endif
    if .folderN > 0
        .trimmedFolders$# = empty$# (.folderN)
        for .ft from 1 to .folderN
            .trimmedFolders$# [.ft] = .rawFolders$# [.ft]
        endfor
        .folders$# = sort$# (.trimmedFolders$#)
    else
        .folders$# = empty$# (0)
    endif
endproc

# ----------------------------------------------------------------------------
# Item 3 difference probe: the sorted relative file lists of both trees are
# equal AND the two setup.praat files are byte-equal (when both exist).
# .scratchDir$ is a writable folder for the two temporary listing files.
procedure emlManagerFoldersAppearIdentical: .candFolder$, .instFolder$, .scratchDir$
    .identical = 0
    @emlManagerListRelFiles: .candFolder$, .scratchDir$ + "/eml_pm_diff_cand.txt"
    .candFiles$# = emlManagerListRelFiles.files$#
    @emlManagerListRelFiles: .instFolder$, .scratchDir$ + "/eml_pm_diff_inst.txt"
    .instFiles$# = emlManagerListRelFiles.files$#
    .sameList = 0
    if size (.candFiles$#) = size (.instFiles$#)
        .sameList = 1
        for .i from 1 to size (.candFiles$#)
            if .candFiles$# [.i] <> .instFiles$# [.i]
                .sameList = 0
            endif
        endfor
    endif
    if .sameList = 1
        .setupSame = 1
        .candSetup$ = .candFolder$ + "/" + emlManager_setupFile$
        .instSetup$ = .instFolder$ + "/" + emlManager_setupFile$
        .candHas = fileReadable (.candSetup$)
        .instHas = fileReadable (.instSetup$)
        if .candHas = 1 and .instHas = 1
            .candContent$ = readFile$ (.candSetup$)
            .instContent$ = readFile$ (.instSetup$)
            if .candContent$ <> .instContent$
                .setupSame = 0
            endif
        elsif .candHas <> .instHas
            .setupSame = 0
        endif
        if .setupSame = 1
            .identical = 1
        endif
    endif
endproc

# ----------------------------------------------------------------------------
# Item 3: builds the version-aware already-installed annotation and the
# collision-row default checkbox state (1 = checked) for a collision between
# .candFolder$ (the found candidate, in staging or the user's folder) and
# .instFolder$ (the already-installed folder). Only called once a collision
# on the proposed install name has been confirmed by the caller.
procedure emlManagerInstalledAnnotation: .candFolder$, .instFolder$, .scratchDir$
    @emlManagerReadVersion: .candFolder$
    .candVer$ = emlManagerReadVersion.version$
    @emlManagerReadVersion: .instFolder$
    .instVer$ = emlManagerReadVersion.version$
    if .candVer$ <> "" and .instVer$ <> ""
        @emlManagerCompareVersions: .candVer$, .instVer$
        .vcmp = emlManagerCompareVersions.cmp
        if .vcmp = 1
            .annot$ = emlManager_annotInstNewerPrefix$ + .instVer$
                ... + emlManager_annotInstMid$ + .candVer$ + ")" + emlManager_annotInstSuffix$
            .checked = 1
        elsif .vcmp = 0
            .annot$ = emlManager_annotInstEqualPrefix$ + .instVer$
                ... + emlManager_annotInstEqualMid$ + emlManager_annotInstSuffix$
            .checked = 0
        else
            .annot$ = emlManager_annotInstOlderPrefix$ + .instVer$
                ... + emlManager_annotInstMid$ + .candVer$ + ")" + emlManager_annotInstSuffix$
            .checked = 0
        endif
    else
        @emlManagerFoldersAppearIdentical: .candFolder$, .instFolder$, .scratchDir$
        if emlManagerFoldersAppearIdentical.identical = 1
            .annot$ = emlManager_annotInstIdentical$ + emlManager_annotInstSuffix$
            .checked = 0
        else
            .annot$ = emlManager_annotInstDiffers$ + emlManager_annotInstSuffix$
            .checked = 1
        endif
    endif
endproc

# ----------------------------------------------------------------------------
# Item 4. Splits .text$ into successive lines of at most .maxWidth characters,
# breaking only at word boundaries. Never shortens or drops text -- a single
# word longer than .maxWidth stays whole on its own line.
procedure emlManagerWrapText: .text$, .maxWidth
    .words$# = splitByWhitespace$# (.text$)
    .nWords = size (.words$#)
    .lines$# = empty$# (max (.nWords, 1))
    .nLines = 0
    .cur$ = ""
    for .wi from 1 to .nWords
        .w$ = .words$# [.wi]
        if .cur$ = ""
            .cand$ = .w$
        else
            .cand$ = .cur$ + " " + .w$
        endif
        if .cur$ = "" or length (.cand$) <= .maxWidth
            .cur$ = .cand$
        else
            .nLines = .nLines + 1
            .lines$# [.nLines] = .cur$
            .cur$ = .w$
        endif
    endfor
    if .cur$ <> "" or .nWords = 0
        .nLines = .nLines + 1
        .lines$# [.nLines] = .cur$
    endif
    # Trim the over-allocated vector down to exactly the lines produced.
    .trimmed$# = empty$# (.nLines)
    for .ti from 1 to .nLines
        .trimmed$# [.ti] = .lines$# [.ti]
    endfor
    .lines$# = .trimmed$#
endproc

# ----------------------------------------------------------------------------
procedure emlManagerMakeStaging
    .path$ = preferencesDirectory$ + "/" + emlManager_stagingName$
    if folderExists (.path$)
        @emlManagerCleanupStaging: .path$
    endif
    createFolder: .path$
    .ok = folderExists (.path$)
endproc

# ----------------------------------------------------------------------------
procedure emlManagerCleanupStaging: .path$
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
procedure emlManagerUnpack: .format$, .source$, .dest$
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
        .message$ = emlManager_msgUnpackFail$
        if unix and .format$ = "zip"
            .message$ = .message$ + emlManager_msgLinuxUnzipHint$ + .source$
        endif
    endif
endproc

# ----------------------------------------------------------------------------
# In-memory BFS walk with a growable vector queue. No cap; doubles on
# overflow. Collects all plugin_ folders AND plugin_ near-misses (folders whose
# name CONTAINS plugin_ past the first character, per sec. 3), excludes __MACOSX
# subtrees. Near-miss gating and dropping happens later, per-candidate.
# Input: .root$ (search root), .resultsFile$ (write found paths here)
# Output: .count (number of candidate folders found)
procedure emlManagerFindPluginDirs: .root$, .resultsFile$
    .count = 0
    writeFile: .resultsFile$, ""
    @emlManagerBaseName: .root$
    .rootName$ = emlManagerBaseName.name$
    @emlManagerIsCandidateName: .rootName$
    if emlManagerIsCandidateName.yes = 1
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
            if .dirName$ <> emlManager_macosxExclude$
                .subPath$ = .current$ + "/" + .dirName$
                @emlManagerIsCandidateName: .dirName$
                if emlManagerIsCandidateName.yes = 1
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
# A folder name is a candidate if it starts with plugin_ (true match) OR
# contains plugin_ at any later position (near-miss). Case-sensitive on
# plugin_ (Praat's own activation rule is the authority, sec. 3).
procedure emlManagerIsCandidateName: .name$
    .yes = 0
    if startsWith (.name$, emlManager_pluginPrefix$)
        .yes = 1
    elsif index (.name$, emlManager_pluginPrefix$) > 1
        .yes = 1
    endif
endproc

# ----------------------------------------------------------------------------
# sec. 4 junk-token test. A trailing token is junk if (case-insensitively) it is a
# branch word, a 7-40 char hex hash, a version (optional v, up to three
# dot-separated digit groups, optional single trailing letter), or a copy
# artifact (copy / copyN / (N)). Regex dialect + all sec. 9 tokens sandbox-verified
# 31 Aug 2026 (Praat 7.0.02).
procedure emlManagerIsJunkToken: .tok$
    .low$ = replace_regex$ (.tok$, "[A-Z]", "\L&", 0)
    .yes = 0
    if index_regex (.low$, "^(master|main|develop|dev|trunk|release|latest|head)$") > 0
        .yes = 1
    elsif index_regex (.low$, "^[0-9a-f]{7,40}$") > 0
        .yes = 1
    elsif index_regex (.low$, "^v?[0-9]+(\.[0-9]+){0,2}[a-z]?$") > 0
        .yes = 1
    elsif index_regex (.low$, "^copy[0-9]*$") > 0
        .yes = 1
    elsif index_regex (.low$, "^\([0-9]+\)$") > 0
        .yes = 1
    endif
endproc

# ----------------------------------------------------------------------------
# One sec. 4 stripping pass. Finds the LEFTMOST separator (-, _, ., space) whose
# ENTIRE tail is a single junk token (this yields the longest trailing token,
# so a dotted version like 1.2.0 is taken whole, not one dot-group at a time).
# HARD GUARD: never strip down to emlManager_pluginPrefix$ or shorter; on hitting the
# guard, stop -- do not fall through to a rightmost separator.
# Output: .result$ (possibly stripped), .stripped (0/1)
procedure emlManagerStripOnce: .name$
    .stripped = 0
    .result$ = .name$
    .prefixLen = length (emlManager_pluginPrefix$)
    .n = length (.name$)
    .p = 1
    .done = 0
    while .done = 0 and .p <= .n
        .ch$ = mid$ (.name$, .p, 1)
        .isSep = (.ch$ = "-") or (.ch$ = "_") or (.ch$ = ".") or (.ch$ = " ")
        if .isSep = 1
            .tail$ = mid$ (.name$, .p + 1, .n - .p)
            if .tail$ <> ""
                @emlManagerIsJunkToken: .tail$
                if emlManagerIsJunkToken.yes = 1
                    .cand$ = left$ (.name$, .p - 1)
                    if length (.cand$) > .prefixLen
                        .result$ = .cand$
                        .stripped = 1
                    endif
                    .done = 1
                endif
            endif
        endif
        .p = .p + 1
    endwhile
endproc

# ----------------------------------------------------------------------------
# sec. 3-sec. 5 per-candidate canonicalization. PURE (no I/O) -- the harness drives the
# whole sec. 9 normative table through this procedure.
# Input:
#   .literal$    the folder name as found
#   .hasSetup    1 if the folder has a top-level setup.praat, else 0
#   .contentRef$ one of: none | literal | proposal | literal_external
#                | proposal_external   (from emlManagerScanNameEvidence at runtime;
#                fed directly from the TSV in the harness)
# Output:
#   .proposal$    the install-name proposal
#   .row$         disposition: row | row_unchecked | dropped
#   .isNearMiss   0/1
#   .confirmed    1 if content evidence confirmed the proposal
#   .renamedFrom$ the literal name when proposal <> literal, else ""
procedure emlManagerCanonicalName: .literal$, .hasSetup, .contentRef$
    .prefixLen = length (emlManager_pluginPrefix$)
    # --- match type + candidate stem (sec. 3) ---
    if startsWith (.literal$, emlManager_pluginPrefix$)
        .isNearMiss = 0
        .stem$ = .literal$
    else
        .isNearMiss = 1
        .firstIdx = index (.literal$, emlManager_pluginPrefix$)
        .stem$ = mid$ (.literal$, .firstIdx, length (.literal$) - .firstIdx + 1)
    endif
    # --- sec. 4 suffix stripping, max 3 iterations ---
    .work$ = .stem$
    .iter = 0
    .changed = 1
    while .changed = 1 and .iter < 3
        @emlManagerStripOnce: .work$
        if emlManagerStripOnce.stripped = 1
            .work$ = emlManagerStripOnce.result$
            .changed = 1
            .iter = .iter + 1
        else
            .changed = 0
        endif
    endwhile
    .heuristic$ = .work$
    # --- sec. 5 content override ---
    .confirmed = 0
    if .contentRef$ = "literal"
        .proposal$ = .literal$
    else
        .proposal$ = .heuristic$
        if .contentRef$ = "proposal"
            .confirmed = 1
        endif
    endif
    # --- renamed-from ---
    if .proposal$ <> .literal$
        .renamedFrom$ = .literal$
    else
        .renamedFrom$ = ""
    endif
    # --- disposition (sec. 5 near-miss gating) ---
    if .isNearMiss = 0
        .row$ = "row"
    else
        if .confirmed = 1
            .row$ = "row"
        elsif .hasSetup = 1
            .row$ = "row_unchecked"
        else
            .row$ = "dropped"
        endif
    endif
endproc

# ----------------------------------------------------------------------------
# sec. 5 content-evidence scan. Reads every *.praat file in the folder (recursive,
# string matching only, never execution), collects maximal plugin_<namechars>
# matches, and applies the subpath-resolution discriminator to decide whether a
# match equal to the proposal or the literal is INTERNAL (counts) or EXTERNAL
# (a same-named reference elsewhere; discarded).
#
# A file-size ceiling (e.g. 1 MB) was CONSIDERED here and DISCARDED (session
# 31 Aug 2026): the scan opens only *.praat files, so data folders never reach
# it; the subpath discriminator below already rejects incidental plugin_ runs
# inside data blobs at any size; and pure Praat has no file-size primitive, so
# a size gate would require reading the file to measure it -- pure downside.
#
# Input: .folderPath$, .literal$, .proposal$
# Output: .contentRef$ (none | literal | proposal | literal_external
#         | proposal_external)
procedure emlManagerScanNameEvidence: .folderPath$, .literal$, .proposal$
    .cProp = 0
    .cLit = 0
    .ncProp = 0
    .ncLit = 0
    # BFS over subfolders; process *.praat files in each
    .cap = 64
    .q$# = empty$# (.cap)
    .head = 1
    .tail = 1
    .q$# [1] = .folderPath$
    while .head <= .tail
        .cur$ = .q$# [.head]
        .head = .head + 1
        .files$# = fileNames$# (.cur$ + "/*.praat")
        for .fi from 1 to size (.files$#)
            @emlManagerScanOneFile: .cur$ + "/" + .files$# [.fi],
                ... .folderPath$, .literal$, .proposal$
            .cProp = .cProp + emlManagerScanOneFile.cProp
            .cLit = .cLit + emlManagerScanOneFile.cLit
            .ncProp = .ncProp + emlManagerScanOneFile.ncProp
            .ncLit = .ncLit + emlManagerScanOneFile.ncLit
        endfor
        .subs$# = folderNames$# (.cur$ + "/*")
        for .si from 1 to size (.subs$#)
            if .subs$# [.si] <> emlManager_macosxExclude$
                if .tail >= .cap
                    .newCap = .cap * 2
                    .newQ$# = empty$# (.newCap)
                    .live = .tail - .head + 1
                    for .k from 0 to .live - 1
                        .newQ$# [.k + 1] = .q$# [.head + .k]
                    endfor
                    .q$# = .newQ$#
                    .head = 1
                    .tail = .live
                    .cap = .newCap
                endif
                .tail = .tail + 1
                .q$# [.tail] = .cur$ + "/" + .subs$# [.si]
            endif
        endfor
    endwhile
    if .cProp > 0
        .contentRef$ = "proposal"
    elsif .cLit > 0
        .contentRef$ = "literal"
    elsif .ncProp > 0
        .contentRef$ = "proposal_external"
    elsif .ncLit > 0
        .contentRef$ = "literal_external"
    else
        .contentRef$ = "none"
    endif
endproc

# ----------------------------------------------------------------------------
procedure emlManagerScanOneFile: .fpath$, .folderPath$, .literal$, .proposal$
    .cProp = 0
    .cLit = 0
    .ncProp = 0
    .ncLit = 0
    if fileReadable (.fpath$)
        .lines$# = readLinesFromFile$# (.fpath$)
        for .li from 1 to size (.lines$#)
            @emlManagerScanOneLine: .lines$# [.li],
                ... .folderPath$, .literal$, .proposal$
            .cProp = .cProp + emlManagerScanOneLine.cProp
            .cLit = .cLit + emlManagerScanOneLine.cLit
            .ncProp = .ncProp + emlManagerScanOneLine.ncProp
            .ncLit = .ncLit + emlManagerScanOneLine.ncLit
        endfor
    endif
endproc

# ----------------------------------------------------------------------------
procedure emlManagerScanOneLine: .line$, .folderPath$, .literal$, .proposal$
    .cProp = 0
    .cLit = 0
    .ncProp = 0
    .ncLit = 0
    .n = length (.line$)
    .pos = 1
    while .pos <= .n
        .rem$ = mid$ (.line$, .pos, .n - .pos + 1)
        .rel = index (.rem$, emlManager_pluginPrefix$)
        if .rel = 0
            .pos = .n + 1
        else
            .mstart = .pos + .rel - 1
            # walk the maximal name-char run from the match start
            .mlen = 0
            .k = .mstart
            .walking = 1
            while .walking = 1 and .k <= .n
                .c$ = mid$ (.line$, .k, 1)
                if index (emlManager_nameChars$, .c$) > 0
                    .mlen = .mlen + 1
                    .k = .k + 1
                else
                    .walking = 0
                endif
            endwhile
            .match$ = mid$ (.line$, .mstart, .mlen)
            if .mlen > length (emlManager_pluginPrefix$)
                .isProp = (.match$ = .proposal$)
                .isLit = (.match$ = .literal$)
                if .isProp = 1 or .isLit = 1
                    # subpath after the match: up to first " , space, tab, EOL
                    .sp = .mstart + .mlen
                    .subpath$ = ""
                    .sw = 1
                    .j = .sp
                    while .sw = 1 and .j <= .n
                        .c2$ = mid$ (.line$, .j, 1)
                        if .c2$ = """" or .c2$ = " " or .c2$ = tab$
                            .sw = 0
                        else
                            .subpath$ = .subpath$ + .c2$
                            .j = .j + 1
                        endif
                    endwhile
                    if startsWith (.subpath$, "/")
                        .subpath$ = right$ (.subpath$, length (.subpath$) - 1)
                    endif
                    # resolve: empty subpath (bare root ref) or a path that
                    # exists inside the folder under evaluation => counts
                    .counts = 0
                    if .subpath$ = ""
                        .counts = 1
                    else
                        .cand$ = .folderPath$ + "/" + .subpath$
                        if fileReadable (.cand$) or folderExists (.cand$)
                            .counts = 1
                        endif
                    endif
                    # classify (proposal takes precedence when both equal)
                    if .isProp = 1
                        if .counts = 1
                            .cProp = .cProp + 1
                        else
                            .ncProp = .ncProp + 1
                        endif
                    else
                        if .counts = 1
                            .cLit = .cLit + 1
                        else
                            .ncLit = .ncLit + 1
                        endif
                    endif
                endif
            endif
            .pos = .mstart + .mlen
            if .mlen = 0
                .pos = .mstart + 1
            endif
        endif
    endwhile
endproc

# ----------------------------------------------------------------------------
# Boolean label + Praat-derived variable name for a proposed/literal name.
# Mirrors Praat's own derivation (spaces -> underscores, first char lowercased)
# so emlManagerReadSelections -- and any other indirect readback of a
# pause-form boolean built from .derived$ -- reads the right variable back.
# GATE READBACK (measured, from the failed drive): Praat lowercases the
# FIRST character when it turns a field label into a pause-form variable
# name. .label$ (the text shown to the user) is NOT touched -- only
# .derived$ (the variable name) is lowercased, here, once, as the canon;
# every caller that derives a variable name goes through this procedure, so
# fixing it here fixes every reader in one place (checked: no caller
# depended on the unlowered form -- see the callers list at the bottom of
# this comment).
procedure emlManagerDeriveLabel: .name$
    .san$ = replace_regex$ (.name$, "[^A-Za-z0-9_]", " ", 0)
    while startsWith (.san$, " ")
        .san$ = right$ (.san$, length (.san$) - 1)
    endwhile
    while endsWith (.san$, " ")
        .san$ = left$ (.san$, length (.san$) - 1)
    endwhile
    .label$ = .san$
    .derived$ = replace$ (.san$, " ", "_", 0)
    .derived$ = replace_regex$ (.derived$, "^.", "\L&", 0)
endproc

# ----------------------------------------------------------------------------
procedure emlManagerNthQuoted: .line$, .n
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
procedure emlManagerScanRegLine: .line$
    .isReg = 0
    .title$ = ""
    if startsWith (.line$, "Add menu command")
        @emlManagerNthQuoted: .line$, 3
        .title$ = emlManagerNthQuoted.result$
        .isReg = 1
    elsif startsWith (.line$, "Add action command")
        @emlManagerNthQuoted: .line$, 4
        .title$ = emlManagerNthQuoted.result$
        .isReg = 1
    endif
    if startsWith (.title$, "--") or .title$ = ""
        .isReg = 0
        .title$ = ""
    endif
endproc

# ----------------------------------------------------------------------------
procedure emlManagerCheckSetupPresent: .folderPath$
    .hasSetup = 0
    .commandCount = 0
    .setupPath$ = .folderPath$ + "/" + emlManager_setupFile$
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
                    @emlManagerScanRegLine: .joined$
                    if emlManagerScanRegLine.isReg = 1
                        .commandCount = .commandCount + 1
                    endif
                endif
                .joined$ = .ln$
            endif
        endfor
        if .joined$ <> ""
            @emlManagerScanRegLine: .joined$
            if emlManagerScanRegLine.isReg = 1
                .commandCount = .commandCount + 1
            endif
        endif
    endif
endproc

# ----------------------------------------------------------------------------
procedure emlManagerArchiveExisting: .pluginName$, .prefsDir$, .archiveDir$
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
        .message$ = emlManager_msgArchiveFail$ + .pluginName$
    endif
endproc

# ----------------------------------------------------------------------------
procedure emlManagerPlaceFolder: .sourcePath$, .pluginName$, .prefsDir$
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
procedure emlManagerVerify: .pluginName$, .prefsDir$, .hadSetup
    .ok = 0
    .message$ = ""
    .pluginPath$ = .prefsDir$ + "/" + .pluginName$
    if not folderExists (.pluginPath$)
        .message$ = emlManager_msgVerifyFail$ + .pluginName$
            ... + " -- folder not found after placement"
    elsif .hadSetup = 1
        if not fileReadable (.pluginPath$ + "/" + emlManager_setupFile$)
            .message$ = emlManager_msgVerifyFail$ + .pluginName$
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
# Input: .derivedNames$# (the variable name for each row), .nRows
# Output: .selected# (vector of 0/1)
procedure emlManagerReadSelections: .derivedNames$#, .nRows
    .selected# = zero# (.nRows)
    for .i from 1 to .nRows
        .vn$ = .derivedNames$# [.i]
        .selected# [.i] = '.vn$'
    endfor
endproc

# ----------------------------------------------------------------------------
procedure emlManagerBaseName: .path$
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

# ----------------------------------------------------------------------------
# Item 5. One argument token starting at .pos in .s$: skips leading spaces,
# tabs and commas (the separators between arguments in both the comma-heavy
# modern syntax and the whitespace-only legacy syntax), then reads either a
# quoted string (doubled "" unescaped to a literal ") or a bare token running
# to the next space/tab/comma. The token's own value is trimmed of leading
# and trailing whitespace -- a quoted title of a single space collapses to
# an empty title, matching a real plugin's setup.praat (regression fixture).
# Output: .found (0 at end of string), .quoted (1 = came from a "..." span),
# .value$, .nextPos (pass back in as .pos for the following token).
procedure emlManagerRptNextToken: .s$, .pos
    .len = length (.s$)
    .p = .pos
    while .p <= .len and (mid$ (.s$, .p, 1) = " " or mid$ (.s$, .p, 1) = tab$
        ... or mid$ (.s$, .p, 1) = ",")
        .p = .p + 1
    endwhile
    if .p > .len
        .found = 0
        .quoted = 0
        .value$ = ""
        .nextPos = .p
    else
        .c$ = mid$ (.s$, .p, 1)
        if .c$ = """"
            .p = .p + 1
            .value$ = ""
            .closed = 0
            while .closed = 0 and .p <= .len
                .ch$ = mid$ (.s$, .p, 1)
                if .ch$ = """" and .p < .len and mid$ (.s$, .p + 1, 1) = """"
                    .value$ = .value$ + """"
                    .p = .p + 2
                elsif .ch$ = """"
                    .closed = 1
                    .p = .p + 1
                else
                    .value$ = .value$ + .ch$
                    .p = .p + 1
                endif
            endwhile
            .found = 1
            .quoted = 1
        else
            .value$ = ""
            while .p <= .len and mid$ (.s$, .p, 1) <> " "
                ... and mid$ (.s$, .p, 1) <> tab$ and mid$ (.s$, .p, 1) <> ","
                .value$ = .value$ + mid$ (.s$, .p, 1)
                .p = .p + 1
            endwhile
            .found = 1
            .quoted = 0
        endif
        .nextPos = .p
        while length (.value$) > 0
            ... and (left$ (.value$, 1) = " " or left$ (.value$, 1) = tab$)
            .value$ = right$ (.value$, length (.value$) - 1)
        endwhile
        while length (.value$) > 0
            ... and (right$ (.value$, 1) = " " or right$ (.value$, 1) = tab$)
            .value$ = left$ (.value$, length (.value$) - 1)
        endwhile
    endif
endproc

# ----------------------------------------------------------------------------
# Item 5. Reads up to .wanted argument tokens from .s$, which is the tail of
# a registration line right after the literal "Add menu/action command" --
# still carrying its ":" (modern) or "..." (legacy) marker, stripped here
# before tokenizing with emlManagerRptNextToken. .n is the number actually
# found (< .wanted on a malformed/short line).
procedure emlManagerRptTokens: .s$, .wanted
    .rest$ = .s$
    if startsWith (.rest$, ":")
        .rest$ = right$ (.rest$, length (.rest$) - 1)
    elsif startsWith (.rest$, "...")
        .rest$ = right$ (.rest$, length (.rest$) - 3)
    endif
    .value$# = empty$# (.wanted)
    .quoted# = zero# (.wanted)
    .n = 0
    .pos = 1
    .more = 1
    while .n < .wanted and .more = 1
        @emlManagerRptNextToken: .rest$, .pos
        if emlManagerRptNextToken.found = 0
            .more = 0
        else
            .n = .n + 1
            .value$# [.n] = emlManagerRptNextToken.value$
            .quoted# [.n] = emlManagerRptNextToken.quoted
            .pos = emlManagerRptNextToken.nextPos
        endif
    endwhile
endproc

# ----------------------------------------------------------------------------
# Item 5, rule 3. "a "/"an " for a class name, amended: "an" before a class
# starting with A, E, I, O, or U.
procedure emlManagerRptArticle: .class$
    .article$ = "a "
    if length (.class$) > 0
        ... and index (emlManager_rptVowels$, left$ (.class$, 1)) > 0
        .article$ = "an "
    endif
endproc

# ----------------------------------------------------------------------------
# Item 5, rule 3. The "<sel>" clause: each non-empty class, in order, as
# "a/an <class>" (n = 0 or 1) or "<n> <class> objects" (n >= 2), joined with
# " and ".
procedure emlManagerRptSelPhrase: .c1$, .n1, .c2$, .n2, .c3$, .n3
    .classes$# = { .c1$, .c2$, .c3$ }
    .counts# = { .n1, .n2, .n3 }
    .sel$ = ""
    for .i from 1 to 3
        .cls$ = .classes$# [.i]
        if .cls$ <> ""
            .cnt = .counts# [.i]
            if .cnt = 0 or .cnt = 1
                @emlManagerRptArticle: .cls$
                .phrase$ = emlManagerRptArticle.article$ + .cls$
            else
                .phrase$ = string$ (.cnt) + " " + .cls$ + " objects"
            endif
            if .sel$ = ""
                .sel$ = .phrase$
            else
                .sel$ = .sel$ + " and " + .phrase$
            endif
        endif
    endfor
endproc

# ----------------------------------------------------------------------------
# Item 5, rules 2-4. Parses one already-joined logical line (a full
# statement, continuation lines already concatenated). .depthTitle$#/
# .depthKnown# is the per-depth title stack in progress (index = depth + 1);
# a menu command with a literal title updates its own depth's entry so a
# later, deeper command can look up its parent. Output: .isReg, .kind$
# ("menu" | "action" | "computed"), .text$ (empty for "computed"), and the
# (possibly updated) .depthTitle$#/.depthKnown# to copy back into the caller.
procedure emlManagerRptProcessLogicalLine: .line$, .depthTitle$#, .depthKnown#, .maxDepth
    .isReg = 0
    .kind$ = ""
    .text$ = ""
    if startsWith (.line$, emlManager_rptCmdMenu$)
        .rest$ = right$ (.line$, length (.line$) - length (emlManager_rptCmdMenu$))
        # AMENDED rule 1: the keyword alone is not enough -- the modern ":"
        # or the legacy "..." must follow IMMEDIATELY, or this is not a
        # registration at all (e.g. "Add menu commands: ..." is prose).
        if startsWith (.rest$, ":") or startsWith (.rest$, "...")
            @emlManagerRptTokens: .rest$, 6
            if emlManagerRptTokens.n = 6
                .isReg = 1
                .windowQuoted = emlManagerRptTokens.quoted# [1]
                .windowVal$ = emlManagerRptTokens.value$# [1]
                .menuQuoted = emlManagerRptTokens.quoted# [2]
                .menuVal$ = emlManagerRptTokens.value$# [2]
                .titleQuoted = emlManagerRptTokens.quoted# [3]
                .titleVal$ = emlManagerRptTokens.value$# [3]
                .depthVal = round (number (emlManagerRptTokens.value$# [5]))
                # AMENDED rule 4: window and menu count too -- a variable
                # name must never leak into the English, not just the title.
                if .titleQuoted = 0 or .windowQuoted = 0 or .menuQuoted = 0
                    .kind$ = "computed"
                else
                    .kind$ = "menu"
                    .text$ = "Adds """ + .titleVal$ + """ to the " + .menuVal$
                        ... + " menu in the " + .windowVal$ + " window"
                    .haveParent = 0
                    if .depthVal > 0 and .depthVal <= .maxDepth
                        if .depthKnown# [.depthVal] = 1
                            .haveParent = 1
                        endif
                    endif
                    if .haveParent = 1
                        .text$ = .text$ + ", under """
                            ... + .depthTitle$# [.depthVal] + """."
                    else
                        .text$ = .text$ + "."
                    endif
                    if .depthVal >= 0 and .depthVal <= .maxDepth
                        .depthTitle$# [.depthVal + 1] = .titleVal$
                        .depthKnown# [.depthVal + 1] = 1
                    endif
                endif
            endif
        endif
    elsif startsWith (.line$, emlManager_rptCmdAction$)
        .rest$ = right$ (.line$, length (.line$) - length (emlManager_rptCmdAction$))
        # AMENDED rule 1: same immediate-delimiter requirement as menu commands.
        if startsWith (.rest$, ":") or startsWith (.rest$, "...")
            @emlManagerRptTokens: .rest$, 10
            if emlManagerRptTokens.n = 10
                .isReg = 1
                .c1$ = emlManagerRptTokens.value$# [1]
                .n1 = round (number (emlManagerRptTokens.value$# [2]))
                .c2$ = emlManagerRptTokens.value$# [3]
                .n2 = round (number (emlManagerRptTokens.value$# [4]))
                .c3$ = emlManagerRptTokens.value$# [5]
                .n3 = round (number (emlManagerRptTokens.value$# [6]))
                .titleQuoted = emlManagerRptTokens.quoted# [7]
                .titleVal$ = emlManagerRptTokens.value$# [7]
                if .titleQuoted = 0
                    .kind$ = "computed"
                else
                    .kind$ = "action"
                    @emlManagerRptSelPhrase: .c1$, .n1, .c2$, .n2, .c3$, .n3
                    .text$ = "Adds a """ + .titleVal$
                        ... + """ button that appears when you select "
                        ... + emlManagerRptSelPhrase.sel$ + "."
                endif
            endif
        endif
    endif
endproc

# ----------------------------------------------------------------------------
# Item 5. Parses one installed plugin's setup.praat -- the only file Praat
# reads to register commands -- into a report of what it adds (rules 1-6 of
# the installed-command-report spec). Continuation lines ("..." at the start
# of a line) are joined into the logical line they continue before parsing,
# matching real Praat script syntax (regression fixture: AERoPlot). Reads
# only the named file; anything it includes or runs is not followed.
# Input: .path$ (absolute path to a setup.praat, or one that does not exist
# -- treated the same as an empty one, rule 5). Output: .n result rows in
# parallel .kind$# ("menu" | "action" | "computed") and .text$# (the
# finished, unwrapped English line -- the caller wraps it for display).
procedure emlManagerParseSetupCommands: .path$
    if fileReadable (.path$)
        .rawLines$# = readLinesFromFile$# (.path$)
    else
        .rawLines$# = empty$# (0)
    endif
    .nRaw = size (.rawLines$#)
    .cap = .nRaw + 2
    .kind$# = empty$# (.cap)
    .text$# = empty$# (.cap)
    .n = 0
    .computedCount = 0

    .maxDepth = 32
    .depthTitle$# = empty$# (.maxDepth + 1)
    .depthKnown# = zero# (.maxDepth + 1)

    .logical$ = ""
    for .j from 1 to .nRaw
        .ln$ = .rawLines$# [.j]
        while length (.ln$) > 0 and (left$ (.ln$, 1) = " " or left$ (.ln$, 1) = tab$)
            .ln$ = right$ (.ln$, length (.ln$) - 1)
        endwhile
        if startsWith (.ln$, "...")
            .logical$ = .logical$ + " " + right$ (.ln$, length (.ln$) - 3)
        else
            if .logical$ <> ""
                @emlManagerRptProcessLogicalLine: .logical$, .depthTitle$#, .depthKnown#, .maxDepth
                .depthTitle$# = emlManagerRptProcessLogicalLine.depthTitle$#
                .depthKnown# = emlManagerRptProcessLogicalLine.depthKnown#
                if emlManagerRptProcessLogicalLine.isReg = 1
                    .n = .n + 1
                    .kind$# [.n] = emlManagerRptProcessLogicalLine.kind$
                    .text$# [.n] = emlManagerRptProcessLogicalLine.text$
                    if emlManagerRptProcessLogicalLine.kind$ = "computed"
                        .computedCount = .computedCount + 1
                    endif
                endif
            endif
            .logical$ = .ln$
        endif
    endfor
    if .logical$ <> ""
        @emlManagerRptProcessLogicalLine: .logical$, .depthTitle$#, .depthKnown#, .maxDepth
        if emlManagerRptProcessLogicalLine.isReg = 1
            .n = .n + 1
            .kind$# [.n] = emlManagerRptProcessLogicalLine.kind$
            .text$# [.n] = emlManagerRptProcessLogicalLine.text$
            if emlManagerRptProcessLogicalLine.kind$ = "computed"
                .computedCount = .computedCount + 1
            endif
        endif
    endif

    if .n = 0
        .n = 1
        .kind$# [1] = ""
        .text$# [1] = emlManager_rptNoCommands$
    elsif .computedCount > 0
        .n = .n + 1
        .kind$# [.n] = ""
        .text$# [.n] = emlManager_rptComputedPrefix$ + string$ (.computedCount)
            ... + emlManager_rptComputedSuffix$
    endif

    # Trim the over-allocated vectors down to exactly the rows produced.
    .trimmedKind$# = empty$# (.n)
    .trimmedText$# = empty$# (.n)
    for .ti from 1 to .n
        .trimmedKind$# [.ti] = .kind$# [.ti]
        .trimmedText$# [.ti] = .text$# [.ti]
    endfor
    .kind$# = .trimmedKind$#
    .text$# = .trimmedText$#
endproc

# ============================================================================
# Main sequence
# ============================================================================
# Skipped when the file is included by the test harness (which sets
# emlManager_harnessMode = 1 before the include) so the harness can drive the
# procedures directly without launching the installer.

if not variableExists ("emlManager_harnessMode")

    @emlManagerVersionOk
    if emlManagerVersionOk.ok = 0
        exitScript: emlManager_msgVersionFail$ + praatVersion$ + emlManager_msgVersionSuffix$
    endif

    # Dialog 1: what to install
    beginPause: emlManager_title$
        choice: "Source type", 1
            option: "A compressed file (.zip or .tar.gz)"
            option: "A folder that is already unpacked"
    clicked = endPause: "Quit", "Continue", 2, 0
    if clicked = 1
        exitScript: emlManager_msgCancelled$
    endif

    prefsDir$ = preferencesDirectory$
    archiveDir$ = prefsDir$ + "/" + emlManager_archiveName$

    @emlManagerMakeStaging
    if emlManagerMakeStaging.ok = 0
        exitScript: emlManager_msgStagingFail$
    endif
    stagingPath$ = emlManagerMakeStaging.path$

    # --- Source acquisition ---

    if source_type = 1
        sourcePath$ = chooseReadFile$: "Select the plugin archive"
        if sourcePath$ = ""
            @emlManagerCleanupStaging: stagingPath$
            exitScript: emlManager_msgCancelled$
        endif
        @emlManagerBaseName: sourcePath$
        sourceName$ = emlManagerBaseName.name$
        if endsWith (sourcePath$, emlManager_extZip$)
            format$ = "zip"
        elsif endsWith (sourcePath$, emlManager_extTarGz$)
            format$ = "targz"
        elsif endsWith (sourcePath$, emlManager_extTgz$)
            format$ = "targz"
        else
            @emlManagerCleanupStaging: stagingPath$
            exitScript: emlManager_msgBadExt$ + sourceName$
        endif
        unpackDest$ = stagingPath$ + "/unpacked"
        @emlManagerUnpack: format$, sourcePath$, unpackDest$
        if emlManagerUnpack.ok = 0
            failMsg$ = emlManagerUnpack.message$
            @emlManagerCleanupStaging: stagingPath$
            exitScript: failMsg$
        endif
        searchRoot$ = unpackDest$

    elsif source_type = 2
        sourcePath$ = chooseFolder$: "Select the plugin folder"
        if sourcePath$ = ""
            @emlManagerCleanupStaging: stagingPath$
            exitScript: emlManager_msgCancelled$
        endif
        @emlManagerBaseName: sourcePath$
        sourceName$ = emlManagerBaseName.name$
        searchRoot$ = sourcePath$
    endif

    # --- Search for plugin folders (true matches + near-misses) ---

    resultsFile$ = stagingPath$ + "/" + emlManager_resultsName$
    @emlManagerFindPluginDirs: searchRoot$, resultsFile$
    nFound = emlManagerFindPluginDirs.count

    if nFound = 0
        @emlManagerCleanupStaging: stagingPath$
        exitScript: emlManager_msgNoPluginFound$ + sourceName$ + "."
    endif

    foundPaths$# = readLinesFromFile$# (resultsFile$)
    nFound = size (foundPaths$#)

    # --- Per-candidate canonicalization (raw arrays over all found) ---

    rawLiteral$# = empty$# (nFound)
    rawPath$# = empty$# (nFound)
    rawProposal$# = empty$# (nFound)
    rawRenamed$# = empty$# (nFound)
    rawDesc$# = empty$# (nFound)
    rawSetup# = zero# (nFound)
    rawDefault# = zero# (nFound)
    rawKeep# = zero# (nFound)
    prefixLen = length (emlManager_pluginPrefix$)
    rootLen = length (searchRoot$)

    for iFound from 1 to nFound
        fPath$ = foundPaths$# [iFound]
        @emlManagerBaseName: fPath$
        litName$ = emlManagerBaseName.name$

        @emlManagerCheckSetupPresent: fPath$
        hasSetup = emlManagerCheckSetupPresent.hasSetup
        cmdCount = emlManagerCheckSetupPresent.commandCount

        # heuristic proposal (no content evidence), then the real content scan
        @emlManagerCanonicalName: litName$, hasSetup, "none"
        heurName$ = emlManagerCanonicalName.proposal$
        @emlManagerScanNameEvidence: fPath$, litName$, heurName$
        contentRef$ = emlManagerScanNameEvidence.contentRef$
        @emlManagerCanonicalName: litName$, hasSetup, contentRef$
        propName$ = emlManagerCanonicalName.proposal$
        rowKind$ = emlManagerCanonicalName.row$
        isNearMiss = emlManagerCanonicalName.isNearMiss
        confirmed = emlManagerCanonicalName.confirmed
        renamedFrom$ = emlManagerCanonicalName.renamedFrom$

        rawLiteral$# [iFound] = litName$
        rawPath$# [iFound] = fPath$
        rawProposal$# [iFound] = propName$
        rawRenamed$# [iFound] = renamedFrom$
        rawSetup# [iFound] = hasSetup

        if rowKind$ = "dropped"
            rawKeep# [iFound] = 0
        else
            rawKeep# [iFound] = 1
        endif

        # default checkbox state
        if isNearMiss = 1
            if rowKind$ = "row"
                rawDefault# [iFound] = 1
            else
                rawDefault# [iFound] = 0
            endif
        else
            rawDefault# [iFound] = hasSetup
        endif

        # relative path from search root
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

        # command-count annotation
        annotCmd$ = ""
        if hasSetup = 1
            if cmdCount > 0
                annotCmd$ = "adds " + string$ (cmdCount) + " command"
                if cmdCount > 1
                    annotCmd$ = annotCmd$ + "s"
                endif
            else
                annotCmd$ = emlManager_annotNoCommands$
            endif
        else
            annotCmd$ = emlManager_annotNoSetup$
        endif

        # sec. 5 name annotation
        annot5$ = ""
        if contentRef$ = "literal"
            annot5$ = emlManager_annotKeepsName$
        elsif isNearMiss = 1 and rowKind$ = "row_unchecked"
            annot5$ = emlManager_annotGuessed$ + litName$
        else
            if renamedFrom$ <> ""
                annot5$ = emlManager_annotRenamedFrom$ + litName$
            endif
            if confirmed = 1
                if annot5$ <> ""
                    annot5$ = annot5$ + "; "
                endif
                annot5$ = annot5$ + emlManager_annotConfirmed$
            endif
        endif

        # already-installed annotation (checked against the proposed name),
        # version-aware per item 3; overrides this row's default checkbox
        # state when (and only when) a collision is found.
        annotInst$ = ""
        if folderExists (prefsDir$ + "/" + propName$)
            @emlManagerInstalledAnnotation: fPath$, prefsDir$ + "/" + propName$,
                ... stagingPath$
            annotInst$ = emlManagerInstalledAnnotation.annot$
            rawDefault# [iFound] = emlManagerInstalledAnnotation.checked
        endif

        # display name from the PROPOSED name's suffix
        if length (propName$) > prefixLen
            suffix$ = right$ (propName$, length (propName$) - prefixLen)
        else
            suffix$ = propName$
        endif
        displayName$ = replace$ (suffix$, "_", " ", 0)

        # assemble description: display (annotCmd[; annot5][; annotInst]) -- at rel
        annotAll$ = annotCmd$
        if annot5$ <> ""
            annotAll$ = annotAll$ + "; " + annot5$
        endif
        if annotInst$ <> ""
            annotAll$ = annotAll$ + "; " + annotInst$
        endif
        rawDesc$# [iFound] = displayName$ + " (" + annotAll$
            ... + ") -- at " + relPath$
    endfor

    # --- sec. 6 ancestor collapse: drop an ancestor whose proposal equals a
    #     descendant's proposal (double-zip wrapper). Keep the innermost. ---

    for iA from 1 to nFound
        if rawKeep# [iA] = 1
            for iB from 1 to nFound
                if iB <> iA and rawKeep# [iB] = 1
                    if rawProposal$# [iA] = rawProposal$# [iB]
                        if startsWith (rawPath$# [iB], rawPath$# [iA] + "/")
                            rawKeep# [iA] = 0
                        endif
                    endif
                endif
            endfor
        endif
    endfor

    # --- Compact kept candidates ---

    nKeep = 0
    for iFound from 1 to nFound
        nKeep = nKeep + rawKeep# [iFound]
    endfor
    if nKeep = 0
        @emlManagerCleanupStaging: stagingPath$
        exitScript: emlManager_msgNoInstallable$ + sourceName$ + "."
    endif

    literal$# = empty$# (nKeep)
    path$# = empty$# (nKeep)
    proposal$# = empty$# (nKeep)
    renamed$# = empty$# (nKeep)
    descLines$# = empty$# (nKeep)
    setupFlags# = zero# (nKeep)
    defaultFlags# = zero# (nKeep)
    boolLabels$# = empty$# (nKeep)
    derivedNames$# = empty$# (nKeep)

    kRow = 0
    for iFound from 1 to nFound
        if rawKeep# [iFound] = 1
            kRow = kRow + 1
            literal$# [kRow] = rawLiteral$# [iFound]
            path$# [kRow] = rawPath$# [iFound]
            proposal$# [kRow] = rawProposal$# [iFound]
            renamed$# [kRow] = rawRenamed$# [iFound]
            descLines$# [kRow] = rawDesc$# [iFound]
            setupFlags# [kRow] = rawSetup# [iFound]
            defaultFlags# [kRow] = rawDefault# [iFound]
            @emlManagerDeriveLabel: proposal$# [kRow]
            boolLabels$# [kRow] = emlManagerDeriveLabel.label$
            derivedNames$# [kRow] = emlManagerDeriveLabel.derived$
        endif
    endfor

    # --- Pre-dialog collision check (on PROPOSED names) ---

    for iA from 1 to nKeep
        for iB from iA + 1 to nKeep
            if derivedNames$# [iA] = derivedNames$# [iB]
                @emlManagerCleanupStaging: stagingPath$
                exitScript: emlManager_msgCollision$
                    ... + proposal$# [iA] + " and "
                    ... + proposal$# [iB]
                    ... + emlManager_msgCollisionSuffix$
            endif
        endfor
    endfor

    # --- Selection dialog (paginated). Final page carries the literal toggle. ---

    nPages = ceiling (nKeep / emlManager_pageSize)

    for iPage from 1 to nPages
        pageStart = (iPage - 1) * emlManager_pageSize + 1
        pageEnd = min (iPage * emlManager_pageSize, nKeep)

        if nPages = 1
            pageTitle$ = emlManager_selTitle$
        else
            pageTitle$ = emlManager_selTitle$ + " (page "
                ... + string$ (iPage) + " of " + string$ (nPages) + ")"
        endif

        beginPause: pageTitle$
            for iShow from pageStart to pageEnd
                # Item 4: pre-wrap at word boundaries into its own comment
                # widgets, so a long description never renders under the
                # following checkbox.
                @emlManagerWrapText: descLines$# [iShow], emlManager_wrapWidth
                for iWrapLine from 1 to size (emlManagerWrapText.lines$#)
                    comment: emlManagerWrapText.lines$# [iWrapLine]
                endfor
                boolean: boolLabels$# [iShow], defaultFlags# [iShow]
            endfor
            if iPage = nPages
                comment: ""
                boolean: emlManager_useLiteralLabel$, 0
            endif

        if iPage < nPages
            clicked = endPause: "Quit", "Next", 2, 0
        else
            clicked = endPause: "Quit", "Install selected", 2, 0
        endif

        if clicked = 1
            @emlManagerCleanupStaging: stagingPath$
            exitScript: emlManager_msgCancelled$
        endif
    endfor

    useLiteral = use_folder_names_exactly_as_found

    # Read row selections (boolean variables persist across pages)
    @emlManagerReadSelections: derivedNames$#, nKeep
    selFlags# = emlManagerReadSelections.selected#

    nSelected = 0
    for iCheck from 1 to nKeep
        nSelected = nSelected + selFlags# [iCheck]
    endfor
    if nSelected = 0
        @emlManagerCleanupStaging: stagingPath$
        exitScript: emlManager_msgNoneSelected$
    endif

    # --- Resolve install names (sec. 7 literal toggle) ---

    installName$# = empty$# (nKeep)
    for iRow from 1 to nKeep
        if useLiteral = 1
            installName$# [iRow] = literal$# [iRow]
        else
            installName$# [iRow] = proposal$# [iRow]
        endif
    endfor

    # Literal-mode collision re-check among SELECTED rows
    if useLiteral = 1
        for iA from 1 to nKeep
            if selFlags# [iA] = 1
                for iB from iA + 1 to nKeep
                    if selFlags# [iB] = 1
                        if installName$# [iA] = installName$# [iB]
                            @emlManagerCleanupStaging: stagingPath$
                            exitScript: emlManager_msgCollisionLiteral$
                                ... + installName$# [iA]
                                ... + emlManager_msgCollisionSuffix$
                        endif
                    endif
                endfor
            endif
        endfor
    endif

    # --- Install loop ---

    summaryLines$# = empty$# (nSelected)
    # Item 5: parallel to summaryLines$# -- which rows get an installed-
    # command report (only actual successful installs with a setup.praat)
    # and where to read it from.
    reportShow# = zero# (nSelected)
    reportFolder$# = empty$# (nSelected)
    reportPath$# = empty$# (nSelected)
    summaryIdx = 0
    createFolder: archiveDir$

    for iInst from 1 to nKeep
        if selFlags# [iInst] = 1
            instName$ = installName$# [iInst]
            litName$ = literal$# [iInst]
            pPath$ = path$# [iInst]
            hadSetup = setupFlags# [iInst]

            wasReplaced = 0
            archiveOk = 1
            if folderExists (prefsDir$ + "/" + instName$)
                @emlManagerArchiveExisting: instName$, prefsDir$, archiveDir$
                if emlManagerArchiveExisting.ok = 1
                    wasReplaced = 1
                else
                    archiveOk = 0
                    summaryIdx = summaryIdx + 1
                    summaryLines$# [summaryIdx] = emlManagerArchiveExisting.message$
                endif
            endif

            if archiveOk = 1
                @emlManagerPlaceFolder: pPath$, instName$, prefsDir$
                @emlManagerVerify: instName$, prefsDir$, hadSetup
                summaryIdx = summaryIdx + 1
                if emlManagerVerify.ok = 0
                    summaryLines$# [summaryIdx] = "FAILED: "
                        ... + instName$ + " -- " + emlManagerVerify.message$
                else
                    line$ = instName$
                    if instName$ <> litName$
                        line$ = line$ + " (" + emlManager_annotRenamedFrom$ + litName$ + ")"
                    endif
                    if wasReplaced = 1
                        line$ = line$ + emlManager_msgArchiveNote$
                    endif
                    summaryLines$# [summaryIdx] = line$
                    reportShow# [summaryIdx] = 1
                    reportFolder$# [summaryIdx] = instName$
                    reportPath$# [summaryIdx] = prefsDir$ + "/" + instName$
                        ... + "/" + emlManager_setupFile$
                endif
            endif
        endif
    endfor

    # --- Cleanup and summary ---

    @emlManagerCleanupStaging: stagingPath$

    # Item 5: one pass to size the flattened comment-line list (each
    # installed plugin's existing summary line, then -- when it was actually
    # installed -- its "<folder> adds:" header and its wrapped report lines),
    # a second pass to fill it, then display it through the existing
    # pagination-at-12 machinery.
    totalLines = 0
    for iSummary from 1 to summaryIdx
        totalLines = totalLines + 1
        if reportShow# [iSummary] = 1
            totalLines = totalLines + 1
            @emlManagerParseSetupCommands: reportPath$# [iSummary]
            for iRep from 1 to emlManagerParseSetupCommands.n
                # AMENDED dialog integration: a computed row's text is empty
                # -- it is not rendered as a blank comment field; only its
                # tally line (which has real text) is.
                if emlManagerParseSetupCommands.text$# [iRep] <> ""
                    @emlManagerWrapText: emlManagerParseSetupCommands.text$# [iRep], emlManager_wrapWidth
                    totalLines = totalLines + size (emlManagerWrapText.lines$#)
                endif
            endfor
        endif
    endfor
    totalLines = totalLines + 2

    allLines$# = empty$# (totalLines)
    lineIdx = 0
    for iSummary from 1 to summaryIdx
        lineIdx = lineIdx + 1
        allLines$# [lineIdx] = summaryLines$# [iSummary]
        if reportShow# [iSummary] = 1
            lineIdx = lineIdx + 1
            allLines$# [lineIdx] = reportFolder$# [iSummary] + emlManager_rptHeaderSuffix$
            @emlManagerParseSetupCommands: reportPath$# [iSummary]
            for iRep from 1 to emlManagerParseSetupCommands.n
                if emlManagerParseSetupCommands.text$# [iRep] <> ""
                    @emlManagerWrapText: emlManagerParseSetupCommands.text$# [iRep], emlManager_wrapWidth
                    for iWrap from 1 to size (emlManagerWrapText.lines$#)
                        lineIdx = lineIdx + 1
                        allLines$# [lineIdx] = emlManagerWrapText.lines$# [iWrap]
                    endfor
                endif
            endfor
        endif
    endfor
    lineIdx = lineIdx + 1
    allLines$# [lineIdx] = ""
    lineIdx = lineIdx + 1
    allLines$# [lineIdx] = emlManager_msgRestart$

    nCompletePages = ceiling (totalLines / emlManager_pageSize)
    for iCPage from 1 to nCompletePages
        cPageStart = (iCPage - 1) * emlManager_pageSize + 1
        cPageEnd = min (iCPage * emlManager_pageSize, totalLines)

        if nCompletePages = 1
            cPageTitle$ = emlManager_titleComplete$
        else
            cPageTitle$ = emlManager_titleComplete$ + " (page "
                ... + string$ (iCPage) + " of " + string$ (nCompletePages) + ")"
        endif

        beginPause: cPageTitle$
            for iCShow from cPageStart to cPageEnd
                comment: allLines$# [iCShow]
            endfor
        if iCPage < nCompletePages
            endPause: emlManager_msgNext$, 1, 0
        else
            endPause: emlManager_msgOk$, 1, 0
        endif
    endfor

endif
