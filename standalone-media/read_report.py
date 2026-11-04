"""Read MiniStream Lab's own diagnostic report over the approved USB connection."""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import retroarch_usb as usb


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    usb.APP_ID = b"org.local.ministreamlab"
    with usb.Documents() as documents:
        try:
            data = documents.read("/Documents/session-report.json")
        except FileNotFoundError:
            print("No torrent-build report yet. The updated app may not have launched.")
            return 2
    report = json.loads(data)
    text = json.dumps(report, indent=2) + "\n"
    if args.output:
        args.output.write_text(text)
    print(text, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
