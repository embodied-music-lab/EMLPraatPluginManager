# Spec — wrapper safety round (v0.7.2)

Fable, 2 September 2026. Approved by Ian ("execute with cheapest agents
that work"). Motivating field failure, measured on Ian's Mac and
confirmed by screenshot: he generated an install file for
plugin_EMLVoiceViews (Create install file only offers INSTALLED plugins,
so the wrapper was written into the installed copy under the prefs
dir), ran the wrapper from there, chose to proceed at the
already-installed dialog — and the wrapper renamed the installed copy
(its own source) to old_plugin_EMLVoiceViews, then cp'd from the
now-nonexistent captured path (runSystem_nocheck, silent), leaving an
EMPTY destination and an honest post-copy verify failure ("VERSION is
missing from the installed copy"). Nothing lost; recovery was manual.

Three parts, one round. Files: create-install-file.praat (dialog flow +
wrapper template), install-from-disk.praat and remove-plugin.praat
(part 3 sweep only), harness, VERSION, regenerated install file.

## Part 0 — reproduce FIRST, in the container GUI drive

Before any fix: reproduce Ian's failure against the v0.7.1 code with
the existing GUI-drive tooling (/root/work/drive: Xvfb + xdotool +
GUI Praat 6.6.30 at /root/work/drive/gui/praat, screenshot evidence
conventions per harness/evidence/). Fixture plugin with setup.praat +
scripts/x.praat in a scratch --pref-dir; generate the wrapper via the
manager's own command path; run the wrapper from inside the installed
copy; drive the dialogs; capture: the already-installed pause, the
failure pause, and an `ls` of the aftermath (empty dest +
old_plugin_* holding everything). Evidence files
harness/evidence/v072_repro_*.png + a text transcript. The SAME drive,
re-run after part 1, must instead show the guard dialog and an
unchanged prefs tree — that is part 1's acceptance.

## Part 1 — self-install guard in the wrapper template

Site: the generated wrapper's main block, immediately after
`scriptFolder$` and `destPath$` are computed and BEFORE the manifest
verify and the already-installed dialog.

Guard condition, exactly: normalize both paths by stripping any
trailing "/" or "\"; fire when `scriptFolder$ = destPath$` (string
compare) OR `startsWith (scriptFolder$, destPath$ + "/")` (wrapper
anywhere UNDER the destination). On fire: one dedicated pause titled
with a new constant (suggested text: "Install: already in place"),
body: the folder name, the version read from the wrapper's own baked
`wrapVersion$`, and the sentence "This install file is running from
inside the installed copy itself, so there is nothing to install." If
`wrapReadVersionFile` on destPath$ yields a version, the body also
names it; if not, it says the installed copy's version is unknown. One
OK button, then exitScript. No rename, no copy, no folder creation on
this path.

Windows path separator: destPath$ is built with "/" in the template;
scriptFolder$ comes from defaultDirectory$. If measurement shows
defaultDirectory$ uses "\" on Windows, normalize "\" to "/" in BOTH
before comparing (do the measurement only if cheaply possible — we have
no Windows box, so implement the separator normalization
unconditionally; it is harmless on POSIX).

The guard goes in the STATIC TEMPLATE so every regenerated wrapper
carries it. Also add the same-shape check to the harness-mode
procedure surface so it is testable headless (see harness section).

## Part 2 — Create install file accepts an arbitrary folder

Today the command's dialog offers only `plugin_*` folders found in the
prefs dir (folderNames$# over prefsDir). Ian's ruling: the author's
dev copy lives elsewhere; the wrapper should be generated THERE.

Changes to the picker flow:

- The existing optionmenu of installed plugins gains one final entry:
  "Another folder (chosen in the next step)". Exact mechanism (extra
  optionmenu row vs. a separate control) is the builder's choice within
  the existing dialog conventions (38-char label cap, wrap width 62).
- Choosing it invokes Praat's folder chooser. MEASURE FIRST at GUI
  6.6.30 which primitive exists and works (`chooseFolder$:` vs
  `chooseDirectory$:`); record the measurement in DRIVE_RECORD. A
  cancelled chooser ("" return) exits politely with a one-line
  cancelled notice — not an error dialog.
- Validation of the chosen folder, in order, each with its own clear
  refusal notice: (a) the folder name must begin with `plugin_` —
  refusal says Praat only activates folders named plugin_<Name> and
  asks the author to rename the folder first (no auto-rename, matching
  the manager's offer-never-force rule — but here we do not even
  offer, because renaming the author's dev folder is not this
  command's business); (b) it must contain a top-level setup.praat
  (the installed-iff-setup canon, reused via the existing procedure,
  never reimplemented) — refusal explains an install file describes a
  plugin and this folder has no setup.praat; (c) the existing
  non-ASCII name refusal applies unchanged.
- After validation the flow is IDENTICAL to the installed-plugin path:
  version popup, VERSION written into the chosen folder, wrapper
  written into the chosen folder, same completion dialog (as amended
  by part 3).

The installed-plugin path stays available and unchanged — an author
regenerating the install file for something already in prefs keeps the
short route (the part-1 guard makes running such a wrapper in place
safe now).

## Part 3 — the path canon: dialogs carry names, paths go to the Info window

New canon, stated once in install-from-disk.praat beside the other
canons and byte-copied into wherever the generator needs it (the
build_installer --check drift rules apply as for the existing canons):
a procedure `emlManagerLogPath: .event$, .path$` that does
`appendInfoLine: "EML Plugin Manager -- " + .event$ + ":"` (ASCII
"--" per the repo convention; amended 2 Sep from the em dash) then
`appendInfoLine: .path$` then a blank line. NO clearinfo anywhere in
the manager — appending under the user's existing Info content is the
pinned behavior.

Sweep: every pause/comment in install-from-disk.praat,
remove-plugin.praat, create-install-file.praat AND the wrapper template
that interpolates a filesystem PATH (not a bare folder or file NAME)
into dialog text. For each site: the dialog line keeps the NAME and
gains/uses the pointer sentence "The full path is printed in the Info
window."; the full path goes through the canon procedure. The builder
lists every site found and changed in DRIVE_RECORD; a site left
unchanged needs a stated reason there. Bare names (plugin_X,
install-X.praat, old_plugin_X) stay in dialogs — they are bounded by
the existing label/wrap rules.

GUI measurement required: with the Info window CLOSED, an
appendInfoLine from a running script — does the window open/raise at
6.6.30? Screenshot evidence. If it does NOT, stop and report before
shipping the pointer sentence; the design assumed it does.

## Harness

- Headless: new cases in run_wrapper_installer.praat (harness mode)
  for the guard condition (equal paths; wrapper under dest; unrelated
  paths → no fire; trailing-slash and backslash normalization) and for
  part 2's validation order (non-plugin_ name refused, missing
  setup.praat refused, cancel path) driven at the procedure level.
- GUI drive: part 0's reproduction (against v0.7.1) and its green
  re-run (against v0.7.2 — guard dialog, tree unchanged); one drive of
  the part-2 chooser path end to end (choose dev folder outside prefs,
  wrapper lands there, then run that wrapper and see a clean install
  into prefs); the part-3 Info-window raise measurement. Screenshots
  under harness/evidence/ with v072_ prefixes.
- All existing harnesses green; build_installer --check green after
  VERSION 0.7.2.

## Out of scope

Recovering Ian's machine (done by hand), any change to the Remove
flow's logic beyond part 3's text sweep, and Windows testing beyond
the unconditional separator normalization.
