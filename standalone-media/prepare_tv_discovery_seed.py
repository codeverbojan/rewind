"""Bounded, sequential TVmaze primary-language seed; exact IMDb identity only."""
from pathlib import Path
import json,time,urllib.request,urllib.parse,urllib.error
root=Path(__file__).resolve().parent
source=root/'Research/discovery-34/seed/seed-input.json';raw=json.loads(source.read_text());cache=source.parent/'tvmaze';cache.mkdir(exist_ok=True)
shows={};started=time.monotonic()
for imdb,meta in raw['catalog'].items():
 if meta.get('type')!='series':continue
 path=cache/(imdb+'.json')
 if path.exists():show=json.loads(path.read_text())
 else:
  if time.monotonic()-started>120:break
  time.sleep(.7)
  try:
   request=urllib.request.Request('https://api.tvmaze.com/lookup/shows?imdb='+urllib.parse.quote(imdb),headers={'User-Agent':'Rewind/0.34 personal iPad experiment'})
   with urllib.request.urlopen(request,timeout=8) as response:data=response.read(1024*1024)
   show=json.loads(data);path.write_text(json.dumps(show))
  except urllib.error.HTTPError as exc:
   if exc.code in (429,503):break
   continue
  except (OSError,ValueError):continue
 if show.get('externals',{}).get('imdb')==imdb and show.get('language'):shows[imdb]=show
raw['tvmaze']=shows;source.write_text(json.dumps(raw,separators=(',',':')))
print(json.dumps({'verified_series_languages':len(shows),'seconds':time.monotonic()-started}))
