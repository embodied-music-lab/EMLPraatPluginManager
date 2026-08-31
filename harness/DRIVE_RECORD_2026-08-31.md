# Drive record — 31 August 2026, Linux

Environment: Praat 6.6.30, Linux x64, in a clean container. Two
legs: the barren (command-line) build drove every procedure
headlessly; the full GUI build under Xvfb (with openbox, xcompmgr,
xdotool — the PraatGen sandbox recipe) drove the real dialogs with
scripted input and screenshot capture.

## Syntax and environment facts, measured at 6.6.30

- `praatVersion` = 6630; `praatVersion$` = "6.6.30".
- String-vector element assignment (`q$# [i] = ...`) works.
- The growable-queue doubling pattern works (capacity 64 to 16
  after 10 pushes in the probe; two forced doublings in the
  613-folder case).
- `include` resolves relative to the including script; a
  procedures-only include executes nothing.
- `createFolder` does not create parent folders.
- `folderExists`, `readLinesFromFile$#`, `replace_regex$`,
  `date#`, `startsWith`/`endsWith`, `rindex` all present.
- A boolean labeled with an underscore-containing name derives its
  variable verbatim; only characters outside letters, digits, and
  underscores are sanitized to spaces (and derive back as
  underscores).
- Return does NOT activate the default button on pause dialogs
  under GTK/Xvfb; drives click buttons by coordinates.

## install-from-disk.praat

Headless (procedures): 17 of 17 cases pass — baseName edge cases;
tar.gz and zip unpacking; the complete recursive search including
nested-inside-a-match, the `__MACOSX` exclusion, and the 613-folder
completeness case; the setup.praat scanner (continuation lines
joined, separator rows excluded, count 3 of 3); archive-with-stamp
including the detected-failure path; copy placement with the source
proven byte-identical afterward; verify; staging round trip with
the preferences directory otherwise undisturbed.

GUI (dialogs): 8 of 8 cases pass — underscore-name derivation
end to end (the load-bearing case); dash-name sanitized label with
installation under the exact original name; the derived-name
collision refusal, shown before any selection dialog with the spec
wording; pagination at 12 with both pages driven and all 15
plugins installed; uncheck-one installing exactly the rest; the
extension refusal; the cancel path; and the summary dialog. Key
screenshots in `evidence/`; each was inspected by eye.

## bootstrap/eml-plugin-manager-install.praat

Headless: 6 of 6 valid cases pass — four payload files with line
counts matching the embedded manifest; VERSION content exact; the
completion-marker logic in both directions; VERSION written only
after verify (confirmed in source); the generated about.praat runs
and prints correctly from a real plugin folder; setup.praat is the
single registration line. (A seventh assertion failed in the
driver, not the code: the driver expected a "Version: " label the
spec never required.)

## Not covered

Windows (documented behavior only; needs a manual pass on real
hardware). macOS rendering of the dialogs (logic is proven; a
short interactive sanity pass on a Mac remains worthwhile before
public release). The manager's future networked features do not
exist yet and are therefore untested.

## End-to-end with real-world plugins (same day, later)

Six genuine, unmodified plugins acquired from their public
repositories (cpran: utils, tgutils, selection, twopass; jjatria:
jjatools; AERodgers: AERoPlot) and packaged into five archives of
deliberately varied shape: plugin at archive root (zip and tar.gz),
GitHub Download-ZIP style (`plugin_tgutils-master/`), nested one
level down (`release/plugin_selection/`), and one zip holding two
plugins side by side. All five installed through the real GUI
dialogs; the two-plugin archive showed both rows ("jjatools, adds
36 commands"; "twopass, adds 1 command") and installed both in one
pass; the nested layout resolved correctly. An independent verifier
re-diffed every installed folder against its source archive:
byte-identical, no staging leftovers, zero discrepancies. Finale:
bare Praat launched with all six accumulated plugins — clean
startup, no error dialogs, meaning every real setup.praat executed.
Evidence pngs in `evidence/`.

Real-world finding for the roadmap: a GitHub-style archive installs
under its literal folder name (`plugin_tgutils-master`), which
works but leaves a noncanonical name in the preferences folder.
Whether the installer should offer to strip `-master`/`-main`
style suffixes is an open design question, deliberately not
decided in code.
