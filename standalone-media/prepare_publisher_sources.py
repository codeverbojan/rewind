"""Build supplemental publisher source records from saved, reviewed metadata.

Does not fetch anything, execute downloaded code, or install onto the device.
"""
import hashlib,json,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parent
RESEARCH=ROOT/'Research/providers'

def torrent_record(path):
    data=path.read_bytes();pos=0;info_range=None
    if len(data)>2*1024*1024:raise ValueError('Torrent metadata exceeds 2 MiB')
    def decode(depth=0):
        nonlocal pos,info_range
        if depth>32 or pos>=len(data):raise ValueError('Invalid nesting or truncated input')
        token=data[pos:pos+1]
        if token==b'i':
            end=data.index(b'e',pos);value=int(data[pos+1:end]);pos=end+1;return value
        if token in (b'd',b'l'):
            mapping=token==b'd';pos+=1;out={} if mapping else []
            while data[pos:pos+1]!=b'e':
                if mapping:
                    key=decode(depth+1);start=pos;out[key]=decode(depth+1)
                    if depth==0 and key==b'info':info_range=(start,pos)
                else:out.append(decode(depth+1))
            pos+=1;return out
        end=data.index(b':',pos);size=int(data[pos:end]);pos=end+1
        if size<0 or pos+size>len(data):raise ValueError('Invalid string bounds')
        value=data[pos:pos+size];pos+=size;return value
    root=decode()
    if pos!=len(data) or not info_range:raise ValueError('Invalid torrent envelope')
    info=root[b'info']
    if info.get(b'private',0):raise ValueError('Publisher qualification fixtures must be public')
    digest=hashlib.sha1(data[slice(*info_range)]).hexdigest()
    trackers=[entry.decode() for tier in root.get(b'announce-list',[]) for entry in tier]
    files=[{'fileIdx':i,'filename':b'/'.join(f[b'path']).decode(),'sizeBytes':f[b'length']} for i,f in enumerate(info[b'files'])]
    return {'infoHash':digest,'metadataBytes':info_range[1]-info_range[0],'pieceLength':info[b'piece length'],'files':files,'trackers':trackers}

def main():
    mapping={};evidence=[]
    specs=[('tt1172203','Sita Sings the Blues','sita-torrent.torrent','https://www.sitasingstheblues.com/watch.html','https://www.sitasingstheblues.com/license.html',[(1080,'Sita_Sings_the_Blues_1080p.mp4'),(720,'Sita_Sings_the_Blues_720p.mp4'),(480,'Sita_Sings_the_Blues_480p_2150kbps.mp4')]),('tt3268458',"The Internet's Own Boy: The Story of Aaron Swartz",'own-boy-torrent.torrent','https://archive.org/details/TheInternetsOwnBoyTheStoryOfAaronSwartz','https://creativecommons.org/licenses/by-nc-sa/4.0/',[(720,'TheInternetsOwnBoy_TheStoryofAaronSwartz-HD.mp4')])]
    for identifier,title,name,source_url,license_url,variants in specs:
        torrent=torrent_record(RESEARCH/name);sources=[]
        destination=ROOT/'Resources/Rewind/torrents';destination.mkdir(exist_ok=True)
        shutil.copy2(RESEARCH/name,destination/(torrent['infoHash']+'.torrent'))
        for quality,filename in variants:
            file=next(f for f in torrent['files'] if f['filename']==filename)
            prefix='sita' if identifier=='tt1172203' else 'own-boy'
            probe=json.loads((RESEARCH/f'{prefix}-{quality}-probe.json').read_text())
            video=next(s for s in probe['streams'] if s.get('codec_type')=='video');audio=next(s for s in probe['streams'] if s.get('codec_type')=='audio')
            assert video['codec_name']=='h264' and audio['codec_name']=='aac'
            assert (video['width'],video['height']) in [(1920,1080),(1280,720),(848,480)]
            source={**file,'infoHash':torrent['infoHash'],'sources':['tracker:'+t for t in torrent['trackers']],'name':f'{quality}p H.264 AAC','publisherSource':True,'publisherURL':source_url,'licenseURL':license_url,'verifiedWidth':video['width'],'verifiedHeight':video['height'],'expectedDuration':float(probe['format']['duration'])}
            sources.append(source)
        mapping[identifier]=sources;evidence.append({'id':identifier,'title':title,'torrent':torrent,'source_url':source_url,'license_url':license_url,'qualifications':{'headers_probed':True,'device_playback':False,'live_swarm':False,'audio_audibility':False}})
    (ROOT/'Resources/Rewind/publisher-sources.json').write_text(json.dumps(mapping,indent=2)+'\n')
    (RESEARCH/'publisher-qualification.json').write_text(json.dumps(evidence,indent=2)+'\n')
    print(json.dumps({'titles':len(mapping),'encodes':sum(map(len,mapping.values())),'device_playback_verified':False}))

if __name__=='__main__':main()
