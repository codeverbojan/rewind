"""Headless, bounded probe using the already-installed Mac VLC and own test clip.

No network, device writes, GUI, or persistent workers. A parent timeout is also
used when invoking this script. Mac VLC is a comparison, not iPad qualification.
"""
import ctypes as C
import json
import os
import pathlib
import sys
import threading
import time

os.environ['VLC_PLUGIN_PATH'] = '/Applications/VLC.app/Contents/MacOS/plugins'
core = C.CDLL('/Applications/VLC.app/Contents/MacOS/lib/libvlccore.dylib', mode=C.RTLD_GLOBAL)
lib = C.CDLL('/Applications/VLC.app/Contents/MacOS/lib/libvlc.dylib')
P = C.c_void_p
def api(name, result, *args):
    f = getattr(lib, 'libvlc_' + name)
    f.restype, f.argtypes = result, args
    return f

OPEN = C.CFUNCTYPE(C.c_int, P, C.POINTER(P), C.POINTER(C.c_uint64))
READ = C.CFUNCTYPE(C.c_ssize_t, P, P, C.c_size_t)
SEEK = C.CFUNCTYPE(C.c_int, P, C.c_uint64)
CLOSE = C.CFUNCTYPE(None, P)
data = pathlib.Path(sys.argv[1]).read_bytes()
began = time.monotonic()
cancelled = threading.Event()
cursor = 0
events = []
gap = int(os.environ.get('GAP_AT', 4 * 1024 * 1024))
delay = float(os.environ.get('GAP_DELAY', 10))

def event(kind, **kwargs):
    if len(events) < 100:
        events.append(dict(at=round(time.monotonic()-began, 3), event=kind, **kwargs))

@OPEN
def opened(opaque, out, size):
    global cursor
    cursor = 0
    out[0] = 1
    size[0] = len(data)
    event('open', size=len(data))
    return 0

@READ
def read(opaque, target, length):
    global cursor
    if cancelled.is_set():
        return -1
    if cursor >= len(data):
        return 0
    # The beginning and final metadata are available; the middle is delayed.
    # A range-aware demuxer can open without consuming that unavailable middle.
    if gap <= cursor < len(data)-65536 and time.monotonic()-began < delay:
        event('wait', offset=cursor, requested=length)
        while time.monotonic()-began < delay:
            if cancelled.wait(.02):
                return -1
    count = min(length, 256 * 1024, len(data)-cursor)
    if cursor < gap:
        count = min(count, gap-cursor)
    C.memmove(target, data[cursor:cursor+count], count)
    cursor += count
    return count

@SEEK
def seek(opaque, offset):
    global cursor
    event('seek', offset=offset)
    cursor = offset
    return 0

@CLOSE
def close(opaque):
    event('close')

options = ['--intf=dummy', '--vout=dummy', '--aout=dummy', '--no-video-title-show',
           '--no-sub-autodetect-file', '--no-osd', '--avcodec-threads=2', '--stats',
           '--verbose=2'] + sys.argv[2:]
argv = (C.c_char_p * len(options))(*[s.encode() for s in options])
instance = api('new', P, C.c_int, C.POINTER(C.c_char_p))(len(options), argv)
if not instance:
    raise RuntimeError('VLC failed to initialize')
media = player = None
try:
    media = api('media_new_callbacks', P, P, OPEN, READ, SEEK, CLOSE, P)(instance, opened, read, seek, close, None)
    player = api('media_player_new_from_media', P, P)(media)
    play = api('media_player_play', C.c_int, P)
    get_time = api('media_player_get_time', C.c_int64, P)
    get_state = api('media_player_get_state', C.c_int, P)
    play(player)
    first = None
    last = None
    while time.monotonic()-began < 14:
        state, position = get_state(player), get_time(player)
        if state != last:
            event('state', state=state, position=position)
            last = state
        if position > 0 and first is None:
            first = time.monotonic()-began
            event('advancing', position=position)
        if first is not None and time.monotonic()-began > first+1:
            break
        time.sleep(.1)
finally:
    cancelled.set()
    if player:
        api('media_player_stop', None, P)(player)
        api('media_player_release', None, P)(player)
    if media:
        api('media_release', None, P)(media)
    api('release', None, P)(instance)
print(json.dumps({'first_advance': first, 'events': events}, indent=2))
