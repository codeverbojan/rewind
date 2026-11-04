"""Bounded BEP 15/9 diagnostic: metadata only, hash verified; no media requests.
Uses Python stdlib, one tracker socket and up to four temporary peer sockets.
All sockets close on exit. No listener, seeding, or persistent service.
"""
import concurrent.futures as futures
import hashlib
import ipaddress
import json
import os
import pathlib
import socket
import struct
import sys
import threading
import time

def decode(b, i=0, depth=0):
    if depth > 20: raise ValueError('nesting')
    if b[i:i+1] == b'i':
        end=b.index(b'e',i+1);return int(b[i+1:end]),end+1
    if b[i:i+1] in (b'l',b'd'):
        dictionary=b[i:i+1]==b'd';out={} if dictionary else [];i+=1
        while b[i:i+1]!=b'e':
            value,i=decode(b,i,depth+1)
            if dictionary:
                child,i=decode(b,i,depth+1);out[value]=child
            else:out.append(value)
        return out,i+1
    colon=b.index(b':',i);size=int(b[i:colon]);end=colon+1+size
    if size<0 or end>len(b):raise ValueError('size')
    return b[colon+1:end],end

def encode(v):
    if isinstance(v,int):return b'i'+str(v).encode()+b'e'
    if isinstance(v,bytes):return str(len(v)).encode()+b':'+v
    return b'd'+b''.join(encode(k)+encode(v[k]) for k in sorted(v))+b'e'

hash_text=sys.argv[1];expected=bytes.fromhex(hash_text)
if len(expected)!=20:raise ValueError('hash')
deadline=time.monotonic()+25;finished=threading.Event();peer_id=b'-RW0020-'+os.urandom(12)
errors=[]
def tracker(host,port):
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as s:
        s.settimeout(2);s.connect((host,port));transaction=int.from_bytes(os.urandom(4),'big')
        s.send(struct.pack('!QII',0x41727101980,0,transaction));data=s.recv(4096)
        action,tid,connection=struct.unpack('!IIQ',data)
        if (action,tid)!=(0,transaction):raise ValueError('connect')
        transaction+=1
        # Metadata-only announce: no payload requests follow, no listening port.
        s.send(struct.pack('!QII20s20sQQQIIIiH',connection,1,transaction,expected,peer_id,0,1,0,2,0,0,64,0))
        data=s.recv(4096);action,tid,interval,leechers,seeds=struct.unpack('!IIIII',data[:20])
        if (action,tid)!=(1,transaction):raise ValueError('announce')
        peers=[]
        for i in range(20,len(data)-5,6):
            host=socket.inet_ntoa(data[i:i+4]);port=struct.unpack('!H',data[i+4:i+6])[0]
            if ipaddress.ip_address(host).is_global and port:peers.append((host,port))
        return peers,seeds,leechers

def metadata(peer):
    try:
        with socket.create_connection(peer,timeout=2) as s:
            s.settimeout(2)
            def receive(count):
                out=b''
                while len(out)<count:
                    if finished.is_set() or time.monotonic()>deadline:raise TimeoutError()
                    data=s.recv(count-len(out))
                    if not data:raise EOFError()
                    out+=data
                return out
            def send(payload):s.sendall(struct.pack('!I',len(payload))+payload)
            s.sendall(b'\x13BitTorrent protocol'+b'\0\0\0\0\0\x10\0\0'+expected+peer_id)
            hello=receive(68)
            if hello[28:48]!=expected:raise ValueError('handshake hash')
            send(b'\x14\0'+encode({b'm':{b'ut_metadata':1}}))
            chunks={};size=None;ext=None;end=time.monotonic()+8
            while time.monotonic()<min(end,deadline) and not finished.is_set():
                length=struct.unpack('!I',receive(4))[0]
                if length>2*1024*1024:raise ValueError('message size')
                if not length:continue
                message=receive(length)
                if message[:2]==b'\x14\0':
                    h,_=decode(message[2:]);size=h.get(b'metadata_size');ext=h.get(b'm',{}).get(b'ut_metadata')
                    if not ext or not isinstance(size,int) or not 0<size<=2*1024*1024:raise ValueError('metadata handshake')
                    for part in range((size+16383)//16384):send(bytes([20,ext])+encode({b'msg_type':0,b'piece':part}))
                elif message[:2]==b'\x14\x01' and size:
                    h,offset=decode(message[2:]);part=h.get(b'piece',-1)
                    if h.get(b'msg_type')!=1 or not 0<=part<(size+16383)//16384:continue
                    chunks[part]=message[2+offset:]
                    if len(chunks)==(size+16383)//16384:
                        raw=b''.join(chunks[i] for i in range(len(chunks)))
                        if len(raw)!=size or hashlib.sha1(raw).digest()!=expected:raise ValueError('metadata hash')
                        finished.set();return raw
    except (OSError,ValueError,IndexError,KeyError,EOFError) as e:errors.append(type(e).__name__)
    return None

report={'info_hash':hash_text,'trackers':[]};peers=[]
for host,port in [('tracker.opentrackr.org',1337),('tracker.torrent.eu.org',451)]:
    try:
        found,seeds,leechers=tracker(host,port);peers+=found
        report['trackers'].append({'host':host,'reported_seeds':seeds,'reported_leechers':leechers,'peers':len(found)})
    except (OSError,ValueError,struct.error) as e:report['trackers'].append({'host':host,'error':type(e).__name__})
raw=None
with futures.ThreadPoolExecutor(max_workers=4) as pool:
    jobs=[pool.submit(metadata,p) for p in list(dict.fromkeys(peers))[:24]]
    for job in futures.as_completed(jobs):
        result=job.result()
        if result and raw is None:raw=result
if raw:
    info,_=decode(raw);files=info.get(b'files',[{b'length':info.get(b'length',0),b'path':[info.get(b'name',b'')]}])
    report.update(metadata_verified=True,piece_bytes=info[b'piece length'],file_count=len(files),torrent_bytes=sum(f[b'length'] for f in files),first_files=[{'index':i,'bytes':f[b'length'],'path':'/'.join(p.decode(errors='replace') for p in f[b'path'])} for i,f in enumerate(files[:3])])
    pathlib.Path('diagnostics/'+hash_text+'.info').write_bytes(raw)
else:report['metadata_verified']=False
report['peer_errors']={name:errors.count(name) for name in set(errors)}
pathlib.Path('diagnostics/'+hash_text+'-metadata.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
