#import <Foundation/Foundation.h>
#import "../RWSourceIdentity.h"
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(b,m) do{checks++;if(!(b)){failures++;fprintf(stderr,"FAIL:%s\n",m);}}while(0)
    NSDictionary *source=@{@"requestedVideoID":@"tt123:1:1"};NSString *error=nil;
    NSArray *(^files)(NSString *)=^NSArray *(NSString *path){return @[@{@"index":@0,@"path":path,@"size":@1000000}];};
    CHECK(RWSelectTorrentVideo(files(@"Show.S01E01.mkv"),source,-1,&error)==0,"Standard episode");
    CHECK(RWSelectTorrentVideo(files(@"Show.1x01.mp4"),source,-1,&error)==0,"Alternative numbered episode");
    CHECK(RWSelectTorrentVideo(files(@"Show.S01E02.mkv"),source,0,&error)<0,"Index cannot override contradictory episode");
    CHECK(RWSelectTorrentVideo(files(@"Show.S01E01-E02.mkv"),source,0,&error)<0,"Combined episode is ambiguous");
    CHECK(RWSelectTorrentVideo(files(@"Show.S01E01E02.mkv"),source,0,&error)<0,"Adjacent combined marker is ambiguous");
    CHECK(RWSelectTorrentVideo(files(@"Show.S01E01-02.mkv"),source,0,&error)<0,"Episode range is ambiguous");
    CHECK(RWSelectTorrentVideo(files(@"Show.S01E01-720p.mkv"),source,0,&error)==0,"Resolution suffix is not an episode range");
    CHECK(RWSelectTorrentVideo(files(@"S01E01/Show.S01E01.mkv"),source,0,&error)==0,"Repeated agreeing path markers remain valid");
    CHECK(RWSelectTorrentVideo(files(@"S01E02/Show.S01E01.mkv"),source,0,&error)<0,"Conflicting path markers cannot identify an episode");
    CHECK(RWSelectTorrentVideo(files(@"Season 1/01 - Pilot.mkv"),source,-1,&error)==0,"Season folder and numbered file identify an episode");
    CHECK(RWSelectTorrentVideo(files(@"Season 1/Episode 02 - Next.mkv"),source,-1,&error)<0,"Season folder does not hide wrong episode");
    CHECK(RWSelectTorrentVideo(files(@"Season 2/Show.S01E01.mkv"),source,-1,&error)<0,"Season folder and explicit episode must agree");
    CHECK(RWSelectTorrentVideo(files(@"Season 2/Season 1/01 - Pilot.mkv"),source,-1,&error)<0,"Conflicting nested season folders remain ambiguous");
    CHECK(RWSelectTorrentVideo(files(@"Season 1/Season 1/01 - Pilot.mkv"),source,-1,&error)==0,"Agreeing nested season folders remain selectable");
    CHECK(RWSelectTorrentVideo(files(@"unknown.mkv"),source,0,&error)<0,"Unlabelled indexed file does not invent episode identity");
    CHECK(RWSelectTorrentVideo(files(@"Show.S01E01.mkv"),@{@"requestedVideoID":@"ttabc:1:1"},0,&error)<0,"Malformed IMDb episode identifier rejected");
    CHECK(RWSelectTorrentVideo(files(@"Show.S01E01.mkv"),@{@"requestedVideoID":@"tt123:01:1"},0,&error)<0,"Noncanonical numeric episode identifier rejected");
    CHECK(RWSelectTorrentVideo(files(@"Film.mp4"),@{@"requestedVideoID":@"tt123"},-1,&error)==0,"Unique movie file remains selectable");
    NSArray *pack=@[@{@"index":@0,@"path":@"Season 1/Show.S01E01.mkv",@"size":@1000000},@{@"index":@1,@"path":@"Season 1/Show.S01E02.mkv",@"size":@9000000}];
    CHECK(RWSelectTorrentVideo(pack,source,-1,&error)==0,"Larger wrong episode never wins");
    CHECK(RWSelectTorrentVideo(pack,@{@"filename":@"Show.S01E01.mkv"},-1,&error)==0,"Filename can identify a smaller video without an index");
    CHECK(RWSelectTorrentVideo(pack,@{},-1,&error)<0,"Unspecified multi-video pack is ambiguous");
    CHECK(RWSelectTorrentVideo(pack,@{@"filename":@"Season 2/Show.S01E01.mkv"},0,&error)<0,"Supplied subdirectory must match");
    CHECK(![RWSourceCandidateKey(@{@"infoHash":@"abc",@"fileIdx":@0})isEqual:RWSourceCandidateKey(@{@"infoHash":@"abc",@"fileIdx":@1})],"Same hash files retain distinct candidates");
    CHECK(![RWSourceCandidateKey(@{@"infoHash":@"abc",@"fileIdx":@0,@"filename":@"Wrong.mkv"})isEqual:RWSourceCandidateKey(@{@"infoHash":@"abc",@"fileIdx":@0,@"filename":@"Right.mkv"})],"Contradictory filename hints do not merge");
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
