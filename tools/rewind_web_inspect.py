"""Bounded read-only discovery of Rewind web views through approved USB libraries.
Uses official libimobiledevice webinspector.h and Google's ios-webkit-debug-proxy
RPC schema. Does not inspect Safari pages, start a server, or change settings.
"""
import ctypes as C, json, plistlib, signal, time, uuid
from pathlib import Path
import retroarch_usb as usb
usb.APP_ID=b'org.local.ministreamlab'
def main():
 signal.alarm(18)
 with usb.Documents() as d:
  P=usb.P;client=P()
  for name,args in {'webinspector_client_start_service':[P,C.POINTER(P),C.c_char_p],'webinspector_send':[P,P],'webinspector_receive_with_timeout':[P,C.POINTER(P),C.c_uint32],'webinspector_client_free':[P]}.items():
   f=getattr(d.lib,name);f.argtypes=args;f.restype=C.c_int
  d.plist.plist_from_xml.argtypes=[C.c_char_p,C.c_uint32,C.POINTER(P)];d.plist.plist_from_xml.restype=C.c_int
  def send(selector,args):
   data=plistlib.dumps({'__selector':selector,'__argument':args});p=P()
   usb.check(d.plist.plist_from_xml(data,len(data),C.byref(p)),'Encode inspector message')
   try:usb.check(d.lib.webinspector_send(client,p),'Send inspector message')
   finally:d.plist.plist_free(p)
  code=d.lib.webinspector_client_start_service(d.device,C.byref(client),b'RewindReadOnlyInspection')
  if code:print(json.dumps({'connected':False,'code':code}));return
  result={'connected':True,'rewind_app_ids':[],'rewind_pages':[],'selectors':[]};cid=str(uuid.uuid4()).upper();base={'WIRConnectionIdentifierKey':cid};targets=set()
  try:
   send('_rpc_reportIdentifier:',base);send('_rpc_getConnectedApplications:',base)
   end=time.monotonic()+8
   while time.monotonic()<end:
    p=P();code=d.lib.webinspector_receive_with_timeout(client,C.byref(p),600)
    if code:
     if p:d.plist.plist_free(p)
     continue
    xml=P();size=C.c_uint32()
    try:
     usb.check(d.plist.plist_to_xml(p,C.byref(xml),C.byref(size)),'Decode inspector response');message=plistlib.loads(C.string_at(xml,size.value))
    finally:
     if xml:d.plist.plist_mem_free(xml)
     if p:d.plist.plist_free(p)
    selector=message.get('__selector');args=message.get('__argument',{})
    if selector not in result['selectors']:result['selectors'].append(selector)
    apps=args.get('WIRApplicationDictionaryKey',{})
    candidates=list(apps.values()) if isinstance(apps,dict) else []
    if 'WIRApplicationIdentifierKey' in args:candidates.append(args)
    for app in candidates:
     if not isinstance(app,dict):continue
     bundle=app.get('WIRApplicationBundleIdentifierKey','');name=app.get('WIRApplicationNameKey','');identifier=app.get('WIRApplicationIdentifierKey','')
     if bundle=='org.local.ministreamlab' or identifier=='org.local.ministreamlab' or name in ['Rewind','MiniStreamLab']:
      if identifier not in targets:
       targets.add(identifier);result['rewind_app_ids'].append(identifier);send('_rpc_forwardGetListing:',dict(base,WIRApplicationIdentifierKey=identifier))
    if args.get('WIRApplicationIdentifierKey') in targets:
     for page in args.get('WIRListingKey',{}).values():
      result['rewind_pages'].append({k:page.get(k) for k in ['WIRPageIdentifierKey','WIRTitleKey','WIRTypeKey','WIRURLKey']})
   Path('diagnostics/rewind-web-inspection.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
  finally:d.lib.webinspector_client_free(client)
if __name__=='__main__':main()
