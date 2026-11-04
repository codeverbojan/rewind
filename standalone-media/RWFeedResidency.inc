// Included in RWFeedStore's implementation. Database handles, compression and
// quota accounting are confined to FeedQueue; UI flags remain on main.
- (void)recordResidency:(NSString *)operation error:(NSString *)error started:(double)start {
    NSDictionary *value=@{@"operation":operation,@"parked":@(!_db&&_archiveBytes>0),@"database_bytes":@(FeedBytes(_path)),@"archive_bytes":@(FeedBytes([_path stringByAppendingString:@".gz"])),@"expanded_bytes":@(_archiveBytes),@"seconds":@(NSProcessInfo.processInfo.systemUptime-start),@"error":error?:@"",@"worker_io":@YES};
    dispatch_async(dispatch_get_main_queue(),^{if(!self->_closed)self->_residency=value;});
}
- (NSString *)ensureOpen {
    if(_db)return nil;
    double start=NSProcessInfo.processInfo.systemUptime;NSFileManager *fm=NSFileManager.defaultManager;
    NSString *archive=[_path stringByAppendingString:@".gz"],*error=nil;BOOL restoring=[fm fileExistsAtPath:archive];
    unsigned long long room=FeedRoom(_path);
    if(room<24576||(restoring&&(_archiveBytes==0||_archiveBytes>room))||(!restoring&&FeedBytes(_path)>room))return @"The browsing cache is full. Existing titles are still available.";
    if(restoring&&![RWFeedArchive unpack:archive to:_path limit:room expected:_archiveBytes error:&error]){[self recordResidency:@"restore" error:error started:start];return error;}
    if(_created&&![fm fileExistsAtPath:_path])return @"This saved browsing list is missing. Try loading it again.";
    int flags=SQLITE_OPEN_READWRITE|SQLITE_OPEN_NOMUTEX|(_created?0:SQLITE_OPEN_CREATE);
    if(sqlite3_open_v2(_path.UTF8String,&_db,flags,NULL)!=SQLITE_OK)error=@"Couldn’t open the browsing cache.";
    if(!error){NSString *settings=[NSString stringWithFormat:@"PRAGMA page_size=4096; PRAGMA auto_vacuum=INCREMENTAL; PRAGMA max_page_count=%llu; PRAGMA cache_size=-256; PRAGMA journal_mode=DELETE; PRAGMA synchronous=NORMAL;",room/4096];if(sqlite3_exec(_db,settings.UTF8String,NULL,NULL,NULL)!=SQLITE_OK)error=@"Couldn’t prepare the browsing cache.";}
    if(!error&&!_created&&sqlite3_exec(_db,"CREATE TABLE cards(position INTEGER PRIMARY KEY, identity TEXT UNIQUE NOT NULL, body BLOB NOT NULL, kind TEXT NOT NULL, year INTEGER NOT NULL, rating REAL NOT NULL); CREATE TABLE visible(position INTEGER PRIMARY KEY, identity TEXT UNIQUE NOT NULL);",NULL,NULL,NULL)!=SQLITE_OK)error=@"Couldn’t create this browsing list.";
    if(!error&&restoring){sqlite3_stmt *check=NULL;BOOL valid=sqlite3_prepare_v2(_db,"PRAGMA quick_check",-1,&check,NULL)==SQLITE_OK&&sqlite3_step(check)==SQLITE_ROW&&strcmp((const char *)sqlite3_column_text(check,0),"ok")==0&&sqlite3_step(check)==SQLITE_DONE;sqlite3_finalize(check);check=NULL;
        if(valid)valid=sqlite3_prepare_v2(_db,"SELECT visible.position,cards.identity,cards.body,cards.kind,cards.year,cards.rating FROM visible JOIN cards ON visible.identity=cards.identity LIMIT 0",-1,&check,NULL)==SQLITE_OK;sqlite3_finalize(check);
        if(!valid)error=@"Couldn’t verify this browsing list. Its saved copy was kept.";
    }
    if(error){if(_db){sqlite3_close(_db);_db=NULL;}if(restoring||!_created)[fm removeItemAtPath:_path error:nil];}
    else{_created=YES;sqlite3_stmt *mode=NULL;_vacuumMode=-1;if(sqlite3_prepare_v2(_db,"PRAGMA auto_vacuum",-1,&mode,NULL)==SQLITE_OK&&sqlite3_step(mode)==SQLITE_ROW)_vacuumMode=sqlite3_column_int(mode,0);sqlite3_finalize(mode);if(restoring){[fm removeItemAtPath:archive error:nil];_archiveBytes=0;}}
    if(restoring)[self recordResidency:@"restore" error:error started:start];return error;
}
- (void)parkOnQueue {
    if(!_db)return;
    double start=NSProcessInfo.processInfo.systemUptime;NSString *error=nil,*archive=[_path stringByAppendingString:@".gz"];
    if(sqlite3_close(_db)!=SQLITE_OK){[self recordResidency:@"park" error:@"The browsing list is still in use." started:start];return;}_db=NULL;
    unsigned long long bytes=FeedBytes(_path);
    // Compression cannot expand the permanent cache. If it offers no saving,
    // keep the original database closed; the next read can reopen it normally.
    if(bytes&&[RWFeedArchive pack:_path to:archive limit:bytes-1 error:&error]){
        if([NSFileManager.defaultManager removeItemAtPath:_path error:nil])_archiveBytes=bytes;
        else{[NSFileManager.defaultManager removeItemAtPath:archive error:nil];error=@"Couldn’t reclaim this browsing list’s space.";}
    }
    [self recordResidency:@"park" error:error started:start];
}
- (void)park {
    if(_closed||!_activeRequested)return;_activeRequested=NO;[self cancelPages];[self discardMemory];
    dispatch_async(_queue,^{@autoreleasepool{self->_inactive=YES;[self parkOnQueue];}});
}
- (void)activate {
    if(_closed||_activeRequested)return;_activeRequested=YES;
    dispatch_async(_queue,^{self->_inactive=NO;}); // Restore only if a read/write needs it.
}
