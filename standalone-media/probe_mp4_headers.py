"""Inspect remote MP4 headers with strict byte limits; never download media payload.

Requires existing ffprobe. Only byte-range responses are accepted. Produces a
compact ftyp+moov fixture for inspecting track metadata, not a playable movie.
"""
import argparse,json,os,re,signal,struct,subprocess,urllib.request
from pathlib import Path

MAX_BYTES=12*1024*1024
class Reader:
    def __init__(self,url):self.url=url;self.bytes=0;self.total=None
    def read(self,start,length):
        if length<0 or self.bytes+length>MAX_BYTES:raise ValueError('12 MiB header budget exceeded')
        req=urllib.request.Request(self.url,headers={'User-Agent':'Rewind-Compatibility-Research/1.0','Range':f'bytes={start}-{start+length-1}','Accept-Encoding':'identity'})
        with urllib.request.urlopen(req,timeout=20) as response:
            content=response.headers.get('Content-Range','')
            match=re.fullmatch(r'bytes (\d+)-(\d+)/(\d+)',content)
            if response.status!=206 or not match or int(match[1])!=start or int(match[2])!=start+length-1:raise ValueError('Server did not honor the exact bounded byte range')
            total=int(match[3])
            if self.total is not None and total!=self.total:raise ValueError('Remote size changed during probe')
            self.total=total;data=response.read(length+1)
            if len(data)!=length:raise ValueError('Incomplete or oversized byte range')
            self.bytes+=len(data);return data

def codec_boxes(data):
    found=[]
    def walk(start,end):
        pos=start
        while pos+8<=end:
            size,kind=struct.unpack('>I4s',data[pos:pos+8]);head=8
            if size==1:
                if pos+16>end:break
                size=struct.unpack('>Q',data[pos+8:pos+16])[0];head=16
            if size==0:size=end-pos
            if size<head or pos+size>end:break
            payload=pos+head
            if kind==b'avcC' and size>=head+4:
                found.append({'type':'avcC','profile':data[payload+1],'level':data[payload+3]})
            elif kind in (b'moov',b'trak',b'mdia',b'minf',b'stbl'):walk(payload,pos+size)
            elif kind==b'stsd':walk(payload+8,pos+size)
            elif kind in (b'avc1',b'avc3'):walk(payload+78,pos+size)
            pos+=size
    walk(0,len(data));return found

def inspect(url,output):
    reader=Reader(url);offset=0;atoms=[];kept=[]
    for _ in range(32):
        header=reader.read(offset,16);size,kind=struct.unpack('>I4s',header[:8]);header_size=8
        if size==1:size=struct.unpack('>Q',header[8:16])[0];header_size=16
        if size==0:size=reader.total-offset
        if size<header_size or size>reader.total-offset:raise ValueError('Invalid MP4 atom bounds')
        atoms.append({'type':kind.decode('ascii',errors='replace'),'offset':offset,'bytes':size})
        if kind in (b'ftyp',b'moov'):
            kept.append(reader.read(offset,size))
        if kind==b'moov':break
        offset+=size
        if offset>=reader.total:raise ValueError('No moov atom')
    else:raise ValueError('Too many top-level atoms')
    fixture=output.with_suffix('.headers.mp4');fixture.write_bytes(b''.join(kept))
    proc=subprocess.Popen(['ffprobe','-v','error','-analyzeduration','0','-probesize','32','-show_streams','-show_format','-of','json',str(fixture)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,start_new_session=True)
    try:
        stdout,stderr=proc.communicate(timeout=15)
        if proc.returncode:raise ValueError(f'ffprobe rejected headers: {stderr.decode(errors="replace")[:200]}')
    finally:
        if proc.poll() is None:os.killpg(proc.pid,signal.SIGKILL);proc.communicate()
    result=json.loads(stdout);result.update({'codec_boxes':codec_boxes(b''.join(kept)),'source_url':url,'remote_size':reader.total,'network_bytes':reader.bytes,'atoms':atoms,'scope':'Header metadata only; no payload decoding or device playback tested'})
    output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'file':str(output),'network_bytes':reader.bytes,'duration':result.get('format',{}).get('duration'),'streams':[{key:s.get(key) for key in ['codec_name','profile','width','height','level','r_frame_rate','sample_rate','channels','bit_rate']} for s in result['streams']]}),flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('url');parser.add_argument('output',type=Path);args=parser.parse_args();inspect(args.url,args.output)
