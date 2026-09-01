#!/usr/bin/env python3
"""Regenerate or check the install script's embedded payload.

The plugin folder (plugin_*/ at the repository root) is the single
source of truth. The install file at eml-plugin-manager-install.praat (repo root)
carries an embedded copy of every plugin file; this tool rewrites that
copy — the folder-name constant, the payload version (read from the
plugin's VERSION file), the manifest with line counts, and one writer
procedure per embedded file — so the copy cannot drift from the plugin.

Usage:
  python3 tools/build_installer.py           # regenerate in place
  python3 tools/build_installer.py --check   # exit 1 if the committed
                                             # install file differs from a
                                             # fresh regeneration

Run --check after any edit to the plugin folder; run the default mode
to bring the install script back into agreement, then re-verify with the
headless payload test and the GUI drive.

Payload sources must be pure ASCII: Praat's writeFileLine switches the
whole output file to UTF-16 when any character is non-ASCII, which
breaks byte-identical extraction. This tool refuses non-ASCII sources.
"""

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
INSTALLER = REPO / "eml-plugin-manager-install.praat"

# VERSION must stay last: it is the completion marker the
# already-installed check keys on.
PAYLOAD_ORDER = ["setup.praat", "install-from-disk.praat", "remove-plugin.praat", "VERSION"]


def fail(msg):
    print(f"build_installer: {msg}", file=sys.stderr)
    sys.exit(1)


def plugin_dir():
    dirs = sorted(p for p in REPO.iterdir()
                  if p.is_dir() and p.name.startswith("plugin_"))
    if len(dirs) != 1:
        fail(f"expected exactly one plugin_* folder at the repo root, found {len(dirs)}")
    return dirs[0]


def read_lines(path):
    data = path.read_bytes()
    try:
        text = data.decode("ascii")
    except UnicodeDecodeError as e:
        fail(f"{path.relative_to(REPO)} is not pure ASCII (byte {e.start}); "
             "ASCII is required for byte-identical extraction")
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines = lines[:-1]
    return lines


def writer_lines(lines):
    out = []
    for i, ln in enumerate(lines):
        esc = ln.replace('"', '""')
        fn = "writeFileLine" if i == 0 else "appendFileLine"
        out.append(f'  {fn}: file$, "{esc}"')
    return out


def proc_name(filename):
    return {"setup.praat": "emlManagerWriteSetup",
            "install-from-disk.praat": "emlManagerWriteInstaller",
            "remove-plugin.praat": "emlManagerWriteRemover"}[filename]


INCLUDE_RE = re.compile(r'^include \.\./([A-Za-z0-9_]+)/install-from-disk\.praat\s*$', re.M)


def check_remover_include(plug):
    """remove-plugin.praat must include the installer via the pinned
    '../<plugin folder>/' form (include resolves relative to the
    OUTERMOST running script's folder — see the remove spec). If the
    plugin folder is ever renamed, this include line must be updated
    to match, or the module silently breaks; fail loudly instead."""
    remover = plug / "remove-plugin.praat"
    if not remover.exists():
        fail(f"{remover.relative_to(REPO)} not found")
    text = remover.read_text(encoding="ascii")
    m = INCLUDE_RE.search(text)
    if not m:
        fail(f"{remover.relative_to(REPO)} has no '../<plugin_*>/install-from-disk.praat' "
             "include line in the pinned form")
    named = m.group(1)
    if named != plug.name:
        fail(f"{remover.relative_to(REPO)} includes installer via folder "
             f"\"{named}\", but the actual plugin folder is \"{plug.name}\" — "
             "update the include line to match the renamed folder")


def regenerate(src):
    plug = plugin_dir()
    check_remover_include(plug)
    found = sorted(p.name for p in plug.iterdir() if p.is_file())
    if found != sorted(PAYLOAD_ORDER):
        fail(f"plugin folder contains {found}, expected exactly {sorted(PAYLOAD_ORDER)}; "
             "update PAYLOAD_ORDER and the writer procedures together")

    version_lines = read_lines(plug / "VERSION")
    if len(version_lines) != 1:
        fail("plugin VERSION file must be exactly one line")
    version = version_lines[0].strip()

    counts = {name: len(read_lines(plug / name)) for name in PAYLOAD_ORDER}

    src = re.sub(r'folderName\$ = "plugin_[A-Za-z0-9_]+"',
                 f'folderName$ = "{plug.name}"', src, count=1)
    src = re.sub(r'payloadVersion\$ = "[^"]*"',
                 f'payloadVersion$ = "{version}"', src, count=1)
    manifest = ('manifestPath$# = { ' +
                ", ".join(f'"{n}"' for n in PAYLOAD_ORDER) + ' }\n' +
                'manifestLines# = { ' +
                ", ".join(str(counts[n]) for n in PAYLOAD_ORDER) + ' }')
    src, n = re.subn(r'manifestPath\$# = \{[^}]*\}\nmanifestLines# = \{[^}]*\}',
                     manifest, src, count=1)
    if n != 1:
        fail("could not locate the manifest block in the install script")

    for name in PAYLOAD_ORDER:
        if name == "VERSION":
            continue  # written by emlManagerWriteVersion from payloadVersion$
        proc = proc_name(name)
        body = (f'procedure {proc}\n'
                f'  file$ = targetFolder$ + "/{name}"\n' +
                "\n".join(writer_lines(read_lines(plug / name))) +
                "\nendproc")
        src, n = re.subn(rf'procedure {proc}\n.*?\nendproc',
                         lambda _m, b=body: b, src, count=1, flags=re.S)
        if n != 1:
            fail(f"could not locate procedure {proc} in the install script")

    return src


def main():
    check = "--check" in sys.argv[1:]
    current = INSTALLER.read_text(encoding="ascii")
    fresh = regenerate(current)
    if check:
        if fresh != current:
            fail("install file DRIFTED from the plugin folder — "
             "run tools/build_installer.py to regenerate, then re-verify")
        print("build_installer: check OK — install file matches the plugin folder")
        return
    if fresh == current:
        print("build_installer: already in agreement, nothing written")
        return
    INSTALLER.write_text(fresh, encoding="ascii")
    print("build_installer: install file regenerated — re-verify before committing "
          "(headless payload test + GUI drive)")


if __name__ == "__main__":
    main()
