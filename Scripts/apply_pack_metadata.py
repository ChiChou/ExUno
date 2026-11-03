#!/usr/bin/env python3
"""Apply the app's authored metadata to locally built or prebuilt vocabulary packs."""
import argparse
import json
from pathlib import Path


def main():
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--packs", type=Path, default=root / "ExUno/Resources/Packs")
    args = parser.parse_args()
    metadata = json.loads((root / "Scripts/pack_metadata.json").read_text(encoding="utf-8"))
    for code, settings in metadata.items():
        path = args.packs / f"{code}.json"
        pack = json.loads(path.read_text(encoding="utf-8"))
        if pack["code"] != code:
            raise ValueError(f"Language mismatch in {path}")
        pack.update(settings)
        path.write_text(json.dumps(pack, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        print(f"Updated {path.name} metadata")


if __name__ == "__main__":
    main()
