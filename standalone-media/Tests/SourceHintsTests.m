#import "../RWSourceHints.h"
int main(){@autoreleasepool{int checks=0,failures=0;
#define CHECK(x) do{checks++;if(!(x)){failures++;fprintf(stderr,"FAIL line %d\n",__LINE__);}}while(0)
    NSDictionary *old=@{@"infoHash":@"a",@"fileIdx":@3,@"url":@"magnet:original",@"filename":@"episode3.mkv",@"score":@1};
    NSDictionary *fresh=@{@"infoHash":@"a",@"fileIdx":@3,@"url":@"magnet:replacement",@"filename":@"different.mkv",@"durationHintSeconds":@1320,@"score":@100,@"seeders":@8,@"metadataURL":@"https://fixture.example/meta"};
    NSDictionary *m=RWMergeSourceHints(old,fresh);
    CHECK([m[@"durationHintSeconds"]intValue]==1320);
    CHECK([m[@"score"]intValue]==100&&[m[@"seeders"]intValue]==8);
    CHECK([m[@"url"]isEqual:old[@"url"]]&&[m[@"filename"]isEqual:old[@"filename"]]);
    CHECK([m[@"metadataURL"]isEqual:fresh[@"metadataURL"]]);
    NSMutableDictionary *wrong=[fresh mutableCopy];wrong[@"fileIdx"]=@4;
    CHECK(RWMergeSourceHints(old,wrong)==old);
    [wrong removeObjectForKey:@"fileIdx"];CHECK(RWMergeSourceHints(old,wrong)==old);
    wrong[@"fileIdx"]=@3;wrong[@"infoHash"]=@"b";CHECK(RWMergeSourceHints(old,wrong)==old);
    wrong=[fresh mutableCopy];wrong[@"durationHintSeconds"]=@(NAN);wrong[@"seeders"]=@(-1);wrong[@"score"]=@(INFINITY);
    m=RWMergeSourceHints(old,wrong);CHECK(!m[@"durationHintSeconds"]&&!m[@"seeders"]&&[m[@"score"]intValue]==1);
    CHECK(!old[@"durationHintSeconds"]);
    printf("{\"checks\":%d,\"failures\":%d}\n",checks,failures);return failures?1:0;
}}
