// Bounded cold-session allocation from already admitted recommendation seeds.
// Narrow specialist rows and World ownership are never donors. No I/O other
// than this transaction, no new discovery/source work, and no mid-visit moves.
- (NSDictionary *)allocateCategorySeeds:(NSArray *)seeds scope:(NSString *)scope group:(BOOL)group error:(NSString **)error {
    NSMutableArray *moves=[NSMutableArray new],*anchors=[NSMutableArray new],*recovered=[NSMutableArray new];
    for(NSDictionary *seed in seeds){
        if(![seed[@"recipe"]isEqual:@"category"])continue;
        NSString *target=seed[@"id"],*type=seed[@"mediaType"],*source=[@"for-you-" stringByAppendingString:type];
        NSArray *rows=[self readRows:scope error:error];if(*error)return nil;NSDictionary *from=nil,*to=nil;
        for(NSDictionary *r in rows){if([r[@"descriptor"][@"id"]isEqual:source])from=r;if([r[@"descriptor"][@"id"]isEqual:target])to=r;}
        // Current eligible category seeds may be reserved in the general row
        // after an earlier policy rejection. Recover that exact ownership and
        // slot first; otherwise both the general refill cap and cross-row
        // reservation guard leave the title unreachable forever.
        if(to&&from&&SameRecipe(seed,to[@"descriptor"])&&[from[@"descriptor"][@"recipe"]isEqual:@"for-you"]){
            for(NSDictionary *m in seed[@"items"]){if(![RWHomeCategoryPolicy matches:m category:seed])continue;
                sqlite3_stmt *reservation=NULL;BOOL ok=sqlite3_prepare_v2(_db,"SELECT position FROM positions WHERE scope=? AND rowid=? AND identity=? AND NOT EXISTS(SELECT 1 FROM cards WHERE scope=? AND identity=?)",-1,&reservation,NULL)==SQLITE_OK;long long oldSlot=-1;
                if(ok){NSArray *args=@[scope,source,m[@"id"],scope,m[@"id"]];for(NSUInteger i=0;i<args.count;i++)sqlite3_bind_text(reservation,(int)i+1,[args[i]UTF8String],-1,SQLITE_TRANSIENT);int step=sqlite3_step(reservation);if(step==SQLITE_ROW)oldSlot=sqlite3_column_int64(reservation,0);else ok=step==SQLITE_DONE;}sqlite3_finalize(reservation);
                if(!ok){*error=@"Couldn’t read Home’s saved title positions.";return nil;}
                if(oldSlot>=0){NSUInteger added=0;if(![self insert:@[m] scope:scope row:source type:type added:&added]){*error=@"Couldn’t recover Home’s eligible titles.";return nil;}if(added)[recovered addObject:@{@"id":m[@"id"],@"row":source,@"slot":@(oldSlot)}];}
            }
            for(NSDictionary *r in [self readRows:scope error:error])if([r[@"descriptor"][@"id"]isEqual:source])from=r;if(*error)return nil;
        }
        if(!group)continue;
        NSUInteger count=[to[@"count"]unsignedIntegerValue];
        if(!to||count>=12||!SameRecipe(seed,to[@"descriptor"]))continue;
        NSMutableDictionary *admitted=[NSMutableDictionary new];for(NSDictionary *m in seed[@"items"])if([RWHomeCategoryPolicy matches:m category:seed])admitted[m[@"id"]]=m;
        // A broad Animation row can otherwise permanently own every title of a
        // narrower adventure/comedy theme. Rebalance only at this cold opening;
        // retain six in Animation and four in the general row. Other specialist
        // rows, World, and the hero are never donors.
        NSMutableArray *donors=[NSMutableArray new];if([from[@"descriptor"][@"recipe"]isEqual:@"for-you"]&&[from[@"descriptor"][@"mediaType"]isEqual:type])[donors addObject:from];
        for(NSDictionary *r in rows){NSDictionary *desc=r[@"descriptor"];NSArray *any=List(desc[@"anyGenres"]);
            BOOL animation=[desc[@"recipe"]isEqual:@"category"]&&[desc[@"mediaType"]isEqual:type]&&any.count==1&&[Text(any.firstObject).lowercaseString isEqual:@"animation"]&&!List(desc[@"allGenres"]).count&&![desc[@"maxMinutes"]unsignedIntegerValue];
            NSArray *targetAny=List(seed[@"anyGenres"]);BOOL narrower=List(seed[@"allGenres"]).count||[seed[@"maxMinutes"]unsignedIntegerValue]||targetAny.count!=1||![Text(targetAny.firstObject).lowercaseString isEqual:@"animation"];
            if(animation&&narrower&&![desc[@"id"]isEqual:target])[donors addObject:r];
        }
        sqlite3_stmt *q=NULL;BOOL ok=YES;NSMutableArray *available=[NSMutableArray new];NSMutableDictionary *donorByID=[NSMutableDictionary new];
        for(NSDictionary *donor in donors){NSDictionary *desc=donor[@"descriptor"];NSString *donorID=desc[@"id"];BOOL broad=[desc[@"recipe"]isEqual:@"for-you"];
            NSUInteger reserve=broad?4:6,donorCount=[donor[@"count"]unsignedIntegerValue];if(donorCount<=reserve)continue;
            donorByID[donorID]=donor;NSMutableArray *matches=[NSMutableArray new];
            for(NSString *key in admitted){if(!broad&&![RWHomeCategoryPolicy matches:admitted[key] category:desc])continue;
                q=NULL;ok=sqlite3_prepare_v2(_db,"SELECT position FROM cards WHERE scope=? AND rowid=? AND identity=?",-1,&q,NULL)==SQLITE_OK;
                if(ok){NSArray *args=@[scope,donorID,key];for(NSUInteger i=0;i<args.count;i++)sqlite3_bind_text(q,(int)i+1,[args[i]UTF8String],-1,SQLITE_TRANSIENT);int step=sqlite3_step(q);if(step==SQLITE_ROW)[matches addObject:@{@"id":key,@"from":donorID,@"old_slot":@(sqlite3_column_int64(q,0))}];else ok=step==SQLITE_DONE;}sqlite3_finalize(q);if(!ok){*error=@"Couldn’t read Home’s category candidates.";return nil;}
            }
            [matches sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"old_slot"]compare:b[@"old_slot"]];}];
            NSUInteger take=MIN(matches.count,donorCount-reserve);[available addObjectsFromArray:[matches subarrayWithRange:NSMakeRange(0,take)]];
        }
        NSUInteger needed=MIN((NSUInteger)12-count,available.count);
        if(!needed||(!count&&needed<6))continue;
        q=NULL;long long position=0;ok=sqlite3_prepare_v2(_db,"SELECT COALESCE(MAX(position)+1,0) FROM (SELECT position FROM cards WHERE scope=? AND rowid=? UNION ALL SELECT position FROM positions WHERE scope=? AND rowid=?)",-1,&q,NULL)==SQLITE_OK;
        if(ok){NSArray *args=@[scope,target,scope,target];for(NSUInteger i=0;i<args.count;i++)sqlite3_bind_text(q,(int)i+1,[args[i]UTF8String],-1,SQLITE_TRANSIENT);ok=sqlite3_step(q)==SQLITE_ROW;if(ok)position=sqlite3_column_int64(q,0);}sqlite3_finalize(q);
        NSMutableDictionary *movedAnchorSlots=[NSMutableDictionary new];
        for(NSUInteger i=0;ok&&i<needed;i++){NSDictionary *candidate=available[i];NSString *key=candidate[@"id"],*donorID=candidate[@"from"];long long slot=position++;
            ok=Run(_db,@"UPDATE cards SET rowid=?,position=?,body=? WHERE scope=? AND rowid=? AND identity=?",@[target,@(slot),JSON(Card(admitted[key]),8192),scope,donorID,key])&&sqlite3_changes(_db)==1;
            if(ok){[moves addObject:@{@"id":key,@"from":donorID,@"to":target,@"old_slot":candidate[@"old_slot"],@"new_slot":@(slot)}];if([donorByID[donorID][@"anchor"][@"id"]isEqual:key])movedAnchorSlots[donorID]=candidate[@"old_slot"];}
        }
        for(NSString *donorID in movedAnchorSlots){if(!ok)break;NSNumber *movedAnchorSlot=movedAnchorSlots[donorID];NSDictionary *oldAnchor=donorByID[donorID][@"anchor"];
            q=NULL;NSString *replacement=nil;ok=sqlite3_prepare_v2(_db,"SELECT identity FROM cards WHERE scope=? AND rowid=? ORDER BY CASE WHEN position>=? THEN 0 ELSE 1 END,ABS(position-?) LIMIT 1",-1,&q,NULL)==SQLITE_OK;
            if(ok){sqlite3_bind_text(q,1,scope.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_text(q,2,donorID.UTF8String,-1,SQLITE_TRANSIENT);sqlite3_bind_int64(q,3,movedAnchorSlot.longLongValue);sqlite3_bind_int64(q,4,movedAnchorSlot.longLongValue);ok=sqlite3_step(q)==SQLITE_ROW;if(ok)replacement=@((const char *)sqlite3_column_text(q,0));}sqlite3_finalize(q);
            if(ok){NSMutableDictionary *next=[oldAnchor mutableCopy];next[@"id"]=replacement;ok=Run(_db,@"UPDATE rows SET anchor=? WHERE scope=? AND identity=?",@[JSON(next,8192),scope,donorID]);if(ok)[anchors addObject:@{@"row":donorID,@"before":oldAnchor,@"after":next}];}
        }
        if(!ok){*error=@"Couldn’t organize Home’s categories.";return nil;}
    }
    return @{@"moves":moves,@"anchors":anchors,@"recovered":recovered};
}
