# Pinned specification — installed-command report (v0.6.0)

Every design decision below is made. The task is mechanical
implementation. Where this text is ambiguous or impossible as
written, STOP and report the question — do not improvise.

## What it does

After an install, the "Installation complete" dialog tells the user
exactly where each installed plugin's commands appear, before the
restart line. The information comes from parsing each installed
plugin's `setup.praat` — the only file Praat reads to register
commands.

## Files

- `plugin_EMLPraatPluginManager/install-from-disk.praat` — gains the
  parser procedure and the completion-dialog lines. No existing
  behavior changes.
- NEW `harness/setup_report.tsv` + `harness/run_setup_report.praat`.
- `tools/build_installer.py` — maintainer tool, updated for the
  four-file payload (see the remove spec's Files section).
- No other file changes. (Root install file is maintainer-regenerated;
  do not edit it.)

## The parser — `emlManagerParseSetupCommands`

Input: absolute path of an installed plugin's `setup.praat`. Output:
`.n` result rows in parallel vectors `.kind$#` ("menu" | "action" |
"computed") and `.text$#` (the finished English line, unwrapped —
the dialog wraps it). Rules:

1. A registration line is one whose first non-blank content is
   `Add menu command` or `Add action command` (exact case),
   IMMEDIATELY followed by `:` or `.` (the modern colon or the
   legacy `...`) — `Add menu commands: ...` is NOT a registration
   (AMENDED: delimiter required). Lines whose first non-blank
   character is `#` are ignored. Praat ignores blanks (spaces and
   tabs) at the start of a line, and so does the parser. A line may
   start with command modifiers (`nocheck`, `nowarn`, `noprogress`,
   `demo`, `asynchronous`), stacked in any order. AMENDED 0.7.3
   (round 2), MEASURED in Praat 7.0.03: a modifier counts only when
   the keyword is followed by exactly ONE space, which goes with it,
   and the rest is read from its first character again. A second
   space or a tab after a keyword leaves the command text starting
   with a blank, Praat refuses it, and the line is not a
   registration (under `nocheck` Praat skips it silently). Legacy
   lines may leave off the trailing script argument (Praat 7.0.03
   accepts 5 menu or 9 action arguments there); modern lines may
   not. Both syntaxes are parsed:
   - modern: `Add menu command: "Objects", "Praat", "Title", "", 0, "s.praat"`
   - legacy: `Add menu command... "Objects" "Praat" "Title" "" 0 s.praat`
   Quoted arguments may contain doubled quotes (`""` inside a
   string). Legacy trailing bare tokens (depth, script) are read
   unquoted.
2. Menu command arguments, in order: window, menu, title, after,
   depth, script. English:
   `Adds "<title>" to the <menu> menu in the <window> window.`
   When depth > 0, the line instead ends
   `... window, under "<parent>".` where `<parent>` is the most
   recent title parsed at depth − 1 (track a per-depth title stack;
   if no parent is known, omit the under-clause).
3. Action command arguments, in order: class1, n1, class2, n2,
   class3, n3, title, after, depth, script. English:
   `Adds a "<title>" button that appears when you select <sel>.`
   `<sel>` = the non-empty classes joined with " and ", each as
   `a <class>` — or `an <class>` when the class name starts with
   A, E, I, O, or U — when its n is 0 or 1, else `<n> <class>
   objects` (e.g. "a Sound and a TextGrid", "an Intensity",
   "2 Sound objects"). AMENDED post-build: the built parser says
   "a Intensity"; fix the article rule and update the normative
   table and golden files accordingly.
4. Any registration line whose title, window, or menu argument is
   not a literal quoted string (a variable or expression) parses as
   kind "computed" with no text (AMENDED: window and menu count too
   — a variable name must never leak into the English). After the literal lines, the report adds
   one line when computed > 0:
   `Plus <computed> command(s) named when the plugin loads.`
5. A setup.praat with no registration lines at all yields one line:
   `Adds no menu commands or buttons (files only).`
6. THE COUNT: the number of clickable commands (rows of kind menu,
   action, or computed; the submenu rows, the no-commands row and the
   tally row are not counted) is the parser's `.registered` output. The
   install checklist's "adds N commands" reads that value
   (`emlManagerCheckSetupPresent`), so the checklist and this report
   cannot disagree. A separator line (a title that starts with a
   hyphen, such as `"--"`; Praat manual, "Add to fixed menu...") is not a
   command: it is neither counted nor listed, in either syntax. A blank
   title (a spacer) is the same. AMENDED round 6: a registration with no
   script (the argument left off, or a quoted empty string) is not a
   command, because Praat shows it as a submenu title (menu command) or
   as a heading label that cannot be clicked (action command). A menu
   one is a row of kind "submenu", worded `Adds a submenu "<title>" to
   the <menu> menu in the <window> window` with the usual under-clause,
   and is not counted. An action one is neither listed nor counted. A
   scriptless menu registration with a computed name is left out.
7. The parser reads only `setup.praat` — files it includes or runs
   are not followed; nothing is guessed about them.

## Dialog integration

In the existing "Installation complete" dialog, after each installed
plugin's existing summary lines: one header line `<folder> adds:`
followed by the parser's lines for that plugin, each wrapped by the
existing wrap procedure AT THE CANON WIDTH, one comment field per
wrapped line, inside the existing pagination-at-12 machinery.
CANON WIDTH (amended after measured overlap at 78): ONE named
width constant, value 62, used by EVERY pause-dialog wrap site in
the plugin — the report dialog, the remove dialogs, and any
existing site currently passing a different width. 78 characters
overflows Praat's pause window in its proportional font (measured
in the GUI drive); 62 is the width the install file's own dialog
was pinned at. Rows with empty text
(computed rows) are NOT rendered — only their tally line is
(AMENDED: no blank comment fields in the dialog). Then the existing restart
line, unchanged.

## Normative table — `harness/setup_report.tsv`

Tab-separated: `input_line` → `expected_kind` → `expected_text`.
At least 25 rows covering: modern and legacy menu commands; depth-0
and depth-1 with the under-clause; the New menu and the Praat menu;
action commands with one, two, and three classes; n values 0, 1, and
2; a title containing doubled quotes; a computed title (variable);
a comment line (expected: ignored); leading whitespace; a legacy
line with unquoted trailing args; AMENDED additions — at least one
an-article row (a class starting with a vowel), the delimiter
false-positive (`Add menu commands: ...` → ignored), and a
non-literal window argument (→ computed). `run_setup_report.praat` drives
the REAL parser over every row headlessly and reports pass/fail per
row, plus two whole-file checks: a fixture setup.praat with zero
registrations (rule 5) and one mixing literal and computed lines
(rule 4).

## Regression fixture

Parse the six real-world plugins' setup files already used by the
E2E record (cpran utils/tgutils/selection/twopass, jjatools,
AERoPlot — clone via git as the drive record documents). Record the
parser's output for each in the harness as expected values after a
human eyeball, so future changes to the parser diff against reality.
