"""Create a local device-only stub overlay; preserve the downloaded SDK."""
import json
import re
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT.parent / "downloads/ios9-build-sdk/theos-sdks/iPhoneOS10.3.sdk"
DEST = ROOT / "build/iPhoneOS10.3-armv7.sdk"


def prepare():
    if (DEST / ".prepared.json").exists() and json.loads((DEST / ".prepared.json").read_text()).get("revision") == 2:
        return DEST
    if DEST.exists():
        assert DEST.parent == ROOT / "build" and not DEST.is_symlink()
        shutil.rmtree(DEST)  # Generated overlay only; original SDK is preserved.
    shutil.copytree(SOURCE, DEST, symlinks=True)
    changed = []
    for path in DEST.rglob("*.tbd"):
        if path.is_symlink():
            continue
        original = path.read_text()
        text = re.sub(
            r"(archs:\s*)\[([^\]]+)\]",
            lambda m: m[1] + "[ " + ", ".join(
                a.strip() for a in m[2].split(",") if a.strip() not in ("i386", "x86_64")
            ) + " ]",
            original,
        )
        if path.name == "libobjc.A.tbd":
            text = text.replace("symbols:              [ ", "symbols:              [ _objc_msgSend_stret, ", 1)
        if path.name == "libunwind.tbd":
            text = text.replace("symbols:              [ ",
                "symbols:              [ __Unwind_SjLj_Register, __Unwind_SjLj_Resume, __Unwind_SjLj_Unregister, ", 1)
        if path.name == "libc++.1.tbd":
            # The upstream stub only lists 64-bit C++ ABI names (long sizes,
            # virtual-base offsets, and DWARF personality). These declarations
            # correspond to the same SDK's ARMv7 public libc++ headers.
            symbols = json.loads((ROOT / "armv7-cxx-exports.json").read_text())
            text = text.replace("\n...", "\n  - archs: [ armv7, armv7s ]\n    symbols: [ " + ", ".join(symbols) + " ]\n...")
        if text != original:
            path.write_text(text)
            changed.append(str(path.relative_to(DEST)))
    (DEST / ".prepared.json").write_text(json.dumps({
        "revision": 2, "changes": changed,
        "reason": "The upstream patched stubs combine simulator and device architectures and omit ARMv7-only exports.",
        "symbol_evidence": "All four added export names are imports of the official RetroArch ARMv7 executable already confirmed running on this iPad.",
        "cxx_declarations": "ARMv7 ABI counterparts of libc++ APIs declared in this SDK; native launch validation remains required.",
        "scope": "Mac-side text linking stubs only. No iPad/system libraries modified.",
    }, indent=2) + "\n")
    return DEST


if __name__ == "__main__":
    print(prepare())
