"""Fetch display metadata/artwork as data; no downloaded executable code is run."""
import json
import hashlib
import subprocess
import urllib.request
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'Resources/Rewind'
RESEARCH = ROOT / 'Research'
PICKS = {
    'movie': ['tt0816692', 'tt1375666', 'tt0245429', 'tt2582802', 'tt1160419',
              'tt2278388', 'tt0133093', 'tt6751668', 'tt3783958', 'tt0110912'],
    'series': ['tt0903747', 'tt4574334', 'tt7366338', 'tt5753856', 'tt11280740', 'tt0386676'],
}
FIELDS = ['id', 'name', 'type', 'poster', 'background', 'description', 'releaseInfo',
          'runtime', 'genres', 'imdbRating', 'cast', 'director', 'trailerStreams', 'trailers']

def fetch(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Rewind-Research/0.6'}), timeout=25).read()

def main():
    result = {}; provenance = []; artwork_map = {}
    for kind, identifiers in PICKS.items():
        result[kind] = []
        for identifier in identifiers:
            cache = RESEARCH / ('curated-' + identifier + '.json')
            url = 'https://v3-cinemeta.strem.io/meta/' + kind + '/' + identifier + '.json'
            try:
                if not cache.exists(): cache.write_bytes(fetch(url))
                raw = json.loads(cache.read_text())['meta']
                m = {k: raw[k] for k in FIELDS if raw.get(k) is not None}
                if m.get('type') != kind:
                    raise ValueError('Provider content type does not match the requested catalog')
                poster = OUT / ('poster-' + identifier + '.jpg')
                if not poster.exists():
                    poster.write_bytes(fetch(m['poster']))
                normalize(poster, 420)
                artwork_map[m['poster']] = poster.name
                provenance.append({'id': identifier, 'metadata': url, 'artwork': m['poster'],
                    'file': poster.name, 'sha256': hashlib.sha256(poster.read_bytes()).hexdigest()})
                m['poster'] = 'asset:' + poster.name
                if m.get('background'):
                    background = OUT / ('background-' + identifier + '.jpg')
                    if not background.exists(): background.write_bytes(fetch(m['background']))
                    normalize(background, 1100)
                    artwork_map[m['background']] = background.name
                    provenance.append({'id': identifier, 'artwork': m['background'], 'file': background.name,
                        'sha256': hashlib.sha256(background.read_bytes()).hexdigest()})
                    m['background'] = 'asset:' + background.name
                result[kind].append(m)
                print(m['name'], flush=True)
            except Exception as exc:
                print(identifier, type(exc).__name__, str(exc), flush=True)
    (OUT / 'curated.json').write_text(json.dumps(result, ensure_ascii=False, indent=2))
    (OUT / 'artwork-map.json').write_text(json.dumps(artwork_map, indent=2))
    (RESEARCH / 'artwork-provenance.json').write_text(json.dumps(provenance, indent=2))

def normalize(path, size):
    if path.read_bytes()[:4] == b'RIFF':
        tmp = path.with_suffix('.converted.jpg')
        subprocess.run([shutil.which('ffmpeg'), '-nostdin', '-hide_banner', '-loglevel', 'error',
            '-threads', '1', '-i', str(path), '-vf', 'scale=-2:' + str(size), '-frames:v', '1',
            '-threads', '1', '-q:v', '3', str(tmp)], check=True, timeout=30)
        tmp.replace(path)
    subprocess.run(['/usr/bin/sips', '-Z', str(size), str(path)], check=True, capture_output=True)

if __name__ == '__main__': main()
