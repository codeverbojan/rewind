"""Single sequential CPU benchmark. No network, browser, server or iPad writes."""
import hashlib,json,os,pathlib,signal,subprocess,sys
root=pathlib.Path(__file__).resolve().parents[1]
label=sys.argv[1] if len(sys.argv)>1 else 'current'
if label not in ('before','after','current'):raise SystemExit('Use before, after or current')
current=None
def stop(*args):
    if current is not None and current.poll() is None:
        os.killpg(current.pid,signal.SIGTERM)
        try:current.wait(timeout=3)
        except subprocess.TimeoutExpired:os.killpg(current.pid,signal.SIGKILL);current.wait()
    if args:raise SystemExit(130)
signal.signal(signal.SIGINT,stop);signal.signal(signal.SIGTERM,stop)
def run(args):
    global current
    current=subprocess.Popen([str(x) for x in args],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,start_new_session=True)
    print('Owned ranking benchmark process group:',current.pid,flush=True)
    out,err=current.communicate(timeout=30)
    if current.returncode:raise RuntimeError(err)
    return out
try:
    binary=root/'build/source-ranking-benchmark'
    run(['/usr/bin/clang','-Os','-fobjc-arc','-Wno-deprecated-declarations','-framework','Foundation',root/'Tests/SourceRankingBenchmark.m',root/'RWSourcePolicy.m','-o',binary])
    report=json.loads(run([binary,*[root/'Research/providers'/name for name in ['current-spiderman-streams.json','older-film-streams.json','series-episode-streams.json']]]))
    report['source_sha256']=hashlib.sha256((root/'RWSourcePolicy.m').read_bytes()).hexdigest()
    (root.parent/f'diagnostics/source-ranking-{label}-0.31.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report),flush=True)
finally:stop()
