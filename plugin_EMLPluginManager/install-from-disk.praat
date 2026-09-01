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
# Date: 31 August 2026
# Version: 4.1
#
# 4.1 — Exit-button labels: buttons that stop the script now read "Quit"
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

# Characters that may appear in a plugin_ name reference (§5 content scan)
kNameChars$ = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"

kTitle$ = "Install Plugin from Disk"
kSelTitle$ = "Select plugins to install"
kUseLiteralLabel$ = "Use folder names exactly as found"
kMsgCancelled$ = "Installation cancelled."
kMsgVersionFail$ = "This script requires Praat "
    ... + kFloorVersionLabel$
    ... + " or newer. You have "
kMsgVersionSuffix$ = ". Please update Praat from praat.org and try again."
kMsgNoPluginFound$ = "No plugin folder (a folder whose name starts with "
    ... + kPluginPrefix$ + ") was found inside "
kMsgNoInstallable$ = "No installable plugin folder was found inside "
kMsgBadExt$ = "Only .zip, .tar.gz, and .tgz files are accepted. Got: "
kMsgUnpackFail$ = "Unpacking failed. "
kMsgLinuxUnzipHint$ = "The unzip tool may not be installed on this system."
    ... + " The file that could not be unpacked: "
kMsgNoneSelected$ = "No plugins selected."
kMsgCollision$ = "Two found plugins produce the same internal name: "
kMsgCollisionSuffix$ = ". Install them one at a time via the folder option."
kMsgCollisionLiteral$ = "Two selected folders share the same literal name: "
kMsgVerifyFail$ = "Verification failed for "
kMsgArchiveFail$ = "FAILED: could not archive existing "
kMsgRestart$ = "Restart Praat to activate."
kMsgArchiveNote$ = " (previous version kept in the archive folder)"
kMsgStagingFail$ = "Failed to create staging folder."

kAnnotNoCommands$ = "registers no commands"
kAnnotNoSetup$ = "no setup.praat -- not a functioning plugin as-is"
kAnnotInstalled$ = "already installed -- replacing keeps the current "
    ... + "version in the archive folder"
kAnnotConfirmed$ = "name confirmed by the plugin's own scripts"
kAnnotKeepsName$ = "keeps its folder name -- the plugin's scripts reference it"
kAnnotRenamedFrom$ = "renamed from "
kAnnotGuessed$ = "name guessed from folder "

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
# overflow. Collects all plugin_ folders AND plugin_ near-misses (folders whose
# name CONTAINS plugin_ past the first character, per §3), excludes __MACOSX
# subtrees. Near-miss gating and dropping happens later, per-candidate.
# Input: .root$ (search root), .resultsFile$ (write found paths here)
# Output: .count (number of candidate folders found)
procedure emlpmL_findPluginDirs: .root$, .resultsFile$
    .count = 0
    writeFile: .resultsFile$, ""
    @emlpmL_baseName: .root$
    .rootName$ = emlpmL_baseName.name$
    @emlpmL_isCandidateName: .rootName$
    if emlpmL_isCandidateName.yes = 1
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
                @emlpmL_isCandidateName: .dirName$
                if emlpmL_isCandidateName.yes = 1
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
# plugin_ (Praat's own activation rule is the authority, §3).
procedure emlpmL_isCandidateName: .name$
    .yes = 0
    if startsWith (.name$, kPluginPrefix$)
        .yes = 1
    elsif index (.name$, kPluginPrefix$) > 1
        .yes = 1
    endif
endproc

# ----------------------------------------------------------------------------
# §4 junk-token test. A trailing token is junk if (case-insensitively) it is a
# branch word, a 7-40 char hex hash, a version (optional v, up to three
# dot-separated digit groups, optional single trailing letter), or a copy
# artifact (copy / copyN / (N)). Regex dialect + all §9 tokens sandbox-verified
# 31 Aug 2026 (Praat 7.0.02).
procedure emlpmL_isJunkToken: .tok$
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
# One §4 stripping pass. Finds the LEFTMOST separator (-, _, ., space) whose
# ENTIRE tail is a single junk token (this yields the longest trailing token,
# so a dotted version like 1.2.0 is taken whole, not one dot-group at a time).
# HARD GUARD: never strip down to kPluginPrefix$ or shorter; on hitting the
# guard, stop -- do not fall through to a rightmost separator.
# Output: .result$ (possibly stripped), .stripped (0/1)
procedure emlpmL_stripOnce: .name$
    .stripped = 0
    .result$ = .name$
    .prefixLen = length (kPluginPrefix$)
    .n = length (.name$)
    .p = 1
    .done = 0
    while .done = 0 and .p <= .n
        .ch$ = mid$ (.name$, .p, 1)
        .isSep = (.ch$ = "-") or (.ch$ = "_") or (.ch$ = ".") or (.ch$ = " ")
        if .isSep = 1
            .tail$ = mid$ (.name$, .p + 1, .n - .p)
            if .tail$ <> ""
                @emlpmL_isJunkToken: .tail$
                if emlpmL_isJunkToken.yes = 1
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
# §3-§5 per-candidate canonicalization. PURE (no I/O) -- the harness drives the
# whole §9 normative table through this procedure.
# Input:
#   .literal$    the folder name as found
#   .hasSetup    1 if the folder has a top-level setup.praat, else 0
#   .contentRef$ one of: none | literal | proposal | literal_external
#                | proposal_external   (from emlpmL_scanNameEvidence at runtime;
#                fed directly from the TSV in the harness)
# Output:
#   .proposal$    the install-name proposal
#   .row$         disposition: row | row_unchecked | dropped
#   .isNearMiss   0/1
#   .confirmed    1 if content evidence confirmed the proposal
#   .renamedFrom$ the literal name when proposal <> literal, else ""
procedure emlpmL_canonicalName: .literal$, .hasSetup, .contentRef$
    .prefixLen = length (kPluginPrefix$)
    # --- match type + candidate stem (§3) ---
    if startsWith (.literal$, kPluginPrefix$)
        .isNearMiss = 0
        .stem$ = .literal$
    else
        .isNearMiss = 1
        .firstIdx = index (.literal$, kPluginPrefix$)
        .stem$ = mid$ (.literal$, .firstIdx, length (.literal$) - .firstIdx + 1)
    endif
    # --- §4 suffix stripping, max 3 iterations ---
    .work$ = .stem$
    .iter = 0
    .changed = 1
    while .changed = 1 and .iter < 3
        @emlpmL_stripOnce: .work$
        if emlpmL_stripOnce.stripped = 1
            .work$ = emlpmL_stripOnce.result$
            .changed = 1
            .iter = .iter + 1
        else
            .changed = 0
        endif
    endwhile
    .heuristic$ = .work$
    # --- §5 content override ---
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
    # --- disposition (§5 near-miss gating) ---
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
# §5 content-evidence scan. Reads every *.praat file in the folder (recursive,
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
procedure emlpmL_scanNameEvidence: .folderPath$, .literal$, .proposal$
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
            @emlpmL_scanOneFile: .cur$ + "/" + .files$# [.fi],
                ... .folderPath$, .literal$, .proposal$
            .cProp = .cProp + emlpmL_scanOneFile.cProp
            .cLit = .cLit + emlpmL_scanOneFile.cLit
            .ncProp = .ncProp + emlpmL_scanOneFile.ncProp
            .ncLit = .ncLit + emlpmL_scanOneFile.ncLit
        endfor
        .subs$# = folderNames$# (.cur$ + "/*")
        for .si from 1 to size (.subs$#)
            if .subs$# [.si] <> kMacosxExclude$
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
procedure emlpmL_scanOneFile: .fpath$, .folderPath$, .literal$, .proposal$
    .cProp = 0
    .cLit = 0
    .ncProp = 0
    .ncLit = 0
    if fileReadable (.fpath$)
        .lines$# = readLinesFromFile$# (.fpath$)
        for .li from 1 to size (.lines$#)
            @emlpmL_scanOneLine: .lines$# [.li],
                ... .folderPath$, .literal$, .proposal$
            .cProp = .cProp + emlpmL_scanOneLine.cProp
            .cLit = .cLit + emlpmL_scanOneLine.cLit
            .ncProp = .ncProp + emlpmL_scanOneLine.ncProp
            .ncLit = .ncLit + emlpmL_scanOneLine.ncLit
        endfor
    endif
endproc

# ----------------------------------------------------------------------------
procedure emlpmL_scanOneLine: .line$, .folderPath$, .literal$, .proposal$
    .cProp = 0
    .cLit = 0
    .ncProp = 0
    .ncLit = 0
    .n = length (.line$)
    .pos = 1
    while .pos <= .n
        .rem$ = mid$ (.line$, .pos, .n - .pos + 1)
        .rel = index (.rem$, kPluginPrefix$)
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
                if index (kNameChars$, .c$) > 0
                    .mlen = .mlen + 1
                    .k = .k + 1
                else
                    .walking = 0
                endif
            endwhile
            .match$ = mid$ (.line$, .mstart, .mlen)
            if .mlen > length (kPluginPrefix$)
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
# so emlpmL_readSelections reads the right variable back.
procedure emlpmL_deriveLabel: .name$
    .san$ = replace_regex$ (.name$, "[^A-Za-z0-9_]", " ", 0)
    while startsWith (.san$, " ")
        .san$ = right$ (.san$, length (.san$) - 1)
    endwhile
    while endsWith (.san$, " ")
        .san$ = left$ (.san$, length (.san$) - 1)
    endwhile
    .label$ = .san$
    .derived$ = replace$ (.san$, " ", "_", 0)
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
# Input: .derivedNames$# (the variable name for each row), .nRows
# Output: .selected# (vector of 0/1)
procedure emlpmL_readSelections: .derivedNames$#, .nRows
    .selected# = zero# (.nRows)
    for .i from 1 to .nRows
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
# Skipped when the file is included by the test harness (which sets
# emlpm_harnessMode = 1 before the include) so the harness can drive the
# procedures directly without launching the installer.

if not variableExists ("emlpm_harnessMode")

    @emlpmL_versionOk
    if emlpmL_versionOk.ok = 0
        exitScript: kMsgVersionFail$ + praatVersion$ + kMsgVersionSuffix$
    endif

    # Dialog 1: what to install
    beginPause: kTitle$
        choice: "Source type", 1
            option: "A compressed file (.zip or .tar.gz)"
            option: "A folder that is already unpacked"
    clicked = endPause: "Quit", "Continue", 2, 0
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

    # --- Search for plugin folders (true matches + near-misses) ---

    resultsFile$ = stagingPath$ + "/" + kResultsName$
    @emlpmL_findPluginDirs: searchRoot$, resultsFile$
    nFound = emlpmL_findPluginDirs.count

    if nFound = 0
        @emlpmL_cleanupStaging: stagingPath$
        exitScript: kMsgNoPluginFound$ + sourceName$ + "."
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
    prefixLen = length (kPluginPrefix$)
    rootLen = length (searchRoot$)

    for iFound from 1 to nFound
        fPath$ = foundPaths$# [iFound]
        @emlpmL_baseName: fPath$
        litName$ = emlpmL_baseName.name$

        @emlpmL_checkSetupPresent: fPath$
        hasSetup = emlpmL_checkSetupPresent.hasSetup
        cmdCount = emlpmL_checkSetupPresent.commandCount

        # heuristic proposal (no content evidence), then the real content scan
        @emlpmL_canonicalName: litName$, hasSetup, "none"
        heurName$ = emlpmL_canonicalName.proposal$
        @emlpmL_scanNameEvidence: fPath$, litName$, heurName$
        contentRef$ = emlpmL_scanNameEvidence.contentRef$
        @emlpmL_canonicalName: litName$, hasSetup, contentRef$
        propName$ = emlpmL_canonicalName.proposal$
        rowKind$ = emlpmL_canonicalName.row$
        isNearMiss = emlpmL_canonicalName.isNearMiss
        confirmed = emlpmL_canonicalName.confirmed
        renamedFrom$ = emlpmL_canonicalName.renamedFrom$

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
                annotCmd$ = kAnnotNoCommands$
            endif
        else
            annotCmd$ = kAnnotNoSetup$
        endif

        # §5 name annotation
        annot5$ = ""
        if contentRef$ = "literal"
            annot5$ = kAnnotKeepsName$
        elsif isNearMiss = 1 and rowKind$ = "row_unchecked"
            annot5$ = kAnnotGuessed$ + litName$
        else
            if renamedFrom$ <> ""
                annot5$ = kAnnotRenamedFrom$ + litName$
            endif
            if confirmed = 1
                if annot5$ <> ""
                    annot5$ = annot5$ + "; "
                endif
                annot5$ = annot5$ + kAnnotConfirmed$
            endif
        endif

        # already-installed annotation (checked against the proposed name)
        annotInst$ = ""
        if folderExists (prefsDir$ + "/" + propName$)
            annotInst$ = kAnnotInstalled$
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

    # --- §6 ancestor collapse: drop an ancestor whose proposal equals a
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
        @emlpmL_cleanupStaging: stagingPath$
        exitScript: kMsgNoInstallable$ + sourceName$ + "."
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
            @emlpmL_deriveLabel: proposal$# [kRow]
            boolLabels$# [kRow] = emlpmL_deriveLabel.label$
            derivedNames$# [kRow] = emlpmL_deriveLabel.derived$
        endif
    endfor

    # --- Pre-dialog collision check (on PROPOSED names) ---

    for iA from 1 to nKeep
        for iB from iA + 1 to nKeep
            if derivedNames$# [iA] = derivedNames$# [iB]
                @emlpmL_cleanupStaging: stagingPath$
                exitScript: kMsgCollision$
                    ... + proposal$# [iA] + " and "
                    ... + proposal$# [iB]
                    ... + kMsgCollisionSuffix$
            endif
        endfor
    endfor

    # --- Selection dialog (paginated). Final page carries the literal toggle. ---

    nPages = ceiling (nKeep / kPageSize)

    for iPage from 1 to nPages
        pageStart = (iPage - 1) * kPageSize + 1
        pageEnd = min (iPage * kPageSize, nKeep)

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
            if iPage = nPages
                comment: ""
                boolean: kUseLiteralLabel$, 0
            endif

        if iPage < nPages
            clicked = endPause: "Quit", "Next", 2, 0
        else
            clicked = endPause: "Quit", "Install selected", 2, 0
        endif

        if clicked = 1
            @emlpmL_cleanupStaging: stagingPath$
            exitScript: kMsgCancelled$
        endif
    endfor

    useLiteral = use_folder_names_exactly_as_found

    # Read row selections (boolean variables persist across pages)
    @emlpmL_readSelections: derivedNames$#, nKeep
    selFlags# = emlpmL_readSelections.selected#

    nSelected = 0
    for iCheck from 1 to nKeep
        nSelected = nSelected + selFlags# [iCheck]
    endfor
    if nSelected = 0
        @emlpmL_cleanupStaging: stagingPath$
        exitScript: kMsgNoneSelected$
    endif

    # --- Resolve install names (§7 literal toggle) ---

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
                            @emlpmL_cleanupStaging: stagingPath$
                            exitScript: kMsgCollisionLiteral$
                                ... + installName$# [iA]
                                ... + kMsgCollisionSuffix$
                        endif
                    endif
                endfor
            endif
        endfor
    endif

    # --- Install loop ---

    summaryLines$# = empty$# (nSelected)
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
                @emlpmL_archiveExisting: instName$, prefsDir$, archiveDir$
                if emlpmL_archiveExisting.ok = 1
                    wasReplaced = 1
                else
                    archiveOk = 0
                    summaryIdx = summaryIdx + 1
                    summaryLines$# [summaryIdx] = emlpmL_archiveExisting.message$
                endif
            endif

            if archiveOk = 1
                @emlpmL_placeFolder: pPath$, instName$, prefsDir$
                @emlpmL_verify: instName$, prefsDir$, hadSetup
                summaryIdx = summaryIdx + 1
                if emlpmL_verify.ok = 0
                    summaryLines$# [summaryIdx] = "FAILED: "
                        ... + instName$ + " -- " + emlpmL_verify.message$
                else
                    line$ = instName$
                    if instName$ <> litName$
                        line$ = line$ + " (" + kAnnotRenamedFrom$ + litName$ + ")"
                    endif
                    if wasReplaced = 1
                        line$ = line$ + kMsgArchiveNote$
                    endif
                    summaryLines$# [summaryIdx] = line$
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

endif
