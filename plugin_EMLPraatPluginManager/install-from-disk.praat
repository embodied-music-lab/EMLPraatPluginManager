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
# Date: 17 November 2026
# Version: 5.4
#
# 5.4 -- Version 0.7.3. Two folders whose names differ only in punctuation
#       (plugin_foo-bar and plugin_foo_bar) no longer share one checkbox: the
#       label canon now looks for collisions among the names Praat reads
#       back, not among the labels, so ticking one row selects only that
#       row. The annotation words (itself, leftover) always show in full.
#       The installed-command report counts setup.praat lines that start
#       with nocheck, nowarn, noprogress, demo, or asynchronous (one space
#       after each keyword, as Praat requires), and legacy lines that leave
#       off the script argument. The checklist's "adds N commands" now comes
#       from the same parser as the report. A line whose title starts with a
#       hyphen ("--", quoted or not) is a separator, and a line with an
#       empty title is a spacer: neither is counted or listed. A registration
#       with no script is not a command either: a menu one is listed as a
#       submenu ("Adds a submenu ...") and not counted, and an action one
#       (a heading label Praat does not let you click) is left out
#       (AERoPlot counts 7 commands and lists 1 submenu). On the install
#       checklist the "use folder names exactly as found" switch now always
#       shares a page with at least one plugin. Every
#       paged dialog (the install checklist, the completion dialog, and the
#       removal dialogs) now pages by the measured on-screen height of its
#       rows instead of a count of lines, so the Next, OK and action buttons
#       stay on a 900-pixel-tall screen. The weights and the budget are in
#       emlManagerPageMetrics.
#       A page break never splits one command's wrapped lines and never
#       leaves a heading ("<plugin> adds:") or the summary line above it
#       alone at the bottom of a page. A word too long for the window
#       counts as the rows it wraps onto.
#
# 5.3 -- Version 0.7.1. Choosing a folder or archive with many plugins scans
#       much faster: folders with canonical names skip the content scan, and
#       files that never mention plugin_ are skipped.
#
# 5.2 -- AMENDED selection-label subsystem (sec. 2a of the UX round spec,
#       Ian's 1 Sep amendment: visible index prefixes on every row are a
#       waste of space). Labels are BARE by default -- emlManagerBuildLabels
#       caps and sanitizes every row's label first with no prefix, then
#       rebuilds only the rows whose bare labels collide, prefixing each
#       member of a colliding group with its listing-index (letter-initial,
#       unchanged from 5.1). One canon procedure now serves both selection
#       dialogs (install's checklist and remove's Dialog 1). The description
#       comment / Dialog-2 line carries the matching "n<i>." breadcrumb only
#       for a row a collision actually prefixed; a bare row's full name
#       needs no breadcrumb.
#
# 5.1 -- REVISED selection-label subsystem (sec. 2 of the UX round spec,
#       after the failed v0.6.1 drive): every selection-row label began
#       with an index prefix that was identity, never touched by shortening,
#       so the derived readback variable was unique by construction; the cap
#       (emlManager_boolLabelCap) is a hard invariant enforced by the
#       shortening helper itself, not by callers passing sane budgets; a
#       suffix is shortened, never dropped; the shortening marker is "___"
#       (survives the sanitizer) rather than "..." (stripped by it); and the
#       pre-dialog duplicate check compares real (uncapped) proposed names.
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

# Page budget (0.7.3, round 4): every paginated pause dialog pages by the
# RENDERED HEIGHT of what it shows, in pixels. The weights and the budget are
# stated once, in procedure emlManagerPageMetrics below; no other place holds
# a page size, a line weight, or a count of lines per page.

# UX round 2026-09-01 REVISED, sec. 2: a checkbox label longer than this is
# shortened with a middle marker (see emlManagerApplyLabelCap). The cap is a
# HARD INVARIANT -- every branch of the label builder below is structured so
# the result can never exceed it, index prefix included.
emlManager_boolLabelCap = 38
# Sanitizer-proof shortening marker: "." and "(" both get stripped to spaces
# by emlManagerDeriveLabel's sanitizer (sec. 2), which is why the old "..."
# never actually showed up in a checkbox -- digits and "_" survive, so three
# underscores do.
emlManager_labelMarker$ = "___"
# Sec. 2a AMENDED: a selection-row checkbox label begins with an index
# prefix ONLY when its bare, capped, sanitized label collides with another
# row's (emlManagerBuildLabels) -- digits and "_" survive the sanitizer,
# making a prefixed label -- and its derived readback variable -- unique by
# construction regardless of what the cap did to the rest. A row whose
# label stayed bare gets no prefix on its description comment / Dialog-2
# line either; a row a collision prefixed gets the same index there too, as
# "n<index>. " (emlManagerIndexDescPrefix; plain display text, not passed
# through the sanitizer, so the more readable trailing period is fine
# there).
# LEADING LETTER (measured, GUI drive): a Praat script variable name must
# start with a letter, and a pause-form boolean's real internal name is
# Praat's OWN derivation of its label text -- not something this plugin can
# override after the fact (a bare "<index>_ " prefix starts with a digit,
# which is not merely unconventional: reading such a widget back through
# indirect substitution is a parse error, "Unknown symbol", confirmed
# against a real pause-form boolean under Xvfb; prepending a guard letter
# to only OUR OWN copy of the derived name does not fix it either, since it
# still does not match whatever Praat itself called the widget --
# "Unknown variable", also confirmed). So the fixed leading letter goes on
# the identity prefix ITSELF, ahead of the index digits: every checkbox
# label this plugin ever builds starts with a letter, both the widget's
# real Praat-derived name and this file's own mirrored emlManagerDeriveLabel
# agree on it (confirmed against real pause-form booleans, single- and
# double-digit indices, values round-tripping correctly both ways).
emlManager_indexLabelLead$ = "n"
emlManager_indexLabelSep$ = "_ "
emlManager_indexDescSep$ = ". "
# Sec. 2c: when a suffix is present it is shortened (tail-preserving) to at
# most this many characters before the name gets whatever budget remains --
# the suffix is NEVER dropped, only ever shortened.
emlManager_labelSuffixCap = 16
# Sec. 2c: minimum tail characters preserved when middle-shortening -- 14 for
# a bare name (no suffix competing for budget), 8 for a name shortened
# alongside a surviving suffix, and 8 for the suffix's own shortening.
emlManager_labelTailMinBare = 14
emlManager_labelTailMinShared = 8

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

# SPEC_WRAPPER_SAFETY part 3: the path canon -- a dialog line names a file or
# folder but never prints a full filesystem path; every site that would have
# printed one instead appends this pointer sentence and routes the real path
# through emlManagerLogPath (below) into the Info window.
emlManager_msgSeePathInInfo$ = "The full path is printed in the Info window."
emlManager_logEventUnpackSource$ = "Could not unpack"

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

# UX round 2026-09-01, item 1: the completion-report line added when install
# placed a plugin over a ghost folder (a plugin_* folder left behind by an
# earlier removal, containing nothing Praat can see).
emlManager_msgGhostReused$ = "Reused a leftover folder from an earlier removal."

emlManager_annotConfirmed$ = "name confirmed by the plugin's own scripts"
emlManager_annotKeepsName$ = "keeps its folder name -- the plugin's scripts reference it"
emlManager_annotRenamedFrom$ = "renamed from "
emlManager_annotGuessed$ = "name guessed from folder "

# Item 5: installed-command report (emlManagerParseSetupCommands and its
# Installation-complete dialog integration -- see below).
emlManager_rptCmdMenu$ = "Add menu command"
# Praat's manual (Add to fixed menu..., Add to dynamic menu...): a title that
# starts with a hyphen ("-", "-- peaks --") draws a separator line. It is not
# a command, so the parser neither counts nor lists it.
emlManager_rptSeparatorPrefix$ = "-"
emlManager_rptCmdAction$ = "Add action command"
# Command modifiers Praat strips from the front of a script line before it
# runs the command (praat_executeCommand): nowarn, noprogress and nocheck
# are in the manual ("Scripting 6.8. Messages to the user"); demo and
# asynchronous are in the interpreter source. A registration line may start
# with any number of them, in any order.
emlManager_rptModifiers$# = { "nocheck", "nowarn", "noprogress", "demo", "asynchronous" }
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
# SPEC_WRAPPER_SAFETY part 3 canon: prints a full filesystem PATH to the Info
# window rather than into a dialog. NO clearinfo anywhere in the manager --
# this appends under whatever the user's Info window already holds.
procedure emlManagerLogPath: .event$, .path$
    appendInfoLine: "EML Plugin Manager -- " + .event$ + ":"
    appendInfoLine: .path$
    appendInfoLine: ""
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
# UX round 2026-09-01, item 1 (the installed-test canon). A plugin_* folder
# is installed if and only if it contains a top-level setup.praat -- Praat's
# own activation rule. A folder that exists but has no setup.praat (every
# file Praat's enumeration could see was already removed; only something
# Praat cannot enumerate, e.g. a macOS .DS_Store, is left) is a GHOST, not an
# installed plugin. ONE canon procedure; every site that asks "is a plugin
# already installed at this folder" routes through this.
procedure emlManagerIsInstalled: .folderPath$
    .installed = 0
    if fileReadable (.folderPath$ + "/" + emlManager_setupFile$)
        .installed = 1
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
# Item 1: the pre-dialog collision check on a proposed install name. A
# collision exists only when .destPath$ is an INSTALLED plugin (per
# emlManagerIsInstalled); a ghost folder at that path is fresh ground -- no
# annotation, no version comparison, .hasCollision stays 0 and the caller's
# default checkbox state is left untouched.
procedure emlManagerInstalledCollisionCheck: .fPath$, .destPath$, .scratchDir$
    .hasCollision = 0
    .annot$ = ""
    .checked = 0
    if folderExists (.destPath$)
        @emlManagerIsInstalled: .destPath$
        if emlManagerIsInstalled.installed = 1
            .hasCollision = 1
            @emlManagerInstalledAnnotation: .fPath$, .destPath$, .scratchDir$
            .annot$ = emlManagerInstalledAnnotation.annot$
            .checked = emlManagerInstalledAnnotation.checked
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
# Sec. 2 helper: middle-shortens .s$ to AT MOST .cap characters -- head,
# emlManager_labelMarker$, then a tail of up to .minTail characters. This is
# the one place the hard cap invariant is enforced, so it is written to be
# unconditionally safe rather than relying on callers to pass a sane .cap:
#   - .s$ already fits: returned unchanged (may be shorter than .cap).
#   - .cap has no room even for the marker: hard-truncated to .cap chars,
#     no marker (there is nowhere to put one).
#   - otherwise: head + marker + tail totals exactly .cap, tail shrinking
#     below .minTail (down to 0) before head is ever allowed to.
# Every call site below only ever needs the "totals exactly .cap" case, but
# the guard branches mean this procedure can never itself be the cause of an
# over-cap result, however small a .cap a future caller passes.
procedure emlManagerMiddleEllipsis: .s$, .cap, .minTail
    .safeCap = .cap
    if .safeCap < 0
        .safeCap = 0
    endif
    .markerLen = length (emlManager_labelMarker$)
    if length (.s$) <= .safeCap
        .result$ = .s$
    elsif .safeCap <= .markerLen
        .result$ = left$ (.s$, .safeCap)
    else
        .avail = .safeCap - .markerLen
        .tailLen = .minTail
        if .tailLen > .avail
            .tailLen = .avail
        endif
        if .tailLen < 0
            .tailLen = 0
        endif
        .headLen = .avail - .tailLen
        .result$ = left$ (.s$, .headLen) + emlManager_labelMarker$ + right$ (.s$, .tailLen)
    endif
endproc

# ----------------------------------------------------------------------------
# Sec. 2 (REVISED): the selection-row label builder. .prefix$ is the index
# prefix (emlManagerIndexPrefix.prefix$, e.g. "n12_ ") -- identity, ALWAYS
# kept whole, never touched by shortening. .name$ is the plugin/folder name;
# .suffix$ is an annotation appended after it (the manager suffix, the ghost
# suffix, or "" for a plain row).
#
# Deterministic budget (sec. 2c) -- the cap invariant holds in every branch:
#   - Everything fits as-is: .prefix$ + .name$ + .suffix$, untouched.
#   - No suffix: .name$ middle-shortens into cap - len(prefix), tail >= 14.
#   - Suffix present and the whole label does not fit: the suffix is
#     shortened tail-preserving to at most
#     emlManager_labelSuffixCap chars FIRST (never dropped, and whole
#     whenever it is that short, so "itself" and "leftover" always show),
#     then .name$ gets whatever budget is left (cap - prefix - shortened
#     suffix) and middle-shortens into THAT, tail >= 8. Since emlManagerMiddleEllipsis
#     itself never exceeds the cap it is given, and every budget here is
#     computed by subtraction from the true remaining room, the total can
#     never exceed .cap regardless of name/suffix length (the measured
#     35-37-char-name-plus-long-suffix overflow is structurally impossible
#     now: the suffix's own budget no longer depends on the name's length).
procedure emlManagerApplyLabelCap: .prefix$, .name$, .suffix$, .cap
    .budget = .cap - length (.prefix$)
    if .budget < 0
        .budget = 0
    endif
    .full$ = .name$ + .suffix$
    if length (.full$) <= .budget
        .capped$ = .prefix$ + .full$
    elsif .suffix$ = ""
        @emlManagerMiddleEllipsis: .name$, .budget, emlManager_labelTailMinBare
        .capped$ = .prefix$ + emlManagerMiddleEllipsis.result$
    else
        if length (.suffix$) <= emlManager_labelSuffixCap
            .shortSuffix$ = .suffix$
        else
            @emlManagerMiddleEllipsis: .suffix$, emlManager_labelSuffixCap,
                ... emlManager_labelTailMinShared
            .shortSuffix$ = emlManagerMiddleEllipsis.result$
        endif
        .nameBudget = .budget - length (.shortSuffix$)
        if length (.name$) <= .nameBudget
            .cappedName$ = .name$
        else
            @emlManagerMiddleEllipsis: .name$, .nameBudget, emlManager_labelTailMinShared
            .cappedName$ = emlManagerMiddleEllipsis.result$
        endif
        .capped$ = .prefix$ + .cappedName$ + .shortSuffix$
    endif
endproc

# ----------------------------------------------------------------------------
# Sec. 2a AMENDED: the identity prefix for selection-row .index (1-based, its
# position in the page-1 listing) -- a fixed leading letter
# (emlManager_indexLabelLead$; see its comment for why), then the index
# digits and "_", all of which survive emlManagerDeriveLabel's sanitizer
# untouched. Used ONLY by emlManagerBuildLabels below, and only for the rows
# a collision actually forces it onto -- see that procedure for the bare-by-
# default rule. Wherever it IS used, the derived readback variable is both a
# valid Praat identifier and unique by construction no matter what the cap
# does to the rest of the label.
procedure emlManagerIndexPrefix: .index
    .prefix$ = emlManager_indexLabelLead$ + string$ (.index) + emlManager_indexLabelSep$
endproc

# ----------------------------------------------------------------------------
# Sec. 2a AMENDED: the plain-text index prefix used on description comments
# and the remove flow's Dialog-2 full-name lines when (and only when) that
# row's checkbox label was itself forced to carry the identity prefix --
# "n<index>. ", the same letter and digits as the checkbox, so a shortened,
# prefixed checkbox label can be resolved against its full name. A row whose
# checkbox stayed bare gets no prefix here either (see emlManagerBuildLabels
# and its .prefixed# output). Not passed through the sanitizer, so it can
# use punctuation the checkbox prefix cannot.
procedure emlManagerIndexDescPrefix: .index
    .prefix$ = emlManager_indexLabelLead$ + string$ (.index) + emlManager_indexDescSep$
endproc

# ----------------------------------------------------------------------------
# Sec. 2a AMENDED (Ian, 1 Sep: visible index prefixes on every row are a
# waste of space) -- THE ONE CANON both selection dialogs (install's
# checklist and remove's Dialog 1) build their row labels through. Every
# label starts BARE: pass 1 caps and sanitizes .name$#[i] + .suffix$#[i]
# with no prefix at all (emlManagerApplyLabelCap with .prefix$ = ""). Pass 2
# looks for any group of rows whose bare DERIVED readback names came out
# identical, and rebuilds ONLY those rows' label and derived name through
# the SAME cap-then-sanitize canon with their listing-index prefix
# (emlManagerIndexPrefix, letter-initial so the derived variable never
# starts with a digit) prepended -- every member of a colliding group is
# rebuilt, not just the second one found, so the whole group becomes
# mutually distinct rather than merely no-longer-matching row 1.
# THE COLLISION TEST RUNS ON THE DERIVED NAME, never on the label (0.7.3
# round 2): Praat reads a checkbox back through the variable name it
# derives from the label, and two different labels can derive the same
# name -- "plugin_foo-bar" shows as "plugin_foo bar" and "plugin_foo_bar"
# shows as "plugin_foo_bar", yet both read back as plugin_foo_bar, so
# ticking one selected the other. Names that differ only in the case of
# the first letter collide the same way (emlManagerDeriveLabel lowercases
# it). A label that stays bare is unique BECAUSE its derived name is; a
# label the pass rebuilds is unique because the prefix digits are identity,
# unique per row by construction (sec. 2a) -- so .derived$# is guaranteed
# unique either way with no separate duplicate guard needed (sec. 2d).
# .prefixed# tells each call site whether that row's label carries the
# prefix, so the description comment / Dialog-2 line
# (emlManagerIndexDescPrefix) can decide whether to show the matching
# "n<i>." breadcrumb or nothing at all.
# CALLER REQUIREMENT (measured, barren build 6.6.30): every element of
# .name$# and .suffix$# must already have been WRITTEN by the caller (a
# real assignment, however trivial -- "" included) rather than left at
# empty$#'s own just-allocated default. This procedure concatenates
# .name$#[i] and .suffix$#[i] (via emlManagerApplyLabelCap); concatenating
# an untouched empty$# element -- even indirectly, copied through a plain
# variable or passed on as a procedure argument -- segfaults the
# interpreter outright, whether or not the element's own string value is
# empty. A row with no suffix passes a real "" (assigned, not left raw),
# never a bare empty$# slot -- see the callers' own comments.
procedure emlManagerBuildLabels: .name$#, .suffix$#, .n, .cap
    .cap0 = max (.n, 1)
    .bareDerived$# = empty$# (.cap0)
    .label$# = empty$# (.cap0)
    .derived$# = empty$# (.cap0)
    .prefixed# = zero# (.cap0)

    for .i from 1 to .n
        @emlManagerApplyLabelCap: "", .name$# [.i], .suffix$# [.i], .cap
        @emlManagerDeriveLabel: emlManagerApplyLabelCap.capped$
        .bareDerived$# [.i] = emlManagerDeriveLabel.derived$
        .label$# [.i] = emlManagerDeriveLabel.label$
        .derived$# [.i] = emlManagerDeriveLabel.derived$
    endfor

    # Duplicate detection reads ONLY .bareDerived$# (pass 1's untouched
    # output), never .derived$# -- .derived$# is overwritten in place as this
    # very loop runs, so comparing against it here would let an earlier
    # row's already-rebuilt (prefixed) name silently stop matching a later
    # row still holding the original bare name, undercounting the group.
    for .i from 1 to .n
        .isDup = 0
        for .j from 1 to .n
            if .j <> .i and .bareDerived$# [.j] = .bareDerived$# [.i]
                .isDup = 1
            endif
        endfor
        if .isDup = 1
            .prefixed# [.i] = 1
            @emlManagerIndexPrefix: .i
            @emlManagerApplyLabelCap: emlManagerIndexPrefix.prefix$,
                ... .name$# [.i], .suffix$# [.i], .cap
            @emlManagerDeriveLabel: emlManagerApplyLabelCap.capped$
            .label$# [.i] = emlManagerDeriveLabel.label$
            .derived$# [.i] = emlManagerDeriveLabel.derived$
        endif
    endfor
endproc

# ----------------------------------------------------------------------------
# The page-budget canon: the ONLY place that states what a pause-window row
# costs and how much a page may hold. All values are pixels, measured on
# Praat 7.0.03 (Linux, 1280x900 Xvfb, openbox): a pause window grows by these
# amounts per row, and its fixed part (button row and padding) is the chrome.
#   - A comment whose text ends in a period, and an empty comment: 37.
#   - A comment whose text ends in a colon: 27.
#   - A comment whose text ends in any other character: 22.
#   - A boolean (checkbox) row: 32.
#   - Chrome: 91 (the largest measured; a window of plain comments).
# The last character of the comment text sets the height. That is what was
# measured; the Praat source was not available to say why.
# .screenPx is the tallest pause window allowed: a 900-pixel-tall screen less
# 100 for the window title bar and the system menu bar, dock or taskbar.
# .budgetPx is what remains for rows, and is the budget every page walk uses.
# .reservePx is the install dialog's last-page extra: the literal-names
# toggle (a boolean) and the blank comment that separates it.
procedure emlManagerPageMetrics
    .periodPx = 37
    .colonPx = 27
    .commentPx = 22
    .booleanPx = 32
    .chromePx = 91
    .screenPx = 800
    .budgetPx = .screenPx - .chromePx
    .reservePx = .booleanPx + .periodPx
endproc

# Rendered height of one comment row (one wrapped line, or "" for a blank
# line), by its last character. A line longer than emlManager_wrapWidth can
# only be one unbreakable word (the wrapper never splits a word), which the
# window itself wraps onto further rendered rows; each extra row adds
# .commentPx (measured: about 20 px, so this is conservative). Output: .px.
procedure emlManagerLinePx: .text$
    @emlManagerPageMetrics
    .last$ = right$ (.text$, 1)
    if .text$ = "" or .last$ = "."
        .px = emlManagerPageMetrics.periodPx
    elsif .last$ = ":"
        .px = emlManagerPageMetrics.colonPx
    else
        .px = emlManagerPageMetrics.commentPx
    endif
    .extraRows = ceiling (length (.text$) / emlManager_wrapWidth) - 1
    if .extraRows > 0
        .px = .px + .extraRows * emlManagerPageMetrics.commentPx
    endif
endproc

# Rendered height of a text after word wrapping at emlManager_wrapWidth: the
# sum of its wrapped lines (a blank text is one blank line). Output: .px.
# With .emit = 1, inside a pause form, it also emits the lines as comments,
# so the height counted is the height shown.
procedure emlManagerWrappedPx: .text$, .emit
    .px = 0
    if .text$ = ""
        @emlManagerLinePx: ""
        .px = emlManagerLinePx.px
        if .emit = 1
            comment: ""
        endif
    else
        @emlManagerWrapText: .text$, emlManager_wrapWidth
        .nLines = size (emlManagerWrapText.lines$#)
        for .wi from 1 to .nLines
            @emlManagerLinePx: emlManagerWrapText.lines$# [.wi]
            .px = .px + emlManagerLinePx.px
            if .emit = 1
                comment: emlManagerWrapText.lines$# [.wi]
            endif
        endfor
    endif
endproc

# ----------------------------------------------------------------------------
# Page-budget pagination (see emlManagerPageMetrics). Packs .nItems items
# (each .itemPx#[i] pixels tall when rendered) into pages of at most
# .budgetPx pixels. The ONE keep-together rule lives here: an item with
# .keepPrev#[i] = 1 always stays on the same page as the item before it, so
# a run of items (the wrapped lines of one command, a heading and its first
# command) is one unbreakable block. A page always takes at least one block,
# even one taller than the budget, so the walk always makes progress.
# When .reservePx > 0 (the install dialog's literal-toggle boolean plus its
# blank spacer; the removal dialogs' footer with the safety switch) a
# trailing pseudo-item of that height is walked along with the real items,
# so the SAME pass that decides page breaks also decides whether the reserve
# fits on the last block's page. With .reserveKeepsPrev = 1 the reserve is
# part of the last block, so the last page always holds at least that
# block; with 0 it may take a page of its own.
# Output: .nPages, and .pageStartItem#/.pageEndItem# (1-based indices into
# the real items, per page; a page holding only the reserve has
# .pageStartItem# [.] > .pageEndItem# [.], an empty range of real items).
procedure emlManagerPageBudgetWalk: .itemPx#, .keepPrev#, .nItems, .budgetPx, .reservePx, .reserveKeepsPrev
    .unitFirst# = zero# (.nItems + 1)
    .unitLast# = zero# (.nItems + 1)
    .unitPx# = zero# (.nItems + 1)
    .nUnits = 0
    for .i from 1 to .nItems
        if .i = 1 or .keepPrev# [.i] = 0
            .nUnits = .nUnits + 1
            .unitFirst# [.nUnits] = .i
        endif
        .unitLast# [.nUnits] = .i
        .unitPx# [.nUnits] = .unitPx# [.nUnits] + .itemPx# [.i]
    endfor
    if .reservePx > 0
        if .reserveKeepsPrev = 1 and .nUnits > 0
            .unitPx# [.nUnits] = .unitPx# [.nUnits] + .reservePx
        else
            .nUnits = .nUnits + 1
            .unitFirst# [.nUnits] = .nItems + 1
            .unitLast# [.nUnits] = .nItems
            .unitPx# [.nUnits] = .reservePx
        endif
    endif

    .rawStart# = zero# (.nUnits)
    .rawEnd# = zero# (.nUnits)
    .nPages = 0
    .u = 1
    while .u <= .nUnits
        .firstU = .u
        .sum = .unitPx# [.u]
        .u = .u + 1
        .keepGoing = 1
        while .keepGoing = 1 and .u <= .nUnits
            if .sum + .unitPx# [.u] <= .budgetPx
                .sum = .sum + .unitPx# [.u]
                .u = .u + 1
            else
                .keepGoing = 0
            endif
        endwhile
        .nPages = .nPages + 1
        .rawStart# [.nPages] = .unitFirst# [.firstU]
        .rawEnd# [.nPages] = .unitLast# [.u - 1]
    endwhile

    .pageStartItem# = zero# (.nPages)
    .pageEndItem# = zero# (.nPages)
    for .p from 1 to .nPages
        .pageStartItem# [.p] = .rawStart# [.p]
        .pageEndItem# [.p] = .rawEnd# [.p]
    endfor
endproc

# ----------------------------------------------------------------------------
# The install checklist's pages: one row per plugin (its wrapped description
# comment plus its checkbox), walked with the literal-names switch and its
# blank spacer as a footer that keeps with the last plugin row, so the switch
# never sits alone on a page. Output: .nPages, .pageStartItem#, .pageEndItem#.
procedure emlManagerChecklistPages: .descLines$#, .nRows
    @emlManagerPageMetrics
    .itemPx# = zero# (.nRows)
    for .i from 1 to .nRows
        @emlManagerWrappedPx: .descLines$# [.i], 0
        .itemPx# [.i] = emlManagerWrappedPx.px + emlManagerPageMetrics.booleanPx
    endfor
    .noKeep# = zero# (.nRows)
    @emlManagerPageBudgetWalk: .itemPx#, .noKeep#, .nRows,
        ... emlManagerPageMetrics.budgetPx, emlManagerPageMetrics.reservePx, 1
    .nPages = emlManagerPageBudgetWalk.nPages
    .pageStartItem# = emlManagerPageBudgetWalk.pageStartItem#
    .pageEndItem# = emlManagerPageBudgetWalk.pageEndItem#
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
procedure emlManagerUnpack: .format$, .sourceName$, .source$, .dest$
    .ok = 0
    .message$ = ""
    .hadHint = 0
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
            .hadHint = 1
            .message$ = .message$ + emlManager_msgLinuxUnzipHint$ + .sourceName$
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
            .subName$ = .subs$# [.si]
            if .subName$ <> emlManager_macosxExclude$
                # SPEC_SCAN_OPTIMIZATION sec. Fix 3: a subfolder whose NAME is
                # itself a candidate (per emlManagerIsCandidateName) is not
                # enqueued -- its whole subtree is excluded from this scan.
                # That nested candidate gets its own turn in the per-candidate
                # loop; without this exclusion its scripts referencing its OWN
                # name would be double-counted as evidence for the ancestor's
                # name too.
                @emlManagerIsCandidateName: .subName$
                if emlManagerIsCandidateName.yes = 0
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
                    .q$# [.tail] = .cur$ + "/" + .subName$
                endif
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
        # SPEC_SCAN_OPTIMIZATION sec. Fix 2: whole-file pre-gate. Read the
        # file once and test for the ASCII substring emlManager_pluginPrefix$
        # before paying for the per-line loop; a file that never mentions it
        # cannot contribute evidence. This is an ASCII substring search only,
        # so it survives whatever decoding readFile$ applies -- the same
        # decoding readLinesFromFile$# applies below -- and the measured
        # readFile$ byte-safety caveat (binary/non-ASCII round-tripping,
        # DRIVE_RECORD 2026-08-31) does not apply here.
        .content$ = readFile$ (.fpath$)
        if index (.content$, emlManager_pluginPrefix$) > 0
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
# LEADING-CHARACTER REQUIREMENT (measured, sec. 2a's GUI drive): a Praat
# script variable name must start with a letter. A label that starts with a
# digit does not just derive an unconventional variable name -- reading it
# back through indirect substitution ('.derived$') re-parses the substituted
# text as Praat code, and a digit followed by "_" is a parse error there
# ("Unknown symbol"). This procedure cannot fix that after the fact: it only
# mirrors whatever Praat itself already did to the WIDGET's real internal
# name, which for a digit-led label is not simply "add a prefix" (measured:
# prepending a guard letter here does not match Praat's own name for the
# widget, "Unknown variable" instead of "Unknown symbol"). The fix has to be
# upstream, in what .name$ is to begin with -- see emlManagerIndexPrefix,
# which starts the index prefix with a fixed letter so every label this
# procedure ever sees already starts with one.
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
# Returns .rest$: .line$ with every leading command modifier
# (emlManager_rptModifiers$#) removed, exactly as Praat removes them
# (measured, Praat 7.0.03): a modifier counts only when the keyword is
# followed by ONE space; that space goes with it, and the rest is examined
# from its first character again, so a second space or a tab after a
# keyword leaves the command text starting with a blank and Praat refuses
# it ("Command ' Add menu command...' not available"; under nocheck the
# line is silently skipped). The caller has already removed the blanks at
# the start of the whole line, which Praat also ignores.
procedure emlManagerStripCommandModifiers: .line$
    .rest$ = .line$
    .stripped = 1
    while .stripped = 1
        .stripped = 0
        for .m to size (emlManager_rptModifiers$#)
            .keyword$ = emlManager_rptModifiers$# [.m] + " "
            if startsWith (.rest$, .keyword$)
                .rest$ = right$ (.rest$, length (.rest$) - length (.keyword$))
                .stripped = 1
            endif
        endfor
    endwhile
endproc

# ----------------------------------------------------------------------------
# Whether .folderPath$ has a setup.praat and how many clickable commands it
# registers (submenu headers and button headings are not commands).
# The count is the report parser's own (emlManagerParseSetupCommands, the
# ONE canon for reading registration lines), so the checklist's "adds N
# commands" and the Installation-complete report can never disagree.
procedure emlManagerCheckSetupPresent: .folderPath$
    .setupPath$ = .folderPath$ + "/" + emlManager_setupFile$
    .hasSetup = 0
    .commandCount = 0
    if fileReadable (.setupPath$)
        .hasSetup = 1
        @emlManagerParseSetupCommands: .setupPath$
        .commandCount = emlManagerParseSetupCommands.registered
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
# Item 1 / UX round spec sec. 4: resolves what happens at .destPath$ before a
# plugin is placed there -- archives an actually-installed plugin (the
# installed-test canon, emlManagerIsInstalled), or, when .destPath$ is a
# ghost (exists but not installed), clears the remnant as fresh ground with
# no archive. Neither branch runs when nothing is there yet. Pulled out of
# the main sequence's install loop, unchanged, so the harness can drive this
# decision directly without a dialog (this is the collision-resolution half
# of that loop; emlManagerPlaceFolder/emlManagerVerify, called after this,
# are the placement half and already covered by Check 9d).
procedure emlManagerResolveInstallTarget: .destPath$, .instName$, .prefsDir$, .archiveDir$
    .wasReplaced = 0
    .wasGhostReused = 0
    .archiveOk = 1
    .preSummary$ = ""
    if folderExists (.destPath$)
        @emlManagerIsInstalled: .destPath$
        if emlManagerIsInstalled.installed = 1
            @emlManagerArchiveExisting: .instName$, .prefsDir$, .archiveDir$
            if emlManagerArchiveExisting.ok = 1
                .wasReplaced = 1
            else
                .archiveOk = 0
                .preSummary$ = emlManagerArchiveExisting.message$
            endif
        else
            @emlManagerCleanupStaging: .destPath$
            .wasGhostReused = 1
        endif
    endif
endproc

# ----------------------------------------------------------------------------
# Item 1 / UX round spec sec. 4: the one or two completion-report summary
# lines for a single successfully-placed-and-verified plugin -- the plain
# success line, plus (only when .wasGhostReused = 1) the ghost-reused note,
# emlManager_msgGhostReused$. Also returns the installed-command report
# fields (.reportShow/.reportFolder$/.reportPath$) for that same row. Pulled
# out of the main sequence's install loop, unchanged, so the harness can
# assert the ghost-reused line is actually emitted (spec sec. 4) without a
# dialog. Not called at all when verification failed -- the caller emits its
# own single "FAILED: ..." line in that case, as before.
procedure emlManagerBuildInstallSummaryLines: .instName$, .litName$,
    ... .wasReplaced, .wasGhostReused, .prefsDir$
    .line$ = .instName$
    if .instName$ <> .litName$
        .line$ = .line$ + " (" + emlManager_annotRenamedFrom$ + .litName$ + ")"
    endif
    if .wasReplaced = 1
        .line$ = .line$ + emlManager_msgArchiveNote$
    endif
    .reportShow = 1
    .reportFolder$ = .instName$
    .reportPath$ = .prefsDir$ + "/" + .instName$ + "/" + emlManager_setupFile$
    if .wasGhostReused = 1
        .n = 2
        .lines$# = empty$# (2)
        .lines$# [1] = .line$
        .lines$# [2] = emlManager_msgGhostReused$
    else
        .n = 1
        .lines$# = empty$# (1)
        .lines$# [1] = .line$
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
# ("menu" | "submenu" | "action" | "computed"), .text$ (empty for
# "computed"), and the
# (possibly updated) .depthTitle$#/.depthKnown# to copy back into the caller.
procedure emlManagerRptProcessLogicalLine: .rawLine$, .depthTitle$#, .depthKnown#, .maxDepth
    .isReg = 0
    .kind$ = ""
    .text$ = ""
    @emlManagerStripCommandModifiers: .rawLine$
    .line$ = emlManagerStripCommandModifiers.rest$
    if startsWith (.line$, emlManager_rptCmdMenu$)
        .rest$ = right$ (.line$, length (.line$) - length (emlManager_rptCmdMenu$))
        # 0.7.3: the legacy ("...") form may leave off the trailing script
        # argument (measured: Praat 7.0.03 accepts 5 arguments there, as in
        # a submenu heading line); the modern (":") form may not.
        # AMENDED rule 1: the keyword alone is not enough -- the modern ":"
        # or the legacy "..." must follow IMMEDIATELY, or this is not a
        # registration at all (e.g. "Add menu commands: ..." is prose).
        if startsWith (.rest$, ":") or startsWith (.rest$, "...")
            @emlManagerRptTokens: .rest$, 6
            .legacy = startsWith (.rest$, "...")
            if emlManagerRptTokens.n = 6 or (.legacy = 1 and emlManagerRptTokens.n = 5)
                .isReg = 1
                .windowQuoted = emlManagerRptTokens.quoted# [1]
                .windowVal$ = emlManagerRptTokens.value$# [1]
                .menuQuoted = emlManagerRptTokens.quoted# [2]
                .menuVal$ = emlManagerRptTokens.value$# [2]
                .titleQuoted = emlManagerRptTokens.quoted# [3]
                .titleVal$ = emlManagerRptTokens.value$# [3]
                .depthVal = round (number (emlManagerRptTokens.value$# [5]))
                # No script (the argument is left off, or is a quoted empty
                # string): Praat shows the registration as a submenu header,
                # which is not a command.
                .scriptless = 0
                if emlManagerRptTokens.n < 6
                    .scriptless = 1
                elsif emlManagerRptTokens.quoted# [6] = 1 and emlManagerRptTokens.value$# [6] = ""
                    .scriptless = 1
                endif
                # AMENDED rule 4: window and menu count too -- a variable
                # name must never leak into the English, not just the title.
                # A separator (title starting with the separator prefix, quoted
                # or not -- the legacy form allows a bare --) and a spacer
                # (an empty title) are not commands; both are tested first.
                if startsWith (.titleVal$, emlManager_rptSeparatorPrefix$)
                    ... or (.titleQuoted = 1 and .titleVal$ = "")
                    .isReg = 0
                elsif .titleQuoted = 0 or .windowQuoted = 0 or .menuQuoted = 0
                    # A scriptless registration with a computed name is not
                    # a command and cannot be named: it is left out.
                    if .scriptless = 1
                        .isReg = 0
                    else
                        .kind$ = "computed"
                    endif
                else
                    .kind$ = "menu"
                    .article$ = "Adds "
                    if .scriptless = 1
                        .kind$ = "submenu"
                        .article$ = "Adds a submenu "
                    endif
                    .text$ = .article$ + """" + .titleVal$ + """ to the " + .menuVal$
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
            .legacy = startsWith (.rest$, "...")
            if emlManagerRptTokens.n = 10 or (.legacy = 1 and emlManagerRptTokens.n = 9)
                .isReg = 1
                .c1$ = emlManagerRptTokens.value$# [1]
                .n1 = round (number (emlManagerRptTokens.value$# [2]))
                .c2$ = emlManagerRptTokens.value$# [3]
                .n2 = round (number (emlManagerRptTokens.value$# [4]))
                .c3$ = emlManagerRptTokens.value$# [5]
                .n3 = round (number (emlManagerRptTokens.value$# [6]))
                .titleQuoted = emlManagerRptTokens.quoted# [7]
                .titleVal$ = emlManagerRptTokens.value$# [7]
                # No script: Praat shows the registration as a heading label
                # that cannot be clicked, so it is not a button.
                .scriptless = 0
                if emlManagerRptTokens.n < 10
                    .scriptless = 1
                elsif emlManagerRptTokens.quoted# [10] = 1 and emlManagerRptTokens.value$# [10] = ""
                    .scriptless = 1
                endif
                if startsWith (.titleVal$, emlManager_rptSeparatorPrefix$)
                    ... or (.titleQuoted = 1 and .titleVal$ = "")
                    ... or .scriptless = 1
                    .isReg = 0
                elsif .titleQuoted = 0
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
# parallel .kind$# ("menu" | "submenu" | "action" | "computed") and .text$#
# (the finished, unwrapped English line -- the caller wraps it for display),
# and .registered, the number of clickable commands: rows of kind menu,
# action and computed. A registration with no script is not a command: a
# menu one is reported as a "submenu" row and not counted, an action one (a
# heading label that Praat does not let you click) is left out. The "no
# commands" row and the "plus N commands" summary row are not registrations.
# emlManagerCheckSetupPresent reports .registered as the checklist's
# command count.
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

    # Join each "..." continuation line onto the line it continues.
    .logicalLine$# = empty$# (.nRaw + 1)
    .nLogical = 0
    for .j from 1 to .nRaw
        .ln$ = .rawLines$# [.j]
        while length (.ln$) > 0 and (left$ (.ln$, 1) = " " or left$ (.ln$, 1) = tab$)
            .ln$ = right$ (.ln$, length (.ln$) - 1)
        endwhile
        if startsWith (.ln$, "...") and .nLogical > 0
            .logicalLine$# [.nLogical] = .logicalLine$# [.nLogical] + " "
                ... + right$ (.ln$, length (.ln$) - 3)
        else
            .nLogical = .nLogical + 1
            .logicalLine$# [.nLogical] = .ln$
        endif
    endfor

    # Only clickable commands count: a submenu header is reported but is not
    # counted (.clickable), and a button heading is neither.
    .clickable = 0
    for .j from 1 to .nLogical
        if .logicalLine$# [.j] <> ""
            @emlManagerRptProcessLogicalLine: .logicalLine$# [.j], .depthTitle$#, .depthKnown#, .maxDepth
            .depthTitle$# = emlManagerRptProcessLogicalLine.depthTitle$#
            .depthKnown# = emlManagerRptProcessLogicalLine.depthKnown#
            if emlManagerRptProcessLogicalLine.isReg = 1
                .n = .n + 1
                .kind$# [.n] = emlManagerRptProcessLogicalLine.kind$
                .text$# [.n] = emlManagerRptProcessLogicalLine.text$
                if emlManagerRptProcessLogicalLine.kind$ = "computed"
                    .computedCount = .computedCount + 1
                endif
                if emlManagerRptProcessLogicalLine.kind$ <> "submenu"
                    .clickable = .clickable + 1
                endif
            endif
        endif
    endfor

    .registered = .clickable

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

# ----------------------------------------------------------------------------
# The command report of one setup.praat as display lines: every entry of
# emlManagerParseSetupCommands word-wrapped at .wrapWidth and flattened into
# one list (a computed-count row's own text is empty and is not rendered as
# a blank line; only its tally line, which has real text, is). .keep#[i] = 1
# marks a line that continues the entry before it, so a page walk
# (emlManagerPageBudgetWalk's .keepPrev#) never breaks one entry across
# pages. The ONE builder for the Installation complete dialog and for the
# report baked into a generated install file. Output: .n, .lines$#, .keep#.
procedure emlManagerReportEntries: .setupPath$, .wrapWidth
    @emlManagerParseSetupCommands: .setupPath$
    .nRows = emlManagerParseSetupCommands.n
    .rowText$# = emlManagerParseSetupCommands.text$#
    .total = 0
    for .i from 1 to .nRows
        if .rowText$# [.i] <> ""
            @emlManagerWrapText: .rowText$# [.i], .wrapWidth
            .total = .total + size (emlManagerWrapText.lines$#)
        endif
    endfor
    .n = .total
    .lines$# = empty$# (.n)
    .keep# = zero# (.n)
    .k = 0
    for .i from 1 to .nRows
        if .rowText$# [.i] <> ""
            @emlManagerWrapText: .rowText$# [.i], .wrapWidth
            for .w from 1 to size (emlManagerWrapText.lines$#)
                .k = .k + 1
                .lines$# [.k] = emlManagerWrapText.lines$# [.w]
                if .w > 1
                    .keep# [.k] = 1
                endif
            endfor
        endif
    endfor
endproc

# ----------------------------------------------------------------------------
# The flattened comment-line list of the Installation complete dialog: each
# installed plugin's summary line, then -- when .reportShow#[i] = 1 -- its
# "<folder> adds:" header and its report entries (emlManagerReportEntries).
# A first pass sizes the list and a second fills it. .keep#[i] = 1 is the
# page walk's keep-with-previous mark: the continuation lines of one entry
# stay with that entry's first line, the header stays with the summary line
# above it and with the first entry below it, and the restart line stays
# with the blank line above it, so a page break never splits any of them. The first .nSummary entries of the summary
# vectors are used. Output: .n, .lines$#, .keep#.
procedure emlManagerBuildCompleteLines: .summaryLines$#, .reportShow#, .reportFolder$#, .reportPath$#, .nSummary
    .n = 0
    for .iSummary from 1 to .nSummary
        .n = .n + 1
        if .reportShow# [.iSummary] = 1
            .n = .n + 1
            @emlManagerReportEntries: .reportPath$# [.iSummary], emlManager_wrapWidth
            .n = .n + emlManagerReportEntries.n
        endif
    endfor
    .n = .n + 2

    .lines$# = empty$# (.n)
    .keep# = zero# (.n)
    .idx = 0
    for .iSummary from 1 to .nSummary
        .idx = .idx + 1
        .lines$# [.idx] = .summaryLines$# [.iSummary]
        if .reportShow# [.iSummary] = 1
            .idx = .idx + 1
            .lines$# [.idx] = .reportFolder$# [.iSummary] + emlManager_rptHeaderSuffix$
            .keep# [.idx] = 1
            @emlManagerReportEntries: .reportPath$# [.iSummary], emlManager_wrapWidth
            .nEntryLines = emlManagerReportEntries.n
            for .iRep from 1 to .nEntryLines
                .idx = .idx + 1
                .lines$# [.idx] = emlManagerReportEntries.lines$# [.iRep]
                .keep# [.idx] = emlManagerReportEntries.keep# [.iRep]
            endfor
            if .nEntryLines > 0
                .keep# [.idx - .nEntryLines + 1] = 1
            endif
        endif
    endfor
    .idx = .idx + 1
    .lines$# [.idx] = ""
    .idx = .idx + 1
    .lines$# [.idx] = emlManager_msgRestart$
    .keep# [.idx] = 1
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
        @emlManagerUnpack: format$, sourceName$, sourcePath$, unpackDest$
        if emlManagerUnpack.ok = 0
            failMsg$ = emlManagerUnpack.message$
            if emlManagerUnpack.hadHint = 1
                @emlManagerLogPath: emlManager_logEventUnpackSource$, sourcePath$
                failMsg$ = failMsg$ + " " + emlManager_msgSeePathInInfo$
            endif
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
    rawFullName$# = empty$# (nFound)
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
        heurIsNearMiss = emlManagerCanonicalName.isNearMiss

        # SPEC_SCAN_OPTIMIZATION sec. Fix 1: skip the scan when it cannot
        # change the outcome. With isNearMiss = 0 and heuristic = literal,
        # every branch of emlManagerCanonicalName yields proposal$ =
        # litName$, row$ = "row", renamedFrom$ = "" regardless of
        # contentRef$ -- the only observable difference would be the
        # cosmetic "confirmed" annotation, so contentRef$ = "none" stands
        # in for the scan's result without running it.
        if heurIsNearMiss = 0 and heurName$ = litName$
            contentRef$ = "none"
        else
            @emlManagerScanNameEvidence: fPath$, litName$, heurName$
            contentRef$ = emlManagerScanNameEvidence.contentRef$
        endif
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
        # state when (and only when) a collision with an ACTUALLY INSTALLED
        # plugin is found (item 1: the installed-test canon). A folder that
        # exists but is not installed -- a ghost left behind by an earlier
        # removal -- is fresh ground: no annotation, no version comparison,
        # default checkbox state untouched.
        annotInst$ = ""
        @emlManagerInstalledCollisionCheck: fPath$, prefsDir$ + "/" + propName$,
            ... stagingPath$
        if emlManagerInstalledCollisionCheck.hasCollision = 1
            annotInst$ = emlManagerInstalledCollisionCheck.annot$
            rawDefault# [iFound] = emlManagerInstalledCollisionCheck.checked
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
        # Real (uncapped) proposed name, carried alongside the display text
        # so the sec. 2a index-prefixed description comment can show the
        # FULL folder name the checkbox's capped label may have shortened.
        rawFullName$# [iFound] = propName$
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
    fullName$# = empty$# (nKeep)
    descSuffix$# = empty$# (nKeep)
    setupFlags# = zero# (nKeep)
    defaultFlags# = zero# (nKeep)
    # MEASURED (barren build, 6.6.30): empty$#'s own elements are NOT plain
    # "" strings until something actually writes to them -- concatenating
    # (the "+" operator) an untouched element, however that concatenation is
    # reached (directly, through a plain-assignment copy, or by passing it
    # into a procedure argument), segfaults the interpreter outright. Every
    # row here has no annotation suffix by definition, so every element is
    # written explicitly (never left at empty$#'s own default) before this
    # array is ever handed to emlManagerBuildLabels, which does concatenate
    # .suffix$# through emlManagerApplyLabelCap.
    noSuffix$# = empty$# (nKeep)
    for iNoSuffix from 1 to nKeep
        noSuffix$# [iNoSuffix] = ""
    endfor

    kRow = 0
    for iFound from 1 to nFound
        if rawKeep# [iFound] = 1
            kRow = kRow + 1
            literal$# [kRow] = rawLiteral$# [iFound]
            path$# [kRow] = rawPath$# [iFound]
            proposal$# [kRow] = rawProposal$# [iFound]
            renamed$# [kRow] = rawRenamed$# [iFound]
            # Full (uncapped) proposed name and the rest of the description
            # text, carried alongside so the pass below can assemble
            # descLines$# once every row's label -- and whether a collision
            # forced it to carry the index prefix -- is known.
            fullName$# [kRow] = rawFullName$# [iFound]
            descSuffix$# [kRow] = rawDesc$# [iFound]
            setupFlags# [kRow] = rawSetup# [iFound]
            defaultFlags# [kRow] = rawDefault# [iFound]
        endif
    endfor

    # Sec. 2a AMENDED: one canon pass over every kept row builds every
    # checkbox label -- bare by default, prefixed only for a row whose bare,
    # capped, sanitized label collides with another's (emlManagerBuildLabels;
    # shared with the remove flow's Dialog 1, "one canon" per sec. 2a).
    # Install rows never carry an annotation suffix -- the manager/ghost
    # suffixes are a remove-flow-only concept (sec. 1/2) -- so the per-row
    # suffix array passed in is all "".
    @emlManagerBuildLabels: proposal$#, noSuffix$#, nKeep, emlManager_boolLabelCap
    boolLabels$# = emlManagerBuildLabels.label$#
    derivedNames$# = emlManagerBuildLabels.derived$#
    rowPrefixed# = emlManagerBuildLabels.prefixed#

    # The description comment above each checkbox always states the FULL
    # (uncapped) proposed name; it carries the matching "n<index>." index
    # breadcrumb only for a row the canon above actually prefixed (sec. 2a)
    # -- a bare checkbox's full name needs no breadcrumb to be resolved by.
    descLines$# = empty$# (nKeep)
    for iRow from 1 to nKeep
        descPrefix$ = ""
        if rowPrefixed# [iRow] = 1
            @emlManagerIndexDescPrefix: iRow
            descPrefix$ = emlManagerIndexDescPrefix.prefix$
        endif
        descLines$# [iRow] = descPrefix$ + fullName$# [iRow] + " -- " + descSuffix$# [iRow]
    endfor

    # --- Pre-dialog collision check (on PROPOSED names) ---
    # Sec. 2d: compares the REAL (uncapped) proposed identity, never a
    # label -- emlManagerBuildLabels already makes derivedNames$# unique by
    # construction (sec. 2a AMENDED: bare where distinct, index-prefixed
    # where not), so a label collision can no longer signal a genuine name
    # collision here even if two rows did propose the same name.

    for iA from 1 to nKeep
        for iB from iA + 1 to nKeep
            if proposal$# [iA] = proposal$# [iB]
                @emlManagerCleanupStaging: stagingPath$
                exitScript: emlManager_msgCollision$
                    ... + proposal$# [iA] + " and "
                    ... + proposal$# [iB]
                    ... + emlManager_msgCollisionSuffix$
            endif
        endfor
    endfor

    # --- Selection dialog (paginated by rendered-line budget, item 3).
    #     Final page carries the literal toggle + its blank spacer -- the
    #     same budget walk that decides page breaks reserves their height.

    @emlManagerChecklistPages: descLines$#, nKeep
    nPages = emlManagerChecklistPages.nPages
    pageStartItem# = emlManagerChecklistPages.pageStartItem#
    pageEndItem# = emlManagerChecklistPages.pageEndItem#

    for iPage from 1 to nPages
        pageStart = pageStartItem# [iPage]
        pageEnd = pageEndItem# [iPage]

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
                @emlManagerWrappedPx: descLines$# [iShow], 1
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

    # Item 1: a ghost reuse adds a second summary line for the same row (the
    # normal install line, then the ghost-reused note), so the arrays that
    # follow summaryIdx are sized to 2 entries per selected row -- a safe
    # upper bound (every other outcome uses at most 1).
    summaryCap = max (nSelected * 2, 1)
    summaryLines$# = empty$# (summaryCap)
    # Item 5: parallel to summaryLines$# -- which rows get an installed-
    # command report (only actual successful installs with a setup.praat)
    # and where to read it from.
    reportShow# = zero# (summaryCap)
    reportFolder$# = empty$# (summaryCap)
    reportPath$# = empty$# (summaryCap)
    summaryIdx = 0
    createFolder: archiveDir$

    for iInst from 1 to nKeep
        if selFlags# [iInst] = 1
            instName$ = installName$# [iInst]
            litName$ = literal$# [iInst]
            pPath$ = path$# [iInst]
            hadSetup = setupFlags# [iInst]
            destPath$ = prefsDir$ + "/" + instName$

            # Item 1: archives an actually-installed collision, or clears a
            # ghost remnant as fresh ground (no archive) -- see
            # emlManagerResolveInstallTarget.
            @emlManagerResolveInstallTarget: destPath$, instName$, prefsDir$, archiveDir$
            wasReplaced = emlManagerResolveInstallTarget.wasReplaced
            wasGhostReused = emlManagerResolveInstallTarget.wasGhostReused
            archiveOk = emlManagerResolveInstallTarget.archiveOk
            if archiveOk = 0
                summaryIdx = summaryIdx + 1
                summaryLines$# [summaryIdx] = emlManagerResolveInstallTarget.preSummary$
            endif

            if archiveOk = 1
                @emlManagerPlaceFolder: pPath$, instName$, prefsDir$
                @emlManagerVerify: instName$, prefsDir$, hadSetup
                summaryIdx = summaryIdx + 1
                if emlManagerVerify.ok = 0
                    summaryLines$# [summaryIdx] = "FAILED: "
                        ... + instName$ + " -- " + emlManagerVerify.message$
                else
                    # Item 1 / spec sec. 4: the success line, plus (only when
                    # placed over a ghost) the reused-leftover note.
                    @emlManagerBuildInstallSummaryLines: instName$, litName$,
                        ... wasReplaced, wasGhostReused, prefsDir$
                    summaryLines$# [summaryIdx] = emlManagerBuildInstallSummaryLines.lines$# [1]
                    reportShow# [summaryIdx] = emlManagerBuildInstallSummaryLines.reportShow
                    reportFolder$# [summaryIdx] = emlManagerBuildInstallSummaryLines.reportFolder$
                    reportPath$# [summaryIdx] = emlManagerBuildInstallSummaryLines.reportPath$
                    if emlManagerBuildInstallSummaryLines.n = 2
                        summaryIdx = summaryIdx + 1
                        summaryLines$# [summaryIdx] = emlManagerBuildInstallSummaryLines.lines$# [2]
                    endif
                endif
            endif
        endif
    endfor

    # --- Cleanup and summary ---

    @emlManagerCleanupStaging: stagingPath$

    @emlManagerBuildCompleteLines: summaryLines$#, reportShow#, reportFolder$#, reportPath$#, summaryIdx
    totalLines = emlManagerBuildCompleteLines.n
    allLines$# = emlManagerBuildCompleteLines.lines$#
    keepLines# = emlManagerBuildCompleteLines.keep#

    # Same page-budget walk as the selection dialog; every entry of
    # allLines$# is already exactly one rendered line, weighted by its
    # measured height, and no reserve applies.
    @emlManagerPageMetrics
    completeLineWeights# = zero# (totalLines)
    for iWeight from 1 to totalLines
        @emlManagerLinePx: allLines$# [iWeight]
        completeLineWeights# [iWeight] = emlManagerLinePx.px
    endfor
    @emlManagerPageBudgetWalk: completeLineWeights#, keepLines#, totalLines,
        ... emlManagerPageMetrics.budgetPx, 0, 0
    nCompletePages = emlManagerPageBudgetWalk.nPages
    completePageStart# = emlManagerPageBudgetWalk.pageStartItem#
    completePageEnd# = emlManagerPageBudgetWalk.pageEndItem#

    for iCPage from 1 to nCompletePages
        cPageStart = completePageStart# [iCPage]
        cPageEnd = completePageEnd# [iCPage]

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
