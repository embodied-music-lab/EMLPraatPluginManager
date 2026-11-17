# ============================================================================
# EML Plugin Manager -- Create Install File for a Plugin
# ============================================================================
# Purpose: Generates a small standalone install script (install-<name>.praat)
#          inside the folder of a plugin: one that is already installed, or
#          any folder you choose ("Another folder"). The plugin author zips
#          the folder as usual; a user who unzips it anywhere and runs the
#          generated script gets the plugin installed with no copy of this
#          manager on their machine. The generated script catalogs file
#          NAMES only -- at install time it copies its own parent folder's
#          contents into the preferences folder; it never reads or embeds
#          any file's contents itself, and never re-reads this manager's own
#          files after generation. A generated script run from inside an
#          installed copy of the same plugin stops and changes nothing.
# Date: 17 November 2026
# Version: 1.2
#
# 1.2 -- Version 0.7.3. The plugin list opens on "Another folder", so
#       packaging a plugin that is not installed is the default; installed
#       plugins follow it. The completion dialog of a generated install file
#       pages by the manager's own page budget, the measured on-screen height
#       of each line, so the Next and OK buttons stay on screen. A page
#       break never splits one command's wrapped lines. The command report
#       in a generated install file lists a plugin's submenu titles as
#       submenus and leaves out heading labels, which Praat does not let
#       you click, so it lists only what you can click. Quitting a dialog
#       says "Install file creation cancelled.". A
#       plugin with many commands, such as jjatools, no longer stops with
#       "Cannot have more than 50 fields in a form", and every command is
#       still shown. The header comment of every generated install file
#       tells you which Trust window button to choose in Praat 7 (the third
#       button, "Yes, and I even allow this script to CONTROL MY COMPUTER
#       from now on"), because the file writes many files.
#
# 1.1 -- Version 0.7.2. You can create an install file for any plugin
#       folder through "Another folder", not only for installed plugins.
#       A generated install file run from inside an already-installed copy
#       stops with an explanation and changes nothing. File paths go to the
#       Info window so you can copy them.
#
# ATTRIBUTION
# Framework: EML PraatGen by Ian Howell
#            Embodied Music Lab -- www.embodiedmusiclab.com
#            https://github.com/embodied-music-lab/PraatGen
# Code generation: Claude (Anthropic)
# ============================================================================

# Library-includes install-from-disk.praat under the harness flag, the same
# pattern remove-plugin.praat uses: this module reuses that file's constants
# and canon procedures (the installed test, the version comparator and its
# numeric-token helper, and the pause-dialog word wrapper) both to build its
# own dialogs and, mechanically, as the exact source text baked into every
# generated wrapper -- see emlManagerCifExtractBlock/emlManagerCifGenerateWrapper
# below. MEASURED (remove-plugin.praat's own note; harness/DRIVE_RECORD_2026-08-31.md):
# Praat resolves an include -- nested ones too -- relative to the OUTERMOST
# running script's own folder, never the file that names the include, so
# the path below is written relative to the plugin folder rather than as a
# bare filename: this resolves correctly both when this file is itself the
# outermost script (real use) and when a harness script includes it from a
# different folder.
emlManager_harnessMode = 1
include ../plugin_EMLPraatPluginManager/install-from-disk.praat

# ============================================================================
# Constants (this module's own dialogs and messages)
# ============================================================================

emlManagerCif_title1$ = "Create install file for a plugin"
emlManagerCif_title2$ = "Version"
emlManagerCif_titleBadVersion$ = "Invalid version"
emlManagerCif_titleComplete$ = "Install file created"
emlManagerCif_titleGenFailed$ = "Could not create the install file"

emlManagerCif_btnQuit$ = "Quit"
emlManagerCif_msgCancelled$ = "Install file creation cancelled."
emlManagerCif_btnContinue$ = "Continue"
emlManagerCif_btnCreate$ = "Create"
emlManagerCif_btnOK$ = "OK"

emlManagerCif_pluginFieldLabel$ = "Plugin"
emlManagerCif_versionFieldLabel$ = "Version"
emlManagerCif_versionHint$ = "Numbers and periods only (for example 1.2.0)."
emlManagerCif_defaultVersion$ = "1.0.0"

emlManagerCif_msgWroteToPrefix$ = "Wrote "
emlManagerCif_msgWroteToMid$ = " to "
emlManagerCif_msgManifestSuffix$ = " files listed in its manifest."
emlManagerCif_msgRegenReminder$ = "Regenerate this file (run this command again) after adding or removing files, or after changing setup.praat's commands. Editing a file's contents does not require regenerating it."
emlManagerCif_msgGenFailed$ = "The manager's own canon procedures could not be located in its install-from-disk.praat. Nothing was written."
emlManagerCif_msgNonAsciiName$ = "This plugin's folder name contains characters outside plain ASCII. An install file cannot carry them in file paths, so no install file was written. Rename the folder to plain ASCII first."
emlManagerCif_titleNonAsciiName$ = "Folder name not supported"
# Printable ASCII 32-126; used by the generation-time ASCII guard.
emlManagerCif_ascii$ = " !""#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~"

emlManagerCif_wrapperPrefix$ = "install-"
emlManagerCif_wrapperExt$ = ".praat"
emlManagerCif_oldPrefix$ = "old_"

# SPEC_WRAPPER_SAFETY part 2: the folder-source option. The optionmenu's
# FIRST entry (default since 0.7.3; exact text pinned by the spec) routes to a folder chooser
# instead of prefsDir$; MEASURED at GUI 6.6.30 (both chooseFolder$: and
# chooseDirectory$: exist and open a working GTK folder picker, both return
# "" on Cancel -- chooseFolder$: is used here for consistency with its only
# other call site in this codebase, install-from-disk.praat's own "a folder
# that is already unpacked" source option).
emlManagerCif_anotherFolderLabel$ = "Another folder (chosen in the next step)"
emlManagerCif_anotherFolderIndex = 1
emlManagerCif_chooseFolderTitle$ = "Select the plugin folder"
emlManagerCif_titleBadFolderName$ = "Not a plugin folder"
emlManagerCif_msgBadFolderNamePrefix$ = "Praat only activates folders whose name starts with plugin_. This folder is named """
emlManagerCif_msgBadFolderNameSuffix$ = """; rename it to start with plugin_ and try again."
emlManagerCif_titleNoSetup$ = "No setup.praat found"
emlManagerCif_msgNoSetupPrefix$ = "An install file describes a plugin, and """
emlManagerCif_msgNoSetupSuffix$ = """ has no setup.praat at its top level."

# SPEC_WRAPPER_SAFETY part 3 sweep: the completion dialog names the folder
# only; the full path goes through emlManagerLogPath (install-from-disk.praat).
emlManagerCif_logEventWroteTo$ = "Wrote install file to"

# ============================================================================
# The wrapper's static header comment (baked verbatim, no per-plugin content;
# a doubled quote below is one quote in the wrapper).
# ============================================================================

emlManagerCif_headerLines$# = {
    ... "# EML plugin install file -- generated by the EML Plugin Manager's",
    ... "# Create install file for a plugin command. Regenerate (do not",
    ... "# hand-edit) after files are added or removed in this folder, or",
    ... "# after setup.praat's registered commands change; editing a file's",
    ... "# contents alone does not require regenerating this file.",
    ... "#",
    ... "# At install time this copies its own parent folder's contents into",
    ... "# Praat's preferences folder under the folder name below. It catalogs",
    ... "# file names only -- never file contents.",
    ... "#",
    ... "# If Praat asks whether to trust this script, choose the third",
    ... "# button, ""Yes, and I even allow this script to CONTROL MY",
    ... "# COMPUTER from now on"". This script writes many files, and",
    ... "# Praat would otherwise ask again for each one.",
    ... "" }

# ============================================================================
# Generator work procedures
# ============================================================================

# ----------------------------------------------------------------------------
# The installed plugins available to build an install file for: every
# plugin_* folder in .prefsDir$ passing the installed canon (emlManagerIsInstalled
# -- a top-level setup.praat), ghosts excluded, sorted by folder name. Bare
# capped labels via the existing label canon (emlManagerBuildLabels, shared
# with the install and remove checklists), with no annotation suffix.
procedure emlManagerCifListInstalled: .prefsDir$
    .rawNames$# = folderNames$# (.prefsDir$ + "/" + emlManager_pluginPrefix$ + "*")
    .rawNames$# = sort$# (.rawNames$#)
    .rawN = size (.rawNames$#)
    .cap = max (.rawN, 1)
    .collect$# = empty$# (.cap)
    .n = 0
    for .i from 1 to .rawN
        @emlManagerIsInstalled: .prefsDir$ + "/" + .rawNames$# [.i]
        if emlManagerIsInstalled.installed = 1
            .n = .n + 1
            .collect$# [.n] = .rawNames$# [.i]
        endif
    endfor
    if .n = 0
        .names$# = empty$# (0)
        .labels$# = empty$# (0)
    else
        .names$# = empty$# (.n)
        .noSuffix$# = empty$# (.n)
        for .i from 1 to .n
            .names$# [.i] = .collect$# [.i]
            .noSuffix$# [.i] = ""
        endfor
        @emlManagerBuildLabels: .names$#, .noSuffix$#, .n, emlManager_boolLabelCap
        .labels$# = emlManagerBuildLabels.label$#
    endif
endproc

# ----------------------------------------------------------------------------
# SPEC_WRAPPER_SAFETY part 2: validates a chosen folder-source folder, in the
# pinned order -- (a) plugin_ prefix, (b) top-level setup.praat (the
# installed-iff-setup canon, emlManagerIsInstalled, reused unchanged), (c)
# the existing non-ASCII name refusal -- stopping at the first failure.
# Trims any trailing "/" or "\" first (chooseFolder$ may add one). Factored
# out of the main sequence so the validation order is directly testable
# headless, at the procedure level, with no dialog. .result$ is one of
# "ok", "bad_prefix", "no_setup", "non_ascii"; .name$/.path$ are always set
# (the normalized folder and its bare name), usable by the caller regardless
# of .result$.
procedure emlManagerCifValidateFolderSource: .chosenFolder$
    .path$ = .chosenFolder$
    while length (.path$) > 0
        ... and (right$ (.path$, 1) = "/" or right$ (.path$, 1) = "\")
        .path$ = left$ (.path$, length (.path$) - 1)
    endwhile
    @emlManagerBaseName: .path$
    .name$ = emlManagerBaseName.name$

    if not startsWith (.name$, emlManager_pluginPrefix$)
        .result$ = "bad_prefix"
    else
        @emlManagerIsInstalled: .path$
        if emlManagerIsInstalled.installed = 0
            .result$ = "no_setup"
        else
            @emlManagerCifAsciiSanitize: .name$
            if emlManagerCifAsciiSanitize.hadNonAscii = 1
                .result$ = "non_ascii"
            else
                .result$ = "ok"
            endif
        endif
    endif
endproc

# ----------------------------------------------------------------------------
# Version-field validation: digits and periods only, at least one digit.
procedure emlManagerCifVersionValid: .v$
    .ok = 0
    if .v$ <> ""
        if index_regex (.v$, "^[0-9.]+$") > 0 and index_regex (.v$, "[0-9]") > 0
            .ok = 1
        endif
    endif
endproc

# ----------------------------------------------------------------------------
# Writes .version$ as the plugin's VERSION file (one line), creating it when
# absent, overwriting when present.
procedure emlManagerCifWriteVersion: .pluginPath$, .version$
    writeFileLine: .pluginPath$ + "/VERSION", .version$
endproc

# ----------------------------------------------------------------------------
# The manifest: every file's path relative to .pluginPath$ (recursive,
# sorted), with .wrapperFileName$ included exactly once -- added when the
# recursive walk (which runs before the wrapper exists on a first
# generation) did not already find it, so regenerating over an existing
# wrapper never duplicates the entry. Folders are not listed (the manifest
# catalogs file names only, per spec). .scratchFile$ is scratch space for
# the underlying recursive walk (emlManagerListRelFiles, install-from-disk.praat).
procedure emlManagerCifBuildManifest: .pluginPath$, .wrapperFileName$, .scratchFile$
    @emlManagerListRelFiles: .pluginPath$, .scratchFile$
    .files$# = emlManagerListRelFiles.files$#
    .nFiles = size (.files$#)
    .hasWrapper = 0
    for .i from 1 to .nFiles
        if .files$# [.i] = .wrapperFileName$
            .hasWrapper = 1
        endif
    endfor
    if .hasWrapper = 1
        .n = .nFiles
        .all$# = .files$#
    else
        .n = .nFiles + 1
        .all$# = empty$# (.n)
        for .i from 1 to .nFiles
            .all$# [.i] = .files$# [.i]
        endfor
        .all$# [.n] = .wrapperFileName$
    endif
    .paths$# = sort$# (.all$#)
endproc

# ----------------------------------------------------------------------------
# The command report for one plugin's setup.praat, as the lines and
# keep-with-previous marks the wrapper's completion dialog shows: the
# manager's own emlManagerReportEntries, so the wrapper and the Installation
# complete dialog read one report. Baked into the wrapper as static text at
# generation time, so the wrapper itself never needs the parser.
# Output: .n, .lines$#, .keep#.
procedure emlManagerCifBuildReportLines: .setupPath$, .wrapWidth
    @emlManagerReportEntries: .setupPath$, .wrapWidth
    .n = emlManagerReportEntries.n
    .lines$# = emlManagerReportEntries.lines$#
    .keep# = emlManagerReportEntries.keep#
endproc

# ----------------------------------------------------------------------------
# This manager's own install-from-disk.praat, read as plain text (not
# included) so specific procedures/constants can be extracted from it
# mechanically. Same relative-path resolution as the `include` line above
# (measured: both resolve against the outermost running script's folder),
# reused here for a plain file read rather than an include.
procedure emlManagerCifReadInstallerSource
    .path$ = defaultDirectory$ + "/../plugin_EMLPraatPluginManager/install-from-disk.praat"
    .lines$# = readLinesFromFile$# (.path$)
endproc

# ----------------------------------------------------------------------------
# The first line of .lines$# whose text, trimmed of leading spaces, starts
# with .prefix$ -- used to extract a single constant-assignment line
# (e.g. "emlManager_wrapWidth = 62") byte-identical from the source.
procedure emlManagerCifExtractLine: .lines$#, .prefix$
    .found = 0
    .line$ = ""
    .n = size (.lines$#)
    .i = 1
    while .found = 0 and .i <= .n
        .trimmed$ = .lines$# [.i]
        while length (.trimmed$) > 0 and left$ (.trimmed$, 1) = " "
            .trimmed$ = right$ (.trimmed$, length (.trimmed$) - 1)
        endwhile
        if startsWith (.trimmed$, .prefix$)
            .found = 1
            .line$ = .lines$# [.i]
        endif
        .i = .i + 1
    endwhile
endproc

# ----------------------------------------------------------------------------
# The exact "procedure .procName$ ... endproc" block from .lines$#, found by
# a plain linear scan (no procedure in this codebase nests another, so the
# first "endproc" after the start line always closes it): matches either
# "procedure NAME:" (has parameters) or the bare "procedure NAME" line
# (none), then collects through the next line that is exactly "endproc"
# once its own leading spaces are trimmed. .found = 0 when .procName$ is not
# defined in .lines$# at all, or its endproc is never reached (malformed
# source) -- the caller treats either as extraction failure.
procedure emlManagerCifExtractBlock: .lines$#, .procName$
    .found = 0
    .n = 0
    .block$# = empty$# (0)
    .startPrefixColon$ = "procedure " + .procName$ + ":"
    .startBare$ = "procedure " + .procName$
    .total = size (.lines$#)
    .i = 1
    .startIdx = 0
    while .startIdx = 0 and .i <= .total
        .ln$ = .lines$# [.i]
        if startsWith (.ln$, .startPrefixColon$) or .ln$ = .startBare$
            .startIdx = .i
        endif
        .i = .i + 1
    endwhile
    if .startIdx > 0
        .j = .startIdx
        .endIdx = 0
        while .endIdx = 0 and .j <= .total
            .trimmed$ = .lines$# [.j]
            while length (.trimmed$) > 0 and left$ (.trimmed$, 1) = " "
                .trimmed$ = right$ (.trimmed$, length (.trimmed$) - 1)
            endwhile
            if .trimmed$ = "endproc"
                .endIdx = .j
            endif
            .j = .j + 1
        endwhile
        if .endIdx > 0
            .found = 1
            .n = .endIdx - .startIdx + 1
            .block$# = empty$# (.n)
            for .k from 1 to .n
                .block$# [.k] = .lines$# [.startIdx + .k - 1]
            endfor
        endif
    endif
endproc

# ----------------------------------------------------------------------------
# .items$#[1..n] as one Praat string-vector literal, e.g. { "a", "b" } --
# quotes inside an item are doubled so the result is valid Praat source.
procedure emlManagerCifSerializeArray: .items$#, .n
    .out$ = "{ "
    for .i from 1 to .n
        .esc$ = replace$ (.items$# [.i], """", """""", 0)
        if .i > 1
            .out$ = .out$ + ", "
        endif
        .out$ = .out$ + """" + .esc$ + """"
    endfor
    .out$ = .out$ + " }"
endproc

# ----------------------------------------------------------------------------
# .items#[1..n] as one Praat numeric-vector literal, e.g. { 0, 1 }.
procedure emlManagerCifSerializeNumbers: .items#, .n
    .out$ = "{ "
    for .i from 1 to .n
        if .i > 1
            .out$ = .out$ + ", "
        endif
        .out$ = .out$ + string$ (.items# [.i])
    endfor
    .out$ = .out$ + " }"
endproc

# ----------------------------------------------------------------------------
# Appends .lines$#[1..n] to .outPath$ -- writeFileLine for the very first
# line written to the file (.isFirst = 1, truncating/creating it), appendFileLine
# for every other line, including every line here when .isFirst = 0.
procedure emlManagerCifAppendLines: .outPath$, .lines$#, .n, .isFirst
    for .i from 1 to .n
        if .i = 1 and .isFirst = 1
            writeFileLine: .outPath$, .lines$# [.i]
        else
            appendFileLine: .outPath$, .lines$# [.i]
        endif
    endfor
endproc

# ============================================================================
# The wrapper's static template: every line of the generated install file
# that never varies by plugin -- its own user-facing text constants (named,
# per house rule, in the WRAPPER's own source) and every work procedure and
# main-sequence line. The four embedded canons (the installed test, the
# version comparator with its numeric-token helper, the word wrapper, and
# the page-budget walk with its budget constant)
# are NOT here -- they are extracted mechanically from install-from-disk.praat
# by emlManagerCifGenerateWrapper and spliced in ahead of this block, never
# hand-copied. No further canon is needed: the wrapper has no selection
# checklist, so the label-capping machinery (emlManagerMiddleEllipsis and
# everything built on it) has nothing to do here.
# ============================================================================

emlManagerCif_staticTemplate$# = {
    ... "wrapOldPrefix$ = ""old_""",
    ... "wrapFloorMajor = 6",
    ... "wrapFloorMinor = 6",
    ... "wrapFloorMicro = 30",
    ... "wrapFloorVersionNum = wrapFloorMajor * 1000 + wrapFloorMinor * 100 + wrapFloorMicro",
    ... "wrapFloorVersionLabel$ = string$ (wrapFloorMajor) + ""."" + string$ (wrapFloorMinor) + ""."" + string$ (wrapFloorMicro)",
    ... "",
    ... "wrapTitleVersionFail$ = ""Praat too old""",
    ... "wrapTitleMissing$ = ""Cannot install""",
    ... "wrapTitleAlready$ = ""Already installed""",
    ... "wrapTitleFailed$ = ""Install failed""",
    ... "wrapTitleComplete$ = ""Installed""",
    ... "wrapBtnOK$ = ""OK""",
    ... "wrapBtnNext$ = ""Next""",
    ... "wrapPagePrefix$ = "" (page """,
    ... "wrapPageMid$ = "" of """,
    ... "wrapPageSuffix$ = "")""",
    ... "wrapBtnQuit$ = ""Quit""",
    ... "wrapBtnKeep$ = ""Keep a backup and install""",
    ... "wrapLabelDelete$ = ""Delete the installed copy instead""",
    ... "wrapMsgVersionFailPrefix$ = ""This script requires Praat """,
    ... "wrapMsgVersionFailMid$ = "" or newer. You have """,
    ... "wrapMsgVersionFailSuffix$ = "". Please update Praat from praat.org and try again.""",
    ... "wrapMsgMissingSuffix$ = "" is missing. Re-download the plugin.""",
    ... "wrapMsgDeleteNote$ = ""The installed copy is deleted, not archived. The EML Plugin Manager archives before replacing.""",
    ... "wrapMsgRenamedPrefix$ = ""The current copy is renamed to """,
    ... "wrapMsgRenamedSuffix$ = "". Praat ignores folders that do not start with plugin_; delete it by hand when you no longer want it.""",
    ... "wrapMsgReusedLeftover$ = ""Reused a leftover folder from an earlier removal.""",
    ... "wrapMsgRestart$ = ""Restart Praat.""",
    ... "wrapMsgIncompleteSuffix$ = "" is missing from the installed copy. The copy is incomplete and may be deleted by hand.""",
    ... "wrapMsgActionFailSuffix$ = "" failed. Nothing else was touched.""",
    ... "wrapActionRename$ = ""Renaming the installed copy""",
    ... "wrapActionDelete$ = ""Deleting the installed copy""",
    ... "wrapStatusNewer$ = ""This installer is newer.""",
    ... "wrapStatusSame$ = ""Same version.""",
    ... "wrapStatusOlder$ = ""The installed copy is newer.""",
    ... "wrapStatusUnknown$ = ""Versions cannot be compared.""",
    ... "wrapUnknownVersion$ = ""unknown""",
    ... "wrapLabelInstalledVersion$ = ""Installed version: """,
    ... "wrapLabelThisVersion$ = ""This installer's version: """,
    ... "wrapMidVersion$ = "" version """,
    ... "wrapMsgInstalledSuffix$ = "" installed.""",
    ... "wrapTitleAlreadyInPlace$ = ""Install: already in place""",
    ... "wrapLabelFolder$ = ""Folder: """,
    ... "wrapMsgAlreadyInPlace$ = ""This install file is running from inside the installed copy itself, so there is nothing to install.""",
    ... "",
    ... "procedure wrapEmitWrapped: .text$",
    ... "    @emlManagerWrapText: .text$, emlManager_wrapWidth",
    ... "    for .wi to size (emlManagerWrapText.lines$#)",
    ... "        comment: emlManagerWrapText.lines$# [.wi]",
    ... "    endfor",
    ... "endproc",
    ... "",
    ... "procedure wrapNoticeExit: .title$, .text$",
    ... "    beginPause: .title$",
    ... "        @wrapEmitWrapped: .text$",
    ... "    endPause: wrapBtnOK$, 1, 0",
    ... "    exitScript ( )",
    ... "endproc",
    ... "",
    ... "procedure wrapVerifyManifestUnder: .root$",
    ... "    .ok = 1",
    ... "    .missingPath$ = """"",
    ... "    .i = 1",
    ... "    .n = size (wrapManifestPath$#)",
    ... "    while .ok = 1 and .i <= .n",
    ... "        if not fileReadable (.root$ + ""/"" + wrapManifestPath$# [.i])",
    ... "            .ok = 0",
    ... "            .missingPath$ = wrapManifestPath$# [.i]",
    ... "        endif",
    ... "        .i = .i + 1",
    ... "    endwhile",
    ... "endproc",
    ... "",
    ... "procedure wrapReadVersionFile: .folderPath$",
    ... "    .version$ = """"",
    ... "    .path$ = .folderPath$ + ""/VERSION""",
    ... "    if fileReadable (.path$)",
    ... "        .lines$# = readLinesFromFile$# (.path$)",
    ... "        if size (.lines$#) >= 1",
    ... "            .raw$ = .lines$# [1]",
    ... "            while length (.raw$) > 0 and (left$ (.raw$, 1) = "" "" or left$ (.raw$, 1) = tab$)",
    ... "                .raw$ = right$ (.raw$, length (.raw$) - 1)",
    ... "            endwhile",
    ... "            while length (.raw$) > 0 and (right$ (.raw$, 1) = "" "" or right$ (.raw$, 1) = tab$)",
    ... "                .raw$ = left$ (.raw$, length (.raw$) - 1)",
    ... "            endwhile",
    ... "            .version$ = .raw$",
    ... "        endif",
    ... "    endif",
    ... "endproc",
    ... "",
    ... "procedure wrapNormalizePath: .path$",
    ... "    .result$ = replace$ (.path$, ""\"", ""/"", 0)",
    ... "    while length (.result$) > 0 and right$ (.result$, 1) = ""/""",
    ... "        .result$ = left$ (.result$, length (.result$) - 1)",
    ... "    endwhile",
    ... "endproc",
    ... "",
    ... "procedure wrapCheckSelfInstall: .scriptFolder$, .destPath$",
    ... "    @wrapNormalizePath: .scriptFolder$",
    ... "    .normScript$ = wrapNormalizePath.result$",
    ... "    @wrapNormalizePath: .destPath$",
    ... "    .normDest$ = wrapNormalizePath.result$",
    ... "    .fires = 0",
    ... "    if .normScript$ = .normDest$",
    ... "        .fires = 1",
    ... "    elsif startsWith (.normScript$, .normDest$ + ""/"")",
    ... "        .fires = 1",
    ... "    endif",
    ... "endproc",
    ... "",
    ... "procedure wrapDetermineStatus: .installedVersion$, .thisVersion$",
    ... "    if .installedVersion$ = """"",
    ... "        .statusLine$ = wrapStatusUnknown$",
    ... "        .defaultBtn = 1",
    ... "    else",
    ... "        @emlManagerCompareVersions: .thisVersion$, .installedVersion$",
    ... "        .cmp = emlManagerCompareVersions.cmp",
    ... "        if .cmp = 1",
    ... "            .statusLine$ = wrapStatusNewer$",
    ... "            .defaultBtn = 2",
    ... "        elsif .cmp = 0",
    ... "            .statusLine$ = wrapStatusSame$",
    ... "            .defaultBtn = 1",
    ... "        else",
    ... "            .statusLine$ = wrapStatusOlder$",
    ... "            .defaultBtn = 1",
    ... "        endif",
    ... "    endif",
    ... "endproc",
    ... "",
    ... "procedure wrapComputeOldName: .prefsDir$, .folderName$",
    ... "    .base$ = wrapOldPrefix$ + .folderName$",
    ... "    .destName$ = .base$",
    ... "    .n = 2",
    ... "    while folderExists (.prefsDir$ + ""/"" + .destName$)",
    ... "        .destName$ = .base$ + ""_"" + string$ (.n)",
    ... "        .n = .n + 1",
    ... "    endwhile",
    ... "endproc",
    ... "",
    ... "procedure wrapDoRename: .prefsDir$, .folderName$, .oldName$",
    ... "    .src$ = .prefsDir$ + ""/"" + .folderName$",
    ... "    .dst$ = .prefsDir$ + ""/"" + .oldName$",
    ... "    .q$ = """"""""",
    ... "    if macintosh or unix",
    ... "        runSystem_nocheck: ""mv "" + .q$ + .src$ + .q$ + "" "" + .q$ + .dst$ + .q$",
    ... "    elsif windows",
    ... "        runSystem_nocheck: ""move "" + .q$ + .src$ + .q$ + "" "" + .q$ + .dst$ + .q$",
    ... "    endif",
    ... "    .ok = folderExists (.dst$) and not folderExists (.src$)",
    ... "endproc",
    ... "",
    ... "procedure wrapDoDelete: .prefsDir$, .folderName$",
    ... "    .target$ = .prefsDir$ + ""/"" + .folderName$",
    ... "    .q$ = """"""""",
    ... "    if macintosh or unix",
    ... "        runSystem_nocheck: ""rm -rf "" + .q$ + .target$ + .q$",
    ... "    elsif windows",
    ... "        runSystem_nocheck: ""rmdir /s /q "" + .q$ + .target$ + .q$",
    ... "    endif",
    ... "    .ok = not folderExists (.target$)",
    ... "endproc",
    ... "",
    ... "procedure wrapDoPlace: .scriptFolder$, .prefsDir$, .folderName$",
    ... "    .dst$ = .prefsDir$ + ""/"" + .folderName$",
    ... "    createFolder: .dst$",
    ... "    .q$ = """"""""",
    ... "    if macintosh or unix",
    ... "        runSystem_nocheck: ""cp -R "" + .q$ + .scriptFolder$ + ""/."" + .q$ + "" "" + .q$ + .dst$ + .q$",
    ... "    elsif windows",
    ... "        runSystem_nocheck: ""xcopy /E /I /Q "" + .q$ + .scriptFolder$ + .q$ + "" "" + .q$ + .dst$ + .q$",
    ... "    endif",
    ... "    .ok = folderExists (.dst$)",
    ... "endproc",
    ... "",
    ... "# The completion lines and, per line, whether it continues the entry",
    ... "# before it (1) -- the page walk keeps those together on one page.",
    ... "procedure wrapBuildCompletionLines: .wasGhostReused",
    ... "    .n = size (wrapReportLines$#) + 3",
    ... "    if .wasGhostReused = 1",
    ... "        .n = .n + 1",
    ... "    endif",
    ... "    .lines$# = empty$# (.n)",
    ... "    .keep# = zero# (.n)",
    ... "    .lines$# [1] = wrapFolderName$ + wrapMidVersion$ + wrapVersion$ + wrapMsgInstalledSuffix$",
    ... "    .idx = 1",
    ... "    for .ri to size (wrapReportLines$#)",
    ... "        .idx = .idx + 1",
    ... "        .lines$# [.idx] = wrapReportLines$# [.ri]",
    ... "        .keep# [.idx] = wrapReportKeep# [.ri]",
    ... "    endfor",
    ... "    if .wasGhostReused = 1",
    ... "        .idx = .idx + 1",
    ... "        .lines$# [.idx] = wrapMsgReusedLeftover$",
    ... "    endif",
    ... "    .idx = .idx + 1",
    ... "    .lines$# [.idx] = """"",
    ... "    .idx = .idx + 1",
    ... "    .lines$# [.idx] = wrapMsgRestart$",
    ... "    .keep# [.idx] = 1",
    ... "endproc",
    ... "",
    ... "if not variableExists (""wrapHarnessMode"")",
    ... "",
    ... "    if praatVersion < wrapFloorVersionNum",
    ... "        @wrapNoticeExit: wrapTitleVersionFail$,",
    ... "            ... wrapMsgVersionFailPrefix$ + wrapFloorVersionLabel$",
    ... "            ... + wrapMsgVersionFailMid$ + praatVersion$ + wrapMsgVersionFailSuffix$",
    ... "    endif",
    ... "",
    ... "    scriptFolder$ = defaultDirectory$",
    ... "    prefsDir$ = preferencesDirectory$",
    ... "    destPath$ = prefsDir$ + ""/"" + wrapFolderName$",
    ... "",
    ... "    @wrapCheckSelfInstall: scriptFolder$, destPath$",
    ... "    if wrapCheckSelfInstall.fires = 1",
    ... "        @wrapReadVersionFile: destPath$",
    ... "        wrapGuardInstalledVersion$ = wrapReadVersionFile.version$",
    ... "        beginPause: wrapTitleAlreadyInPlace$",
    ... "            @wrapEmitWrapped: wrapLabelFolder$ + wrapFolderName$",
    ... "            @wrapEmitWrapped: wrapLabelThisVersion$ + wrapVersion$",
    ... "            @wrapEmitWrapped: wrapMsgAlreadyInPlace$",
    ... "            if wrapGuardInstalledVersion$ = """"",
    ... "                @wrapEmitWrapped: wrapLabelInstalledVersion$ + wrapUnknownVersion$",
    ... "            else",
    ... "                @wrapEmitWrapped: wrapLabelInstalledVersion$ + wrapGuardInstalledVersion$",
    ... "            endif",
    ... "        endPause: wrapBtnOK$, 1, 0",
    ... "        exitScript ( )",
    ... "    endif",
    ... "",
    ... "    @wrapVerifyManifestUnder: scriptFolder$",
    ... "    if wrapVerifyManifestUnder.ok = 0",
    ... "        @wrapNoticeExit: wrapTitleMissing$,",
    ... "            ... wrapVerifyManifestUnder.missingPath$ + wrapMsgMissingSuffix$",
    ... "    endif",
    ... "",
    ... "    wasGhostReused = 0",
    ... "",
    ... "    if folderExists (destPath$)",
    ... "        @emlManagerIsInstalled: destPath$",
    ... "        if emlManagerIsInstalled.installed = 1",
    ... "            @wrapReadVersionFile: destPath$",
    ... "            installedVersion$ = wrapReadVersionFile.version$",
    ... "            @wrapDetermineStatus: installedVersion$, wrapVersion$",
    ... "            statusLine$ = wrapDetermineStatus.statusLine$",
    ... "            defaultBtn = wrapDetermineStatus.defaultBtn",
    ... "",
    ... "            @wrapComputeOldName: prefsDir$, wrapFolderName$",
    ... "            oldName$ = wrapComputeOldName.destName$",
    ... "",
    ... "            if installedVersion$ = """"",
    ... "                installedLine$ = wrapLabelInstalledVersion$ + wrapUnknownVersion$",
    ... "            else",
    ... "                installedLine$ = wrapLabelInstalledVersion$ + installedVersion$",
    ... "            endif",
    ... "",
    ... "            beginPause: wrapTitleAlready$",
    ... "                @wrapEmitWrapped: installedLine$",
    ... "                @wrapEmitWrapped: wrapLabelThisVersion$ + wrapVersion$",
    ... "                @wrapEmitWrapped: statusLine$",
    ... "                comment: """"",
    ... "                @wrapEmitWrapped: wrapMsgRenamedPrefix$ + oldName$ + wrapMsgRenamedSuffix$",
    ... "                comment: """"",
    ... "                boolean: wrapLabelDelete$, 0",
    ... "                @wrapEmitWrapped: wrapMsgDeleteNote$",
    ... "            clicked = endPause: wrapBtnQuit$, wrapBtnKeep$, defaultBtn, 0",
    ... "",
    ... "            if clicked = 1",
    ... "                exitScript ( )",
    ... "            endif",
    ... "",
    ... "            # The boolean's own Praat-derived readback name, used directly",
    ... "            # -- same convention install-from-disk.praat's own main",
    ... "            # sequence uses for use_folder_names_exactly_as_found: a",
    ... "            # fixed label's derived name hardcoded once rather than",
    ... "            # rederived at runtime (the label-derivation canon is not",
    ... "            # embedded here -- see the block comment above this template).",
    ... "            deleteOn = delete_the_installed_copy_instead",
    ... "",
    ... "            if deleteOn = 1",
    ... "                @wrapDoDelete: prefsDir$, wrapFolderName$",
    ... "                if wrapDoDelete.ok = 0",
    ... "                    @wrapNoticeExit: wrapTitleFailed$, wrapActionDelete$ + wrapMsgActionFailSuffix$",
    ... "                endif",
    ... "            else",
    ... "                @wrapDoRename: prefsDir$, wrapFolderName$, oldName$",
    ... "                if wrapDoRename.ok = 0",
    ... "                    @wrapNoticeExit: wrapTitleFailed$, wrapActionRename$ + wrapMsgActionFailSuffix$",
    ... "                endif",
    ... "            endif",
    ... "        else",
    ... "            wasGhostReused = 1",
    ... "        endif",
    ... "    endif",
    ... "",
    ... "    @wrapDoPlace: scriptFolder$, prefsDir$, wrapFolderName$",
    ... "",
    ... "    @wrapVerifyManifestUnder: destPath$",
    ... "    if wrapVerifyManifestUnder.ok = 0",
    ... "        @wrapNoticeExit: wrapTitleFailed$,",
    ... "            ... wrapVerifyManifestUnder.missingPath$ + wrapMsgIncompleteSuffix$",
    ... "    endif",
    ... "",
    ... "    # The completion dialog is paged by the manager's page budget (the",
    ... "    # rendered height of each line, in pixels), so every command is shown",
    ... "    # with its buttons on screen however many the plugin registers.",
    ... "    @wrapBuildCompletionLines: wasGhostReused",
    ... "    wrapNLines = wrapBuildCompletionLines.n",
    ... "    wrapLineWeights# = zero# (wrapNLines)",
    ... "    for wrapCi to wrapNLines",
    ... "        @emlManagerWrappedPx: wrapBuildCompletionLines.lines$# [wrapCi], 0",
    ... "        wrapLineWeights# [wrapCi] = emlManagerWrappedPx.px",
    ... "    endfor",
    ... "    @emlManagerPageMetrics",
    ... "    @emlManagerPageBudgetWalk: wrapLineWeights#, wrapBuildCompletionLines.keep#, wrapNLines,",
    ... "        ... emlManagerPageMetrics.budgetPx, 0, 0",
    ... "    wrapNPages = emlManagerPageBudgetWalk.nPages",
    ... "    wrapPageStart# = emlManagerPageBudgetWalk.pageStartItem#",
    ... "    wrapPageEnd# = emlManagerPageBudgetWalk.pageEndItem#",
    ... "    for wrapPi to wrapNPages",
    ... "        if wrapNPages = 1",
    ... "            wrapPageTitle$ = wrapTitleComplete$",
    ... "        else",
    ... "            wrapPageTitle$ = wrapTitleComplete$ + wrapPagePrefix$ + string$ (wrapPi)",
    ... "                ... + wrapPageMid$ + string$ (wrapNPages) + wrapPageSuffix$",
    ... "        endif",
    ... "        beginPause: wrapPageTitle$",
    ... "            for wrapCi from wrapPageStart# [wrapPi] to wrapPageEnd# [wrapPi]",
    ... "                @wrapEmitWrapped: wrapBuildCompletionLines.lines$# [wrapCi]",
    ... "            endfor",
    ... "        if wrapPi < wrapNPages",
    ... "            endPause: wrapBtnNext$, 1, 0",
    ... "        else",
    ... "            endPause: wrapBtnOK$, 1, 0",
    ... "        endif",
    ... "    endfor",
    ... "    exitScript ( )",
    ... "",
    ... "endif" }

# ============================================================================
# Top-level generation
# ============================================================================

# ----------------------------------------------------------------------------
# Writes install-<stem>.praat into .pluginPath$ (.folderName$ without the
# plugin_ prefix is <stem>), where .folderName$ is the plugin's TRUE folder
# name (never re-derived from a path) and .version$ is the value already
# written to VERSION by the caller. .ok = 0 only when the four embedded
# canons -- or the constants they depend on -- could not be located in
# this manager's own install-from-disk.praat (a manager file that failed to
# parse at all would already have stopped this script earlier via the
# include above, so in practice .ok = 0 signals a renamed procedure/constant
# that this module's extraction prefixes no longer match).
# Generation-time ASCII guard: .out$ has every character outside
# printable ASCII replaced with "?"; .hadNonAscii reports whether any
# replacement happened. Report text is cosmetic and is sanitized;
# a folder name is load-bearing in paths and refuses generation
# instead (checked at the call site).
procedure emlManagerCifAsciiSanitize: .text$
    .out$ = ""
    .hadNonAscii = 0
    .len = length (.text$)
    for .i from 1 to .len
        .c$ = mid$ (.text$, .i, 1)
        if index (emlManagerCif_ascii$, .c$) > 0
            .out$ = .out$ + .c$
        else
            .out$ = .out$ + "?"
            .hadNonAscii = 1
        endif
    endfor
endproc

procedure emlManagerCifGenerateWrapper: .pluginPath$, .folderName$, .version$, .scratchFile$
    .ok = 0
    .wrapperFileName$ = ""

    .stem$ = .folderName$
    if startsWith (.stem$, emlManager_pluginPrefix$)
        .stem$ = right$ (.stem$, length (.stem$) - length (emlManager_pluginPrefix$))
    endif
    .thisWrapperFileName$ = emlManagerCif_wrapperPrefix$ + .stem$ + emlManagerCif_wrapperExt$
    .outPath$ = .pluginPath$ + "/" + .thisWrapperFileName$

    @emlManagerCifBuildManifest: .pluginPath$, .thisWrapperFileName$, .scratchFile$
    .manifestCount = emlManagerCifBuildManifest.n
    @emlManagerCifSerializeArray: emlManagerCifBuildManifest.paths$#, .manifestCount
    .manifestLine$ = "wrapManifestPath$# = " + emlManagerCifSerializeArray.out$

    @emlManagerCifBuildReportLines: .pluginPath$ + "/" + emlManager_setupFile$, emlManager_wrapWidth
    .reportCount = emlManagerCifBuildReportLines.n
    # ASCII guard on baked report text (non-ASCII becomes "?").
    for .iRep from 1 to .reportCount
        @emlManagerCifAsciiSanitize: emlManagerCifBuildReportLines.lines$# [.iRep]
        emlManagerCifBuildReportLines.lines$# [.iRep] = emlManagerCifAsciiSanitize.out$
    endfor
    @emlManagerCifSerializeArray: emlManagerCifBuildReportLines.lines$#, .reportCount
    .reportLine$ = "wrapReportLines$# = " + emlManagerCifSerializeArray.out$
    @emlManagerCifSerializeNumbers: emlManagerCifBuildReportLines.keep#, .reportCount
    .reportKeepLine$ = "wrapReportKeep# = " + emlManagerCifSerializeNumbers.out$

    @emlManagerCifReadInstallerSource
    .sourceLines$# = emlManagerCifReadInstallerSource.lines$#

    @emlManagerCifExtractLine: .sourceLines$#, "emlManager_setupFile$ ="
    .constSetupFileOk = emlManagerCifExtractLine.found
    .constSetupFile$ = emlManagerCifExtractLine.line$
    @emlManagerCifExtractLine: .sourceLines$#, "emlManager_wrapWidth ="
    .constWrapWidthOk = emlManagerCifExtractLine.found
    .constWrapWidth$ = emlManagerCifExtractLine.line$

    @emlManagerCifExtractBlock: .sourceLines$#, "emlManagerIsInstalled"
    .blockInstalled$# = emlManagerCifExtractBlock.block$#
    .nInstalled = emlManagerCifExtractBlock.n
    .foundInstalled = emlManagerCifExtractBlock.found
    @emlManagerCifExtractBlock: .sourceLines$#, "emlManagerIsNumericToken"
    .blockNumeric$# = emlManagerCifExtractBlock.block$#
    .nNumeric = emlManagerCifExtractBlock.n
    .foundNumeric = emlManagerCifExtractBlock.found
    @emlManagerCifExtractBlock: .sourceLines$#, "emlManagerCompareVersions"
    .blockCompare$# = emlManagerCifExtractBlock.block$#
    .nCompare = emlManagerCifExtractBlock.n
    .foundCompare = emlManagerCifExtractBlock.found
    @emlManagerCifExtractBlock: .sourceLines$#, "emlManagerWrapText"
    .blockWrap$# = emlManagerCifExtractBlock.block$#
    .nWrap = emlManagerCifExtractBlock.n
    .foundWrap = emlManagerCifExtractBlock.found
    @emlManagerCifExtractBlock: .sourceLines$#, "emlManagerPageMetrics"
    .blockMetrics$# = emlManagerCifExtractBlock.block$#
    .nMetrics = emlManagerCifExtractBlock.n
    .foundMetrics = emlManagerCifExtractBlock.found
    @emlManagerCifExtractBlock: .sourceLines$#, "emlManagerLinePx"
    .blockLinePx$# = emlManagerCifExtractBlock.block$#
    .nLinePx = emlManagerCifExtractBlock.n
    .foundLinePx = emlManagerCifExtractBlock.found
    @emlManagerCifExtractBlock: .sourceLines$#, "emlManagerWrappedPx"
    .blockWrappedPx$# = emlManagerCifExtractBlock.block$#
    .nWrappedPx = emlManagerCifExtractBlock.n
    .foundWrappedPx = emlManagerCifExtractBlock.found
    @emlManagerCifExtractBlock: .sourceLines$#, "emlManagerPageBudgetWalk"
    .blockPageWalk$# = emlManagerCifExtractBlock.block$#
    .nPageWalk = emlManagerCifExtractBlock.n
    .foundPageWalk = emlManagerCifExtractBlock.found

    .allFound = 1
    if .constSetupFileOk = 0 or .constWrapWidthOk = 0
        ... or .foundPageWalk = 0 or .foundMetrics = 0 or .foundLinePx = 0
        ... or .foundWrappedPx = 0 or .foundInstalled = 0 or .foundNumeric = 0
        ... or .foundCompare = 0 or .foundWrap = 0
        .allFound = 0
    endif

    if .allFound = 1
        @emlManagerCifAppendLines: .outPath$, emlManagerCif_headerLines$#,
            ... size (emlManagerCif_headerLines$#), 1

        .folderLine$ = "wrapFolderName$ = """ + .folderName$ + """"
        .versionLine$ = "wrapVersion$ = """ + .version$ + """"
        .bakedLines$# = { .folderLine$, .versionLine$, .manifestLine$, .reportLine$,
            ... .reportKeepLine$ }
        @emlManagerCifAppendLines: .outPath$, .bakedLines$#, 5, 0

        .constLines$# = { .constSetupFile$, .constWrapWidth$ }
        @emlManagerCifAppendLines: .outPath$, .constLines$#, 2, 0

        @emlManagerCifAppendLines: .outPath$, .blockInstalled$#, .nInstalled, 0
        @emlManagerCifAppendLines: .outPath$, .blockNumeric$#, .nNumeric, 0
        @emlManagerCifAppendLines: .outPath$, .blockCompare$#, .nCompare, 0
        @emlManagerCifAppendLines: .outPath$, .blockWrap$#, .nWrap, 0
        @emlManagerCifAppendLines: .outPath$, .blockMetrics$#, .nMetrics, 0
        @emlManagerCifAppendLines: .outPath$, .blockLinePx$#, .nLinePx, 0
        @emlManagerCifAppendLines: .outPath$, .blockWrappedPx$#, .nWrappedPx, 0
        @emlManagerCifAppendLines: .outPath$, .blockPageWalk$#, .nPageWalk, 0

        @emlManagerCifAppendLines: .outPath$, emlManagerCif_staticTemplate$#,
            ... size (emlManagerCif_staticTemplate$#), 0

        .ok = 1
        .wrapperFileName$ = .thisWrapperFileName$
    endif
endproc

# ----------------------------------------------------------------------------
# Emits .text$ inside the pause form currently being built, one comment
# field per wrapped line (pause-window comment fields do not wrap on their
# own). Reuses the shared word-wrapping procedure. Called only between a
# beginPause and its endPause. This module's own copy of the same small
# helper remove-plugin.praat and install-from-disk.praat each keep
# (emlManagerRemoveEmitWrapped / the installer's inline wrap loop) -- every
# module that builds pause-form text wraps through the one shared
# emlManagerWrapText canon, never its own reimplementation of wrapping.
procedure emlManagerCifEmitWrapped: .text$
    @emlManagerWrapText: .text$, emlManager_wrapWidth
    for .wi to size (emlManagerWrapText.lines$#)
        comment: emlManagerWrapText.lines$# [.wi]
    endfor
endproc

# ============================================================================
# Main sequence
# ============================================================================
# Skipped when this file is included by the test harness (which sets
# emlManagerCif_harnessMode = 1 before the include, exactly as
# emlManager_harnessMode/emlManagerRemove_harnessMode suppress the other
# modules' own main sequences), so the harness can drive the work
# procedures above directly, with the chosen plugin and version passed in
# as explicit arguments, and no dialog shown.

if not variableExists ("emlManagerCif_harnessMode")

    @emlManagerVersionOk
    if emlManagerVersionOk.ok = 0
        exitScript: emlManager_msgVersionFail$ + praatVersion$ + emlManager_msgVersionSuffix$
    endif

    prefsDir$ = preferencesDirectory$

    @emlManagerMakeStaging
    if emlManagerMakeStaging.ok = 0
        exitScript: emlManager_msgStagingFail$
    endif
    scratchDir$ = emlManagerMakeStaging.path$

    # --- Dialog 1: which installed plugin, or another folder (part 2) ---

    @emlManagerCifListInstalled: prefsDir$
    nInstalled = emlManagerCifListInstalled.n
    names$# = emlManagerCifListInstalled.names$#
    labels$# = emlManagerCifListInstalled.labels$#

    # "Another folder" is the first and default choice: packaging a plugin
    # that is not installed is the usual job. Installed plugins follow it,
    # so the menu always offers at least the folder choice.
    beginPause: emlManagerCif_title1$
        optionMenu: emlManagerCif_pluginFieldLabel$, emlManagerCif_anotherFolderIndex
            option: emlManagerCif_anotherFolderLabel$
            for iOpt to nInstalled
                option: labels$# [iOpt]
            endfor
    clicked1 = endPause: emlManagerCif_btnQuit$, emlManagerCif_btnContinue$, 2, 0
    if clicked1 = 1
        @emlManagerCleanupStaging: scratchDir$
        exitScript: emlManagerCif_msgCancelled$
    endif

    usingFolderSource = 0
    if plugin = emlManagerCif_anotherFolderIndex
        usingFolderSource = 1
    endif

    if usingFolderSource = 1

        # --- Folder-source path: the author's dev copy, outside prefsDir$ ---

        chosenFolder$ = chooseFolder$: emlManagerCif_chooseFolderTitle$
        if chosenFolder$ = ""
            @emlManagerCleanupStaging: scratchDir$
            exitScript: emlManagerCif_msgCancelled$
        endif

        @emlManagerCifValidateFolderSource: chosenFolder$
        pluginFolderName$ = emlManagerCifValidateFolderSource.name$
        pluginPath$ = emlManagerCifValidateFolderSource.path$

        if emlManagerCifValidateFolderSource.result$ = "bad_prefix"
            # (a) the folder name must begin with plugin_ -- Praat's own
            #     activation rule; no auto-rename (offer-never-force), and
            #     here we do not even offer, since renaming the author's dev
            #     folder is not this command's business.
            @emlManagerCleanupStaging: scratchDir$
            beginPause: emlManagerCif_titleBadFolderName$
                @emlManagerCifEmitWrapped: emlManagerCif_msgBadFolderNamePrefix$
                    ... + pluginFolderName$ + emlManagerCif_msgBadFolderNameSuffix$
            endPause: emlManagerCif_btnOK$, 1, 0
            exitScript ( )
        elsif emlManagerCifValidateFolderSource.result$ = "no_setup"
            # (b) must contain a top-level setup.praat -- the
            #     installed-iff-setup canon, reused via
            #     emlManagerCifValidateFolderSource, never reimplemented.
            @emlManagerCleanupStaging: scratchDir$
            beginPause: emlManagerCif_titleNoSetup$
                @emlManagerCifEmitWrapped: emlManagerCif_msgNoSetupPrefix$
                    ... + pluginFolderName$ + emlManagerCif_msgNoSetupSuffix$
            endPause: emlManagerCif_btnOK$, 1, 0
            exitScript ( )
        elsif emlManagerCifValidateFolderSource.result$ = "non_ascii"
            # (c) the existing non-ASCII name refusal applies unchanged.
            @emlManagerCleanupStaging: scratchDir$
            beginPause: emlManagerCif_titleNonAsciiName$
                @emlManagerCifEmitWrapped: emlManagerCif_msgNonAsciiName$
            endPause: emlManagerCif_btnOK$, 1, 0
            exitScript ( )
        endif

    else

        # --- Installed-plugin path: unchanged ---

        pluginFolderName$ = names$# [plugin - emlManagerCif_anotherFolderIndex]
        pluginPath$ = prefsDir$ + "/" + pluginFolderName$

        # ASCII guard: a non-ASCII folder name refuses generation.
        @emlManagerCifAsciiSanitize: pluginFolderName$
        if emlManagerCifAsciiSanitize.hadNonAscii = 1
            @emlManagerCleanupStaging: scratchDir$
            beginPause: emlManagerCif_titleNonAsciiName$
                @emlManagerCifEmitWrapped: emlManagerCif_msgNonAsciiName$
            endPause: emlManagerCif_btnOK$, 1, 0
            exitScript ( )
        endif

    endif

    # --- Dialog 2: version, looping on an invalid entry until Quit or a
    #     valid value is accepted ---

    @emlManagerReadVersion: pluginPath$
    prefillVersion$ = emlManagerReadVersion.version$
    if prefillVersion$ = ""
        prefillVersion$ = emlManagerCif_defaultVersion$
    endif

    versionAccepted = 0
    while versionAccepted = 0
        beginPause: emlManagerCif_title2$
            sentence: emlManagerCif_versionFieldLabel$, prefillVersion$
            comment: emlManagerCif_versionHint$
        clicked2 = endPause: emlManagerCif_btnQuit$, emlManagerCif_btnContinue$, 2, 0
        if clicked2 = 1
            @emlManagerCleanupStaging: scratchDir$
            exitScript: emlManagerCif_msgCancelled$
        endif

        # Carried forward as the next prefill on a rejected attempt, so the
        # user's own typed text is not lost, per the pinned "the dialog
        # again" retry.
        prefillVersion$ = version$

        @emlManagerCifVersionValid: version$
        if emlManagerCifVersionValid.ok = 1
            versionAccepted = 1
        else
            beginPause: emlManagerCif_titleBadVersion$
                comment: emlManagerCif_versionHint$
            endPause: emlManagerCif_btnOK$, 1, 0
        endif
    endwhile

    @emlManagerCifWriteVersion: pluginPath$, version$

    # --- Generation ---

    @emlManagerCifGenerateWrapper: pluginPath$, pluginFolderName$, version$, scratchDir$ + "/eml_pm_cif_scratch.txt"
    @emlManagerCleanupStaging: scratchDir$

    if emlManagerCifGenerateWrapper.ok = 0
        beginPause: emlManagerCif_titleGenFailed$
            comment: emlManagerCif_msgGenFailed$
        endPause: emlManagerCif_btnOK$, 1, 0
        exitScript ( )
    endif

    @emlManagerLogPath: emlManagerCif_logEventWroteTo$, pluginPath$
    beginPause: emlManagerCif_titleComplete$
        comment: emlManagerCif_msgWroteToPrefix$ + emlManagerCifGenerateWrapper.wrapperFileName$
            ... + emlManagerCif_msgWroteToMid$ + pluginFolderName$ + "."
        @emlManagerCifEmitWrapped: emlManager_msgSeePathInInfo$
        comment: string$ (emlManagerCifGenerateWrapper.manifestCount) + emlManagerCif_msgManifestSuffix$
        comment: ""
        @emlManagerCifEmitWrapped: emlManagerCif_msgRegenReminder$
    endPause: emlManagerCif_btnOK$, 1, 0

endif
