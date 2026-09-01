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

procedure emlManagerVersionOk
  emlManagerVersionOk.result = 0
  if praatVersion >= floorVersionNum
    emlManagerVersionOk.result = 1
  endif
endproc

procedure emlManagerAlreadyInstalled
  emlManagerAlreadyInstalled.result = 0
  if folderExists (targetFolder$)
    if fileReadable (targetFolder$ + "/VERSION")
      emlManagerAlreadyInstalled.result = 1
    endif
  endif
endproc

procedure emlManagerWriteSetup
  file$ = targetFolder$ + "/setup.praat"
  writeFileLine: file$, "Add menu command: ""Objects"", ""Praat"", ""EML Plugin Manager: About"", """", 0, ""about.praat"""
endproc

procedure emlManagerWriteAbout
  file$ = targetFolder$ + "/about.praat"
  writeFileLine: file$, "folder$ = preferencesDirectory$ + ""/plugin_EMLPluginManager"""
  appendFileLine: file$, "version$# = readLinesFromFile$# (folder$ + ""/VERSION"")"
  appendFileLine: file$, "writeInfoLine: ""EML Plugin Manager"""
  appendFileLine: file$, "appendInfoLine: version$# [1]"
  appendFileLine: file$, "appendInfoLine: ""The full manager arrives in a later build."""
endproc

procedure emlManagerWriteReadme
  file$ = targetFolder$ + "/README.txt"
  writeFileLine: file$, "This folder contains the EML Plugin Manager."
  appendFileLine: file$, "It was installed by the EML Plugin Manager bootstrap installer."
  appendFileLine: file$, "It can be managed from the Plugin manager menu in a later build."
endproc

procedure emlManagerWritePayload
  if not folderExists (targetFolder$)
    createFolder: targetFolder$
  endif
  @emlManagerWriteSetup
  @emlManagerWriteAbout
  @emlManagerWriteReadme
endproc

procedure emlManagerVerify (count)
  emlManagerVerify.ok = 1
  emlManagerVerify.failFile$ = ""
  for i to count
    filePath$ = targetFolder$ + "/" + manifestPath$# [i]
    lines$# = readLinesFromFile$# (filePath$)
    if size (lines$#) <> manifestLines# [i]
      if emlManagerVerify.ok = 1
        emlManagerVerify.ok = 0
        emlManagerVerify.failFile$ = manifestPath$# [i]
      endif
    endif
  endfor
endproc

procedure emlManagerWriteVersion
  file$ = targetFolder$ + "/VERSION"
  writeFileLine: file$, payloadVersion$
endproc

beginPause: msgDialogTitle$
  comment: msgDialogBody$
clicked = endPause: "Quit", "Install", 2, 1

if clicked = 2
  @emlManagerVersionOk
  if emlManagerVersionOk.result = 0
    exitScript: msgTooOld$
  endif

  @emlManagerAlreadyInstalled
  if emlManagerAlreadyInstalled.result = 1
    exitScript: msgAlreadyInstalled$
  endif

  @emlManagerWritePayload

  @emlManagerVerify: size (manifestPath$#) - 1
  if emlManagerVerify.ok = 0
    msgFailure$ = "The verify step failed on " + emlManagerVerify.failFile$ + ". Nothing needs to be cleaned up manually."
    exitScript: msgFailure$
  endif

  @emlManagerWriteVersion

  @emlManagerVerify: size (manifestPath$#)
  if emlManagerVerify.ok = 0
    msgFailure$ = "The final verify step failed on " + emlManagerVerify.failFile$ + ". Nothing needs to be cleaned up manually."
    exitScript: msgFailure$
  endif

  exitScript: msgSuccess$
else
  exitScript ( )
endif
