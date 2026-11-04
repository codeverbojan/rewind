"""Compile upstream libtorrent source for ARMv7 with at most two compiler processes."""
import concurrent.futures
import hashlib
import json
import os
import re
import signal
import subprocess
import threading
from pathlib import Path
from prepare_sdk import prepare

ROOT = Path(__file__).resolve().parent
SOURCES = ROOT.parent / "downloads/standalone-media-sources"
SRC = SOURCES / "libtorrent-rasterbar-1.2.20"
BOOST = SOURCES / "boost_1_84_0"
OUT = ROOT / "build/torrent"
SDK = prepare()
DEFINES = ["NDEBUG", "TORRENT_USE_I2P=0", "TORRENT_DISABLE_LOGGING",
           "BOOST_ASIO_ENABLE_CANCELIO", "BOOST_ASIO_HAS_STD_CHRONO",
           "BOOST_ASIO_USE_TS_EXECUTOR_AS_DEFAULT", "BOOST_EXCEPTION_DISABLE"]
FLAGS = ["-target", "armv7-apple-ios9.0", "-isysroot", str(SDK), "-std=c++14",
         "-stdlib=libc++", "-Os", "-fvisibility=hidden", "-fvisibility-inlines-hidden",
         "-I" + str(SRC / "include"), "-I" + str(BOOST), "-Wno-deprecated-declarations",
         *["-D" + d for d in DEFINES]]
live = set()
lock = threading.Lock()
stop = threading.Event()


def cleanup(*_):
    stop.set()
    with lock:
        for process in list(live):
            if process.poll() is None:
                process.terminate()


def compile_one(path):
    if stop.is_set():
        return False
    obj = OUT / (str(path.relative_to(SRC)).replace("/", "_") + ".o")
    digest = hashlib.sha256((json.dumps(FLAGS) + path.read_text()).encode()).hexdigest()
    marker = obj.with_suffix(".sha256")
    if obj.exists() and marker.exists() and marker.read_text() == digest:
        return True
    args = ["/usr/bin/clang++", *FLAGS, "-DTORRENT_BUILDING_LIBRARY", "-c", str(path), "-o", str(obj)]
    with lock:
        if stop.is_set():
            return False
        proc = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        live.add(proc)
    try:
        output, _ = proc.communicate(timeout=120)
    except BaseException:
        proc.kill()
        proc.communicate()
        raise
    finally:
        with lock:
            live.discard(proc)
    obj.with_suffix(".log").write_bytes(output)
    if proc.returncode:
        print("FAILED", path.name, output.decode(errors="replace")[-6500:], flush=True)
        cleanup()
        return False
    marker.write_text(digest)
    print("Built", path.relative_to(SRC), flush=True)
    return True


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cmake = (SRC / "CMakeLists.txt").read_text()
    paths = []
    for group, prefix in [("sources", "src"), ("kademlia_sources", "src/kademlia"),
                           ("ed25519_sources", "ed25519/src")]:
        body = re.search(r"set\(" + group + r"\s+(.*?)\n\)", cmake, re.S)[1]
        paths.extend(SRC / prefix / name for name in re.findall(r"^\s*([a-z0-9_]+\.cpp)\s*$", body, re.M))
    paths.extend(SRC / "src" / name for name in ["pe_crypto.cpp", "hasher512.cpp", "sha512.cpp"])
    for sig in [signal.SIGTERM, signal.SIGINT]:
        signal.signal(sig, cleanup)
    print("Compiling", len(paths), "files with two workers", flush=True)
    try:
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(compile_one, paths))
        if not all(results):
            raise SystemExit(1)
        objects = [OUT / (str(p.relative_to(SRC)).replace("/", "_") + ".o") for p in paths]
        lib = OUT / "libtorrent.a"
        if lib.exists():
            lib.unlink()
        subprocess.run(["/usr/bin/ar", "rcs", str(lib), *map(str, objects)], check=True)
        report = {"source": "libtorrent 1.2.20 official release", "boost_headers": "1.84.0",
                  "target": "ARMv7 iOS 9.0", "library": str(lib), "bytes": lib.stat().st_size,
                  "sha256": hashlib.sha256(lib.read_bytes()).hexdigest(),
                  "features": ["BitTorrent v1", "magnets", "DHT", "UDP/HTTP trackers", "piece deadlines"],
                  "limitations": ["HTTPS trackers and web seeds need an additional TLS backend"]}
        (OUT / "build-report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report, indent=2), flush=True)
    finally:
        cleanup()


if __name__ == "__main__":
    main()
