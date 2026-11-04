// Offline replay of copied app metadata. No network or device modifications.
#import "../RWAvailability.h"
#import "../RWRecommendationPolicy.h"
#import "../RWDiscoveryMetadataPolicy.h"
#import "../RWDiscoveryEpisodes.h"
#import "../RWHomeDelivery.h"
#import "../RWDiscoveryCatalog.h"
#import <sqlite3.h>
static NSDictionary *Read(NSString *path){NSData *data=[NSData dataWithContentsOfFile:path];id result=data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;return [result isKindOfClass:NSDictionary.class]?result:@{};}
static NSString *ID(NSDictionary *m){return m[@"id"]?:m[@"imdb_id"]?:@"";}
int main(int argc,char **argv){@autoreleasepool{
    if(argc<4||argc>5)return 2;BOOL balanced=argc==5&&strcmp(argv[4],"balanced")==0;NSString *diagnostics=@(argv[1]),*resources=@(argv[2]);double now=atof(argv[3]);
    NSDictionary *state=Read([diagnostics stringByAppendingPathComponent:@"rewind-home-replay-rewind-state.json"]),*profile=state[@"profiles"][@"main"];
    NSDictionary *fresh=Read([diagnostics stringByAppendingPathComponent:@"rewind-home-replay-rewind-current-catalog.json"]),*catalog=Read([diagnostics stringByAppendingPathComponent:@"rewind-home-replay-rewind-catalog.json"]),*curated=Read([resources stringByAppendingPathComponent:@"curated.json"]),*shows=Read([diagnostics stringByAppendingPathComponent:@"rewind-home-replay-rewind-series.json"]);
    NSMutableDictionary *metadata=[Read([resources stringByAppendingPathComponent:@"discovery-metadata.json"])[@"titles"]mutableCopy];[metadata addEntriesFromDictionary:Read([diagnostics stringByAppendingPathComponent:@"rewind-home-replay-discovery-metadata.json"])[@"titles"]?:@{}];
    NSArray *groups=@[fresh[@"movie"]?:@[],fresh[@"series"]?:@[],catalog[@"movie"]?:@[],catalog[@"series"]?:@[],Read([resources stringByAppendingPathComponent:@"discovery-catalog.json"])[@"items"]?:@[],curated[@"movie"]?:@[],curated[@"series"]?:@[],profile[@"saved"]?:@[]];
    NSMutableArray *prepared=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];RWDiscoveryEpisodes *episodes=[RWDiscoveryEpisodes new];
    sqlite3 *db=NULL;sqlite3_stmt *statement=NULL;sqlite3_open_v2([[resources stringByAppendingPathComponent:@"imdb-ratings.sqlite"]UTF8String],&db,SQLITE_OPEN_READONLY,NULL);
    if(sqlite3_prepare_v2(db,"SELECT r,v FROM ratings WHERE id=?",-1,&statement,NULL)!=SQLITE_OK){fprintf(stderr,"rating schema: %s\n",sqlite3_errmsg(db));return 3;}
    NSMutableDictionary *(^enrich)(NSDictionary *)=^NSMutableDictionary *(NSDictionary *meta){NSString *key=ID(meta);NSMutableDictionary *m=[meta mutableCopy];[m removeObjectForKey:@"videos"];if(metadata[key])m[@"discovery"]=metadata[key];m[@"ageAllowed"]=@YES;
        sqlite3_reset(statement);sqlite3_clear_bindings(statement);sqlite3_bind_int64(statement,1,key.length>2?[[key substringFromIndex:2]longLongValue]:0);if(sqlite3_step(statement)==SQLITE_ROW){m[@"imdbRating"]=@(sqlite3_column_double(statement,0)/10.0);m[@"imdbVotes"]=@(sqlite3_column_int64(statement,1));}return m;};
    if(balanced)groups=@[[RWDiscoveryCatalog balancedPool:groups limit:500 allows:nil]];
    NSUInteger eligible=0;
    for(NSArray *group in groups)for(NSDictionary *meta in group){NSString *key=ID(meta);if(!key.length||[seen containsObject:key]||prepared.count>=500)continue;[seen addObject:key];NSMutableDictionary *m=enrich(meta);
        NSString *video=key;NSDictionary *target=m;if([m[@"type"]isEqual:@"series"]){NSDictionary *ep=[episodes episode:nil show:shows[key]?:m history:profile[@"history"] now:[NSDate dateWithTimeIntervalSince1970:now]];video=ep[@"id"]?:@"";if(video.length)m[@"episodeVideoID"]=video;NSMutableDictionary *withDate=[m mutableCopy];withDate[@"released"]=ep[@"released"]?:m[@"released"]?:@"";target=withDate;}
        m[@"availability"]=[RWAvailability presentation:target observation:profile[@"sourceAvailability"][video] quality:[profile[@"quality"]integerValue] now:now];if([m[@"availability"][@"discovery_eligible"]boolValue])eligible++;[prepared addObject:m];
    }
    NSMutableDictionary *preparedProfile=[profile mutableCopy];for(NSString *key in @[@"liked",@"saved"]){NSMutableArray *signals=[NSMutableArray new];for(NSDictionary *m in profile[key])[signals addObject:enrich(m)];preparedProfile[key]=signals;}
    NSMutableDictionary *history=[NSMutableDictionary new];for(NSString *key in profile[@"history"]){NSMutableDictionary *record=[profile[@"history"][key]mutableCopy];record[@"meta"]=enrich(record[@"meta"]);history[key]=record;}preparedProfile[@"history"]=history;profile=preparedProfile;
    sqlite3_finalize(statement);sqlite3_close(db);
    NSDictionary *home=[RWRecommendationPolicy home:prepared profile:profile year:2026 now:now];
    NSMutableArray *rows=[NSMutableArray new];NSUInteger cards=0;
    for(NSDictionary *row in home[@"rows"]){NSMutableArray *names=[NSMutableArray new],*evidence=[NSMutableArray new];for(NSDictionary *m in row[@"items"]){[names addObject:m[@"name"]?:ID(m)];[evidence addObject:@{@"id":ID(m),@"type":m[@"type"]?:@"",@"year":m[@"releaseInfo"]?:@"",@"imdb_rating":m[@"imdbRating"]?:@0,@"imdb_votes":m[@"imdbVotes"]?:@0,@"language_group":[RWDiscoveryMetadataPolicy languageGroup:m[@"discovery"]],@"availability_state":m[@"availability"][@"state"]?:@"",@"discovery_eligible":m[@"availability"][@"discovery_eligible"]?:@NO}];}[rows addObject:@{@"id":row[@"id"],@"count":@(names.count),@"titles":names,@"evidence":evidence,@"mediaType":row[@"mediaType"]?:@"mixed",@"heading":row[@"title"]?:@"",@"recipe":row[@"recipe"]?:@""}];cards+=names.count;}
    NSDictionary *snapshot=[RWHomeDelivery snapshot:home profile:profile quality:[profile[@"quality"]integerValue] now:now];NSDictionary *restored=[RWHomeDelivery restore:snapshot profile:profile quality:[profile[@"quality"]integerValue] now:now+600];
    NSDictionary *result=@{@"pool_mode":balanced?@"balanced":@"sequential",@"candidate_ids":[prepared valueForKey:@"id"],@"interest_model":home[@"interestModel"]?:@{},@"row_decisions":home[@"rowDecisions"]?:@[],@"catalog_count":@(prepared.count),@"eligible_listings":@(eligible),@"recommendation_cards":@(cards),@"rows":rows,@"hero":ID(home[@"hero"]),@"rank_seconds":home[@"seconds"],@"cache_roundtrip_matches":@([restored isEqual:snapshot[@"page"]]),@"snapshot_bytes":@([NSJSONSerialization dataWithJSONObject:snapshot options:0 error:nil].length)};
    puts([[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil] encoding:NSUTF8StringEncoding].UTF8String);return 0;
}}
