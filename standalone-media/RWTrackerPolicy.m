#import "RWTrackerPolicy.h"

@implementation RWTrackerPolicy
+ (BOOL)supportsHTTPS {
#ifdef TORRENT_USE_OPENSSL
    return YES;
#else
    return NO;
#endif
}
+ (NSString *)canonicalKeyForURL:(NSString *)url allowHTTPS:(BOOL)allowHTTPS {
    if(![url isKindOfClass:NSString.class]||!url.length||url.length>2048)return nil;
    NSCharacterSet *bad=[NSCharacterSet whitespaceAndNewlineCharacterSet];
    if([url rangeOfCharacterFromSet:bad].location!=NSNotFound||[url rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location!=NSNotFound)return nil;
    NSCharacterSet *hex=[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    for(NSUInteger i=0;i<url.length;i++)if([url characterAtIndex:i]=='%'){
        if(i+2>=url.length||![hex characterIsMember:[url characterAtIndex:i+1]]||![hex characterIsMember:[url characterAtIndex:i+2]])return nil;
        i+=2;
    }
    @try{
        NSURLComponents *parts=[NSURLComponents componentsWithString:url];
        NSString *scheme=parts.scheme.lowercaseString,*host=parts.host.lowercaseString;
        BOOL http=[scheme isEqual:@"http"],https=[scheme isEqual:@"https"],udp=[scheme isEqual:@"udp"];
        if(!(http||udp||(https&&allowHTTPS))||!host.length||parts.fragment!=nil||!parts.URL)return nil;
        NSNumber *port=parts.port;
        if(port&&(port.longLongValue<1||port.longLongValue>65535))return nil;
        // UDP has no implicit tracker port. HTTP(S) default ports are identities,
        // but path/query escaping and order remain opaque (including UDP URLData).
        if(udp&&!port)return nil;
        NSInteger effectivePort=port?port.integerValue:(https?443:80);
        NSString *path=parts.percentEncodedPath?:@"";
        if((http||https)&&!path.length)path=@"/";
        NSArray *identity=@[scheme,host,@(effectivePort),parts.percentEncodedUser?:NSNull.null,
            parts.percentEncodedPassword?:NSNull.null,path,parts.percentEncodedQuery?:NSNull.null];
        NSData *data=[NSJSONSerialization dataWithJSONObject:identity options:0 error:nil];
        return data?[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]:nil;
    }@catch(NSException *exception){return nil;}
}
+ (NSArray *)URLsFromSourceEntries:(NSArray *)entries allowHTTPS:(BOOL)allowHTTPS limit:(NSUInteger)limit {
    if(![entries isKindOfClass:NSArray.class]||!limit)return @[];
    NSMutableArray *out=[NSMutableArray new];NSMutableSet *seen=[NSMutableSet new];
    NSUInteger scanned=0;limit=MIN(limit,16);
    for(id entry in entries){
        if(scanned++>=256||out.count>=limit)break;
        if(![entry isKindOfClass:NSString.class]||[entry length]>2056||![entry hasPrefix:@"tracker:"])continue;
        NSString *url=[entry substringFromIndex:8],*key=[self canonicalKeyForURL:url allowHTTPS:allowHTTPS];
        if(!key||[seen containsObject:key])continue;
        // libtorrent's protocol parser is case-sensitive. Normalize only that
        // prefix; credentials, host spelling and opaque path/query stay intact.
        NSRange colon=[url rangeOfString:@":"];
        NSString *scheme=[[url substringToIndex:colon.location]lowercaseString];
        NSString *usable=[scheme stringByAppendingString:[url substringFromIndex:colon.location]];
        [seen addObject:key];[out addObject:usable];
    }
    return out;
}
+ (NSArray *)publicFallbacks {
    return @[@"udp://tracker.opentrackr.org:1337/announce",@"udp://tracker.torrent.eu.org:451"];
}
@end
