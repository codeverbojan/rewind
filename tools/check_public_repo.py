#!/usr/bin/env python3
"""Validate the publishable tree without network, SDKs, credentials or devices."""
import ast
import json
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
DENIED = ('downloads/', 'diagnostics/', '.private/', 'library/', 'patch-work/',
          'standalone-media/build/', 'standalone-media/versions/',
          'standalone-media/Research/', 'standalone-media/Tests/Fixtures/')
SECRET_PATTERNS = (
    re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----'),
    re.compile(rb'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}'),
    re.compile(rb'AKIA[0-9A-Z]{16}'),
    re.compile(rb'/' + rb'Users/[^/\s]+/'),
)

def main():
    result = subprocess.run(['git', 'ls-files', '-z'], cwd=ROOT,
                            capture_output=True, check=True)
    paths = [ROOT / p.decode() for p in result.stdout.split(b'\0') if p]
    failures = []
    links = 0
    for path in paths:
        rel = path.relative_to(ROOT).as_posix()
        if rel.startswith(DENIED) or rel == 'AGENTS.md':
            failures.append(f'Local-only path: {rel}')
        if rel.startswith('standalone-media/Resources/Rewind/') and path.suffix == '.json' and path.name != 'language-labels.json':
            failures.append(f'Harvested catalog requires removal: {rel}')
        if rel.startswith('standalone-media/Resources/Rewind/') and (path.name.startswith('poster-tt') or path.name.startswith('background-tt')):
            failures.append(f'Standalone commercial artwork: {rel}')
        if path.is_symlink():
            failures.append(f'Symlink requires review: {rel}')
            continue
        if not path.is_file():
            failures.append(f'Missing tracked file: {rel}')
            continue
        blob = path.read_bytes()
        if len(blob) > 10 * 1024 * 1024:
            failures.append(f'File exceeds 10 MiB: {rel}')
        if path.suffix in {'.key', '.p12', '.pfx', '.mobileprovision', '.ipa', '.sqlite'}:
            failures.append(f'Private/generated file: {rel}')
        if path.suffix == '.pem' and rel != 'standalone-media/Resources/Rewind/tracker-roots.pem':
            failures.append(f'Unreviewed PEM: {rel}')
        if any(p.search(blob) for p in SECRET_PATTERNS):
            failures.append(f'Sensitive-pattern match (content withheld): {rel}')
        if path.suffix == '.py':
            try:
                ast.parse(blob, filename=rel)
            except SyntaxError as e:
                failures.append(f'Python syntax: {rel}:{e.lineno}')
        if path.suffix == '.json':
            try:
                json.loads(blob)
            except (ValueError, UnicodeDecodeError):
                failures.append(f'Invalid JSON: {rel}')
        if path.suffix == '.md':
            text = blob.decode('utf-8')
            urls = re.findall(r'!?\[[^\]]*\]\(([^\s)]+)(?:\s+[^)]*)?\)', text)
            urls += re.findall(r'(?:src|href)="([^"]+)"', text)
            for url in urls:
                if url.startswith('#') or urlsplit(url).scheme:
                    continue
                target = unquote(url.split('#', 1)[0].split('?', 1)[0])
                if target and not (path.parent / target).exists():
                    failures.append(f'Broken local link: {rel} -> {target}')
                links += 1
    for name in ('README.md', 'LICENSE', 'CONTRIBUTING.md', 'SECURITY.md',
                 'THIRD_PARTY_NOTICES.md', 'docs/assets/rewind-logo.svg'):
        if not (ROOT / name).is_file():
            failures.append(f'Missing project file: {name}')
    print(json.dumps({'files': len(paths), 'local_links': links,
                      'failures': failures}, indent=2))
    return bool(failures)

if __name__ == '__main__':
    sys.exit(main())
