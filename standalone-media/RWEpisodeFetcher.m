#import "RWEpisodeFetcher.h"
#import "RWMetadataBudget.h"
#import "RWDiscoveryEpisodes.h"
@implementation RWEpisodeFetcher {
    NSURLSession *_session;RWMetadataBudget *_budget;NSURLSessionDataTask *_task;
    BOOL _background,_finished,_started;double _began,_deadline,_readyAt;NSUInteger _index,_requests,_completed,_successes;
    NSArray *_identifiers;NSMutableArray *_errors;BOOL(^_ready)(void);NSArray *(^_targets)(void);void(^_accept)(NSDictionary *);void(^_done)(NSDictionary *);
}
- (instancetype)initWithSession:(NSURLSession *)session budget:(RWMetadataBudget *)budget {if((self=[super init])){_session=session;_budget=budget;_errors=[NSMutableArray new];}return self;}
- (BOOL)background {return _background;}
- (NSDictionary *)diagnostics {return @{@"background":@(_background),@"targets":@(_identifiers.count),@"requests":@(_requests),@"completed":@(_completed),@"accepted":@(_successes),@"seconds":@(MAX(0,NSProcessInfo.processInfo.systemUptime-_began)),@"catalog_wait_seconds":@(_readyAt?_readyAt-_began:0),@"errors":[_errors copy],@"finished":@(_finished),@"request_limit":@4,@"concurrency_limit":@1};}
- (void)startWhenReady:(BOOL(^)(void))ready identifiers:(NSArray *(^)(void))identifiers background:(BOOL)background timeout:(double)timeout accept:(void(^)(NSDictionary *))accept done:(void(^)(NSDictionary *))done {
    NSAssert(NSThread.isMainThread,@"Episode fetch ownership is on main");NSAssert(!_started,@"Single-use fetch");_started=YES;_background=background;_ready=[ready copy];_targets=[identifiers copy];_accept=[accept copy];_done=[done copy];_began=NSProcessInfo.processInfo.systemUptime;_deadline=_began+MIN(20,MAX(.05,timeout));
    __weak RWEpisodeFetcher *weak=self;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)((_deadline-_began)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{RWEpisodeFetcher *owner=weak;if(!owner||owner->_finished)return;[owner->_errors addObject:@"deadline"];[owner finish];});[self awaitCatalog];
}
- (void)awaitCatalog {
    if(_finished)return;if(_ready&&!_ready()){__weak RWEpisodeFetcher *weak=self;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/10),dispatch_get_main_queue(),^{[weak awaitCatalog];});return;}
    _readyAt=NSProcessInfo.processInfo.systemUptime;NSMutableOrderedSet *ids=[NSMutableOrderedSet new];id targets=_targets?_targets():@[];
    if([targets isKindOfClass:NSArray.class])for(id key in targets){if([key isKindOfClass:NSString.class]){NSRange r=[key rangeOfString:@"^tt[0-9]{5,12}$" options:NSRegularExpressionSearch];if(r.location==0&&r.length==[key length])[ids addObject:key];}if(ids.count==4)break;}
    _identifiers=ids.array;_ready=nil;_targets=nil;[self next];
}
- (void)next {
    if(_finished)return;if(_index>=_identifiers.count){[self finish];return;}
    NSString *identifier=_identifiers[_index++];NSURL *url=[NSURL URLWithString:[NSString stringWithFormat:@"https://v3-cinemeta.strem.io/meta/series/%@.json",identifier]];
    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];request.timeoutInterval=MIN(8,MAX(.05,_deadline-NSProcessInfo.processInfo.systemUptime));[request setValue:@"Rewind/0.96 (iOS9 episode updates)" forHTTPHeaderField:@"User-Agent"];
    __weak RWEpisodeFetcher *weak=self;
    _task=[_session dataTaskWithRequest:request completionHandler:^(NSData *data,NSURLResponse *response,NSError *error){@autoreleasepool{
        NSInteger status=[response isKindOfClass:NSHTTPURLResponse.class]?[(NSHTTPURLResponse *)response statusCode]:0;
        id payload=!error&&status==200&&data.length<=3*1024*1024?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;
        NSDictionary *show=[payload isKindOfClass:NSDictionary.class]&&[payload[@"meta"]isKindOfClass:NSDictionary.class]?payload[@"meta"]:nil;
        if(![show[@"id"]isEqual:identifier]||![show[@"type"]isEqual:@"series"]||![show[@"videos"]isKindOfClass:NSArray.class])show=nil;
        NSDictionary *owned=show?[RWDiscoveryEpisodes immutableShow:show]:nil;
        dispatch_async(dispatch_get_main_queue(),^{RWEpisodeFetcher *self=weak;if(!self||self->_finished)return;if(!self->_background)[self->_budget complete:self->_task];self->_task=nil;self->_completed++;
            if(owned){self->_successes++;if(self->_accept)self->_accept(owned);}else [self->_errors addObject:error?@"network":status==200?@"invalid_show":[NSString stringWithFormat:@"http_%ld",(long)status]];
            [self next];
        });
    }}];_requests++;
    if(_background)[_task resume];else [_budget enqueue:_task foreground:NO];
}
- (void)finish {
    if(_finished)return;_finished=YES;if(_task){if(_background)[_task cancel];else [_budget cancel:_task];_task=nil;}
    void(^done)(NSDictionary *)=_done;_done=nil;_accept=nil;_ready=nil;_targets=nil;if(done)done(self.diagnostics);
}
- (void)cancel {if(_finished)return;[_errors addObject:@"cancelled"];[self finish];}
@end
