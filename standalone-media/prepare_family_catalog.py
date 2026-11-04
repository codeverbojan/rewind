"""Read public metadata, verify exact IMDb IDs, and bundle a small rated starting shelf."""
from pathlib import Path
import json,urllib.request,urllib.parse,time
ROOT=Path(__file__).resolve().parent;DEST=ROOT/'Research/experience';DEST.mkdir(parents=True,exist_ok=True)
IDS=['tt0114709','tt0266543','tt0910970','tt0382932','tt0126029','tt0892769','tt2096673','tt2380307','tt2948372','tt0245429','tt4633694','tt8050740']
def get(url):
 with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'RewindResearch/0.11 (org.local.ministreamlab)','Accept':'application/json'}),timeout=15) as f:
  data=f.read(5*1024*1024+1)
  if len(data)>5*1024*1024:raise ValueError('Response too large')
  return json.loads(data)
def api(**args):
 r=get('https://www.wikidata.org/w/api.php?'+urllib.parse.urlencode(dict(format='json',maxlag=5,**args)))
 (DEST/(args['action']+'-family.json')).write_text(json.dumps(r,indent=2))
 if 'error' in r:raise RuntimeError(str(r['error']))
 return r
search=api(action='query',list='search',srsearch='haswbstatement:'+'|'.join('P345='+i for i in IDS),srlimit=50,srnamespace=0,srprop='')
entities=api(action='wbgetentities',ids='|'.join(i['title'] for i in search['query']['search'] if i['title'].startswith('Q')),props='claims')['entities']
compact={}
for q,e in entities.items():
 c=e.get('claims',{})
 for claim in c.get('P345',[]):
  imdb=claim.get('mainsnak',{}).get('datavalue',{}).get('value')
  if imdb in IDS:compact[imdb]={'id':q,'claims':{p:c.get(p,[]) for p in ['P345','P1657','P2629']}}
(DEST/'family-rating-entities.json').write_text(json.dumps(compact,indent=2))
(ROOT/'Resources/Rewind/rating-entities.json').write_text(json.dumps(compact))
movies=[]
for imdb in IDS:
 kind='series' if imdb=='tt8050740' else 'movie'
 try:
  m=get('https://v3-cinemeta.strem.io/meta/'+kind+'/'+imdb+'.json')['meta']
  if m.get('id')!=imdb:continue
  m={k:v for k,v in m.items() if k in ['id','imdb_id','name','type','poster','background','description','releaseInfo','runtime','genres','imdbRating','preview','trailerStreams','trailers']}
  movies.append(m)
 except Exception as e:print(imdb,type(e).__name__)
 time.sleep(.2)
(ROOT/'Resources/Rewind/family-catalog.json').write_text(json.dumps({'items':movies}))
print(json.dumps({'matched_entities':len(compact),'catalog_titles':len(movies),'ratings':{i:[s['mainsnak'].get('datavalue',{}).get('value') for s in e['claims'].get('P1657',[])] for i,e in compact.items()}},indent=2))
