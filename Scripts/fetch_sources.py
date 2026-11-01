#!/usr/bin/env python3
"""Download the pinned pack inputs listed in Scripts/sources.json and verify them.

    python3 Scripts/fetch_sources.py              # everything, into .cache/sources
    python3 Scripts/fetch_sources.py --only omw-it
    python3 Scripts/fetch_sources.py --local dcc-latin=/path/to/dcc-latin-core-list.csv

Each source lands in .cache/sources/<id>/<file>. A file whose SHA-256 differs
from the manifest is deleted and the run fails. Tarballs listed with "extract"
are unpacked next to the download (only the named member is extracted).
Standard library only.
"""
import argparse
import hashlib
import json
import shutil
import sys
import tarfile
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "Scripts" / "sources.json"
USER_AGENT = "ExUno-data-fetch/1.0 (https://github.com/ChiChou/ExUno)"


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def download(url: str, dest: Path) -> None:
    tmp = dest.with_suffix(dest.suffix + ".part")
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=120) as r, tmp.open("wb") as f:
        shutil.copyfileobj(r, f)
    tmp.replace(dest)


def extract(archive: Path, member: str, into: Path) -> Path:
    target = into / member
    with tarfile.open(archive) as tar:
        info = tar.getmember(member)
        if not info.isfile():
            raise SystemExit(f"{archive.name}: {member} is not a regular file")
        target.parent.mkdir(parents=True, exist_ok=True)
        with tar.extractfile(info) as src, target.open("wb") as out:
            shutil.copyfileobj(src, out)
    return target


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--cache", type=Path, default=ROOT / ".cache" / "sources")
    ap.add_argument("--only", action="append", default=[], help="source id (repeatable)")
    ap.add_argument("--local", action="append", default=[], metavar="ID=PATH", help="use a local file instead of downloading")
    ap.add_argument("--force", action="store_true", help="download again even if a verified copy exists")
    a = ap.parse_args()

    local = dict(item.split("=", 1) for item in a.local)
    sources = json.loads(MANIFEST.read_text())["sources"]
    failed = False
    for s in sources:
        if a.only and s["id"] not in a.only:
            continue
        folder = a.cache / s["id"]
        folder.mkdir(parents=True, exist_ok=True)
        dest = folder / s["file"]
        try:
            if s["id"] in local:
                shutil.copyfile(Path(local[s["id"]]).expanduser(), dest)
            elif a.force or not dest.exists() or sha256(dest) != s["sha256"]:
                print(f"↓ {s['id']}: {s['url']}")
                download(s["url"], dest)
        except (urllib.error.URLError, OSError) as e:
            print(f"✗ {s['id']}: {e}", file=sys.stderr)
            failed = True
            continue

        digest = sha256(dest)
        if digest != s["sha256"]:
            dest.unlink()
            print(f"✗ {s['id']}: checksum mismatch (got {digest})", file=sys.stderr)
            failed = True
            continue
        if s.get("extract"):
            extract(dest, s["extract"], folder)
        print(f"✓ {s['id']} ({s['license']})")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
