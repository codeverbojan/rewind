#import "RWMetadataBudget.h"
#import "RWCast.h"
#import "RWAtomicWriter.h"
static NSString *CT(id v){return [v isKindOfClass:NSString.class]?v:@"";}
static NSDictionary *CD(id v){return [v isKindOfClass:NSDictionary.class]?v:@{};}
static NSArray *CA(id v){return [v isKindOfClass:NSArray.class]?v:@[];}
static NSString *CN(NSString *v){return [[v stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]]lowercaseString];}
static NSString *CE(NSString *v){return [v stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"]];}
static id CV(id s){return [CD(s)[@"rank"]isEqual:@"deprecated"]?nil:CD(CD(CD(s)[@"mainsnak"])[@"datavalue"])[@"value"];}
static BOOL CH(NSString *value,NSString *host){NSURL *u=[NSURL URLWithString:value];return [u.scheme isEqual:@"https"]&&[u.host.lowercaseString isEqual:host]&&!u.user&&!u.password;}
static NSString *Plain(NSString *s){return [[s stringByReplacingOccurrencesOfString:@"<[^>]+>" withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0,s.length)]stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];}
static NSString *Match(NSString *s,NSString *pattern,NSUInteger group){NSRegularExpression *r=[NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionDotMatchesLineSeparators error:nil];NSTextCheckingResult *m=[r firstMatchInString:s options:0 range:NSMakeRange(0,s.length)];return m&&group<m.numberOfRanges&&[m rangeAtIndex:group].location!=NSNotFound?[s substringWithRange:[m rangeAtIndex:group]]:@"";}
static NSString *HTMLText(NSString *s){s=Plain(s);for(NSArray *pair in @[@[@"&quot;",@"\""],@[@"&#39;",@"'"],@[@"&apos;",@"'"],@[@"&nbsp;",@" "]])s=[s stringByReplacingOccurrencesOfString:pair[0] withString:pair[1]];return [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];}
static NSString *TitleKey(NSString *s){return [[CN(HTMLText(s))componentsSeparatedByCharactersInSet:NSCharacterSet.alphanumericCharacterSet.invertedSet]componentsJoinedByString:@""];}
static NSMutableDictionary *ProviderCooldowns(void){static NSMutableDictionary *value;static dispatch_once_t once;dispatch_once(&once,^{value=[NSMutableDictionary new];});return value;}
static double RetryDelay(NSHTTPURLResponse *response){NSString *header=CT(response.allHeaderFields[@"Retry-After"]?:response.allHeaderFields[@"retry-after"]);double delay=header.doubleValue;if(delay<=0&&header.length){NSDateFormatter *f=[NSDateFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];f.dateFormat=@"EEE, dd MMM yyyy HH:mm:ss z";delay=[[f dateFromString:header]timeIntervalSinceNow];}return MAX(120,delay);}
@implementation RWCast {
    NSURLSession *_session;NSURLSessionDataTask *_task;NSMutableDictionary *_cache,*_identityRefreshes;NSString *_path,*_key;NSUInteger _generation;void(^_done)(NSArray *);NSDictionary *_lastFailure;NSArray *_legacyPeople;
}
 + (NSArray *)publicMoviePeople:(NSString *)html meta:(NSDictionary *)meta {
    if(![meta[@"type"]isEqual:@"movie"]||html.length>2*1024*1024)return @[];
    id raw=meta[@"moviedb_id"];NSString *identifier=[raw isKindOfClass:NSNumber.class]?[raw stringValue]:CT(raw);
    if([identifier rangeOfString:@"^[1-9][0-9]{0,9}$" options:NSRegularExpressionSearch].location!=0)return @[];
    NSString *canonical=Match(html,@"<link[^>]+rel=\"canonical\"[^>]+href=\"([^\"]+)\"",1);NSURL *url=[NSURL URLWithString:canonical];
    NSString *pattern=[NSString stringWithFormat:@"^/movie/%@(?:-[^/]+)?/cast/?$",identifier];
    if(!CH(canonical,@"www.themoviedb.org")||[url.path rangeOfString:pattern options:NSRegularExpressionSearch].location!=0)return @[];
    NSString *title=Match(html,@"<meta[^>]+property=\"og:title\"[^>]+content=\"([^\"]+)\"",1);if(![TitleKey(title)isEqual:TitleKey(CT(meta[@"name"]))])return @[];
    NSInteger year=[CT(meta[@"releaseInfo"])integerValue];if(year<1800||![Match(html,@"<title>(.*?)</title>",1)containsString:[NSString stringWithFormat:@"(%ld)",(long)year]])return @[];
    NSString *section=Match(html,@"<h3>Cast[^<]*(?:<span>.*?</span>)?</h3>\\s*<ol[^>]*>(.*?)</ol>",1);if(!section.length)return @[];
    NSRegularExpression *rows=[NSRegularExpression regularExpressionWithPattern:@"<li[^>]+data-credit-id=[^>]+>(.*?)</li>" options:NSRegularExpressionDotMatchesLineSeparators error:nil];NSMutableArray *people=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
    for(NSTextCheckingResult *match in [rows matchesInString:section options:0 range:NSMakeRange(0,section.length)]){NSString *row=[section substringWithRange:[match rangeAtIndex:1]];
        NSString *linkPattern=@"<p>\\s*<a[^>]+href=\"(/person/[0-9]+[^\"]*)\"[^>]*>(.*?)</a>";NSString *name=HTMLText(Match(row,linkPattern,2));NSString *person=Match(row,linkPattern,1);NSString *pid=Match(person,@"^/person/([1-9][0-9]{0,9})(?:-[^/?#]+)?/?$",1);if(!name.length||!pid.length||[seen containsObject:pid])continue;[seen addObject:pid];
        NSString *image=Match(row,@"(https://media\\.themoviedb\\.org/t/p/w132_and_h132_face/[^\" ,]+)",1);if(!image.length)image=Match(row,@"<img[^>]+src=\"([^\"]+)\"",1);
        if(!CH(image,@"media.themoviedb.org")||![[NSURL URLWithString:image].path hasPrefix:@"/t/p/w"]||![image.pathExtension.lowercaseString isEqual:@"jpg"])image=@"";
        NSString *role=HTMLText(Match(row,@"<p[^>]+class=\"character\"[^>]*>(.*?)</p>",1));
        [people addObject:@{@"name":name,@"role":role,@"image":image,@"sourceURL":canonical,@"personURL":[@"https://www.themoviedb.org" stringByAppendingString:person],@"providerPersonID":pid,@"credit":@"Cast and images: The Movie Database (TMDB). From this film’s public cast page.",@"provider":@"TMDB"}];if(people.count==12)break;
    }return people;
}
+ (NSString *)showID:(NSDictionary *)show imdb:(NSString *)imdb {
    if(![CT(CD(show[@"externals"])[@"imdb"])isEqual:imdb]||![imdb hasPrefix:@"tt"])return nil;
    id value=show[@"id"];return [value isKindOfClass:NSNumber.class]&&[value integerValue]>0?[value stringValue]:nil;
}
+ (NSArray *)tvPeople:(NSDictionary *)show imdb:(NSString *)imdb {
    if(![self showID:show imdb:imdb])return @[];NSMutableArray *people=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
    for(id item in CA(CD(show[@"_embedded"])[@"cast"])){
        NSDictionary *p=CD(CD(item)[@"person"]),*c=CD(CD(item)[@"character"]);NSString *name=CT(p[@"name"]),*photo=CT(CD(p[@"image"])[@"medium"]),*source=CT(p[@"url"]);
        if(!name.length||[seen containsObject:p[@"id"]?:name])continue;[seen addObject:p[@"id"]?:name];
        NSString *pid=[p[@"id"]isKindOfClass:NSNumber.class]&&[p[@"id"]longLongValue]>0?[p[@"id"]stringValue]:@"";
        [people addObject:@{@"name":name,@"role":CT(c[@"name"]),@"image":CH(photo,@"static.tvmaze.com")?photo:@"",@"sourceURL":CH(source,@"www.tvmaze.com")?source:@"https://www.tvmaze.com",@"personURL":CH(source,@"www.tvmaze.com")?source:@"",@"providerPersonID":pid,@"credit":@"Cast data: TVmaze · CC BY-SA",@"provider":@"TVmaze"}];if(people.count==12)break;
    }return people;
}
+ (NSDictionary *)personReference:(NSDictionary *)person {
    BOOL tmdb=[person[@"provider"]isEqual:@"TMDB"],tv=[person[@"provider"]isEqual:@"TVmaze"];if(!tmdb&&!tv)return nil;
    NSString *address=CT(person[@"personURL"]);if(!address.length&&tv)address=CT(person[@"sourceURL"]);
    NSURL *url=[NSURL URLWithString:address];if(!CH(address,tmdb?@"www.themoviedb.org":@"www.tvmaze.com")||url.query||url.fragment||url.port)return nil;
    NSString *pid=Match(url.path,tmdb?@"^/person/([1-9][0-9]{0,9})(?:-[^/]+)?/?$":@"^/people/([1-9][0-9]{0,9})(?:/[^/]+)?/?$",1);
    NSString *provided=CT(person[@"providerPersonID"]);if(!pid.length||(provided.length&&![provided isEqual:pid]))return nil;
    return @{@"property":tmdb?@"P4985":@"P11449",@"value":pid};
}
+ (NSString *)knownPersonID:(NSDictionary *)person titleCredits:(NSArray *)credits {
    NSString *qid=CT(person[@"personID"]);if([qid rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location==0)return qid;
    // Credits are already verified against the opened title's exact IMDb ID.
    // Preserve that existing path; this is not a global name search.
    NSString *name=CT(person[@"name"]);if(!name.length)return @"";NSMutableArray *matches=[NSMutableArray new];
    for(id raw in CA(credits)){NSDictionary *ref=CD(raw);NSString *candidate=CT(ref[@"id"]);if([CT(ref[@"name"])caseInsensitiveCompare:name]==NSOrderedSame&&[candidate rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location==0)[matches addObject:candidate];}
    return matches.count==1?matches[0]:@"";
}
+ (NSDictionary *)canonicalPerson:(NSDictionary *)entity reference:(NSDictionary *)reference {
    NSString *property=CT(reference[@"property"]),*value=CT(reference[@"value"]),*qid=CT(entity[@"id"]);
    if(![@[@"P4985",@"P11449"]containsObject:property]||[value rangeOfString:@"^[1-9][0-9]{0,9}$" options:NSRegularExpressionSearch].location!=0||[qid rangeOfString:@"^Q[1-9][0-9]*$" options:NSRegularExpressionSearch].location!=0)return nil;
    BOOL exact=NO,human=NO;NSDictionary *claims=CD(entity[@"claims"]);for(id s in CA(claims[property]))if([CV(s)isEqual:value])exact=YES;for(id s in CA(claims[@"P31"]))if([CD(CV(s))[@"id"]isEqual:@"Q5"])human=YES;
    if(!exact||!human)return nil;return @{@"id":qid,@"name":CT(CD(CD(entity[@"labels"])[@"en"])[@"value"]),@"type":@"person",@"property":property,@"value":value};
}
+ (NSArray *)actorIDs:(NSDictionary *)entity imdb:(NSString *)imdb {
    NSDictionary *claims=CD(entity[@"claims"]);BOOL exact=NO;for(id s in CA(claims[@"P345"]))if([CV(s)isEqual:imdb])exact=YES;if(!exact)return @[];
    NSMutableOrderedSet *ids=[NSMutableOrderedSet new];for(id s in CA(claims[@"P161"])){NSString *qid=CT(CD(CV(s))[@"id"]);if([qid rangeOfString:@"^Q[0-9]+$" options:NSRegularExpressionSearch].location==0)[ids addObject:qid];if(ids.count==24)break;}return ids.array;
}
+ (NSArray *)wikiPeople:(NSDictionary *)entities names:(NSArray *)cast {
    NSMutableArray *people=[NSMutableArray new];
    for(id raw in cast){NSString *name=[raw isKindOfClass:NSDictionary.class]?CT(raw[@"name"]):CT(raw);if(!name.length)continue;NSMutableArray *matches=[NSMutableArray new];
        for(NSDictionary *e in [CD(entities)allValues]){NSString *label=CT(CD(CD(e[@"labels"])[@"en"])[@"value"]);BOOL match=[CN(label)isEqual:CN(name)];for(id a in CA(CD(e[@"aliases"])[@"en"]))if([CN(CT(CD(a)[@"value"]))isEqual:CN(name)])match=YES;if(match)[matches addObject:e];}
        if(matches.count!=1)continue;NSDictionary *e=matches[0];NSString *file=@"";for(id claim in CA(CD(e[@"claims"])[@"P18"])){file=CT(CV(claim));if(file.length)break;}
        if(!file.length)continue;[people addObject:@{@"name":name,@"imageFile":file,@"personID":CT(e[@"id"]),@"provider":@"Wikimedia Commons"}];if(people.count==12)break;
    }return people;
}
+ (NSArray *)photos:(NSDictionary *)response people:(NSArray *)people {
    NSMutableDictionary *files=[NSMutableDictionary new];for(NSDictionary *p in [CD(CD(response[@"query"])[@"pages"])allValues]){NSDictionary *i=CD(CA(p[@"imageinfo"]).firstObject);if(i.count)files[[CT(p[@"title"])stringByReplacingOccurrencesOfString:@"_" withString:@" "]]=i;}
    NSMutableArray *out=[NSMutableArray new];for(NSDictionary *p in people){NSString *file=[[@"File:" stringByAppendingString:CT(p[@"imageFile"])]stringByReplacingOccurrencesOfString:@"_" withString:@" "];NSDictionary *i=files[file],*ext=CD(i[@"extmetadata"]);NSString *url=CT(i[@"thumburl"]),*source=CT(i[@"descriptionurl"]),*license=CT(CD(ext[@"LicenseShortName"])[@"value"]),*artist=Plain(CT(CD(ext[@"Artist"])[@"value"]));
        if(!(CH(url,@"upload.wikimedia.org")||CH(url,@"thumb.wikimedia.org"))||!CH(source,@"commons.wikimedia.org")||!license.length||!artist.length)continue;
        NSMutableDictionary *row=[p mutableCopy];row[@"image"]=url;row[@"sourceURL"]=source;row[@"credit"]=[NSString stringWithFormat:@"%@ · %@ · Cropped portrait",artist,license];row[@"role"]=@"";[out addObject:row];
    }return out;
}
+ (NSURLSessionConfiguration *)sessionConfiguration {return [NSURLSessionConfiguration ephemeralSessionConfiguration];}
- (NSDictionary *)lastFailure {return _lastFailure?:@{};}
- (instancetype)initWithCache:(NSString *)path {
    if((self=[super init])){_path=path;_identityRefreshes=[NSMutableDictionary new];NSData *data=[NSData dataWithContentsOfFile:path];_cache=[CD(data?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil)mutableCopy];for(NSString *key in [_cache.allKeys copy])if(!CA(CD(_cache[key])[@"people"]).count)[_cache removeObjectForKey:key];NSURLSessionConfiguration *c=[[self class]sessionConfiguration];c.timeoutIntervalForRequest=5;c.timeoutIntervalForResource=6;c.HTTPMaximumConnectionsPerHost=1;c.HTTPAdditionalHeaders=@{@"User-Agent":@"Rewind/0.29 (standalone iPad experiment; org.local.ministreamlab)",@"Accept":@"application/json"};_session=[NSURLSession sessionWithConfiguration:c];}return self;
}
- (NSArray *)cached:(NSDictionary *)meta {NSDictionary *entry=_cache[CT(meta[@"id"])];return [entry[@"expires"]doubleValue]>NSDate.date.timeIntervalSince1970?CA(entry[@"people"]):nil;}
- (void)cancel {[[RWMetadataBudget shared]cancel:_task];_task=nil;_generation++;_done=nil;_key=nil;_legacyPeople=nil;}
- (void)finish:(NSArray *)people { [self finish:people cacheable:YES]; }
- (void)finish:(NSArray *)people cacheable:(BOOL)cacheable {
    if(!_key)return;NSString *key=_key;void(^done)(NSArray *)=_done;NSArray *legacy=_legacyPeople;[self cancel];if(!people.count&&legacy.count){people=legacy;cacheable=NO;}if(cacheable)_cache[key]=@{@"people":people?:@[],@"identityVersion":@2,@"expires":@(NSDate.date.timeIntervalSince1970+(people.count?7*86400:900))};
    if(_cache.count>48){NSArray *keys=[_cache keysSortedByValueUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"expires"]compare:b[@"expires"]];}];for(NSUInteger i=0;i<keys.count-40;i++)[_cache removeObjectForKey:keys[i]];}
    if(cacheable)[[RWAtomicWriter shared]write:[NSJSONSerialization dataWithJSONObject:_cache options:0 error:nil] path:_path];if(done)done(people?:@[]);
}
- (void)fetch:(NSString *)url generation:(NSUInteger)g done:(void(^)(NSDictionary *))done {
    NSString *host=[NSURL URLWithString:url].host;double remaining=[ProviderCooldowns()[host]doubleValue]-NSDate.date.timeIntervalSince1970;if(remaining>0){_lastFailure=@{@"host":host,@"http":@429,@"retry_after_seconds":@(remaining)};[self finish:@[] cacheable:NO];return;}
    __block NSURLSessionDataTask *requestTask=nil;
    requestTask=[_session dataTaskWithURL:[NSURL URLWithString:url] completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){id json=!error&&[(NSHTTPURLResponse *)response statusCode]==200&&data.length<=2*1024*1024?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;dispatch_async(dispatch_get_main_queue(),^{[[RWMetadataBudget shared]complete:requestTask];requestTask=nil;if(g!=self->_generation)return;if([(NSHTTPURLResponse *)response statusCode]==429||[(NSHTTPURLResponse *)response statusCode]==503)ProviderCooldowns()[host]=@(NSDate.date.timeIntervalSince1970+RetryDelay((NSHTTPURLResponse *)response));if(![json isKindOfClass:NSDictionary.class]||json[@"error"]){self->_lastFailure=@{@"host":[NSURL URLWithString:url].host?:@"",@"code":@(error.code),@"domain":error.domain?:@"",@"http":@([(NSHTTPURLResponse *)response statusCode])};[self finish:@[] cacheable:NO];return;}done(json);});}];_task=requestTask;_task.priority=NSURLSessionTaskPriorityHigh;[[RWMetadataBudget shared]enqueue:_task foreground:YES];
}
- (void)wikiEntity:(NSDictionary *)entity meta:(NSDictionary *)meta generation:(NSUInteger)g {
    NSArray *ids=[RWCast actorIDs:entity imdb:meta[@"id"]];if(!ids.count){[self finish:@[]];return;}
    [self fetch:[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=wbgetentities&format=json&props=claims%%7Clabels%%7Caliases&languages=en&ids=%@",[ids componentsJoinedByString:@"%7C"]] generation:g done:^(NSDictionary *json){
        NSArray *people=[RWCast wikiPeople:CD(json[@"entities"]) names:CA(meta[@"cast"])];NSMutableArray *files=[NSMutableArray new];for(NSDictionary *p in people)[files addObject:[@"File:" stringByAppendingString:p[@"imageFile"]]];if(!files.count){[self finish:@[]];return;}
        [self fetch:[NSString stringWithFormat:@"https://commons.wikimedia.org/w/api.php?action=query&format=json&prop=imageinfo&iiprop=url%%7Cextmetadata&iiurlwidth=200&titles=%@",CE([files componentsJoinedByString:@"|"])] generation:g done:^(NSDictionary *photos){[self finish:[RWCast photos:photos people:people]];}];
    }];
}
- (void)resolve:(NSDictionary *)meta done:(void(^)(NSArray *))done {
    _lastFailure=nil;NSArray *cached=[self cached:meta];NSString *imdb=CT(meta[@"id"]);BOOL migrate=NO;
    if(cached.count&&[_cache[imdb][@"identityVersion"]intValue]<2){for(NSDictionary *p in cached)if([p[@"provider"]isEqual:@"TMDB"]&&![RWCast personReference:p]){migrate=YES;break;}}
    double now=NSDate.date.timeIntervalSince1970;if(cached&&(!migrate||[_identityRefreshes[imdb]doubleValue]>now)){done(cached);return;}
    [self cancel];if(migrate){_legacyPeople=cached;if(_identityRefreshes.count>=48)[_identityRefreshes removeAllObjects];_identityRefreshes[imdb]=@(now+300);}if([imdb rangeOfString:@"^tt[0-9]{5,12}$" options:NSRegularExpressionSearch].location!=0){done(@[]);return;}
    _key=imdb;_done=[done copy];NSUInteger g=_generation;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,16*NSEC_PER_SEC),dispatch_get_main_queue(),^{if(self->_generation==g){self->_lastFailure=@{@"stage":@"deadline"};[self finish:@[] cacheable:NO];}});
    if([meta[@"type"]isEqual:@"series"]){[self fetch:[@"https://api.tvmaze.com/lookup/shows?imdb=" stringByAppendingString:imdb] generation:g done:^(NSDictionary *show){NSString *identifier=[RWCast showID:show imdb:imdb];if(!identifier){[self finish:@[]];return;}[self fetch:[NSString stringWithFormat:@"https://api.tvmaze.com/shows/%@?embed=cast",identifier] generation:g done:^(NSDictionary *full){[self finish:[RWCast tvPeople:full imdb:imdb]];}];}];return;}
    id raw=meta[@"moviedb_id"];NSString *tmdb=[raw isKindOfClass:NSNumber.class]?[raw stringValue]:CT(raw);
    if([tmdb rangeOfString:@"^[1-9][0-9]{0,9}$" options:NSRegularExpressionSearch].location==0){[self publicMovie:meta identifier:tmdb generation:g];return;}
    [self wikiMovie:meta generation:g];
}
- (void)wikiMovie:(NSDictionary *)meta generation:(NSUInteger)g {
    NSString *imdb=CT(meta[@"id"]);
    [self fetch:[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=query&list=search&format=json&srlimit=3&srnamespace=0&srprop=&srsearch=%@",CE([@"haswbstatement:P345=" stringByAppendingString:imdb])] generation:g done:^(NSDictionary *search){NSMutableArray *ids=[NSMutableArray new];for(NSDictionary *row in CA(CD(search[@"query"])[@"search"])){NSString *qid=CT(row[@"title"]);if([qid rangeOfString:@"^Q[0-9]+$" options:NSRegularExpressionSearch].location==0)[ids addObject:qid];}if(!ids.count){[self finish:@[]];return;}
        [self fetch:[NSString stringWithFormat:@"https://www.wikidata.org/w/api.php?action=wbgetentities&format=json&props=claims&ids=%@",[ids componentsJoinedByString:@"%7C"]] generation:g done:^(NSDictionary *json){for(NSDictionary *entity in [CD(json[@"entities"])allValues])if([RWCast actorIDs:entity imdb:imdb].count){[self wikiEntity:entity meta:meta generation:g];return;}[self finish:@[]];}];
    }];
}
- (void)publicMovie:(NSDictionary *)meta identifier:(NSString *)identifier generation:(NSUInteger)g {
    NSString *host=@"www.themoviedb.org";if([ProviderCooldowns()[host]doubleValue]>NSDate.date.timeIntervalSince1970){if(_legacyPeople.count)[self finish:@[] cacheable:NO];else [self wikiMovie:meta generation:g];return;}
    NSURL *url=[NSURL URLWithString:[NSString stringWithFormat:@"https://www.themoviedb.org/movie/%@/cast",identifier]];NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];[request setValue:@"text/html" forHTTPHeaderField:@"Accept"];[request setValue:@"en-US" forHTTPHeaderField:@"Accept-Language"];
    __block NSURLSessionDataTask *requestTask=nil;
    requestTask=[_session dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){NSInteger status=[response isKindOfClass:NSHTTPURLResponse.class]?[(NSHTTPURLResponse *)response statusCode]:0;NSString *html=!error&&status==200&&data.length<=2*1024*1024?[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]:nil;NSArray *people=html?[RWCast publicMoviePeople:html meta:meta]:@[];
        dispatch_async(dispatch_get_main_queue(),^{[[RWMetadataBudget shared]complete:requestTask];requestTask=nil;if(g!=self->_generation)return;if(status==429||status==503)ProviderCooldowns()[host]=@(NSDate.date.timeIntervalSince1970+RetryDelay((NSHTTPURLResponse *)response));
            if(people.count){[self finish:people];return;}
            self->_lastFailure=@{@"host":host,@"http":@(status),@"code":@(error.code),@"domain":error.domain?:@"",@"stage":html?@"identity_or_markup":@"request"};if(self->_legacyPeople.count)[self finish:@[] cacheable:NO];else [self wikiMovie:meta generation:g];
        });
    }];_task=requestTask;_task.priority=NSURLSessionTaskPriorityHigh;[[RWMetadataBudget shared]enqueue:_task foreground:YES];
}
- (void)dealloc {[[RWMetadataBudget shared]cancel:_task];[_session invalidateAndCancel];}
@end
