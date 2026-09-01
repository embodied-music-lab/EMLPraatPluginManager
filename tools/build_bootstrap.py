#!/usr/bin/env python3
"""Regenerate or check the bootstrap installer's embedded payload.

The plugin folder (plugin_*/ at the repository root) is the single
source of truth. The bootstrap at bootstrap/eml-plugin-manager-install.praat
carries an embedded copy of every plugin file; this tool rewrites that
copy — the folder-name constant, the payload version (read from the
plugin's VERSION file), the manifest with line counts, and one writer
procedure per embedded file — so the copy cannot drift from the plugin.

Usage:
  python3 tools/build_bootstrap.py           # regenerate in place
  python3 tools/build_bootstrap.py --check   # exit 1 if the committed
                                             # bootstrap differs from a
                                             # fresh regeneration

Run --check after any edit to the plugin folder; run the default mode
to bring the bootstrap back into agreement, then re-verify with the
headless payload test and the GUI drive.

Payload sources must be pure ASCII: Praat's writeFileLine switches the
whole output file to UTF-16 when any character is non-ASCII, which
breaks byte-identical extraction. This tool refuses non-ASCII sources.
"""

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BOOTSTRAP = REPO / "bootstrap" / "eml-plugin-manager-install.praat"

# VERSION must stay last: it is the completion marker the
# already-installed check keys on.
PAYLOAD_ORDER = ["setup.praat", "install-from-disk.praat", "VERSION"]


def fail(msg):
    print(f"build_bootstrap: {msg}", file=sys.stderr)
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
            "install-from-disk.praat": "emlManagerWriteInstaller"}[filename]


def regenerate(src):
    plug = plugin_dir()
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
        fail("could not locate the manifest block in the bootstrap")

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
            fail(f"could not locate procedure {proc} in the bootstrap")

    return src


def main():
    check = "--check" in sys.argv[1:]
    current = BOOTSTRAP.read_text(encoding="ascii")
    fresh = regenerate(current)
    if check:
        if fresh != current:
            fail("bootstrap payload DRIFTED from the plugin folder — "
             "run tools/build_bootstrap.py to regenerate, then re-verify")
        print("build_bootstrap: check OK — bootstrap payload matches the plugin folder")
        return
    if fresh == current:
        print("build_bootstrap: already in agreement, nothing written")
        return
    BOOTSTRAP.write_text(fresh, encoding="ascii")
    print("build_bootstrap: bootstrap regenerated — re-verify before committing "
          "(headless payload test + GUI drive)")


if __name__ == "__main__":
    main()
