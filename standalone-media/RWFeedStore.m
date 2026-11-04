#import "RWFeedStore.h"
#import "RWFeedStorageBudget.h"
#import "RWFeedArchive.h"
#import <sqlite3.h>
#include <math.h>

static NSString *FT(id value){return [value isKindOfClass:NSString.class]?value:@"";}
static dispatch_queue_t FeedQueue(void){static dispatch_queue_t queue;static dispatch_once_t once;dispatch_once(&once,^{queue=dispatch_queue_create("org.rewind.feed-storage",DISPATCH_QUEUE_SERIAL);});return queue;}
static unsigned long long FeedBytes(NSString *path){return [[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil][NSFileSize]unsignedLongLongValue];}
static unsigned long long FeedRoom(NSString *path){unsigned long long used=0;NSString *folder=path.stringByDeletingLastPathComponent,*archive=[path.lastPathComponent stringByAppendingString:@".gz"];for(NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:folder error:nil])if(([name hasSuffix:@".sqlite"]||[name hasSuffix:@".sqlite.gz"])&&![name isEqual:path.lastPathComponent]&&![name isEqual:archive])used+=FeedBytes([folder stringByAppendingPathComponent:name]);return used<RWFeedDiskBudgetBytes?RWFeedDiskBudgetBytes-used:0;}
static void FeedRemove(NSString *path){for(NSString *suffix in @[@"",@"-journal",@".gz"])[NSFileManager.defaultManager removeItemAtPath:[path stringByAppendingString:suffix] error:nil];}
static NSDictionary *Brief(NSDictionary *raw){
    if(![raw isKindOfClass:NSDictionary.class])return nil;NSString *identifier=FT(raw[@"id"]?:raw[@"imdb_id"]),*type=FT(raw[@"type"]);
    BOOL entity=[@[@"person",@"studio",@"mood"]containsObject:type];
    if(!identifier.length||identifier.length>128||(!entity&&![@[@"movie",@"series"]containsObject:type]))return nil;
    if(entity&&(!FT(raw[@"profileID"]).length||([type isEqual:@"mood"]?![identifier hasPrefix:@"mood:"]:[identifier rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location!=0)))return nil;
    NSMutableDictionary *m=[@{@"id":identifier,@"type":type}mutableCopy];
    // A feed needs title-card metadata, not cast lists or every TV episode.
    for(NSString *key in @[@"name",@"poster",@"background",@"releaseInfo",@"released",@"year",@"runtime",@"imdbRating",@"imdbVotes",@"episodeVideoID",@"episodeCaption"]){id value=raw[key];if([value isKindOfClass:NSString.class]&&[value length]<=2048)m[key]=value;else if([value isKindOfClass:NSNumber.class])m[key]=value;}
    NSMutableArray *genres=[NSMutableArray new];if([raw[@"genres"]isKindOfClass:NSArray.class])for(id value in raw[@"genres"])if(FT(value).length&&[value length]<=80&&genres.count<24)[genres addObject:value];m[@"genres"]=genres;
    if(entity){for(NSString *key in @[@"profileID",@"image",@"imageRole",@"biography",@"credit",@"sourceURL",@"creditRole",@"kindLabel",@"entitySourceURL"]){NSString *value=FT(raw[key]);if(value.length<=2048)m[key]=value;}
        NSMutableArray *roles=[NSMutableArray new];if([raw[@"roles"]isKindOfClass:NSArray.class])for(id role in raw[@"roles"])if([@[@"cast",@"director",@"studio",@"distributor",@"network",@"mood"]containsObject:role]&&![roles containsObject:role])[roles addObject:role];m[@"roles"]=roles;
        NSMutableArray *known=[NSMutableArray new];if([raw[@"knownFor"]isKindOfClass:NSArray.class])for(id item in raw[@"knownFor"]){if(![item isKindOfClass:NSDictionary.class]||![@[@"movie",@"series"]containsObject:item[@"type"]?:@""])continue;NSDictionary *credit=Brief(item);if(credit)[known addObject:credit];if(known.count==3)break;}BOOL verified=[raw[@"verifiedEntity"]isEqual:@YES]&&[@[@"person",@"studio"]containsObject:type];if(!known.count&&!verified)return nil;if(verified)m[@"verifiedEntity"]=@YES;m[@"knownFor"]=known;m[@"creditCount"]=@([raw[@"creditCount"]respondsToSelector:@selector(unsignedIntegerValue)]?[raw[@"creditCount"]unsignedIntegerValue]:known.count);
    }
    return FT(m[@"name"]).length?m:nil;
}
static NSUInteger FeedCount(sqlite3 *db,BOOL visible){sqlite3_stmt *query=NULL;NSUInteger n=0;if(sqlite3_prepare_v2(db,visible?"SELECT COUNT(*) FROM visible":"SELECT COUNT(*) FROM cards",-1,&query,NULL)==SQLITE_OK&&sqlite3_step(query)==SQLITE_ROW)n=(NSUInteger)sqlite3_column_int64(query,0);sqlite3_finalize(query);return n;}
static BOOL FeedSelect(sqlite3 *db,NSString *type,NSString *sort,BOOL reset){
    if(reset&&sqlite3_exec(db,"DELETE FROM visible",NULL,NULL,NULL)!=SQLITE_OK)return NO;
    NSUInteger position=FeedCount(db,YES);NSString *order=[sort isEqual:@"Rating"]?@"rating DESC,year DESC,position":[sort isEqual:@"Year"]?@"year DESC,rating DESC,position":@"position";
    NSString *sql=[NSString stringWithFormat:@"SELECT identity FROM cards WHERE (?='' OR kind=?) AND identity NOT IN (SELECT identity FROM visible) ORDER BY %@",order];
    sqlite3_stmt *read=NULL,*write=NULL;BOOL ok=sqlite3_prepare_v2(db,sql.UTF8String,-1,&read,NULL)==SQLITE_OK&&sqlite3_prepare_v2(db,"INSERT INTO visible(position,identity) VALUES(?,?)",-1,&write,NULL)==SQLITE_OK;
    if(ok){sqlite3_bind_text(read,1,type.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_text(read,2,type.UTF8String,-1,SQLITE_TRANSIENT);int step;
        while((step=sqlite3_step(read))==SQLITE_ROW){sqlite3_reset(write);sqlite3_clear_bindings(write);sqlite3_bind_int64(write,1,(sqlite3_int64)position++);sqlite3_bind_text(write,2,(const char *)sqlite3_column_text(read,0),-1,SQLITE_TRANSIENT);if(sqlite3_step(write)!=SQLITE_DONE){ok=NO;break;}}
        if(step!=SQLITE_DONE)ok=NO;
    }sqlite3_finalize(read);sqlite3_finalize(write);return ok;
}
@implementation RWFeedStore {
    dispatch_queue_t _queue;sqlite3 *_db;NSString *_path,*_context,*_type,*_sort;NSUInteger _count,_storedCount,_revision,_generation,_memoryEpoch,_batchEpoch;
    NSMutableDictionary *_cache;NSMutableArray *_order;NSDictionary *_diagnostics;BOOL _closed,_pagesComplete,_created,_inactive,_activeRequested;NSInteger _vacuumMode;unsigned long long _archiveBytes;NSDictionary *_residency;
}
+ (dispatch_queue_t)storageQueue {return FeedQueue();}
+ (unsigned long long)roomForPath:(NSString *)path {return FeedRoom(path);}
+ (NSDictionary *)cardRecord:(NSDictionary *)record {return Brief(record);}
#include "RWFeedResidency.inc"
- (instancetype)initWithFolder:(NSString *)folder context:(NSString *)context {
    if((self=[super init])){_context=[context copy];_type=@"";_sort=@"Added";_path=[folder stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingString:@".sqlite"]];_queue=FeedQueue();_cache=[NSMutableDictionary new];_order=[NSMutableArray new];_diagnostics=@{};_activeRequested=YES;
        dispatch_async(_queue,^{@autoreleasepool{
            [[NSFileManager defaultManager]createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
            // A feed lives only for this process. Remove stale owned files once
            // per folder, without touching unrelated cache or user files.
            static NSMutableSet *cleaned; if(!cleaned)cleaned=[NSMutableSet new];
            if(![cleaned containsObject:folder]){[cleaned addObject:folder];for(NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:folder error:nil])if(name.length>=43&&[[NSUUID alloc]initWithUUIDString:[name substringToIndex:36]]&&[[name substringFromIndex:36]hasPrefix:@".sqlite"]) [NSFileManager.defaultManager removeItemAtPath:[folder stringByAppendingPathComponent:name] error:nil];}
            [self ensureOpen];
        }});
    }return self;
}
- (NSString *)context{return _context;}
- (NSUInteger)count{return _count;}
- (NSUInteger)revision{return _revision;}
- (BOOL)pagesComplete{return _pagesComplete;}
- (NSDictionary *)diagnostics {NSMutableDictionary *d=[_diagnostics mutableCopy];if(_residency)d[@"residency"]=_residency;d[@"memory_records"]=@(_cache.count);d[@"count"]=@(_count);d[@"stored_records"]=@(_storedCount);d[@"revision"]=@(_revision);d[@"pages_complete"]=@(_pagesComplete);return d;}
- (void)cancelPages {_batchEpoch++;}
- (void)appendPages:(NSArray *)records progress:(void(^)(NSUInteger,NSString *,BOOL))progress {_pagesComplete=NO;[self appendPages:[records copy] offset:0 epoch:++_batchEpoch progress:progress];}
- (void)appendPages:(NSArray *)records offset:(NSUInteger)offset epoch:(NSUInteger)epoch progress:(void(^)(NSUInteger,NSString *,BOOL))progress {
    if(_closed){progress(0,@"This browsing session has ended.",YES);return;}if(epoch!=_batchEpoch)return;
    NSUInteger length=MIN((NSUInteger)32,records.count-offset);NSArray *batch=[records subarrayWithRange:NSMakeRange(offset,length)];
    [self append:batch done:^(NSUInteger added,NSString *error){if(epoch!=self->_batchEpoch)return;BOOL finished=error.length||offset+length==records.count;if(finished)self->_pagesComplete=!error.length;progress(added,error,finished);if(!finished&&!self->_closed&&epoch==self->_batchEpoch)[self appendPages:records offset:offset+length epoch:epoch progress:progress];}];
}
- (void)replacePages:(NSArray *)records context:(NSString *)context type:(NSString *)type progress:(void(^)(NSUInteger,NSString *,BOOL))progress {
    _pagesComplete=NO;NSArray *input=[records copy]?:@[];NSUInteger epoch=++_batchEpoch,length=MIN((NSUInteger)32,input.count);NSString *filter=[@[@"movie",@"series"]containsObject:FT(type)]?type:@"";
    [self writeRecords:[input subarrayWithRange:NSMakeRange(0,length)] replacement:@{@"context":context?:@"",@"type":filter} done:^(NSUInteger added,NSString *error){if(epoch!=self->_batchEpoch)return;BOOL finished=error.length||length==input.count;if(finished)self->_pagesComplete=!error.length;progress(added,error,finished);if(!finished&&!self->_closed&&epoch==self->_batchEpoch)[self appendPages:input offset:length epoch:epoch progress:progress];}];
}
- (void)append:(NSArray *)records done:(void(^)(NSUInteger,NSString *))done {[self writeRecords:records replacement:nil done:done];}
- (void)writeRecords:(NSArray *)records replacement:(NSDictionary *)replacement done:(void(^)(NSUInteger,NSString *))done {
    if(_closed){done(0,@"This browsing session has ended.");return;}
    NSArray *input=[records copy];NSUInteger generation=_generation;
    dispatch_async(_queue,^{@autoreleasepool{
        NSString *error=[self ensureOpen];NSUInteger before=0,after=0,visibleBefore=FeedCount(self->_db,YES),visibleAfter=visibleBefore;double start=NSProcessInfo.processInfo.systemUptime;
        sqlite3_stmt *count=NULL,*write=NULL,*update=NULL;
        if(!error&&sqlite3_prepare_v2(self->_db,"SELECT COUNT(*) FROM cards",-1,&count,NULL)==SQLITE_OK&&sqlite3_step(count)==SQLITE_ROW)before=(NSUInteger)sqlite3_column_int64(count,0);else if(!error)error=@"Couldn’t read the browsing cache.";sqlite3_finalize(count);
        after=before;BOOL transaction=NO;
        if(!error){NSString *limit=[NSString stringWithFormat:@"PRAGMA max_page_count=%llu",MAX(1ULL,FeedRoom(self->_path)/4096)];if(sqlite3_exec(self->_db,limit.UTF8String,NULL,NULL,NULL)!=SQLITE_OK)error=@"Couldn’t reserve browsing space.";}
        if(!error){transaction=sqlite3_exec(self->_db,"BEGIN IMMEDIATE",NULL,NULL,NULL)==SQLITE_OK;if(!transaction)error=@"The browsing cache is busy. Try again.";}
        if(!error&&replacement){if(sqlite3_exec(self->_db,"DELETE FROM visible; DELETE FROM cards;",NULL,NULL,NULL)!=SQLITE_OK)error=@"Couldn’t replace this search.";else {after=0;visibleBefore=0;}}
        if(!error&&(sqlite3_prepare_v2(self->_db,"INSERT OR IGNORE INTO cards(position,identity,body,kind,year,rating) VALUES(?,?,?,?,?,?)",-1,&write,NULL)!=SQLITE_OK||sqlite3_prepare_v2(self->_db,"UPDATE cards SET body=?,year=?,rating=? WHERE identity=? AND kind=?",-1,&update,NULL)!=SQLITE_OK))error=@"Couldn’t save these titles.";
        if(!error)for(NSDictionary *raw in input){NSDictionary *m=Brief(raw);if(!m)continue;NSData *data=[NSJSONSerialization dataWithJSONObject:m options:0 error:nil];if(!data||data.length>8192){error=@"A title contains too much browsing data.";break;}
            sqlite3_reset(write);sqlite3_clear_bindings(write);sqlite3_bind_int64(write,1,(sqlite3_int64)after);sqlite3_bind_text(write,2,[m[@"id"]UTF8String],-1,SQLITE_TRANSIENT);sqlite3_bind_blob(write,3,data.bytes,(int)data.length,SQLITE_TRANSIENT);
            NSInteger year=[m[@"releaseInfo"]integerValue]?:[m[@"year"]integerValue];double rating=[m[@"imdbRating"]doubleValue];if(!isfinite(rating)||rating<1||rating>10)rating=0;
            sqlite3_bind_text(write,4,[m[@"type"]UTF8String],-1,SQLITE_TRANSIENT);sqlite3_bind_int64(write,5,year);sqlite3_bind_double(write,6,rating);
            if(sqlite3_step(write)!=SQLITE_DONE){error=@"The browsing cache is full. Existing titles are still available.";break;}
            if(sqlite3_changes(self->_db))after++;
            else{sqlite3_reset(update);sqlite3_clear_bindings(update);sqlite3_bind_blob(update,1,data.bytes,(int)data.length,SQLITE_TRANSIENT);sqlite3_bind_int64(update,2,year);sqlite3_bind_double(update,3,rating);sqlite3_bind_text(update,4,[m[@"id"]UTF8String],-1,SQLITE_TRANSIENT);sqlite3_bind_text(update,5,[m[@"type"]UTF8String],-1,SQLITE_TRANSIENT);if(sqlite3_step(update)!=SQLITE_DONE){error=@"Couldn’t update the browsing cache.";break;}}
        }
        sqlite3_finalize(write);sqlite3_finalize(update);
        if(!error){if(!FeedSelect(self->_db,replacement?replacement[@"type"]:self->_type,replacement?@"Added":self->_sort,NO))error=@"Couldn’t arrange this part of the list.";else visibleAfter=FeedCount(self->_db,YES);}
        if(transaction){if(error)sqlite3_exec(self->_db,"ROLLBACK",NULL,NULL,NULL);else if(sqlite3_exec(self->_db,"COMMIT",NULL,NULL,NULL)!=SQLITE_OK){error=@"Couldn’t finish saving these titles.";sqlite3_exec(self->_db,"ROLLBACK",NULL,NULL,NULL);}}
        int vacuumResult=SQLITE_OK;if(!error&&replacement){self->_type=replacement[@"type"];self->_sort=@"Added";vacuumResult=sqlite3_exec(self->_db,"PRAGMA incremental_vacuum",NULL,NULL,NULL);}
        unsigned long long bytes=[[[NSFileManager defaultManager]attributesOfItemAtPath:self->_path error:nil][NSFileSize]unsignedLongLongValue];double elapsed=NSProcessInfo.processInfo.systemUptime-start;if(self->_inactive)[self parkOnQueue];
        dispatch_async(dispatch_get_main_queue(),^{if(generation!=self->_generation||self->_closed){done(0,@"This browsing session has changed.");return;}
            if(!error){if(replacement)self->_context=[replacement[@"context"]copy];self->_storedCount=after;self->_count=visibleAfter;self->_revision++;[self discardMemory];}self->_diagnostics=@{@"sqlite_version":[NSString stringWithUTF8String:sqlite3_libversion()],@"auto_vacuum_mode":@(self->_vacuumMode),@"vacuum_result":@(vacuumResult),@"disk_bytes":@(bytes),@"last_write_seconds":@(elapsed),@"worker_io":@YES,@"shared_disk_limit_bytes":@(RWFeedDiskBudgetBytes),@"storage_reserve_bytes":@(RWFeedStorageReserveBytes)};done(error?0:visibleAfter-visibleBefore,error);
        });
    }});
}
- (void)selectType:(NSString *)type sort:(NSString *)sort done:(void(^)(NSString *))done {
    if(_closed){done(@"This browsing session has ended.");return;}type=FT(type);sort=FT(sort);type=[@[@"movie",@"series"]containsObject:type]?type:@"";sort=[@[@"Year",@"Rating"]containsObject:sort]?sort:@"Added";NSUInteger generation=_generation;
    dispatch_async(_queue,^{@autoreleasepool{NSString *error=[self ensureOpen];BOOL transaction=NO;
        if(!error){NSString *limit=[NSString stringWithFormat:@"PRAGMA max_page_count=%llu",MAX(1ULL,FeedRoom(self->_path)/4096)];if(sqlite3_exec(self->_db,limit.UTF8String,NULL,NULL,NULL)!=SQLITE_OK)error=@"Couldn’t reserve browsing space.";}
        if(!error){transaction=sqlite3_exec(self->_db,"BEGIN IMMEDIATE",NULL,NULL,NULL)==SQLITE_OK;if(!transaction)error=@"The browsing cache is busy.";}
        if(!error&&!FeedSelect(self->_db,type,sort,YES))error=@"Couldn’t sort the saved credits.";
        if(transaction){if(error)sqlite3_exec(self->_db,"ROLLBACK",NULL,NULL,NULL);else if(sqlite3_exec(self->_db,"COMMIT",NULL,NULL,NULL)!=SQLITE_OK){error=@"Couldn’t finish arranging the list.";sqlite3_exec(self->_db,"ROLLBACK",NULL,NULL,NULL);}}
        if(!error){self->_type=type;self->_sort=sort;}NSUInteger count=FeedCount(self->_db,YES);if(self->_inactive)[self parkOnQueue];
        dispatch_async(dispatch_get_main_queue(),^{if(self->_closed||generation!=self->_generation){done(@"This browsing session has changed.");return;}if(!error){self->_count=count;self->_revision++;[self discardMemory];}done(error);});
    }});
}
- (NSDictionary *)cachedItem:(NSUInteger)index {NSNumber *key=@(index);NSDictionary *m=_cache[key];if(m){[_order removeObject:key];[_order addObject:key];}return m;}
- (void)loadRange:(NSRange)range done:(void(^)(NSString *))done {
    if(!_activeRequested&&!_closed){done(@"This browsing list is paused.");return;}
    if(_closed){done(@"This browsing session has ended.");return;}NSUInteger start=MIN(range.location,_count),length=MIN(MIN(range.length,(NSUInteger)160),_count-start),generation=_generation,revision=_revision,memoryEpoch=_memoryEpoch;
    dispatch_async(_queue,^{@autoreleasepool{
        NSMutableDictionary *found=[NSMutableDictionary new];NSString *error=[self ensureOpen];sqlite3_stmt *query=NULL;
        if(!error&&sqlite3_prepare_v2(self->_db,"SELECT visible.position,cards.body FROM visible JOIN cards ON visible.identity=cards.identity WHERE visible.position>=? AND visible.position<? ORDER BY visible.position",-1,&query,NULL)==SQLITE_OK){sqlite3_bind_int64(query,1,(sqlite3_int64)start);sqlite3_bind_int64(query,2,(sqlite3_int64)(start+length));int step;
            while((step=sqlite3_step(query))==SQLITE_ROW){NSUInteger index=(NSUInteger)sqlite3_column_int64(query,0);NSData *data=[NSData dataWithBytes:sqlite3_column_blob(query,1) length:(NSUInteger)sqlite3_column_bytes(query,1)];NSDictionary *m=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];if([m isKindOfClass:NSDictionary.class])found[@(index)]=m;}
            if(step!=SQLITE_DONE||found.count!=length)error=@"Couldn’t load this part of the list.";
        }else if(!error)error=@"Couldn’t load this part of the list.";sqlite3_finalize(query);if(self->_inactive)[self parkOnQueue];
        dispatch_async(dispatch_get_main_queue(),^{if(generation!=self->_generation||revision!=self->_revision||memoryEpoch!=self->_memoryEpoch||self->_closed){done(@"This browsing session has changed.");return;}
            for(NSNumber *key in [[found allKeys]sortedArrayUsingSelector:@selector(compare:)]){[self->_order removeObject:key];self->_cache[key]=found[key];[self->_order addObject:key];}
            while(self->_order.count>200){NSNumber *key=self->_order.firstObject;[self->_cache removeObjectForKey:key];[self->_order removeObjectAtIndex:0];}done(error);
        });
    }});
}
- (void)recordsForIDs:(NSArray *)identifiers done:(void(^)(NSArray *,NSString *))done {
    if(_closed){done(@[],@"This browsing session has ended.");return;}NSMutableOrderedSet *ids=[NSMutableOrderedSet new];for(id raw in identifiers)if(FT(raw).length&&[raw length]<=128){[ids addObject:raw];if(ids.count==64)break;}NSUInteger generation=_generation,revision=_revision;
    dispatch_async(_queue,^{@autoreleasepool{NSMutableArray *records=[NSMutableArray new];NSString *error=[self ensureOpen];sqlite3_stmt *read=NULL;
        if(!error&&sqlite3_prepare_v2(self->_db,"SELECT body FROM cards WHERE identity=?",-1,&read,NULL)==SQLITE_OK){for(NSString *identifier in ids){sqlite3_reset(read);sqlite3_clear_bindings(read);sqlite3_bind_text(read,1,identifier.UTF8String,-1,SQLITE_TRANSIENT);int step=sqlite3_step(read);if(step==SQLITE_ROW){NSData *data=[NSData dataWithBytes:sqlite3_column_blob(read,0) length:sqlite3_column_bytes(read,0)];NSDictionary *record=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil];if([record isKindOfClass:NSDictionary.class])[records addObject:record];else{error=@"Couldn’t read existing search context.";break;}}else if(step!=SQLITE_DONE){error=@"Couldn’t read existing search context.";break;}}}else if(!error)error=@"Couldn’t read existing search context.";sqlite3_finalize(read);if(self->_inactive)[self parkOnQueue];
        dispatch_async(dispatch_get_main_queue(),^{if(self->_closed||generation!=self->_generation||revision!=self->_revision){done(@[],@"This browsing session has changed.");return;}done(error?@[]:records,error);});
    }});
}
- (void)discardMemory {_memoryEpoch++;[_cache removeAllObjects];[_order removeAllObjects];}
- (void)close:(void(^)(void))done {
    if(_closed){if(done)done();return;}_closed=YES;_generation++;[self discardMemory];
    dispatch_async(_queue,^{if(self->_db){sqlite3_close(self->_db);self->_db=NULL;}FeedRemove(self->_path);if(done)dispatch_async(dispatch_get_main_queue(),done);});
}
- (void)dealloc {sqlite3 *db=_db;NSString *path=_path;dispatch_async(_queue,^{if(db)sqlite3_close(db);FeedRemove(path);});}
@end
