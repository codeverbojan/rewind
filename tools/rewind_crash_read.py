"""Copy Rewind crash diagnostics via existing approved USB libraries; never delete.

API reference: official libimobiledevice tools/idevicecrashreport.c and lockdown.h.
By default only opens crashreportcopymobile, without invoking crashreportmover.
"""
import argparse
import ctypes as C
import hashlib
import json
from pathlib import Path, PurePosixPath
from retroarch_usb import Documents, P, PP, STRS, check


class CrashReports(Documents):
    def __enter__(self):
        self.lockdown, self.service = P(), P()
        for name, args in {
            'lockdownd_client_new_with_handshake': [P, PP, C.c_char_p],
            'lockdownd_start_service': [P, C.c_char_p, PP],
            'lockdownd_client_free': [P],
            'lockdownd_service_descriptor_free': [P],
            'afc_client_new': [P, P, PP],
        }.items():
            fn = getattr(self.lib, name)
            fn.argtypes, fn.restype = args, C.c_int
        try:
            devices, count = STRS(), C.c_int()
            check(self.lib.idevice_get_device_list(C.byref(devices), C.byref(count)), 'List USB devices')
            try:
                if count.value != 1:
                    raise RuntimeError(f'Expected one USB device; found {count.value}')
                udid = bytes(devices[0])
            finally:
                self.lib.idevice_device_list_free(devices)
            check(self.lib.idevice_new_with_options(C.byref(self.device), udid, 1), 'Connect USB')
            check(self.lib.lockdownd_client_new_with_handshake(self.device, C.byref(self.lockdown), b'RewindCrashRead'), 'Open paired diagnostic session')
            check(self.lib.lockdownd_start_service(self.lockdown, b'com.apple.crashreportcopymobile', C.byref(self.service)), 'Open crash report copy service')
            check(self.lib.afc_client_new(self.device, self.service, C.byref(self.afc)), 'Connect crash report reader')
            return self
        except BaseException:
            self.close()
            raise
        finally:
            for handle, fn in [(self.service, self.lib.lockdownd_service_descriptor_free), (self.lockdown, self.lib.lockdownd_client_free)]:
                if handle:
                    fn(handle)
                    handle.value = None

    @staticmethod
    def path(value, allow_root=False):
        p = PurePosixPath(value)
        if '..' in p.parts or not p.is_absolute():
            raise ValueError('Absolute diagnostic paths only')
        return str(p).encode()

    def put_new(self, *args):
        raise RuntimeError('Read-only crash reader')

    def mkdirs(self, *args):
        raise RuntimeError('Read-only crash reader')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    manifest = []
    with CrashReports() as device:
        pending = [('/', 0)]
        while pending:
            folder, depth = pending.pop()
            for name in device.ls(folder) or []:
                if name in ('.', '..'):
                    continue
                remote = str(PurePosixPath(folder) / name)
                info = device.stat(remote)
                if info is None:
                    continue
                if info.get('st_ifmt') == 'S_IFDIR' and depth < 3:
                    pending.append((remote, depth + 1))
                elif info.get('st_ifmt') == 'S_IFREG' and any(term in name.lower() for term in ('ministream', 'rewind', 'jetsam')):
                    if len(manifest) >= 100:
                        raise RuntimeError('Diagnostic file limit reached')
                    data = device.read(remote)
                    target = args.output / remote.lstrip('/')
                    target.parent.mkdir(parents=True, exist_ok=True)
                    if target.exists() and target.read_bytes() != data:
                        raise FileExistsError(target)
                    target.write_bytes(data)
                    record = {'remote': remote, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
                    manifest.append(record)
                    print(json.dumps(record), flush=True)
    (args.output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Copied {len(manifest)} reports; device originals retained')


if __name__ == '__main__':
    main()
