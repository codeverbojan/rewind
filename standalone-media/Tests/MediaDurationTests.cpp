#include "../RWMediaDuration.h"
#include <vector>
#include <cstdio>
#include <fstream>
using Bytes=std::vector<uint8_t>;
static void put(Bytes &b,uint64_t v,size_t n){for(size_t i=n;i>0;i--)b.push_back(uint8_t(v>>((i-1)*8)));}
static void append(Bytes &b,const Bytes &v){b.insert(b.end(),v.begin(),v.end());}
static Bytes atom(uint32_t id,Bytes body,bool extended=false){Bytes b;put(b,extended?1:body.size()+8,4);put(b,id,4);if(extended)put(b,body.size()+16,8);append(b,body);return b;}
static Bytes mvhd(bool large,uint64_t ticks,uint32_t scale){Bytes b(large?32:20);b[0]=large?1:0;Bytes n;put(n,scale,4);put(n,ticks,large?8:4);std::copy(n.begin(),n.end(),b.begin()+(large?20:12));return atom(0x6d766864,b);}
static Bytes element(uint64_t id,unsigned idBytes,Bytes body){Bytes b;put(b,id,idBytes);if(body.size()<127)put(b,128|body.size(),1);else put(b,16384|body.size(),2);append(b,body);return b;}
static Bytes mkv(double ticks,uint64_t scale,bool durationFirst=false){Bytes d;uint64_t bits;std::memcpy(&bits,&ticks,8);put(d,bits,8);Bytes duration=element(0x4489,2,d),s;put(s,scale,3);Bytes scaling=element(0x2ad7b1,3,s),info;if(durationFirst){append(info,duration);append(info,scaling);}else{append(info,scaling);append(info,duration);}return element(0x18538067,4,element(0x1549a966,4,info));}
static RWMediaDuration parse(RWMediaDuration::Format kind,const Bytes &b){RWMediaDuration p(kind,b.size());for(int i=0;i<65&&p.state()==RWMediaDuration::Waiting;i++){if(p.offset()>b.size()||p.length()>b.size()-p.offset())break;p.consume(b.data()+p.offset(),p.length());}return p;}
int main(int argc,char **argv){int checks=0,failures=0;auto check=[&](bool ok,const char *why){checks++;if(!ok){failures++;fprintf(stderr,"FAIL:%s\n",why);}};
 Bytes front=atom(0x6d6f6f76,mvhd(false,72000,1000));append(front,atom(0x6d646174,Bytes(200,1)));check(parse(RWMediaDuration::MP4,front).seconds()==72,"MP4 version0 uses timescale");
 Bytes tail=atom(0x6d646174,Bytes(200,1));append(tail,atom(0x6d6f6f76,mvhd(true,72000000000ULL,1000000000),true));check(parse(RWMediaDuration::MP4,tail).seconds()==72,"Extended tail moov and version1 fields");
 Bytes fake=atom(0x6d646174,front);check(parse(RWMediaDuration::MP4,fake).state()==RWMediaDuration::Unavailable,"Do not scan payload for fake duration markers");
 check(parse(RWMediaDuration::MP4,atom(0x6d6f6f76,mvhd(false,72000,0))).state()==RWMediaDuration::Unavailable,"Zero scale rejected");
 check(parse(RWMediaDuration::MP4,atom(0x6d6f6f76,mvhd(false,UINT32_MAX,1000))).state()==RWMediaDuration::Unavailable,"Unknown32bit duration rejected");
 check(parse(RWMediaDuration::MP4,atom(0x6d6f6f76,mvhd(true,UINT64_MAX,1000))).state()==RWMediaDuration::Unavailable,"Unknown64bit duration rejected");
 Bytes invalid=front;invalid[0]=0x7f;check(parse(RWMediaDuration::MP4,invalid).state()==RWMediaDuration::Unavailable,"Atom escaping file rejected");
 Bytes crowded;for(int i=0;i<70;i++)append(crowded,atom(0x66726565,{}));append(crowded,front);check(parse(RWMediaDuration::MP4,crowded).headers()==64,"Header walk bounded");
 check(parse(RWMediaDuration::Matroska,mkv(72000,1000000)).seconds()==72,"Matroska scale and double duration");
 check(parse(RWMediaDuration::Matroska,mkv(72000,1000000,true)).seconds()==72,"Scale after duration is honored");
 check(parse(RWMediaDuration::Matroska,mkv(NAN,1000000)).state()==RWMediaDuration::Unavailable,"NaN duration rejected");
 check(parse(RWMediaDuration::Matroska,mkv(72000,0)).state()==RWMediaDuration::Unavailable,"Zero Matroska scale rejected");
 check(parse(RWMediaDuration::Matroska,mkv(-1,1000000)).state()==RWMediaDuration::Unavailable,"Negative duration rejected");
 check(parse(RWMediaDuration::Matroska,mkv(1e20,1000000)).state()==RWMediaDuration::Unavailable,"Unreasonable duration rejected");
 Bytes unknown=mkv(72000,1000000);unknown[4]=0xff;check(parse(RWMediaDuration::Matroska,unknown).seconds()==72,"Unknown-size segment remains bounded by actual file");
 for(size_t n=0;n<front.size();n++) {Bytes truncated(front.begin(),front.begin()+n);auto p=parse(RWMediaDuration::MP4,truncated);check(p.state()!=RWMediaDuration::Waiting,"Truncated atom walk terminates");}
 if(argc>1){std::ifstream f(argv[1],std::ios::binary);Bytes bytes((std::istreambuf_iterator<char>(f)),{});check(parse(RWMediaDuration::MP4,bytes).seconds()==72,"Real generated MP4 runtime parsed");}
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}
