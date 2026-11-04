#!/usr/bin/env python3
"""Sequential, dependency-free subset of existing C++ policy tests.

No device access, network listeners or fixture downloads. All outputs are temporary.
"""
import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SUITES = ('FrameCodeTests', 'ProbeConnectionsTests', 'NativeBufferRecoveryTests',
          'StackReadPolicyTests')
ACTIVE = None

def stop(signum=None, frame=None):
    global ACTIVE
    if ACTIVE is not None and ACTIVE.poll() is None:
        os.killpg(ACTIVE.pid, signal.SIGTERM)
        try:
            ACTIVE.wait(timeout=3)
        except subprocess.TimeoutExpired:
            os.killpg(ACTIVE.pid, signal.SIGKILL)
            ACTIVE.wait()
    if signum is not None:
        raise KeyboardInterrupt

def run(args, timeout):
    global ACTIVE
    ACTIVE = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              text=True, start_new_session=True)
    try:
        stdout, stderr = ACTIVE.communicate(timeout=timeout)
        if ACTIVE.returncode:
            raise RuntimeError(stderr or stdout or f'Failed: {args[0]}')
        return stdout
    finally:
        stop()
        ACTIVE = None

def main():
    if os.name != 'posix':
        raise SystemExit('Use macOS, Linux or WSL with a C++14 compiler.')
    compiler = shlex.split(os.environ.get('CXX', '')) or [shutil.which('clang++') or shutil.which('g++') or '']
    if not compiler[0]:
        raise SystemExit('Install/select a C++14 compiler first (CXX, clang++ or g++).')
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    results = []
    with tempfile.TemporaryDirectory(prefix='rewind-portable-') as folder:
        for suite in SUITES:
            binary = str(Path(folder) / suite)
            source = str(ROOT / 'standalone-media/Tests' / (suite + '.cpp'))
            run(compiler + ['-std=c++14', '-Wall', '-Wextra', source, '-o', binary], 45)
            result = json.loads(run([binary], 10))
            if result.get('failures') != 0 or result.get('checks', 0) <= 0:
                raise RuntimeError(f'{suite}: {result}')
            results.append({'suite': suite, **result})
    print(json.dumps({'scope': 'portable policy subset; no device acceptance',
                      'checks': sum(x['checks'] for x in results), 'suites': results}, indent=2))

if __name__ == '__main__':
    try:
        main()
    finally:
        stop()
