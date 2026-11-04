#import "RWHomeFeedStore.h"
#import "RWFeedStore.h"
#import "RWHomeCategoryPolicy.h"
#import <sqlite3.h>
#import <CommonCrypto/CommonDigest.h>
#include <math.h>
static NSString *Text(id v){return [v isKindOfClass:NSString.class]?v:@"";}
static NSDictionary *Map(id v){return [v isKindOfClass:NSDictionary.class]?v:@{};}
static NSArray *List(id v){return [v isKindOfClass:NSArray.class]?v:@[];}
static BOOL SameRecipe(NSDictionary *a,NSDictionary *b){
    for(NSString *key in @[@"mediaType",@"recipe",@"anchorID",@"anchor",@"mood",@"year",@"anyGenres",@"allGenres",@"maxMinutes",@"providerGenre"]){id x=a[key],y=b[key];if(x!=y&&![x isEqual:y])return NO;}return YES;
}
static NSData *JSON(id v,NSUInteger limit){if(![NSJSONSerialization isValidJSONObject:v])return nil;NSData *d=[NSJSONSerialization dataWithJSONObject:v options:0 error:nil];return d.length&&d.length<=limit?d:nil;}
static NSDictionary *Read(sqlite3_stmt *q,int column){const void *p=sqlite3_column_blob(q,column);int n=sqlite3_column_bytes(q,column);return n>0&&n<=8192?Map([NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:p length:n] options:0 error:nil]):@{};}
// Compare the exact stored body without retaining a second media payload.
static NSData *BodyDigest(sqlite3_stmt *q,int column){const void *p=sqlite3_column_blob(q,column);int n=sqlite3_column_bytes(q,column);if(n<=0||n>8192)return nil;unsigned char hash[CC_SHA256_DIGEST_LENGTH];CC_SHA256(p,(CC_LONG)n,hash);return [NSData dataWithBytes:hash length:sizeof(hash)];}
static BOOL Run(sqlite3 *db,NSString *sql,NSArray *args){sqlite3_stmt *q=NULL;BOOL ok=sqlite3_prepare_v2(db,sql.UTF8String,-1,&q,NULL)==SQLITE_OK;for(NSUInteger i=0;ok&&i<args.count;i++){id x=args[i];int r=[x isKindOfClass:NSData.class]?sqlite3_bind_blob(q,(int)i+1,[x bytes],(int)[x length],SQLITE_TRANSIENT):[x isKindOfClass:NSNumber.class]?sqlite3_bind_int64(q,(int)i+1,[x longLongValue]):sqlite3_bind_text(q,(int)i+1,[Text(x)UTF8String],-1,SQLITE_TRANSIENT);ok=r==SQLITE_OK;}if(ok)ok=sqlite3_step(q)==SQLITE_DONE;sqlite3_finalize(q);return ok;}
// Connection-local revisions cover every committed membership/body mutation,
// including a superseded activation. TEMP bookkeeping rolls back with writes
// and disappears on close; no persistent schema or catalogue payload is added.
static BOOL TrackHomeRows(sqlite3 *db){
    NSMutableString *sql=[NSMutableString stringWithString:@"CREATE TEMP TABLE rw_home_clock(value INTEGER NOT NULL); INSERT INTO rw_home_clock VALUES(0); CREATE TEMP TABLE rw_home_versions(scope TEXT NOT NULL,rowid TEXT NOT NULL,version INTEGER NOT NULL,prefix_version INTEGER NOT NULL,PRIMARY KEY(scope,rowid));"];
    NSArray *triggers=@[@[@"row_insert",@"AFTER INSERT ON main.rows",@[@"NEW"]],@[@"card_insert",@"AFTER INSERT ON main.cards",@[@"NEW"]],@[@"card_delete",@"AFTER DELETE ON main.cards",@[@"OLD"]],@[@"card_update",@"AFTER UPDATE ON main.cards WHEN OLD.scope IS NOT NEW.scope OR OLD.rowid IS NOT NEW.rowid OR OLD.position IS NOT NEW.position OR OLD.body IS NOT NEW.body OR OLD.identity IS NOT NEW.identity",@[@"OLD",@"NEW"]],@[@"row_update",@"AFTER UPDATE OF body ON main.rows WHEN OLD.body IS NOT NEW.body",@[@"NEW"]]];
    for(NSArray *spec in triggers){[sql appendFormat:@"CREATE TEMP TRIGGER rw_home_%@ %@ BEGIN UPDATE rw_home_clock SET value=value+1;",spec[0],spec[1]];
        for(NSString *record in spec[2]){NSString *row=[spec[0]hasPrefix:@"row_"]?@"identity":@"rowid";
            // UPDATE then conditional INSERT also works when the outer write
            // uses OR IGNORE (its conflict policy applies inside triggers).
            // Only a strictly later insertion leaves every existing array index
            // unchanged. Earlier reserved-slot restoration, deletion, body edits,
            // moves and row recreation invalidate the prefix. These revisions
            // also cover superseded transactions, and roll back atomically.
            NSString *invalidates=[spec[0]isEqual:@"card_insert"]?@"EXISTS(SELECT 1 FROM main.cards c WHERE c.scope=NEW.scope AND c.rowid=NEW.rowid AND c.position>=NEW.position AND c.identity<>NEW.identity)":@"1";
            [sql appendFormat:@"UPDATE rw_home_versions SET version=(SELECT value FROM rw_home_clock),prefix_version=CASE WHEN %@ THEN (SELECT value FROM rw_home_clock) ELSE prefix_version END WHERE scope=%@.scope AND rowid=%@.%@; INSERT INTO rw_home_versions SELECT %@.scope,%@.%@,value,CASE WHEN %@ THEN value ELSE 0 END FROM rw_home_clock WHERE NOT EXISTS(SELECT 1 FROM rw_home_versions WHERE scope=%@.scope AND rowid=%@.%@);",invalidates,record,record,row,record,record,row,invalidates,record,record,row];
        }[sql appendString:@"END;"];
    }
    [sql appendString:@"CREATE TEMP TRIGGER rw_home_row_delete AFTER DELETE ON main.rows BEGIN DELETE FROM rw_home_versions WHERE scope=OLD.scope AND rowid=OLD.identity; END;"];
    return sqlite3_exec(db,sql.UTF8String,NULL,NULL,NULL)==SQLITE_OK;
}
static NSDictionary *Card(NSDictionary *raw){NSMutableDictionary *m=[[RWFeedStore cardRecord:raw]mutableCopy];if(!m||![@[@"movie",@"series"]containsObject:m[@"type"]])return nil;
    // Keep enough stable metadata to revalidate a window. Never serialize source
    // objects, episode arrays, cast biographies, images or profile history.
    [m removeObjectForKey:@"episodeVideoID"];[m removeObjectForKey:@"episodeCaption"];NSDictionary *d=Map(raw[@"discovery"]);NSMutableDictionary *brief=[NSMutableDictionary new];for(NSString *key in @[@"primaryLanguage",@"languageSource",@"originalLanguages",@"industry",@"countries",@"directors",@"genres",@"themes",@"franchises",@"collectionPolicy"])if(d[key])brief[key]=d[key];
    if(brief.count&&JSON(brief,4096))m[@"discovery"]=brief;if([raw[@"showLanguage"]boolValue])m[@"showLanguage"]=@YES;return JSON(m,8192)?m:nil;
}
@interface RWHomeRowFeed ()
@property(nonatomic,weak) RWHomeFeedStore *owner;
@property(nonatomic,strong) NSString *identifier,*scope;
@property(nonatomic,strong) NSDictionary *descriptor,*cursor,*anchor;
@property(nonatomic,assign) NSUInteger count,revision,epoch;
@property(nonatomic,assign) long long storageVersion,prefixVersion;
@property(nonatomic,assign) BOOL more;
@end
@interface RWHomeFeedStore ()
- (BOOL)owns:(RWHomeRowFeed *)row;
- (NSDictionary *)cached:(NSUInteger)index row:(RWHomeRowFeed *)row;
- (void)load:(NSRange)range row:(RWHomeRowFeed *)row done:(void(^)(NSString *))done;
@end
@implementation RWHomeRowFeed
- (NSString *)context {return [self.scope stringByAppendingFormat:@":%@",self.identifier];}
- (NSDictionary *)cachedItem:(NSUInteger)index {return [self.owner cached:index row:self];}
- (void)loadRange:(NSRange)range done:(void(^)(NSString *))done {if(self.owner)[self.owner load:range row:self done:done];else done(@"This Home session has ended.");}
@end
@implementation RWHomeFeedStore {
    dispatch_queue_t _queue;sqlite3 *_db;NSString *_path,*_scope;
    NSDictionary *_opening;NSArray *_rows,*_foldedRows,*_allocationMoves,*_allocationAnchors,*_allocationRecovered;NSMutableDictionary *_organizedContexts;NSMutableDictionary *_memory,*_memoryFingerprints;NSMutableArray *_memoryOrder,*_anchorQueries;
    NSUInteger _generation,_revision,_memoryEpoch,_emptyRowsRetired,_seedSnapshotBytes,_retainedWindowRecords,_invalidatedWindowRecords,_retainedAppendRecords,_reconciledWindowRecords;BOOL _closed;NSString *_profile;NSMutableDictionary *_seedRefills;NSSet *_excluded;
}
- (instancetype)initWithFolder:(NSString *)folder {if((self=[super init])){_queue=[RWFeedStore storageQueue];_path=[folder stringByAppendingPathComponent:@"rewind-home.sqlite"];_rows=@[];_organizedContexts=[NSMutableDictionary new];_memory=[NSMutableDictionary new];_memoryFingerprints=[NSMutableDictionary new];_memoryOrder=[NSMutableArray new];}return self;}
- (NSArray *)rows{return _rows;}
- (NSString *)scope{return _scope;}
- (NSDictionary *)diagnostics {NSUInteger total=0;for(RWHomeRowFeed *r in _rows)total+=r.count;return @{@"rows":@(_rows.count),@"assigned_titles":@(total),@"memory_records":@(_memory.count),@"memory_limit":@128,@"retained_window_records":@(_retainedWindowRecords),@"retained_append_records":@(_retainedAppendRecords),@"reconciled_window_records":@(_reconciledWindowRecords),@"fingerprint_bytes":@(_memoryFingerprints.count*CC_SHA256_DIGEST_LENGTH),@"invalidated_window_records":@(_invalidatedWindowRecords),@"revision":@(_revision),@"anchor_queries":_anchorQueries?:@[],@"persistent":@YES,@"seed_refills":_seedRefills?:@{},@"empty_rows_retired":@(_emptyRowsRetired),@"seed_snapshot_bytes":@(_seedSnapshotBytes),@"folded_rows":_foldedRows?:@[],@"allocation_moves":_allocationMoves?:@[],@"allocation_anchors":_allocationAnchors?:@[],@"allocation_recovered":_allocationRecovered?:@[],@"opening":_opening?:@{}};}
- (BOOL)owns:(RWHomeRowFeed *)r{return !_closed&&r.owner==self&&r.epoch==_generation&&[r.scope isEqual:_scope]&&[_rows containsObject:r];}
- (NSString *)open {
    if(_db)return nil;[[NSFileManager defaultManager]createDirectoryAtPath:_path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
    unsigned long long room=[RWFeedStore roomForPath:_path];BOOL exists=[NSFileManager.defaultManager fileExistsAtPath:_path];if(room<40960&&!exists)return @"The browsing cache is full. Existing titles are still available.";
    if(sqlite3_open_v2(_path.UTF8String,&_db,SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE|SQLITE_OPEN_NOMUTEX,NULL)!=SQLITE_OK){if(_db)sqlite3_close(_db);_db=NULL;return @"Couldn’t open Home’s saved rows.";}
    NSString *settings=[NSString stringWithFormat:@"PRAGMA page_size=4096; PRAGMA auto_vacuum=INCREMENTAL; PRAGMA max_page_count=%llu; PRAGMA cache_size=-256; PRAGMA journal_mode=DELETE; PRAGMA synchronous=NORMAL;",MAX(1ULL,room/4096)];
    BOOL ok=sqlite3_exec(_db,settings.UTF8String,NULL,NULL,NULL)==SQLITE_OK;
    sqlite3_stmt *version=NULL;int schema=-1;if(ok&&sqlite3_prepare_v2(_db,"PRAGMA user_version",-1,&version,NULL)==SQLITE_OK&&sqlite3_step(version)==SQLITE_ROW)schema=sqlite3_column_int(version,0);sqlite3_finalize(version);
    if(schema==0&&ok){const char *create="BEGIN IMMEDIATE; CREATE TABLE scopes(scope TEXT PRIMARY KEY,profile TEXT NOT NULL); CREATE TABLE rows(scope TEXT NOT NULL,identity TEXT NOT NULL,position INTEGER NOT NULL,body BLOB NOT NULL,cursor BLOB NOT NULL,more INTEGER NOT NULL,anchor BLOB NOT NULL,PRIMARY KEY(scope,identity)); CREATE TABLE cards(scope TEXT NOT NULL,identity TEXT NOT NULL,rowid TEXT NOT NULL,position INTEGER NOT NULL,body BLOB NOT NULL,PRIMARY KEY(scope,identity),UNIQUE(scope,rowid,position)); CREATE TABLE exclusions(scope TEXT NOT NULL,identity TEXT NOT NULL,PRIMARY KEY(scope,identity)); PRAGMA user_version=1; COMMIT;";ok=sqlite3_exec(_db,create,NULL,NULL,NULL)==SQLITE_OK;if(!ok)sqlite3_exec(_db,"ROLLBACK",NULL,NULL,NULL);}
    else ok=ok&&(schema==1||schema==2);
    // Remember only removed identities and slots, never their media metadata.
    // Upgrade in place so existing rows, cursors and user anchors survive.
    if(ok&&schema<2){ok=sqlite3_exec(_db,"BEGIN IMMEDIATE; CREATE TABLE positions(scope TEXT NOT NULL,identity TEXT NOT NULL,rowid TEXT NOT NULL,position INTEGER NOT NULL,sequence INTEGER NOT NULL,PRIMARY KEY(scope,identity),UNIQUE(scope,rowid,position)); PRAGMA user_version=2; COMMIT;",NULL,NULL,NULL)==SQLITE_OK;if(!ok)sqlite3_exec(_db,"ROLLBACK",NULL,NULL,NULL);}
    if(ok)ok=TrackHomeRows(_db);
    if(!ok){sqlite3_close(_db);_db=NULL;return @"Couldn’t read Home’s saved rows. They have been kept.";}return nil;
}
- (NSString *)begin {
    NSString *error=[self open];if(error)return error;unsigned long long room=[RWFeedStore roomForPath:_path];
    if(room<40960)return @"The browsing cache is full. Existing titles are still available.";
    NSString *quota=[NSString stringWithFormat:@"PRAGMA max_page_count=%llu",room/4096];
    if(sqlite3_exec(_db,quota.UTF8String,NULL,NULL,NULL)!=SQLITE_OK||sqlite3_exec(_db,"BEGIN IMMEDIATE",NULL,NULL,NULL)!=SQLITE_OK)return @"Home’s browsing cache is busy. Try again.";return nil;
}
- (NSString *)finish:(NSString *)error {if(!error&&sqlite3_exec(_db,"COMMIT",NULL,NULL,NULL)!=SQLITE_OK)error=@"Couldn’t save more titles. Try again.";if(error&&_db)sqlite3_exec(_db,"ROLLBACK",NULL,NULL,NULL);return error;}
- (NSArray *)readRows:(NSString *)scope error:(NSString **)error {
    sqlite3_stmt *q=NULL;NSMutableArray *out=[NSMutableArray new];const char *sql="SELECT r.identity,r.body,r.cursor,r.more,r.anchor,(SELECT COUNT(*) FROM cards c WHERE c.scope=r.scope AND c.rowid=r.identity),COALESCE((SELECT version FROM rw_home_versions v WHERE v.scope=r.scope AND v.rowid=r.identity),0),COALESCE((SELECT prefix_version FROM rw_home_versions v WHERE v.scope=r.scope AND v.rowid=r.identity),0) FROM rows r WHERE r.scope=? ORDER BY CASE r.identity WHEN '__hero' THEN 0 WHEN 'for-you-movie' THEN 1 WHEN 'for-you-series' THEN 2 ELSE 3 END,r.position";
    if(sqlite3_prepare_v2(_db,sql,-1,&q,NULL)!=SQLITE_OK){*error=@"Couldn’t read Home’s saved rows.";return nil;}sqlite3_bind_text(q,1,scope.UTF8String,-1,SQLITE_TRANSIENT);int step;
    while((step=sqlite3_step(q))==SQLITE_ROW){NSString *key=@((const char *)sqlite3_column_text(q,0));NSDictionary *body=Read(q,1);if(![body[@"id"]isEqual:key]||out.count>=14){*error=@"Home’s saved row metadata could not be verified.";break;}
        [out addObject:@{@"descriptor":body,@"cursor":Read(q,2),@"more":@(sqlite3_column_int(q,3)!=0),@"anchor":Read(q,4),@"count":@(sqlite3_column_int64(q,5)),@"storageVersion":@(sqlite3_column_int64(q,6)),@"prefixVersion":@(sqlite3_column_int64(q,7))}];}
    if(step!=SQLITE_DONE&&!*error)*error=@"Couldn’t finish reading Home’s rows.";sqlite3_finalize(q);return *error?nil:out;
}
// Snapshot only resident references and32-byte digests on main. SQLite index
// reconciliation runs in the existing worker and is bounded by the128card cache.
- (NSArray *)residentSnapshot {
    NSMutableArray *out=[NSMutableArray new];NSMutableDictionary *rows=[NSMutableDictionary new];for(RWHomeRowFeed *r in _rows)rows[r.identifier]=r;
    for(NSString *key in _memoryOrder){NSRange split=[key rangeOfString:@":" options:NSBackwardsSearch];if(split.location==NSNotFound)continue;NSString *row=[key substringToIndex:split.location];RWHomeRowFeed *r=rows[row];NSDictionary *m=_memory[key];NSData *hash=_memoryFingerprints[key];
        if(r&&m&&hash)[out addObject:@{@"row":row,@"id":m[@"id"],@"record":m,@"digest":hash,@"descriptor":r.descriptor,@"prefix":@(r.prefixVersion)}];
    }return out;
}
- (NSDictionary *)reconcile:(NSArray *)resident scope:(NSString *)scope rows:(NSArray *)rows {
    NSMutableDictionary *next=[NSMutableDictionary new],*out=[NSMutableDictionary new];for(NSDictionary *r in rows)next[r[@"descriptor"][@"id"]]=r;
    sqlite3_stmt *q=NULL;const char *sql="SELECT (SELECT COUNT(*) FROM cards c WHERE c.scope=t.scope AND c.rowid=t.rowid AND c.position<t.position),t.body FROM cards t WHERE t.scope=? AND t.rowid=? AND t.identity=?";
    if(sqlite3_prepare_v2(_db,sql,-1,&q,NULL)!=SQLITE_OK)return @{};
    for(NSDictionary *entry in resident){NSString *row=entry[@"row"];NSDictionary *r=next[row];if(!r||![entry[@"descriptor"]isEqual:r[@"descriptor"]]||[entry[@"prefix"]isEqual:r[@"prefixVersion"]])continue;
        sqlite3_reset(q);sqlite3_clear_bindings(q);sqlite3_bind_text(q,1,scope.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_text(q,2,row.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_text(q,3,[entry[@"id"]UTF8String],-1,SQLITE_TRANSIENT);
        if(sqlite3_step(q)!=SQLITE_ROW||![BodyDigest(q,1)isEqual:entry[@"digest"]])continue;
        long long index=sqlite3_column_int64(q,0);if(index<0||index>=[r[@"count"]longLongValue])continue;NSMutableDictionary *mapped=[entry mutableCopy];mapped[@"index"]=@(index);
        if(!out[row])out[row]=[NSMutableDictionary new];out[row][entry[@"id"]]=mapped;
    }sqlite3_finalize(q);return out;
}
- (void)publish:(NSArray *)records reconciled:(NSDictionary *)reconciled {
    _revision++;NSMutableDictionary *old=[NSMutableDictionary new];for(RWHomeRowFeed *r in _rows)old[r.identifier]=r;NSMutableArray *next=[NSMutableArray new];NSMutableSet *unchanged=[NSMutableSet new],*appended=[NSMutableSet new];
    for(NSDictionary *record in records){NSString *key=record[@"descriptor"][@"id"];RWHomeRowFeed *r=old[key];
        if(r&&r.prefixVersion==[record[@"prefixVersion"]longLongValue]&&r.count<=[record[@"count"]unsignedIntegerValue]&&[r.descriptor isEqual:record[@"descriptor"]]){
            [unchanged addObject:key];if(r.storageVersion!=[record[@"storageVersion"]longLongValue])[appended addObject:key];
        }
        r=r?:[RWHomeRowFeed new];r.owner=self;r.scope=_scope;r.epoch=_generation;r.identifier=key;r.descriptor=record[@"descriptor"];r.cursor=record[@"cursor"];r.anchor=record[@"anchor"];r.more=[record[@"more"]boolValue];r.count=[record[@"count"]unsignedIntegerValue];r.storageVersion=[record[@"storageVersion"]longLongValue];r.prefixVersion=[record[@"prefixVersion"]longLongValue];r.revision=_revision;[next addObject:r];
    }
    NSMutableDictionary *memory=[NSMutableDictionary new],*fingerprints=[NSMutableDictionary new];NSMutableArray *order=[NSMutableArray new];
    for(NSString *key in _memoryOrder){NSRange separator=[key rangeOfString:@":" options:NSBackwardsSearch];NSString *row=separator.location==NSNotFound?@"":[key substringToIndex:separator.location];NSDictionary *m=_memory[key];NSString *destination=nil;
        if([unchanged containsObject:row]){destination=key;_retainedWindowRecords++;if([appended containsObject:row])_retainedAppendRecords++;}
        else {NSDictionary *entry=reconciled[row][m[@"id"]];
            // Another queued load, memory purge or publication may have changed
            // this entry. Never resurrect a snapshot that is no longer resident.
            if(entry&&entry[@"record"]==m&&[entry[@"digest"]isEqual:_memoryFingerprints[key]]){destination=[row stringByAppendingFormat:@":%@",entry[@"index"]];_reconciledWindowRecords++;_retainedWindowRecords++;}
        }
        if(destination&&!memory[destination]){memory[destination]=m;if(_memoryFingerprints[key])fingerprints[destination]=_memoryFingerprints[key];[order addObject:destination];}else _invalidatedWindowRecords++;
    }_memory=memory;_memoryFingerprints=fingerprints;_memoryOrder=order;_rows=[next copy];
}

- (BOOL)insert:(NSArray *)records scope:(NSString *)scope row:(NSString *)row type:(NSString *)type added:(NSUInteger *)added {
    return [self insert:records scope:scope row:row type:type limit:NSUIntegerMax added:added];
}
- (BOOL)insert:(NSArray *)records scope:(NSString *)scope row:(NSString *)row type:(NSString *)type limit:(NSUInteger)limit added:(NSUInteger *)added {
    sqlite3_stmt *q=NULL;long long position=0;
    const char *maximum="SELECT COALESCE(MAX(position)+1,0) FROM (SELECT position FROM cards WHERE scope=? AND rowid=? UNION ALL SELECT position FROM positions WHERE scope=? AND rowid=?)";
    if(sqlite3_prepare_v2(_db,maximum,-1,&q,NULL)!=SQLITE_OK)return NO;
    NSArray *args=@[scope,row,scope,row];for(NSUInteger i=0;i<args.count;i++)sqlite3_bind_text(q,(int)i+1,[args[i]UTF8String],-1,SQLITE_TRANSIENT);
    BOOL ok=sqlite3_step(q)==SQLITE_ROW;if(ok)position=sqlite3_column_int64(q,0);sqlite3_finalize(q);if(!ok)return NO;
    for(NSDictionary *raw in records){
        if(*added>=limit)break;NSDictionary *m=Card(raw);if(!m||(![type isEqual:@"hero"]&&![m[@"type"]isEqual:type]))return NO;
        long long slot=position;BOOL reserved=NO,other=NO;
        if(sqlite3_prepare_v2(_db,"SELECT rowid,position FROM positions WHERE scope=? AND identity=?",-1,&q,NULL)!=SQLITE_OK)return NO;
        sqlite3_bind_text(q,1,scope.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_text(q,2,[m[@"id"]UTF8String],-1,SQLITE_TRANSIENT);int step=sqlite3_step(q);
        if(step==SQLITE_ROW){other=![row isEqual:@((const char *)sqlite3_column_text(q,0))];reserved=!other;slot=sqlite3_column_int64(q,1);}sqlite3_finalize(q);if(step!=SQLITE_ROW&&step!=SQLITE_DONE)return NO;if(other)continue;
        NSData *data=JSON(m,8192);
        if(!Run(_db,@"INSERT OR IGNORE INTO cards(scope,identity,rowid,position,body) SELECT ?,?,?,?,? WHERE NOT EXISTS(SELECT 1 FROM exclusions WHERE scope=? AND identity=?)",@[scope,m[@"id"],row,@(slot),data,scope,m[@"id"]]))return NO;
        if(sqlite3_changes(_db)){(*added)++;if(reserved){if(!Run(_db,@"DELETE FROM positions WHERE scope=? AND identity=?",@[scope,m[@"id"]]))return NO;}else position++;}
    }
    return YES;
}
#include "RWHomeShelfConsolidation.inc"
#include "RWHomeShelfAllocation.inc"
- (void)activate:(NSString *)scope profile:(NSString *)profile seedRows:(NSArray *)rows excluding:(NSSet *)identifiers done:(void(^)(NSString *))done {
    [self activate:scope profile:profile seedRows:rows excluding:identifiers settled:YES done:done];
}
- (void)sealOrganization:(NSString *)scope profile:(NSString *)profile {
    if(!scope.length||!profile.length)return;NSString *key=[scope copy],*owner=[profile copy];
    dispatch_async(_queue,^{if(self->_organizedContexts.count>=12&&!self->_organizedContexts[owner])[self->_organizedContexts removeObjectForKey:[[self->_organizedContexts.allKeys sortedArrayUsingSelector:@selector(compare:)]firstObject]];self->_organizedContexts[owner]=key;});
}
- (void)activate:(NSString *)scope profile:(NSString *)profile seedRows:(NSArray *)rows excluding:(NSSet *)identifiers settled:(BOOL)settled done:(void(^)(NSString *))done {
    if(_closed||!Text(scope).length||scope.length>512||!Text(profile).length||profile.length>128||![rows isKindOfClass:NSArray.class]||rows.count>14||identifiers.count>500){done(@"This Home context could not be loaded.");return;}
    // Own bounded immutable JSON before dispatch. The controller can mutate its
    // ranking records immediately after this call without changing the seed.
    // Snapshot the card contract, not unused provider cast, episode or source
    // payloads. The same per-card and aggregate caps still apply before dispatch.
    NSMutableArray *compact=[NSMutableArray new];
    for(id raw in rows){NSDictionary *row=Map(raw);id items=row[@"items"];if(![items isKindOfClass:NSArray.class]||[items count]>12){done(@"This Home row could not be verified.");return;}
        NSMutableDictionary *seed=[NSMutableDictionary new];for(NSString *field in @[@"id",@"title",@"mediaType",@"recipe",@"anchorID",@"anchor",@"mood",@"year",@"anyGenres",@"allGenres",@"maxMinutes",@"providerGenre"])if(row[field])seed[field]=[field isEqual:@"anchor"]?(Card(row[field])?:@{}):row[field];
        NSMutableArray *cards=[NSMutableArray new];for(id item in items){NSDictionary *brief=Card(Map(item));if(!brief){done(@"This Home title could not be verified.");return;}[cards addObject:brief];}seed[@"items"]=cards;[compact addObject:seed];
    }
    NSData *owned=JSON(compact,256*1024);_seedSnapshotBytes=owned.length;if(!owned){done(@"Home’s initial rows are too large.");return;}NSArray *seeds=[NSJSONSerialization JSONObjectWithData:owned options:0 error:nil];NSSet *excluded=[[NSSet alloc]initWithSet:identifiers copyItems:YES];
    // Keep row objects for layout maintenance in the same profile/context.
    // Replacing them resets collection offsets and automatic-scroll intent.
    // Generations still invalidate queued work. Same-context cached windows
    // remain visible until the atomic publish identifies changed rows; every
    // read still checks live policy and newly requested exclusions immediately.
    BOOL same=[_scope isEqual:scope]&&[_profile isEqual:profile];_scope=[scope copy];_profile=[profile copy];_excluded=excluded;if(!same){_opening=nil;_rows=@[];_foldedRows=@[];_allocationMoves=@[];_allocationAnchors=@[];_allocationRecovered=@[];_seedRefills=[NSMutableDictionary new];_emptyRowsRetired=0;[self discardMemory];}NSUInteger epoch=++_generation;for(RWHomeRowFeed *row in _rows)row.epoch=epoch;NSString *scopeKey=_scope,*profileKey=[profile copy];NSArray *resident=[self residentSnapshot];
    dispatch_async(_queue,^{@autoreleasepool{NSString *error=[self begin];NSArray *saved=nil;NSDictionary *remapped=nil;NSData *empty=JSON(@{},8192);NSMutableDictionary *refills=[NSMutableDictionary new];NSUInteger retired=0;NSMutableArray *folded=[NSMutableArray new];NSDictionary *allocation=nil;BOOL organize=settled&&![self->_organizedContexts[profileKey]isEqual:scopeKey];NSMutableSet *populated=[NSMutableSet new],*createdEmpty=[NSMutableSet new];
        if(!error){for(NSString *table in @[@"cards",@"rows",@"exclusions",@"positions"]){NSString *sql=[NSString stringWithFormat:@"DELETE FROM %@ WHERE scope IN(SELECT scope FROM scopes WHERE profile=? AND scope<>?)",table];if(!Run(self->_db,sql,@[profileKey,scopeKey])){error=@"Couldn’t update this profile’s Home cache.";break;}}
            if(!error&&(!Run(self->_db,@"DELETE FROM scopes WHERE profile=? AND scope<>?",@[profileKey,scopeKey])||!Run(self->_db,@"INSERT OR IGNORE INTO scopes VALUES(?,?)",@[scopeKey,profileKey])))error=@"Couldn’t open this profile’s Home cache.";
            sqlite3_stmt *owner=NULL;if(!error){BOOL ok=sqlite3_prepare_v2(self->_db,"SELECT profile FROM scopes WHERE scope=?",-1,&owner,NULL)==SQLITE_OK;if(ok){sqlite3_bind_text(owner,1,scopeKey.UTF8String,-1,SQLITE_TRANSIENT);ok=sqlite3_step(owner)==SQLITE_ROW&&[profileKey isEqual:@((const char *)sqlite3_column_text(owner,0))];}sqlite3_finalize(owner);if(!ok)error=@"This Home cache belongs to another profile.";}
            if(!error&&!Run(self->_db,@"DELETE FROM exclusions WHERE scope=?",@[scopeKey]))error=@"Couldn’t update Home exclusions.";
            for(id key in excluded)if(!error&&(!Text(key).length||[key length]>128||!Run(self->_db,@"INSERT INTO exclusions VALUES(?,?)",@[scopeKey,key])))error=@"Couldn’t update Home exclusions.";
            if(!error&&!Run(self->_db,@"DELETE FROM cards WHERE scope=? AND identity IN(SELECT identity FROM exclusions WHERE scope=?)",@[scopeKey,scopeKey]))error=@"Couldn’t update Home exclusions.";
            if(!error&&!Run(self->_db,@"DELETE FROM positions WHERE scope=? AND identity IN(SELECT identity FROM exclusions WHERE scope=?)",@[scopeKey,scopeKey]))error=@"Couldn’t update Home exclusions.";
            // A stale empty recipe must not permanently occupy one of the
            // fourteen slots. Keep every populated shelf and current recipe.
            if(!error){NSMutableSet *wanted=[NSMutableSet new];for(id raw in seeds){NSString *key=Text(Map(raw)[@"id"]);if(key.length)[wanted addObject:key];}
                for(NSDictionary *old in [self readRows:scopeKey error:&error])if(![old[@"count"]unsignedIntegerValue]&&![wanted containsObject:old[@"descriptor"][@"id"]]){
                    if(!Run(self->_db,@"DELETE FROM rows WHERE scope=? AND identity=? AND NOT EXISTS(SELECT 1 FROM cards WHERE scope=? AND rowid=?)",@[scopeKey,old[@"descriptor"][@"id"],scopeKey,old[@"descriptor"][@"id"]])){error=@"Couldn’t retire an empty Home row.";break;}retired+=(NSUInteger)sqlite3_changes(self->_db);
                    if(!Run(self->_db,@"DELETE FROM positions WHERE scope=? AND rowid=?",@[scopeKey,old[@"descriptor"][@"id"]])){error=@"Couldn’t retire an empty Home row.";break;}
                }
            }
            if(!error)for(NSDictionary *r in [self readRows:scopeKey error:&error])if([r[@"count"]unsignedIntegerValue])[populated addObject:r[@"descriptor"][@"id"]];
            for(id raw in seeds){if(error)break;NSDictionary *row=Map(raw);NSString *key=Text(row[@"id"]),*type=Text(row[@"mediaType"]);NSArray *items=row[@"items"];
                if(!key.length||key.length>128||!Text(row[@"title"]).length||!([@[@"movie",@"series"]containsObject:type]||([type isEqual:@"hero"]&&[key isEqual:@"__hero"]&&[row[@"recipe"]isEqual:@"hero"]))||![items isKindOfClass:NSArray.class]||items.count>12){error=@"This Home row could not be verified.";break;}
                NSMutableDictionary *desc=[NSMutableDictionary new];for(NSString *field in @[@"id",@"title",@"mediaType",@"recipe",@"anchorID",@"anchor",@"mood",@"year",@"anyGenres",@"allGenres",@"maxMinutes",@"providerGenre"])if(row[field])desc[field]=[field isEqual:@"anchor"]?(Card(row[field])?:@{}):row[field];NSData *body=JSON(desc,8192);if(!body){error=@"This Home row is too large.";break;}
                BOOL ok=Run(self->_db,@"INSERT OR IGNORE INTO rows(scope,identity,position,body,cursor,more,anchor) SELECT ?,?,(SELECT COALESCE(MAX(position)+1,0) FROM rows WHERE scope=?),?,?,1,? WHERE (SELECT COUNT(*) FROM rows WHERE scope=?)<14",@[scopeKey,key,scopeKey,body,empty,empty,scopeKey]);BOOL created=ok&&sqlite3_changes(self->_db)>0;NSUInteger count=0,limit=created?NSUIntegerMax:0;
                if(ok&&!created){sqlite3_stmt *existing=NULL;ok=sqlite3_prepare_v2(self->_db,@"SELECT r.body,(SELECT COUNT(*) FROM cards c WHERE c.scope=r.scope AND c.rowid=r.identity) FROM rows r WHERE r.scope=? AND r.identity=?".UTF8String,-1,&existing,NULL)==SQLITE_OK;
                    if(ok){sqlite3_bind_text(existing,1,scopeKey.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_text(existing,2,key.UTF8String,-1,SQLITE_TRANSIENT);int step=sqlite3_step(existing);
                        if(step==SQLITE_ROW){NSDictionary *old=Read(existing,0);NSUInteger present=(NSUInteger)sqlite3_column_int64(existing,1);
                            if(!present&&!SameRecipe(old,desc))ok=Run(self->_db,@"DELETE FROM positions WHERE scope=? AND rowid=?",@[scopeKey,key])&&Run(self->_db,@"UPDATE rows SET body=?,cursor=?,more=1,anchor=? WHERE scope=? AND identity=?",@[body,empty,empty,scopeKey,key]);
                            // A qualified seed is already bounded to twelve cards. New
                            // identities append after the existing prefix; a six-card
                            // row is not a complete catalog. Ownership, exclusions,
                            // reservations and the shared disk quota still apply.
                            if(!present)limit=NSUIntegerMax;else if(SameRecipe(old,desc)&&![type isEqual:@"hero"])limit=items.count;
                        }else if(step!=SQLITE_DONE)ok=NO;
                        // SQLITE_DONE means the slot cap prevented creation.
                        // Never assign cards to a row that does not exist.
                    }sqlite3_finalize(existing);
                }
                if(!ok||(limit&&![self insert:items scope:scopeKey row:key type:type limit:limit added:&count]))error=@"Couldn’t save Home’s initial titles.";
                if(!error&&created&&!count&&items.count&&[@[@"category",@"new",@"older",@"mood",@"because",@"more"]containsObject:row[@"recipe"]])[createdEmpty addObject:key];
                if(!created&&count)refills[key]=@(count);
            }
            if(!error&&settled)allocation=[self allocateCategorySeeds:seeds scope:scopeKey group:organize error:&error];
            for(NSString *key in createdEmpty)if(!error&&!Run(self->_db,@"DELETE FROM rows WHERE scope=? AND identity=? AND NOT EXISTS(SELECT 1 FROM cards WHERE scope=? AND rowid=?)",@[scopeKey,key,scopeKey,key]))error=@"Couldn’t retire an empty Home row.";
            if(!error&&organize)[folded addObjectsFromArray:[self foldSparseRows:scopeKey error:&error]?:@[]];
            // A row absent from the visible layout must earn a full category
            // before publication. Its unique cards remain reachable in broad.
            NSMutableSet *unseen=[NSMutableSet new],*auxiliary=[NSMutableSet new];
            for(NSDictionary *seed in seeds)if(![populated containsObject:seed[@"id"]]){
                if([seed[@"recipe"]isEqual:@"category"])[unseen addObject:seed[@"id"]];
                else if([@[@"new",@"older",@"mood",@"because",@"more"]containsObject:seed[@"recipe"]])[auxiliary addObject:seed[@"id"]];
            }
            if(!error)[folded addObjectsFromArray:[self foldSparseRows:scopeKey only:unseen minimum:6 error:&error]?:@[]];
            // Late ranking results can create a new auxiliary row after cold
            // organization. Fold only rows that have never been published with
            // cards; already visible shelves keep their position during a visit.
            if(!error)[folded addObjectsFromArray:[self foldSparseRows:scopeKey only:auxiliary minimum:4 error:&error]?:@[]];
            if(!error)saved=[self readRows:scopeKey error:&error];if(!error)remapped=[self reconcile:resident scope:scopeKey rows:saved];error=[self finish:error];
            if(!error&&organize){if(self->_organizedContexts.count>=12&&!self->_organizedContexts[profileKey])[self->_organizedContexts removeObjectForKey:[[self->_organizedContexts.allKeys sortedArrayUsingSelector:@selector(compare:)]firstObject]];self->_organizedContexts[profileKey]=scopeKey;}
        }
        dispatch_async(dispatch_get_main_queue(),^{if(epoch!=self->_generation||self->_closed){done(@"This Home session has changed.");return;}if(!error){NSMutableDictionary *seedIDs=[NSMutableDictionary new];for(NSDictionary *row in seeds)seedIDs[row[@"id"]]=[row[@"items"]valueForKey:@"id"]?:@[];if(![self->_opening[@"settled"]boolValue])self->_opening=@{@"settled":@(settled),@"organized":@(organize),@"seed_ids":seedIDs};if(folded.count){NSArray *history=[(self->_foldedRows?:@[]) arrayByAddingObjectsFromArray:folded];self->_foldedRows=history.count>64?[history subarrayWithRange:NSMakeRange(history.count-64,64)]:history;}if(allocation){if(organize){self->_allocationMoves=allocation[@"moves"];self->_allocationAnchors=allocation[@"anchors"];}NSArray *restored=[(self->_allocationRecovered?:@[]) arrayByAddingObjectsFromArray:allocation[@"recovered"]?:@[]];self->_allocationRecovered=restored.count>168?[restored subarrayWithRange:NSMakeRange(restored.count-168,168)]:restored;}[self publish:saved reconciled:remapped];for(NSString *key in refills)self->_seedRefills[key]=@([self->_seedRefills[key]unsignedIntegerValue]+[refills[key]unsignedIntegerValue]);self->_emptyRowsRetired+=retired;}else{self->_rows=@[];[self discardMemory];}done(error);});
    }});
}
- (void)append:(NSArray *)records row:(RWHomeRowFeed *)row expectedCursor:(NSDictionary *)expected nextCursor:(NSDictionary *)next more:(BOOL)more done:(void(^)(NSUInteger,NSString *))done {
    NSData *owned=JSON(records,256*1024),*cursor=JSON(next,8192),*expectedData=JSON(expected,8192);
    if(![self owns:row]||![records isKindOfClass:NSArray.class]||records.count>32||!owned||!cursor||!expectedData){done(0,@"This Home page could not be accepted.");return;}
    NSArray *input=[NSJSONSerialization JSONObjectWithData:owned options:0 error:nil];NSDictionary *previous=Map([NSJSONSerialization JSONObjectWithData:expectedData options:0 error:nil]);NSString *scope=_scope,*key=row.identifier,*type=row.descriptor[@"mediaType"];NSUInteger epoch=_generation;NSArray *resident=[self residentSnapshot];
    dispatch_async(_queue,^{@autoreleasepool{NSString *error=[self begin];NSUInteger added=0;NSArray *saved=nil;NSDictionary *remapped=nil;
        if(!error){sqlite3_stmt *q=NULL;BOOL valid=sqlite3_prepare_v2(self->_db,"SELECT cursor FROM rows WHERE scope=? AND identity=?",-1,&q,NULL)==SQLITE_OK;if(valid){sqlite3_bind_text(q,1,scope.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_text(q,2,key.UTF8String,-1,SQLITE_TRANSIENT);valid=sqlite3_step(q)==SQLITE_ROW&&[Read(q,0)isEqual:previous];}sqlite3_finalize(q);
            if(!valid)error=@"This row has already moved to another page.";
            if(!error&&![self insert:input scope:scope row:key type:type added:&added])error=@"Couldn’t save more titles. Existing titles were kept.";
            if(!error&&!Run(self->_db,@"UPDATE rows SET cursor=?,more=? WHERE scope=? AND identity=?",@[cursor,@(more),scope,key]))error=@"Couldn’t save this row’s next page.";
            if(!error)saved=[self readRows:scope error:&error];if(!error)remapped=[self reconcile:resident scope:scope rows:saved];error=[self finish:error];
        }
        dispatch_async(dispatch_get_main_queue(),^{if(epoch!=self->_generation||self->_closed){done(0,@"This Home session has changed.");return;}if(!error)[self publish:saved reconciled:remapped];done(error?0:added,error);});
    }});
}
- (void)saveAnchor:(NSDictionary *)anchor row:(RWHomeRowFeed *)row done:(void(^)(NSString *))done {
    NSString *key=[Text(anchor[@"id"])copy];id delta=anchor[@"delta"];NSData *data=JSON(@{@"id":key,@"delta":delta?:@0},8192);
    if(![self owns:row]||!key.length||key.length>128||![delta isKindOfClass:NSNumber.class]||!isfinite([delta doubleValue])||fabs([delta doubleValue])>10000||!data){done(@"This scroll position could not be saved.");return;}
    NSString *scope=_scope,*identifier=row.identifier;NSUInteger epoch=_generation;
    dispatch_async(_queue,^{NSString *error=[self begin];if(!error){if(!Run(self->_db,@"UPDATE rows SET anchor=? WHERE scope=? AND identity=? AND EXISTS(SELECT 1 FROM cards WHERE scope=? AND rowid=? AND identity=?)",@[data,scope,identifier,scope,identifier,key])||sqlite3_changes(self->_db)!=1)error=@"This title is no longer in the row.";error=[self finish:error];}
        dispatch_async(dispatch_get_main_queue(),^{if(epoch!=self->_generation||self->_closed){done(@"This Home session has changed.");return;}if(!error)row.anchor=Map([NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);done(error);});});
}
- (void)removeIdentifiers:(NSArray *)identifiers row:(RWHomeRowFeed *)row done:(void(^)(NSString *))done {
    if(![self owns:row]||identifiers.count>72){done(@"This Home window has changed.");return;}NSArray *ids=[[NSArray alloc]initWithArray:identifiers copyItems:YES];NSString *scope=_scope,*key=row.identifier;NSUInteger epoch=_generation;NSArray *resident=[self residentSnapshot];
    dispatch_async(_queue,^{NSString *error=[self begin];NSArray *saved=nil;NSDictionary *remapped=nil;if(!error){
        for(id value in ids){
            if(!Text(value).length||[value length]>128||!Run(self->_db,@"INSERT OR REPLACE INTO positions(scope,identity,rowid,position,sequence) SELECT scope,identity,rowid,position,(SELECT COALESCE(MAX(sequence)+1,0) FROM positions WHERE scope=?) FROM cards WHERE scope=? AND rowid=? AND identity=?",@[scope,scope,key,value])||!Run(self->_db,@"DELETE FROM cards WHERE scope=? AND rowid=? AND identity=?",@[scope,key,value])){error=@"Couldn’t update this Home row.";break;}
        }
        // Bound history separately from the resident card window and within the
        // same aggregate disk quota. Oldest removed slots expire first.
        if(!error&&!Run(self->_db,@"DELETE FROM positions WHERE scope=? AND identity IN(SELECT identity FROM positions WHERE scope=? ORDER BY sequence DESC,identity LIMIT -1 OFFSET 256)",@[scope,scope]))error=@"Couldn’t update Home’s title positions.";
        if(!error)saved=[self readRows:scope error:&error];if(!error)remapped=[self reconcile:resident scope:scope rows:saved];error=[self finish:error];}

        dispatch_async(dispatch_get_main_queue(),^{if(epoch!=self->_generation||self->_closed){done(@"This Home session has changed.");return;}if(!error)[self publish:saved reconciled:remapped];done(error);});});
}
- (NSDictionary *)cached:(NSUInteger)index row:(RWHomeRowFeed *)row {if(![self owns:row]||index>=row.count)return nil;NSDictionary *m=_memory[[row.identifier stringByAppendingFormat:@":%lu",(unsigned long)index]];return m&&![_excluded containsObject:m[@"id"]]&&(!self.permitsRecord||self.permitsRecord(m,row.descriptor))?m:nil;}
- (void)load:(NSRange)range row:(RWHomeRowFeed *)row done:(void(^)(NSString *))done {
    if(![self owns:row]||range.length>72||range.location>row.count||range.length>row.count-range.location){done(@"This Home window could not be read.");return;}NSString *scope=_scope,*key=row.identifier;NSUInteger epoch=_generation,revision=row.revision,memoryEpoch=_memoryEpoch;
    dispatch_async(_queue,^{@autoreleasepool{NSString *error=[self open];NSMutableArray *found=[NSMutableArray new],*fingerprints=[NSMutableArray new];sqlite3_stmt *q=NULL;
        if(!error){if(sqlite3_prepare_v2(self->_db,"SELECT body FROM cards WHERE scope=? AND rowid=? ORDER BY position LIMIT ? OFFSET ?",-1,&q,NULL)!=SQLITE_OK)error=@"Couldn’t read this part of Home.";else{sqlite3_bind_text(q,1,scope.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_text(q,2,key.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_int64(q,3,range.length);sqlite3_bind_int64(q,4,range.location);int step;while((step=sqlite3_step(q))==SQLITE_ROW){NSDictionary *m=Read(q,0);if(!Text(m[@"id"]).length){error=@"A saved title could not be read.";break;}[found addObject:m];[fingerprints addObject:BodyDigest(q,0)];}if(step!=SQLITE_DONE&&!error)error=@"Couldn’t finish reading this part of Home.";}sqlite3_finalize(q);}
        dispatch_async(dispatch_get_main_queue(),^{
            BOOL(^valid)(void)=^BOOL{return epoch==self->_generation&&revision==row.revision&&memoryEpoch==self->_memoryEpoch&&!self->_closed;};
            if(!valid()){done(@"This Home window has changed.");return;}
            if(error){done(error);return;}
            void(^accept)(NSArray *,NSString *)=^(NSArray *ready,NSString *failure){
                if(!valid()){done(@"This Home window has changed.");return;}if(failure){done(failure);return;}
                NSMutableDictionary *byID=[NSMutableDictionary new];for(NSDictionary *m in ready)if(Text(m[@"id"]).length)byID[m[@"id"]]=m;
                NSMutableArray *removed=[NSMutableArray new];for(NSDictionary *m in found)if(!byID[m[@"id"]])[removed addObject:m[@"id"]];
                if(removed.count){[self removeIdentifiers:removed row:row done:^(NSString *removeError){if(!removeError&&self.onChange)self.onChange();done(removeError);}];return;}
                for(NSUInteger i=0;i<found.count;i++){NSString *cacheKey=[key stringByAppendingFormat:@":%lu",(unsigned long)(range.location+i)];[self->_memoryOrder removeObject:cacheKey];self->_memory[cacheKey]=byID[found[i][@"id"]];self->_memoryFingerprints[cacheKey]=fingerprints[i];[self->_memoryOrder addObject:cacheKey];}
                while(self->_memoryOrder.count>128){NSString *old=self->_memoryOrder.firstObject;[self->_memory removeObjectForKey:old];[self->_memoryFingerprints removeObjectForKey:old];[self->_memoryOrder removeObjectAtIndex:0];}done(nil);
            };
            if(self.prepareRecords)self.prepareRecords(found,row.descriptor,accept);else accept(found,nil);
        });
    }});
}
- (void)assignedIDs:(void(^)(NSSet *,NSString *))done {[self assignedIDsExceptRemovedInRow:nil done:done];}
- (void)assignedIDsExceptRemovedInRow:(NSString *)row done:(void(^)(NSSet *,NSString *))done {
    NSString *scope=[_scope copy],*key=[Text(row)copy];NSUInteger epoch=_generation;
    dispatch_async(_queue,^{NSString *error=[self open];NSMutableSet *ids=[NSMutableSet new];sqlite3_stmt *q=NULL;
        if(!error){if(sqlite3_prepare_v2(self->_db,"SELECT identity FROM cards WHERE scope=? UNION SELECT identity FROM exclusions WHERE scope=? UNION SELECT identity FROM positions WHERE scope=? AND rowid<>?",-1,&q,NULL)!=SQLITE_OK)error=@"Couldn’t read Home’s title assignments.";
            else{NSArray *args=@[scope,scope,scope,key];for(NSUInteger i=0;i<args.count;i++)sqlite3_bind_text(q,(int)i+1,[args[i]UTF8String],-1,SQLITE_TRANSIENT);int step;while((step=sqlite3_step(q))==SQLITE_ROW)[ids addObject:@((const char *)sqlite3_column_text(q,0))];if(step!=SQLITE_DONE)error=@"Couldn’t read Home’s title assignments.";}sqlite3_finalize(q);}
        dispatch_async(dispatch_get_main_queue(),^{done(epoch==self->_generation&&!self->_closed?ids:nil,error?:((epoch!=self->_generation||self->_closed)?@"This Home session has changed.":nil));});
    });
}
- (void)recordAnchorQuery:(RWHomeRowFeed *)row title:(NSString *)title epoch:(NSUInteger)epoch revision:(NSUInteger)revision index:(NSUInteger)index reason:(NSString *)reason {
    if(!_anchorQueries)_anchorQueries=[NSMutableArray new];
    [_anchorQueries addObject:@{@"row":row.identifier?:@"",@"context":row.context?:@"",@"title":title?:@"",@"reason":reason,@"read_generation":@(epoch),@"generation":@(_generation),@"read_revision":@(revision),@"revision":@(row.revision),@"count":@(row.count),@"index":index==NSNotFound?@(-1):@(index),@"uptime":@(NSProcessInfo.processInfo.systemUptime)}];
    while(_anchorQueries.count>16)[_anchorQueries removeObjectAtIndex:0];
}
- (void)anchorIndex:(RWHomeRowFeed *)row done:(void(^)(NSUInteger))done {
    [self anchorIndex:row retries:3 done:done];
}
- (void)anchorIndex:(RWHomeRowFeed *)row retries:(NSUInteger)retries done:(void(^)(NSUInteger))done {
    if(![self owns:row]||!Text(row.anchor[@"id"]).length){[self recordAnchorQuery:row title:row.anchor[@"id"] epoch:_generation revision:row.revision index:NSNotFound reason:@"unowned_or_unset"];done(NSNotFound);return;}
    NSString *scope=_scope,*key=row.identifier,*title=row.anchor[@"id"];NSUInteger epoch=_generation,revision=row.revision;
    dispatch_async(_queue,^{NSUInteger index=NSNotFound;BOOL readOK=NO;sqlite3_stmt *q=NULL;
        if(![self open]&&sqlite3_prepare_v2(self->_db,"SELECT (SELECT COUNT(*) FROM cards c WHERE c.scope=t.scope AND c.rowid=t.rowid AND c.position<t.position) FROM cards t WHERE t.scope=? AND t.rowid=? AND t.identity=?",-1,&q,NULL)==SQLITE_OK){
            NSArray *args=@[scope,key,title];for(NSUInteger i=0;i<args.count;i++)sqlite3_bind_text(q,(int)i+1,[args[i]UTF8String],-1,SQLITE_TRANSIENT);int step=sqlite3_step(q);readOK=step==SQLITE_ROW||step==SQLITE_DONE;if(step==SQLITE_ROW)index=(NSUInteger)sqlite3_column_int64(q,0);
        }sqlite3_finalize(q);dispatch_async(dispatch_get_main_queue(),^{
            if(![self owns:row]||![scope isEqual:self->_scope]||![row.anchor[@"id"]isEqual:title]){[self recordAnchorQuery:row title:title epoch:epoch revision:revision index:index reason:@"owner_or_anchor_changed"];done(NSNotFound);return;}
            // Same-context activation advances generation before its commit;
            // the row handle still belongs to this session. Requery current
            // ordering instead of discarding valid restoration intent. A new
            // profile/row/anchor was rejected above; retries remain bounded.
            BOOL changedGeneration=epoch!=self->_generation,changedRevision=revision!=row.revision;
            if(changedGeneration||changedRevision){
                [self recordAnchorQuery:row title:title epoch:epoch revision:revision index:index reason:retries?(changedGeneration?@"retry_generation":@"retry_revision"):@"retry_limit"];
                if(retries)[self anchorIndex:row retries:retries-1 done:done];else done(NSNotFound);return;
            }
            [self recordAnchorQuery:row title:title epoch:epoch revision:revision index:index reason:!readOK?@"read_error":index==NSNotFound?@"missing":@"found"];
            done(readOK?index:NSNotFound);
        });
    });
}
- (void)discardMemory {_memoryEpoch++;[_memory removeAllObjects];[_memoryFingerprints removeAllObjects];[_memoryOrder removeAllObjects];}
- (void)close:(void(^)(void))done {if(_closed){if(done)done();return;}_closed=YES;_generation++;[self discardMemory];_rows=@[];dispatch_async(_queue,^{if(self->_db){sqlite3_close(self->_db);self->_db=NULL;}if(done)dispatch_async(dispatch_get_main_queue(),done);});}
- (void)dealloc {sqlite3 *db=_db;dispatch_async(_queue,^{if(db)sqlite3_close(db);});}
@end
