"""Build the existing pinned libtorrent sources for a bounded Mac-only test.
One compiler at a time; no installation, downloads or listening services.
"""
import hashlib
import pathlib
import re
import signal
import subprocess
root=pathlib.Path(__file__).resolve().parents[1]
src=root.parent/'downloads/standalone-media-sources/libtorrent-rasterbar-1.2.20'
boost=src.parent/'boost_1_84_0';out=root/'build/host-torrent';out.mkdir(exist_ok=True)
flags=['-std=c++14','-Os','-DNDEBUG','-DTORRENT_USE_I2P=0','-DTORRENT_DISABLE_LOGGING','-DBOOST_ASIO_ENABLE_CANCELIO','-DBOOST_ASIO_HAS_STD_CHRONO','-DBOOST_ASIO_USE_TS_EXECUTOR_AS_DEFAULT','-DBOOST_EXCEPTION_DISABLE','-Wno-deprecated-declarations','-I'+str(src/'include'),'-I'+str(boost)]
current=None
def stop(*args):
    if current is not None and current.poll() is None:
        current.terminate()
        try:current.wait(timeout=3)
        except subprocess.TimeoutExpired:current.kill();current.wait()
    raise SystemExit(130)
signal.signal(signal.SIGTERM,stop);signal.signal(signal.SIGINT,stop)
paths=[];cmake=(src/'CMakeLists.txt').read_text()
for group,prefix in [('sources','src'),('kademlia_sources','src/kademlia'),('ed25519_sources','ed25519/src')]:
    body=re.search(r'set\('+group+r'\s+(.*?)\n\)',cmake,re.S)[1]
    paths.extend(src/prefix/name for name in re.findall(r'^\s*([a-z0-9_]+\.cpp)\s*$',body,re.M))
paths.extend(src/'src'/name for name in ['pe_crypto.cpp','hasher512.cpp','sha512.cpp'])
objects=[]
try:
    for index,path in enumerate(paths):
        obj=out/(str(path.relative_to(src)).replace('/','_')+'.o');objects.append(obj)
        checksum=hashlib.sha256(path.read_bytes()+str(flags).encode()).hexdigest();marker=obj.with_suffix('.sha256')
        if obj.exists() and marker.exists() and marker.read_text()==checksum:continue
        with obj.with_suffix('.log').open('w') as log:
            current=subprocess.Popen(['/usr/bin/clang++',*flags,'-DTORRENT_BUILDING_LIBRARY','-c',str(path),'-o',str(obj)],stdout=log,stderr=log)
            try:code=current.wait(timeout=60)
            except subprocess.TimeoutExpired:current.kill();current.wait();raise
        if code:raise RuntimeError(str(path)+' failed: '+obj.with_suffix('.log').read_text()[-2000:])
        marker.write_text(checksum)
        if index%20==0:print(str(index+1)+'/'+str(len(paths)),flush=True)
    subprocess.run(['/usr/bin/ar','rcs',str(out/'libtorrent.a'),*map(str,objects)],check=True,timeout=30)
    print('Host library ready.',flush=True)
finally:
    if current is not None and current.poll() is None:current.terminate();current.wait(timeout=5)
