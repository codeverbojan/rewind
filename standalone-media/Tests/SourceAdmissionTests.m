#import "../RWSourceAdmission.h"
static int checks,failures;
static void Check(BOOL ok){checks++;if(!ok)failures++;}
static NSDictionary *Source(int index,double score){NSString *h=[NSString stringWithFormat:@"%040x",index];return @{@"infoHash":h,@"url":[@"magnet:?xt=urn:btih:" stringByAppendingString:h],@"fileIdx":@0,@"filename":@"movie.mp4",@"score":@(score)};}
int main(){@autoreleasepool{
 NSMutableArray *q=[NSMutableArray new];NSMutableSet *keys=[NSMutableSet new];NSMutableArray *offered=[NSMutableArray new];
 for(int i=0;i<12;i++)[offered addObject:Source(i,100-i)];RWAdmitSources(q,keys,0,offered);Check(q.count==12);
 NSArray *started=[q subarrayWithRange:NSMakeRange(0,3)];RWAdmitSources(q,keys,3,@[Source(12,300)]);
 Check(q.count==13&&[q[3][@"infoHash"]isEqual:Source(12,300)[@"infoHash"]]);Check([[q subarrayWithRange:NSMakeRange(0,3)]isEqual:started]);
 // A provider update enriches metadata without changing the bound file locator.
 NSMutableDictionary *update=[Source(7,500)mutableCopy];update[@"metadataURL"]=@"https://yts.gg/torrent/download/example";
 RWAdmitSources(q,keys,3,@[update]);Check(q.count==13&&[q[3][@"infoHash"]isEqual:update[@"infoHash"]]&&[q[3][@"metadataURL"]isEqual:update[@"metadataURL"]]);
 NSMutableDictionary *other=[update mutableCopy];other[@"fileIdx"]=@1;RWAdmitSources(q,keys,3,@[other]);Check(q.count==14&&keys.count==14);
 RWAdmitSources(q,keys,3,@[other,other]);Check(q.count==14&&keys.count==14);
 q=[NSMutableArray new];keys=[NSMutableSet new];offered=[NSMutableArray new];for(int i=0;i<80;i++)[offered addObject:Source(i,100-i)];RWAdmitSources(q,keys,0,offered);Check(q.count==64&&keys.count==64);
 started=[q subarrayWithRange:NSMakeRange(0,3)];NSDictionary *removed=q.lastObject;RWAdmitSources(q,keys,3,@[Source(90,500)]);
 Check(q.count==64&&keys.count==64&&![keys containsObject:RWSourceCandidateKey(removed)]&&[q[3][@"infoHash"]isEqual:Source(90,500)[@"infoHash"]]);
 Check([[q subarrayWithRange:NSMakeRange(0,3)]isEqual:started]);NSArray *before=[q copy];RWAdmitSources(q,keys,3,@[Source(91,-100)]);Check([q isEqual:before]);
 RWAdmitSources(q,keys,64,@[Source(92,1000)]);Check([q isEqual:before]); // all attempted: no retry/replacement
 NSMutableDictionary *same=[Source(0,2000)mutableCopy];same[@"filename"]=@"other.mp4";RWAdmitSources(q,keys,3,@[same]);Check(q.count==64&&[q[3][@"filename"]isEqual:@"other.mp4"]&&[q[0][@"filename"]isEqual:@"movie.mp4"]);
 before=[q copy];RWAdmitSources(q,keys,65,@[Source(93,3000)]);Check([q isEqual:before]);
 for(id bad in @[NSNull.null,@"bad",@42]){RWAdmitSources(q,keys,3,bad);Check([q isEqual:before]);}
 RWAdmitSources(q,keys,3,@[NSNull.null,@"bad",@{},@{@"infoHash":@42},@{@"infoHash":Source(1,0)[@"infoHash"],@"url":@"https://example.com/movie.mp4"}]);Check([q isEqual:before]);
 q=[NSMutableArray new];keys=[NSMutableSet new];RWAdmitSources(q,keys,0,@[Source(1,5),Source(2,5),Source(3,5)]);NSArray *ties=[q copy];RWAdmitSources(q,keys,0,@[Source(4,5)]);Check([[q subarrayWithRange:NSMakeRange(0,3)]isEqual:ties]);
 q=[NSMutableArray new];keys=[NSMutableSet new];offered=[NSMutableArray new];for(int i=0;i<300;i++)[offered addObject:Source(i,i)];RWAdmitSources(q,keys,0,offered);Check(q.count==64&&[q[0][@"infoHash"]isEqual:Source(255,255)[@"infoHash"]]);
 printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
