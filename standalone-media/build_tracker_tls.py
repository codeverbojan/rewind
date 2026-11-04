"""Verified TLS dependencies for the ARMv7 app; no downloads or implicit builds."""
import hashlib
import json
from pathlib import Path
from build_torrent import FLAGS as BASE_FLAGS, SRC, BOOST

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parent
TLS = ROOT / "build/openssl-3.5.9-armv7-portable-locks"
OPENSSL = PROJECT / "downloads/standalone-media-sources/openssl-3.5.9"
FLAGS = BASE_FLAGS + ["-DTORRENT_USE_OPENSSL", "-I" + str(TLS / "include"),
                     "-I" + str(OPENSSL / "include")]
LIBRARIES = [ROOT / "build/torrent-observer-261-armv7/libtorrent.a",
             TLS / "libssl.a", TLS / "libcrypto.a"]


def verify():
    lock = json.loads((ROOT / "Dependencies/tracker-tls.json").read_text())
    inputs = dict(lock["libtorrent_inputs"])
    inputs.update(lock["linked_inputs"])
    for name, expected in inputs.items():
        path = PROJECT / name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise RuntimeError("TLS dependency differs from verified build: " + name)
    old = ROOT / "build/openssl-3.5.9-armv7-portable/include"
    headers = list(old.rglob("*.h"))
    if not headers:
        raise RuntimeError("Missing verified OpenSSL headers")
    for header in headers:
        replacement = TLS / "include" / header.relative_to(old)
        if not replacement.is_file() or replacement.read_bytes() != header.read_bytes():
            raise RuntimeError("OpenSSL header ABI changed; rebuild and verify libtorrent")
