"""Read-only BEP 15 scrape. No peer announcement, media payload, or seeding."""
import json,secrets,socket,struct,time
from pathlib import Path
HASHES=['4f10f81747bffafccfe3cf09ff076d439e5589d3','b665ec81c51f24eb900ce571fe5174a2a3bb1338']
results=[]
for host,port in [('tracker.torrent.eu.org',451),('tracker.opentrackr.org',1337)]:
    start=time.monotonic();report={'tracker':f'udp://{host}:{port}','scope':'One read-only scrape from the Mac; not proof of payload availability'}
    try:
        address=socket.getaddrinfo(host,port,socket.AF_INET,socket.SOCK_DGRAM)[0][4]
        with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:
            sock.settimeout(15);sock.connect(address);transaction=secrets.randbits(32)
            sock.send(struct.pack('!QII',0x41727101980,0,transaction));data=sock.recv(2048)
            if len(data)<16 or struct.unpack('!II',data[:8])!=(0,transaction):raise ValueError('Invalid connect response')
            connection=struct.unpack('!Q',data[8:16])[0];transaction=secrets.randbits(32)
            sock.send(struct.pack('!QII',connection,2,transaction)+b''.join(bytes.fromhex(h) for h in HASHES));data=sock.recv(2048)
            if len(data)<8+12*len(HASHES) or struct.unpack('!II',data[:8])!=(2,transaction):raise ValueError('Invalid scrape response')
            report['hashes']=[{'infoHash':h,**dict(zip(['seeders','completed','leechers'],struct.unpack('!III',data[8+12*i:20+12*i])))} for i,h in enumerate(HASHES)]
    except Exception as error:report['error']=str(error) or type(error).__name__
    report['elapsed_seconds']=round(time.monotonic()-start,3);results.append(report);print(json.dumps(report),flush=True)
Path('diagnostics/publisher-swarm-scrape.json').write_text(json.dumps(results,indent=2)+'\n')
