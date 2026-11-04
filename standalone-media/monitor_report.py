"""Bounded USB observation of this app's report. No device writes or servers."""
import argparse
import json
import pathlib
import signal
import sys
import time

root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / 'tools'))
import retroarch_usb as usb

args = argparse.ArgumentParser(description=__doc__)
args.add_argument('--version', required=True)
args.add_argument('--seconds', type=int, default=55, choices=range(1, 56), metavar='1..55')
options = args.parse_args()
if not options.version.replace('.', '').isdigit():
    raise SystemExit('Use a numeric release version.')
usb.APP_ID = b'org.local.ministreamlab'
signal.signal(signal.SIGALRM, lambda *_: sys.exit(124))
signal.alarm(options.seconds + 5)
end = time.monotonic() + options.seconds
last = None
prefix = root / 'diagnostics'
while time.monotonic() < end:
    try:
        with usb.Documents() as documents:
            report = json.loads(documents.read('/Documents/session-report.json'))
        if report.get('updated') != last:
            last = report.get('updated')
            with (prefix / ('rewind-monitor-' + options.version + '.jsonl')).open('a') as file:
                file.write(json.dumps(report) + '\n')
            (prefix / ('rewind-live-' + options.version + '.json')).write_text(json.dumps(report, indent=2))
            discovery = report.get('discovery', {})
            torrent = report.get('torrent', {})
            print(json.dumps({
                'build': report.get('build'), 'screen': report.get('screen'),
                'search': report.get('search_metrics'), 'episode_list': report.get('episode_list'),
                'trailer': report.get('trailer_state'), 'cast': report.get('cast_lookup'),
                'position': report.get('position'), 'exhausted': report.get('playback_exhausted'),
                'first_frame': report.get('playback_metrics', {}).get('first_frame_seconds'),
                'discovery_seconds': discovery.get('elapsed'), 'selected': discovery.get('selected'),
                'torrent': {key: torrent.get(key) for key in [
                    'peers', 'peer_payload_bytes', 'download_bytes_per_second',
                    'interested_peers', 'peers_choking_us', 'peer_requests_pending',
                    'requested_video_offset', 'requested_piece_finished_blocks',
                    'requested_piece_pending_blocks', 'resume_loaded']}
                    if discovery.get('selected') else {},
                'candidates': [{key: candidate.get(key) for key in [
                    'infoHash', 'peers', 'local_checking', 'torrent_progress', 'resume_loaded',
                    'resume_writes', 'opening_received_bytes', 'opening_missing_bytes',
                    'opening_eta_seconds', 'bytes_per_second', 'ready']}
                    for candidate in (discovery.get('candidates', []) if discovery.get('active') else [])]
            }), flush=True)
    except Exception as error:
        print(type(error).__name__, str(error)[:120], flush=True)
    time.sleep(min(5, max(0, end - time.monotonic())))
print('USB monitor finished; no retained process.', flush=True)
