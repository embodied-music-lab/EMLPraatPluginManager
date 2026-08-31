# EML Plugin Manager bootstrap installer.
# Creates plugin_EMLPluginManager in Praat's preferences folder and
# writes its payload files.
#
# ATTRIBUTION
# Framework: EML PraatGen by Ian Howell
#            Embodied Music Lab -- www.embodiedmusiclab.com
#            https://github.com/embodied-music-lab/PraatGen
# Code generation: Claude (Anthropic)

folderName$ = "plugin_EMLPluginManager"
prefDir$ = preferencesDirectory$
targetFolder$ = prefDir$ + "/" + folderName$
payloadVersion$ = "0.1.0"

floorMajor = 6
floorMinor = 6
floorMicro = 30
floorVersionNum = floorMajor * 1000 + floorMinor * 100 + floorMicro
floorVersionLabel$ = string$ (floorMajor) + "." + string$ (floorMinor) + "." + string$ (floorMicro)

manifestPath$# = { "setup.praat", "about.praat", "README.txt", "VERSION" }
manifestLines# = { 1, 5, 3, 1 }

msgDialogTitle$ = "Install EML Plugin Manager"
msgDialogBody$ = "This installs the EML Plugin Manager into your Praat preferences folder. Nothing else on your computer is touched. Praat may ask for permission to write files; choose ""Approve for this session""."
msgTooOld$ = "This installer needs Praat " + floorVersionLabel$ + " or newer. You have " + praatVersion$ + ". Please update Praat from praat.org and run this installer again."
msgAlreadyInstalled$ = "EML Plugin Manager is already installed. To update or repair it, use the Plugin manager menu inside Praat."
msgSuccess$ = "Installed. Restart Praat to activate the Plugin manager menu."

procedure emlpmB_versionOk
  emlpmB_versionOk.result = 0
  if praatVersion >= floorVersionNum
    emlpmB_versionOk.result = 1
  endif
endproc

procedure emlpmB_alreadyInstalled
  emlpmB_alreadyInstalled.result = 0
  if folderExists (targetFolder$)
    if fileReadable (targetFolder$ + "/VERSION")
      emlpmB_alreadyInstalled.result = 1
    endif
  endif
endproc

procedure emlpmB_writeSetup
  file$ = targetFolder$ + "/setup.praat"
  writeFileLine: file$, "Add menu command: ""Objects"", ""Praat"", ""EML Plugin Manager: About"", """", 0, ""about.praat"""
endproc

procedure emlpmB_writeAbout
  file$ = targetFolder$ + "/about.praat"
  writeFileLine: file$, "folder$ = preferencesDirectory$ + ""/plugin_EMLPluginManager"""
  appendFileLine: file$, "version$# = readLinesFromFile$# (folder$ + ""/VERSION"")"
  appendFileLine: file$, "writeInfoLine: ""EML Plugin Manager"""
  appendFileLine: file$, "appendInfoLine: version$# [1]"
  appendFileLine: file$, "appendInfoLine: ""The full manager arrives in a later build."""
endproc

procedure emlpmB_writeReadme
  file$ = targetFolder$ + "/README.txt"
  writeFileLine: file$, "This folder contains the EML Plugin Manager."
  appendFileLine: file$, "It was installed by the EML Plugin Manager bootstrap installer."
  appendFileLine: file$, "It can be managed from the Plugin manager menu in a later build."
endproc

procedure emlpmB_writePayload
  if not folderExists (targetFolder$)
    createFolder: targetFolder$
  endif
  @emlpmB_writeSetup
  @emlpmB_writeAbout
  @emlpmB_writeReadme
endproc

procedure emlpmB_verify (count)
  emlpmB_verify.ok = 1
  emlpmB_verify.failFile$ = ""
  for i to count
    filePath$ = targetFolder$ + "/" + manifestPath$# [i]
    lines$# = readLinesFromFile$# (filePath$)
    if size (lines$#) <> manifestLines# [i]
      if emlpmB_verify.ok = 1
        emlpmB_verify.ok = 0
        emlpmB_verify.failFile$ = manifestPath$# [i]
      endif
    endif
  endfor
endproc

procedure emlpmB_writeVersion
  file$ = targetFolder$ + "/VERSION"
  writeFileLine: file$, payloadVersion$
endproc

beginPause: msgDialogTitle$
  comment: msgDialogBody$
clicked = endPause: "Cancel", "Install", 1, 1

if clicked = 2
  @emlpmB_versionOk
  if emlpmB_versionOk.result = 0
    exitScript: msgTooOld$
  endif

  @emlpmB_alreadyInstalled
  if emlpmB_alreadyInstalled.result = 1
    exitScript: msgAlreadyInstalled$
  endif

  @emlpmB_writePayload

  @emlpmB_verify: size (manifestPath$#) - 1
  if emlpmB_verify.ok = 0
    msgFailure$ = "The verify step failed on " + emlpmB_verify.failFile$ + ". Nothing needs to be cleaned up manually."
    exitScript: msgFailure$
  endif

  @emlpmB_writeVersion

  @emlpmB_verify: size (manifestPath$#)
  if emlpmB_verify.ok = 0
    msgFailure$ = "The final verify step failed on " + emlpmB_verify.failFile$ + ". Nothing needs to be cleaned up manually."
    exitScript: msgFailure$
  endif

  exitScript: msgSuccess$
else
  exitScript ( )
endif
