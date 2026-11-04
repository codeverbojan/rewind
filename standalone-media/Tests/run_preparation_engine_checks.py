"""One bounded local fixture stack using the actual engine. No iPad writes."""
import json,os,pathlib,signal,subprocess,tempfile,sys
root=pathlib.Path(__file__).resolve().parents[1]
src=root.parent/'downloads/standalone-media-sources/libtorrent-rasterbar-1.2.20'
boost=src.parent/'boost_1_84_0';out=root/'build/host-torrent';current=None
benchmark='--benchmark' in sys.argv
cache_checks='--cache-checks' in sys.argv
storage_checks='--storage-checks' in sys.argv
qualification_checks='--qualification-checks' in sys.argv
if sum([benchmark,cache_checks,storage_checks,qualification_checks])>1:raise SystemExit('Choose one fixture mode')
def stop(*args):
    if current is not None and current.poll() is None:
        os.killpg(current.pid,signal.SIGTERM)
        try:current.wait(timeout=5)
        except subprocess.TimeoutExpired:os.killpg(current.pid,signal.SIGKILL);current.wait()
    if args:raise SystemExit(130)
signal.signal(signal.SIGINT,stop);signal.signal(signal.SIGTERM,stop)
def verify_ports(stdout):
    for line in stdout.splitlines():
        if not line.startswith('{'):continue
        event=json.loads(line)
        if event.get('event')=='listener':
            probe=subprocess.run(['/usr/sbin/lsof','-nP','-iTCP:'+str(event['port']),'-sTCP:LISTEN'],capture_output=True,text=True,timeout=5)
            if probe.returncode!=1:raise RuntimeError('Fixture listener is still present: '+probe.stdout+probe.stderr)
            print('Released loopback port:',event['port'],flush=True)
def run(args,timeout,env=None):
    global current
    current=subprocess.Popen(args,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,start_new_session=True,env=env)
    print('Owned preparation test process group:',current.pid,flush=True)
    try:stdout,stderr=current.communicate(timeout=timeout)
    except BaseException:
        stop();stdout,stderr=current.communicate();verify_ports(stdout)
        (root.parent/'diagnostics/preparation-engine-0.33-interrupted.log').write_text(stdout+stderr)
        raise
    if stderr:print(stderr[-5000:],flush=True)
    verify_ports(stdout)
    if not benchmark and not cache_checks and not storage_checks and not qualification_checks and any('preparation-engine-tests' in str(arg) for arg in args) and stdout:
        (root.parent/'diagnostics/preparation-engine-0.33.jsonl').write_text(stdout)
    if current.returncode:
        (root.parent/'diagnostics/preparation-engine-0.33-failure.log').write_text(stdout+stderr)
        raise RuntimeError(f'Process failed ({current.returncode}): {stdout}')
    return stdout
flags=['-std=c++14','-Os','-fobjc-arc','-DRW_ENGINE_TESTING','-DNDEBUG','-DTORRENT_USE_I2P=0','-DTORRENT_DISABLE_LOGGING','-DBOOST_ASIO_ENABLE_CANCELIO','-DBOOST_ASIO_HAS_STD_CHRONO','-DBOOST_ASIO_USE_TS_EXECUTOR_AS_DEFAULT','-DBOOST_EXCEPTION_DISABLE','-Wno-deprecated-declarations','-I'+str(src/'include'),'-I'+str(boost)]
try:
    sources=['Tests/PreparationEngineTests.mm','TorrentEngine.mm','RWMediaCache.m'];objects=[]
    for source in sources:
        obj=out/('preparation-'+pathlib.Path(source).name+'.o');objects.append(str(obj))
        run(['/usr/bin/clang++',*flags,'-x','objective-c++','-c',str(root/source),'-o',str(obj)],60)
    binary=out/'preparation-engine-tests'
    run(['/usr/bin/clang++',*flags,*objects,str(out/'libtorrent.a'),'-framework','Foundation','-framework','CoreFoundation','-framework','SystemConfiguration','-lz','-o',str(binary)],30)
    if qualification_checks:
        with (root.parent/'diagnostics/preparation-qualification-0.33.jsonl').open('w') as saved:
            for piece,mode in [(1,'fast'),(1,'cached'),(1,'slow'),(8,'fast'),(8,'cached')]:
                with tempfile.TemporaryDirectory(prefix='rewind-qualification-') as fixture:
                    env=dict(os.environ,REWIND_ENGINE_FIXTURE_ROOT=fixture,REWIND_ENGINE_QUALIFICATION_MODE=mode,REWIND_ENGINE_BENCHMARK_MODE='cold',REWIND_ENGINE_PIECE_MIB=str(piece))
                    report=run([str(binary)],60,env)
                for line in report.splitlines():
                    if line.startswith('{'):
                        event=json.loads(line)
                        if event.get('event')=='qualification_check':saved.write(line+'\n');saved.flush();print(json.dumps({k:v for k,v in event.items() if k!='discovery'}),flush=True)
    elif storage_checks:
        target=root.parent/'diagnostics/preparation-storage-0.33.jsonl'
        with target.open('w') as saved:
            for piece in [1,8]:
                for mode in ['baseline','compact']:
                    with tempfile.TemporaryDirectory(prefix='rewind-storage-') as fixture:
                        env=dict(os.environ,REWIND_ENGINE_FIXTURE_ROOT=fixture,REWIND_ENGINE_BENCHMARK_MODE='cold',REWIND_ENGINE_PIECE_MIB=str(piece),REWIND_ENGINE_STORAGE_CHECK='1')
                        if mode=='compact':env['REWIND_ENGINE_COMPACT_STORAGE']='1'
                        else:env['REWIND_ENGINE_LEGACY_STORAGE']='1'
                        report=run([str(binary)],110,env)
                    for line in report.splitlines():
                        if line.startswith('{'):
                            event=json.loads(line)
                            if event.get('event')=='storage_check':saved.write(json.dumps(event)+'\n');saved.flush();print(json.dumps(event),flush=True)
    elif cache_checks:
        target=root.parent/'diagnostics/preparation-cache-0.33.jsonl'
        with target.open('w') as saved:
            for piece in [1,4,8]:
                for mode in ['metadata','partial','complete','cancel']:
                    with tempfile.TemporaryDirectory(prefix='rewind-cache-') as fixture:
                        env=dict(os.environ,REWIND_ENGINE_FIXTURE_ROOT=fixture,REWIND_ENGINE_BENCHMARK_MODE='cold',REWIND_ENGINE_PIECE_MIB=str(piece),REWIND_ENGINE_CACHE_MODE=mode)
                        report=run([str(binary)],100,env)
                    for line in report.splitlines():
                        if line.startswith('{'):
                            event=json.loads(line)
                            if event.get('event')=='cache_check':saved.write(json.dumps(event)+'\n');saved.flush();print(json.dumps(event),flush=True)
    elif benchmark:
        target=root.parent/'diagnostics/preparation-benchmark-0.33.jsonl'
        with target.open('w') as saved:
            modes=['cold','metadata5','preload5','preload10']
            for piece in [1,4,8]:
                for sample in range(3):
                    order=modes[sample:]+modes[:sample]
                    for mode in order:
                        with tempfile.TemporaryDirectory(prefix='rewind-benchmark-') as fixture:
                            env=dict(os.environ,REWIND_ENGINE_FIXTURE_ROOT=fixture,REWIND_ENGINE_BENCHMARK_MODE=mode,REWIND_ENGINE_PIECE_MIB=str(piece))
                            report=run([str(binary)],60,env)
                        for line in report.splitlines():
                            if line.startswith('{'):
                                event=json.loads(line)
                                if event.get('event')=='benchmark':
                                    event['sample']=sample+1;saved.write(json.dumps(event)+'\n');saved.flush();print(json.dumps(event),flush=True)
    else:
        with tempfile.TemporaryDirectory(prefix='rewind-preparation-') as fixture:
            env=dict(os.environ,REWIND_ENGINE_FIXTURE_ROOT=fixture)
            report=run([str(binary)],100,env)
        (root.parent/'diagnostics/preparation-engine-0.33.jsonl').write_text(report)
        print(report.strip(),flush=True)
finally:stop()
