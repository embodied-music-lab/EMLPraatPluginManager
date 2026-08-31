# EML Plugin Manager for Praat

A plugin that installs, updates, and removes Praat plugins from
inside Praat. No native installer, no external runtime — Praat plus
what the operating system already ships.

Author: Ian Howell, Embodied Music Lab.

## Status

Early development. What exists today:

- `plugin_EMLPluginManager/install-from-disk.praat` — installs an
  already-downloaded plugin (`.zip`, `.tar.gz`/`.tgz`, or an
  unpacked folder). Finds every `plugin_` folder at any depth
  inside the source, presents a checklist, archives any same-named
  installed plugin before replacing it, and never deletes anything
  except its own staging folder. Specification-complete; the
  adversarial verification pass has not yet run.
- `plugin_EMLPluginManager/setup.praat` — registers the one working
  command.
- `docs/` — the product design roadmap and FAQ.
- `planning/` — the pinned generation specifications and review
  handbacks that produced the code.
- `bootstrap/` — will hold the generated one-file installer that
  installs this manager itself (specification in `planning/`;
  regeneration pending).
- `harness/` — will hold the verification driver and fixtures.

## Install (current, manual — the bootstrap replaces this)

Copy `plugin_EMLPluginManager/` into your Praat preferences folder
and restart Praat. The preferences folder is named in Praat's
manual under "preferences folder".

## Requirements

Praat 6.6.30 or newer, including Praat 7. Under Praat 7's
permission system, choose "Approve for this session" when Praat
asks — every prompt arrives in direct response to an action you
took; nothing runs at startup.

## License

Not yet chosen. The roadmap recommends a permissive license; the
decision is pending.
