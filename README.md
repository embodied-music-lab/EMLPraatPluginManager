# EML Plugin Manager for Praat

A plugin that installs, updates, and removes Praat plugins from
inside Praat. No native installer, no external runtime — Praat plus
what the operating system already ships.

Author: Ian Howell, Embodied Music Lab.

## Status

Version 5.1.0. Install-from-disk and the install script are
working and verified against the test harness in `harness/`,
including installs of real published plugins in every supported
archive shape.

What the repository contains:

- `plugin_EMLPraatPluginManager/install-from-disk.praat` — installs an
  already-downloaded plugin (`.zip`, `.tar.gz`/`.tgz`, or an
  unpacked folder). Finds every `plugin_` folder at any depth
  inside the source and presents a checklist. Offers a canonical
  rename when a folder name carries a suffix such as `-main` (your
  choice — it never forces one). When a same-named plugin is
  already installed, compares versions and labels each choice
  (newer, equal, older) before you decide. Archives any plugin it
  replaces and never deletes anything except its own staging
  folder.
- `plugin_EMLPraatPluginManager/setup.praat` — registers the menu
  command.
- `eml-plugin-manager-install.praat` (repo root) — the install
  file: one self-contained script that installs the manager. Open
  it in Praat, run it, restart Praat. It is regenerated from the
  plugin folder and is the file to distribute, from anywhere.
- `docs/` — the product design roadmap and FAQ.
- `harness/` — the verification driver, fixtures, drive record,
  and screenshot evidence.
- `planning/` — the pinned generation specifications and review
  handbacks that produced the code.
- `tools/build_installer.py` — regenerates the install file from
  the plugin folder; `--check` verifies the two agree. After any
  edit to the plugin folder, run the tool and commit the
  regenerated install file with the edit.
- `hooks/pre-commit` — refuses a commit when the install file has
  drifted from the plugin folder. Enable once per clone with
  `git config core.hooksPath hooks`. CI runs the same check on
  every push.

## Install

Two routes:

1. **Install file (recommended).** Download
   `eml-plugin-manager-install.praat`, open it in Praat
   (**Praat > Open Praat script...**), and run it. Restart Praat.
2. **Manual.** Copy `plugin_EMLPraatPluginManager/` into your Praat
   preferences folder and restart Praat. The preferences folder is
   named in Praat's manual under "preferences folder".

After installing, the manager's commands appear in the Praat menu.

## Requirements

Praat 6.6.30 or newer, including Praat 7. Under Praat 7's
permission system, choose "Approve for this session" when Praat
asks — every prompt arrives in direct response to an action you
took; nothing runs at startup.

## License

Not yet chosen. The roadmap recommends a permissive license; the
decision is pending.
