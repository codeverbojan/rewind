// Consolidate on opening a context, or before publishing a new populated row.
// Short specialist shelves contribute their remaining titles to the matching
// broad shelf. World Cinema remains separate from the main-language shelves.
- (NSArray *)foldSparseRows:(NSString *)scope error:(NSString **)error {
    return [self foldSparseRows:scope only:nil minimum:4 error:error];
}
- (NSArray *)foldSparseRows:(NSString *)scope only:(NSSet *)only minimum:(NSUInteger)minimum error:(NSString **)error {
    NSArray *rows=[self readRows:scope error:error];if(*error)return nil;
    NSMutableDictionary *byID=[NSMutableDictionary new];for(NSDictionary *r in rows)byID[r[@"descriptor"][@"id"]]=r;
    NSMutableArray *folded=[NSMutableArray new];
    for(NSDictionary *r in rows){NSDictionary *d=r[@"descriptor"];NSUInteger count=[r[@"count"]unsignedIntegerValue];NSString *from=d[@"id"],*type=d[@"mediaType"],*to=[@"for-you-" stringByAppendingString:type?:@""];
        if((only&&![only containsObject:from])||!count||count>=minimum||![@[@"movie",@"series"]containsObject:type]||![@[@"category",@"new",@"older",@"mood",@"because",@"more"]containsObject:d[@"recipe"]])continue;
        NSDictionary *target=byID[to];if(!target||![target[@"descriptor"][@"recipe"]isEqual:@"for-you"]||![target[@"descriptor"][@"mediaType"]isEqual:type])continue;
        sqlite3_stmt *q=NULL;long long base=0,reserved=0;
        BOOL ok=sqlite3_prepare_v2(_db,"SELECT COALESCE(MAX(position)+1,0) FROM (SELECT position FROM cards WHERE scope=? AND rowid=? UNION ALL SELECT position FROM positions WHERE scope=? AND rowid=?)",-1,&q,NULL)==SQLITE_OK;
        if(ok){NSArray *args=@[scope,to,scope,to];for(NSUInteger i=0;i<args.count;i++)sqlite3_bind_text(q,(int)i+1,[args[i]UTF8String],-1,SQLITE_TRANSIENT);ok=sqlite3_step(q)==SQLITE_ROW;if(ok)base=sqlite3_column_int64(q,0);}sqlite3_finalize(q);
        if(ok)ok=Run(_db,@"UPDATE cards SET rowid=?,position=position+? WHERE scope=? AND rowid=?",@[to,@(base),scope,from]);
        if(ok)ok=Run(_db,@"UPDATE positions SET rowid=?,position=position+? WHERE scope=? AND rowid=?",@[to,@(base),scope,from]);if(ok)reserved=sqlite3_changes(_db);
        // The target's cursor and anchor stay intact. Retire the specialist's
        // cursor with its heading; continuing the broad shelf uses its own query.
        if(ok)ok=Run(_db,@"DELETE FROM rows WHERE scope=? AND identity=?",@[scope,from]);
        if(!ok){*error=@"Couldn’t organize Home’s saved shelves.";return nil;}
        [folded addObject:@{@"from":from,@"to":to,@"count":@(count),@"reserved":@(reserved),@"position_base":@(base),@"minimum":@(minimum),@"reason":only?([d[@"recipe"]isEqual:@"category"]?@"new_category":@"new_auxiliary"):@"cold_sparse"}];
    }return folded;
}
