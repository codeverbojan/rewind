"""Fetch bounded public metadata for the first-launch catalog; no device access.
Uses Wikidata's documented property-OR search, exact IMDb checks and a single
HTTP request at a time. Existing response files are reused. No API keys.
"""
from pathlib import Path
import json, urllib.request, urllib.parse, time, hashlib, os
ROOT=Path(__file__).resolve().parent
CACHE=ROOT/'Research/discovery-34/seed';CACHE.mkdir(exist_ok=True)
HEADERS={'User-Agent':'Rewind/0.34 (personal standalone iPad experiment)','Accept':'application/json'}
started=time.monotonic();log=[]
def fetch(params):
    if time.monotonic()-started>240:return {}
    query=urllib.parse.urlencode(params);url='https://www.wikidata.org/w/api.php?'+query
    key=hashlib.sha256(query.encode()).hexdigest();path=CACHE/(key+'.json')
    if path.exists():return json.loads(path.read_text())
    if os.environ.get('REWIND_SEED_OFFLINE')=='1':return {}
    cooldown=CACHE/'cooldown.json'
    if cooldown.exists() and json.loads(cooldown.read_text()).get('until',0)>time.time():return {}
    time.sleep(7)
    try:
        with urllib.request.urlopen(urllib.request.Request(url,headers=HEADERS),timeout=10) as response:
            data=response.read(4*1024*1024+1)
            if len(data)>4*1024*1024:raise ValueError('Metadata response exceeded 4 MiB')
        obj=json.loads(data)
        if 'error' in obj:raise ValueError(obj['error'].get('info','API error'))
        path.write_bytes(data);log.append({'url':url,'bytes':len(data),'file':path.name});return obj
    except urllib.error.HTTPError as exc:
        if exc.code in (429,503):
            delay=max(300,float(exc.headers.get('Retry-After','300')) if exc.headers.get('Retry-After','300').isdigit() else 300)
            (CACHE/'cooldown.json').write_text(json.dumps({'until':time.time()+delay,'http':exc.code}))
            os.environ['REWIND_SEED_OFFLINE']='1';log.append({'cooldown':exc.code,'seconds':delay});return {}
        raise

def values(entity,prop):
    return [s.get('mainsnak',{}).get('datavalue',{}).get('value') for s in entity.get('claims',{}).get(prop,[]) if s.get('rank')!='deprecated']

def main():
    chosen={}
    for name,limit in [('popular-movies',16),('top-rated-movies',18),('films-1995',12),('films-2025',12),('top-rated-series',14)]:
        for m in json.loads((ROOT/'Research/discovery-34'/(name+'.json')).read_text())['metas'][:limit]:chosen[m['id']]=m
    for name in ['inception','parasite','three-idiots','breaking-bad']:
        m=json.loads((ROOT/'Research/discovery-34'/(name+'.json')).read_text())['meta'];chosen[m['id']]=m
    ids=list(chosen);qids=set()
    for i in range(0,len(ids),8):
        query='haswbstatement:'+'|'.join('P345='+identifier for identifier in ids[i:i+8])
        obj=fetch({'action':'query','list':'search','format':'json','srnamespace':0,'srprop':'','srlimit':30,'srsearch':query})
        qids.update(row['title'] for row in obj.get('query',{}).get('search',[]))
    print(json.dumps({'requested':len(ids),'entity_search_matches':len(qids)}),flush=True)
    qids=sorted(qids);entities={};labels={}
    for i in range(0,len(qids),5):
        obj=fetch({'action':'wbgetentities','format':'json','props':'claims|labels','languages':'en','ids':'|'.join(qids[i:i+5])})
        for qid,entity in obj.get('entities',{}).items():
            if any(v in chosen for v in values(entity,'P345') if isinstance(v,str)):entities[qid]=entity
    for path in (ROOT/'Research/discovery-34').glob('*.json'):
        old=json.loads(path.read_text())
        if isinstance(old,dict):
            for qid,e in old.get('entities',{}).items():
                if 'claims' in e and any(v in chosen for v in values(e,'P345') if isinstance(v,str)):entities[qid]=e
                if 'labels' in e:labels[qid]=e
    refs=set()
    for entity in entities.values():
        for prop in ['P364','P495','P57','P272','P136','P921','P179','P161','P31']:
            refs.update(v['id'] for v in values(entity,prop)[:24] if isinstance(v,dict) and 'id' in v)
    refs=sorted(refs)
    for i in range(0,len(refs),50):
        labels.update(fetch({'action':'wbgetentities','format':'json','props':'labels','languages':'en','ids':'|'.join(refs[i:i+50])}).get('entities',{}))
    (CACHE/'seed-input.json').write_text(json.dumps({'entities':entities,'labels':labels,'catalog':chosen},separators=(',',':')))
    (CACHE/'fetch-log.json').write_text(json.dumps(log,indent=2))
    print(json.dumps({'verified_entities':len(entities),'labels':len(labels),'network_requests':len(log),'seconds':time.monotonic()-started}),flush=True)
if __name__=='__main__':main()
